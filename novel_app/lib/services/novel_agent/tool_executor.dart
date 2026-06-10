/// 工具执行器 — Agent 工具 → Repository 调度
///
/// Phase 2: 接收工具名和参数，调用对应的 Repository 方法
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novel_app/services/logger_service.dart';

import '../../core/providers/database_providers.dart';
import '../../models/character.dart';
import '../../models/outline.dart';
import 'agent_tools.dart';

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
        case 'rewrite_chapter_paragraph':
          return await _rewriteParagraph(args);
        case 'insert_paragraph':
          return await _insertParagraph(args);
        case 'delete_paragraph':
          return await _deleteParagraph(args);
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

  // ===== 小说 =====

  Future<String> _listNovels(Map<String, dynamic> args) async {
    final repo = ref.read(novelRepositoryProvider);
    final novels = await repo.getNovels();
    final list = novels.map((n) => {
          'title': n.title,
          'author': n.author,
          'url': n.url,
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
    final repo = ref.read(chapterRepositoryProvider);
    final content = await repo.getCachedChapter(args['chapterUrl'] as String);
    if (content == null) {
      LoggerService.instance.w('章节未缓存: ${args['chapterUrl']}',
          category: LogCategory.ai, tags: ['agent', 'tool', 'read_chapter_content', 'not_found']);
      return jsonEncode({
        'error': 'not_found',
        'message': '章节未缓存或不存在',
      });
    }
    LoggerService.instance.i('读取章节成功: ${args['chapterUrl']} (${content.length} chars)',
        category: LogCategory.ai, tags: ['agent', 'tool', 'read_chapter_content']);
    return content;
  }

  Future<String> _listChapters(Map<String, dynamic> args) async {
    final repo = ref.read(chapterRepositoryProvider);
    final chapters = await repo.getCachedNovelChapters(args['novelUrl'] as String);
    final list = chapters.map((c) => {
          'title': c.title,
          'url': c.url,
          'index': c.chapterIndex,
          'isCached': c.isCached,
        }).toList();
    LoggerService.instance.i('列出章节: ${args['novelUrl']} (${list.length} 章)',
        category: LogCategory.ai, tags: ['agent', 'tool', 'list_chapters']);
    return jsonEncode({'chapters': list, 'count': list.length});
  }

  Future<String> _searchInChapters(Map<String, dynamic> args) async {
    final repo = ref.read(chapterRepositoryProvider);
    final results = await repo.searchInCachedContent(
      args['keyword'] as String,
      novelUrl: args['novelUrl'] as String?,
    );
    final list = results.map((r) => {
          'chapterTitle': r.chapterTitle,
          'chapterUrl': r.chapterUrl,
          'matchedText': r.matchedText,
          'matchCount': r.matchCount,
        }).toList();
    LoggerService.instance.i('章节搜索: keyword="${args['keyword']}", ${list.length} 个匹配',
        category: LogCategory.ai, tags: ['agent', 'tool', 'search_in_chapters']);
    return jsonEncode({'results': list, 'count': list.length});
  }

  // ===== 章节写入 =====

  Future<String> _updateChapterContent(Map<String, dynamic> args) async {
    final repo = ref.read(chapterRepositoryProvider);
    await repo.updateChapterContent(
      args['chapterUrl'] as String,
      args['content'] as String,
    );
    LoggerService.instance.i('更新章节内容: ${args['chapterUrl']} (${(args['content'] as String).length} chars)',
        category: LogCategory.ai, tags: ['agent', 'tool', 'update_chapter_content']);
    return jsonEncode({'success': true, 'message': '章节内容已更新'});
  }

  Future<String> _rewriteParagraph(Map<String, dynamic> args) async {
    final repo = ref.read(chapterRepositoryProvider);
    final chapterUrl = args['chapterUrl'] as String;
    final paraIndex = args['paragraphIndex'] as int;
    final instruction = args['instruction'] as String;

    // 读取原文
    final rawContent = await repo.getCachedChapter(chapterUrl);
    if (rawContent == null) {
      return jsonEncode({'error': 'not_found', 'message': '章节未缓存'});
    }

    final paragraphs = rawContent.split('\n\n');
    if (paraIndex < 0 || paraIndex >= paragraphs.length) {
      return jsonEncode({
        'error': 'invalid_index',
        'message': '段落索引 $paraIndex 超出范围 (0-${paragraphs.length - 1})',
      });
    }

    // 改写段落 — 由 Agent 的 LLM 在循环中完成，这里只做文本替换
    // 注意：rewrite 工具的特殊之处在于 LLM 已经在上一轮思考中给出了改写文本
    // 如果 instruction 中包含改写后的文本，直接替换
    // 否则返回原文让 LLM 在下一轮处理
    final rewritten = instruction; // LLM 应该把改写后的内容放在 instruction 中
    paragraphs[paraIndex] = rewritten;
    await repo.updateChapterContent(chapterUrl, paragraphs.join('\n\n'));

    LoggerService.instance.i('改写段落: $chapterUrl[$paraIndex]',
        category: LogCategory.ai, tags: ['agent', 'tool', 'rewrite_chapter_paragraph']);
    return jsonEncode({
      'success': true,
      'message': '段落 $paraIndex 已改写',
      'newText': rewritten.substring(0, 200),
    });
  }

  Future<String> _insertParagraph(Map<String, dynamic> args) async {
    final repo = ref.read(chapterRepositoryProvider);
    final chapterUrl = args['chapterUrl'] as String;
    final afterIndex = args['afterParagraphIndex'] as int;
    final newParagraph = args['newParagraph'] as String;

    final rawContent = await repo.getCachedChapter(chapterUrl);
    if (rawContent == null) {
      return jsonEncode({'error': 'not_found', 'message': '章节未缓存'});
    }

    final paragraphs = rawContent.split('\n\n');
    if (afterIndex < -1 || afterIndex >= paragraphs.length) {
      return jsonEncode({
        'error': 'invalid_index',
        'message': '插入位置 $afterIndex 无效',
      });
    }

    paragraphs.insert(afterIndex + 1, newParagraph);
    await repo.updateChapterContent(chapterUrl, paragraphs.join('\n\n'));

    LoggerService.instance.i('插入段落: $chapterUrl[afterIndex+1]',
        category: LogCategory.ai, tags: ['agent', 'tool', 'insert_paragraph']);
    return jsonEncode({
      'success': true,
      'message': '已在段落 $afterIndex 后插入新段落',
    });
  }

  Future<String> _deleteParagraph(Map<String, dynamic> args) async {
    final repo = ref.read(chapterRepositoryProvider);
    final chapterUrl = args['chapterUrl'] as String;
    final paraIndex = args['paragraphIndex'] as int;

    final rawContent = await repo.getCachedChapter(chapterUrl);
    if (rawContent == null) {
      return jsonEncode({'error': 'not_found', 'message': '章节未缓存'});
    }

    final paragraphs = rawContent.split('\n\n');
    if (paraIndex < 0 || paraIndex >= paragraphs.length) {
      return jsonEncode({
        'error': 'invalid_index',
        'message': '段落索引 $paraIndex 超出范围',
      });
    }

    final deleted = paragraphs.removeAt(paraIndex);
    await repo.updateChapterContent(chapterUrl, paragraphs.join('\n\n'));

    LoggerService.instance.i('删除段落: $chapterUrl[$paraIndex]',
        category: LogCategory.ai, tags: ['agent', 'tool', 'delete_paragraph']);
    return jsonEncode({
      'success': true,
      'message': '已删除段落 $paraIndex',
      'deletedPreview': deleted.substring(0, 100),
    });
  }

  Future<String> _createCustomChapter(Map<String, dynamic> args) async {
    final repo = ref.read(chapterRepositoryProvider);
    final novelUrl = args['novelUrl'] as String;
    final title = args['title'] as String;
    final content = args['content'] as String;
    final index = args['index'] as int?;

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
    final repo = ref.read(characterRepositoryProvider);
    final characters = await repo.getCharacters(args['novelUrl'] as String);
    final list = characters.map((c) => {
          'id': c.id,
          'name': c.name,
          'appearanceFeatures': c.appearanceFeatures,
          'gender': c.gender,
          'age': c.age,
          'occupation': c.occupation,
          'personality': c.personality,
        }).toList();
    LoggerService.instance.i('列出角色: ${args['novelUrl']} (${list.length} 个)',
        category: LogCategory.ai, tags: ['agent', 'tool', 'list_characters']);
    return jsonEncode({'characters': list, 'count': list.length});
  }

  Future<String> _updateCharacter(Map<String, dynamic> args) async {
    final repo = ref.read(characterRepositoryProvider);
    final novelUrl = args['novelUrl'] as String;
    final name = args['name'] as String;

    final existing = await repo.findCharacterByName(novelUrl, name);
    if (existing == null) {
      return jsonEncode({
        'error': 'not_found',
        'message': '角色 "$name" 不存在。使用 create_character 创建新角色。',
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
    final repo = ref.read(characterRepositoryProvider);
    final novelUrl = args['novelUrl'] as String;
    final name = args['name'] as String;

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
    final repo = ref.read(novelRepositoryProvider);
    await repo.updateBackgroundSetting(
      args['novelUrl'] as String,
      args['setting'] as String,
    );
    LoggerService.instance.i('更新背景设定: ${args['novelUrl']}',
        category: LogCategory.ai, tags: ['agent', 'tool', 'update_background_setting']);
    return jsonEncode({'success': true, 'message': '背景设定已更新'});
  }

  Future<String> _updateOutline(Map<String, dynamic> args) async {
    final repo = ref.read(outlineRepositoryProvider);
    final outline = Outline(
      novelUrl: args['novelUrl'] as String,
      title: args['title'] as String,
      content: args['content'] as String,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repo.saveOutline(outline);
    LoggerService.instance.i('保存大纲: "${args['title']}"',
        category: LogCategory.ai, tags: ['agent', 'tool', 'update_outline']);
    return jsonEncode({'success': true, 'message': '大纲已保存'});
  }

  Future<String> _getOutline(Map<String, dynamic> args) async {
    final repo = ref.read(outlineRepositoryProvider);
    final outline = await repo.getOutlineByNovelUrl(args['novelUrl'] as String);
    if (outline == null) {
      LoggerService.instance.w('大纲不存在: ${args['novelUrl']}',
          category: LogCategory.ai, tags: ['agent', 'tool', 'get_outline', 'not_found']);
      return jsonEncode({'error': 'not_found', 'message': '暂无大纲'});
    }
    LoggerService.instance.i('获取大纲成功: ${args['novelUrl']}',
        category: LogCategory.ai, tags: ['agent', 'tool', 'get_outline']);
    return jsonEncode({
      'title': outline.title,
      'content': outline.content,
      'updatedAt': outline.updatedAt.toIso8601String(),
    });
  }
}