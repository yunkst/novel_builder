/// 工具执行器 — Agent 工具 → Repository 调度
///
/// 全面 ID 化：通过 novelId / chapterId 操作，由执行器内部解析为 URL
/// 错误响应包含 suggested_tool，引导 AI 自助修复
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novel_app/services/logger_service.dart';

import '../../core/providers/database_providers.dart';
import '../../models/character.dart';
import '../../models/outline.dart';
import 'agent_tools.dart';

/// ID 解析结果
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
  Future<String> execute(String toolName, Map<String, dynamic> args) async {
    LoggerService.instance.d('执行工具: $toolName (args=${args.keys.toList()})',
        category: LogCategory.ai, tags: ['agent', 'tool', toolName, 'exec']);
    try {
      switch (toolName) {
        // ===== 小说 =====
        case 'list_novels':
          return await _listNovels(args);
        // ===== 章节读取 =====
        case 'read_chapter_content':
          return await _readChapterContent(args);
        case 'list_chapters':
          return await _listChapters(args);
        case 'search_in_chapters':
          return await _searchInChapters(args);
        // ===== 章节写入 =====
        case 'update_chapter_content':
          return await _updateChapterContent(args);
        case 'create_custom_chapter':
          return await _createCustomChapter(args);
        // ===== 角色 =====
        case 'list_characters':
          return await _listCharacters(args);
        case 'update_character':
          return await _updateCharacter(args);
        case 'create_character':
          return await _createCharacter(args);
        // ===== 设定 / 大纲 =====
        case 'update_background_setting':
          return await _updateBackgroundSetting(args);
        case 'update_outline':
          return await _updateOutline(args);
        case 'get_outline':
          return await _getOutline(args);
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

  // ===== ID 解析辅助方法 =====

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

  /// 构造小说上下文对象 {id, title} 用于返回结果
  Future<Map<String, dynamic>?> _buildNovelContext(int novelId) async {
    final repo = ref.read(novelRepositoryProvider);
    final novel = await repo.getNovelById(novelId);
    if (novel == null) return null;
    return {'id': novel.id, 'title': novel.title};
  }

  // ===== 小说 =====

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

  // ===== 章节读取 =====

  Future<String> _readChapterContent(Map<String, dynamic> args) async {
    final chapterId = args['chapterId'] as int;
    final repo = ref.read(chapterRepositoryProvider);

    // 直接通过 ID 查完整 Chapter（含 JOIN 信息）
    final chapter = await repo.getChapterById(chapterId);
    if (chapter == null) {
      LoggerService.instance.w('章节不存在: id=$chapterId',
          category: LogCategory.ai, tags: ['agent', 'tool', 'read_chapter_content', 'not_found']);
      return jsonEncode({
        'error': 'chapter_not_found',
        'message':
            '章节ID $chapterId 不存在。请先调用 list_chapters 查看小说的所有章节及其ID。',
        'suggested_tool': 'list_chapters',
        'suggested_args': <String, dynamic>{},
      });
    }

    if (chapter.content == null || chapter.content!.isEmpty) {
      LoggerService.instance.w('章节未缓存: id=$chapterId, title=${chapter.title}',
          category: LogCategory.ai, tags: ['agent', 'tool', 'read_chapter_content', 'not_cached']);
      return jsonEncode({
        'error': 'not_cached',
        'message':
            '章节 "${chapter.title}" (ID: $chapterId) 存在但内容尚未缓存，无法读取。',
        'suggested_action': '请告知用户该章节需要先加载/缓存。',
      });
    }

    LoggerService.instance.i('读取章节成功: id=$chapterId (${chapter.content!.length} chars)',
        category: LogCategory.ai, tags: ['agent', 'tool', 'read_chapter_content']);
    return chapter.content!;
  }

  Future<String> _listChapters(Map<String, dynamic> args) async {
    final novelId = args['novelId'] as int;
    final resolveResult = await _resolveNovelUrl(novelId);
    if (resolveResult.errorJson != null) {
      return jsonEncode(resolveResult.errorJson);
    }
    final novelUrl = resolveResult.url!;

    final repo = ref.read(chapterRepositoryProvider);
    final chapters = await repo.getCachedNovelChapters(novelUrl);
    final list = chapters.map((c) => {
          'id': c.id,
          'title': c.title,
          'index': c.chapterIndex,
          'isCached': c.isCached,
        }).toList();

    final novelContext = await _buildNovelContext(novelId);
    LoggerService.instance.i('列出章节: novelId=$novelId (${list.length} 章)',
        category: LogCategory.ai, tags: ['agent', 'tool', 'list_chapters']);
    return jsonEncode({
      'novel': novelContext,
      'chapters': list,
      'count': list.length,
    });
  }

  Future<String> _searchInChapters(Map<String, dynamic> args) async {
    final novelId = args['novelId'] as int;
    final keyword = args['keyword'] as String;
    final resolveResult = await _resolveNovelUrl(novelId);
    if (resolveResult.errorJson != null) {
      return jsonEncode(resolveResult.errorJson);
    }
    final novelUrl = resolveResult.url!;

    final repo = ref.read(chapterRepositoryProvider);
    final results = await repo.searchInCachedContent(
      keyword,
      novelUrl: novelUrl,
    );

    // 解析每个结果项的 chapterId
    final list = <Map<String, dynamic>>[];
    for (final r in results) {
      final cid = await repo.getChapterIdByUrl(r.chapterUrl);
      list.add({
        'chapterId': cid,
        'chapterTitle': r.chapterTitle,
        'matchedText': r.matchedText,
        'matchCount': r.matchCount,
      });
    }

    final novelContext = await _buildNovelContext(novelId);
    LoggerService.instance.i('章节搜索: novelId=$novelId, keyword="$keyword", ${list.length} 个匹配',
        category: LogCategory.ai, tags: ['agent', 'tool', 'search_in_chapters']);
    return jsonEncode({
      'novel': novelContext,
      'results': list,
      'count': list.length,
    });
  }

  // ===== 章节写入 =====

  Future<String> _updateChapterContent(Map<String, dynamic> args) async {
    final chapterId = args['chapterId'] as int;
    final content = args['content'] as String;
    final repo = ref.read(chapterRepositoryProvider);

    final affected = await repo.updateChapterContentById(chapterId, content);
    if (affected == 0) {
      return jsonEncode({
        'error': 'chapter_not_found',
        'message':
            '章节ID $chapterId 不存在。请先调用 list_chapters 查看小说的所有章节及其ID。',
        'suggested_tool': 'list_chapters',
        'suggested_args': <String, dynamic>{},
      });
    }

    LoggerService.instance.i('更新章节内容: id=$chapterId (${content.length} chars)',
        category: LogCategory.ai, tags: ['agent', 'tool', 'update_chapter_content']);
    return jsonEncode({'success': true, 'message': '章节内容已更新'});
  }

  Future<String> _createCustomChapter(Map<String, dynamic> args) async {
    final novelId = args['novelId'] as int;
    final title = args['title'] as String;
    final content = args['content'] as String;
    final index = args['index'] as int?;

    final resolveResult = await _resolveNovelUrl(novelId);
    if (resolveResult.errorJson != null) {
      return jsonEncode(resolveResult.errorJson);
    }
    final novelUrl = resolveResult.url!;

    final repo = ref.read(chapterRepositoryProvider);
    final id = await repo.createCustomChapter(novelUrl, title, content, index);
    LoggerService.instance.i('创建自定义章节: "$title" (id=$id)',
        category: LogCategory.ai, tags: ['agent', 'tool', 'create_custom_chapter']);
    return jsonEncode({
      'success': true,
      'message': '新章节 "$title" 已创建',
      'chapterId': id,
    });
  }

  // ===== 角色 =====

  Future<String> _listCharacters(Map<String, dynamic> args) async {
    final novelId = args['novelId'] as int;
    final resolveResult = await _resolveNovelUrl(novelId);
    if (resolveResult.errorJson != null) {
      return jsonEncode(resolveResult.errorJson);
    }
    final novelUrl = resolveResult.url!;

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

    final novelContext = await _buildNovelContext(novelId);
    LoggerService.instance.i('列出角色: novelId=$novelId (${list.length} 个)',
        category: LogCategory.ai, tags: ['agent', 'tool', 'list_characters']);
    return jsonEncode({
      'novel': novelContext,
      'characters': list,
      'count': list.length,
    });
  }

  Future<String> _updateCharacter(Map<String, dynamic> args) async {
    final novelId = args['novelId'] as int;
    final name = args['name'] as String;

    final resolveResult = await _resolveNovelUrl(novelId);
    if (resolveResult.errorJson != null) {
      return jsonEncode(resolveResult.errorJson);
    }
    final novelUrl = resolveResult.url!;

    final repo = ref.read(characterRepositoryProvider);
    final existing = await repo.findCharacterByName(novelUrl, name);
    if (existing == null) {
      return jsonEncode({
        'error': 'character_not_found',
        'message': '角色 "$name" 不存在。使用 create_character 创建新角色。',
        'suggested_tool': 'list_characters',
        'suggested_args': {'novelId': novelId},
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

  Future<String> _createCharacter(Map<String, dynamic> args) async {
    final novelId = args['novelId'] as int;
    final name = args['name'] as String;

    final resolveResult = await _resolveNovelUrl(novelId);
    if (resolveResult.errorJson != null) {
      return jsonEncode(resolveResult.errorJson);
    }
    final novelUrl = resolveResult.url!;

    final repo = ref.read(characterRepositoryProvider);

    // 检查是否已存在
    final existing = await repo.findCharacterByName(novelUrl, name);
    if (existing != null) {
      LoggerService.instance.w('角色已存在: "$name"',
          category: LogCategory.ai, tags: ['agent', 'tool', 'create_character', 'duplicate']);
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

  Future<String> _updateBackgroundSetting(Map<String, dynamic> args) async {
    final novelId = args['novelId'] as int;
    final setting = args['setting'] as String;

    final repo = ref.read(novelRepositoryProvider);
    final affected = await repo.updateBackgroundSettingById(novelId, setting);
    if (affected == 0) {
      return jsonEncode({
        'error': 'novel_not_found',
        'message': '小说ID $novelId 不存在。请先调用 list_novels 查看书架中的所有小说及其ID。',
        'suggested_tool': 'list_novels',
        'suggested_args': <String, dynamic>{},
      });
    }

    LoggerService.instance.i('更新背景设定: novelId=$novelId',
        category: LogCategory.ai, tags: ['agent', 'tool', 'update_background_setting']);
    return jsonEncode({'success': true, 'message': '背景设定已更新'});
  }

  Future<String> _updateOutline(Map<String, dynamic> args) async {
    final novelId = args['novelId'] as int;
    final title = args['title'] as String;
    final content = args['content'] as String;

    final resolveResult = await _resolveNovelUrl(novelId);
    if (resolveResult.errorJson != null) {
      return jsonEncode(resolveResult.errorJson);
    }
    final novelUrl = resolveResult.url!;

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

  Future<String> _getOutline(Map<String, dynamic> args) async {
    final novelId = args['novelId'] as int;
    final resolveResult = await _resolveNovelUrl(novelId);
    if (resolveResult.errorJson != null) {
      return jsonEncode(resolveResult.errorJson);
    }
    final novelUrl = resolveResult.url!;

    final repo = ref.read(outlineRepositoryProvider);
    final outline = await repo.getOutlineByNovelUrl(novelUrl);
    if (outline == null) {
      LoggerService.instance.w('大纲不存在: novelId=$novelId',
          category: LogCategory.ai, tags: ['agent', 'tool', 'get_outline', 'not_found']);
      return jsonEncode({'error': 'not_found', 'message': '暂无大纲'});
    }

    final novelContext = await _buildNovelContext(novelId);
    LoggerService.instance.i('获取大纲成功: novelId=$novelId',
        category: LogCategory.ai, tags: ['agent', 'tool', 'get_outline']);
    return jsonEncode({
      'novel': novelContext,
      'title': outline.title,
      'content': outline.content,
      'updatedAt': outline.updatedAt.toIso8601String(),
    });
  }
}
