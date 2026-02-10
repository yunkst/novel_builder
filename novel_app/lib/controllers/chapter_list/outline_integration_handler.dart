import '../../models/outline.dart';
import '../../services/outline_service.dart';

/// 大纲集成处理器
/// 负责大纲相关的业务逻辑
class OutlineIntegrationHandler {
  final OutlineService _outlineService;

  OutlineIntegrationHandler({
    required OutlineService outlineService,
  }) : _outlineService = outlineService;

  /// 检查大纲是否存在
  Future<Outline?> getOutline(String novelUrl) async {
    return await _outlineService.getOutline(novelUrl);
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
    return await _outlineService.generateChapterOutline(
      novelUrl: novelUrl,
      mainOutline: mainOutline,
      previousChapters: previousChapters,
    );
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
    return await _outlineService.regenerateChapterOutline(
      novelUrl: novelUrl,
      mainOutline: mainOutline,
      previousChapters: previousChapters,
      feedback: feedback,
      currentDraft: currentDraft,
    );
  }
}
