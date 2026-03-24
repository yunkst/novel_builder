import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:novel_api/novel_api.dart';

import '../models/novel.dart' as local;
import '../models/novel_export_data.dart';
import '../repositories/novel_export_repository.dart';
import '../services/logger_service.dart';
import '../services/api_service_wrapper.dart';
import '../services/preferences_service.dart';

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

/// 已同步小说信息
class SyncedNovelInfo {
  final String sourceUrl;
  final String title;
  final String? author;
  final int syncVersion;
  final DateTime syncedAt;

  const SyncedNovelInfo({
    required this.sourceUrl,
    required this.title,
    this.author,
    required this.syncVersion,
    required this.syncedAt,
  });
}

/// 小说同步服务
///
/// 负责小说数据的上传、下载和列表查询操作。
/// 整合了NovelExportRepository和NovelSyncApi，实现完整的数据同步流程。
///
/// 依赖注入：
/// - ApiServiceWrapper: 提供API客户端配置和Token
/// - NovelExportRepository: 提供数据导出/导入功能
/// - PreferencesService: 提供设备标识存储
class NovelSyncService {
  final ApiServiceWrapper _apiServiceWrapper;
  final NovelExportRepository _exportRepository;

  /// 设备ID缓存
  String? _cachedDeviceId;

  /// 构造函数 - 通过依赖注入接收服务实例
  NovelSyncService({
    required ApiServiceWrapper apiServiceWrapper,
    required NovelExportRepository exportRepository,
  })  : _apiServiceWrapper = apiServiceWrapper,
        _exportRepository = exportRepository;

  /// 获取设备唯一标识
  ///
  /// 使用平台信息生成唯一标识符。
  /// 该标识用于追踪同步来源。
  /// 注意：这是一个简化的实现，不依赖device_info_plus包。
  Future<String> _getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    // 尝试从SharedPreferences获取已保存的设备ID
    const deviceIdKey = 'sync_device_id';
    final savedDeviceId = await PreferencesService.instance.getString(deviceIdKey);

    if (savedDeviceId.isNotEmpty) {
      _cachedDeviceId = savedDeviceId;
      return _cachedDeviceId!;
    }

    // 生成新的设备ID
    String deviceId;

    try {
      // 使用平台信息和时间戳生成唯一ID
      final platform = Platform.operatingSystem;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = timestamp % 10000;

      deviceId = '${platform}_${timestamp}_$random';
    } catch (e) {
      LoggerService.instance.w(
        '生成设备ID失败，使用默认ID: $e',
        category: LogCategory.network,
        tags: ['sync', 'device_id'],
      );
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
    }

    // 保存设备ID以便下次使用
    await PreferencesService.instance.setString(deviceIdKey, deviceId);
    _cachedDeviceId = deviceId;

    LoggerService.instance.i(
      '生成设备ID: $deviceId',
      category: LogCategory.network,
      tags: ['sync', 'device_id'],
    );

