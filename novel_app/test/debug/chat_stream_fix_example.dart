/// 沉浸式对话流式解析修复示例
///
/// 演示如何使用新的状态机解析器处理跨chunk的XML标签

import 'package:novel_app/models/chat_message.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/utils/chat_stream_parser.dart';

void main() {
  print('=== 沉浸式对话流式解析修复示例 ===\n');

  // 创建测试角色
  final zhangSan = Character(
    id: 1,
    novelUrl: 'test_novel',
    name: '张三',
    gender: '男',
    age: 25,
    personality: '开朗',
  );

  final liSi = Character(
    id: 2,
    novelUrl: 'test_novel',
    name: '李四',
    gender: '女',
    age: 23,
    personality: '温柔',
  );

  final characters = [zhangSan, liSi];

  // 示例1: 标签被分割的情况
  print('示例1: 开放标签被分割');
  print('输入chunks: ["<张", "三>你好</张三>"]');
  print('期望: 张三说"你好"\n');

  final chunks1 = ['<张', '三>你好</张三>'];
  List<ChatMessage> messages1 = [];
  bool inDialogue1 = false;
  final tagState1 = TagParserState();

  for (final chunk in chunks1) {
    final result = ChatStreamParser.parseChunkForMultiRole(
      chunk,
      messages1,
      characters,
      inDialogue1,
      tagState: tagState1,
    );
    messages1 = result.messages;
    inDialogue1 = result.inDialogue;
  }

  print('输出结果:');
  for (final msg in messages1) {
    print('  - ${msg.type}: "${msg.content}" (角色: ${msg.character?.name ?? "无"})');
  }
  print('状态: ${inDialogue1 ? "对话中" : "旁白"}\n');

  // 示例2: 复杂场景（多个标签被分割）
  print('示例2: 复杂场景（Dify真实模拟）');
  print('输入chunks: ["夜色降临，", "<张", "三>老板，来杯酒！</", "张三>"]');
  print('期望: 旁白 + 张三对话\n');

  final chunks2 = [
    '夜色降临，',
    '<张',
    '三>老板，来杯酒！</',
    '张三>',
  ];
  List<ChatMessage> messages2 = [];
  bool inDialogue2 = false;
  final tagState2 = TagParserState();

  for (final chunk in chunks2) {
    final result = ChatStreamParser.parseChunkForMultiRole(
      chunk,
      messages2,
      characters,
      inDialogue2,
      tagState: tagState2,
    );
    messages2 = result.messages;
    inDialogue2 = result.inDialogue;
  }

  print('输出结果:');
  for (final msg in messages2) {
    print('  - ${msg.type}: "${msg.content}" (角色: ${msg.character?.name ?? "无"})');
  }
  print('状态: ${inDialogue2 ? "对话中" : "旁白"}\n');

  // 示例3: 多角色切换（标签完整）
  print('示例3: 多角色切换（向后兼容）');
  print('输入chunks: ["<张三>你好</张三><李四>嗨</李四>"]');
  print('期望: 张三对话 + 李四对话\n');

  final chunks3 = ['<张三>你好</张三><李四>嗨</李四>'];
  List<ChatMessage> messages3 = [];
  bool inDialogue3 = false;
  final tagState3 = TagParserState();

  for (final chunk in chunks3) {
    final result = ChatStreamParser.parseChunkForMultiRole(
      chunk,
      messages3,
      characters,
      inDialogue3,
      tagState: tagState3,
    );
    messages3 = result.messages;
    inDialogue3 = result.inDialogue;
  }

  print('输出结果:');
  for (final msg in messages3) {
    print('  - ${msg.type}: "${msg.content}" (角色: ${msg.character?.name ?? "无"})');
  }
  print('状态: ${inDialogue3 ? "对话中" : "旁白"}\n');

  // 示例4: 状态重置
  print('示例4: 状态重置（多轮对话）');
  print('第一轮: ["<张三>你好</张三>"]');
  print('第二轮: ["<李四>嗨</李四>"]');
  print('期望: 第一轮张三，第二轮李四\n');

  final tagState4 = TagParserState();

  // 第一轮
  List<ChatMessage> messages4a = [];
  bool inDialogue4a = false;

  final chunks4a = ['<张三>你好</张三>'];
  for (final chunk in chunks4a) {
    final result = ChatStreamParser.parseChunkForMultiRole(
      chunk,
      messages4a,
      characters,
      inDialogue4a,
      tagState: tagState4,
    );
    messages4a = result.messages;
    inDialogue4a = result.inDialogue;
  }

  print('第一轮输出:');
  for (final msg in messages4a) {
    print('  - ${msg.type}: "${msg.content}" (角色: ${msg.character?.name ?? "无"})');
  }

  // 重置状态
  tagState4.reset();
  print('（状态已重置）\n');

  // 第二轮
  List<ChatMessage> messages4b = [];
  bool inDialogue4b = false;

  final chunks4b = ['<李四>嗨</李四>'];
  for (final chunk in chunks4b) {
    final result = ChatStreamParser.parseChunkForMultiRole(
      chunk,
      messages4b,
      characters,
      inDialogue4b,
      tagState: tagState4,
    );
    messages4b = result.messages;
    inDialogue4b = result.inDialogue;
  }

  print('第二轮输出:');
  for (final msg in messages4b) {
    print('  - ${msg.type}: "${msg.content}" (角色: ${msg.character?.name ?? "无"})');
  }
  print('\n=== 示例完成 ===');
}
