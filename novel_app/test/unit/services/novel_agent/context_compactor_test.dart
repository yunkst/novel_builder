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
