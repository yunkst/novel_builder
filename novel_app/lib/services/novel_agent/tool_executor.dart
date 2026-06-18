/// 工具执行器 — Agent 工具 → Repository 调度
///
/// 上下文驱动：通过 [AgentScenarioContext] 读取当前小说，position 解析为 chapterUrl。
/// 错误响应包含 suggested_tool，引导 AI 自助修复。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novel_app/services/logger_service.dart';

import '../../core/providers/database_providers.dart';
import '../../models/character.dart';
import '../../models/outline.dart';
import 'agent_scenario.dart';
import 'agent_tools.dart';

/// ID/位置解析结果
class _IdResolveResult {
  final String? url;
  final Map<String, dynamic>? errorJson;
  const _IdResolveResult.success(this.url) : errorJson = null;
  const _IdResolveResult.failure(this.errorJson) : url = null;
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
        case 'update_chapter_content':
          return await _updateChapterContent(args, scenarioContext);
        case 'create_custom_chapter':
          return await _createCustomChapter(args, scenarioContext);
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

  /// 是否破坏性操作（需要用户确认）
  bool isDestructive(String toolName) =>
      AgentTools.destructiveTools.contains(toolName);

  // ===== ID / 位置解析辅助方法 =====

  /// 解析当前小说 URL（从场景上下文中读取 currentNovelId）
  ///
  /// 未设置时返回 no_current_novel 错误，引导 AI 调用 list_novels + select_novel。
  Future<_IdResolveResult> _resolveCurrentNovelUrl(
    AgentScenarioContext? ctx,
  ) async {
    final currentNovelId = ctx?.currentNovelId;
    if (currentNovelId == null) {
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
    final novelId = args['novelId'] as int;
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
    final title = (args['title'] as String?)?.trim() ?? '';
    final descriptionRaw = args['description'] as String?;
    final description =
        descriptionRaw != null && descriptionRaw.trim().isNotEmpty
            ? descriptionRaw.trim()
            : null;

    if (title.isEmpty) {
      LoggerService.instance.w('create_novel: 标题为空',
          category: LogCategory.ai,
          tags: ['agent', 'tool', 'create_novel', 'validation_failed']);
      return jsonEncode({
        'error': 'validation_failed',
        'message': '小说标题不能为空。',
      });
    }

    final dbService = ref.read(databaseServiceProvider);
    final id = await dbService.createCustomNovel(
      title,
      '原创',
      description: description,
    );

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
    final position = args['position'] as int;
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
    final keyword = args['keyword'] as String;
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
          'matchedText': r.matchedText,
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

  Future<String> _updateChapterContent(
    Map<String, dynamic> args,
    AgentScenarioContext? ctx,
  ) async {
    final position = args['position'] as int;
    final content = args['content'] as String;

    final resolveResult = await _resolveChapterUrlByPosition(ctx, position);
    if (resolveResult.errorJson != null) {
      return jsonEncode(resolveResult.errorJson);
    }
    final chapterUrl = resolveResult.url!;

    final repo = ref.read(chapterRepositoryProvider);
    final affected = await repo.updateChapterContent(chapterUrl, content);
    if (affected == 0) {
      return jsonEncode({
        'error': 'chapter_not_found',
        'message': '章节位置 $position 的数据库记录不存在或内容表无对应行。',
        'suggested_tool': 'list_chapters',
        'suggested_args': <String, dynamic>{},
      });
    }

    LoggerService.instance.i('更新章节内容: position=$position (${content.length} chars)',
        category: LogCategory.ai, tags: ['agent', 'tool', 'update_chapter_content']);
    return jsonEncode({'success': true, 'message': '章节内容已更新'});
  }

  Future<String> _createCustomChapter(
    Map<String, dynamic> args,
    AgentScenarioContext? ctx,
  ) async {
    final title = args['title'] as String;
    final content = args['content'] as String;
    final position = args['position'] as int?;

    final novelResolve = await _resolveCurrentNovelUrl(ctx);
    if (novelResolve.errorJson != null) {
      return jsonEncode(novelResolve.errorJson);
    }
    final novelUrl = novelResolve.url!;

    final repo = ref.read(chapterRepositoryProvider);
    final chapters = await repo.getCachedNovelChapters(novelUrl);

    // position 是 1-based 的目标插入位置
    // 合法范围：1 ~ chapters.length + 1（末尾追加是合法值）
    // 返回新章节在插入后的 position（用于后续章节操作）
    int resultPosition;
    int? insertIndex;
    if (position != null) {
      if (position < 1 || position > chapters.length + 1) {
        return jsonEncode({
          'error': 'chapter_position_out_of_range',
          'message':
              '插入位置 $position 超出范围（当前 ${chapters.length} 个章节，'
              '合法插入位 1~${chapters.length + 1}）。',
          'suggested_tool': 'list_chapters',
          'suggested_args': <String, dynamic>{},
        });
      }
      resultPosition = position;
      if (position <= chapters.length) {
        // 插入到 position 处，继承该位置原章节的 chapterIndex
        // 后续章节需要全部 +1 让出新位置
        insertIndex = chapters[position - 1].chapterIndex ?? position - 1;
        await repo.shiftChapterIndicesFrom(novelUrl, insertIndex);
      } else {
        // position == chapters.length + 1：追加到末尾
        insertIndex = null;
      }
    } else {
      // 不传 position → 追加到末尾
      resultPosition = chapters.length + 1;
      insertIndex = null;
    }

    final id = await repo.createCustomChapter(novelUrl, title, content, insertIndex);

    LoggerService.instance.i(
        '创建自定义章节: "$title" (id=$id, insertIndex=$insertIndex, position=$resultPosition)',
        category: LogCategory.ai, tags: ['agent', 'tool', 'create_custom_chapter']);
    return jsonEncode({
      'success': true,
      'message': '新章节 "$title" 已创建',
      'position': resultPosition,
    });
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
          'id': c.id,
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
    final name = args['name'] as String;

    final novelResolve = await _resolveCurrentNovelUrl(ctx);
    if (novelResolve.errorJson != null) {
      return jsonEncode(novelResolve.errorJson);
    }
    final novelUrl = novelResolve.url!;

    final repo = ref.read(characterRepositoryProvider);
    final existing = await repo.findCharacterByName(novelUrl, name);
    if (existing == null) {
      return jsonEncode({
        'error': 'character_not_found',
        'message': '角色 "$name" 不存在。使用 create_character 创建新角色。',
        'suggested_tool': 'list_characters',
        'suggested_args': <String, dynamic>{},
      });
    }

    final updated = existing.copyWith(
      appearanceFeatures: args['description'] as String? ?? existing.appearanceFeatures,
      cachedImageUrl: args['avatarUrl'] as String? ?? existing.cachedImageUrl,
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
    final name = args['name'] as String;

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

    final character = Character(
      novelUrl: novelUrl,
      name: name,
      appearanceFeatures: args['description'] as String? ?? '',
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
    final setting = args['setting'] as String;

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
    final title = args['title'] as String;
    final content = args['content'] as String;

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
}
