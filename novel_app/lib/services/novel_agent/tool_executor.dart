/// 工具执行器 — Agent 工具 → Repository 调度
///
/// 上下文驱动：通过 [AgentScenarioContext] 读取当前小说，position 解析为 chapterUrl。
/// 错误响应包含 suggested_tool，引导 AI 自助修复。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novel_app/services/logger_service.dart';
import 'package:novel_app/services/llm_config_service.dart';
import 'package:novel_app/services/ai/ai_service_factory.dart';
import 'package:novel_app/services/preferences_service.dart';

import '../../core/providers/database_providers.dart';
import '../../core/providers/services/ai_service_providers.dart';
import '../../models/character.dart';
import '../../models/novel.dart';
import '../../models/outline.dart';
import '../../models/prompt_tag.dart';
import '../../models/prompt_tag_category.dart';
import '../../utils/content_sanitizer.dart';
import 'agent_scenario.dart';
import 'tool_arg_parser.dart';

/// ID/位置解析结果
class _IdResolveResult {
  final String? url;
  final Map<String, dynamic>? errorJson;
  const _IdResolveResult.success(this.url) : errorJson = null;
  const _IdResolveResult.failure(this.errorJson) : url = null;
}

/// LLM 重写结果
class _RewriteResult {
  final String? content;
  final Map<String, dynamic>? errorJson;
  const _RewriteResult.success(this.content) : errorJson = null;
  const _RewriteResult.failure(this.errorJson) : content = null;
}

class ToolExecutor {
  final Ref ref;

  ToolExecutor(this.ref);

  /// 分发工具调用
  ///
  /// [scenarioContext] 写作场景专用，包含当前小说 ID。
  /// 对于 `select_novel` 工具，返回的结果会包含 success 标记，
  /// 上游（HermesChatNotifier）需自行维护状态。
  Future<String> execute(
    String toolName,
    Map<String, dynamic> args, {
    AgentScenarioContext? scenarioContext,
  }) async {
    LoggerService.instance.d('执行工具: $toolName (args=${args.keys.toList()})',
        category: LogCategory.ai, tags: ['agent', 'tool', toolName, 'exec']);
    try {
      switch (toolName) {
        // ===== 小说导航 =====
        case 'list_novels':
          return await _listNovels(args);
        case 'select_novel':
          return await _selectNovel(args);
        case 'create_novel':
          return await _createNovel(args);
        // ===== 章节读取 =====
        case 'read_chapter_content':
          return await _readChapterContent(args, scenarioContext);
        case 'list_chapters':
          return await _listChapters(args, scenarioContext);
        case 'search_in_chapters':
          return await _searchInChapters(args, scenarioContext);
        // ===== 章节写入 =====
        case 'create_chapter':
          return await _createChapter(args, scenarioContext);
        case 'update_chapter_content':
          return await _updateChapterContent(args, scenarioContext);
        // ===== 角色 =====
        case 'list_characters':
          return await _listCharacters(args, scenarioContext);
        case 'update_character':
          return await _updateCharacter(args, scenarioContext);
        case 'create_character':
          return await _createCharacter(args, scenarioContext);
        // ===== 设定 / 大纲 =====
        case 'update_background_setting':
          return await _updateBackgroundSetting(args, scenarioContext);
        case 'update_outline':
          return await _updateOutline(args, scenarioContext);
        case 'get_outline':
          return await _getOutline(args, scenarioContext);
        // ===== 提示标签 =====
        case 'list_prompt_tags':
          return await _listPromptTags(args);
        case 'save_prompt_tag':
          return await _savePromptTag(args);
        case 'delete_prompt_tag':
          return await _deletePromptTag(args);
        default:
          LoggerService.instance.w('未知工具: $toolName',
              category: LogCategory.ai, tags: ['agent', 'tool', toolName, 'unknown']);
          return jsonEncode({
            'error': 'unknown_tool',
            'message': '未知工具: $toolName',
          });
      }
    } catch (e, stack) {
      LoggerService.instance.e('工具执行失败: $toolName, error=$e',
          stackTrace: stack.toString(),
              category: LogCategory.ai,
              tags: ['agent', 'tool', toolName, 'error']);
      return jsonEncode({
        'error': 'execution_failed',
        'message': e.toString(),
      });
    }
  }

  // ===== ID / 位置解析辅助方法 =====

  /// 解析当前小说 URL（从场景上下文中读取 currentNovelId）
  ///
  /// 未设置时返回 no_current_novel 错误，引导 AI 调用 list_novels + select_novel。
  Future<_IdResolveResult> _resolveCurrentNovelUrl(
    AgentScenarioContext? ctx,
  ) async {
    final currentNovelId = ctx?.currentNovelId;
    if (currentNovelId == null) {
      LoggerService.instance.d(
        '工具引导错误: no_current_novel',
        category: LogCategory.ai,
        tags: ['agent', 'tool', 'no_current_novel'],
      );
      return _IdResolveResult.failure({
        'error': 'no_current_novel',
        'message':
            '尚未选择当前小说。请先调用 list_novels 查看书架，然后用 select_novel 选定目标。',
        'suggested_tool': 'list_novels',
        'suggested_args': <String, dynamic>{},
      });
    }
    return _resolveNovelUrl(currentNovelId);
  }

