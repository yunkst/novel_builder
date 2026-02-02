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

    test('应该正确处理刚好到期的进度', () {
      // 8天前的进度应该过期（默认7天）
      final exactExpired = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 0,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now().subtract(const Duration(days: 8)),
      );

      expect(exactExpired.isExpired(days: 7), true);
    });

    test('应该正确处理未到期的进度', () {
      // 6天前的进度不应该过期（默认7天）
      final notExpired = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 0,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now().subtract(const Duration(days: 6)),
      );

      expect(notExpired.isExpired(days: 7), false);
    });

    test('copyWith应该支持修改所有字段', () {
      final progress = ReadingProgress(
        novelUrl: 'url1',
        novelTitle: '小说1',
        chapterUrl: 'chapter1',
        chapterTitle: '章节1',
        paragraphIndex: 5,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime(2025, 1, 1),
      );

      final updated = progress.copyWith(
        novelUrl: 'url2',
        novelTitle: '小说2',
        chapterUrl: 'chapter2',
        chapterTitle: '章节2',
        paragraphIndex: 10,
        speechRate: 1.5,
        pitch: 0.8,
        timestamp: DateTime(2025, 1, 2),
      );

      expect(updated.novelUrl, 'url2');
      expect(updated.novelTitle, '小说2');
      expect(updated.chapterUrl, 'chapter2');
      expect(updated.chapterTitle, '章节2');
      expect(updated.paragraphIndex, 10);
      expect(updated.speechRate, 1.5);
      expect(updated.pitch, 0.8);
      expect(updated.timestamp, DateTime(2025, 1, 2));
    });

    test('copyWith不传参数时应保持原值', () {
      final progress = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 5,
        speechRate: 1.2,
        pitch: 1.0,
        timestamp: DateTime(2025, 1, 1),
      );

      final copied = progress.copyWith();

      expect(copied.novelUrl, progress.novelUrl);
      expect(copied.novelTitle, progress.novelTitle);
      expect(copied.chapterUrl, progress.chapterUrl);
      expect(copied.chapterTitle, progress.chapterTitle);
      expect(copied.paragraphIndex, progress.paragraphIndex);
      expect(copied.speechRate, progress.speechRate);
      expect(copied.pitch, progress.pitch);
      expect(copied.timestamp, progress.timestamp);
    });

    test('应该正确处理负数的paragraphIndex', () {
      final progress = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: -1,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now(),
      );

      expect(progress.paragraphIndex, -1);
      expect(progress.positionText, '章节 (第0段)');
    });

    test('应该正确处理非常大的paragraphIndex', () {
      final progress = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 999999,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now(),
      );

      expect(progress.paragraphIndex, 999999);
      expect(progress.positionText, '章节 (第1000000段)');
    });

    test('应该正确处理包含特殊字符的标题', () {
      final progress = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说《测试》',
        chapterUrl: 'chapter',
        chapterTitle: '第一章：新开始',
        paragraphIndex: 0,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now(),
      );

      expect(progress.positionText, '第一章：新开始 (第1段)');
      expect(progress.toString(), contains('小说《测试》'));
      expect(progress.toString(), contains('第一章：新开始'));
    });

    test('应该正确处理空字符串标题', () {
      final progress = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '',
        chapterUrl: 'chapter',
        chapterTitle: '',
        paragraphIndex: 5,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now(),
      );

      expect(progress.novelTitle, '');
      expect(progress.chapterTitle, '');
      expect(progress.positionText, ' (第6段)');
      expect(progress.toString(), contains('ReadingProgress'));
      expect(progress.toString(), contains('(novel: , chapter: , paragraph: 5)'));
    });

    test('JSON序列化应该保持浮点数精度', () {
      final progress = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 0,
        speechRate: 1.23456789,
        pitch: 0.987654321,
        timestamp: DateTime.now(),
      );

      final jsonString = progress.toJsonString();
      final parsed = ReadingProgress.fromJsonString(jsonString);

      expect(parsed, isNotNull);
      expect(parsed!.speechRate, closeTo(1.23456789, 0.0000001));
      expect(parsed.pitch, closeTo(0.987654321, 0.0000001));
    });

    test('应该正确处理JSON中的整数值', () {
      final json = {
        'novelUrl': 'url',
        'novelTitle': '小说',
        'chapterUrl': 'chapter',
        'chapterTitle': '章节',
        'paragraphIndex': 5,
        'speechRate': 1, // 整数而不是浮点数
        'pitch': 1, // 整数而不是浮点数
        'timestamp': '2025-01-01T00:00:00.000',
      };

      final progress = ReadingProgress.fromJson(json);

      expect(progress.speechRate, 1.0);
      expect(progress.pitch, 1.0);
    });

    test('toString应该包含所有关键信息', () {
      final progress = ReadingProgress(
        novelUrl: 'https://example.com/novel/1',
        novelTitle: '测试小说标题',
        chapterUrl: 'https://example.com/chapter/1',
        chapterTitle: '第一章：开始',
        paragraphIndex: 42,
        speechRate: 1.5,
        pitch: 0.9,
        timestamp: DateTime(2025, 1, 21, 10, 30),
      );

      final str = progress.toString();
      expect(str, contains('测试小说标题'));
      expect(str, contains('第一章：开始'));
      expect(str, contains('42'));
      expect(str, contains('ReadingProgress'));
    });

    test('相等性比较应该忽略时间戳', () {
      final now = DateTime.now();
      final progress1 = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 5,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: now,
      );

      final progress2 = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 5,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: now.add(const Duration(days: 1)), // 不同的时间戳
      );

      expect(progress1, equals(progress2));
      expect(progress1.hashCode, progress2.hashCode);
    });

    test('相等性比较应该忽略标题和语音设置', () {
      final progress1 = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说1',
        chapterUrl: 'chapter',
        chapterTitle: '章节1',
        paragraphIndex: 5,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now(),
      );

      final progress2 = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说2', // 不同的标题
        chapterUrl: 'chapter',
        chapterTitle: '章节2', // 不同的章节标题
        paragraphIndex: 5,
        speechRate: 1.5, // 不同的语速
        pitch: 0.8, // 不同的音调
        timestamp: DateTime.now(),
      );

      expect(progress1, equals(progress2));
      expect(progress1.hashCode, progress2.hashCode);
    });

    test('不同novelUrl的进度不应该相等', () {
      final progress1 = ReadingProgress(
        novelUrl: 'url1',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 5,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now(),
      );

      final progress2 = ReadingProgress(
        novelUrl: 'url2',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 5,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now(),
      );

      expect(progress1, isNot(equals(progress2)));
    });

    test('不同chapterUrl的进度不应该相等', () {
      final progress1 = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter1',
        chapterTitle: '章节',
        paragraphIndex: 5,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now(),
      );

      final progress2 = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter2',
        chapterTitle: '章节',
        paragraphIndex: 5,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now(),
      );

      expect(progress1, isNot(equals(progress2)));
    });

    test('不同paragraphIndex的进度不应该相等', () {
      final progress1 = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 5,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now(),
      );

      final progress2 = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 10,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now(),
      );

      expect(progress1, isNot(equals(progress2)));
    });
  });

  group('ReadingProgress - 跨章节进度', () {
    test('应该能够跨章节追踪进度', () {
      final chapter1 = ReadingProgress(
        novelUrl: 'novel_url',
        novelTitle: '小说',
        chapterUrl: 'chapter_1',
        chapterTitle: '第一章',
        paragraphIndex: 10,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now(),
      );

      final chapter2 = ReadingProgress(
        novelUrl: 'novel_url',
        novelTitle: '小说',
        chapterUrl: 'chapter_2',
        chapterTitle: '第二章',
        paragraphIndex: 5,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now(),
      );

      // 验证它们是不同的进度记录
      expect(chapter1, isNot(equals(chapter2)));
      expect(chapter1.chapterTitle, '第一章');
      expect(chapter2.chapterTitle, '第二章');
    });

    test('应该能够恢复跨章节的语音设置', () {
      final chapter1 = ReadingProgress(
        novelUrl: 'novel_url',
        novelTitle: '小说',
        chapterUrl: 'chapter_1',
        chapterTitle: '第一章',
        paragraphIndex: 10,
        speechRate: 1.5,
        pitch: 0.9,
        timestamp: DateTime.now(),
      );

      // 使用copyWith切换到下一章，保持语音设置
      final chapter2 = chapter1.copyWith(
        chapterUrl: 'chapter_2',
        chapterTitle: '第二章',
        paragraphIndex: 0,
      );

      expect(chapter2.speechRate, 1.5);
      expect(chapter2.pitch, 0.9);
      expect(chapter2.chapterTitle, '第二章');
      expect(chapter2.paragraphIndex, 0);
    });

    test('应该能够重置章节内进度', () {
      final progress = ReadingProgress(
        novelUrl: 'novel_url',
        novelTitle: '小说',
        chapterUrl: 'chapter_1',
        chapterTitle: '第一章',
        paragraphIndex: 50,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now(),
      );

      // 重置到章节开头
      final reset = progress.copyWith(paragraphIndex: 0);

      expect(reset.paragraphIndex, 0);
      expect(reset.chapterTitle, '第一章');
      expect(reset.positionText, '第一章 (第1段)');
    });

    test('应该能够计算相对位置变化', () {
      final progress1 = ReadingProgress(
        novelUrl: 'novel_url',
        novelTitle: '小说',
        chapterUrl: 'chapter_1',
        chapterTitle: '第一章',
        paragraphIndex: 10,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now(),
      );

      final progress2 = progress1.copyWith(paragraphIndex: 15);

      final difference = progress2.paragraphIndex - progress1.paragraphIndex;
      expect(difference, 5);
    });
  });

  group('ReadingProgress - 进度持久化场景', () {
    test('应该能够序列化和反序列化完整的进度信息', () {
      final original = ReadingProgress(
        novelUrl: 'https://example.com/novel/123',
        novelTitle: '测试小说标题',
        chapterUrl: 'https://example.com/chapter/456',
        chapterTitle: '第一百章：高潮',
        paragraphIndex: 78,
        speechRate: 1.3,
        pitch: 0.95,
        timestamp: DateTime(2025, 1, 21, 15, 30, 45),
      );

      // 序列化
      final jsonString = original.toJsonString();

      // 反序列化
      final restored = ReadingProgress.fromJsonString(jsonString);

      expect(restored, isNotNull);
      expect(restored!.novelUrl, original.novelUrl);
      expect(restored.novelTitle, original.novelTitle);
      expect(restored.chapterUrl, original.chapterUrl);
      expect(restored.chapterTitle, original.chapterTitle);
      expect(restored.paragraphIndex, original.paragraphIndex);
      expect(restored.speechRate, original.speechRate);
      expect(restored.pitch, original.pitch);
      expect(restored.timestamp, original.timestamp);
    });

    test('应该能够批量处理多个进度记录', () {
      final progresses = List.generate(
        10,
        (i) => ReadingProgress(
          novelUrl: 'novel_$i',
          novelTitle: '小说$i',
          chapterUrl: 'chapter_$i',
          chapterTitle: '章节$i',
          paragraphIndex: i * 10,
          speechRate: 1.0,
          pitch: 1.0,
          timestamp: DateTime.now(),
        ),
      );

      // 序列化所有进度
      final jsonStrings = progresses.map((p) => p.toJsonString()).toList();

      // 反序列化所有进度
      final restored = jsonStrings
          .map((json) => ReadingProgress.fromJsonString(json))
          .whereType<ReadingProgress>()
          .toList();

      expect(restored, hasLength(10));
      for (var i = 0; i < 10; i++) {
        expect(restored[i].novelTitle, '小说$i');
        expect(restored[i].paragraphIndex, i * 10);
      }
    });

    test('应该能够处理损坏的序列化数据', () {
      final validJson = ReadingProgress(
        novelUrl: 'url',
        novelTitle: '小说',
        chapterUrl: 'chapter',
        chapterTitle: '章节',
        paragraphIndex: 0,
        speechRate: 1.0,
        pitch: 1.0,
        timestamp: DateTime.now(),
      ).toJsonString();

      final invalidJsonStrings = [
        '',
        'not a json',
        '{invalid json}',
        'null',
        '{"novelUrl": "url"}', // 缺少必填字段
      ];

      // 验证有效JSON可以解析
      expect(ReadingProgress.fromJsonString(validJson), isNotNull);

      // 验证无效JSON返回null
      for (final invalid in invalidJsonStrings) {
        expect(ReadingProgress.fromJsonString(invalid), null);
      }
    });
  });
}
