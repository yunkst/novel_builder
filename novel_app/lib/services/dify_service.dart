import '../models/character.dart';
import '../models/character_relationship.dart';
import '../models/ai_companion_response.dart';
import '../models/tag_introspection.dart';
import 'dify/dify_config_service.dart';
import 'dify/dify_workflow_service.dart';
import 'dify/dify_character_service.dart';
import 'dify/dify_creative_service.dart';
import 'dify/dify_formatter.dart';

/// AI 工作流服务 - 门面类
///
/// 此类作为统一入口，委托给各个专用服务：
/// - [DifyConfigService]: AI 设定管理
/// - [DifyWorkflowService]: 工作流调用（本地 DSL Engine 执行）
/// - [DifyCharacterService]: 角色相关操作
/// - [DifyCreativeService]: 创作相关操作
class DifyService {
  // 子服务实例
  final DifyConfigService _config;
  late final DifyWorkflowService _workflow;
  late final DifyCharacterService _character;
  late final DifyCreativeService _creative;

  /// 构造函数 - 支持依赖注入
  ///
  /// [config] 可选的配置服务实例，用于测试和依赖注入
  DifyService({DifyConfigService? config})
      : _config = config ?? DifyConfigService() {
    _workflow = DifyWorkflowService();
    _character = DifyCharacterService(
      config: _config,
      workflow: _workflow,
    );
    _creative = DifyCreativeService(
      config: _config,
      workflow: _workflow,
    );
  }

  /// 获取配置服务（用于测试和高级用法）
  DifyConfigService get config => _config;

  /// 获取工作流服务（用于高级用法）
  DifyWorkflowService get workflow => _workflow;

  /// 获取角色服务（用于高级用法）
  DifyCharacterService get character => _character;

  /// 获取创作服务（用于高级用法）
  DifyCreativeService get creative => _creative;

  // ============================================================================
  // 工作流方法（委托给 DifyWorkflowService）
  // ============================================================================

  /// 通用的流式工作流执行方法
  Future<void> runWorkflowStreaming({
    required Map<String, dynamic> inputs,
    required Function(String data) onData,
    Function(String error)? onError,
    Function()? onDone,
    bool enableDebugLog = false,
  }) =>
      _workflow.executeStreaming(
        inputs: inputs,
        onData: onData,
        onError: onError,
        onDone: onDone,
        enableDebugLog: enableDebugLog,
      );

  /// 通用的阻塞式工作流执行方法
  Future<Map<String, dynamic>?> runWorkflowBlocking({
    required Map<String, dynamic> inputs,
  }) =>
      _workflow.executeBlocking(inputs: inputs);

  // ============================================================================
  // 角色相关方法（委托给 DifyCharacterService）
  // ============================================================================

  /// AI生成角色
  Future<List<Character>> generateCharacters({
    required String userInput,
    required String novelUrl,
    required String backgroundSetting,
  }) =>
      _character.generateCharacters(
        userInput: userInput,
        novelUrl: novelUrl,
        backgroundSetting: backgroundSetting,
      );

  /// 从大纲生成角色
  Future<List<Character>> generateCharactersFromOutline({
    required String outline,
    required String userInput,
    required String novelUrl,
  }) =>
      _character.generateCharactersFromOutline(
        outline: outline,
        userInput: userInput,
        novelUrl: novelUrl,
      );

  /// 更新角色卡
  Future<List<Character>> updateCharacterCards({
    required String chaptersContent,
    required String roles,
    required String novelUrl,
    String backgroundSetting = '',
  }) =>
      _character.updateCharacterCards(
        chaptersContent: chaptersContent,
        roles: roles,
        novelUrl: novelUrl,
        backgroundSetting: backgroundSetting,
      );

  /// 从章节内容提取角色
  Future<List<Character>> extractCharacter({
    required String chapterContent,
    required String roles,
    required String novelUrl,
  }) =>
      _character.extractCharacter(
        chapterContent: chapterContent,
        roles: roles,
        novelUrl: novelUrl,
      );

  /// 生成角色卡提示词
  Future<Map<String, String>> generateCharacterPrompts({
    required String characterDescription,
  }) =>
      _character.generateCharacterPrompts(
        characterDescription: characterDescription,
      );

  // ============================================================================
  // 创作相关方法（委托给 DifyCreativeService）
  // ============================================================================

  /// 生成沉浸体验剧本
  Future<Map<String, dynamic>?> generateImmersiveScript({
    required String chapterContent,
    required List<Character> characters,
    required String userInput,
    required String userChoiceRole,
    String? existingPlay,
    List<Map<String, dynamic>>? existingRoleStrategy,
  }) =>
      _creative.generateImmersiveScript(
        chapterContent: chapterContent,
        characters: characters,
        userInput: userInput,
        userChoiceRole: userChoiceRole,
        existingPlay: existingPlay,
        existingRoleStrategy: existingRoleStrategy,
      );

  /// AI伴读功能
  Future<AICompanionResponse?> generateAICompanion({
    required String chaptersContent,
    required String backgroundSetting,
    required List<Character> characters,
    required List<CharacterRelationship> relationships,
  }) =>
      _creative.generateAICompanion(
        chaptersContent: chaptersContent,
        backgroundSetting: backgroundSetting,
        characters: characters,
        relationships: relationships,
      );

  /// AI 提取写作技巧标签
  Future<List<ExtractedPromptTag>> extractPromptTags({
    required String userInput,
    required String chapterContent,
    required String tagCategories,
  }) =>
      _creative.extractPromptTags(
        userInput: userInput,
        chapterContent: chapterContent,
        tagCategories: tagCategories,
      );

  /// 标签自省：分析用户修改意见，诊断 tag 体系问题
  Future<List<TagIntrospectionProblem>> introspectPromptTags({
    required String usedTags,
    required String generatedContent,
    required String userFeedback,
  }) =>
      _creative.introspectPromptTags(
        usedTags: usedTags,
        generatedContent: generatedContent,
        userFeedback: userFeedback,
      );

  /// 标签匹配：根据当前创作场景筛选适合的标签
  Future<List<TagMatchResult>> matchPromptTags({
    required String sceneDescription,
    required String availableTags,
  }) =>
      _creative.matchPromptTags(
        sceneDescription: sceneDescription,
        availableTags: availableTags,
      );

  // ============================================================================
  // 私有辅助方法（保持向后兼容）
  // ============================================================================

  /// 格式化角色信息为AI友好的JSON字符串
  // ignore: unused_element
  String _formatCharactersForAI(List<Character> characters) {
    return DifyFormatter.formatCharactersForAI(characters);
  }

  /// 格式化关系信息为AI友好的文本格式
  // ignore: unused_element
  String _formatRelationshipsForAI(
    List<CharacterRelationship> relationships,
    List<Character> characters,
  ) {
    return DifyFormatter.formatRelationships(relationships, characters);
  }
}