  /// novelId → novelUrl 解析，失败时返回错误 JSON
  Future<_IdResolveResult> _resolveNovelUrl(int novelId) async {
    final repo = ref.read(novelRepositoryProvider);
    final novelUrl = await repo.getNovelUrlById(novelId);
    if (novelUrl == null) {
      LoggerService.instance.d(
        '工具引导错误: novel_not_found novelId=$novelId',
        category: LogCategory.ai,
        tags: ['agent', 'tool', 'novel_not_found'],
      );
      return _IdResolveResult.failure({
        'error': 'novel_not_found',
        'message': '小说ID $novelId 不存在。请先调用 list_novels 查看书架中的所有小说及其ID。',
        'suggested_tool': 'list_novels',
        'suggested_args': <String, dynamic>{},
      });
    }
    return _IdResolveResult.success(novelUrl);
  }

  /// 构造小说上下文对象 {id, title} 用于返回结果（同步，无 IO）
  Map<String, dynamic>? _buildCurrentNovelContext(AgentScenarioContext? ctx) {
    final currentNovelId = ctx?.currentNovelId;
    if (currentNovelId == null) return null;
    return {
      'id': currentNovelId,
      'title': ctx?.currentNovelTitle,
    };
  }

  /// position → chapterUrl 解析
  ///
  /// position 是 1-based 的顺序号，依赖 list_chapters 返回的顺序（按 chapterIndex ASC 排序）。
  Future<_IdResolveResult> _resolveChapterUrlByPosition(
    AgentScenarioContext? ctx,
    int position,
  ) async {
    final novelResolve = await _resolveCurrentNovelUrl(ctx);
    if (novelResolve.errorJson != null) return novelResolve;
    final novelUrl = novelResolve.url!;

    final repo = ref.read(chapterRepositoryProvider);
    final chapters = await repo.getCachedNovelChapters(novelUrl);
    if (position < 1 || position > chapters.length) {
      LoggerService.instance.d(
        '工具引导错误: chapter_position_out_of_range position=$position total=${chapters.length}',
        category: LogCategory.ai,
        tags: ['agent', 'tool', 'chapter_position_out_of_range'],
      );
      return _IdResolveResult.failure({
        'error': 'chapter_position_out_of_range',
        'message': chapters.isEmpty
            ? '当前小说没有任何章节。请先调用 list_chapters 确认。'
            : '章节位置 $position 超出范围（当前小说共 ${chapters.length} 章）。'
                '请先调用 list_chapters 查看有效位置。',
        'suggested_tool': 'list_chapters',
        'suggested_args': <String, dynamic>{},
      });
    }
    return _IdResolveResult.success(chapters[position - 1].url);
  }

  // ===== 小说导航 =====

  Future<String> _listNovels(Map<String, dynamic> args) async {
    final repo = ref.read(novelRepositoryProvider);
    final novels = await repo.getNovels();
    final list = novels.map((n) => {
          'id': n.id,
          'title': n.title,
          'author': n.author,
          if (n.description != null && n.description!.isNotEmpty)
            'description': n.description!.length > 200
                ? '${n.description!.substring(0, 200)}...'
                : n.description,
        }).toList();
    LoggerService.instance.i('列出小说: ${list.length} 本',
        category: LogCategory.ai, tags: ['agent', 'tool', 'list_novels']);
    return jsonEncode({'novels': list, 'count': list.length});
  }

  Future<String> _selectNovel(Map<String, dynamic> args) async {
    final parser = ToolArgParser(args);
    final (novelId, novelIdErr) = parser.requireInt('novelId');
    if (novelIdErr != null) return novelIdErr;
    final repo = ref.read(novelRepositoryProvider);
    final novel = await repo.getNovelById(novelId);
    if (novel == null) {
      LoggerService.instance.w('select_novel: 小说不存在 id=$novelId',
          category: LogCategory.ai,
          tags: ['agent', 'tool', 'select_novel', 'not_found']);
      return jsonEncode({
        'error': 'novel_not_found',
        'message': '小说ID $novelId 不存在。请先调用 list_novels。',
        'suggested_tool': 'list_novels',
        'suggested_args': <String, dynamic>{},
      });
    }
    LoggerService.instance.i('select_novel: id=$novelId, title="${novel.title}"',
        category: LogCategory.ai, tags: ['agent', 'tool', 'select_novel']);
    return jsonEncode({
      'success': true,
      'novelId': novel.id,
      'title': novel.title,
      'message': '已切换到 "${novel.title}"。后续操作将作用于该小说。',
    });
  }

  Future<String> _createNovel(Map<String, dynamic> args) async {
    final parser = ToolArgParser(args);
    final (title, titleErr) = parser.requireString('title');
    if (titleErr != null) return titleErr;
    final (description, _) = parser.nullableString('description');

    final novelRepository = ref.read(novelRepositoryProvider);
    final novel = Novel(
      title: title,
      author: '原创',
      url: 'custom://custom_novel_${DateTime.now().millisecondsSinceEpoch}',
      coverUrl: null,
      description: description,
      backgroundSetting: null,
    );
    final id = await novelRepository.addToBookshelf(novel);

    LoggerService.instance.i('create_novel: "$title" (id=$id)',
        category: LogCategory.ai, tags: ['agent', 'tool', 'create_novel']);
    return jsonEncode({
      'success': true,
      'novelId': id,
      'title': title,
      'message': '小说 "$title" 已创建并自动切换为当前工作小说。',
    });
  }

  // ===== 章节读取 =====

