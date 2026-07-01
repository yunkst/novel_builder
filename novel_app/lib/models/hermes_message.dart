import 'dart:convert';

import '../services/logger_service.dart';
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

  /// segments → JSON 字符串（持久化到 chat_messages.segmentsJson）
  ///
  /// 每条 segment 输出 `{type:'text', content}` 或
  /// `{type:'tool', id, name, arguments, status, result?}`。
  /// 任何异常不会抛出，返回空数组，保证 DB 写入不阻塞主流程。
  static String segmentsToJson(List<HermesSegment> segments) {
    try {
      final list = segments.map((s) {
        if (s is TextSegment) {
          return {'type': 'text', 'content': s.content};
        }
        if (s is ToolCallSegment) {
          final c = s.call;
          return {
            'type': 'tool',
            'id': c.id,
            'name': c.name,
            'arguments': c.arguments,
            'status': c.status.name,
            if (c.result != null) 'result': c.result,
          };
        }
        // 未知子类降级为 text（防御未来扩展）
        return {'type': 'text', 'content': ''};
      }).toList();
      return jsonEncode(list);
    } catch (e) {
      LoggerService.instance.w(
        'segmentsToJson 失败: $e',
        category: LogCategory.ai,
        tags: ['hermes_message', 'serialize_failed'],
      );
      return '[]';
    }
  }

  /// JSON 字符串 → segments（坏数据降级为空 list，不抛异常）
  static List<HermesSegment> segmentsFromJson(String json) {
    if (json.isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return const [];
      final result = <HermesSegment>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final type = item['type']?.toString();
        if (type == 'text') {
          result.add(TextSegment(item['content']?.toString() ?? ''));
        } else if (type == 'tool') {
          final argumentsRaw = item['arguments'];
          final arguments = argumentsRaw is Map
              ? Map<String, dynamic>.from(argumentsRaw)
              : <String, dynamic>{};
          final statusStr = item['status']?.toString() ?? 'running';
          final status = AgentToolStatus.values.firstWhere(
            (s) => s.name == statusStr,
            orElse: () => AgentToolStatus.running,
          );
          result.add(ToolCallSegment(AgentToolCall(
            id: item['id']?.toString() ?? '',
            name: item['name']?.toString() ?? '',
            arguments: arguments,
            status: status,
            result: item['result']?.toString(),
          )));
        }
        // 未知 type 跳过
      }
      return result;
    } catch (e) {
      LoggerService.instance.w(
        'segmentsFromJson 失败: $e rawLen=${json.length}',
        category: LogCategory.ai,
        tags: ['hermes_message', 'deserialize_failed'],
      );
      return const [];
    }
  }

  /// 序列化为完整快照（含 segments 多态细节，用于持久化）
  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'segmentsJson': segmentsToJson(segments),
    };
  }

  /// 从完整快照反序列化（坏数据降级为仅文本 user 消息）
  factory HermesMessage.fromJson(Map<String, dynamic> map) {
    final roleStr = map['role']?.toString() ?? 'user';
    final HermesRole role;
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
    final tsMs = map['timestamp'];
    final ts = tsMs is int
        ? DateTime.fromMillisecondsSinceEpoch(tsMs)
        : DateTime.now();
    final rawSegments = map['segmentsJson']?.toString() ?? '[]';
    final segs = segmentsFromJson(rawSegments);
    if (segs.isEmpty) {
      return HermesMessage(
        role: role,
        segments: [TextSegment(map['content']?.toString() ?? '')],
        timestamp: ts,
      );
    }
    return HermesMessage(role: role, segments: segs, timestamp: ts);
  }

  /// 序列化为 LLM 历史格式（只保留 role + content，不含 segments 细节）
  ///
  /// 保留供历史/外部 LLM 历史回放使用，不被持久化路径调用。
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