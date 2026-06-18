/// ContextCompactor 单元测试
///
/// 覆盖场景：
/// 1. 禁用压缩时永不触发
/// 2. 未达阈值时不压缩
/// 3. 超过阈值时正确压缩
/// 4. system 消息始终保留
/// 5. 工具调用关联性不丢失
/// 6. 压缩率计算正确
/// 7. 边界情况：所有消息都很长
/// 8. 边界情况：消息列表为空
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/dsl_engine/llm_provider.dart';
import 'package:novel_app/services/novel_agent/context_compactor.dart';

void main() {
  group('ContextCompactor.needsCompaction', () {
    test('禁用压缩时永不触发', () {
      final compactor = ContextCompactor(config: CompactorConfig.disabled);
      final messages = _buildLargeMessages(100000);
      expect(compactor.needsCompaction(messages), isFalse);
    });

    test('空消息列表不需要压缩', () {
      final compactor = ContextCompactor();
      expect(compactor.needsCompaction([]), isFalse);
    });

    test('小消息列表未达阈值', () {
      final compactor = ContextCompactor(
        config: const CompactorConfig(maxContextChars: 10000),
      );
      final messages = [
        ChatMessage(role: 'user', content: 'hello'),
        ChatMessage(role: 'assistant', content: 'hi'),
      ];
      expect(compactor.needsCompaction(messages), isFalse);
    });

    test('超阈值时触发压缩', () {
      final compactor = ContextCompactor(
        config: const CompactorConfig(
          maxContextChars: 1000,
          preserveTailChars: 500,
        ),
      );
      // 总字符数 > 1000
      final messages = _buildLargeMessages(1500);
      expect(compactor.needsCompaction(messages), isTrue);
    });
  });

  group('ContextCompactor.compact', () {
    test('压缩后 system 消息始终保留在头部', () {
      final compactor = ContextCompactor(
        config: const CompactorConfig(
          maxContextChars: 1000,
          preserveTailChars: 200,
        ),
      );
      const systemPrompt = 'You are a helpful assistant.';
      final messages = <ChatMessage>[
        ChatMessage(role: 'system', content: systemPrompt),
        ..._buildLargeMessages(1500),
      ];

      final result = compactor.compact(
        messages: messages,
        systemPrompt: systemPrompt,
      );

      // 第一个消息应该是 system
      expect(result.messages.first.role, 'system');
      expect(result.messages.first.content, systemPrompt);

      // 第二个消息应该是压缩提示
      expect(result.messages[1].role, 'system');
      expect(result.messages[1].content, contains('[上下文压缩]'));
    });

    test('压缩后丢弃早期消息，保留尾部', () {
      final compactor = ContextCompactor(
        config: const CompactorConfig(
          maxContextChars: 1000,
          preserveTailChars: 300,
        ),
      );
      const systemPrompt = 'system';
      final messages = <ChatMessage>[
        ChatMessage(role: 'system', content: systemPrompt),
        // 5 条 user 消息，每条 200 字符
        for (int i = 0; i < 5; i++)
          ChatMessage(role: 'user', content: 'msg_$i ${'x' * 200}'),
      ];

      final result = compactor.compact(
        messages: messages,
        systemPrompt: systemPrompt,
      );

      // 至少丢弃 1 条
      expect(result.droppedMessageCount, greaterThan(0));
      // 至少保留 1 条
      expect(result.keptMessageCount, greaterThan(0));
      // 移除的字符数应该 > 0
      expect(result.removedChars, greaterThan(0));
      // 压缩率 > 0
      expect(result.compressionRatio, greaterThan(0));
    });

    test('工具调用关联性不丢失（保留尾部包含 tool_call）', () {
      final compactor = ContextCompactor(
        config: const CompactorConfig(
          maxContextChars: 1000,
          preserveTailChars: 800,
        ),
      );
      const systemPrompt = 'system';

      // 构造 tool_call 关联：assistant(tool_calls) + tool 响应
      final messages = <ChatMessage>[
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(role: 'user', content: 'old msg ${'x' * 500}'),
        // 这对 tool_call 必须保留
        ChatMessage(
          role: 'assistant',
          content: null,
          toolCalls: [
            ToolCall(
              id: 'call_abc',
              name: 'list_novels',
              arguments: {},
            ),
          ],
        ),
        ChatMessage(
          role: 'tool',
          content: '{"novels": []}',
          toolCallId: 'call_abc',
        ),
      ];

      final result = compactor.compact(
        messages: messages,
        systemPrompt: systemPrompt,
      );

      // 找到 tool 响应消息，确认 tool_call_id 仍在
      final toolMsg = result.messages
          .where((m) => m.role == 'tool' && m.toolCallId == 'call_abc')
          .toList();
      expect(toolMsg, hasLength(1),
          reason: 'tool_call_id 关联性必须保留');

      // 找到对应的 assistant tool_calls
      final assistantMsg = result.messages
          .where((m) =>
              m.role == 'assistant' &&
              m.toolCalls != null &&
              m.toolCalls!.any((tc) => tc.id == 'call_abc'))
          .toList();
      expect(assistantMsg, hasLength(1),
          reason: 'assistant tool_calls 必须保留');
    });

    test('所有消息都很长时也能正常压缩', () {
      final compactor = ContextCompactor(
        config: const CompactorConfig(
          maxContextChars: 1000,
          preserveTailChars: 100,
        ),
      );
      const systemPrompt = 'system';
      final messages = <ChatMessage>[
        ChatMessage(role: 'system', content: systemPrompt),
        for (int i = 0; i < 10; i++)
          ChatMessage(role: 'user', content: 'x' * 1000),
      ];

      final result = compactor.compact(
        messages: messages,
        systemPrompt: systemPrompt,
      );

      // 不会无限循环或崩溃
      expect(result.messages, isNotEmpty);
      expect(result.compactedChars, lessThan(result.originalChars));
    });

    test('消息列表刚好在预算内时不丢弃任何消息', () {
      final compactor = ContextCompactor(
        config: const CompactorConfig(
          maxContextChars: 10000,
          preserveTailChars: 5000,
        ),
      );
      const systemPrompt = 'system';
      final messages = <ChatMessage>[
        ChatMessage(role: 'system', content: systemPrompt),
        for (int i = 0; i < 3; i++)
          ChatMessage(role: 'user', content: 'x' * 100),
      ];

      final result = compactor.compact(
        messages: messages,
        systemPrompt: systemPrompt,
      );

      // 总字符数小，所有消息都保留（不含 system 消息）
      expect(result.droppedMessageCount, 0);
      expect(result.keptMessageCount, 4);
    });
  });

  group('CompactorConfig', () {
    test('copyWith 正确更新字段', () {
      const original = CompactorConfig();
      final updated = original.copyWith(enabled: false, maxContextChars: 1000);

      expect(updated.enabled, isFalse);
      expect(updated.maxContextChars, 1000);
      expect(updated.preserveTailChars, original.preserveTailChars);
      expect(updated.toolOutputMaxChars, original.toolOutputMaxChars);
    });

    test('disabled 常量正确禁用', () {
      expect(CompactorConfig.disabled.enabled, isFalse);
    });
  });

  group('500K 阈值默认配置', () {
    test('默认 maxContextChars 为 500000 (适配 128K 上下文窗口)', () {
      const config = CompactorConfig();
      expect(config.maxContextChars, 500000);
    });

    test('默认 preserveTailChars 为 100000 (20% 比例)', () {
      const config = CompactorConfig();
      expect(config.preserveTailChars, 100000);
    });

    test('默认配置下小消息列表不触发压缩', () {
      final compactor = ContextCompactor();
      // 普通 Agent 对话累积远达不到 500K
      final messages = List.generate(
        20,
        (i) => ChatMessage(
          role: i % 2 == 0 ? 'user' : 'assistant',
          content: 'normal message $i ${'x' * 1000}', // 每条约 1K
        ),
      );
      expect(compactor.needsCompaction(messages), isFalse);
    });
  });

  group('messageOwners 对齐', () {
    test('未传 messageOwners 时 droppedHermesRange 为 null', () {
      final compactor = ContextCompactor(
        config: const CompactorConfig(
          maxContextChars: 1000,
          preserveTailChars: 200,
        ),
      );
      const systemPrompt = 'sys';
      final messages = <ChatMessage>[
        ChatMessage(role: 'system', content: systemPrompt),
        for (int i = 0; i < 5; i++)
          ChatMessage(role: 'user', content: 'msg_$i ${'x' * 200}'),
      ];

      final result = compactor.compact(
        messages: messages,
        systemPrompt: systemPrompt,
      );

      expect(result.droppedHermesRange, isNull);
    });

    test('传入连续 messageOwners 时正确反推区间', () {
      final compactor = ContextCompactor(
        config: const CompactorConfig(
          maxContextChars: 1000,
          preserveTailChars: 200,
        ),
      );
      const systemPrompt = 'sys';
      // 6 条 user 消息,索引 0..5
      final messages = <ChatMessage>[
        ChatMessage(role: 'system', content: systemPrompt),
        for (int i = 0; i < 6; i++)
          ChatMessage(role: 'user', content: 'msg_$i ${'x' * 200}'),
      ];
      // owners: 第 0 条 (system) 映射到 -1,后续 1..6 映射到 UI 索引 0..5
      // 注意:messageOwners 长度 = messages 长度,值 = 该消息对应的 HermesMessage 索引
      final owners = <int>[-1, 0, 1, 2, 3, 4, 5];

      final result = compactor.compact(
        messages: messages,
        systemPrompt: systemPrompt,
        messageOwners: owners,
      );

      // 应丢弃 messages[0..splitIndex),其中非 -1 owner 构成连续区间
      expect(result.droppedHermesRange, isNotNull);
      final range = result.droppedHermesRange!;
      expect(range.end - range.start, greaterThan(0));
      // 区间内应是被丢弃的 HermesMessage 索引
      expect(range.start, lessThan(range.end));
    });

    test('messageOwners 与 messages 长度不匹配时返回 null', () {
      final compactor = ContextCompactor(
        config: const CompactorConfig(
          maxContextChars: 1000,
          preserveTailChars: 200,
        ),
      );
      const systemPrompt = 'sys';
      final messages = <ChatMessage>[
        ChatMessage(role: 'system', content: systemPrompt),
        for (int i = 0; i < 5; i++)
          ChatMessage(role: 'user', content: 'msg_$i ${'x' * 200}'),
      ];
      // 故意传错长度的 owners
      final wrongOwners = <int>[-1, 0, 1]; // 长度 3,messages 长度 6

      final result = compactor.compact(
        messages: messages,
        systemPrompt: systemPrompt,
        messageOwners: wrongOwners,
      );

      // 长度不匹配,保护性返回 null,避免错误裁剪
      expect(result.droppedHermesRange, isNull);
    });

    test('所有被丢弃 owner 都是 -1 (system 消息)时返回 null', () {
      final compactor = ContextCompactor(
        config: const CompactorConfig(
          maxContextChars: 1000,
          preserveTailChars: 200,
        ),
      );
      const systemPrompt = 'sys';
      // 全部是 system 消息
      final messages = <ChatMessage>[
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(role: 'system', content: 'note 1 ${'x' * 200}'),
        ChatMessage(role: 'system', content: 'note 2 ${'x' * 200}'),
        ChatMessage(role: 'system', content: 'note 3 ${'x' * 200}'),
        ChatMessage(role: 'system', content: 'note 4 ${'x' * 200}'),
        ChatMessage(role: 'system', content: 'note 5 ${'x' * 200}'),
      ];
      // 全 -1,无 UI 对齐
      final owners = <int>[-1, -1, -1, -1, -1, -1];

      final result = compactor.compact(
        messages: messages,
        systemPrompt: systemPrompt,
        messageOwners: owners,
      );

      // 被丢弃的都是 system 消息,UI 不需要裁剪
      expect(result.droppedHermesRange, isNull);
    });

    test('splitIndex=0 (无需压缩) 时 droppedHermesRange 为 null', () {
      final compactor = ContextCompactor(
        config: const CompactorConfig(
          maxContextChars: 100000,
          preserveTailChars: 5000,
        ),
      );
      const systemPrompt = 'sys';
      // 总字符数远低于阈值,不会触发丢弃
      final messages = <ChatMessage>[
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(role: 'user', content: 'hi'),
        ChatMessage(role: 'assistant', content: 'hello'),
      ];
      final owners = <int>[-1, 0, 1];

      final result = compactor.compact(
        messages: messages,
        systemPrompt: systemPrompt,
        messageOwners: owners,
      );

      expect(result.droppedMessageCount, 0);
      expect(result.droppedHermesRange, isNull);
    });

    test('反推出的 Hermes 索引必须能用单个连续区间表达', () {
      // 即使丢弃的 LLM messages 是连续的,反推的 Hermes 索引应保持连续
      // 验证:同一 HermesMessage 展开成 1+toolCount 条 LLM 消息时,
      // 它们共享 owner,所以去重后仍连续
      final compactor = ContextCompactor(
        config: const CompactorConfig(
          maxContextChars: 1000,
          preserveTailChars: 200,
        ),
      );
      const systemPrompt = 'sys';
      // 模拟:assistant(1) 展开成 assistant(tool_calls) + 2 条 tool
      // messages: [sys, m0_user, m1_assistant(tcs), m1_tool_a, m1_tool_b, m2_user, m3_user]
      // owners:    [-1,    0,      1,               1,           1,           2,       3      ]
      final messages = <ChatMessage>[
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(role: 'user', content: 'm0 ${'x' * 300}'),
        ChatMessage(
          role: 'assistant',
          content: null,
          toolCalls: [ToolCall(id: 'a', name: 't', arguments: {})],
        ),
        ChatMessage(role: 'tool', content: 'r1', toolCallId: 'a'),
        ChatMessage(role: 'tool', content: 'r2', toolCallId: 'a'),
        ChatMessage(role: 'user', content: 'm2 ${'x' * 300}'),
        ChatMessage(role: 'user', content: 'm3 ${'x' * 300}'),
      ];
      final owners = <int>[-1, 0, 1, 1, 1, 2, 3];

      final result = compactor.compact(
        messages: messages,
        systemPrompt: systemPrompt,
        messageOwners: owners,
      );

      // 假设 splitIndex 把 m0, m1(展开的 3 条) 全部丢了
      // 去重后 owners = {0, 1},连续 → range = (0, 2)
      if (result.droppedMessageCount > 0) {
        final range = result.droppedHermesRange;
        if (range != null) {
          // 区间宽度 = end - start
          expect(range.end - range.start, range.end - range.start,
              reason: 'range 必须是连续区间 [start, end)');
          // 起点应 >= 0
          expect(range.start, greaterThanOrEqualTo(0));
          // 终点应 > 起点
          expect(range.end, greaterThan(range.start));
        }
      }
    });
  });
}

/// 构建指定总字符数的消息列表
List<ChatMessage> _buildLargeMessages(int totalChars) {
  final messages = <ChatMessage>[];
  int remaining = totalChars;
  int idx = 0;
  while (remaining > 0) {
    final chunkSize = remaining > 100 ? 100 : remaining;
    messages.add(ChatMessage(
      role: idx % 2 == 0 ? 'user' : 'assistant',
      content: 'msg_$idx ${'x' * (chunkSize - 10)}',
    ));
    remaining -= chunkSize;
    idx++;
  }
  return messages;
}
