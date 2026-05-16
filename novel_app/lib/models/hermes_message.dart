/// Hermes 聊天消息角色
enum HermesRole {
  system,
  user,
  assistant,
}

/// Hermes 聊天消息
class HermesMessage {
  final HermesRole role;
  final String content;
  final DateTime timestamp;

  HermesMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory HermesMessage.system(String content) => HermesMessage(
        role: HermesRole.system,
        content: content,
      );

  factory HermesMessage.user(String content) => HermesMessage(
        role: HermesRole.user,
        content: content,
      );

  factory HermesMessage.assistant(String content) => HermesMessage(
        role: HermesRole.assistant,
        content: content,
      );

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
      content: map['content']?.toString() ?? '',
    );
  }

  HermesMessage copyWith({
    HermesRole? role,
    String? content,
    DateTime? timestamp,
  }) {
    return HermesMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'HermesMessage(role: $role, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content})';
  }
}
