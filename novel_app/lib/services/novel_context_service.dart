import '../models/novel.dart';
import '../models/chapter.dart';
import '../services/chapter_history_service.dart';
import '../core/interfaces/repositories/i_novel_repository.dart';

/// 小说上下文数据
///
/// 封装AI功能所需的背景设定、历史章节内容等数据
class NovelContext {
  final String backgroundSetting;
  final String historyChaptersContent;
  final String currentChapterContent;
  final String novelDescription;

  const NovelContext({
    required this.backgroundSetting,
    required this.historyChaptersContent,
    required this.currentChapterContent,
    this.novelDescription = '',
  });

  /// 构建Dify工作流的基础输入参数
  ///
  /// 提供通用的参数结构，子类可以扩展特定参数
  Map<String, String> buildBaseInputs({
    String? userInput,
    String? cmd,
    String? choiceContent,
    String? aiWriterSetting,
    String? nextChapterOverview,
    String? charactersInfo,
  }) {
    return {
      'user_input': userInput ?? '',
      'cmd': cmd ?? '',
      'history_chapters_content': historyChaptersContent,
      'current_chapter_content': currentChapterContent,
      'choice_content': choiceContent ?? '',
      'ai_writer_setting': aiWriterSetting ?? '',
      'background_setting': backgroundSetting,
      'next_chapter_overview': nextChapterOverview ?? '',
      'characters_info': charactersInfo ?? '',
    };
  }

  /// 构建总结专用的输入参数
  Map<String, String> buildSummaryInputs() {
    return buildBaseInputs(
      userInput: '总结',
      cmd: '总结',
    );
  }

  /// 构建全文重写专用的输入参数
  Map<String, String> buildFullRewriteInputs(String userInput) {
    return buildBaseInputs(
      userInput: userInput,
      cmd: '',
      choiceContent: '',
    );
  }
}

/// 小说上下文构建器
///
/// 负责从各种数据源收集并构建 NovelContext
/// 消除多个Dialog中重复的数据获取逻辑
class NovelContextBuilder {
  final ChapterHistoryService? _historyService;
  final INovelRepository _novelRepository;

  NovelContextBuilder({
    ChapterHistoryService? historyService,
    required INovelRepository novelRepository,
  })  : _historyService = historyService,
        _novelRepository = novelRepository;

  /// 构建小说上下文
  ///
  /// [novel] 小说对象
  /// [chapters] 章节列表
  /// [currentChapter] 当前章节
  /// [currentContent] 当前章节内容
  /// [maxHistoryCount] 最大历史章节数量，默认为2
  Future<NovelContext> buildContext(
    Novel novel,
    List<Chapter> chapters,
    Chapter currentChapter,
    String currentContent, {
    int maxHistoryCount = 2,
  }) async {
    // 获取背景设定
    final backgroundSetting =
        await _novelRepository.getBackgroundSetting(novel.url) ?? '';

    // 获取历史章节内容（如果提供了 historyService）
    final historyContent = _historyService != null
        ? await _historyService!.fetchHistoryChaptersContent(
            chapters: chapters,
            currentChapter: currentChapter,
            maxHistoryCount: maxHistoryCount,
          )
        : '';

    return NovelContext(
      backgroundSetting: backgroundSetting,
      historyChaptersContent: historyContent,
      currentChapterContent: currentContent,
      novelDescription: novel.description ?? '',
    );
  }

  /// 仅获取背景设定（用于只需更新背景的场景）
  Future<String> getBackgroundSetting(String novelUrl) async {
    final backgroundSetting =
        await _novelRepository.getBackgroundSetting(novelUrl);
    return backgroundSetting ?? '';
  }

  /// 使用小说URL直接构建上下文（简化版）
  ///
  /// 当只有 novelUrl 可用时使用，需要额外提供章节信息
  Future<NovelContext> buildContextByUrl(
    String novelUrl,
    String? novelDescription,
    List<Chapter> chapters,
    Chapter currentChapter,
    String currentContent, {
    int maxHistoryCount = 2,
  }) async {
    // 获取历史章节内容（如果提供了 historyService）
    final historyContent = _historyService != null
        ? await _historyService!.fetchHistoryChaptersContent(
            chapters: chapters,
            currentChapter: currentChapter,
            maxHistoryCount: maxHistoryCount,
          )
        : '';

    final backgroundSetting =
        await _novelRepository.getBackgroundSetting(novelUrl) ?? '';

    return NovelContext(
      backgroundSetting: backgroundSetting,
      historyChaptersContent: historyContent,
      currentChapterContent: currentContent,
      novelDescription: novelDescription ?? '',
    );
  }
}