  Future<String> _readChapterContent(
    Map<String, dynamic> args,
    AgentScenarioContext? ctx,
  ) async {
    final parser = ToolArgParser(args);
    final (position, posErr) = parser.requireInt('position');
    if (posErr != null) return posErr;
    final resolveResult = await _resolveChapterUrlByPosition(ctx, position);
    if (resolveResult.errorJson != null) {
      return jsonEncode(resolveResult.errorJson);
    }
    final chapterUrl = resolveResult.url!;

    final repo = ref.read(chapterRepositoryProvider);
    final content = await repo.getCachedChapter(chapterUrl);
    if (content == null || content.isEmpty) {
      LoggerService.instance.w('章节未缓存: position=$position',
          category: LogCategory.ai,
          tags: ['agent', 'tool', 'read_chapter_content', 'not_cached']);
      return jsonEncode({
        'error': 'not_cached',
        'message':
            '位置 $position 的章节存在但内容尚未缓存，无法读取。',
        'suggested_action': '请告知用户该章节需要先加载/缓存。',
      });
    }

    LoggerService.instance.i('读取章节成功: position=$position (${content.length} chars)',
        category: LogCategory.ai, tags: ['agent', 'tool', 'read_chapter_content']);
    return content;
  }

  Future<String> _listChapters(
    Map<String, dynamic> args,
    AgentScenarioContext? ctx,
  ) async {
    final novelResolve = await _resolveCurrentNovelUrl(ctx);
    if (novelResolve.errorJson != null) {
      return jsonEncode(novelResolve.errorJson);
    }
    final novelUrl = novelResolve.url!;

    final repo = ref.read(chapterRepositoryProvider);
    final chapters = await repo.getCachedNovelChapters(novelUrl);
    final list = <Map<String, dynamic>>[];
    for (var i = 0; i < chapters.length; i++) {
      final c = chapters[i];
      list.add({
        'position': i + 1,
        'title': c.title,
        'chapterIndex': c.chapterIndex,
        'isCached': c.isCached,
        'isUserInserted': c.isUserInserted,
      });
    }

    final novelContext = _buildCurrentNovelContext(ctx);
    LoggerService.instance.i(
        '列出章节: ${list.length} 章 (currentNovelId=${ctx?.currentNovelId})',
        category: LogCategory.ai, tags: ['agent', 'tool', 'list_chapters']);
    return jsonEncode({
      'novel': novelContext,
      'chapters': list,
      'count': list.length,
    });
  }

  Future<String> _searchInChapters(
    Map<String, dynamic> args,
    AgentScenarioContext? ctx,
  ) async {
    final parser = ToolArgParser(args);
    final (keyword, kwErr) = parser.requireString('keyword');
    if (kwErr != null) return kwErr;
    final novelResolve = await _resolveCurrentNovelUrl(ctx);
    if (novelResolve.errorJson != null) {
      return jsonEncode(novelResolve.errorJson);
    }
    final novelUrl = novelResolve.url!;

    final repo = ref.read(chapterRepositoryProvider);
    final results = await repo.searchInCachedContent(
      keyword,
      novelUrl: novelUrl,
    );

    // 解析每个结果项的 position（按 list_chapters 顺序）
    final chapters = await repo.getCachedNovelChapters(novelUrl);
    final urlToPosition = <String, int>{
      for (var i = 0; i < chapters.length; i++) chapters[i].url: i + 1,
    };

    final list = results.map((r) => {
          'position': urlToPosition[r.chapterUrl],
          'chapterTitle': r.chapterTitle,
          'matchedText': r.matchPositions.isNotEmpty
              ? r.content.substring(r.matchPositions.first.start, r.matchPositions.first.end)
              : '',
          'matchCount': r.matchCount,
        }).toList();

    final novelContext = _buildCurrentNovelContext(ctx);
    LoggerService.instance.i(
        '章节搜索: keyword="$keyword", ${list.length} 个匹配',
        category: LogCategory.ai, tags: ['agent', 'tool', 'search_in_chapters']);
    return jsonEncode({
      'novel': novelContext,
      'results': list,
      'count': list.length,
    });
  }

  // ===== 章节写入 =====

