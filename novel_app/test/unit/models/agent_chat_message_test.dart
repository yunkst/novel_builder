library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/agent_chat_message.dart';

void main() {
  group('AgentChatMessage ImageSegment 序列化', () {
    test('ImageSegment 序列化 round-trip', () {
      final msg = AgentChatMessage(
        role: AgentChatRole.user,
        segments: [
          const ImageSegment(mediaId: 'local_abc123'),
          const TextSegment('把这张图动起来'),
        ],
      );

      final json = msg.toJson();
      final restored = AgentChatMessage.fromJson(json);

      expect(restored.segments.length, 2);
      expect(restored.segments[0], isA<ImageSegment>());
      expect((restored.segments[0] as ImageSegment).mediaId, 'local_abc123');
      expect(restored.segments[1], isA<TextSegment>());
      expect((restored.segments[1] as TextSegment).content, '把这张图动起来');
    });

    test('老数据（纯 text）fromJson 兼容', () {
      final msg = AgentChatMessage.fromJson({
        'role': 'user',
        'content': '你好',
        'timestamp': 1700000000000,
        'segmentsJson': '[{"type":"text","content":"你好"}]',
      });

      expect(msg.segments.length, 1);
      expect(msg.segments[0], isA<TextSegment>());
      expect(msg.content, '你好');
    });

    test('老数据（纯 tool）fromJson 兼容', () {
      final msg = AgentChatMessage.fromJson({
        'role': 'assistant',
        'content': '',
        'timestamp': 1700000000000,
        'segmentsJson':
            '[{"type":"tool","id":"call_1","name":"create_images","arguments":"{\\"prompt\\":\\"cat\\"}","status":"running"}]',
      });

      expect(msg.segments.length, 1);
      expect(msg.segments[0], isA<ToolCallSegment>());
    });
  });
}
