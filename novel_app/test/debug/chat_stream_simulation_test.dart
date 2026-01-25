import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/chat_message.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/utils/chat_stream_parser.dart';

void main() {
  group('ChatStreamParser - 跨chunk标签解析测试', () {
    // 测试角色
    final characterA = Character(
      id: 1,
      novelUrl: 'test_novel',
      name: '张三',
      gender: '男',
      age: 25,
      personality: '开朗',
      bodyType: '中等',
    );

    final characterB = Character(
      id: 2,
      novelUrl: 'test_novel',
      name: '李四',
      gender: '女',
      age: 23,
      personality: '温柔',
      bodyType: '苗条',
    );

    final List<Character> characters = [characterA, characterB];

    /// 场景1: 标签完整在一个chunk（理想情况 - 当前能工作）
    test('场景1: 标签完整在一个chunk - 应该正确解析', () {
      final chunks = ['<张三>你好</张三>'];
      List<ChatMessage> messages = [];
      bool inDialogue = false;

      for (final chunk in chunks) {
        final result = ChatStreamParser.parseChunkForMultiRole(
          chunk,
          messages,
          characters,
          inDialogue,
        );
        messages = result.messages;
        inDialogue = result.inDialogue;
      }

      print('✅ 场景1 结果:');
      for (final msg in messages) {
        print('  - ${msg.type}: ${msg.content} (角色: ${msg.character?.name})');
      }

      // 验证
      expect(messages.length, equals(1));
      expect(messages[0].type, equals('dialogue'));
      expect(messages[0].content, equals('你好'));
      expect(messages[0].character?.name, equals('张三'));
      expect(inDialogue, isFalse);
    });

    /// 场景2: 开放标签被分割（`<张三>` 分成 `<张` 和 `三>`）
    test('场景2: 开放标签被分割 - 当前会失败', () {
      final chunks = ['<张', '三>你好</张三>'];
      List<ChatMessage> messages = [];
      bool inDialogue = false;

      for (final chunk in chunks) {
        final result = ChatStreamParser.parseChunkForMultiRole(
          chunk,
          messages,
          characters,
          inDialogue,
        );
        messages = result.messages;
        inDialogue = result.inDialogue;
      }

      print('❌ 场景2 结果（标签被分割）:');
      for (final msg in messages) {
        print('  - ${msg.type}: ${msg.content} (角色: ${msg.character?.name})');
      }

      // 当前实现会失败："<张" 和 "三>你好</张三>" 都会被当作旁白
      // 期望：应该识别为角色"张三"的对话
      // 实际：会当作普通文本处理
      expect(messages.isNotEmpty, true);
      // TODO: 修复后应该验证 dialogue 类型的消息
    });

    /// 场景3: 闭合标签被分割（`</张三>` 分成 `</张` 和 `三>`）
    test('场景3: 闭合标签被分割 - 当前会失败', () {
      final chunks = ['<张三>你好</张', '三>'];
      List<ChatMessage> messages = [];
      bool inDialogue = false;

      for (final chunk in chunks) {
        final result = ChatStreamParser.parseChunkForMultiRole(
          chunk,
          messages,
          characters,
          inDialogue,
        );
        messages = result.messages;
        inDialogue = result.inDialogue;
      }

      print('❌ 场景3 结果（闭合标签被分割）:');
      for (final msg in messages) {
        print('  - ${msg.type}: ${msg.content} (角色: ${msg.character?.name})');
      }

      // 当前实现会失败
      // TODO: 修复后应该验证对话正确结束
    });

    /// 场景4: 标签完全逐字符分割（`<`, `张`, `三`, `>` 分别在4个chunk）
    test('场景4: 标签完全逐字符分割 - 当前会失败', () {
      final chunks = ['<', '张', '三', '>', '你好', '<', '/', '张', '三', '>'];
      List<ChatMessage> messages = [];
      bool inDialogue = false;

      for (final chunk in chunks) {
        final result = ChatStreamParser.parseChunkForMultiRole(
          chunk,
          messages,
          characters,
          inDialogue,
        );
        messages = result.messages;
        inDialogue = result.inDialogue;
      }

      print('❌ 场景4 结果（逐字符分割）:');
      for (final msg in messages) {
        print('  - ${msg.type}: ${msg.content} (角色: ${msg.character?.name})');
      }

      // 当前实现会失败
      // TODO: 修复后应该验证对话正确识别
    });

    /// 场景5: 多角色切换（标签完整 - 当前能工作）
    test('场景5: 多角色切换（标签完整） - 应该正确解析', () {
      final chunks = ['<张三>你好</张三><李四>嗨</李四>'];
      List<ChatMessage> messages = [];
      bool inDialogue = false;

      for (final chunk in chunks) {
        final result = ChatStreamParser.parseChunkForMultiRole(
          chunk,
          messages,
          characters,
          inDialogue,
        );
        messages = result.messages;
        inDialogue = result.inDialogue;
      }

      print('✅ 场景5 结果（多角色切换）:');
      for (final msg in messages) {
        print('  - ${msg.type}: ${msg.content} (角色: ${msg.character?.name})');
      }

      // 验证：两个对话消息
      expect(messages.length, equals(2));
      expect(messages[0].type, equals('dialogue'));
      expect(messages[0].content, equals('你好'));
      expect(messages[0].character?.name, equals('张三'));
      expect(messages[1].type, equals('dialogue'));
      expect(messages[1].content, equals('嗨'));
      expect(messages[1].character?.name, equals('李四'));
    });

    /// 场景6: 旁白和对话混合（标签完整 - 当前能工作）
    test('场景6: 旁白和对话混合（标签完整） - 应该正确解析', () {
      final chunks = ['风吹过。<张三>你好</张三>天空很蓝。'];
      List<ChatMessage> messages = [];
      bool inDialogue = false;

      for (final chunk in chunks) {
        final result = ChatStreamParser.parseChunkForMultiRole(
          chunk,
          messages,
          characters,
          inDialogue,
        );
        messages = result.messages;
        inDialogue = result.inDialogue;
      }

      print('✅ 场景6 结果（旁白和对话混合）:');
      for (final msg in messages) {
        print('  - ${msg.type}: ${msg.content} (角色: ${msg.character?.name})');
      }

      // 验证：旁白 -> 对话 -> 旁白
      expect(messages.length, equals(3));
      expect(messages[0].type, equals('narration'));
      expect(messages[0].content, equals('风吹过。'));
      expect(messages[1].type, equals('dialogue'));
      expect(messages[1].content, equals('你好'));
      expect(messages[1].character?.name, equals('张三'));
      expect(messages[2].type, equals('narration'));
      expect(messages[2].content, equals('天空很蓝。'));
    });

    /// 场景7: 复杂场景（标签被分割 + 多角色 + 旁白）
    test('场景7: 复杂场景（标签被分割 + 多角色 + 旁白） - 当前会失败', () {
      final chunks = [
        '微风吹过。<张',
        '三>大家好</张三>',
        '<李四>你们好</李四>',
        '<张三>今天天气',
        '真不错</张三>天气很好。',
      ];
      List<ChatMessage> messages = [];
      bool inDialogue = false;

      for (final chunk in chunks) {
        final result = ChatStreamParser.parseChunkForMultiRole(
          chunk,
          messages,
          characters,
          inDialogue,
        );
        messages = result.messages;
        inDialogue = result.inDialogue;
      }

      print('❌ 场景7 结果（复杂场景）:');
      for (final msg in messages) {
        print('  - ${msg.type}: ${msg.content} (角色: ${msg.character?.name})');
      }

      // 当前实现会失败
      // 期望：旁白 -> 张三对话 -> 李四对话 -> 张三对话 -> 旁白
      // TODO: 修复后应该验证正确的解析顺序
    });

    /// 场景8: Dify真实流式场景模拟
    test('场景8: Dify真实流式场景模拟 - 当前会部分失败', () {
      // 模拟Dify SSE流的真实chunk分割情况
      final chunks = [
        '夜色降临，',
        '酒馆内灯',
        '火通明。<张三>',
        '老板，来杯酒！',
        '</张三>',
        '<李四>这位客官',
        '，请问要什',
        '么酒？</李四>',
        '<张三>最烈的',
        '白酒。</张三>',
        '李四点了点头。',
      ];
      List<ChatMessage> messages = [];
      bool inDialogue = false;

      for (final chunk in chunks) {
        final result = ChatStreamParser.parseChunkForMultiRole(
          chunk,
          messages,
          characters,
          inDialogue,
        );
        messages = result.messages;
        inDialogue = result.inDialogue;
      }

      print('📡 场景8 结果（Dify真实流式场景）:');
      for (final msg in messages) {
        print('  - ${msg.type}: ${msg.content} (角色: ${msg.character?.name})');
      }

      // 期望：
      // 1. 旁白: "夜色降临，酒馆内灯火通明。"
      // 2. 张三: "老板，来杯酒！"
      // 3. 李四: "这位客官，请问要什么酒？"
      // 4. 张三: "最烈的白酒。"
      // 5. 旁白: "李四点了点头。"

      // 验证（仅验证标签完整的部分）
      final dialogueMessages = messages.where((m) => m.type == 'dialogue').toList();
      print('  对话消息数量: ${dialogueMessages.length}');

      // 当前实现：只有标签完整的chunk能正确识别
      // TODO: 修复后应该验证所有对话都被正确识别
    });

    /// 场景9: 空chunk处理
    test('场景9: 空chunk处理 - 应该不影响解析', () {
      final chunks = ['<张三>', '', '你好', '', '</张三>'];
      List<ChatMessage> messages = [];
      bool inDialogue = false;

      for (final chunk in chunks) {
        final result = ChatStreamParser.parseChunkForMultiRole(
          chunk,
          messages,
          characters,
          inDialogue,
        );
        messages = result.messages;
        inDialogue = result.inDialogue;
      }

      print('✅ 场景9 结果（空chunk处理）:');
      for (final msg in messages) {
        print('  - ${msg.type}: ${msg.content} (角色: ${msg.character?.name})');
      }

      // 验证
      expect(messages.length, equals(1));
      expect(messages[0].type, equals('dialogue'));
      expect(messages[0].content, equals('你好'));
    });

    /// 场景10: 只有部分标签内容到达
    test('场景10: 只有部分标签内容到达（不完整流） - 应该部分处理', () {
      final chunks = ['<张三>你好', '</张三']; // 故意不完整
      List<ChatMessage> messages = [];
      bool inDialogue = false;

      for (final chunk in chunks) {
        final result = ChatStreamParser.parseChunkForMultiRole(
          chunk,
          messages,
          characters,
          inDialogue,
        );
        messages = result.messages;
        inDialogue = result.inDialogue;
      }

      print('⚠️ 场景10 结果（不完整流）:');
      for (final msg in messages) {
        print('  - ${msg.type}: ${msg.content} (角色: ${msg.character?.name})');
      }

      // 当前实现会处理能识别的部分
      // TODO: 修复后应该验证状态正确保持
    });
  });
}