  Future<String> _createChapter(
    Map<String, dynamic> args,
    AgentScenarioContext? ctx,
  ) async {
    final parser = ToolArgParser(args);
    final (position, posErr) = parser.requireInt('position');
    if (posErr != null) return posErr;
    final (instruction, instErr) = parser.requireString('instruction');
    if (instErr != null) return instErr;
    final (title, _) = parser.optionalString('title');
    final (characterNames, charNamesErr) = parser.optionalStringList('characterNames');
    if (charNamesErr != null) return charNamesErr;
    final (tagNames, tagNamesErr) = parser.optionalStringList('tagNames');
    if (tagNamesErr != null) return tagNamesErr;
    final charNames = characterNames ?? const <String>[];
    final tags = tagNames ?? const <String>[];

    final novelResolve = await _resolveCurrentNovelUrl(ctx);
    if (novelResolve.errorJson != null) {
      return jsonEncode(novelResolve.errorJson);
    }
    final novelUrl = novelResolve.url!;

    // 校验 position 范围：1 ≤ position ≤ 章节总数 + 1
    final chapterRepo = ref.read(chapterRepositoryProvider);
    final chapters = await chapterRepo.getCachedNovelChapters(novelUrl);
    final totalCount = chapters.length;
    if (position < 1 || position > totalCount + 1) {
      LoggerService.instance.d(
        '工具引导错误: create_chapter_position_out_of_range position=$position total=$totalCount',
        category: LogCategory.ai,
        tags: ['agent', 'tool', 'create_chapter', 'position_out_of_range'],
      );
      return jsonEncode({
        'error': 'position_out_of_range',
        'message': totalCount == 0
            ? '当前小说没有任何章节，position 只能为 1。'
            : '插入位置 $position 超出范围（当前共 $totalCount 章，有效范围 1~${totalCount + 1}）。'
                '请先调用 list_chapters 查看有效位置。',
        'suggested_tool': 'list_chapters',
        'suggested_args': <String, dynamic>{},
      });
    }

    // 确定章节标题
    final chapterTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : '第 $position 章';

    // 调用 LLM 生成正文
    final generateResult = await _generateChapter(
      novelUrl: novelUrl,
      chapterTitle: chapterTitle,
      instruction: instruction,
      characterNames: charNames,
      tagNames: tags,
    );
    if (generateResult.errorJson != null) {
      return jsonEncode(generateResult.errorJson);
    }
    final newContent = ContentSanitizer.sanitize(generateResult.content!);

    // 插入章节：先腾出位置，再创建
    final insertIndex = position - 1; // 0-based
    try {
      await chapterRepo.shiftChapterIndicesFrom(novelUrl, insertIndex);
      await chapterRepo.createCustomChapter(
        novelUrl,
        chapterTitle,
        newContent,
        insertIndex,
      );
    } catch (e, stack) {
      LoggerService.instance.e('创建章节入库失败: $e',
          stackTrace: stack.toString(),
          category: LogCategory.ai,
          tags: ['agent', 'tool', 'create_chapter', 'db_error']);
      return jsonEncode({
        'error': 'db_error',
        'message': '章节内容已生成但入库失败：$e',
      });
    }

    // 重新获取章节列表以拿到新章节的 URL
    final updatedChapters = await chapterRepo.getCachedNovelChapters(novelUrl);
    final newChapter = updatedChapters.firstWhere(
      (c) => c.title == chapterTitle && c.chapterIndex == insertIndex,
      orElse: () => updatedChapters[position - 1],
    );

    LoggerService.instance.i(
        'AI 创建章节: position=$position, title="$chapterTitle", ${newContent.length} chars',
        category: LogCategory.ai, tags: ['agent', 'tool', 'create_chapter']);
    return jsonEncode({
      'success': true,
      'message': '章节「$chapterTitle」已创建（${newContent.length} 字）。',
      'chapterTitle': chapterTitle,
      'position': position,
      'novelUrl': novelUrl,
      'chapterUrl': newChapter.url,
      'charCount': newContent.length,
    });
  }

  Future<String> _updateChapterContent(
    Map<String, dynamic> args,
    AgentScenarioContext? ctx,
  ) async {
    final parser = ToolArgParser(args);
    final (position, posErr) = parser.requireInt('position');
    if (posErr != null) return posErr;
    final (rewriteInstruction, instErr) =
        parser.requireString('rewriteInstruction');
    if (instErr != null) return instErr;
    final (characterNames, charNamesErr) = parser.optionalStringList('characterNames');
    if (charNamesErr != null) return charNamesErr;
    final (tagNames, tagNamesErr) = parser.optionalStringList('tagNames');
    if (tagNamesErr != null) return tagNamesErr;
    final charNames = characterNames ?? const <String>[];
    final tags = tagNames ?? const <String>[];

    final resolveResult = await _resolveChapterUrlByPosition(ctx, position);
    if (resolveResult.errorJson != null) {
      return jsonEncode(resolveResult.errorJson);
    }
    final chapterUrl = resolveResult.url!;

    // 读取章节原文（重写基础）
    final novelResolve = await _resolveCurrentNovelUrl(ctx);
    final novelUrl = novelResolve.url!;
    final chapterRepo = ref.read(chapterRepositoryProvider);
    final chapters = await chapterRepo.getCachedNovelChapters(novelUrl);
    final chapter =
        chapters.firstWhere((c) => c.url == chapterUrl, orElse: () => chapters[position - 1]);
    final originalContent = await chapterRepo.getCachedChapter(chapterUrl);
    if (originalContent == null || originalContent.isEmpty) {
      return jsonEncode({
        'error': 'not_cached',
        'message':
            '位置 $position 的章节存在但内容尚未缓存，无法重写。请告知用户先加载/缓存该章节。',
      });
    }

    // 组合提示词并调用 LLM 重写
    final rewriteResult = await _rewriteChapter(
      novelUrl: novelUrl,
      chapterTitle: chapter.title,
      originalContent: originalContent,
      rewriteInstruction: rewriteInstruction,
      characterNames: charNames,
      tagNames: tags,
    );
    if (rewriteResult.errorJson != null) {
      return jsonEncode(rewriteResult.errorJson);
    }
    final newContent = ContentSanitizer.sanitize(rewriteResult.content!);

    // 保存到数据库
    final affected = await chapterRepo.updateChapterContent(chapterUrl, newContent, source: 'ai_rewrite');
    if (affected == 0) {
      LoggerService.instance.d(
        '工具引导错误: chapter_not_found position=$position',
        category: LogCategory.ai,
        tags: ['agent', 'tool', 'update_chapter_content', 'chapter_not_found'],
      );
      return jsonEncode({
        'error': 'chapter_not_found',
        'message': '章节位置 $position 的数据库记录不存在或内容表无对应行。',
        'suggested_tool': 'list_chapters',
        'suggested_args': <String, dynamic>{},
      });
    }

    LoggerService.instance.i(
        'AI 重写章节: position=$position, ${originalContent.length}→${newContent.length} chars',
        category: LogCategory.ai, tags: ['agent', 'tool', 'update_chapter_content']);
    // 返回元信息（不含正文，避免 LLM 上下文爆炸）
    // __meta 不会被 agent_loop 截断，UI 据此渲染跳转入口
    return jsonEncode({
      'success': true,
      'message': '章节「${chapter.title}」已重写（${newContent.length} 字）。',
      'chapterTitle': chapter.title,
      'position': position,
      'novelUrl': novelUrl,
      'chapterUrl': chapterUrl,
      'charCount': newContent.length,
    });
  }

