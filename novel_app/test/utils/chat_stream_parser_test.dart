import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/chat_message.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/utils/chat_stream_parser.dart';

void main() {
  group('ChatStreamParser.parseChunkForMultiRole', () {
    final characters = [
      Character(novelUrl: '', name: '角色A'),
      Character(novelUrl: '', name: '角色B'),
      Character(novelUrl: '', name: '角色C'),
    ];

    test('应该解析旁白', () {
      final result = ChatStreamParser.parseChunkForMultiRole(
        '这是旁白内容',
        [],
        characters,
        false,
      );

      expect(result.messages.length, 1);
      expect(result.messages.first.type, 'narration');
      expect(result.messages.first.content, '这是旁白内容');
      expect(result.inDialogue, false);
    });

    test('应该解析角色对话', () {
      final result = ChatStreamParser.parseChunkForMultiRole(
        '<角色A>你好</角色A>',
        [],
        characters,
        false,
      );

      expect(result.messages.length, 1);
      expect(result.messages.first.type, 'dialogue');
      expect(result.messages.first.character?.name, '角色A');
      expect(result.messages.first.content, '你好');
      expect(result.inDialogue, false);
    });

    test('应该解析多角色对话', () {
      final result = ChatStreamParser.parseChunkForMultiRole(
        '旁白<角色A>你好</角色A>旁白<角色B>你好</角色B>',
        [],
        characters,
        false,
      );

      expect(result.messages.length, 4);
      expect(result.messages[0].type, 'narration');
      expect(result.messages[0].content, '旁白');

      expect(result.messages[1].type, 'dialogue');
      expect(result.messages[1].character?.name, '角色A');
      expect(result.messages[1].content, '你好');

      expect(result.messages[2].type, 'narration');
      expect(result.messages[2].content, '旁白');

      expect(result.messages[3].type, 'dialogue');
      expect(result.messages[3].character?.name, '角色B');
      expect(result.messages[3].content, '你好');
    });

    test('应该处理流式更新', () {
      // 第一次接收
      var result = ChatStreamParser.parseChunkForMultiRole(
        '<角色A>你',
        [],
        characters,
        false,
      );

      expect(result.messages.length, 1);
      expect(result.messages.first.content, '你');
      expect(result.inDialogue, true);

      // 第二次接收
      result = ChatStreamParser.parseChunkForMultiRole(
        '好',
        result.messages,
        characters,
        result.inDialogue,
      );

      expect(result.messages.length, 1);
      expect(result.messages.first.content, '你好');
      expect(result.inDialogue, true);

      // 第三次接收
      result = ChatStreamParser.parseChunkForMultiRole(
        '</角色A>',
        result.messages,
        characters,
        result.inDialogue,
      );

      expect(result.messages.length, 1);
      expect(result.messages.first.content, '你好');
      expect(result.inDialogue, false);
    });

    test('应该处理未闭合的标签', () {
      final result = ChatStreamParser.parseChunkForMultiRole(
        '<角色A>你好',
        [],
        characters,
        false,
      );

      expect(result.messages.length, 1);
      expect(result.messages.first.type, 'dialogue');
      expect(result.messages.first.character?.name, '角色A');
      expect(result.messages.first.content, '你好');
      expect(result.inDialogue, true);
    });

    test('应该处理未知角色标签', () {
      final result = ChatStreamParser.parseChunkForMultiRole(
        '旁白<未知角色>你好</未知角色>旁白',
        [],
        characters,
        false,
      );

      // 未知角色标签会被作为旁白处理
      expect(result.messages.length, 1);
      expect(result.messages[0].type, 'narration');
      expect(result.messages[0].content, '旁白<未知角色>你好</未知角色>旁白');
    });

    test('应该处理多角色混合对话', () {
      final result = ChatStreamParser.parseChunkForMultiRole(
        '今天天气真好<角色A>是的</角色A><角色B>我们出去走走吧</角色B><角色A>好主意</角色A>',
        [],
        characters,
        false,
      );

      // 解析结果应该是4条消息：
      // [0] narration: "今天天气真好"
      // [1] dialogue: "是的" (角色A)
      // [2] dialogue: "我们出去走走吧" (角色B)
      // [3] dialogue: "好主意" (角色A)

      expect(result.messages.length, 4);

      expect(result.messages[0].type, 'narration');
      expect(result.messages[0].content, '今天天气真好');

      expect(result.messages[1].type, 'dialogue');
      expect(result.messages[1].character?.name, '角色A');
      expect(result.messages[1].content, '是的');

      expect(result.messages[2].type, 'dialogue');
      expect(result.messages[2].character?.name, '角色B');
      expect(result.messages[2].content, '我们出去走走吧');

      expect(result.messages[3].type, 'dialogue');
      expect(result.messages[3].character?.name, '角色A');
      expect(result.messages[3].content, '好主意');
    });

    test('应该处理标签不匹配的情况', () {
      final result = ChatStreamParser.parseChunkForMultiRole(
        '<角色A>你好</角色B>', // 错误的闭合标签
        [],
        characters,
        false,
      );

      // </角色B> 不匹配当前角色(角色A)，所以会作为普通文本处理
      // 并且对话状态会继续（因为currentCharacter还是角色A）
      expect(result.messages.length, 1);
      expect(result.messages[0].type, 'dialogue');
      expect(result.messages[0].character?.name, '角色A');
      expect(result.messages[0].content, '你好</角色B>');
      expect(result.inDialogue, true); // 对话状态未结束
    });
  });
}
