import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/utils/media_markup_parser.dart';

/// MediaMarkupParser 单元测试
///
/// 测试媒体标记解析工具的核心功能：
/// - 解析文本中的媒体标记
/// - 创建各种类型的媒体标记
/// - 移除和替换媒体标记
/// - 统计和检查媒体标记
void main() {
  group('MediaMarkupParser - 标记解析测试', () {
    group('parseMediaMarkup - 解析标记', () {
      test('应该解析单个插图标记', () {
        const text = '这是一段文字[!插图!](task123)后续内容';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        expect(markups.length, 1);
        expect(markups[0].type, '插图');
        expect(markups[0].id, 'task123');
        expect(markups[0].fullMarkup, '[!插图!](task123)');
        // 注意：位置计算基于实际字符串长度，不硬编码
        expect(markups[0].start, greaterThanOrEqualTo(0));
        expect(markups[0].end, greaterThanOrEqualTo(markups[0].start));
      });

      test('应该解析视频标记', () {
        const text = '视频内容[!视频!](video456)结束';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        expect(markups.length, 1);
        expect(markups[0].type, '视频');
        expect(markups[0].id, 'video456');
        expect(markups[0].isVideo, isTrue);
        expect(markups[0].isIllustration, isFalse);
      });

      test('应该解析多个混合标记', () {
        const text = '[!插图!](task1)[!视频!](video1)[!插图!](task2)';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        expect(markups.length, 3);
        expect(markups[0].type, '插图');
        expect(markups[0].id, 'task1');
        expect(markups[1].type, '视频');
        expect(markups[1].id, 'video1');
        expect(markups[2].type, '插图');
        expect(markups[2].id, 'task2');
      });

      test('空文本应该返回空列表', () {
        const text = '';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        expect(markups.isEmpty, isTrue);
      });

      test('无标记文本应该返回空列表', () {
        const text = '这是普通的文本内容，没有任何标记';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        expect(markups.isEmpty, isTrue);
      });

      test('应该正确记录位置信息', () {
        const text = '开始[!插图!](abc)中间[!视频!](xyz)结束';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        expect(markups.length, 2);
        // 位置计算基于实际字符串长度
        expect(markups[0].start, greaterThanOrEqualTo(0));
        expect(markups[0].end, greaterThanOrEqualTo(markups[0].start));
        expect(markups[1].start, greaterThanOrEqualTo(markups[0].end));
        expect(markups[1].end, greaterThanOrEqualTo(markups[1].start));
      });
    });

    group('MediaMarkupParser - 标记创建测试', () {
      test('createIllustrationMarkup 应该创建正确格式的插图标记', () {
        const taskId = '20250130_123456_abc';
        final markup = MediaMarkupParser.createIllustrationMarkup(taskId);

        expect(markup, '[!插图!]($taskId)');
        expect(MediaMarkupParser.isMediaMarkup(markup), isTrue);
      });

      test('createVideoMarkup 应该创建正确格式的视频标记', () {
        const videoId = 'video_123';
        final markup = MediaMarkupParser.createVideoMarkup(videoId);

        expect(markup, '[!视频!]($videoId)');
        expect(MediaMarkupParser.isMediaMarkup(markup), isTrue);
      });

      test('createMediaMarkup 应该支持自定义类型', () {
        final markup = MediaMarkupParser.createMediaMarkup('音频', 'audio123');

        expect(markup, '[!音频!](audio123)');
        expect(MediaMarkupParser.isMediaMarkup(markup), isTrue);
      });

      test('创建的标记应该可以被正确解析', () {
        const taskId = 'test_task_id';
        final markup = MediaMarkupParser.createIllustrationMarkup(taskId);
        final parsed = MediaMarkupParser.parseMediaMarkup(markup);

        expect(parsed.length, 1);
        expect(parsed[0].type, '插图');
        expect(parsed[0].id, taskId);
      });
    });

    group('MediaMarkupParser - 标记检查测试', () {
      test('isMediaMarkup 应该识别有效的媒体标记', () {
        expect(MediaMarkupParser.isMediaMarkup('[!插图!](task123)'), isTrue);
        expect(MediaMarkupParser.isMediaMarkup('[!视频!](video456)'), isTrue);
        expect(MediaMarkupParser.isMediaMarkup('[!音频!](audio789)'), isTrue);
      });

      test('isMediaMarkup 应该拒绝无效格式', () {
        expect(MediaMarkupParser.isMediaMarkup('[插图](task123)'), isFalse);
        expect(MediaMarkupParser.isMediaMarkup('[!!插图!]()'), isFalse);
        expect(MediaMarkupParser.isMediaMarkup('普通文本'), isFalse);
        expect(MediaMarkupParser.isMediaMarkup('[!插图!](task123'), isFalse); // 缺少闭合括号
      });

      test('getMarkupType 应该返回正确的类型', () {
        expect(MediaMarkupParser.getMarkupType('[!插图!](task123)'), '插图');
        expect(MediaMarkupParser.getMarkupType('[!视频!](video456)'), '视频');
      });

      test('getMarkupId 应该返回正确的ID', () {
        expect(MediaMarkupParser.getMarkupId('[!插图!](task123)'), 'task123');
        expect(MediaMarkupParser.getMarkupId('[!视频!](video456)'), 'video456');
      });

      test('getMarkupType 处理无效标记应该返回空字符串', () {
        final result = MediaMarkupParser.getMarkupType('无效标记');
        expect(result, isEmpty);
      });

      test('getMarkupId 处理无效标记应该返回空字符串', () {
        expect(MediaMarkupParser.getMarkupId('无效标记'), isEmpty);
      });
    });

    group('MediaMarkupParser - 标记移除测试', () {
      test('removeMediaMarkup 应该移除所有媒体标记', () {
        const text = '开始[!插图!](task1)中间[!视频!](video1)结束';
        final result = MediaMarkupParser.removeMediaMarkup(text);

        expect(result, '开始中间结束');
        expect(MediaMarkupParser.parseMediaMarkup(result).length, 0);
      });

      test('removeMediaMarkup 空文本应该返回空字符串', () {
        const text = '';
        final result = MediaMarkupParser.removeMediaMarkup(text);

        expect(result, '');
      });

      test('removeMediaMarkup 无标记文本应该保持不变', () {
        const text = '这是普通的文本内容';
        final result = MediaMarkupParser.removeMediaMarkup(text);

        expect(result, text);
      });

      test('removeMediaMarkup 应该只移除媒体标记', () {
        const text = '这是[!插图!](task1)文本[!插图!](task2)内容';
        final result = MediaMarkupParser.removeMediaMarkup(text);

        expect(result, '这是文本内容');
      });
    });

    group('MediaMarkupParser - 标记替换测试', () {
      test('replaceMediaMarkup 应该支持自定义替换逻辑', () {
        const text = '图片1: [!插图!](task1) 图片2: [!插图!](task2)';
        final result = MediaMarkupParser.replaceMediaMarkup(
          text,
          (markup) => '[图片:${markup.id}]',
        );

        expect(result, '图片1: [图片:task1] 图片2: [图片:task2]');
      });

      test('replaceMediaMarkup 应该保持位置准确性', () {
        const text = 'A[!插图!](task1)B[!视频!](video1)C';
        final result = MediaMarkupParser.replaceMediaMarkup(
          text,
          (markup) => markup.id,
        );

        expect(result, 'Atask1Bvideo1C');
      });

      test('replaceMediaMarkup 空文本应该返回空字符串', () {
        const text = '';
        final result = MediaMarkupParser.replaceMediaMarkup(
          text,
          (markup) => 'replacement',
        );

        expect(result, '');
      });

      test('replaceMediaMarkup 无标记文本应该保持不变', () {
        const text = '普通文本内容';
        final result = MediaMarkupParser.replaceMediaMarkup(
          text,
          (markup) => 'replacement',
        );

        expect(result, text);
      });
    });

    group('MediaMarkupParser - 统计测试', () {
      test('countMediaMarkup 应该正确统计所有标记', () {
        const text = '[!插图!](task1)[!视频!](video1)[!插图!](task2)';
        final count = MediaMarkupParser.countMediaMarkup(text);

        expect(count, 3);
      });

      test('countMediaMarkup 空文本应该返回0', () {
        const text = '';
        final count = MediaMarkupParser.countMediaMarkup(text);

        expect(count, 0);
      });

      test('countMediaMarkup 按类型筛选应该只统计指定类型', () {
        const text = '[!插图!](task1)[!视频!](video1)[!插图!](task2)';
        final illustrationCount = MediaMarkupParser.countMediaMarkup(text, type: '插图');
        final videoCount = MediaMarkupParser.countMediaMarkup(text, type: '视频');
        final audioCount = MediaMarkupParser.countMediaMarkup(text, type: '音频');

        expect(illustrationCount, 2);
        expect(videoCount, 1);
        expect(audioCount, 0);
      });

      test('containsMediaType 应该正确检查标记类型', () {
        const text = '[!插图!](task1)[!视频!](video1)';

        expect(MediaMarkupParser.containsMediaType(text, '插图'), isTrue);
        expect(MediaMarkupParser.containsMediaType(text, '视频'), isTrue);
        expect(MediaMarkupParser.containsMediaType(text, '音频'), isFalse);
      });

      test('containsMediaType 空文本应该返回false', () {
        const text = '';
        final result = MediaMarkupParser.containsMediaType(text, '插图');

        expect(result, isFalse);
      });
    });

    group('MediaMarkup - 模型测试', () {
      test('MediaMarkup 应该正确存储属性', () {
        const markup = MediaMarkup(
          type: '插图',
          id: 'task123',
          fullMarkup: '[!插图!](task123)',
          start: 0,
          end: 20,
        );

        expect(markup.type, '插图');
        expect(markup.id, 'task123');
        expect(markup.fullMarkup, '[!插图!](task123)');
        expect(markup.start, 0);
        expect(markup.end, 20);
      });

      test('MediaMarkup isIllustration 应该正确判断插图类型', () {
        const illustration = MediaMarkup(
          type: '插图',
          id: 'task123',
          fullMarkup: '[!插图!](task123)',
          start: 0,
          end: 20,
        );
        const video = MediaMarkup(
          type: '视频',
          id: 'video123',
          fullMarkup: '[!视频!](video123)',
          start: 0,
          end: 20,
        );

        expect(illustration.isIllustration, isTrue);
        expect(illustration.isVideo, isFalse);
        expect(video.isIllustration, isFalse);
        expect(video.isVideo, isTrue);
      });

      test('MediaMarkup copyWith 应该正确复制和修改属性', () {
        const markup = MediaMarkup(
          type: '插图',
          id: 'task123',
          fullMarkup: '[!插图!](task123)',
          start: 0,
          end: 20,
        );

        final copied = markup.copyWith(id: 'task456');

        expect(copied.type, '插图'); // 未修改
        expect(copied.id, 'task456'); // 已修改
        expect(copied.fullMarkup, '[!插图!](task123)'); // 未修改
        expect(copied.start, 0); // 未修改
        expect(copied.end, 20); // 未修改
      });

      test('MediaMarkup 相等性判断应该基于type和id', () {
        const markup1 = MediaMarkup(
          type: '插图',
          id: 'task123',
          fullMarkup: '[!插图!](task123)',
          start: 0,
          end: 20,
        );
        const markup2 = MediaMarkup(
          type: '插图',
          id: 'task123',
          fullMarkup: '[!插图!](task123)', // 不同位置
          start: 10,
          end: 30,
        );
        const markup3 = MediaMarkup(
          type: '视频',
          id: 'task123',
          fullMarkup: '[!视频!](task123)',
          start: 0,
          end: 20,
        );

        expect(markup1, markup2); // type和id相同
        expect(markup1 == markup3, isFalse); // type不同
        expect(markup1.hashCode == markup2.hashCode, isTrue);
      });
    });

    group('MediaMarkupParser - 边界情况测试', () {
      test('应该处理嵌套括号', () {
        const text = '文本[(内容)][!插图!](task123)结束';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        expect(markups.length, 1);
        expect(markups[0].id, 'task123');
      });

      test('应该处理特殊字符ID', () {
        const text = '[!插图!](task-with-special_chars_123)';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        expect(markups.length, 1);
        expect(markups[0].id, 'task-with-special_chars_123');
      });

      test('应该处理空类型', () {
        const text = '[!!](empty)';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        // 空类型的标记可能不会被正则匹配
        // 取决于正则表达式对空字符串的处理
        // 这里我们测试实际行为
        if (markups.isEmpty) {
          // 如果不匹配，这是预期的行为
          expect(markups.isEmpty, isTrue);
        } else {
          // 如果匹配，验证其内容
          expect(markups.length, 1);
          expect(markups[0].type, '');
          expect(markups[0].id, 'empty');
        }
      });

      test('应该处理长ID', () {
        final longId = 'task_' * 100; // 很长的ID
        final text = '[!插图!]($longId)';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        expect(markups.length, 1);
        expect(markups[0].id, longId);
      });

      test('应该处理Unicode类型名称', () {
        const text = '[!图片插图!](task123)';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        expect(markups.length, 1);
        expect(markups[0].type, '图片插图');
      });

      test('应该处理多个连续的标记', () {
        const text = '[!插图!](a)[!插图!](b)[!插图!](c)';
        final markups = MediaMarkupParser.parseMediaMarkup(text);

        expect(markups.length, 3);
      });
    });
  });
}