  /// 读取 AI 作家设定（用户在 AI 配置页填写的作家人设 prompt），返回 trim 后的字符串
  Future<String> _loadWriterPrompt() async {
    final raw = await PreferencesService.instance.getString('ai_writer_prompt');
    return raw.trim();
  }

  /// 拼装 LLM 上下文片段：人物卡 + 写作标签。
  ///
  /// 人物卡按名字在当前小说里查找（避免暴露/误传真实 ID）；
  /// 写作标签按名匹配，每个标签随机抽一条 prompt。
  Future<List<String>> _buildContextParts(
    String novelUrl,
    List<String> characterNames,
    List<String> tagNames,
  ) async {
    final parts = <String>[];

    // 人物卡
    if (characterNames.isNotEmpty) {
      final charRepo = ref.read(characterRepositoryProvider);
      final allCharacters = await charRepo.getCharacters(novelUrl);
      final wanted = allCharacters
          .where((c) => characterNames.contains(c.name))
          .toList();
      if (wanted.isNotEmpty) {
        parts.add(Character.formatForAI(wanted));
      }
    }

    // 写作标签（每个标签随机抽一条 prompt）
    if (tagNames.isNotEmpty) {
      final tagRepo = ref.read(promptTagRepositoryProvider);
      final allTags = await tagRepo.getAll();
      final buffer = StringBuffer('【写作标签参考】\n');
      for (final name in tagNames) {
        final matched = allTags.where((t) => t.name == name).toList();
        if (matched.isEmpty) continue;
        matched.shuffle();
        buffer.writeln('- $name：${matched.first.promptText}');
      }
      if (buffer.length > '【写作标签参考】\n'.length) {
        parts.add(buffer.toString());
      }
    }

    return parts;
  }

  /// 阻塞调用 LLM 生成正文。
  ///
  /// 由 [systemPrompt] 和 [userPrompt] 组成消息，使用写作场景的激活配置。
  /// [failTag] 用于失败日志的 tag 归属。
  Future<_RewriteResult> _callLlm({
    required String systemPrompt,
    required String userPrompt,
    required String failTag,
  }) async {
    final configService = ref.read(llmConfigServiceProvider);
    final activeConfig =
        await configService.getActiveConfig(scenarioId: ScenarioIds.writing);
    if (activeConfig == null) {
      return _RewriteResult.failure({
        'error': 'llm_not_configured',
        'message': LlmConfigService.notConfiguredMessage,
      });
    }
    final llmProviderConfig = configService.buildLlmProviderConfig(activeConfig);
    final llm = AiServiceFactory.buildLlmProvider(llmProviderConfig);

    try {
      final response = await llm.chat(
        messages: [
          ChatMessage(role: 'system', content: systemPrompt),
          ChatMessage(role: 'user', content: userPrompt),
        ],
        maxTokens: 8192,
        temperature: 0.8,
      );
      final content = response.content.trim();
      if (content.isEmpty) {
        return _RewriteResult.failure({
          'error': 'llm_empty_response',
          'message': 'LLM 返回了空内容。请稍后重试或调整要求。',
        });
      }
      return _RewriteResult.success(content);
    } catch (e, stack) {
      LoggerService.instance.e('LLM 调用失败: $e',
          stackTrace: stack.toString(),
          category: LogCategory.ai,
          tags: ['agent', 'tool', failTag, 'llm_error']);
      return _RewriteResult.failure({
        'error': 'llm_call_failed',
        'message': '调用 LLM 失败：$e',
      });
    }
  }

  /// 调用 LLM 重写章节
  ///
  /// 组合「原文 + 修改要求 + 人物卡 + 标签 prompt」为提示词，
  /// 阻塞调用 LLM，返回新正文或错误。
  Future<_RewriteResult> _rewriteChapter({
    required String novelUrl,
    required String chapterTitle,
    required String originalContent,
    required String rewriteInstruction,
    required List<String> characterNames,
    required List<String> tagNames,
  }) async {
    final writerPrompt = await _loadWriterPrompt();
    final contextParts =
        await _buildContextParts(novelUrl, characterNames, tagNames);

    final prompt = StringBuffer()
      ..writeln('请根据以下信息重写章节正文。')
      ..writeln()
      ..writeln('## 章节标题')
      ..writeln(chapterTitle)
      ..writeln()
      ..writeln('## 修改要求')
      ..writeln(rewriteInstruction)
      ..writeln();
    if (writerPrompt.isNotEmpty) {
      prompt.writeln('## AI 作家设定');
      prompt.writeln(writerPrompt);
      prompt.writeln();
    }
    if (contextParts.isNotEmpty) {
      prompt.writeln(contextParts.join('\n'));
      prompt.writeln();
    }
    prompt
      ..writeln('## 原文')
      ..writeln(originalContent)
      ..writeln()
      ..writeln('## 输出要求')
      ..writeln('请直接输出重写后的完整章节正文，不要输出任何说明、标题或解释性文字。');

    final systemPrompt = writerPrompt.isNotEmpty
        ? '$writerPrompt\n\n你是专业的小说写作助手，只输出小说正文。'
        : '你是专业的小说写作助手，只输出小说正文。';

    return _callLlm(
      systemPrompt: systemPrompt,
      userPrompt: prompt.toString(),
      failTag: 'update_chapter_content',
    );
  }

