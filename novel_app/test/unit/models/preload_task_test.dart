import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/preload_task.dart';

void main() {
  group('PreloadTask - 构造函数', () {
    test('应该正确创建任务对象', () {
      final task = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      expect(task.chapterUrl, 'https://example.com/chapter/1');
      expect(task.novelUrl, 'https://example.com/novel/1');
      expect(task.novelTitle, '测试小说');
      expect(task.chapterIndex, 0);
      expect(task.createdAt, isNotNull);
      expect(task.createdAt, isA<DateTime>());
    });

    test('应该自动设置创建时间', () {
      final beforeCreate = DateTime.now();
      final task = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );
      final afterCreate = DateTime.now();

      expect(task.createdAt.isAtSameMomentAs(beforeCreate) ||
                 task.createdAt.isAtSameMomentAs(afterCreate) ||
                 (task.createdAt.isAfter(beforeCreate) &&
                     task.createdAt.isBefore(afterCreate)),
             true);
    });

    test('应该支持负数章节索引', () {
      final task = PreloadTask(
        chapterUrl: 'https://example.com/chapter/-1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: -1,
      );

      expect(task.chapterIndex, -1);
    });

    test('应该支持大章节索引', () {
      final task = PreloadTask(
        chapterUrl: 'https://example.com/chapter/9999',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 9999,
      );

      expect(task.chapterIndex, 9999);
    });
  });

  group('PreloadTask - toString', () {
    test('应该正确格式化字符串表示', () {
      final task = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      final str = task.toString();
      expect(str, contains('测试小说'));
      expect(str, contains('第'));
      expect(str, contains('章'));
      expect(str, contains('1')); // chapterIndex + 1
    });

    test('应该显示正确的章节编号（从1开始）', () {
      final task1 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/0',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      final task2 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/99',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 99,
      );

      expect(task1.toString(), contains('第1章'));
      expect(task2.toString(), contains('第100章'));
    });
  });

  group('PreloadTask - 相等性', () {
    test('相同参数的任务应该相等', () {
      final task1 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      final task2 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      expect(task1, equals(task2));
      expect(task1 == task2, true);
    });

    test('chapterUrl不同应该不相等', () {
      final task1 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      final task2 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/2',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 1,
      );

      expect(task1, isNot(equals(task2)));
      expect(task1 == task2, false);
    });

    test('novelUrl不同应该不相等', () {
      final task1 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      final task2 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/2',
        novelTitle: '其他小说',
        chapterIndex: 0,
      );

      expect(task1, isNot(equals(task2)));
      expect(task1 == task2, false);
    });

    test('相同chapterUrl和novelUrl但其他参数不同也应该相等', () {
      final task1 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      final task2 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '不同标题', // 标题不同
        chapterIndex: 99, // 索引不同
      );

      // 相等性只基于chapterUrl和novelUrl
      expect(task1, equals(task2));
    });

    test('任务应该与自身相等', () {
      final task = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      expect(task, equals(task));
      expect(task == task, true);
    });

    test('任务不应该与其他类型相等', () {
      final task = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      expect(task == 'string', false);
      expect(task == 123, false);
      expect(task == null, false);
    });

    test('identical对象应该相等', () {
      final task = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      expect(identical(task, task), true);
    });
  });

  group('PreloadTask - 哈希码', () {
    test('相同任务应该有相同哈希码', () {
      final task1 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      final task2 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      expect(task1.hashCode, equals(task2.hashCode));
    });

    test('不同任务应该有不同哈希码（高概率）', () {
      final tasks = List.generate(
        100,
        (i) => PreloadTask(
          chapterUrl: 'https://example.com/chapter/$i',
          novelUrl: 'https://example.com/novel/1',
          novelTitle: '测试小说',
          chapterIndex: i,
        ),
      );

      final uniqueHashCodes = tasks.map((t) => t.hashCode).toSet();

      // 至少应该有95%的哈希码是唯一的
      expect(uniqueHashCodes.length, greaterThan(95));
    });

    test('哈希码应该基于chapterUrl和novelUrl', () {
      final task1 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      final task2 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '不同标题',
        chapterIndex: 99,
      );

      // 相同的chapterUrl和novelUrl应该产生相同哈希码
      expect(task1.hashCode, equals(task2.hashCode));
    });

    test('哈希码应该与equals一致', () {
      final task1 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      final task2 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      final task3 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/2',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 1,
      );

      // 相等的对象必须有相同的哈希码
      if (task1 == task2) {
        expect(task1.hashCode, equals(task2.hashCode));
      }

      // 不相等的对象应该有不同的哈希码（大概率）
      if (task1 != task3) {
        expect(task1.hashCode, isNot(equals(task3.hashCode)));
      }
    });
  });

  group('PreloadTask - Set和Map使用', () {
    test('应该能在Set中去重', () {
      final task1 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      final task2 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      final taskSet = {task1, task2};

      expect(taskSet.length, 1); // 重复的任务应该被去重
    });

    test('应该能在Map中作为键', () {
      final task1 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      final task2 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      final taskMap = <PreloadTask, String>{};
      taskMap[task1] = 'value1';
      taskMap[task2] = 'value2'; // 应该覆盖value1

      expect(taskMap.length, 1);
      expect(taskMap[task1], 'value2');
      expect(taskMap[task2], 'value2');
    });

    test('Set应该正确区分不同任务', () {
      final tasks = [
        PreloadTask(
          chapterUrl: 'https://example.com/chapter/1',
          novelUrl: 'https://example.com/novel/1',
          novelTitle: '测试小说',
          chapterIndex: 0,
        ),
        PreloadTask(
          chapterUrl: 'https://example.com/chapter/2',
          novelUrl: 'https://example.com/novel/1',
          novelTitle: '测试小说',
          chapterIndex: 1,
        ),
        PreloadTask(
          chapterUrl: 'https://example.com/chapter/1',
          novelUrl: 'https://example.com/novel/2',
          novelTitle: '其他小说',
          chapterIndex: 0,
        ),
      ];

      final taskSet = tasks.toSet();

      expect(taskSet.length, 3); // 三个不同的任务
    });

    test('Map查找应该正确匹配', () {
      final task1 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      final taskMap = <PreloadTask, int>{};
      taskMap[task1] = 100;

      // 使用相同chapterUrl和novelUrl的新对象查找
      final task2 = PreloadTask(
        chapterUrl: 'https://example.com/chapter/1',
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '不同标题', // 标题不同但应该不影响
        chapterIndex: 99, // 索引不同但应该不影响
      );

      expect(taskMap[task2], 100); // 应该能找到
    });
  });

  group('PreloadTask - 边界情况', () {
    test('应该处理空字符串URL', () {
      final task = PreloadTask(
        chapterUrl: '',
        novelUrl: '',
        novelTitle: '',
        chapterIndex: 0,
      );

      expect(task.chapterUrl, '');
      expect(task.novelUrl, '');
      expect(task.novelTitle, '');
    });

    test('应该处理特殊字符URL', () {
      final task = PreloadTask(
        chapterUrl: 'https://example.com/chapter/测试章节?id=123&name=测试',
        novelUrl: 'https://example.com/novel/小说名称?v=1.0',
        novelTitle: '测试<>&"\'小说',
        chapterIndex: 0,
      );

      expect(task.chapterUrl, contains('测试章节'));
      expect(task.chapterUrl, contains('?'));
      expect(task.novelUrl, contains('小说名称'));
      expect(task.novelTitle, contains('<>&'));
    });

    test('应该处理非常长的URL', () {
      final longUrl = 'https://example.com/chapter/' + 'a' * 10000;
      final task = PreloadTask(
        chapterUrl: longUrl,
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterIndex: 0,
      );

      expect(task.chapterUrl.length, 10000 + 'https://example.com/chapter/'.length);
    });
  });
}
