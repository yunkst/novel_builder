import '../ai/ai_service_factory.dart';
import '../ai/info_extraction_service.dart';
import '../ai/writing_service.dart';
import '../logger_service.dart';

/// 工作流服务（已切换到强类型 Dart Service）
///
/// 内部委托给 WritingService（流式）和 InfoExtractionService（阻塞），
/// 替代原 DslExecutor + yml 黑盒。保持对外接口 [executeStreaming] / [executeBlocking] 不变，
/// UI 调用点和 DifyService 门面零改动。
///
/// 路由规则：根据 inputs['cmd'] 分发到对应的强类型方法。
///
/// 返回值说明：
/// - 结构化方法（带 responseFormat）返回 `Map<String, dynamic>`
/// - 纯文本方法返回 `String`
/// [executeBlocking] 统一包装为 `{'content': Object}` 格式。
class DifyWorkflowService {
  DifyWorkflowService();

  // ============================================================================
  // 流式执行（原 creater.yml 路径 → WritingService）
  // ============================================================================

  Future<void> executeStreaming({
    required Map<String, dynamic> inputs,
    required Function(String data) onData,
    Function(String error)? onError,
    Function()? onDone,
    bool enableDebugLog = false,
  }) async {
    LoggerService.instance.d(
      'DifyWorkflowService.executeStreaming: cmd=${inputs['cmd']}, '
      'inputs=${inputs.keys.toList()}',
      category: LogCategory.ai,
      tags: ['workflow', 'streaming'],
    );
    try {
      final service = await AiServiceFactory.createWritingService();
      final stream = _routeStreaming(service, inputs);
      await for (final chunk in stream) {
        onData(chunk);
      }
      onDone?.call();
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        'executeStreaming 失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['workflow', 'streaming', 'error'],
      );
      onError?.call(e.toString());
    }
  }

  // ============================================================================
  // 阻塞执行（原 structured_info.yml 路径 → InfoExtractionService）
  // ============================================================================

  Future<Map<String, dynamic>?> executeBlocking({
    required Map<String, dynamic> inputs,
  }) async {
    LoggerService.instance.d(
      'DifyWorkflowService.executeBlocking: cmd=${inputs['cmd']}, '
      'inputs=${inputs.keys.toList()}',
      category: LogCategory.ai,
      tags: ['workflow', 'blocking'],
    );
    final service = await AiServiceFactory.createInfoExtractionService();
    final result = await _routeBlocking(service, inputs);
    return {'content': result};
  }

  // ============================================================================
  // cmd 路由
  // ============================================================================

  /// 根据 inputs['cmd'] 路由到 WritingService 的对应流式方法
  Stream<String> _routeStreaming(
    WritingService service,
    Map<String, dynamic> inputs,
  ) {
    final cmd = (inputs['cmd'] as String?) ?? '';

    // 公共字段读取辅助
    String s(String key) => (inputs[key] ?? '').toString();

    switch (cmd) {
      case '':
        // cmd='' 根据 current_chapter_content 是否为空区分重写/新建，
        // 但两者共用同一模板（user 的 if content 分支自动处理），直接走 fullRewrite
        return service.fullRewrite(
          aiWriterSetting: s('ai_writer_setting'),
          backgroundSetting: s('background_setting'),
          historyChaptersContent: s('history_chapters_content'),
          currentChapterContent: s('current_chapter_content'),
          roles: s('roles'),
          nextChapterOverview: s('next_chapter_overview'),
          userInput: s('user_input'),
        );
      case '特写':
        return service.closeup(
          aiWriterSetting: s('ai_writer_setting'),
          backgroundSetting: s('background_setting'),
          historyChaptersContent: s('history_chapters_content'),
          currentChapterContent: s('current_chapter_content'),
          roles: s('roles'),
          nextChapterOverview: s('next_chapter_overview'),
          userInput: s('user_input'),
          choiceContent: s('choice_content'),
        );
      case '总结':
        return service.summarize(currentChapterContent: s('current_chapter_content'));
      case '场景描写':
        return service.sceneDescription(
          currentChapterContent: s('current_chapter_content'),
          roles: s('roles'),
        );
      case '生成大纲':
        return service.generateOutline(
          backgroundSetting: s('background_setting'),
          outline: s('outline'),
          userInput: s('user_input'),
        );
      case '生成细纲':
        return service.generateSubOutline(
          historyChaptersContent: s('history_chapters_content'),
          outline: s('outline'),
          outlineItem: s('outline_item'),
          userInput: s('user_input'),
        );
      case '聊天':
        return service.chat(
          roles: s('roles'),
          scene: s('scene'),
          chatHistory: s('chat_history'),
          userInput: s('user_input'),
          choiceContent: s('choice_content'),
        );
      case '设定总结':
        return service.settingSummary(backgroundSetting: s('background_setting'));
      default:
        throw UnimplementedError('未知的流式 cmd: "$cmd"');
    }
  }

  /// 根据 inputs['cmd'] 路由到 InfoExtractionService 的对应阻塞方法
  ///
  /// 返回类型为 Object：
  /// - 纯文本方法返回 String
  /// - 结构化方法（immersiveScript/tagIntrospection/tagMatch）返回 `Map<String, dynamic>`
  Future<Object> _routeBlocking(
    InfoExtractionService service,
    Map<String, dynamic> inputs,
  ) async {
    final cmd = (inputs['cmd'] as String?) ?? '';
    String s(String key) => (inputs[key] ?? '').toString();

    switch (cmd) {
      case '生成':
        return service.generateCharacters(
          backgroundSetting: s('background_setting'),
          userInput: s('user_input'),
        );
      case '大纲生成角色':
        return service.generateCharactersFromOutline(
          outline: s('outline'),
          userInput: s('user_input'),
        );
      case 'update_characters':
        return service.updateCharacterCards(
          chaptersContent: s('chapters_content'),
          roles: s('roles'),
        );
      case '提取角色':
        return service.extractCharacter(
          chaptersContent: s('chapters_content'),
          roles: s('roles'),
        );
      case '角色卡提示词描写':
        return service.generateCharacterPrompts(roles: s('roles'));
      case 'AI伴读':
        return service.aiCompanion(
          backgroundSetting: s('background_setting'),
          roles: s('roles'),
          relations: s('relations'),
          chaptersContent: s('chapters_content'),
        );
      case '提取标签':
        return service.extractPromptTags(
          userInput: s('user_input'),
          currentChapterContent: s('current_chapter_content'),
          tagCategories: s('tag_categories'),
        );
      case '生成剧本':
        // role_strategy 可能是 List<Map<String,dynamic>> 或 JSON 字符串，需特殊处理
        final rawRoleStrategy = inputs['role_strategy'];
        final existingPlay = s('play');
        return service.immersiveScript(
          chaptersContent: s('chapters_content'),
          roles: s('roles'),
          userInput: s('user_input'),
          userChoiceRole: s('user_choice_role'),
          existingPlay: existingPlay,
          existingRoleStrategy: rawRoleStrategy,
        );
      case '标签自省':
        return service.tagIntrospection(
          usedTags: s('used_tags'),
          generatedContent: s('generated_content'),
          userFeedback: s('user_feedback'),
        );
      case '标签匹配':
        return service.tagMatch(
          sceneDescription: s('scene_description'),
          availableTags: s('available_tags'),
        );
      default:
        throw UnimplementedError('未知的阻塞 cmd: "$cmd"');
    }
  }
}