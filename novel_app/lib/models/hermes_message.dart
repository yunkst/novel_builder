import '../services/novel_agent/agent_event.dart';

/// Hermes 聊天消息角色
enum HermesRole {
  system,
  user,
  assistant,
}

/// 消息内容片段（有序，保留时序关系）
///
/// assistant 消息由交替的 TextSegment 和 ToolCallSegment 组成，
/// 精确反映 Agent 的"思考 → 行动 → 思考"流程。
sealed class HermesSegment {
  const HermesSegment();
}

/// 文本片段（LLM 输出内容）
class TextSegment extends HermesSegment {
  final String content;
  const TextSegment(this.content);
}

/// 工具调用片段
class ToolCallSegment extends HermesSegment {
  final AgentToolCall call;
  const ToolCallSegment(this.call);
}

/// Hermes 聊天消息
class HermesMessage {
  final HermesRole role;
  final List<HermesSegment> segments;
  final DateTime timestamp;

  HermesMessage({
    required this.role,
    this.segments = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 合并所有文本片段的内容（用于 LLM 历史和日志）
  String get content => segments
      .whereType<TextSegment>()
      .map((s) => s.content)
      .join('');

  /// 提取所有工具调用（用于向后兼容）
  List<AgentToolCall> get toolCalls => segments
      .whereType<ToolCallSegment>()
      .map((s) => s.call)
      .toList();

  /// 创建系统消息
  factory HermesMessage.system(String content) => HermesMessage(
        role: HermesRole.system,
        segments: [TextSegment(content)],
      );

  /// 创建用户消息
  factory HermesMessage.user(String content) => HermesMessage(
        role: HermesRole.user,
        segments: [TextSegment(content)],
      );

  /// 创建助手消息（兼容旧格式：文本 + 工具调用列表）
  ///
  /// 生成结构为 [TextSegment(content), ToolCallSegment×N]
  factory HermesMessage.assistant(String content, {List<AgentToolCall> toolCalls = const []}) {
    final segs = <HermesSegment>[
      if (content.isNotEmpty) TextSegment(content),
      for (final call in toolCalls) ToolCallSegment(call),
    ];
    return HermesMessage(
      role: HermesRole.assistant,
      segments: segs,
    );
  }

  /// 创建助手消息（直接使用 segments 列表，保留交替时序）
  factory HermesMessage.assistantFromSegments(List<HermesSegment> segments) =>
      HermesMessage(
        role: HermesRole.assistant,
        segments: segments,
      );

  /// 序列化为 LLM 历史格式（只保留 role + content，不含 segments 细节）
  Map<String, String> toMap() {
    return {
      'role': role.name,
      'content': content,
    };
  }

  factory HermesMessage.fromMap(Map<String, dynamic> map) {
    final roleStr = map['role']?.toString() ?? 'user';
    HermesRole role;
    switch (roleStr) {
      case 'system':
        role = HermesRole.system;
        break;
      case 'assistant':
        role = HermesRole.assistant;
        break;
      default:
        role = HermesRole.user;
    }
    return HermesMessage(
      role: role,
      segments: [TextSegment(map['content']?.toString() ?? '')],
    );
  }

  HermesMessage copyWith({
    HermesRole? role,
    List<HermesSegment>? segments,
    DateTime? timestamp,
  }) {
    return HermesMessage(
      role: role ?? this.role,
      segments: segments ?? this.segments,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    final contentPreview = content.length > 50
        ? '${content.substring(0, 50)}...'
        : content;
    return 'HermesMessage(role: $role, content: $contentPreview, segments: ${segments.length})';
  }
}