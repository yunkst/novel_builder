import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/outline.dart';
import '../../test_bootstrap.dart';

/// Outline模型单元测试
///
/// 测试重点：
/// 1. 构造函数和默认值
/// 2. toMap/fromMap序列化/反序列化
/// 3. copyWith方法的正确性
/// 4. ChapterOutlineDraft模型测试
/// 5. 边界情况和异常处理
void main() {
  // 初始化测试环境
  initTests();
  group('Outline模型 - 基础功能测试', () {
    group('构造函数和字段', () {
      test('应该正确创建Outline实例', () {
        final now = DateTime.now();
        final outline = Outline(
          id: 1,
          novelUrl: 'https://example.com/novel/1',
          title: '测试大纲',
          content: '这是大纲内容',
          createdAt: now,
          updatedAt: now,
        );

        expect(outline.id, 1);
        expect(outline.novelUrl, 'https://example.com/novel/1');
        expect(outline.title, '测试大纲');
        expect(outline.content, '这是大纲内容');
        expect(outline.createdAt, now);
        expect(outline.updatedAt, now);
      });

      test('应该支持id为null（新建时）', () {
        final now = DateTime.now();
        final outline = Outline(
          novelUrl: 'https://example.com/novel/1',
          title: '测试大纲',
          content: '这是大纲内容',
          createdAt: now,
          updatedAt: now,
        );

        expect(outline.id, isNull);
      });

      test('应该支持空字符串字段', () {
        final now = DateTime.now();
        final outline = Outline(
          novelUrl: '',
          title: '',
          content: '',
          createdAt: now,
          updatedAt: now,
        );

        expect(outline.novelUrl, '');
        expect(outline.title, '');
        expect(outline.content, '');
      });

      test('应该支持长文本内容', () {
        final longContent = '内容' * 20000; // 约40KB
        final now = DateTime.now();
        final outline = Outline(
          novelUrl: 'https://example.com/novel/1',
          title: '长内容大纲',
          content: longContent,
          createdAt: now,
          updatedAt: now,
        );

        expect(outline.content, longContent);
        expect(outline.content.length, 40000);
      });

      test('应该支持特殊字符', () {
        final now = DateTime.now();
        final outline = Outline(
          novelUrl: 'https://example.com/novel/1?param=value&other=123',
          title: '第\'一\'章"测\\试大纲',
          content: '包含\n换行符\t制表符\n的内容',
          createdAt: now,
          updatedAt: now,
        );

        expect(outline.novelUrl, contains('?'));
        expect(outline.title, contains('"'));
        expect(outline.content, contains('\n'));
      });
    });

    group('toString - 字符串表示', () {
      test('toString应该包含所有关键字段', () {
        final now = DateTime(2025, 1, 30, 12, 30, 45);
        final outline = Outline(
          id: 1,
          novelUrl: 'https://example.com/novel/1',
          title: '测试大纲',
          content: '内容',
          createdAt: now,
          updatedAt: now,
        );

        final str = outline.toString();

        expect(str, contains('id: 1'));
        expect(str, contains('novelUrl: https://example.com/novel/1'));
        expect(str, contains('title: 测试大纲'));
        expect(str, contains('createdAt:'));
        expect(str, contains('updatedAt:'));
      });

      test('toString应该正确处理null id', () {
        final now = DateTime.now();
        final outline = Outline(
          novelUrl: 'https://example.com/novel/1',
          title: '测试大纲',
          content: '内容',
          createdAt: now,
          updatedAt: now,
        );

        final str = outline.toString();

        expect(str, contains('id: null'));
      });
    });
  });

  group('Outline模型 - 序列化测试', () {
    group('toMap - 序列化为Map', () {
      test('应该正确序列化所有字段', () {
        final now = DateTime(2025, 1, 30, 12, 30, 45);
        final outline = Outline(
          id: 1,
          novelUrl: 'https://example.com/novel/1',
          title: '测试大纲',
          content: '这是大纲内容',
          createdAt: now,
          updatedAt: now,
        );

        final map = outline.toMap();

        expect(map['id'], 1);
        expect(map['novel_url'], 'https://example.com/novel/1');
        expect(map['title'], '测试大纲');
        expect(map['content'], '这是大纲内容');
        expect(map['created_at'], now.millisecondsSinceEpoch);
        expect(map['updated_at'], now.millisecondsSinceEpoch);
      });

      test('应该正确序列化null id', () {
        final now = DateTime.now();
        final outline = Outline(
          novelUrl: 'https://example.com/novel/1',
          title: '测试大纲',
          content: '内容',
          createdAt: now,
          updatedAt: now,
        );

        final map = outline.toMap();

        expect(map['id'], isNull);
      });

      test('应该正确序列化DateTime为毫秒时间戳', () {
        final now = DateTime(2025, 1, 30, 12, 30, 45, 123);
        final outline = Outline(
          novelUrl: 'https://example.com/novel/1',
          title: '测试',
          content: '内容',
          createdAt: now,
          updatedAt: now,
        );

        final map = outline.toMap();

        expect(map['created_at'], now.millisecondsSinceEpoch);
        expect(map['updated_at'], now.millisecondsSinceEpoch);
      });

      test('应该正确序列化不同时间', () {
        final created = DateTime(2025, 1, 1, 10, 0, 0);
        final updated = DateTime(2025, 1, 30, 12, 30, 45);
        final outline = Outline(
          novelUrl: 'https://example.com/novel/1',
          title: '测试',
          content: '内容',
          createdAt: created,
          updatedAt: updated,
        );

        final map = outline.toMap();

        expect(map['created_at'], created.millisecondsSinceEpoch);
        expect(map['updated_at'], updated.millisecondsSinceEpoch);
        expect(map['created_at'], lessThan(map['updated_at']));
      });

      test('应该正确序列化长文本', () {
        final longContent = '内容' * 20000;
        final now = DateTime.now();
        final outline = Outline(
          novelUrl: 'https://example.com/novel/1',
          title: '长内容',
          content: longContent,
          createdAt: now,
          updatedAt: now,
        );

        final map = outline.toMap();

        expect(map['content'], longContent);
        expect((map['content'] as String).length, 40000);
      });
    });

    group('fromMap - 从Map反序列化', () {
      test('应该正确反序列化所有字段', () {
        final now = DateTime(2025, 1, 30, 12, 30, 45);
        final map = {
          'id': 1,
          'novel_url': 'https://example.com/novel/1',
          'title': '测试大纲',
          'content': '这是大纲内容',
          'created_at': now.millisecondsSinceEpoch,
          'updated_at': now.millisecondsSinceEpoch,
        };

        final outline = Outline.fromMap(map);

        expect(outline.id, 1);
        expect(outline.novelUrl, 'https://example.com/novel/1');
        expect(outline.title, '测试大纲');
        expect(outline.content, '这是大纲内容');
        expect(outline.createdAt, now);
        expect(outline.updatedAt, now);
      });

      test('应该正确处理null id', () {
        final now = DateTime.now();
        final map = {
          'id': null,
          'novel_url': 'https://example.com/novel/1',
          'title': '测试',
          'content': '内容',
          'created_at': now.millisecondsSinceEpoch,
          'updated_at': now.millisecondsSinceEpoch,
        };

        final outline = Outline.fromMap(map);

        expect(outline.id, isNull);
      });

      test('应该正确反序列化毫秒时间戳为DateTime', () {
        final created = DateTime(2025, 1, 1, 10, 0, 0);
        final updated = DateTime(2025, 1, 30, 12, 30, 45);
        final map = {
          'id': 1,
          'novel_url': 'https://example.com/novel/1',
          'title': '测试',
          'content': '内容',
          'created_at': created.millisecondsSinceEpoch,
          'updated_at': updated.millisecondsSinceEpoch,
        };

        final outline = Outline.fromMap(map);

        expect(outline.createdAt, created);
        expect(outline.updatedAt, updated);
      });

      test('应该正确反序列化空字符串', () {
        final now = DateTime.now();
        final map = {
          'id': 1,
          'novel_url': '',
          'title': '',
          'content': '',
          'created_at': now.millisecondsSinceEpoch,
          'updated_at': now.millisecondsSinceEpoch,
        };

        final outline = Outline.fromMap(map);

        expect(outline.novelUrl, '');
        expect(outline.title, '');
        expect(outline.content, '');
      });

      test('应该正确反序列化包含特殊字符的内容', () {
        final now = DateTime.now();
        final map = {
          'id': 1,
          'novel_url': 'https://example.com/novel?param=value',
          'title': '第\'一\'章"测\\试',
          'content': '第一行\n第二行\t制表符',
          'created_at': now.millisecondsSinceEpoch,
          'updated_at': now.millisecondsSinceEpoch,
        };

        final outline = Outline.fromMap(map);

        expect(outline.novelUrl, contains('?'));
        expect(outline.title, contains('"'));
        expect(outline.content, contains('\n'));
      });
    });

    group('序列化/反序列化往返测试', () {
      test('toMap -> fromMap应该保持数据完整性', () {
        final original = Outline(
          id: 1,
          novelUrl: 'https://example.com/novel/1',
          title: '测试大纲',
          content: '这是大纲内容',
          createdAt: DateTime(2025, 1, 30, 12, 30, 45),
          updatedAt: DateTime(2025, 1, 30, 12, 30, 45),
        );

        final map = original.toMap();
        final restored = Outline.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.novelUrl, original.novelUrl);
        expect(restored.title, original.title);
        expect(restored.content, original.content);
        expect(restored.createdAt, original.createdAt);
        expect(restored.updatedAt, original.updatedAt);
      });

      test('多次往返应该保持一致性', () {
        final original = Outline(
          id: 1,
          novelUrl: 'https://example.com/novel/1',
          title: '测试',
          content: '内容',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // 第一次往返
        final map1 = original.toMap();
        final restored1 = Outline.fromMap(map1);

        // 第二次往返
        final map2 = restored1.toMap();
        final restored2 = Outline.fromMap(map2);

        // 第三次往返
        final map3 = restored2.toMap();
        final restored3 = Outline.fromMap(map3);

        expect(restored3.id, original.id);
        expect(restored3.novelUrl, original.novelUrl);
        expect(restored3.title, original.title);
        expect(restored3.content, original.content);
        expect(map3['id'], map1['id']);
        expect(map3['novel_url'], map1['novel_url']);
      });

      test('往返应该保持null id', () {
        final original = Outline(
          novelUrl: 'https://example.com/novel/1',
          title: '测试',
          content: '内容',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final map = original.toMap();
        final restored = Outline.fromMap(map);

        expect(restored.id, isNull);
      });

      test('往返应该保持长文本内容', () {
        final longContent = '内容' * 20000;
        final original = Outline(
          id: 1,
          novelUrl: 'https://example.com/novel/1',
          title: '长内容',
          content: longContent,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final map = original.toMap();
        final restored = Outline.fromMap(map);

        expect(restored.content, longContent);
        expect(restored.content.length, 40000);
      });

      test('往返应该保持不同时间戳', () {
        final created = DateTime(2025, 1, 1, 10, 0, 0);
        final updated = DateTime(2025, 1, 30, 12, 30, 45);
        final original = Outline(
          id: 1,
          novelUrl: 'https://example.com/novel/1',
          title: '测试',
          content: '内容',
          createdAt: created,
          updatedAt: updated,
        );

        final map = original.toMap();
        final restored = Outline.fromMap(map);

        expect(restored.createdAt, created);
        expect(restored.updatedAt, updated);
        expect(restored.updatedAt.isAfter(restored.createdAt), isTrue);
      });
    });
  });

  group('Outline模型 - copyWith方法测试', () {
    test('copyWithout参数应该创建相同副本', () {
      final original = Outline(
        id: 1,
        novelUrl: 'https://example.com/novel/1',
        title: '测试大纲',
        content: '内容',
        createdAt: DateTime(2025, 1, 30),
        updatedAt: DateTime(2025, 1, 30),
      );

      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.novelUrl, original.novelUrl);
      expect(copy.title, original.title);
      expect(copy.content, original.content);
      expect(copy.createdAt, original.createdAt);
      expect(copy.updatedAt, original.updatedAt);
    });

    test('copyWith应该可以修改id', () {
      final original = Outline(
        id: 1,
        novelUrl: 'https://example.com/novel/1',
        title: '测试',
        content: '内容',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final copy = original.copyWith(id: 2);

      expect(copy.id, 2);
      expect(original.id, 1); // 原对象不变
      expect(copy.novelUrl, original.novelUrl);
    });

    test('copyWith应该可以修改novelUrl', () {
      final original = Outline(
        id: 1,
        novelUrl: 'https://example.com/novel/1',
        title: '测试',
        content: '内容',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final newUrl = 'https://example.com/novel/2';
      final copy = original.copyWith(novelUrl: newUrl);

      expect(copy.novelUrl, newUrl);
      expect(original.novelUrl, 'https://example.com/novel/1');
      expect(copy.title, original.title);
    });

    test('copyWith应该可以修改title', () {
      final original = Outline(
        id: 1,
        novelUrl: 'https://example.com/novel/1',
        title: '旧标题',
        content: '内容',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final copy = original.copyWith(title: '新标题');

      expect(copy.title, '新标题');
      expect(original.title, '旧标题');
      expect(copy.content, original.content);
    });

    test('copyWith应该可以修改content', () {
      final original = Outline(
        id: 1,
        novelUrl: 'https://example.com/novel/1',
        title: '测试',
        content: '旧内容',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final copy = original.copyWith(content: '新内容');

      expect(copy.content, '新内容');
      expect(original.content, '旧内容');
    });

    test('copyWith应该可以修改createdAt', () {
      final original = Outline(
        id: 1,
        novelUrl: 'https://example.com/novel/1',
        title: '测试',
        content: '内容',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 30),
      );

      final newDate = DateTime(2025, 2, 1);
      final copy = original.copyWith(createdAt: newDate);

      expect(copy.createdAt, newDate);
      expect(original.createdAt, DateTime(2025, 1, 1));
      expect(copy.updatedAt, original.updatedAt);
    });

    test('copyWith应该可以修改updatedAt', () {
      final original = Outline(
        id: 1,
        novelUrl: 'https://example.com/novel/1',
        title: '测试',
        content: '内容',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 30),
      );

      final newDate = DateTime(2025, 2, 1);
      final copy = original.copyWith(updatedAt: newDate);

      expect(copy.updatedAt, newDate);
      expect(original.updatedAt, DateTime(2025, 1, 30));
      expect(copy.createdAt, original.createdAt);
    });

    test('copyWith应该可以同时修改多个字段', () {
      final original = Outline(
        id: 1,
        novelUrl: 'https://example.com/novel/1',
        title: '旧标题',
        content: '旧内容',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 30),
      );

      final copy = original.copyWith(
        id: 2,
        title: '新标题',
        content: '新内容',
      );

      expect(copy.id, 2);
      expect(copy.title, '新标题');
      expect(copy.content, '新内容');
      expect(copy.novelUrl, original.novelUrl);
      expect(copy.createdAt, original.createdAt);
      expect(copy.updatedAt, original.updatedAt);
    });

    test('copyWith应该正确处理null参数（保持原值）', () {
      final original = Outline(
        id: 1,
        novelUrl: 'https://example.com/novel/1',
        title: '测试',
        content: '内容',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final copy = original.copyWith(
        title: null,
        content: null,
      );

      expect(copy.title, original.title);
      expect(copy.content, original.content);
    });

    test('copyWith的限制：无法将id修改为null', () {
      final original = Outline(
        id: 1,
        novelUrl: 'https://example.com/novel/1',
        title: '测试',
        content: '内容',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 注意：copyWith方法使用 ?? 运算符，无法区分"传入null"和"未传入"
      // 这是Dart可选参数的常见限制
      int? newId = null;
      final copy = original.copyWith(id: newId);

      // 由于 ?? 运算符，null会被当作"使用原值"
      expect(copy.id, 1); // 实际行为：保持原值
      expect(copy.id, original.id);
    });
  });

  group('Outline模型 - 边界情况和兼容性测试', () {
    test('应该处理超长标题', () {
      final longTitle = '标题' * 150; // 300字符
      final now = DateTime.now();
      final outline = Outline(
        novelUrl: 'https://example.com/novel/1',
        title: longTitle,
        content: '内容',
        createdAt: now,
        updatedAt: now,
      );

      expect(outline.title, longTitle);
      expect(outline.title.length, 300);

      // 验证序列化/反序列化
      final map = outline.toMap();
      final restored = Outline.fromMap(map);
      expect(restored.title, longTitle);
    });

    test('应该处理JSON格式的内容', () {
      final jsonContent = '{"title": "大纲", "chapters": [{"id": 1, "name": "第一章"}]}';
      final now = DateTime.now();
      final outline = Outline(
        novelUrl: 'https://example.com/novel/1',
        title: 'JSON大纲',
        content: jsonContent,
        createdAt: now,
        updatedAt: now,
      );

      expect(outline.content, jsonContent);

      final map = outline.toMap();
      final restored = Outline.fromMap(map);
      expect(restored.content, jsonContent);
    });

    test('应该处理Markdown格式的内容', () {
      final markdownContent = '''# 第一章 开篇

## 场景设置
- 时间：2025年
- 地点：北京

## 主要情节
这是第一章的主要内容。''';

      final now = DateTime.now();
      final outline = Outline(
        novelUrl: 'https://example.com/novel/1',
        title: 'Markdown大纲',
        content: markdownContent,
        createdAt: now,
        updatedAt: now,
      );

      expect(outline.content, contains('# 第一章'));
      expect(outline.content, contains('## 场景设置'));

      final map = outline.toMap();
      final restored = Outline.fromMap(map);
      expect(restored.content, markdownContent);
    });

    test('应该处理包含Unicode字符的内容', () {
      final unicodeContent = 'Emoji: 🎉🎊🎈\n中文: 你好世界\n日文: こんにちは\n韩文: 안녕하세요';
      final now = DateTime.now();
      final outline = Outline(
        novelUrl: 'https://example.com/novel/1',
        title: 'Unicode大纲',
        content: unicodeContent,
        createdAt: now,
        updatedAt: now,
      );

      expect(outline.content, contains('🎉'));

      final map = outline.toMap();
      final restored = Outline.fromMap(map);
      expect(restored.content, unicodeContent);
    });

    test('应该处理极短内容（单字符）', () {
      final now = DateTime.now();
      final outline = Outline(
        novelUrl: 'https://example.com/novel/1',
        title: '短',
        content: '内',
        createdAt: now,
        updatedAt: now,
      );

      expect(outline.title.length, 1);
      expect(outline.content.length, 1);

      final map = outline.toMap();
      final restored = Outline.fromMap(map);
      expect(restored.title, '短');
      expect(restored.content, '内');
    });

    test('应该正确比较两个Outline对象', () {
      final now = DateTime.now();
      final outline1 = Outline(
        id: 1,
        novelUrl: 'https://example.com/novel/1',
        title: '测试',
        content: '内容',
        createdAt: now,
        updatedAt: now,
      );

      final outline2 = Outline(
        id: 1,
        novelUrl: 'https://example.com/novel/1',
        title: '测试',
        content: '内容',
        createdAt: now,
        updatedAt: now,
      );

      final outline3 = Outline(
        id: 2,
        novelUrl: 'https://example.com/novel/2',
        title: '不同',
        content: '不同内容',
        createdAt: now,
        updatedAt: now,
      );

      expect(outline1.toString(), outline2.toString());
      expect(outline1.toString(), isNot(outline3.toString()));
    });
  });

  group('ChapterOutlineDraft模型测试', () {
    group('构造函数和字段', () {
      test('应该正确创建ChapterOutlineDraft实例', () {
        final draft = ChapterOutlineDraft(
          title: '第一章',
          content: '这是第一章的细纲内容',
          keyPoints: ['要点1', '要点2', '要点3'],
        );

        expect(draft.title, '第一章');
        expect(draft.content, '这是第一章的细纲内容');
        expect(draft.keyPoints.length, 3);
        expect(draft.keyPoints[0], '要点1');
      });

      test('应该支持空keyPoints列表', () {
        final draft = ChapterOutlineDraft(
          title: '第一章',
          content: '内容',
          keyPoints: [],
        );

        expect(draft.keyPoints, isEmpty);
      });

      test('应该支持单个keyPoint', () {
        final draft = ChapterOutlineDraft(
          title: '第一章',
          content: '内容',
          keyPoints: ['唯一要点'],
        );

        expect(draft.keyPoints.length, 1);
        expect(draft.keyPoints[0], '唯一要点');
      });

      test('应该支持长标题和内容', () {
        final longTitle = '标题' * 50;
        final longContent = '内容' * 20000;
        final draft = ChapterOutlineDraft(
          title: longTitle,
          content: longContent,
          keyPoints: ['要点'],
        );

        expect(draft.title, longTitle);
        expect(draft.content, longContent);
        expect(draft.content.length, 40000);
      });

      test('应该支持特殊字符', () {
        final draft = ChapterOutlineDraft(
          title: '第\'一\'章"测\\试',
          content: '包含\n换行符\t制表符\n的内容',
          keyPoints: ['要点\n换行', '要点\t制表', '要点"引号"'],
        );

        expect(draft.title, contains('"'));
        expect(draft.content, contains('\n'));
        expect(draft.keyPoints[0], contains('\n'));
        expect(draft.keyPoints[2], contains('"'));
      });
    });

    group('copyWith方法', () {
      test('copyWithout参数应该创建相同副本', () {
        final original = ChapterOutlineDraft(
          title: '第一章',
          content: '内容',
          keyPoints: ['要点1', '要点2'],
        );

        final copy = original.copyWith();

        expect(copy.title, original.title);
        expect(copy.content, original.content);
        expect(copy.keyPoints, original.keyPoints);
      });

      test('copyWith应该可以修改title', () {
        final original = ChapterOutlineDraft(
          title: '旧标题',
          content: '内容',
          keyPoints: ['要点'],
        );

        final copy = original.copyWith(title: '新标题');

        expect(copy.title, '新标题');
        expect(original.title, '旧标题');
        expect(copy.content, original.content);
      });

      test('copyWith应该可以修改content', () {
        final original = ChapterOutlineDraft(
          title: '标题',
          content: '旧内容',
          keyPoints: ['要点'],
        );

        final copy = original.copyWith(content: '新内容');

        expect(copy.content, '新内容');
        expect(original.content, '旧内容');
      });

      test('copyWith应该可以修改keyPoints', () {
        final original = ChapterOutlineDraft(
          title: '标题',
          content: '内容',
          keyPoints: ['要点1', '要点2'],
        );

        final newKeyPoints = ['新要点1', '新要点2', '新要点3'];
        final copy = original.copyWith(keyPoints: newKeyPoints);

        expect(copy.keyPoints, newKeyPoints);
        expect(copy.keyPoints.length, 3);
        expect(original.keyPoints.length, 2);
      });

      test('copyWith应该可以同时修改多个字段', () {
        final original = ChapterOutlineDraft(
          title: '旧标题',
          content: '旧内容',
          keyPoints: ['旧要点'],
        );

        final copy = original.copyWith(
          title: '新标题',
          content: '新内容',
          keyPoints: ['新要点'],
        );

        expect(copy.title, '新标题');
        expect(copy.content, '新内容');
        expect(copy.keyPoints, ['新要点']);
        expect(original.title, '旧标题');
        expect(original.content, '旧内容');
      });

      test('copyWith应该正确处理null参数（保持原值）', () {
        final original = ChapterOutlineDraft(
          title: '标题',
          content: '内容',
          keyPoints: ['要点'],
        );

        final copy = original.copyWith(
          title: null,
          content: null,
          keyPoints: null,
        );

        expect(copy.title, original.title);
        expect(copy.content, original.content);
        expect(copy.keyPoints, original.keyPoints);
      });

      test('copyWith修改keyPoints应该不影响原列表', () {
        final original = ChapterOutlineDraft(
          title: '标题',
          content: '内容',
          keyPoints: ['要点1', '要点2'],
        );

        final newKeyPoints = ['新要点1', '新要点2'];
        final copy = original.copyWith(keyPoints: newKeyPoints);

        // 修改新列表
        newKeyPoints.add('新要点3');

        expect(copy.keyPoints.length, 3);
        expect(original.keyPoints.length, 2); // 原列表不受影响
      });
    });

    group('toString方法', () {
      test('toString应该包含title和keyPoints', () {
        final draft = ChapterOutlineDraft(
          title: '第一章 命运的起点',
          content: '这是第一章的详细内容描述',
          keyPoints: ['要点1', '要点2', '要点3'],
        );

        final str = draft.toString();

        expect(str, contains('title: 第一章 命运的起点'));
        expect(str, contains('keyPoints:'));
      });

      test('toString应该截取过长的content', () {
        final longContent = '内容' * 100; // 400字符
        final draft = ChapterOutlineDraft(
          title: '测试',
          content: longContent,
          keyPoints: [],
        );

        final str = draft.toString();

        expect(str, contains('...')); // 应该被截断
        expect(str, isNot(contains(longContent))); // 不应该包含完整内容
      });

      test('toString应该显示短内容', () {
        final shortContent = '短内容';
        final draft = ChapterOutlineDraft(
          title: '测试',
          content: shortContent,
          keyPoints: [],
        );

        final str = draft.toString();

        // ChapterOutlineDraft的toString总是添加"..."
        expect(str, contains(shortContent.substring(0, 3)));
        expect(str, contains('...'));
      });

      test('toString应该正确显示空keyPoints', () {
        final draft = ChapterOutlineDraft(
          title: '测试',
          content: '内容',
          keyPoints: [],
        );

        final str = draft.toString();

        expect(str, contains('keyPoints: []'));
      });

      test('toString应该正确显示多个keyPoints', () {
        final draft = ChapterOutlineDraft(
          title: '测试',
          content: '内容',
          keyPoints: ['要点1', '要点2', '要点3', '要点4'],
        );

        final str = draft.toString();

        expect(str, contains('要点1'));
        expect(str, contains('要点2'));
        expect(str, contains('要点3'));
        expect(str, contains('要点4'));
      });
    });

    group('边界情况和异常处理', () {
      test('应该处理空字符串', () {
        final draft = ChapterOutlineDraft(
          title: '',
          content: '',
          keyPoints: [],
        );

        expect(draft.title, '');
        expect(draft.content, '');
        expect(draft.keyPoints, isEmpty);
      });

      test('应该处理包含换行符的keyPoint', () {
        final draft = ChapterOutlineDraft(
          title: '测试',
          content: '内容',
          keyPoints: ['第一行\n第二行', '单独一行'],
        );

        expect(draft.keyPoints[0], contains('\n'));
        expect(draft.keyPoints.length, 2);
      });

      test('应该处理大量keyPoints', () {
        final manyKeyPoints = List.generate(100, (i) => '要点$i');
        final draft = ChapterOutlineDraft(
          title: '测试',
          content: '内容',
          keyPoints: manyKeyPoints,
        );

        expect(draft.keyPoints.length, 100);
        expect(draft.keyPoints[0], '要点0');
        expect(draft.keyPoints[99], '要点99');
      });

      test('应该处理包含特殊字符的keyPoint', () {
        final draft = ChapterOutlineDraft(
          title: '测试',
          content: '内容',
          keyPoints: [
            '包含"引号"',
            '包含\'单引号\'',
            '包含\\反斜杠',
            '包含/斜杠',
            '包含:冒号',
          ],
        );

        expect(draft.keyPoints[0], contains('"'));
        expect(draft.keyPoints[1], contains('\''));
        expect(draft.keyPoints[2], contains('\\'));
        expect(draft.keyPoints[3], contains('/'));
        expect(draft.keyPoints[4], contains(':'));
      });
    });

    group('使用场景测试', () {
      test('应该正确表示章节细纲草稿', () {
        final draft = ChapterOutlineDraft(
          title: '第1章 命运的起点',
          content: '''**场景设置**: 主角出生的偏远小村庄

**关键事件**:
- 主角觉醒特殊能力
- 遇到神秘导师
- 开始冒险之旅

**重点描写**:
- 人物对话和心理活动
- 环境描写和氛围营造''',
          keyPoints: [
            '承接前文',
            '引入新元素',
            '展现角色成长',
            '设置悬念',
          ],
        );

        expect(draft.title, startsWith('第1章'));
        expect(draft.content, contains('场景设置'));
        expect(draft.content, contains('关键事件'));
        expect(draft.keyPoints.length, 4);
      });

      test('应该支持修订版本的细纲', () {
        final originalDraft = ChapterOutlineDraft(
          title: '第1章',
          content: '原始内容',
          keyPoints: ['原始要点'],
        );

        final revisedDraft = originalDraft.copyWith(
          title: '第1章 (修订版)',
          content: '修改后的内容，根据反馈优化',
          keyPoints: ['优化要点1', '优化要点2'],
        );

        expect(revisedDraft.title, contains('修订版'));
        expect(revisedDraft.content, contains('修改'));
        expect(revisedDraft.keyPoints.length, 2);
        expect(originalDraft.title, '第1章'); // 原草稿不变
      });

      test('应该支持AI生成的细纲结构', () {
        final aiDraft = ChapterOutlineDraft(
          title: '第2章 未知的召唤',
          content: 'AI生成的详细细纲...',
          keyPoints: [
            '根据反馈优化',
            '增强戏剧冲突',
            '深化角色刻画',
            '改进节奏把控',
            '提升吸引力',
          ],
        );

        expect(aiDraft.title, contains('第2章'));
        expect(aiDraft.keyPoints.length, 5);
        expect(aiDraft.keyPoints, contains('增强戏剧冲突'));
      });
    });
  });
}
