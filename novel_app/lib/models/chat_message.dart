import 'character.dart';

/// 聊天消息模型
class ChatMessage {
  /// 消息类型
  /// - narration: 旁白/行为描述（灰色斜体）
  /// - dialogue: 角色对话（带头像和气泡）
  /// - user_action: 用户行为（右对齐）
  /// - user_speech: 用户对话（右对齐）
  final String type;

  /// 消息内容
  final String content;

  /// 角色信息（仅对话类型需要）
  final Character? character;

  /// 是否为用户消息
  final bool isUser;

  /// 时间戳
  final DateTime timestamp;

  ChatMessage({
    required this.type,
    required this.content,
    this.character,
    this.isUser = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 创建旁白消息
  factory ChatMessage.narration(String content) {
    return ChatMessage(
      type: 'narration',
      content: content,
      timestamp: DateTime.now(),
    );
  }

  /// 创建角色对话消息
  factory ChatMessage.dialogue(String content, Character character) {
    return ChatMessage(
      type: 'dialogue',
      content: content,
      character: character,
      isUser: false,
      timestamp: DateTime.now(),
    );
  }

  /// 创建用户行为消息
  factory ChatMessage.userAction(String content) {
    return ChatMessage(
      type: 'user_action',
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  /// 创建用户对话消息
  factory ChatMessage.userSpeech(String content) {
    return ChatMessage(
      type: 'user_speech',
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  /// 复制消息并更新部分字段
  ChatMessage copyWith({
    String? type,
    String? content,
    Character? character,
    bool? isUser,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      type: type ?? this.type,
      content: content ?? this.content,
      character: character ?? this.character,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// 判断消息是否为对话类型
  bool get isDialogue => type == 'dialogue';

  /// 判断消息是否为旁白类型
  bool get isNarration => type == 'narration';

  /// 判断消息是否为用户消息
  bool get isUserMessage => isUser;

  @override
  String toString() {
    return 'ChatMessage(type: $type, content: $content, isUser: $isUser)';
  }
}
