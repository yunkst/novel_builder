import 'package:flutter/foundation.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../services/api_service_wrapper.dart';
import '../services/database_service.dart';
// import '../services/preload_service.dart'; // 暂未使用

/// ReaderContentController
///
/// 职责：
/// - 章节内容加载（从缓存或API）
/// - 缓存管理
/// - 预加载调度
/// - 阅读进度更新
///
/// 使用方式：
/// ```dart
/// final controller = ReaderContentController(
///   onStateChanged: () => setState(() {}),
///   apiService: _apiService,
///   databaseService: _databaseService,
///   preloadService: _preloadService,
/// );
///
/// await controller.initialize();
/// await controller.loadChapter(chapter, novel);
/// ```
class ReaderContentController {
  // ========== 依赖服务 ==========
  final ApiServiceWrapper _apiService;
  final DatabaseService _databaseService;
  // final PreloadService _preloadService; // 暂未使用，保留供后续扩展

  // ========== UI状态回调 ==========
  final VoidCallback _onStateChanged;

  // ========== 内部状态 ==========
  bool _isLoading = false;
  String _content = '';
  String _errorMessage = '';
  Chapter? _currentChapter;
  Novel? _currentNovel;

  // ========== 构造函数 ==========

  ReaderContentController({
    required VoidCallback onStateChanged,
    required ApiServiceWrapper apiService,
    required DatabaseService databaseService,
    // required PreloadService preloadService, // 暂未使用
  })  : _onStateChanged = onStateChanged,
        _apiService = apiService,
        _databaseService = databaseService;

  // ========== 公开方法 ==========

  /// 初始化Controller
  ///
  /// 初始化API服务，准备加载章节
  Future<void> initialize() async {
    try {
      await _apiService.init();
      debugPrint('✅ ReaderContentController: API初始化成功');
    } catch (e) {
      _errorMessage = '初始化API失败: $e';
      _isLoading = false;
      _onStateChanged();
      debugPrint('❌ ReaderContentController: API初始化失败 - $e');
      rethrow;
    }
  }

  /// 加载章节内容
  ///
  /// [chapter] 要加载的章节
  /// [novel] 所属小说
  /// [forceRefresh] 是否强制刷新（忽略缓存）
  /// [resetScrollPosition] 是否重置滚动位置（用于回调，本Controller不处理）
  Future<void> loadChapter(
    Chapter chapter,
    Novel novel, {
    bool forceRefresh = false,
    bool resetScrollPosition = true,
  }) async {
    _currentChapter = chapter;
    _currentNovel = novel;

    // 设置加载状态
    _isLoading = true;
    _errorMessage = '';
    if (resetScrollPosition) {
      _content = '';
    }
    _onStateChanged();

    try {
      debugPrint('📖 ReaderContentController: 开始加载章节 - ${chapter.title}');

      String content;

      // 强制刷新时先删除缓存
      if (forceRefresh) {
        await _databaseService.deleteChapterCache(chapter.url);
        debugPrint('🗑️ ReaderContentController: 已删除缓存 - ${chapter.url}');
      }

      // 尝试从缓存获取
      final cachedContent = await _databaseService.getCachedChapter(chapter.url);
      if (cachedContent != null && cachedContent.isNotEmpty) {
        content = cachedContent;
        debugPrint('💾 ReaderContentController: 从缓存加载 - ${cachedContent.length}字符');
      } else {
        // 缓存未命中，从API获取
        debugPrint('🌐 ReaderContentController: 缓存未命中，从API获取');
        content = await _apiService.getChapterContent(
          chapter.url,
          forceRefresh: forceRefresh,
        );

        // 验证内容并缓存
        if (content.isNotEmpty && content.length > 50) {
          await _databaseService.cacheChapter(
            novel.url,
            chapter,
            content,
          );
          debugPrint('✅ ReaderContentController: 已缓存章节 - ${content.length}字符');
        } else {
          throw Exception('获取到的章节内容为空或过短');
        }
      }

      // 更新状态
      _content = content;
      _isLoading = false;
      _onStateChanged();

      // 更新阅读进度
      await updateReadingProgress(novel.url, chapter);

      // 启动预加载
      await preloadChapters(novel, chapter);

      debugPrint('✅ ReaderContentController: 章节加载完成 - ${chapter.title}');
    } catch (e) {
      _isLoading = false;
      _errorMessage = '加载章节失败: ${_getErrorMessage(e)}';
      _onStateChanged();
      debugPrint('❌ ReaderContentController: 加载失败 - $e');
      rethrow;
    }
  }

  /// 预加载后续章节
  ///
  /// 使用PreloadService在后台预加载章节
  Future<void> preloadChapters(
    Novel novel,
    Chapter currentChapter,
  ) async {
    // 注意：这里需要章节列表，但Controller不应该存储整个章节列表
    // 所以这个方法需要从外部传入，或者通过回调获取
    // 暂时保留接口，实际实现在reader_screen中调用PreloadService
    debugPrint('⏳ ReaderContentController: preloadChapters调用（待实现）');
  }

  /// 更新阅读进度
  ///
  /// [novelUrl] 小说URL
  /// [chapter] 当前章节
  Future<void> updateReadingProgress(String novelUrl, Chapter chapter) async {
    try {
      final chapterIndex = chapter.chapterIndex ?? 0;
      await _databaseService.updateLastReadChapter(novelUrl, chapterIndex);
      debugPrint('📖 ReaderContentController: 已更新阅读进度 - 章节$chapterIndex');
    } catch (e) {
      debugPrint('❌ ReaderContentController: 更新阅读进度失败 - $e');
    }
  }

  // ========== Getters ==========

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 章节内容
  String get content => _content;

  /// 设置内容（用于改写等需要直接更新内容的场景）
  set content(String newContent) {
    _content = newContent;
    debugPrint('📝 ReaderContentController: 内容已更新 - ${newContent.length}字符');
  }

  /// 错误信息
  String get errorMessage => _errorMessage;

  /// 当前章节
  Chapter? get currentChapter => _currentChapter;

  /// 当前小说
  Novel? get currentNovel => _currentNovel;

  // ========== 私有辅助方法 ==========

  /// 获取错误信息的友好提示
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString();

    if (errorStr.contains('SocketException')) {
      return '网络连接失败，请检查网络设置';
    } else if (errorStr.contains('TimeoutException')) {
      return '请求超时，请稍后重试';
    } else if (errorStr.contains('请求过于频繁')) {
      return '请求过于频繁，请稍后再试';
    } else if (errorStr.contains('404')) {
      return '章节不存在';
    } else if (errorStr.contains('500') || errorStr.contains('502') || errorStr.contains('503')) {
      return '服务器暂时不可用，请稍后重试';
    } else {
      return '加载失败: $errorStr';
    }
  }
}
