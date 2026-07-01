/// AI 对话消息记录（chat_messages 表）
///
/// 一条 chat_message 对应 HermesMessage 在某 session 中的快照，
/// segments（含工具调用详情）以 JSON 字符串形式存入 segmentsJson 列。
/// 反序列化时通过 [HermesMessage.segmentsFromJson] 还原。
library;

import 'hermes_message.dart';

class ChatMessageRecord {
  final int? id;
  final int sessionId;
  final String role;
  final String content;
  final String segmentsJson;
  final DateTime timestamp;
  final int orderIndex;

  ChatMessageRecord({
    this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.segmentsJson,
    DateTime? timestamp,
    required this.orderIndex,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 还原 segments 列表（坏数据时降级为单 TextSegment，不抛异常）
  List<HermesSegment> get segments => HermesMessage.segmentsFromJson(segmentsJson);

  /// 还原为 HermesMessage（坏数据时由 [HermesMessage.fromJson] 降级为单 TextSegment）
  ///
  /// 与 [HermesMessage.fromJson] 共享同一套 role 解析 + segments 降级逻辑，
  /// 是 hydrate 路径的单一真理来源。
  HermesMessage toHermesMessage() => HermesMessage.fromJson({
        'role': role,
        'content': content,
        'segmentsJson': segmentsJson,
        'timestamp': timestamp.millisecondsSinceEpoch,
      });

  /// 从一条 HermesMessage 构造 DB 行（segments 全量序列化）
  ///
  /// [orderIndex] 由 Repository 内部事务覆盖（MAX+1），调用方可传 0。
  /// 如需携带已知的 id（更新场景），用 `.copyWith(id: id)`。
  factory ChatMessageRecord.fromHermesMessage(
    int sessionId,
    int orderIndex,
    HermesMessage message,
  ) {
    return ChatMessageRecord(
      sessionId: sessionId,
      role: message.role.name,
      content: message.content,
      segmentsJson: HermesMessage.segmentsToJson(message.segments),
      timestamp: message.timestamp,
      orderIndex: orderIndex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sessionId': sessionId,
      'role': role,
      'content': content,
      'segmentsJson': segmentsJson,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'orderIndex': orderIndex,
    };
  }

  factory ChatMessageRecord.fromMap(Map<String, dynamic> map) {
    final ts = map['timestamp'];
    return ChatMessageRecord(
      id: map['id'] as int?,
      sessionId: (map['sessionId'] as num).toInt(),
      role: map['role'] as String? ?? 'user',
      content: map['content'] as String? ?? '',
      segmentsJson: map['segmentsJson'] as String? ?? '[]',
      timestamp: ts is int
          ? DateTime.fromMillisecondsSinceEpoch(ts)
          : DateTime.now(),
      orderIndex: (map['orderIndex'] as num).toInt(),
    );
  }

  ChatMessageRecord copyWith({
    int? id,
    int? sessionId,
    String? role,
    String? content,
    String? segmentsJson,
    DateTime? timestamp,
    int? orderIndex,
  }) {
    return ChatMessageRecord(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      segmentsJson: segmentsJson ?? this.segmentsJson,
      timestamp: timestamp ?? this.timestamp,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  @override
  String toString() =>
      'ChatMessageRecord(id: $id, sessionId: $sessionId, role: $role, '
      'orderIndex: $orderIndex, contentLen: ${content.length})';
}
