import 'package:built_collection/built_collection.dart';
import 'package:novel_api/novel_api.dart';

import '../models/novel.dart' as local;
import '../models/novel_export_data.dart';
import '../repositories/novel_export_repository.dart';
import '../core/interfaces/repositories/i_novel_repository.dart';
import '../services/logger_service.dart';
import '../services/api_service_wrapper.dart';

/// 同步操作结果
class SyncResult {
  final bool success;
  final String? errorMessage;
  final Map<String, dynamic>? data;

  const SyncResult({
    required this.success,
    this.errorMessage,
    this.data,
  });

  factory SyncResult.success([Map<String, dynamic>? data]) {
    return SyncResult(success: true, data: data);
  }

  factory SyncResult.failure(String errorMessage) {
    return SyncResult(success: false, errorMessage: errorMessage);
  }
}

/// 批量同步结果
class BatchSyncResult {
  final int total;
  final int successCount;
  final int failureCount;
  final List<String> successTitles;
  final List<String> failureTitles;
  final Map<String, String> errorMessages;

  const BatchSyncResult({
    required this.total,
    this.successCount = 0,
    this.failureCount = 0,
    this.successTitles = const [],
    this.failureTitles = const [],
    this.errorMessages = const {},
  });

  BatchSyncResult copyWith({
    int? successCount,
    int? failureCount,
    List<String>? successTitles,
    List<String>? failureTitles,
    Map<String, String>? errorMessages,
  }) {
    return BatchSyncResult(
      total: total,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      successTitles: successTitles ?? this.successTitles,
      failureTitles: failureTitles ?? this.failureTitles,
      errorMessages: errorMessages ?? this.errorMessages,
    );
  }
}

/// 已同步小说信息
class SyncedNovelInfo {
  final String title;
  final String? author;
  final int syncVersion;
  final DateTime syncedAt;

  const SyncedNovelInfo({
    required this.title,
    this.author,
    required this.syncVersion,
    required this.syncedAt,
  });
}

/// 小说同步服务
///
/// 负责小说数据的上传、下载和列表查询操作。
/// 适配精简后的同步格式（仅保留创作编辑相关字段）。
class NovelSyncService {
  final ApiServiceWrapper _apiServiceWrapper;
  final NovelExportRepository _exportRepository;
  final INovelRepository _novelRepository;

  NovelSyncService({
    required ApiServiceWrapper apiServiceWrapper,
    required NovelExportRepository exportRepository,
    required INovelRepository novelRepository,
  })  : _apiServiceWrapper = apiServiceWrapper,
        _exportRepository = exportRepository,
        _novelRepository = novelRepository;

