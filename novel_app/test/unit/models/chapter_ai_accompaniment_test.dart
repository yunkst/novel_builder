import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/chapter.dart';

/// Chapter模型单元测试（AI伴读功能）
///
/// 测试重点：
/// 1. isAccompanied字段的序列化/反序列化
/// 2. copyWith方法的正确性
/// 3. 默认值处理
void main() {
  group('Chapter模型 - AI伴读字段测试', () {
    group('构造函数和默认值', () {
      test('应该默认isAccompanied为false', () {
        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
        );

        expect(chapter.isAccompanied, false);
      });

      test('应该可以显式设置isAccompanied为true', () {
        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          isAccompanied: true,
        );

        expect(chapter.isAccompanied, true);
      });

      test('应该可以显式设置isAccompanied为false', () {
        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          isAccompanied: false,
        );

        expect(chapter.isAccompanied, false);
      });
    });

    group('toMap - 序列化测试', () {
      test('应该正确序列化isAccompanied=true', () {
        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          isAccompanied: true,
        );

        final map = chapter.toMap();

        expect(map['isAccompanied'], 1); // true -> 1
      });

      test('应该正确序列化isAccompanied=false', () {
        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          isAccompanied: false,
        );

        final map = chapter.toMap();

        expect(map['isAccompanied'], 0); // false -> 0
      });

      test('应该保留其他字段', () {
        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '测试内容',
          isCached: true,
          chapterIndex: 1,
          isUserInserted: false,
          readAt: 1234567890,
          isAccompanied: true,
        );

        final map = chapter.toMap();

        expect(map['title'], '第一章');
        expect(map['url'], 'https://example.com/chapter1');
        expect(map['content'], '测试内容');
        expect(map['isCached'], 1);
        expect(map['chapterIndex'], 1);
        expect(map['isUserInserted'], 0);
        expect(map['readAt'], 1234567890);
        expect(map['isAccompanied'], 1);
      });
    });

    group('fromMap - 反序列化测试', () {
      test('应该正确反序列化isAccompanied=1', () {
        final map = {
          'title': '第一章',
          'url': 'https://example.com/chapter1',
          'isAccompanied': 1,
        };

        final chapter = Chapter.fromMap(map);

        expect(chapter.isAccompanied, true); // 1 -> true
      });

      test('应该正确反序列化isAccompanied=0', () {
        final map = {
          'title': '第一章',
          'url': 'https://example.com/chapter1',
          'isAccompanied': 0,
        };

        final chapter = Chapter.fromMap(map);

        expect(chapter.isAccompanied, false); // 0 -> false
      });

      test('应该处理isAccompanied为null的情况', () {
        final map = {
          'title': '第一章',
          'url': 'https://example.com/chapter1',
          'isAccompanied': null,
        };

        final chapter = Chapter.fromMap(map);

        expect(chapter.isAccompanied, false); // null -> false
      });

      test('应该正确反序列化所有字段', () {
        final map = {
          'title': '第一章',
          'url': 'https://example.com/chapter1',
          'content': '测试内容',
          'isCached': 1,
          'chapterIndex': 1,
          'isUserInserted': 0,
          'readAt': 1234567890,
          'isAccompanied': 1,
        };

        final chapter = Chapter.fromMap(map);

        expect(chapter.title, '第一章');
        expect(chapter.url, 'https://example.com/chapter1');
        expect(chapter.content, '测试内容');
        expect(chapter.isCached, true);
        expect(chapter.chapterIndex, 1);
        expect(chapter.isUserInserted, false);
        expect(chapter.readAt, 1234567890);
        expect(chapter.isAccompanied, true);
      });
    });

    group('copyWith - 复制方法测试', () {
      test('应该保留原有的isAccompanied值', () {
        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          isAccompanied: true,
        );

        final copied = chapter.copyWith();

        expect(copied.isAccompanied, true);
      });

      test('应该可以修改isAccompanied为true', () {
        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          isAccompanied: false,
        );

        final copied = chapter.copyWith(isAccompanied: true);

        expect(copied.isAccompanied, true);
        expect(chapter.isAccompanied, false); // 原对象不变
      });

      test('应该可以修改isAccompanied为false', () {
        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          isAccompanied: true,
        );

        final copied = chapter.copyWith(isAccompanied: false);

        expect(copied.isAccompanied, false);
        expect(chapter.isAccompanied, true); // 原对象不变
      });

      test('应该可以同时修改isAccompanied和其他字段', () {
        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          isAccompanied: false,
        );

        final copied = chapter.copyWith(
          title: '第二章',
          isAccompanied: true,
        );

        expect(copied.title, '第二章');
        expect(copied.isAccompanied, true);
        expect(chapter.title, '第一章'); // 原对象不变
        expect(chapter.isAccompanied, false);
      });

      test('应该正确处理null参数（保持原值）', () {
        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          isAccompanied: true,
        );

        final copied = chapter.copyWith(
          isAccompanied: null,
        );

        expect(copied.isAccompanied, true); // 保持原值
      });
    });

    group('序列化/反序列化往返测试', () {
      test('toMap -> fromMap应该保持isAccompanied=true', () {
        final original = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '测试内容',
          isCached: true,
          chapterIndex: 1,
          isUserInserted: false,
          readAt: 1234567890,
          isAccompanied: true,
        );

        final map = original.toMap();
        final restored = Chapter.fromMap(map);

        expect(restored.title, original.title);
        expect(restored.url, original.url);
        expect(restored.content, original.content);
        expect(restored.isCached, original.isCached);
        expect(restored.chapterIndex, original.chapterIndex);
        expect(restored.isUserInserted, original.isUserInserted);
        expect(restored.readAt, original.readAt);
        expect(restored.isAccompanied, original.isAccompanied);
      });

      test('toMap -> fromMap应该保持isAccompanied=false', () {
        final original = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          isAccompanied: false,
        );

        final map = original.toMap();
        final restored = Chapter.fromMap(map);

        expect(restored.isAccompanied, false);
      });

      test('多次往返应该保持一致性', () {
        final original = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          isAccompanied: true,
        );

        // 第一次往返
        final map1 = original.toMap();
        final restored1 = Chapter.fromMap(map1);

        // 第二次往返
        final map2 = restored1.toMap();
        final restored2 = Chapter.fromMap(map2);

        // 第三次往返
        final map3 = restored2.toMap();
        final restored3 = Chapter.fromMap(map3);

        expect(restored3.isAccompanied, original.isAccompanied);
        expect(map3['isAccompanied'], map1['isAccompanied']);
      });
    });

    group('边界情况测试', () {
      test('空URL应该也能正常工作', () {
        final chapter = Chapter(
          title: '',
          url: '',
          isAccompanied: true,
        );

        final map = chapter.toMap();
        final restored = Chapter.fromMap(map);

        expect(restored.isAccompanied, true);
      });

      test('特殊字符应该正常处理', () {
        final chapter = Chapter(
          title: '第\'一\'章"测\\试',
          url: 'https://example.com/chapter?param=value&other=123',
          isAccompanied: true,
        );

        final map = chapter.toMap();
        final restored = Chapter.fromMap(map);

        expect(restored.title, chapter.title);
        expect(restored.url, chapter.url);
        expect(restored.isAccompanied, true);
      });

      test('大量数据应该正确序列化', () {
        final longContent = '内容' * 10000; // 40KB
        final chapter = Chapter(
          title: '长章节',
          url: 'https://example.com/long',
          content: longContent,
          isAccompanied: true,
        );

        final map = chapter.toMap();
        final restored = Chapter.fromMap(map);

        expect(restored.content, longContent);
        expect(restored.isAccompanied, true);
      });
    });

    group('兼容性测试', () {
      test('应该兼容旧数据（没有isAccompanied字段）', () {
        // 模拟旧数据库数据（没有isAccompanied字段）
        final oldMap = {
          'title': '第一章',
          'url': 'https://example.com/chapter1',
          'content': '测试内容',
          'isCached': 1,
          'chapterIndex': 1,
          'isUserInserted': 0,
          'readAt': 1234567890,
          // 注意：没有 isAccompanied 字段
        };

        final chapter = Chapter.fromMap(oldMap);

        // 应该默认为false
        expect(chapter.isAccompanied, false);
      });

      test('新数据序列化后应该包含isAccompanied字段', () {
        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          isAccompanied: true,
        );

        final map = chapter.toMap();

        // 必须包含该字段
        expect(map.containsKey('isAccompanied'), true);
        expect(map['isAccompanied'], 1);
      });
    });
  });
}
