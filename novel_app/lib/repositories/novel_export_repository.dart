import '../models/novel.dart';
import '../models/novel_export_data.dart';
import '../models/character.dart';
import '../models/character_relationship.dart';
import '../services/logger_service.dart';
import '../core/interfaces/repositories/i_chapter_repository.dart';
import '../core/interfaces/repositories/i_character_repository.dart';
import '../core/interfaces/repositories/i_character_relation_repository.dart';
import '../core/interfaces/repositories/i_outline_repository.dart';

/// 小说数据导出/导入结果
class ExportImportResult {
  final bool success;
  final String? errorMessage;
  final Map<String, int> statistics;

  const ExportImportResult({
    required this.success,
    this.errorMessage,
    this.statistics = const {},
  });

  factory ExportImportResult.success(Map<String, int> statistics) {
    return ExportImportResult(success: true, statistics: statistics);
  }

  factory ExportImportResult.failure(String errorMessage) {
    return ExportImportResult(success: false, errorMessage: errorMessage);
  }
}

/// 小说数据导出/导入Repository
///
/// 负责小说数据的导出和导入操作，包括：
/// - 导出小说数据（章节、角色、关系、大纲）为JSON格式
/// - 导入小说数据，替换本地数据库
///
/// 依赖注入：
/// - IChapterRepository: 章节数据访问
/// - ICharacterRepository: 角色数据访问
/// - ICharacterRelationRepository: 角色关系数据访问
/// - IOutlineRepository: 大纲数据访问
class NovelExportRepository {
  final IChapterRepository _chapterRepository;
  final ICharacterRepository _characterRepository;
  final ICharacterRelationRepository _characterRelationRepository;
  final IOutlineRepository _outlineRepository;

  /// 构造函数 - 通过依赖注入接收各Repository实例
  NovelExportRepository({
    required IChapterRepository chapterRepository,
    required ICharacterRepository characterRepository,
    required ICharacterRelationRepository characterRelationRepository,
    required IOutlineRepository outlineRepository,
  })  : _chapterRepository = chapterRepository,
        _characterRepository = characterRepository,
        _characterRelationRepository = characterRelationRepository,
        _outlineRepository = outlineRepository;

