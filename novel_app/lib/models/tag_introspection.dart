/// AI 标签自省分析出的单个问题
///
/// 三种问题类型：
/// - [reasonAdjust]：标签的使用场景(reason)描述不准（太窄/太宽），需调整
/// - [promptClarify]：标签的提示词(promptText)描述不清晰，需改写
/// - [missingTag]：标签库缺少某个写作技巧的标签，需新增
class TagIntrospectionProblem {
  /// 问题类型：reason_adjust | prompt_clarify | missing_tag
  final String type;

  /// 受影响的 tag 名（reason_adjust / prompt_clarify 必填）
  final String? tagName;

  /// 当前 reason（reason_adjust 时）
  final String? currentReason;

  /// 建议的 reason（reason_adjust 时）
  final String? suggestedReason;

  /// 当前 promptText（prompt_clarify 时）
  final String? currentPrompt;

  /// 建议的 promptText（prompt_clarify / missing_tag 时）
  final String? suggestedPrompt;

  /// 建议的新 tag 名（missing_tag 时）
  final String? suggestedTag;

  /// 建议的分类（missing_tag 时）
  final String? suggestedCategory;

  /// 新 tag 的 reason（missing_tag 时）
  final String? suggestedNewReason;

  /// AI 给出的分析理由
  final String analysis;

  const TagIntrospectionProblem({
    required this.type,
    required this.analysis,
    this.tagName,
    this.currentReason,
    this.suggestedReason,
    this.currentPrompt,
    this.suggestedPrompt,
    this.suggestedTag,
    this.suggestedCategory,
    this.suggestedNewReason,
  });

  /// 问题类型枚举快捷判断
  bool get isReasonAdjust => type == 'reason_adjust';
  bool get isPromptClarify => type == 'prompt_clarify';
  bool get isMissingTag => type == 'missing_tag';

  /// 问题类型的中文标签
  String get typeLabel {
    switch (type) {
      case 'reason_adjust':
        return '使用场景调整';
      case 'prompt_clarify':
        return '提示词优化';
      case 'missing_tag':
        return '建议新增标签';
      default:
        return type;
    }
  }

  factory TagIntrospectionProblem.fromJson(Map<String, dynamic> json) {
    return TagIntrospectionProblem(
      type: (json['type'] ?? '').toString().trim(),
      analysis: (json['analysis'] ?? json['reason'] ?? '').toString().trim(),
      tagName: _asString(json['tag_name']),
      currentReason: _asString(json['current_reason']),
      suggestedReason: _asString(json['suggested_reason']),
      currentPrompt: _asString(json['current_prompt']),
      suggestedPrompt: _asString(json['suggested_prompt']),
      suggestedTag: _asString(json['suggested_tag']),
      suggestedCategory: _asString(json['suggested_category']),
      suggestedNewReason: _asString(json['suggested_new_reason']),
    );
  }

  static String? _asString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}

/// 智能匹配返回的单个推荐 tag
class TagMatchResult {
  /// tag 名
  final String name;

  /// 分类 ID
  final int categoryId;

  /// 为什么推荐这个 tag
  final String matchReason;

  const TagMatchResult({
    required this.name,
    required this.categoryId,
    required this.matchReason,
  });

  factory TagMatchResult.fromJson(Map<String, dynamic> json) {
    return TagMatchResult(
      name: (json['name'] ?? '').toString().trim(),
      categoryId: (json['category_id'] as num?)?.toInt() ?? 0,
      matchReason: (json['match_reason'] ?? '').toString().trim(),
    );
  }
}
