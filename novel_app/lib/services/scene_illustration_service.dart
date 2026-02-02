import '../models/scene_illustration.dart';
import '../services/database_service.dart';
import '../core/di/api_service_provider.dart';
import '../services/api_service_wrapper.dart';
import '../utils/media_markup_parser.dart';
import 'logger_service.dart';
import 'package:novel_api/novel_api.dart';

class SceneIllustrationService {
  final DatabaseService _databaseService;
  final ApiServiceWrapper _apiService;

  SceneIllustrationService({
    DatabaseService? databaseService,
    ApiServiceWrapper? apiService,
  })  : _databaseService = databaseService ?? DatabaseService(),
        _apiService = apiService ?? ApiServiceProvider.instance;

  /// 创建场景插图任务（新版本：基于段落索引插入标记）
  Future<int> createSceneIllustrationWithMarkup({
    required String novelUrl,
    required String chapterId,
    required String paragraphText, // 要插入插图的段落文本
    required List<RoleInfo> roles,
    required int imageCount,
    String? modelName,
    required String insertionPosition, // 'before' | 'after' | 'replace'
    required int paragraphIndex, // 段落索引，用于直接定位
  }) async {
    try {
      // 1. 预生成 taskId
      final taskId = SceneIllustration.generateTaskId();

      // 2. 先在章节内容中插入插图标记
      await _insertIllustrationMarkup(
        novelUrl: novelUrl,
        chapterId: chapterId,
        taskId: taskId,
        paragraphText: paragraphText,
        insertionPosition: insertionPosition,
        paragraphIndex: paragraphIndex, // 传递段落索引
      );

      // 3. 创建本地记录
      final illustration = SceneIllustration(
        id: 0, // 数据库自动生成
        novelUrl: novelUrl,
        chapterId: chapterId,
        taskId: taskId, // 使用预生成的 taskId
        content: paragraphText,
        roles: '', // roles数据主要用于API传输，数据库中不需要存储
        imageCount: imageCount,
        status: 'pending',
        images: [],
        prompts: null,
        createdAt: DateTime.now(),
        completedAt: null,
      );

      final id = await _databaseService.insertSceneIllustration(illustration);

      // 4. 调用后端API生成图片（直接传递RoleInfo列表）
      final response = await _apiService.createSceneIllustration(
        chaptersContent: paragraphText,
        taskId: taskId, // 使用预生成的 taskId
        roles: roles, // 使用新的RoleInfo列表格式
        num: imageCount,
        modelName: modelName,
      );

      if (response['status'] == 'pending' ||
          response['status'] == 'processing') {
        LoggerService.instance.i(
          '场景插图任务创建成功: $taskId',
          category: LogCategory.ai,
          tags: ['illustration', 'create', 'success'],
        );
      } else {
        LoggerService.instance.w(
          '场景插图任务创建失败: $response',
          category: LogCategory.ai,
          tags: ['illustration', 'create', 'failed'],
        );
      }

      return id;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '创建场景插图失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['illustration', 'create', 'error'],
      );
      throw Exception('创建场景插图失败: $e');
    }
  }

  /// 创建场景插图任务（保持向后兼容）
  Future<String> createSceneIllustration({
    required String novelUrl,
    required String chapterId,
    required int paragraphIndex,
    required String content,
    required Map<String, String> roles,
    required int imageCount,
    String? modelName,
  }) async {
    // 调用新版本方法，默认在段落后插入插图
    final taskId = SceneIllustration.generateTaskId();

    try {
      // 先在章节内容中插入插图标记
      await _insertIllustrationMarkup(
        novelUrl: novelUrl,
        chapterId: chapterId,
        taskId: taskId,
        paragraphText: content,
        insertionPosition: 'after',
        paragraphIndex: paragraphIndex,
      );

      // 创建本地记录
      final illustration = SceneIllustration(
        id: 0, // 数据库自动生成
        novelUrl: novelUrl,
        chapterId: chapterId,
        taskId: taskId,
        content: content,
        roles: '', // roles数据主要用于API传输，数据库中不需要存储
        imageCount: imageCount,
        status: 'pending',
        images: [],
        prompts: null,
        createdAt: DateTime.now(),
      );

      // 插入数据库
      final id = await _databaseService.insertSceneIllustration(illustration);

      if (id > 0) {
        return taskId; // 返回 taskId
      } else {
        throw Exception('插入场景插图记录失败');
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '创建场景插图失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['illustration', 'create', 'error'],
      );
      throw Exception('创建场景插图失败: $e');
    }
  }

  /// 在章节内容中插入插图标记
  Future<void> _insertIllustrationMarkup({
    required String novelUrl,
    required String chapterId,
    required String taskId,
    required String paragraphText,
    required String insertionPosition,
    required int paragraphIndex, // 段落索引，用于直接定位
  }) async {
    try {
      // 获取当前章节内容
      final currentContent = await _databaseService.getCachedChapter(chapterId);
      if (currentContent == null || currentContent.isEmpty) {
        LoggerService.instance.e(
          '章节内容为空，无法插入插图标记',
          category: LogCategory.ai,
          tags: ['illustration', 'markup', 'error'],
        );
        throw Exception('章节内容为空，无法插入插图标记');
      }

      // 分割为段落
      final paragraphs =
          currentContent.split('\n').where((p) => p.trim().isNotEmpty).toList();

      // 验证段落索引的有效性
      if (paragraphIndex < 0) {
        LoggerService.instance.e(
          '段落索引不能为负数: $paragraphIndex',
          category: LogCategory.ai,
          tags: ['illustration', 'markup', 'error'],
        );
        throw ArgumentError('段落索引不能为负数: $paragraphIndex');
      }

      if (paragraphIndex >= paragraphs.length) {
        LoggerService.instance.e(
          '段落索引超出范围: $paragraphIndex，段落数量: ${paragraphs.length}',
          category: LogCategory.ai,
          tags: ['illustration', 'markup', 'error'],
        );
        throw ArgumentError(
            '段落索引超出范围: $paragraphIndex，段落数量: ${paragraphs.length}');
      }

      // 直接使用传入的段落索引，无需文本匹配
      final targetIndex = paragraphIndex;
      LoggerService.instance.d(
        '使用段落索引定位: $targetIndex，段落数量: ${paragraphs.length}',
        category: LogCategory.ai,
        tags: ['illustration', 'markup', 'index'],
      );

      // 创建插图标记
      final illustrationMarkup =
          MediaMarkupParser.createIllustrationMarkup(taskId);

      // 根据插入位置修改内容
      switch (insertionPosition) {
        case 'before':
          paragraphs.insert(targetIndex, illustrationMarkup);
          break;
        case 'after':
          paragraphs.insert(targetIndex + 1, illustrationMarkup);
          break;
        case 'replace':
          paragraphs[targetIndex] = illustrationMarkup;
          break;
        default:
          paragraphs.insert(targetIndex + 1, illustrationMarkup);
      }

      // 重新组合内容并保存
      final newContent = paragraphs.join('\n');
      await _databaseService.updateChapterContent(chapterId, newContent);

      LoggerService.instance.i(
        '插图标记已插入章节内容: $illustrationMarkup',
        category: LogCategory.ai,
        tags: ['illustration', 'markup', 'success'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '插入插图标记失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['illustration', 'markup', 'error'],
      );
      // 重新抛出异常，停止插图创建流程
      rethrow;
    }
  }

  /// 根据章节获取所有场景插图
  Future<List<SceneIllustration>> getIllustrationsByChapter(
      String novelUrl, String chapterId) async {
    try {
      final illustrations = await _databaseService
          .getSceneIllustrationsByChapter(novelUrl, chapterId);
      return illustrations;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '获取场景插图失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['illustration', 'get', 'error'],
      );
      return [];
    }
  }

  // 删除了 getIllustrationByParagraph 方法，新系统不使用段落索引

  /// 删除场景插图
  Future<bool> deleteIllustration(int illustrationId) async {
    try {
      final illustration = await _getIllustrationById(illustrationId);
      if (illustration == null) {
        return false;
      }

      // 1. 从章节内容中移除插图标记
      await _removeIllustrationMarkup(
        chapterId: illustration.chapterId,
        taskId: illustration.taskId,
      );

      // 2. 删除本地记录（移除后端API调用）
      await _databaseService.deleteSceneIllustration(illustrationId);
      return true;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '删除场景插图失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['illustration', 'delete', 'error'],
      );
      return false;
    }
  }

  /// 从章节内容中移除插图标记
  Future<void> _removeIllustrationMarkup({
    required String chapterId,
    required String taskId,
  }) async {
    try {
      // 获取当前章节内容
      final currentContent = await _databaseService.getCachedChapter(chapterId);
      if (currentContent == null || currentContent.isEmpty) {
        LoggerService.instance.w(
          '章节内容为空，无法移除插图标记',
          category: LogCategory.ai,
          tags: ['illustration', 'markup', 'warning'],
        );
        return;
      }

      // 创建目标插图标记
      final targetMarkup = MediaMarkupParser.createIllustrationMarkup(taskId);

      // 移除所有匹配的标记
      final newContent = currentContent.replaceAll(targetMarkup, '');

      // 保存修改后的内容
      await _databaseService.updateChapterContent(chapterId, newContent);

      LoggerService.instance.i(
        '插图标记已从章节内容中移除: $targetMarkup',
        category: LogCategory.ai,
        tags: ['illustration', 'markup', 'remove'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '移除插图标记失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['illustration', 'markup', 'error'],
      );
      // 不抛出异常，避免影响插图删除流程
    }
  }

  /// 重新生成更多图片
  Future<bool> regenerateMoreImages({
    required int illustrationId,
    required int count,
    String? modelName,
  }) async {
    try {
      final illustration = await _getIllustrationById(illustrationId);
      if (illustration == null) {
        return false;
      }

      // 调用后端API重新生成
      final response = await _apiService.regenerateSceneIllustrationImages(
        taskId: illustration.taskId,
        count: count,
        modelName: modelName,
      );

      if (response['message'] != null) {
        LoggerService.instance.i(
          '重新生成图片任务提交成功: ${illustration.taskId}',
          category: LogCategory.ai,
          tags: ['illustration', 'regenerate', 'success'],
        );
        // 更新本地状态为处理中
        await _databaseService.updateSceneIllustrationStatus(
          illustrationId,
          'processing',
        );
        return true;
      } else {
        LoggerService.instance.w(
          '重新生成图片失败: $response',
          category: LogCategory.ai,
          tags: ['illustration', 'regenerate', 'failed'],
        );
        return false;
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '重新生成图片失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['illustration', 'regenerate', 'error'],
      );
      return false;
    }
  }

  /// 编辑提示词
  Future<bool> updatePrompts(int illustrationId, String newPrompts) async {
    try {
      await _databaseService.updateSceneIllustrationStatus(
        illustrationId,
        'completed',
        prompts: newPrompts,
      );
      return true;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '更新提示词失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['illustration', 'update', 'error'],
      );
      return false;
    }
  }

  /// 根据ID获取场景插图
  Future<SceneIllustration?> _getIllustrationById(int id) async {
    try {
      final db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'scene_illustrations',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return SceneIllustration.fromMap(maps.first);
      }
      return null;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '获取场景插图失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['illustration', 'get', 'error'],
      );
      return null;
    }
  }

  /// 刷新章节所有插图状态
  Future<void> refreshChapterIllustrations(
      String novelUrl, String chapterId) async {
    try {
      // 仅刷新本地数据，不同步后端状态
      await _databaseService.getSceneIllustrationsByChapter(
          novelUrl, chapterId);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '刷新章节插图状态失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['illustration', 'refresh', 'error'],
      );
    }
  }

  /// 获取所有待处理的插图
  Future<List<SceneIllustration>> getPendingIllustrations() async {
    try {
      final illustrations =
          await _databaseService.getPendingSceneIllustrations();
      return illustrations;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '获取待处理插图失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['illustration', 'pending', 'error'],
      );
      return [];
    }
  }
}
