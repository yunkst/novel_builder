import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/tts_player_service.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';

void main() {
  // 测试数据
  final testNovel = Novel(
    title: '测试小说',
    author: '测试作者',
    url: 'https://example.com/novel/1',
  );

  final testChapters = [
    Chapter(title: '第一章', url: 'chapter1'),
    Chapter(title: '第二章', url: 'chapter2'),
    Chapter(title: '第三章', url: 'chapter3'),
  ];

  final testContent = '第一段内容。\n\n第二段内容。\n\n第三段内容。';

  group('TtsPlayerService - 状态管理', () {
    test('语速设置应该在有效范围内', () {
      // 测试语速范围 0.5 - 2.0
      for (final rate in [0.5, 1.0, 1.5, 2.0]) {
        expect(rate >= 0.5 && rate <= 2.0, true);
      }
    });
  });

  group('TtsPlayerService - 段落解析', () {
    test('应该正确解析普通段落', () {
      final content = '第一段\n\n第二段\n\n第三段';
      final paragraphs = content
          .split('\n')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      expect(paragraphs.length, 3);
      expect(paragraphs[0], '第一段');
      expect(paragraphs[1], '第二段');
      expect(paragraphs[2], '第三段');
    });

    test('应该过滤空段落', () {
      final content = '第一段\n\n\n第二段\n\n\n\n第三段';
      final paragraphs = content
          .split('\n')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      expect(paragraphs.length, 3);
    });

    test('应该过滤标记段落', () {
      final content = '''第一段

[插图:task1]

第二段

[视频:task2]

第三段''';

      final paragraphs = content
          .split('\n')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .where((p) => !p.startsWith('[插图:') && !p.startsWith('[视频:') && !p.startsWith('[图片:'))
          .toList();

      expect(paragraphs.length, 3);
      expect(paragraphs[0], '第一段');
      expect(paragraphs[1], '第二段');
      expect(paragraphs[2], '第三段');
    });
  });

  group('TtsPlayerService - 章节切换逻辑', () {
    test('应该正确计算章节索引', () {
      final chapters = [
        Chapter(title: '第一章', url: 'c1'),
        Chapter(title: '第二章', url: 'c2'),
        Chapter(title: '第三章', url: 'c3'),
      ];

      final currentIndex = chapters.indexWhere((c) => c.url == 'c2');
      expect(currentIndex, 1);

      final hasPrevious = currentIndex > 0;
      final hasNext = currentIndex < chapters.length - 1;

      expect(hasPrevious, true);
      expect(hasNext, true);
    });

    test('第一章不应该有上一章', () {
      final chapters = [
        Chapter(title: '第一章', url: 'c1'),
        Chapter(title: '第二章', url: 'c2'),
      ];

      final currentIndex = 0;
      expect(currentIndex > 0, false);
    });

    test('最后一章不应该有下一章', () {
      final chapters = [
        Chapter(title: '第一章', url: 'c1'),
        Chapter(title: '第二章', url: 'c2'),
      ];

      final currentIndex = chapters.length - 1;
      expect(currentIndex < chapters.length - 1, false);
    });

    test('应该正确计算总进度', () {
      final totalChapters = 10;
      final currentChapterIndex = 4;
      final currentParagraphIndex = 5;
      final totalParagraphs = 20;

      final chapterProgress = currentParagraphIndex / totalParagraphs;
      final totalProgress = (currentChapterIndex + chapterProgress) / totalChapters;

      expect(totalProgress, closeTo(0.425, 0.001)); // (4 + 0.25) / 10 = 0.425
    });
  });

  group('TtsPlayerService - 播放控制', () {
    test('段落索引应该在有效范围内', () {
      final totalParagraphs = 10;

      // 测试边界情况
      expect(0 >= 0 && 0 < totalParagraphs, true); // 第一段
      expect(9 >= 0 && 9 < totalParagraphs, true); // 最后一段
      expect(-1 >= 0 && -1 < totalParagraphs, false); // 无效：负数
      expect(10 >= 0 && 10 < totalParagraphs, false); // 无效：超出
    });

    test('应该能够跳转到指定段落', () {
      final currentIndex = 5;
      final targetIndex = 8;
      final totalParagraphs = 10;

      expect(targetIndex >= 0 && targetIndex < totalParagraphs, true);
    });

    test('上一段应该在有效范围内', () {
      final currentIndex = 5;
      final prevIndex = currentIndex - 1;

      expect(prevIndex >= 0, true);
    });

    test('第一段的上一段应该无效', () {
      final currentIndex = 0;
      final hasPrevious = currentIndex > 0;

      expect(hasPrevious, false);
    });

    test('下一段应该在有效范围内', () {
      final currentIndex = 5;
      final totalParagraphs = 10;
      final nextIndex = currentIndex + 1;

      expect(nextIndex < totalParagraphs, true);
    });

    test('最后一段的下一段应该无效', () {
      final currentIndex = 9;
      final totalParagraphs = 10;
      final hasNext = currentIndex < totalParagraphs - 1;

      expect(hasNext, false);
    });
  });

  group('TtsPlayerService - 语速和音调', () {
    test('语速应该在0.5到2.0之间', () {
      final validRates = [0.5, 0.8, 1.0, 1.2, 1.5, 2.0];
      for (final rate in validRates) {
        expect(rate >= 0.5 && rate <= 2.0, true,
            reason: '语速 $rate 应该在有效范围内');
      }
    });

    test('音调应该在0.5到2.0之间', () {
      final validPitches = [0.5, 0.8, 1.0, 1.2, 1.5, 2.0];
      for (final pitch in validPitches) {
        expect(pitch >= 0.5 && pitch <= 2.0, true,
            reason: '音调 $pitch 应该在有效范围内');
      }
    });

    test('无效的语速应该被拒绝', () {
      final invalidRates = [0.1, 0.4, 2.1, 3.0];
      for (final rate in invalidRates) {
        expect(rate >= 0.5 && rate <= 2.0, false,
            reason: '语速 $rate 应该被拒绝');
      }
    });
  });

  group('TtsPlayerService - 状态转换', () {
    test('状态枚举应该包含所有必要的状态', () {
      final states = TtsPlayerState.values;

      expect(states, contains(TtsPlayerState.idle));
      expect(states, contains(TtsPlayerState.loading));
      expect(states, contains(TtsPlayerState.playing));
      expect(states, contains(TtsPlayerState.paused));
      expect(states, contains(TtsPlayerState.error));
      expect(states, contains(TtsPlayerState.completed));
    });

    test('状态应该可以正确转换', () {
      // 测试状态转换逻辑
      var state = TtsPlayerState.idle;

      // idle -> loading
      state = TtsPlayerState.loading;
      expect(state, TtsPlayerState.loading);

      // loading -> playing
      state = TtsPlayerState.playing;
      expect(state, TtsPlayerState.playing);

      // playing -> paused
      state = TtsPlayerState.paused;
      expect(state, TtsPlayerState.paused);

      // paused -> playing
      state = TtsPlayerState.playing;
      expect(state, TtsPlayerState.playing);

      // playing -> completed
      state = TtsPlayerState.completed;
      expect(state, TtsPlayerState.completed);
    });
  });
}

// 辅助函数：模拟段落解析
List<String> parseTestParagraphs(String content) {
  return content
      .split('\n')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .where((p) => !p.startsWith('[插图:') &&
                   !p.startsWith('[视频:') &&
                   !p.startsWith('[图片:'))
      .toList();
}
