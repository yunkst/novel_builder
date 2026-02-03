import 'package:flutter/foundation.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../services/api_service_wrapper.dart';
import '../core/interfaces/repositories/i_chapter_repository.dart';
import '../core/providers/reader_state_providers.dart';
import 'package:riverpod/riverpod.dart';

/// ReaderContentController (新版本)
///
/// 职责：
/// - 章节内容加载（从缓存或API）
/// - 缓存管理
/// - 阅读进度更新
/// - 通过Riverpod Provider管理状态，不使用setState回调
///
/// 使用方式：
/// ```dart
/// final controller = ReaderContentController(
///   ref: ref,
///   apiService: _apiService,
///   chapterRepository: _chapterRepository,
/// );
///
/// await controller.initialize();
/// await controller.loadChapter(chapter, novel);
/// ```
///
/// 状态变化通过Provider自动通知UI更新
class ReaderContentController {
  // ========== 依赖服务 ==========
  final ApiServiceWrapper _apiService;
  final IChapterRepository _chapterRepository;
  final Ref _ref;

  // ========== 构造函数 ==========

  ReaderContentController({
    required Ref ref,
    required ApiServiceWrapper apiService,
    required IChapterRepository chapterRepository,
  })  : _ref = ref,
        _apiService = apiService,
        _chapterRepository = chapterRepository;

  // ========== 公开方法 ==========

  /// 初始化Controller
  ///
  /// 初始化API服务，准备加载章节
  Future<void> initialize() async {
    try {
      await _apiService.init();
      debugPrint('✅ ReaderContentController: API初始化成功');
    } catch (e) {
      _ref.read(chapterContentStateNotifierProvider.notifier).setError('初始化API失败: $e');
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
    final notifier = _ref.read(chapterContentStateNotifierProvider.notifier);

    // 设置当前上下文
    notifier.setCurrentContext(chapter, novel);

    // 设置加载状态
    notifier.setLoading(true);
    if (resetScrollPosition) {
      notifier.clearContent();
    }

    try {
      debugPrint('📖 ReaderContentController: 开始加载章节 - ${chapter.title}');

      String content;

      // 强制刷新时先删除缓存
      if (forceRefresh) {
        await _chapterRepository.deleteChapterCache(chapter.url);
        debugPrint('🗑️ ReaderContentController: 已删除缓存 - ${chapter.url}');
      }

      // 尝试从缓存获取
      final cachedContent = await _chapterRepository.getCachedChapter(chapter.url);
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
          await _chapterRepository.cacheChapter(
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
      notifier.setContent(content);
      notifier.setLoading(false);

      // 更新阅读进度
      await updateReadingProgress(novel.url, chapter);

      // 注意：预加载功能由 reader_screen 直接调用 PreloadService 处理
      // 此 Controller 不负责预加载逻辑

      debugPrint('✅ ReaderContentController: 章节加载完成 - ${chapter.title}');
    } catch (e) {
      notifier.setLoading(false);
      notifier.setError('加载章节失败: $e');
      debugPrint('❌ ReaderContentController: 加载失败 - $e');
      rethrow;
    }
  }

  /// 更新阅读进度
  ///
  /// [novelUrl] 小说URL
  /// [chapter] 当前章节
  Future<void> updateReadingProgress(String novelUrl, Chapter chapter) async {
    try {
      final chapterIndex = chapter.chapterIndex ?? 0;
      await _chapterRepository.updateLastReadChapter(novelUrl, chapterIndex);
      debugPrint('📖 ReaderContentController: 已更新阅读进度 - 章节$chapterIndex');
    } catch (e) {
      debugPrint('❌ ReaderContentController: 更新阅读进度失败 - $e');
    }
  }

  /// 更新内容（用于改写等需要直接更新内容的场景）
  void setContent(String newContent) {
    _ref.read(chapterContentStateNotifierProvider.notifier).updateContent(newContent);
    debugPrint('📝 ReaderContentController: 内容已更新 - ${newContent.length}字符');
  }

  // ========== Getters ==========

  /// 章节内容（从Provider获取）
  String get content => _ref.read(chapterContentStateNotifierProvider).content;

  /// 是否正在加载（从Provider获取）
  bool get isLoading => _ref.read(chapterContentStateNotifierProvider).isLoading;

  /// 错误信息（从Provider获取）
  String get errorMessage => _ref.read(chapterContentStateNotifierProvider).errorMessage;

  /// 当前章节（从Provider获取）
  Chapter? get currentChapter => _ref.read(chapterContentStateNotifierProvider).currentChapter;

  /// 当前小说（从Provider获取）
  Novel? get currentNovel => _ref.read(chapterContentStateNotifierProvider).currentNovel;
}
