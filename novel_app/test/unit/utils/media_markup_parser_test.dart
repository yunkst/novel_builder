/// MediaMarkupParser 媒体标记解析器单元测试
///
/// 验证媒体标记的解析、创建、替换和统计功能。
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/utils/media_markup_parser_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/utils/media_markup_parser.dart';

void main() {
  group('MediaMarkupParser', () {
    group('parseMediaMarkup', () {
      test('应解析插图标记', () {
        final text = '这是正文[!插图!](task_123)继续正文';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        expect(markups.length, 1);
        expect(markups[0].type, '插图');
        expect(markups[0].id, 'task_123');
        expect(markups[0].fullMarkup, '[!插图!](task_123)');
        expect(markups[0].isIllustration, isTrue);
        expect(markups[0].isVideo, isFalse);
      });

      test('应解析视频标记', () {
        final text = '[!视频!](vid_456)';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        expect(markups.length, 1);
        expect(markups[0].type, '视频');
        expect(markups[0].id, 'vid_456');
        expect(markups[0].isVideo, isTrue);
        expect(markups[0].isIllustration, isFalse);
      });

      test('应解析音频标记', () {
        final text = '[!音频!](audio_789)';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        expect(markups.length, 1);
        expect(markups[0].type, '音频');
        expect(markups[0].id, 'audio_789');
        expect(markups[0].isAudio, isTrue);
      });

      test('应解析多个标记', () {
        final text = '[!插图!](t1) 中间文字 [!视频!](v1) [!插图!](t2)';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        expect(markups.length, 3);
        expect(markups[0].type, '插图');
        expect(markups[1].type, '视频');
        expect(markups[2].type, '插图');
      });

      test('无标记应返回空列表', () {
        final text = '纯文本内容，没有任何标记';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        expect(markups, isEmpty);
      });

      test('应记录标记的起始和结束位置', () {
        final text = '开头[!插图!](id1)结尾';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        // "开头" 2 个字符，所以标记从索引 2 开始
        expect(markups[0].start, 2);
        // "[!插图!](id1)" 总长 13
        expect(markups[0].end, 13);
      });
    });

    group('isMediaMarkup', () {
      test('媒体标记应返回 true', () {
        expect(MediaMarkupParser.isMediaMarkup('[!插图!](id)'), isTrue);
      });

      test('普通文本应返回 false', () {
        expect(MediaMarkupParser.isMediaMarkup('普通文本'), isFalse);
      });
    });

    group('getMarkupType', () {
      test('应返回标记类型', () {
        expect(MediaMarkupParser.getMarkupType('[!插图!](id)'), '插图');
        expect(MediaMarkupParser.getMarkupType('[!视频!](id)'), '视频');
      });

      test('非标记文本应返回空字符串', () {
        expect(MediaMarkupParser.getMarkupType('普通文本'), '');
      });
    });

    group('getMarkupId', () {
      test('应返回标记 ID', () {
        expect(MediaMarkupParser.getMarkupId('[!插图!](task_123)'), 'task_123');
      });

      test('非标记文本应返回空字符串', () {
        expect(MediaMarkupParser.getMarkupId('普通文本'), '');
      });
    });

    group('createMediaMarkup', () {
      test('应创建指定类型的标记', () {
        expect(MediaMarkupParser.createMediaMarkup('插图', 'id1'),
            '[!插图!](id1)');
        expect(MediaMarkupParser.createMediaMarkup('视频', 'id2'),
            '[!视频!](id2)');
      });
    });

    group('createIllustrationMarkup', () {
      test('应创建插图标记', () {
        expect(MediaMarkupParser.createIllustrationMarkup('task_123'),
            '[!插图!](task_123)');
      });
    });

    group('createVideoMarkup', () {
      test('应创建视频标记', () {
        expect(MediaMarkupParser.createVideoMarkup('vid_456'),
            '[!视频!](vid_456)');
      });
    });

    group('removeMediaMarkup', () {
      test('应移除所有媒体标记', () {
        final text = '开头[!插图!](t1)中间[!视频!](v1)结尾';
        final result = MediaMarkupParser.removeMediaMarkup(text);

        expect(result, '开头中间结尾');
      });

      test('无标记文本应保持不变', () {
        final text = '纯文本';
        expect(MediaMarkupParser.removeMediaMarkup(text), '纯文本');
      });
    });

    group('replaceMediaMarkup', () {
      test('应替换媒体标记', () {
        final text = '开头[!插图!](t1)结尾';
        final result = MediaMarkupParser.replaceMediaMarkup(
          text,
          (markup) => '[图片:${markup.id}]',
        );

        expect(result, '开头[图片:t1]结尾');
      });

      test('应替换多个标记', () {
        final text = '[!插图!](a)[!视频!](b)';
        final result = MediaMarkupParser.replaceMediaMarkup(
          text,
          (markup) => '[${markup.type}:${markup.id}]',
        );

        expect(result, '[插图:a][视频:b]');
      });
    });

    group('countMediaMarkup', () {
      test('应统计所有标记数量', () {
        final text = '[!插图!](a) [!插图!](b) [!视频!](c)';
        expect(MediaMarkupParser.countMediaMarkup(text), 3);
      });

      test('应统计指定类型标记数量', () {
        final text = '[!插图!](a) [!插图!](b) [!视频!](c)';
        expect(MediaMarkupParser.countMediaMarkup(text, type: '插图'), 2);
        expect(MediaMarkupParser.countMediaMarkup(text, type: '视频'), 1);
        expect(MediaMarkupParser.countMediaMarkup(text, type: '音频'), 0);
      });

      test('无标记应返回 0', () {
        expect(MediaMarkupParser.countMediaMarkup('普通文本'), 0);
      });
    });

    group('containsMediaType', () {
      test('包含指定类型应返回 true', () {
        final text = '[!插图!](a)';
        expect(MediaMarkupParser.containsMediaType(text, '插图'), isTrue);
      });

      test('不包含指定类型应返回 false', () {
        final text = '[!插图!](a)';
        expect(MediaMarkupParser.containsMediaType(text, '视频'), isFalse);
      });
    });
  });

  group('MediaMarkup 模型', () {
    test('== 应正确比较', () {
      final a = MediaMarkup(
          type: '插图', id: '1', fullMarkup: '[!插图!](1)', start: 0, end: 10);
      final b = MediaMarkup(
          type: '插图', id: '1', fullMarkup: '[!插图!](1)', start: 0, end: 10);
      final c = MediaMarkup(
          type: '视频', id: '1', fullMarkup: '[!视频!](1)', start: 0, end: 10);

      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });

    test('hashCode 应一致', () {
      final a = MediaMarkup(
          type: '插图', id: '1', fullMarkup: '[!插图!](1)', start: 0, end: 10);
      final b = MediaMarkup(
          type: '插图', id: '1', fullMarkup: '[!插图!](1)', start: 0, end: 10);

      expect(a.hashCode, b.hashCode);
    });

    test('copyWith 应正确复制', () {
      final original = MediaMarkup(
          type: '插图', id: '1', fullMarkup: '[!插图!](1)', start: 0, end: 10);
      final copied = original.copyWith(type: '视频');

      expect(copied.type, '视频');
      expect(copied.id, '1');
      expect(copied.fullMarkup, '[!插图!](1)');
    });

    test('toString 应包含类型和 ID', () {
      final markup = MediaMarkup(
          type: '插图', id: '123', fullMarkup: '[!插图!](123)', start: 0, end: 10);
      expect(markup.toString(), contains('插图'));
      expect(markup.toString(), contains('123'));
    });

    test('isIllustration / isVideo / isAudio 应正确判断', () {
      final illustration = MediaMarkup(
          type: '插图', id: '1', fullMarkup: '', start: 0, end: 0);
      final video = MediaMarkup(
          type: '视频', id: '2', fullMarkup: '', start: 0, end: 0);
      final audio = MediaMarkup(
          type: '音频', id: '3', fullMarkup: '', start: 0, end: 0);

      expect(illustration.isIllustration, isTrue);
      expect(illustration.isVideo, isFalse);
      expect(video.isVideo, isTrue);
      expect(audio.isAudio, isTrue);
    });
  });
}
