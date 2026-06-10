/// TemplateRenderer：DSL 引擎的模板渲染层
///
/// 复现 Dify 的双层模板机制：
/// 1. VariablePool.convert_template 处理 {{#node_id.var#}} → 解析为实际值
/// 2. Jinja2 处理 {{ var }} 和 {% if %} 等 → 渲染为最终文本
///
/// Dify 节点用法：
/// - template-transform：先 convertTemplate，再 Jinja2 渲染
/// - LLM basic 模式：convertTemplate 后的 text 字段就是最终提示词
/// - LLM jinja2 模式：先 convertTemplate 拿到 jinja2_text，再 Jinja2 渲染
/// - completion_params：convertTemplate 后作为参数（如 temperature）
library;

import 'package:jinja/jinja.dart';

import 'models/variable_pool.dart';
import 'package:novel_app/services/logger_service.dart';

class TemplateRenderer {
  /// 仅执行 convertTemplate（不跑 Jinja2）
  ///
  /// 用于：completion_params 替换、LLM basic 模式的 text 字段
  String convertTemplate(VariablePool pool, String template) {
    return pool.convertTemplate(template).text;
  }

  /// 仅执行 Jinja2 渲染（不跑 convertTemplate）
  ///
  /// context 是 Jinja 变量字典，键值会被模板中的 {{ key }} 引用
  String renderJinja(String template, Map<String, Object?> context) {
    LoggerService.instance.d(
      'renderJinja 入口: templateLength=${template.length}',
      category: LogCategory.ai,
      tags: ['dsl', 'template'],
    );
    try {
      final tpl = Template(template);
      return tpl.render(context);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        'Jinja2 渲染失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['dsl', 'template'],
      );
      rethrow;
    }
  }

  /// 双层渲染：先对 context 中的每个值跑 convertTemplate，再 Jinja2 渲染
  ///
  /// 用于：LLM jinja2 模式的 prompt_template、template-transform 节点的 variables
  String renderTemplate(
    VariablePool pool,
    String template,
    Map<String, Object?> context,
  ) {
    final resolvedContext = <String, Object?>{};
    context.forEach((key, value) {
      if (value is String) {
        // 把字符串值中的 {{#...#}} 占位符先解析
        resolvedContext[key] = pool.convertTemplate(value).text;
      } else {
        resolvedContext[key] = value;
      }
    });
    return renderJinja(template, resolvedContext);
  }

  /// template-transform 节点专用：
  /// - template: Jinja2 模板，使用 variables 中声明的别名
  /// - variables: [{variable: 'alias', value_selector: [node_id, var_name]}]
  String renderTemplateTransform(
    VariablePool pool, {
    required String template,
    required List<Map<String, dynamic>> variables,
  }) {
    final context = <String, Object?>{};
    for (final v in variables) {
      final alias = v['variable']?.toString() ?? '';
      final selectorRaw = v['value_selector'];
      if (alias.isEmpty || selectorRaw is! List) continue;
      final selector = selectorRaw.map((e) => e.toString()).toList();
      final segment = pool.get(selector);
      if (segment == null) continue;
      // 把 segment 转成 jinja 可用的值
      context[alias] = _segmentToJinjaValue(segment.toObject());
    }
    return renderJinja(template, context);
  }

  /// LLM jinja2 模式专用：
  /// - jinja2_text 字段 = Jinja2 模板
  /// - jinja2_variables 字段 = [{variable: 'name', value_selector: [...]}]
  String renderTemplateWithJinja(
    VariablePool pool,
    String jinja2Text,
    List<Map<String, dynamic>> jinja2Variables,
  ) {
    final context = <String, Object?>{};
    for (final v in jinja2Variables) {
      final alias = v['variable']?.toString() ?? '';
      final selectorRaw = v['value_selector'];
      if (alias.isEmpty || selectorRaw is! List) continue;
      final selector = selectorRaw.map((e) => e.toString()).toList();
      final segment = pool.get(selector);
      if (segment == null) continue;
      context[alias] = _segmentToJinjaValue(segment.toObject());
    }
    return renderJinja(jinja2Text, context);
  }

  /// LLM basic 模式专用：
  /// - text 字段 = 可能含 {{#...#}} 占位符的字符串
  /// - 直接 convertTemplate
  String renderLlmBasic(VariablePool pool, String text) {
    return pool.convertTemplate(text).text;
  }

  // -- 内部 --

  dynamic _segmentToJinjaValue(dynamic value) {
    if (value == null) return '';
    return value;
  }
}