  /// 导出小说数据
  ///
  /// 将小说的所有关联数据（章节、角色、关系、大纲）导出为NovelExportData格式
  ///
  /// [novel] 要导出的小说对象
  /// 返回包含所有数据的NovelExportData对象
  Future<NovelExportData> exportNovel(Novel novel) async {
    try {
      LoggerService.instance.i(
        '开始导出小说数据: ${novel.title}',
        category: LogCategory.database,
        tags: ['export', 'novel', 'start'],
      );

      final novelUrl = novel.url;

      // 1. 导出章节数据
      final chapters = await _exportChapters(novelUrl);

      // 2. 导出角色数据
      final characters = await _characterRepository.getCharacters(novelUrl);
      final characterExportData = characters
          .map((c) => CharacterExportData.fromCharacter(c))
          .toList();

      // 3. 导出角色关系数据（需要角色名称映射）
      final relationships = await _exportRelationships(novelUrl, characters);

      // 4. 导出大纲数据
      final outline = await _outlineRepository.getOutlineByNovelUrl(novelUrl);
      final outlineExportData =
          outline != null ? OutlineExportData.fromOutline(outline) : null;

      final exportData = NovelExportData(
        novelUrl: novelUrl,
        title: novel.title,
        author: novel.author,
        coverUrl: novel.coverUrl,
        description: novel.description,
        backgroundSetting: novel.backgroundSetting,
        chapters: chapters,
        characters: characterExportData,
        relationships: relationships,
        outline: outlineExportData,
      );

      LoggerService.instance.i(
        '小说数据导出完成: ${novel.title}, ${exportData.summary}',
        category: LogCategory.database,
        tags: ['export', 'novel', 'success'],
      );

      return exportData;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '导出小说数据失败: ${novel.title} - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['export', 'novel', 'error'],
      );
      rethrow;
    }
  }

  /// 导出章节数据
  Future<List<ChapterExportData>> _exportChapters(String novelUrl) async {
    final chapters = await _chapterRepository.getCachedNovelChapters(novelUrl);
    final chapterExportData = <ChapterExportData>[];

    for (final chapter in chapters) {
      // 获取章节内容
      String? content;
      if (chapter.isCached) {
        content = await _chapterRepository.getCachedChapter(chapter.url);
      }

      chapterExportData.add(ChapterExportData(
        title: chapter.title,
        url: chapter.url,
        content: content ?? chapter.content,
        chapterIndex: chapter.chapterIndex,
        isUserInserted: chapter.isUserInserted,
        readAt: chapter.readAt,
        isAccompanied: chapter.isAccompanied,
      ));
    }

    return chapterExportData;
  }

  /// 导出角色关系数据
  Future<List<CharacterRelationExportData>> _exportRelationships(
    String novelUrl,
    List<Character> characters,
  ) async {
    final relationships =
        await _characterRelationRepository.getAllRelationships(novelUrl);

    // 创建角色ID到名称的映射
    final idToNameMap = <int, String>{};
    for (final character in characters) {
      if (character.id != null) {
        idToNameMap[character.id!] = character.name;
      }
    }

    final relationExportData = <CharacterRelationExportData>[];

    for (final relationship in relationships) {
      final sourceName = idToNameMap[relationship.sourceCharacterId];
      final targetName = idToNameMap[relationship.targetCharacterId];

      if (sourceName != null && targetName != null) {
        relationExportData.add(CharacterRelationExportData.fromRelationship(
          relationship,
          sourceName: sourceName,
          targetName: targetName,
        ));
      } else {
        LoggerService.instance.w(
          '跳过无法映射的关系: source=${relationship.sourceCharacterId}, target=${relationship.targetCharacterId}',
          category: LogCategory.database,
          tags: ['export', 'relationship', 'missing_character'],
        );
      }
    }

    return relationExportData;
  }

  /// 导入小说数据
  ///
  /// 将NovelExportData中的数据导入到本地数据库，替换现有数据
  ///
  /// [exportData] 要导入的数据
  /// [deleteExisting] 是否删除现有数据后再导入，默认为true
  /// 返回导入结果
  Future<ExportImportResult> importNovel(
    NovelExportData exportData, {
    bool deleteExisting = true,
  }) async {
    try {
      LoggerService.instance.i(
        '开始导入小说数据: ${exportData.title}',
        category: LogCategory.database,
        tags: ['import', 'novel', 'start'],
      );

      final novelUrl = exportData.novelUrl;
      final statistics = <String, int>{};

      // 1. 如果需要，删除现有数据
      if (deleteExisting) {
        await _deleteExistingData(novelUrl);
      }

      // 2. 导入章节数据
      statistics['chapters'] = await _importChapters(novelUrl, exportData.chapters);

      // 3. 导入角色数据
      final characterIdMap = await _importCharacters(novelUrl, exportData.characters);
      statistics['characters'] = characterIdMap.length;

      // 4. 导入角色关系数据
      statistics['relationships'] =
          await _importRelationships(novelUrl, exportData.relationships, characterIdMap);

      // 5. 导入大纲数据
      if (exportData.outline != null) {
        final outline = exportData.outline!.toOutline(novelUrl);
        await _outlineRepository.saveOutline(outline);
        statistics['outline'] = 1;
      } else {
        statistics['outline'] = 0;
      }

      LoggerService.instance.i(
        '小说数据导入完成: ${exportData.title}, 统计: $statistics',
        category: LogCategory.database,
        tags: ['import', 'novel', 'success'],
      );

      return ExportImportResult.success(statistics);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '导入小说数据失败: ${exportData.title} - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['import', 'novel', 'error'],
      );
      return ExportImportResult.failure(e.toString());
    }
  }

  /// 删除现有数据
  Future<void> _deleteExistingData(String novelUrl) async {
    // 删除章节缓存和列表
    await _chapterRepository.deleteCachedChapters(novelUrl);

    // 删除角色关系（需要先删除，因为依赖角色）
    final characters = await _characterRepository.getCharacters(novelUrl);
    for (final character in characters) {
      if (character.id != null) {
        final relationships =
            await _characterRelationRepository.getRelationships(character.id!);
        for (final rel in relationships) {
          if (rel.id != null) {
            await _characterRelationRepository.deleteRelationship(rel.id!);
          }
        }
      }
    }

    // 删除角色
    await _characterRepository.deleteAllCharacters(novelUrl);

    // 删除大纲
    await _outlineRepository.deleteOutline(novelUrl);

    LoggerService.instance.i(
      '已删除现有数据: $novelUrl',
      category: LogCategory.database,
      tags: ['import', 'delete_existing'],
    );
  }

  /// 导入章节数据
  Future<int> _importChapters(
    String novelUrl,
    List<ChapterExportData> chapters,
  ) async {
    int count = 0;

    for (final chapterData in chapters) {
      final chapter = chapterData.toChapter();

      // 导入章节列表元数据
      if (chapter.chapterIndex != null) {
        await _chapterRepository.cacheNovelChapters(novelUrl, [chapter]);
      }

      // 如果有内容，缓存章节内容
      if (chapterData.content != null && chapterData.content!.isNotEmpty) {
        await _chapterRepository.cacheChapter(
          novelUrl,
          chapter,
          chapterData.content!,
        );
      }

      // 恢复阅读状态
      if (chapterData.readAt != null) {
        await _chapterRepository.markChapterAsRead(novelUrl, chapter.url);
      }

      // 恢复伴读状态
      if (chapterData.isAccompanied) {
        await _chapterRepository.markChapterAsAccompanied(novelUrl, chapter.url);
      }

      count++;
    }

    return count;
  }

  /// 导入角色数据
  ///
  /// 返回角色名称到新ID的映射
  Future<Map<String, int>> _importCharacters(
    String novelUrl,
    List<CharacterExportData> characters,
  ) async {
    final nameToIdMap = <String, int>{};

    for (final characterData in characters) {
      final character = characterData.toCharacter(novelUrl);
      final id = await _characterRepository.createCharacter(character);
      nameToIdMap[characterData.name] = id;

      // 恢复头像缓存
      if (characterData.cachedImageUrl != null) {
        await _characterRepository.updateCharacterCachedImage(
          id,
          characterData.cachedImageUrl,
        );
      }
    }

    return nameToIdMap;
  }

  /// 导入角色关系数据
  Future<int> _importRelationships(
    String novelUrl,
    List<CharacterRelationExportData> relationships,
    Map<String, int> characterIdMap,
  ) async {
    int count = 0;

    for (final relationData in relationships) {
      final sourceId = characterIdMap[relationData.sourceCharacterName];
      final targetId = characterIdMap[relationData.targetCharacterName];

      if (sourceId != null && targetId != null) {
        final relationship = CharacterRelationship(
          sourceCharacterId: sourceId,
          targetCharacterId: targetId,
          relationshipType: relationData.relationshipType,
          description: relationData.description,
        );

        await _characterRelationRepository.createRelationship(relationship);
        count++;
      } else {
        LoggerService.instance.w(
          '跳过无法映射的导入关系: ${relationData.sourceCharacterName} -> ${relationData.targetCharacterName}',
          category: LogCategory.database,
          tags: ['import', 'relationship', 'missing_character'],
        );
      }
    }

    return count;
  }

  /// 验证导出数据
  ///
  /// 检查导出数据是否有效
  static bool validateExportData(NovelExportData exportData) {
    // 检查必要字段
    if (exportData.novelUrl.isEmpty) {
      return false;
    }
    if (exportData.title.isEmpty) {
      return false;
    }
    if (exportData.author.isEmpty) {
      return false;
    }

    // 检查章节URL唯一性
    final chapterUrls = <String>{};
    for (final chapter in exportData.chapters) {
      if (chapter.url.isEmpty) {
        return false;
      }
      if (chapterUrls.contains(chapter.url)) {
        return false;
      }
      chapterUrls.add(chapter.url);
    }

    return true;
  }
}