  /// 调用 LLM 创作新章节
  ///
  /// 组合「创作要求 + 人物卡 + 标签 prompt」为提示词（无原文），
  /// 阻塞调用 LLM，返回新正文或错误。
  Future<_RewriteResult> _generateChapter({
    required String novelUrl,
    required String chapterTitle,
    required String instruction,
    required List<String> characterNames,
    required List<String> tagNames,
  }) async {
    final writerPrompt = await _loadWriterPrompt();
    final contextParts =
        await _buildContextParts(novelUrl, characterNames, tagNames);

    final prompt = StringBuffer()
      ..writeln('请根据以下信息创作新的章节正文。')
      ..writeln()
      ..writeln('## 章节标题')
      ..writeln(chapterTitle)
      ..writeln()
      ..writeln('## 创作要求')
      ..writeln(instruction)
      ..writeln();
    if (writerPrompt.isNotEmpty) {
      prompt.writeln('## AI 作家设定');
      prompt.writeln(writerPrompt);
      prompt.writeln();
    }
    if (contextParts.isNotEmpty) {
      prompt.writeln(contextParts.join('\n'));
      prompt.writeln();
    }
    prompt
      ..writeln('## 输出要求')
      ..writeln('请直接输出完整的章节正文，不要输出任何说明、标题或解释性文字。');

    final systemPrompt = writerPrompt.isNotEmpty
        ? '$writerPrompt\n\n你是专业的小说写作助手，只输出小说正文。'
        : '你是专业的小说写作助手，只输出小说正文。';

    return _callLlm(
      systemPrompt: systemPrompt,
      userPrompt: prompt.toString(),
      failTag: 'create_chapter',
    );
  }

  // ===== 角色 =====

  Future<String> _listCharacters(
    Map<String, dynamic> args,
    AgentScenarioContext? ctx,
  ) async {
    final novelResolve = await _resolveCurrentNovelUrl(ctx);
    if (novelResolve.errorJson != null) {
      return jsonEncode(novelResolve.errorJson);
    }
    final novelUrl = novelResolve.url!;

    final repo = ref.read(characterRepositoryProvider);
    final characters = await repo.getCharacters(novelUrl);
    final list = characters.map((c) => {
          'name': c.name,
          'appearanceFeatures': c.appearanceFeatures,
          'gender': c.gender,
          'age': c.age,
          'occupation': c.occupation,
          'personality': c.personality,
        }).toList();

    final novelContext = _buildCurrentNovelContext(ctx);
    LoggerService.instance.i('列出角色: ${list.length} 个',
        category: LogCategory.ai, tags: ['agent', 'tool', 'list_characters']);
    return jsonEncode({
      'novel': novelContext,
      'characters': list,
      'count': list.length,
    });
  }

  Future<String> _updateCharacter(
    Map<String, dynamic> args,
    AgentScenarioContext? ctx,
  ) async {
    final parser = ToolArgParser(args);
    final (name, nameErr) = parser.requireString('name');
    if (nameErr != null) return nameErr;

    final novelResolve = await _resolveCurrentNovelUrl(ctx);
    if (novelResolve.errorJson != null) {
      return jsonEncode(novelResolve.errorJson);
    }
    final novelUrl = novelResolve.url!;

    final repo = ref.read(characterRepositoryProvider);
    final existing = await repo.findCharacterByName(novelUrl, name);
    if (existing == null) {
      LoggerService.instance.d(
        '工具引导错误: character_not_found name=$name',
        category: LogCategory.ai,
        tags: ['agent', 'tool', 'update_character', 'character_not_found'],
      );
      return jsonEncode({
        'error': 'character_not_found',
        'message': '角色 "$name" 不存在。使用 create_character 创建新角色。',
        'suggested_tool': 'list_characters',
        'suggested_args': <String, dynamic>{},
      });
    }

    final (description, _) = parser.nullableString('description');
    final (avatarUrl, _) = parser.nullableString('avatarUrl');
    final updated = existing.copyWith(
      appearanceFeatures: description ?? existing.appearanceFeatures,
      cachedImageUrl: avatarUrl ?? existing.cachedImageUrl,
    );
    await repo.updateCharacter(updated);

    LoggerService.instance.i('更新角色: "$name"',
        category: LogCategory.ai, tags: ['agent', 'tool', 'update_character']);
    return jsonEncode({'success': true, 'message': '角色 "$name" 已更新'});
  }

  Future<String> _createCharacter(
    Map<String, dynamic> args,
    AgentScenarioContext? ctx,
  ) async {
    final parser = ToolArgParser(args);
    final (name, nameErr) = parser.requireString('name');
    if (nameErr != null) return nameErr;

    final novelResolve = await _resolveCurrentNovelUrl(ctx);
    if (novelResolve.errorJson != null) {
      return jsonEncode(novelResolve.errorJson);
    }
    final novelUrl = novelResolve.url!;

    final repo = ref.read(characterRepositoryProvider);

    // 检查是否已存在
    final existing = await repo.findCharacterByName(novelUrl, name);
    if (existing != null) {
      LoggerService.instance.w('角色已存在: "$name"',
          category: LogCategory.ai,
          tags: ['agent', 'tool', 'create_character', 'duplicate']);
      return jsonEncode({
        'error': 'duplicate',
        'message': '角色 "$name" 已存在。使用 update_character 更新。',
      });
    }

    final (charDesc, _) = parser.nullableString('description');
    final character = Character(
      novelUrl: novelUrl,
      name: name,
      appearanceFeatures: charDesc ?? '',
    );
    final id = await repo.createCharacter(character);

    LoggerService.instance.i('创建角色: "$name" (id=$id)',
        category: LogCategory.ai, tags: ['agent', 'tool', 'create_character']);
    return jsonEncode({
      'success': true,
      'message': '角色 "$name" 已创建',
      'characterId': id,
    });
  }

