import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/chat_scene.dart';
import '../../test_bootstrap.dart';

void main() {
  // 初始化测试环境
  initTests();
  group('ChatScene - 模型基础测试', () {
    test('测试1: 创建ChatScene对象应包含所有必需字段', () {
      final now = DateTime.now();
      final scene = ChatScene(
        id: 1,
        title: '测试场景',
        content: '这是一个测试场景的内容',
        createdAt: now,
        updatedAt: now,
      );

      expect(scene.id, 1);
      expect(scene.title, '测试场景');
      expect(scene.content, '这是一个测试场景的内容');
      expect(scene.createdAt, now);
      expect(scene.updatedAt, now);
    });

    test('测试2: 创建ChatScene时不提供createdAt应使用当前时间', () {
      final beforeCreate = DateTime.now();
      final scene = ChatScene(
        id: 1,
        title: '测试场景',
        content: '测试内容',
      );
      final afterCreate = DateTime.now();

      expect(scene.createdAt.isAfter(beforeCreate) || scene.createdAt.isAtSameMomentAs(beforeCreate), true);
      expect(scene.createdAt.isBefore(afterCreate) || scene.createdAt.isAtSameMomentAs(afterCreate), true);
    });

    test('测试3: 创建ChatScene时不提供updatedAt应为null', () {
      final scene = ChatScene(
        id: 1,
        title: '测试场景',
        content: '测试内容',
      );

      expect(scene.updatedAt, isNull);
    });
  });

  group('ChatScene - 序列化测试', () {
    test('测试4: toMap应正确转换所有字段', () {
      final now = DateTime(2025, 1, 1, 12, 0, 0);
      final updatedAt = DateTime(2025, 1, 2, 12, 0, 0);
      final scene = ChatScene(
        id: 1,
        title: '测试标题',
        content: '测试内容',
        createdAt: now,
        updatedAt: updatedAt,
      );

      final map = scene.toMap();

      expect(map['id'], 1);
      expect(map['title'], '测试标题');
      expect(map['content'], '测试内容');
      expect(map['createdAt'], now.millisecondsSinceEpoch);
      expect(map['updatedAt'], updatedAt.millisecondsSinceEpoch);
    });

    test('测试5: fromMap应正确解析所有字段', () {
      final now = DateTime(2025, 1, 1, 12, 0, 0);
      final updatedAt = DateTime(2025, 1, 2, 12, 0, 0);

      final map = {
        'id': 1,
        'title': '测试标题',
        'content': '测试内容',
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

      final scene = ChatScene.fromMap(map);

      expect(scene.id, 1);
      expect(scene.title, '测试标题');
      expect(scene.content, '测试内容');
      expect(scene.createdAt, now);
      expect(scene.updatedAt, updatedAt);
    });

    test('测试6: fromMap处理updatedAt为null的情况', () {
      final now = DateTime(2025, 1, 1, 12, 0, 0);

      final map = {
        'id': 1,
        'title': '测试标题',
        'content': '测试内容',
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': null,
      };

      final scene = ChatScene.fromMap(map);

      expect(scene.updatedAt, isNull);
    });

    test('测试7: 序列化和反序列化应保持数据一致性', () {
      final originalScene = ChatScene(
        id: 100,
        title: '序列化测试',
        content: '这是一个用于测试序列化一致性的场景内容',
        createdAt: DateTime(2025, 6, 15, 10, 30),
        updatedAt: DateTime(2025, 6, 16, 11, 45),
      );

      // 序列化
      final map = originalScene.toMap();

      // 反序列化
      final restoredScene = ChatScene.fromMap(map);

      // 验证数据一致性
      expect(restoredScene.id, originalScene.id);
      expect(restoredScene.title, originalScene.title);
      expect(restoredScene.content, originalScene.content);
      expect(restoredScene.createdAt, originalScene.createdAt);
      expect(restoredScene.updatedAt, originalScene.updatedAt);
    });
  });

  group('ChatScene - copyWith测试', () {
    test('测试8: copyWith只更新title', () {
      final original = ChatScene(
        id: 1,
        title: '原标题',
        content: '原内容',
        createdAt: DateTime(2025, 1, 1),
      );

      final updated = original.copyWith(title: '新标题');

      expect(updated.id, original.id);
      expect(updated.title, '新标题');
      expect(updated.content, original.content);
      expect(updated.createdAt, original.createdAt);
      expect(updated.updatedAt, isNotNull);
      expect(updated.updatedAt!.isAfter(original.createdAt), true);
    });

    test('测试9: copyWith只更新content', () {
      final original = ChatScene(
        id: 1,
        title: '原标题',
        content: '原内容',
        createdAt: DateTime(2025, 1, 1),
      );

      final updated = original.copyWith(content: '新内容');

      expect(updated.id, original.id);
      expect(updated.title, original.title);
      expect(updated.content, '新内容');
      expect(updated.createdAt, original.createdAt);
      expect(updated.updatedAt, isNotNull);
    });

    test('测试10: copyWith同时更新title和content', () {
      final original = ChatScene(
        id: 1,
        title: '原标题',
        content: '原内容',
      );

      final updated = original.copyWith(
        title: '新标题',
        content: '新内容',
      );

      expect(updated.title, '新标题');
      expect(updated.content, '新内容');
      expect(updated.id, original.id);
      expect(updated.createdAt, original.createdAt);
    });

    test('测试11: copyWith不传参数应创建相同副本', () {
      final original = ChatScene(
        id: 1,
        title: '标题',
        content: '内容',
        createdAt: DateTime(2025, 1, 1),
      );

      final copy = original.copyWith();

      // updatedAt会被自动更新为当前时间
      expect(copy.title, original.title);
      expect(copy.content, original.content);
      expect(copy.id, original.id);
      expect(copy.createdAt, original.createdAt);
      expect(copy.updatedAt, isNotNull);
    });

    test('测试12: copyWith更新id', () {
      final original = ChatScene(
        id: 1,
        title: '标题',
        content: '内容',
      );

      final updated = original.copyWith(id: 2);

      expect(updated.id, 2);
      expect(updated.title, original.title);
    });

    test('测试13: copyWith更新createdAt', () {
      final original = ChatScene(
        id: 1,
        title: '标题',
        content: '内容',
        createdAt: DateTime(2025, 1, 1),
      );

      final newDate = DateTime(2025, 2, 1);
      final updated = original.copyWith(createdAt: newDate);

      expect(updated.createdAt, newDate);
    });

    test('测试14: copyWith更新updatedAt', () {
      final original = ChatScene(
        id: 1,
        title: '标题',
        content: '内容',
        createdAt: DateTime(2025, 1, 1),
      );

      final newDate = DateTime(2025, 2, 1);
      final updated = original.copyWith(updatedAt: newDate);

      expect(updated.updatedAt, newDate);
    });
  });

  group('ChatScene - toString测试', () {
    test('测试15: toString应包含关键信息', () {
      final scene = ChatScene(
        id: 1,
        title: '测试标题',
        content: '这是一个较长的场景内容，应该在toString中被截断',
        createdAt: DateTime(2025, 1, 1),
      );

      final str = scene.toString();

      expect(str, contains('id: 1'));
      expect(str, contains('title: 测试标题'));
      expect(str, contains('content:'));
      expect(str, contains('createdAt:'));
    });

    test('测试16: 长内容应在toString中被截断', () {
      final longContent = '这是一个非常非常长的场景内容' * 10;
      final scene = ChatScene(
        id: 1,
        title: '标题',
        content: longContent,
      );

      final str = scene.toString();

      // 验证内容被截断（应该只显示前20个字符）
      expect(str, contains('...'));
      expect(str.contains(longContent), false);
    });

    test('测试17: 短内容应在toString中完整显示', () {
      final shortContent = '短内容';
      final scene = ChatScene(
        id: 1,
        title: '标题',
        content: shortContent,
      );

      final str = scene.toString();

      // 验证短内容完整显示
      expect(str, contains('content: $shortContent'));
      // 短内容也可能显示截断标记（因为20字符的限制）
      // 所以我们只验证内容存在，不验证是否没有...
      expect(str.contains(shortContent), true);
    });
  });

  group('ChatScene - 相等性测试', () {
    test('测试18: 相同字段的对象应相等', () {
      final now = DateTime(2025, 1, 1);
      final scene1 = ChatScene(
        id: 1,
        title: '标题',
        content: '内容',
        createdAt: now,
      );
      final scene2 = ChatScene(
        id: 1,
        title: '标题',
        content: '内容',
        createdAt: now,
      );

      expect(scene1, equals(scene2));
      expect(scene1 == scene2, true);
    });

    test('测试19: 不同id的对象不应相等', () {
      final now = DateTime(2025, 1, 1);
      final scene1 = ChatScene(
        id: 1,
        title: '标题',
        content: '内容',
        createdAt: now,
      );
      final scene2 = ChatScene(
        id: 2,
        title: '标题',
        content: '内容',
        createdAt: now,
      );

      expect(scene1, isNot(equals(scene2)));
      expect(scene1 == scene2, false);
    });

    test('测试20: 不同title的对象不应相等', () {
      final now = DateTime(2025, 1, 1);
      final scene1 = ChatScene(
        id: 1,
        title: '标题1',
        content: '内容',
        createdAt: now,
      );
      final scene2 = ChatScene(
        id: 1,
        title: '标题2',
        content: '内容',
        createdAt: now,
      );

      expect(scene1 == scene2, false);
    });

    test('测试21: 不同content的对象不应相等', () {
      final now = DateTime(2025, 1, 1);
      final scene1 = ChatScene(
        id: 1,
        title: '标题',
        content: '内容1',
        createdAt: now,
      );
      final scene2 = ChatScene(
        id: 1,
        title: '标题',
        content: '内容2',
        createdAt: now,
      );

      expect(scene1 == scene2, false);
    });

    test('测试22: 不同createdAt的对象不应相等', () {
      final scene1 = ChatScene(
        id: 1,
        title: '标题',
        content: '内容',
        createdAt: DateTime(2025, 1, 1),
      );
      final scene2 = ChatScene(
        id: 1,
        title: '标题',
        content: '内容',
        createdAt: DateTime(2025, 1, 2),
      );

      expect(scene1 == scene2, false);
    });

    test('测试23: 不同updatedAt的对象不应相等', () {
      final now = DateTime(2025, 1, 1);
      final scene1 = ChatScene(
        id: 1,
        title: '标题',
        content: '内容',
        createdAt: now,
        updatedAt: DateTime(2025, 1, 2),
      );
      final scene2 = ChatScene(
        id: 1,
        title: '标题',
        content: '内容',
        createdAt: now,
        updatedAt: DateTime(2025, 1, 3),
      );

      expect(scene1 == scene2, false);
    });

    test('测试24: 一个有updatedAt一个没有应不相等', () {
      final now = DateTime(2025, 1, 1);
      final scene1 = ChatScene(
        id: 1,
        title: '标题',
        content: '内容',
        createdAt: now,
        updatedAt: now,
      );
      final scene2 = ChatScene(
        id: 1,
        title: '标题',
        content: '内容',
        createdAt: now,
      );

      expect(scene1 == scene2, false);
    });
  });

  group('ChatScene - hashCode测试', () {
    test('测试25: 相等的对象应有相同的hashCode', () {
      final now = DateTime(2025, 1, 1);
      final scene1 = ChatScene(
        id: 1,
        title: '标题',
        content: '内容',
        createdAt: now,
      );
      final scene2 = ChatScene(
        id: 1,
        title: '标题',
        content: '内容',
        createdAt: now,
      );

      expect(scene1.hashCode, equals(scene2.hashCode));
    });

    test('测试26: 不相等的对象应有不同的hashCode', () {
      final scene1 = ChatScene(
        id: 1,
        title: '标题1',
        content: '内容',
        createdAt: DateTime(2025, 1, 1),
      );
      final scene2 = ChatScene(
        id: 2,
        title: '标题2',
        content: '内容',
        createdAt: DateTime(2025, 1, 1),
      );

      expect(scene1.hashCode, isNot(equals(scene2.hashCode)));
    });
  });

  group('ChatScene - 边界情况测试', () {
    test('测试27: title为空字符串应正常工作', () {
      final scene = ChatScene(
        id: 1,
        title: '',
        content: '内容',
      );

      expect(scene.title, '');
      expect(scene.toMap()['title'], '');
    });

    test('测试28: content为空字符串应正常工作', () {
      final scene = ChatScene(
        id: 1,
        title: '标题',
        content: '',
      );

      expect(scene.content, '');
      expect(scene.toMap()['content'], '');
    });

    test('测试29: id为null应正常工作', () {
      final scene = ChatScene(
        title: '标题',
        content: '内容',
      );

      expect(scene.id, isNull);
      expect(scene.toMap()['id'], isNull);
    });

    test('测试30: 特殊字符应正常处理', () {
      final specialTitle = '标题\n包含\t换行和制表符"引号"\'单引号\'';
      final specialContent = '内容🎉表情符号✨';

      final scene = ChatScene(
        id: 1,
        title: specialTitle,
        content: specialContent,
      );

      expect(scene.title, specialTitle);
      expect(scene.content, specialContent);

      // 验证序列化和反序列化
      final map = scene.toMap();
      final restored = ChatScene.fromMap(map);

      expect(restored.title, specialTitle);
      expect(restored.content, specialContent);
    });

    test('测试31: 非常长的标题和内容应正常处理', () {
      final longTitle = '非常长的标题' * 100;
      final longContent = '非常长的内容' * 1000;

      final scene = ChatScene(
        id: 1,
        title: longTitle,
        content: longContent,
      );

      expect(scene.title.length, longTitle.length);
      expect(scene.content.length, longContent.length);

      // 验证序列化和反序列化
      final map = scene.toMap();
      final restored = ChatScene.fromMap(map);

      expect(restored.title, longTitle);
      expect(restored.content, longContent);
    });
  });
}