  /// 上传小说到服务器
  Future<SyncResult> uploadNovel(local.Novel novel, {bool forceOverwrite = false}) async {
    try {
      LoggerService.instance.i(
        '开始上传小说: ${novel.title}',
        category: LogCategory.network,
        tags: ['sync', 'upload', 'start'],
      );

      final exportData = await _exportRepository.exportNovel(novel);
      final syncData = _convertToSyncData(exportData);

      final token = await _apiServiceWrapper.getToken();
      if (token == null || token.isEmpty) {
        return SyncResult.failure('API Token未配置');
      }

      final uploadRequest = NovelSyncUploadRequest((b) => b
        ..novelData.replace(syncData)
        ..forceOverwrite = forceOverwrite);

      final novelSyncApi = _createNovelSyncApi();
      final response = await novelSyncApi.uploadNovelApiNovelSyncUploadPost(
        novelSyncUploadRequest: uploadRequest,
        X_API_TOKEN: token,
      );

      if (response.statusCode == 200 && response.data != null) {
        final result = response.data!;
        LoggerService.instance.i(
          '小说上传成功: ${novel.title}, 版本: ${result.syncVersion}',
          category: LogCategory.network,
          tags: ['sync', 'upload', 'success'],
        );

        return SyncResult.success({
          'title': result.title,
          'sync_version': result.syncVersion,
          'synced_at': result.syncedAt,
        });
      } else {
        return SyncResult.failure('上传失败: HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '上传小说失败: ${novel.title} - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['sync', 'upload', 'error'],
      );
      return SyncResult.failure('上传失败: $e');
    }
  }

  /// 从服务器下载小说
  Future<SyncResult> downloadNovel(local.Novel novel, {bool deleteExisting = true}) async {
    try {
      LoggerService.instance.i(
        '开始下载小说: ${novel.title}',
        category: LogCategory.network,
        tags: ['sync', 'download', 'start'],
      );

      final token = await _apiServiceWrapper.getToken();
      if (token == null || token.isEmpty) {
        return SyncResult.failure('API Token未配置');
      }

      final downloadRequest = NovelSyncDownloadRequest((b) => b
        ..title = novel.title
        ..includeChapters = true
        ..includeCharacters = true
        ..includeOutlines = true);

      final novelSyncApi = _createNovelSyncApi();
      final response = await novelSyncApi.downloadNovelApiNovelSyncDownloadPost(
        novelSyncDownloadRequest: downloadRequest,
        X_API_TOKEN: token,
      );

      if (response.statusCode == 200 && response.data != null) {
        final result = response.data!;

        if (!result.success || result.novelData == null) {
          return SyncResult.failure(result.message);
        }

        final exportData = _convertFromSyncData(result.novelData!);

        final importResult = await _exportRepository.importNovel(
          exportData,
          deleteExisting: deleteExisting,
        );

        if (importResult.success) {
          LoggerService.instance.i(
            '小说下载成功: ${novel.title}, 统计: ${importResult.statistics}',
            category: LogCategory.network,
            tags: ['sync', 'download', 'success'],
          );

          return SyncResult.success({
            'sync_version': result.syncVersion,
            'synced_at': result.syncedAt,
            'statistics': importResult.statistics,
          });
        } else {
          return SyncResult.failure(importResult.errorMessage ?? '导入失败');
        }
      } else {
        return SyncResult.failure('下载失败: HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '下载小说失败: ${novel.title} - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['sync', 'download', 'error'],
      );
      return SyncResult.failure('下载失败: $e');
    }
  }

  /// 获取已同步的小说列表
  Future<List<SyncedNovelInfo>> listSyncedNovels({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final token = await _apiServiceWrapper.getToken();

      if (token == null || token.isEmpty) {
        LoggerService.instance.w(
          'API Token未配置，无法获取同步列表',
          category: LogCategory.network,
          tags: ['sync', 'list', 'error'],
        );
        return [];
      }

      final novelSyncApi = _createNovelSyncApi();
      final response = await novelSyncApi.listSyncedNovelsApiNovelSyncListGet(
        page: page,
        pageSize: pageSize,
        X_API_TOKEN: token,
      );

      if (response.statusCode == 200 && response.data != null) {
        final result = response.data!;

        if (!result.success || result.novels == null) {
          return [];
        }

        return result.novels!.map((novelData) {
          return SyncedNovelInfo(
            title: novelData.title,
            author: novelData.author,
            syncVersion: 1,
            syncedAt: DateTime.now(),
          );
        }).toList();
      }

      return [];
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '获取同步列表失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['sync', 'list', 'error'],
      );
      return [];
    }
  }

  /// 删除服务器上的同步数据
  Future<SyncResult> deleteSyncedNovel(String title) async {
    try {
      final token = await _apiServiceWrapper.getToken();

      if (token == null || token.isEmpty) {
        return SyncResult.failure('API Token未配置');
      }

      final novelSyncApi = _createNovelSyncApi();
      final response = await novelSyncApi.deleteSyncedNovelApiNovelSyncDeleteDelete(
        title: title,
        X_API_TOKEN: token,
      );

      if (response.statusCode == 200) {
        LoggerService.instance.i(
          '删除同步数据成功: $title',
          category: LogCategory.network,
          tags: ['sync', 'delete', 'success'],
        );
        return SyncResult.success();
      } else {
        return SyncResult.failure('删除失败: HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '删除同步数据失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['sync', 'delete', 'error'],
      );
      return SyncResult.failure('删除失败: $e');
    }
  }

  /// 批量上传所有本地小说
  Future<BatchSyncResult> uploadAllNovels(
    List<local.Novel> novels, {
    void Function(int current, int total, String title)? onProgress,
  }) async {
    final total = novels.length;
    final successTitles = <String>[];
    final failureTitles = <String>[];
    final errorMessages = <String, String>{};

    for (var i = 0; i < novels.length; i++) {
      final novel = novels[i];
      onProgress?.call(i + 1, total, novel.title);

      final result = await uploadNovel(novel, forceOverwrite: true);
      if (result.success) {
        successTitles.add(novel.title);
      } else {
        failureTitles.add(novel.title);
        errorMessages[novel.title] = result.errorMessage ?? '未知错误';
      }
    }

    return BatchSyncResult(
      total: total,
      successCount: successTitles.length,
      failureCount: failureTitles.length,
      successTitles: successTitles,
      failureTitles: failureTitles,
      errorMessages: errorMessages,
    );
  }

  /// 批量下载服务器上的小说
  ///
  /// 先获取服务器小说列表，然后逐一下载。
  /// 如果本地不存在该 title 的小说，则自动创建。
  Future<BatchSyncResult> downloadAllNovels({
    void Function(int current, int total, String title)? onProgress,
  }) async {
    final syncedNovels = await listSyncedNovels();
    if (syncedNovels.isEmpty) {
      return const BatchSyncResult(total: 0);
    }

    final total = syncedNovels.length;
    final successTitles = <String>[];
    final failureTitles = <String>[];
    final errorMessages = <String, String>{};

    for (var i = 0; i < syncedNovels.length; i++) {
      final syncedNovel = syncedNovels[i];
      final title = syncedNovel.title;
      onProgress?.call(i + 1, total, title);

      final result = await _downloadAndCreateNovel(title);
      if (result.success) {
        successTitles.add(title);
      } else {
        failureTitles.add(title);
        errorMessages[title] = result.errorMessage ?? '未知错误';
      }
    }

    return BatchSyncResult(
      total: total,
      successCount: successTitles.length,
      failureCount: failureTitles.length,
      successTitles: successTitles,
      failureTitles: failureTitles,
      errorMessages: errorMessages,
    );
  }

  /// 下载小说，如果本地不存在则自动创建
  Future<SyncResult> _downloadAndCreateNovel(String title) async {
    try {
      // 1. 查询本地是否有该 title 的小说
      var novel = await _novelRepository.getNovelByTitle(title);

      // 2. 如果本地不存在，创建新小说
      novel ??= await _novelRepository.createNovel(
        title: title,
        author: '',
      );

      // 3. 下载并导入数据
      return await downloadNovel(novel, deleteExisting: true);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '下载并创建小说失败: $title - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['sync', 'download', 'create', 'error'],
      );
      return SyncResult.failure('下载失败: $e');
    }
  }

  // ========================================================================
  // 私有辅助方法
  // ========================================================================

  NovelSyncApi _createNovelSyncApi() {
    return NovelSyncApi(_apiServiceWrapper.dio, standardSerializers);
  }

  /// 将本地导出数据转换为API同步数据格式（精简版）
  NovelSyncData _convertToSyncData(NovelExportData exportData) {
    // 转换章节数据
    final chaptersBuilder = ListBuilder<ChapterSyncData>();
    for (var i = 0; i < exportData.chapters.length; i++) {
      final chapter = exportData.chapters[i];
      chaptersBuilder.add(ChapterSyncData((b) => b
        ..title = chapter.title
        ..content = chapter.content ?? ''
        ..chapterIndex = chapter.chapterIndex ?? i
        ..isUserInserted = chapter.isUserInserted
        ..url = chapter.url));
    }

    // 转换角色数据
    final charactersBuilder = ListBuilder<CharacterSyncData>();
    for (final character in exportData.characters) {
      charactersBuilder.add(CharacterSyncData((b) => b
        ..name = character.name
        ..gender = character.gender
        ..age = character.age
        ..occupation = character.occupation
        ..personality = character.personality
        ..appearanceFeatures = character.appearanceFeatures
        ..bodyType = character.bodyType
        ..clothingStyle = character.clothingStyle
        ..backgroundStory = character.backgroundStory
        ..facePrompts = character.facePrompts
        ..bodyPrompts = character.bodyPrompts));
    }

    // 转换角色关系数据（使用名称而非ID）
    final relationsBuilder = ListBuilder<CharacterRelationSyncData>();
    for (final relation in exportData.relationships) {
      relationsBuilder.add(CharacterRelationSyncData((b) => b
        ..character1 = relation.sourceCharacterName
        ..character2 = relation.targetCharacterName
        ..relationType = relation.relationshipType
        ..description = relation.description));
    }

    // 转换大纲数据
    final outlinesBuilder = ListBuilder<OutlineSyncData>();
    if (exportData.outline != null) {
      outlinesBuilder.add(OutlineSyncData((b) => b
        ..title = exportData.outline!.title
        ..content = exportData.outline!.content));
    }

    return NovelSyncData((b) => b
      ..title = exportData.title
      ..author = exportData.author
      ..description = exportData.description
      ..coverUrl = exportData.coverUrl
      ..backgroundSetting = exportData.backgroundSetting
      ..chapters.replace(chaptersBuilder.build())
      ..characters.replace(charactersBuilder.build())
      ..characterRelations.replace(relationsBuilder.build())
      ..outlines.replace(outlinesBuilder.build()));
  }

  /// 将API同步数据转换为本地导出数据格式
  NovelExportData _convertFromSyncData(NovelSyncData syncData) {
    final chapters = syncData.chapters?.map((chapter) {
      final chapterUrl = chapter.url ?? '${syncData.title}#chapter_${chapter.chapterIndex}';
      return ChapterExportData(
        title: chapter.title,
        url: chapterUrl,
        content: chapter.content,
        chapterIndex: chapter.chapterIndex,
        isUserInserted: chapter.isUserInserted ?? false,
      );
    }).toList() ?? <ChapterExportData>[];

    final characters = syncData.characters?.map((character) {
      return CharacterExportData(
        name: character.name,
        gender: character.gender,
        age: character.age,
        occupation: character.occupation,
        personality: character.personality,
        appearanceFeatures: character.appearanceFeatures,
        bodyType: character.bodyType,
        clothingStyle: character.clothingStyle,
        backgroundStory: character.backgroundStory,
        facePrompts: character.facePrompts,
        bodyPrompts: character.bodyPrompts,
      );
    }).toList() ?? <CharacterExportData>[];

    // 角色关系直接用名称
    final relationships = syncData.characterRelations?.map((relation) {
      return CharacterRelationExportData(
        sourceCharacterName: relation.character1,
        targetCharacterName: relation.character2,
        relationshipType: relation.relationType,
        description: relation.description,
      );
    }).toList() ?? <CharacterRelationExportData>[];

    OutlineExportData? outline;
    if (syncData.outlines != null && syncData.outlines!.isNotEmpty) {
      final outlineData = syncData.outlines!.first;
      outline = OutlineExportData(
        title: outlineData.title,
        content: outlineData.content,
      );
    }

    return NovelExportData(
      novelUrl: syncData.title,
      title: syncData.title,
      author: syncData.author ?? '',
      coverUrl: syncData.coverUrl,
      description: syncData.description,
      backgroundSetting: syncData.backgroundSetting,
      chapters: chapters,
      characters: characters,
      relationships: relationships,
      outline: outline,
    );
  }
}