  // ===== 设定 / 大纲 =====

  Future<String> _updateBackgroundSetting(
    Map<String, dynamic> args,
    AgentScenarioContext? ctx,
  ) async {
    final parser = ToolArgParser(args);
    final (setting, settingErr) = parser.requireString('setting');
    if (settingErr != null) return settingErr;

    final novelResolve = await _resolveCurrentNovelUrl(ctx);
    if (novelResolve.errorJson != null) {
      return jsonEncode(novelResolve.errorJson);
    }
    final currentNovelId = ctx!.currentNovelId!;

    final repo = ref.read(novelRepositoryProvider);
    final affected = await repo.updateBackgroundSettingById(currentNovelId, setting);
    if (affected == 0) {
      return jsonEncode({
        'error': 'novel_not_found',
        'message': '当前小说不存在。',
        'suggested_tool': 'list_novels',
        'suggested_args': <String, dynamic>{},
      });
    }

    LoggerService.instance.i('更新背景设定: novelId=$currentNovelId',
        category: LogCategory.ai, tags: ['agent', 'tool', 'update_background_setting']);
    return jsonEncode({'success': true, 'message': '背景设定已更新'});
  }

  Future<String> _updateOutline(
    Map<String, dynamic> args,
    AgentScenarioContext? ctx,
  ) async {
    final parser = ToolArgParser(args);
    final (title, titleErr) = parser.requireString('title');
    if (titleErr != null) return titleErr;
    final (content, contentErr) = parser.requireString('content');
    if (contentErr != null) return contentErr;

    final novelResolve = await _resolveCurrentNovelUrl(ctx);
    if (novelResolve.errorJson != null) {
      return jsonEncode(novelResolve.errorJson);
    }
    final novelUrl = novelResolve.url!;

    final repo = ref.read(outlineRepositoryProvider);
    final outline = Outline(
      novelUrl: novelUrl,
      title: title,
      content: content,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repo.saveOutline(outline);
    LoggerService.instance.i('保存大纲: "$title"',
        category: LogCategory.ai, tags: ['agent', 'tool', 'update_outline']);
    return jsonEncode({'success': true, 'message': '大纲已保存'});
  }

  Future<String> _getOutline(
    Map<String, dynamic> args,
    AgentScenarioContext? ctx,
  ) async {
    final novelResolve = await _resolveCurrentNovelUrl(ctx);
    if (novelResolve.errorJson != null) {
      return jsonEncode(novelResolve.errorJson);
    }
    final novelUrl = novelResolve.url!;

    final repo = ref.read(outlineRepositoryProvider);
    final outline = await repo.getOutlineByNovelUrl(novelUrl);
    if (outline == null) {
      LoggerService.instance.w('大纲不存在',
          category: LogCategory.ai,
          tags: ['agent', 'tool', 'get_outline', 'not_found']);
      return jsonEncode({'error': 'not_found', 'message': '暂无大纲'});
    }

    final novelContext = _buildCurrentNovelContext(ctx);
    LoggerService.instance.i('获取大纲成功',
        category: LogCategory.ai, tags: ['agent', 'tool', 'get_outline']);
    return jsonEncode({
      'novel': novelContext,
      'title': outline.title,
      'content': outline.content,
      'updatedAt': outline.updatedAt.toIso8601String(),
    });
  }

  // ===== 提示标签 =====

  Future<String> _listPromptTags(Map<String, dynamic> args) async {
    final parser = ToolArgParser(args);
    final (categoryName, _) = parser.optionalString('categoryName');

    final categoryRepo = ref.read(promptTagCategoryRepositoryProvider);
    final tagRepo = ref.read(promptTagRepositoryProvider);

    // 获取全部分类
    final allCategories = await categoryRepo.getAll();

    // 按分类名筛选
    List<PromptTagCategory> categories;
    if (categoryName != null && categoryName.isNotEmpty) {
      categories = allCategories
          .where((c) => c.name.toLowerCase() == categoryName.toLowerCase())
          .toList();
      if (categories.isEmpty) {
        LoggerService.instance.d(
          '工具引导错误: category_not_found categoryName=$categoryName',
          category: LogCategory.ai,
          tags: ['agent', 'tool', 'list_prompt_tags', 'category_not_found'],
        );
        return jsonEncode({
          'error': 'category_not_found',
          'message': '分类 "$categoryName" 不存在。可用分类：${allCategories.map((c) => c.name).join("、")}',
          'available_categories': allCategories
              .map((c) => {'id': c.id, 'name': c.name})
              .toList(),
        });
      }
    } else {
      categories = allCategories;
    }

    // 按分类获取标签
    final result = <Map<String, dynamic>>[];
    for (final category in categories) {
      final tags = await tagRepo.getByCategory(category.id!);
      result.add({
        'categoryId': category.id,
        'categoryName': category.name,
        'tags': tags
            .map((t) => {
                  'id': t.id,
                  'name': t.name,
                  'reason': t.reason,
                  'promptText': t.promptText.length > 150
                      ? '${t.promptText.substring(0, 150)}...'
                      : t.promptText,
                })
            .toList(),
        'tagCount': tags.length,
      });
    }

    final totalTags =
        result.fold<int>(0, (sum, c) => sum + (c['tagCount'] as int));
    LoggerService.instance.i(
        '列出提示标签: ${categories.length} 个分类, $totalTags 个标签',
        category: LogCategory.ai,
        tags: ['agent', 'tool', 'list_prompt_tags']);
    return jsonEncode({
      'categories': result,
      'totalTags': totalTags,
    });
  }

  Future<String> _savePromptTag(Map<String, dynamic> args) async {
    final parser = ToolArgParser(args);
    final (categoryName, cnErr) = parser.requireString('categoryName');
    if (cnErr != null) return cnErr;
    final (name, nameErr) = parser.requireString('name');
    if (nameErr != null) return nameErr;
    final (promptText, ptErr) = parser.requireString('promptText');
    if (ptErr != null) return ptErr;
    final (reasonRaw, _) = parser.optionalString('reason');
    final reason = reasonRaw ?? '';
    final (id, idErr) = parser.optionalInt('id');
    if (idErr != null) return idErr;

    final categoryRepo = ref.read(promptTagCategoryRepositoryProvider);
    final tagRepo = ref.read(promptTagRepositoryProvider);

    // 通过分类名查找 categoryId
    final allCategories = await categoryRepo.getAll();
    final category = allCategories
        .where((c) => c.name.toLowerCase() == categoryName.toLowerCase())
        .firstOrNull;
    if (category == null || category.id == null) {
      LoggerService.instance.d(
        '工具引导错误: category_not_found categoryName=$categoryName',
        category: LogCategory.ai,
        tags: ['agent', 'tool', 'save_prompt_tag', 'category_not_found'],
      );
      return jsonEncode({
        'error': 'category_not_found',
        'message': '分类 "$categoryName" 不存在。可用分类：${allCategories.map((c) => c.name).join("、")}',
        'available_categories': allCategories
            .map((c) => {'id': c.id, 'name': c.name})
            .toList(),
      });
    }
    final categoryId = category.id!;

    if (id != null) {
      // 更新已有标签
      final existingTags = await tagRepo.getByIds([id]);
      if (existingTags.isEmpty) {
        LoggerService.instance.d(
          '工具引导错误: tag_not_found id=$id',
          category: LogCategory.ai,
          tags: ['agent', 'tool', 'save_prompt_tag', 'tag_not_found'],
        );
        return jsonEncode({
          'error': 'tag_not_found',
          'message': '标签 ID $id 不存在。请先调用 list_prompt_tags 查看所有标签。',
          'suggested_tool': 'list_prompt_tags',
          'suggested_args': <String, dynamic>{},
        });
      }
      final existing = existingTags.first;
      final updated = existing.copyWith(
        categoryId: categoryId,
        name: name,
        reason: reason.isNotEmpty ? reason : existing.reason,
        promptText: promptText,
        updatedAt: DateTime.now(),
      );
      await tagRepo.save(updated);

      LoggerService.instance.i('更新提示标签: "$name" (id=$id)',
          category: LogCategory.ai,
          tags: ['agent', 'tool', 'save_prompt_tag']);
      return jsonEncode({
        'success': true,
        'message': '标签 "$name" 已更新',
        'tagId': id,
      });
    }

    // 创建新标签
    final sortOrder = await tagRepo.getNextSortOrder(categoryId);
    final now = DateTime.now();
    final newTag = PromptTag(
      categoryId: categoryId,
      name: name,
      reason: reason,
      promptText: promptText,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );
    final newId = await tagRepo.save(newTag);

    LoggerService.instance.i(
        '创建提示标签: "$name" (id=$newId, category="${category.name}")',
        category: LogCategory.ai,
        tags: ['agent', 'tool', 'save_prompt_tag']);
    return jsonEncode({
      'success': true,
      'message': '标签 "$name" 已创建（分类：${category.name}）',
      'tagId': newId,
    });
  }

  Future<String> _deletePromptTag(Map<String, dynamic> args) async {
    final parser = ToolArgParser(args);
    final (id, idErr) = parser.requireInt('id');
    if (idErr != null) return idErr;

    final tagRepo = ref.read(promptTagRepositoryProvider);

    // 确认标签存在
    final existingTags = await tagRepo.getByIds([id]);
    if (existingTags.isEmpty) {
      LoggerService.instance.d(
        '工具引导错误: tag_not_found id=$id',
        category: LogCategory.ai,
        tags: ['agent', 'tool', 'delete_prompt_tag', 'tag_not_found'],
      );
      return jsonEncode({
        'error': 'tag_not_found',
        'message': '标签 ID $id 不存在。请先调用 list_prompt_tags 查看所有标签。',
        'suggested_tool': 'list_prompt_tags',
      });
    }

    final existing = existingTags.first;
    await tagRepo.delete(id);

    LoggerService.instance.i(
        '删除提示标签: "${existing.name}" (id=$id)',
        category: LogCategory.ai,
        tags: ['agent', 'tool', 'delete_prompt_tag']);
    return jsonEncode({
      'success': true,
      'message': '标签 "${existing.name}" 已删除',
    });
  }
}