    return deviceId;
  }

  /// 上传小说到服务器
  ///
  /// 将小说的所有关联数据（章节、角色、关系、大纲）上传到服务器。
  ///
  /// [novel] 要上传的小说对象
  /// [forceOverwrite] 是否强制覆盖服务器数据
  ///
  /// 返回上传结果，包含同步版本号和时间戳
  Future<SyncResult> uploadNovel(local.Novel novel, {bool forceOverwrite = false}) async {
    try {
      LoggerService.instance.i(
        '开始上传小说: ${novel.title}',
        category: LogCategory.network,
        tags: ['sync', 'upload', 'start'],
      );

      // 1. 导出小说数据
      final exportData = await _exportRepository.exportNovel(novel);

      // 2. 转换为API数据格式
      final syncData = _convertToSyncData(exportData);

      // 3. 获取设备ID和Token
      final deviceId = await _getDeviceId();
      final token = await _apiServiceWrapper.getToken();

      if (token == null || token.isEmpty) {
        return SyncResult.failure('API Token未配置');
      }

      // 4. 创建上传请求
      final uploadRequest = NovelSyncUploadRequest((b) => b
        ..deviceId = deviceId
        ..novelData.replace(syncData)
        ..forceOverwrite = forceOverwrite);

      // 5. 调用API上传
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
          'novel_id': result.novelId,
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
  ///
  /// 从服务器下载小说数据并导入到本地数据库。
  ///
  /// [novel] 要下载的小说对象（需要包含url）
  /// [deleteExisting] 是否删除本地现有数据后再导入
  ///
  /// 返回下载结果，包含导入统计信息
  Future<SyncResult> downloadNovel(local.Novel novel, {bool deleteExisting = true}) async {
    try {
      LoggerService.instance.i(
        '开始下载小说: ${novel.title}',
        category: LogCategory.network,
        tags: ['sync', 'download', 'start'],
      );

      // 1. 获取设备ID和Token
      final deviceId = await _getDeviceId();
      final token = await _apiServiceWrapper.getToken();

      if (token == null || token.isEmpty) {
        return SyncResult.failure('API Token未配置');
      }

      // 2. 创建下载请求 - 使用sourceUrl作为唯一标识
      final downloadRequest = NovelSyncDownloadRequest((b) => b
        ..deviceId = deviceId
        ..sourceUrl = novel.url // 使用小说URL作为唯一标识
        ..includeChapters = true
        ..includeCharacters = true
        ..includeOutlines = true);

      // 3. 调用API下载
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

        // 4. 转换为本地数据格式
        final exportData = _convertFromSyncData(result.novelData!);

        // 5. 导入数据
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
  ///
  /// 返回服务器上已同步小说的基本信息列表。
  ///
  /// [page] 页码（从1开始）
  /// [pageSize] 每页数量
  ///
  /// 返回已同步小说信息列表
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
            sourceUrl: novelData.sourceUrl ?? '',
            title: novelData.title,
            author: novelData.author,
            syncVersion: novelData.novelId, // 使用novelId作为同步版本参考
            syncedAt: DateTime.tryParse(novelData.updatedAt ?? '') ?? DateTime.now(),
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
  ///
  /// [novelUrl] 小说URL（作为唯一标识）
  ///
  /// 返回删除结果
  Future<SyncResult> deleteSyncedNovel(String novelUrl) async {
    try {
      final token = await _apiServiceWrapper.getToken();

      if (token == null || token.isEmpty) {
        return SyncResult.failure('API Token未配置');
      }

      final novelSyncApi = _createNovelSyncApi();
      final response = await novelSyncApi.deleteSyncedNovelApiNovelSyncDeleteDelete(
        novelUrl: novelUrl,
        X_API_TOKEN: token,
      );

      if (response.statusCode == 200) {
        LoggerService.instance.i(
          '删除同步数据成功: $novelUrl',
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

  // ========================================================================
  // 私有辅助方法
  // ========================================================================

  /// 创建NovelSyncApi实例
  NovelSyncApi _createNovelSyncApi() {
    return NovelSyncApi(_apiServiceWrapper.dio, standardSerializers);
  }

  /// 将本地导出数据转换为API同步数据格式
  NovelSyncData _convertToSyncData(NovelExportData exportData) {
    // 转换章节数据
    final chaptersBuilder = ListBuilder<ChapterSyncData>();
    for (var i = 0; i < exportData.chapters.length; i++) {
      final chapter = exportData.chapters[i];
      chaptersBuilder.add(ChapterSyncData((b) => b
        ..chapterId = i + 1 // 使用索引+1作为临时ID
        ..title = chapter.title
        ..content = chapter.content ?? ''
        ..chapterIndex = chapter.chapterIndex ?? i
        ..isUserInserted = chapter.isUserInserted
        ..url = chapter.url
        ..createdAt = DateTime.now().toIso8601String()
        ..updatedAt = DateTime.now().toIso8601String()));
    }

    // 转换角色数据
    final charactersBuilder = ListBuilder<CharacterSyncData>();
    final characterIdMap = <String, int>{}; // 角色名称到ID的映射
    for (var i = 0; i < exportData.characters.length; i++) {
      final character = exportData.characters[i];
      final characterId = i + 1;
      characterIdMap[character.name] = characterId;

      charactersBuilder.add(CharacterSyncData((b) => b
        ..characterId = characterId
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
        ..bodyPrompts = character.bodyPrompts
        ..createdAt = DateTime.now().toIso8601String()
        ..updatedAt = DateTime.now().toIso8601String()));
    }

    // 转换角色关系数据
    final relationsBuilder = ListBuilder<CharacterRelationSyncData>();
    for (var i = 0; i < exportData.relationships.length; i++) {
      final relation = exportData.relationships[i];
      final sourceId = characterIdMap[relation.sourceCharacterName];
      final targetId = characterIdMap[relation.targetCharacterName];

      if (sourceId != null && targetId != null) {
        relationsBuilder.add(CharacterRelationSyncData((b) => b
          ..relationId = i + 1
          ..character1Id = sourceId
          ..character2Id = targetId
          ..relationType = relation.relationshipType
          ..description = relation.description
          ..createdAt = DateTime.now().toIso8601String()
          ..updatedAt = DateTime.now().toIso8601String()));
      }
    }

    // 转换大纲数据
    final outlinesBuilder = ListBuilder<OutlineSyncData>();
    if (exportData.outline != null) {
      outlinesBuilder.add(OutlineSyncData((b) => b
        ..outlineId = 1
        ..title = exportData.outline!.title
        ..content = exportData.outline!.content
        ..outlineType = 'main'
        ..sortOrder = 0
        ..createdAt = DateTime.now().toIso8601String()
        ..updatedAt = DateTime.now().toIso8601String()));
    }

    // 构建NovelSyncData
    return NovelSyncData((b) => b
      ..novelId = exportData.novelUrl.hashCode // 使用URL的hashCode作为临时ID
      ..title = exportData.title
      ..author = exportData.author
      ..description = exportData.description
      ..coverUrl = exportData.coverUrl
      ..sourceUrl = exportData.novelUrl
      ..totalChapters = exportData.chapters.length
      ..totalWords = 0 // 暂不支持
      ..isFavorite = false
      ..chapters.replace(chaptersBuilder.build())
      ..characters.replace(charactersBuilder.build())
      ..characterRelations.replace(relationsBuilder.build())
      ..outlines.replace(outlinesBuilder.build())
      ..createdAt = exportData.exportedAt.toIso8601String()
      ..updatedAt = DateTime.now().toIso8601String());
  }

  /// 将API同步数据转换为本地导出数据格式
  NovelExportData _convertFromSyncData(NovelSyncData syncData) {
    // 转换章节数据
    final chapters = syncData.chapters?.map((chapter) {
      // 使用原始URL，如果没有则降级为生成URL
      final chapterUrl = chapter.url ??
          '${syncData.sourceUrl}#chapter_${chapter.chapterIndex}';
      return ChapterExportData(
        title: chapter.title,
        url: chapterUrl,
        content: chapter.content,
        chapterIndex: chapter.chapterIndex,
        isUserInserted: chapter.isUserInserted ?? false,
      );
    }).toList() ?? <ChapterExportData>[];

    // 创建角色名称到ID的映射
    final characterIdToName = <int, String>{};
    final characters = syncData.characters?.map((character) {
      // 注意：这里ID是临时的，实际导入时会重新分配
      if (syncData.characters != null) {
        for (var i = 0; i < syncData.characters!.length; i++) {
          final c = syncData.characters![i];
          characterIdToName[c.characterId] = c.name;
        }
      }

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

    // 转换角色关系数据
    final relationships = syncData.characterRelations?.map((relation) {
      final sourceName = characterIdToName[relation.character1Id] ?? '';
      final targetName = characterIdToName[relation.character2Id] ?? '';

      return CharacterRelationExportData(
        sourceCharacterName: sourceName,
        targetCharacterName: targetName,
        relationshipType: relation.relationType,
        description: relation.description,
      );
    }).toList() ?? <CharacterRelationExportData>[];

    // 转换大纲数据
    OutlineExportData? outline;
    if (syncData.outlines != null && syncData.outlines!.isNotEmpty) {
      final outlineData = syncData.outlines!.first;
      outline = OutlineExportData(
        title: outlineData.title,
        content: outlineData.content,
      );
    }

    return NovelExportData(
      novelUrl: syncData.sourceUrl ?? '',
      title: syncData.title,
      author: syncData.author ?? '',
      coverUrl: syncData.coverUrl,
      description: syncData.description,
      chapters: chapters,
      characters: characters,
      relationships: relationships,
      outline: outline,
    );
  }
}