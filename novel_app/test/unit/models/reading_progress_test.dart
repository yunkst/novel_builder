import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/reading_progress.dart';

void main() {
  group('ReadingProgress', () {
    late ReadingProgress progress;

    setUp(() {
      progress = ReadingProgress(
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterUrl: 'https://example.com/chapter/1',
        chapterTitle: '第一章',
        paragraphIndex: 5,
        speechRate: 1.2,
        pitch: 1.0,
        timestamp: DateTime(2025, 1, 21, 10, 30),
      );
    });

    test('应该正确创建进度对象', () {
      expect(progress.novelUrl, 'https://example.com/novel/1');
      expect(progress.novelTitle, '测试小说');
      expect(progress.chapterUrl, 'https://example.com/chapter/1');
      expect(progress.chapterTitle, '第一章');
      expect(progress.paragraphIndex, 5);
      expect(progress.speechRate, 1.2);
      expect(progress.pitch, 1.0);
    });

    test('positionText应该返回正确的格式', () {
      expect(progress.positionText, '第一章 (第6段)');
    });

    test('未过期的进度应该返回false', () {
      final recentProgress = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 0,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(recentProgress.isExpired(), false);
    });

    test('超过7天的进度应该过期', () {
      final expiredProgress = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 0,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now().subtract(const Duration(days: 8)),
      );
      expect(expiredProgress.isExpired(), true);
    });

    test('自定义过期天数应该正常工作', () {
      final oldProgress = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 0,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(oldProgress.isExpired(days: 2), true);
      expect(oldProgress.isExpired(days: 5), false);
    });

    test('copyWith应该正确复制并修改字段', () {
      final updated = progress.copyWith(
        paragraphIndex: 10,
        speechRate: 1.5,
      );

      // 修改的字段应该改变
      expect(updated.paragraphIndex, 10);
      expect(updated.speechRate, 1.5);

      // 未修改的字段应该保持原值
      expect(updated.novelUrl, progress.novelUrl);
      expect(updated.novelTitle, progress.novelTitle);
      expect(updated.chapterUrl, progress.chapterUrl);
      expect(updated.chapterTitle, progress.chapterTitle);
      expect(updated.pitch, progress.pitch);
    });

    test('toJson应该返回正确的JSON格式', () {
      final json = progress.toJson();

      expect(json['novelUrl'], 'https://example.com/novel/1');
      expect(json['novelTitle'], '测试小说');
      expect(json['chapterUrl'], 'https://example.com/chapter/1');
      expect(json['chapterTitle'], '第一章');
      expect(json['paragraphIndex'], 5);
      expect(json['speechRate'], 1.2);
      expect(json['pitch'], 1.0);
      expect(json['timestamp'], '2025-01-21T10:30:00.000');
    });

    test('fromJson应该正确解析JSON', () {
      final json = {
        'novelUrl': 'https://example.com/novel/2',
        'novelTitle': '新小说',
        'chapterUrl': 'https://example.com/chapter/2',
        'chapterTitle': '第二章',
        'paragraphIndex': 3,
        'speechRate': 1.3,
        'pitch': 0.9,
        'timestamp': '2025-01-20T15:45:00.000',
      };

      final parsed = ReadingProgress.fromJson(json);

      expect(parsed.novelUrl, 'https://example.com/novel/2');
      expect(parsed.novelTitle, '新小说');
      expect(parsed.chapterUrl, 'https://example.com/chapter/2');
      expect(parsed.chapterTitle, '第二章');
      expect(parsed.paragraphIndex, 3);
      expect(parsed.speechRate, 1.3);
      expect(parsed.pitch, 0.9);
      expect(parsed.timestamp, DateTime(2025, 1, 20, 15, 45));
    });

    test('toJsonString应该返回有效的JSON字符串', () {
      final jsonString = progress.toJsonString();

      expect(jsonString, isA<String>());
      expect(jsonString.isNotEmpty, true);

      // 验证可以解析回原始对象
      final parsed = ReadingProgress.fromJsonString(jsonString);
      expect(parsed, isNotNull);
      expect(parsed!.novelUrl, progress.novelUrl);
      expect(parsed.novelTitle, progress.novelTitle);
      expect(parsed.chapterUrl, progress.chapterUrl);
      expect(parsed.chapterTitle, progress.chapterTitle);
      expect(parsed.paragraphIndex, progress.paragraphIndex);
    });

    test('fromJsonString应该正确解析JSON字符串', () {
      final jsonString = progress.toJsonString();
      final parsed = ReadingProgress.fromJsonString(jsonString);

      expect(parsed, isNotNull);
      expect(parsed!.novelUrl, progress.novelUrl);
      expect(parsed.novelTitle, progress.novelTitle);
      expect(parsed.chapterUrl, progress.chapterUrl);
      expect(parsed.chapterTitle, progress.chapterTitle);
    });

    test('fromJsonString对null输入应该返回null', () {
      expect(ReadingProgress.fromJsonString(null), null);
    });

    test('fromJsonString对空字符串应该返回null', () {
      expect(ReadingProgress.fromJsonString(''), null);
    });

    test('fromJsonString对无效JSON应该返回null', () {
      expect(ReadingProgress.fromJsonString('invalid json'), null);
    });

    test('相等性比较应该正常工作', () {
      final same = ReadingProgress(
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterUrl: 'https://example.com/chapter/1',
        chapterTitle: '第一章',
        paragraphIndex: 5,
        speechRate: 1.2,
        pitch: 1.0,
        timestamp: DateTime(2025, 1, 21, 10, 30),
      );

      final different = progress.copyWith(paragraphIndex: 10);

      expect(progress, same);
      expect(progress == different, false);
    });

    test('hashCode应该基于关键字段', () {
      final same = ReadingProgress(
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说',
        chapterUrl: 'https://example.com/chapter/1',
        chapterTitle: '第一章',
        paragraphIndex: 5,
        speechRate: 1.2,
        pitch: 1.0,
        timestamp: DateTime(2025, 1, 21, 10, 30),
      );

      expect(progress.hashCode, same.hashCode);
    });

    test('toString应该返回有用的描述', () {
      final str = progress.toString();
      expect(str, contains('测试小说'));
      expect(str, contains('第一章'));
      expect(str, contains('5'));
    });
  });

  group('ReadingProgress - 边界情况', () {
    test('paragraphIndex为0时应该显示第1段', () {
      final progress = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 0,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now(),
      );

      expect(progress.positionText, '章节 (第1段)');
    });

    test('最小语速和音调值', () {
      final progress = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 0,
        speechRate: 0.5,
        pitch: 0.5,
        timestamp: DateTime.now(),
      );

      expect(progress.speechRate, 0.5);
      expect(progress.pitch, 0.5);
    });

    test('最大语速和音调值', () {
      final progress = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 0,
        speechRate: 2.0,
        pitch: 2.0,
        timestamp: DateTime.now(),
      );

      expect(progress.speechRate, 2.0);
      expect(progress.pitch, 2.0);
    });

    test('刚创建的进度不应该过期', () {
      final now = DateTime.now();
      final progress = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 0,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: now,
      );

      expect(progress.isExpired(), false);
      // 刚创建的进度，即使设置为0天也不应该立即过期（需要超过天数）
      expect(progress.isExpired(days: 0), false);
    });
  });
}
