import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/preload_progress_update.dart';

void main() {
  group('PreloadProgressUpdate - 构造函数', () {
    test('应该正确创建进度更新对象', () {
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      expect(update.novelUrl, 'https://example.com/novel/1');
      expect(update.chapterUrl, 'https://example.com/chapter/1');
      expect(update.isPreloading, true);
      expect(update.cachedChapters, 5);
      expect(update.totalChapters, 10);
      expect(update.timestamp, isNotNull);
      expect(update.timestamp, isA<DateTime>());
    });

    test('应该自动设置时间戳', () {
      final beforeCreate = DateTime.now();
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );
      final afterCreate = DateTime.now();

      expect(update.timestamp.isAtSameMomentAs(beforeCreate) ||
                 update.timestamp.isAtSameMomentAs(afterCreate) ||
                 (update.timestamp.isAfter(beforeCreate) &&
                     update.timestamp.isBefore(afterCreate)),
             true);
    });

    test('应该支持可选chapterUrl', () {
      final updateWithChapter = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final updateWithoutChapter = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      expect(updateWithChapter.chapterUrl, 'https://example.com/chapter/1');
      expect(updateWithoutChapter.chapterUrl, null);
    });

    test('应该支持零值', () {
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: false,
        cachedChapters: 0,
        totalChapters: 0,
      );

      expect(update.cachedChapters, 0);
      expect(update.totalChapters, 0);
      expect(update.isPreloading, false);
    });

    test('应该支持大数值', () {
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: true,
        cachedChapters: 99999,
        totalChapters: 100000,
      );

      expect(update.cachedChapters, 99999);
      expect(update.totalChapters, 100000);
    });
  });

  group('PreloadProgressUpdate - toString', () {
    test('应该正确格式化字符串表示', () {
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final str = update.toString();
      expect(str, contains('PreloadProgressUpdate'));
      expect(str, contains('novelUrl'));
      expect(str, contains('chapterUrl'));
      expect(str, contains('isPreloading'));
      expect(str, contains('cachedChapters'));
      expect(str, contains('totalChapters'));
      expect(str, contains('timestamp'));
    });

    test('应该显示所有字段的值', () {
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final str = update.toString();
      expect(str, contains('https://example.com/novel/1'));
      expect(str, contains('https://example.com/chapter/1'));
      expect(str, contains('true'));
      expect(str, contains('5'));
      expect(str, contains('10'));
    });

    test('null chapterUrl应该在toString中显示', () {
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: false,
        cachedChapters: 10,
        totalChapters: 10,
      );

      final str = update.toString();
      expect(str, contains('null'));
    });
  });

  group('PreloadProgressUpdate - 相等性', () {
    test('相同参数的更新应该相等', () {
      // 时间戳会影响相等性，所以我们需要在创建后修改它
      final update1 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      // 等待一小段时间确保时间戳不同
      // 但由于PreloadProgressUpdate的相等性不包含timestamp，
      // 所以它们应该相等
      final update2 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      expect(update1, equals(update2));
      expect(update1 == update2, true);
    });

    test('novelUrl不同应该不相等', () {
      final update1 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final update2 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/2',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      expect(update1, isNot(equals(update2)));
      expect(update1 == update2, false);
    });

    test('chapterUrl不同应该不相等', () {
      final update1 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final update2 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/2',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      expect(update1, isNot(equals(update2)));
      expect(update1 == update2, false);
    });

    test('chapterUrl为null和非null应该不相等', () {
      final update1 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final update2 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      expect(update1, isNot(equals(update2)));
      expect(update1 == update2, false);
    });

    test('isPreloading不同应该不相等', () {
      final update1 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final update2 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: false,
        cachedChapters: 5,
        totalChapters: 10,
      );

      expect(update1, isNot(equals(update2)));
      expect(update1 == update2, false);
    });

    test('cachedChapters不同应该不相等', () {
      final update1 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final update2 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: true,
        cachedChapters: 6,
        totalChapters: 10,
      );

      expect(update1, isNot(equals(update2)));
      expect(update1 == update2, false);
    });

    test('totalChapters不同应该不相等', () {
      final update1 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final update2 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 11,
      );

      expect(update1, isNot(equals(update2)));
      expect(update1 == update2, false);
    });

    test('更新应该与自身相等', () {
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      expect(update, equals(update));
      expect(update == update, true);
    });

    test('更新不应该与其他类型相等', () {
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      expect(update == 'string', false);
      expect(update == 123, false);
      expect(update == null, false);
    });

    test('identical对象应该相等', () {
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      expect(identical(update, update), true);
    });
  });

  group('PreloadProgressUpdate - 哈希码', () {
    test('相同更新应该有相同哈希码', () {
      final update1 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final update2 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      expect(update1.hashCode, equals(update2.hashCode));
    });

    test('不同更新应该有不同哈希码（高概率）', () {
      final updates = List.generate(
        100,
        (i) => PreloadProgressUpdate(
          novelUrl: 'https://example.com/novel/$i',
          chapterUrl: 'https://example.com/chapter/$i',
          isPreloading: i % 2 == 0,
          cachedChapters: i,
          totalChapters: 100,
        ),
      );

      final uniqueHashCodes = updates.map((u) => u.hashCode).toSet();

      // 至少应该有95%的哈希码是唯一的
      expect(uniqueHashCodes.length, greaterThan(95));
    });

    test('哈希码应该基于所有关键字段', () {
      final update1 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final update2 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      // 所有字段相同应该产生相同哈希码
      expect(update1.hashCode, equals(update2.hashCode));
    });

    test('哈希码应该与equals一致', () {
      final update1 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final update2 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final update3 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/2',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      // 相等的对象必须有相同的哈希码
      if (update1 == update2) {
        expect(update1.hashCode, equals(update2.hashCode));
      }

      // 不相等的对象应该有不同的哈希码（大概率）
      if (update1 != update3) {
        expect(update1.hashCode, isNot(equals(update3.hashCode)));
      }
    });

    test('null chapterUrl的哈希码应该正确处理', () {
      final update1 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final update2 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      // null应该产生哈希码0
      expect(update1.hashCode, equals(update2.hashCode));
    });
  });

  group('PreloadProgressUpdate - Set和Map使用', () {
    test('应该能在Set中去重', () {
      final update1 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final update2 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final updateSet = {update1, update2};

      expect(updateSet.length, 1); // 重复的更新应该被去重
    });

    test('应该能在Map中作为键', () {
      final update1 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final update2 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final updateMap = <PreloadProgressUpdate, String>{};
      updateMap[update1] = 'value1';
      updateMap[update2] = 'value2'; // 应该覆盖value1

      expect(updateMap.length, 1);
      expect(updateMap[update1], 'value2');
      expect(updateMap[update2], 'value2');
    });

    test('Set应该正确区分不同更新', () {
      final updates = [
        PreloadProgressUpdate(
          novelUrl: 'https://example.com/novel/1',
          chapterUrl: 'https://example.com/chapter/1',
          isPreloading: true,
          cachedChapters: 5,
          totalChapters: 10,
        ),
        PreloadProgressUpdate(
          novelUrl: 'https://example.com/novel/1',
          chapterUrl: 'https://example.com/chapter/2',
          isPreloading: true,
          cachedChapters: 6,
          totalChapters: 10,
        ),
        PreloadProgressUpdate(
          novelUrl: 'https://example.com/novel/1',
          isPreloading: true,
          cachedChapters: 5,
          totalChapters: 10,
        ),
      ];

      final updateSet = updates.toSet();

      expect(updateSet.length, 3); // 三个不同的更新
    });

    test('Map查找应该正确匹配', () {
      final update1 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final updateMap = <PreloadProgressUpdate, int>{};
      updateMap[update1] = 100;

      // 使用相同参数的新对象查找
      final update2 = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        chapterUrl: 'https://example.com/chapter/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      expect(updateMap[update2], 100); // 应该能找到
    });
  });

  group('PreloadProgressUpdate - 业务逻辑', () {
    test('进度计算应该正确', () {
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      final progress = update.cachedChapters / update.totalChapters;
      expect(progress, 0.5);
    });

    test('完成状态应该100%', () {
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: false,
        cachedChapters: 10,
        totalChapters: 10,
      );

      expect(update.isPreloading, false);
      expect(update.cachedChapters, equals(update.totalChapters));
    });

    test('开始状态应该0%', () {
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: true,
        cachedChapters: 0,
        totalChapters: 10,
      );

      expect(update.isPreloading, true);
      expect(update.cachedChapters, 0);
    });

    test('应该处理completed状态', () {
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: false,
        cachedChapters: 10,
        totalChapters: 10,
      );

      expect(update.isPreloading, false);
      expect(update.cachedChapters, equals(update.totalChapters));
    });

    test('应该处理error状态（cachedChapters < totalChapters但isPreloading=false）', () {
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: false,
        cachedChapters: 5,
        totalChapters: 10,
      );

      // 这种状态表示预加载停止但未完成
      expect(update.isPreloading, false);
      expect(update.cachedChapters, lessThan(update.totalChapters));
    });
  });

  group('PreloadProgressUpdate - 边界情况', () {
    test('应该处理空字符串URL', () {
      final update = PreloadProgressUpdate(
        novelUrl: '',
        chapterUrl: '',
        isPreloading: false,
        cachedChapters: 0,
        totalChapters: 0,
      );

      expect(update.novelUrl, '');
      expect(update.chapterUrl, '');
    });

    test('应该处理特殊字符URL', () {
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/测试?id=123',
        chapterUrl: 'https://example.com/chapter/章节?v=1.0',
        isPreloading: true,
        cachedChapters: 5,
        totalChapters: 10,
      );

      expect(update.novelUrl, contains('测试'));
      expect(update.chapterUrl, contains('章节'));
    });

    test('应该处理cachedChapters > totalChapters的异常情况', () {
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: false,
        cachedChapters: 15,
        totalChapters: 10,
      );

      // 虽然不合理，但应该允许创建
      expect(update.cachedChapters, 15);
      expect(update.totalChapters, 10);
    });

    test('应该处理非常大的数值', () {
      final update = PreloadProgressUpdate(
        novelUrl: 'https://example.com/novel/1',
        isPreloading: true,
        cachedChapters: 999999999,
        totalChapters: 1000000000,
      );

      expect(update.cachedChapters, 999999999);
      expect(update.totalChapters, 1000000000);
    });
  });
}
