/// 用户提示词历史记录模型
class PromptHistory {
  final int? id;
  final String promptText;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PromptHistory({
    this.id,
    required this.promptText,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'prompt_text': promptText,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory PromptHistory.fromMap(Map<String, dynamic> map) => PromptHistory(
        id: map['id'] as int?,
        promptText: map['prompt_text'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      );

  PromptHistory copyWith({
    int? id,
    String? promptText,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      PromptHistory(
        id: id ?? this.id,
        promptText: promptText ?? this.promptText,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
