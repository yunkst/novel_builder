import '../../models/outline.dart';
import '../../services/outline_service.dart';
import '../../services/logger_service.dart';

/// 大纲集成处理器
/// 负责大纲相关的业务逻辑
class OutlineIntegrationHandler {
  final OutlineService _outlineService;
  final _log = LoggerService.instance;

  OutlineIntegrationHandler({
    required OutlineService outlineService,
  }) : _outlineService = outlineService;

  /// 检查大纲是否存在
  Future<Outline?> getOutline(String novelUrl) async {
    _log.d(
      '查询大纲: $novelUrl',
      category: LogCategory.ui,
      tags: ['chapter-list', 'outline'],
    );
    try {
      final outline = await _outlineService.getOutline(novelUrl);
      if (outline != null) {
        _log.i(
          '大纲查询命中: "${outline.title}"',
          category: LogCategory.ui,
          tags: ['chapter-list', 'outline'],
        );
      }
      return outline;
    } catch (e, st) {
      _log.e(
        '查询大纲失败: $novelUrl - $e',
        stackTrace: st.toString(),
        category: LogCategory.database,
        tags: ['chapter', 'outline'],
      );
      rethrow;
    }
  }

  /// 生成章节细纲
  /// [novelUrl] 小说URL
  /// [mainOutline] 主大纲内容
  /// [previousChapters] 前文章节内容列表
  /// 返回生成的章节细纲
  Future<ChapterOutlineDraft> generateChapterOutline({
    required String novelUrl,
    required String mainOutline,
    required List<String> previousChapters,
  }) async {
    _log.d(
      '开始生成章节细纲, 前文章节数: ${previousChapters.length}',
      category: LogCategory.ai,
      tags: ['chapter-list', 'outline', 'generate'],
    );
    try {
      final draft = await _outlineService.generateChapterOutline(
        novelUrl: novelUrl,
        mainOutline: mainOutline,
        previousChapters: previousChapters,
      );
      _log.i(
        '章节细纲生成完成: "${draft.title}"',
        category: LogCategory.ai,
        tags: ['chapter-list', 'outline', 'generate'],
      );
      return draft;
    } catch (e, st) {
      _log.e(
        '章节细纲生成失败: $novelUrl - $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['chapter-list', 'outline', 'generate'],
      );
      rethrow;
    }
  }

  /// 重新生成章节细纲
  /// [novelUrl] 小说URL
  /// [mainOutline] 主大纲内容
  /// [previousChapters] 前文章节内容列表
  /// [feedback] 用户反馈
  /// [currentDraft] 当前细纲
  /// 返回重新生成的章节细纲
  Future<ChapterOutlineDraft> regenerateChapterOutline({
    required String novelUrl,
    required String mainOutline,
    required List<String> previousChapters,
    required String feedback,
    required ChapterOutlineDraft currentDraft,
  }) async {
    _log.d(
      '开始重新生成章节细纲: "${currentDraft.title}"',
      category: LogCategory.ai,
      tags: ['chapter-list', 'outline', 'regenerate'],
    );
    try {
      final draft = await _outlineService.regenerateChapterOutline(
        novelUrl: novelUrl,
        mainOutline: mainOutline,
        previousChapters: previousChapters,
        feedback: feedback,
        currentDraft: currentDraft,
      );
      _log.i(
        '章节细纲重新生成完成: "${draft.title}"',
        category: LogCategory.ai,
        tags: ['chapter-list', 'outline', 'regenerate'],
      );
      return draft;
    } catch (e, st) {
      _log.e(
        '章节细纲重新生成失败: $novelUrl - $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['chapter-list', 'outline', 'regenerate'],
      );
      rethrow;
    }
  }
}
