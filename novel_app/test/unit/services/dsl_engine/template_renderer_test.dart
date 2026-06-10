/// TemplateRenderer 单元测试
///
/// 复现 Dify 的双层模板渲染：
/// 1. VariablePool.convert_template 处理 {{#node_id.var#}}
/// 2. Jinja2 处理 {{ var }} 和 {% if %} 等
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/dsl_engine/models/variable_pool.dart';
import 'package:novel_app/services/dsl_engine/template_renderer.dart';

void main() {
  late VariablePool pool;
  late TemplateRenderer renderer;

  setUp(() {
    pool = VariablePool();
    renderer = TemplateRenderer();
  });

  group('convertTemplate only (不跑 Jinja2)', () {
    test('简单占位符替换', () {
      pool.add(['n1', 'text'], 'hello');
      final result = renderer.convertTemplate(pool, 'Hello {{#n1.text#}}!');
      expect(result, 'Hello hello!');
    });

    test('未解析的占位符降级为空串', () {
      final result = renderer.convertTemplate(pool, 'Hi {{#missing.x#}}!');
      expect(result, 'Hi !');
    });

    test('多个占位符', () {
      pool.add(['n1', 'a'], 'A');
      pool.add(['n2', 'b'], 'B');
      final result = renderer.convertTemplate(pool, '{{#n1.a#}}-{{#n2.b#}}');
      expect(result, 'A-B');
    });

    test('非占位符文本原样保留', () {
      pool.add(['n', 'v'], 'X');
      final result = renderer.convertTemplate(pool, 'plain text {{#n.v#}}');
      expect(result, 'plain text X');
    });
  });

  group('Jinja2 only (不跑 convert_template)', () {
    test('简单变量替换', () {
      final result = renderer.renderJinja('Hello {{ name }}!', {
        'name': 'World',
      });
      expect(result, 'Hello World!');
    });

    test('多个变量', () {
      final result = renderer.renderJinja('{{ a }} + {{ b }} = {{ c }}', {
        'a': 1,
        'b': 2,
        'c': 3,
      });
      expect(result, '1 + 2 = 3');
    });

    test('if 条件', () {
      final result = renderer.renderJinja(
        '{% if show %}YES{% else %}NO{% endif %}',
        {'show': true},
      );
      expect(result, 'YES');
    });

    test('未定义变量不抛错（Dify 行为）', () {
      // jinja 0.6.6 默认 undefined = silent
      final result = renderer.renderJinja('Hello {{ missing }}', {});
      expect(result, 'Hello ');
    });

    test('嵌套对象属性', () {
      final result = renderer.renderJinja('{{ user.name }}', {
        'user': {'name': 'Alice'},
      });
      expect(result, 'Alice');
    });

    test('for 循环', () {
      final result = renderer.renderJinja(
        '{% for item in items %}[{{ item }}]{% endfor %}',
        {'items': ['a', 'b', 'c']},
      );
      expect(result, '[a][b][c]');
    });
  });

  group('convertTemplate + Jinja2 组合（顺序: 先 convert 后 jinja）', () {
    test('基本组合：占位符先解析成 Jinja 变量名，再渲染', () {
      pool.add(['start', 'user_input'], 'Alice');
      // creater.yml 的实际场景：template 里有 {{#xxx#}} 直接作为 Jinja 上下文
      // 但 creater.yml 中 template 里的 {{}} 是 Jinja 变量
      // {{#n1.x#}} 是 VariablePool 占位符
      final result = renderer.renderTemplate(
        pool,
        '你好 {{ name }}！',
        {'name': '{{#start.user_input#}}'},
      );
      expect(result, '你好 Alice！');
    });

    test('LLM basic 模式: text 字段已用 convertTemplate 处理', () {
      pool.add(['node1', 'output'], 'some text');
      // 模拟 LLM 节点 basic 模式：text 字段 = convert_template 后的纯文本
      final result = renderer.convertTemplate(
        pool,
        'Answer: {{#node1.output#}}',
      );
      expect(result, 'Answer: some text');
    });

    test('LLM jinja2 模式: jinja2_text 字段需先用 convertTemplate 再 jinja2', () {
      pool.add(['start', 'content'], 'chapter content');
      pool.add(['start', 'cmd'], '特写');
      // 模拟 jinja2_text 字段 + jinja2_variables 列表
      final result = renderer.renderTemplateWithJinja(
        pool,
        '{% if cmd %}执行{{ cmd }}{% endif %}: {{ content }}',
        <Map<String, dynamic>>[
          {'variable': 'cmd', 'value_selector': ['start', 'cmd']},
          {'variable': 'content', 'value_selector': ['start', 'content']},
        ],
      );
      expect(result, '执行特写: chapter content');
    });
  });

  group('template-transform 节点专用渲染', () {
    test('basic 模式：template + variables 列表', () {
      // creater.yml 中 template-transform 节点：
      // - template: Jinja2 模板，用别名
      // - variables: [{variable: alias, value_selector: [start, real_var]}]
      pool.add(['start', 'setting'], '我是 AI 写手');
      pool.add(['start', 'content'], '章节内容');
      final result = renderer.renderTemplateTransform(
        pool,
        template: '设定：{{ setting }}\n内容：{{ content }}',
        variables: [
          {
            'variable': 'setting',
            'value_selector': ['start', 'setting'],
          },
          {
            'variable': 'content',
            'value_selector': ['start', 'content'],
          },
        ],
      );
      expect(result, '设定：我是 AI 写手\n内容：章节内容');
    });

    test('template 中含 if 条件', () {
      pool.add(['start', 'a'], '');
      pool.add(['start', 'b'], 'content');
      final result = renderer.renderTemplateTransform(
        pool,
        template: '{% if a %}A:{{ a }}{% endif %}{% if b %}B:{{ b }}{% endif %}',
        variables: [
          {'variable': 'a', 'value_selector': ['start', 'a']},
          {'variable': 'b', 'value_selector': ['start', 'b']},
        ],
      );
      // 条件分支：a 为空字符串视为 falsy，b 有值则显示
      expect(result, contains('B:content'));
      expect(result, isNot(contains('A:')));
    });
  });

  group('completion_params 模板替换（temperature 等动态参数）', () {
    test('温度参数可使用 {{#...#}} 占位符', () {
      pool.add(['n1', 'temp'], '0.7');
      // 模拟 LLM 节点的 completion_params 中 temperature: '{{#n1.temp#}}'
      final result = renderer.convertTemplate(pool, '{{#n1.temp#}}');
      expect(result, '0.7');
    });
  });
}
