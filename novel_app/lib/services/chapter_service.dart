import '../models/chapter.dart';
import '../models/character.dart';
import '../models/novel.dart';
import '../constants/chapter_constants.dart';
import 'database_service.dart';

/// 章节生成相关的业务逻辑服务
///
/// 职责：
/// - 处理章节生成的业务逻辑
/// - 提供历史章节查询和处理
/// - 提供角色信息格式化
/// - 构建完整的 AI 请求参数
class ChapterService {
  final DatabaseService _databaseService;

  /// 构造函数
  ChapterService({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService();

  /// 获取历史章节内容（用于生成上下文）
  ///
  /// 参数：
  /// - [chapters] 当前章节列表
  /// - [afterIndex] 插入位置索引
  /// - [novel] 小说信息（可选，用于空列表时的默认上下文）
  ///
  /// 返回：拼接好的历史章节文本
  ///
  /// 业务逻辑：
  /// - 如果章节列表为空，返回默认的引导文本（需要novel参数）
  /// - 如果有章节，获取最近 [ChapterConstants.contextChapterCount] 章的内容
  /// - 处理边界情况（索引越界、空章节等）
  Future<String> getHistoryChaptersContent({
    required List<Chapter> chapters,
    required int afterIndex,
    Novel? novel,
  }) async {
    String historyChaptersContent = '';

    // 安全检查：确保chapters不为空且索引有效
    if (chapters.isNotEmpty &&
        afterIndex >= 0 &&
        afterIndex < chapters.length) {
      // 计算范围：最近N章（包括当前章节）
      final startIndex = (afterIndex - ChapterConstants.contextChapterCount + 1)
          .clamp(0, chapters.length - 1);

      // 遍历并拼接历史章节内容
      for (int i = startIndex; i <= afterIndex; i++) {
        final content = await _databaseService.getCachedChapter(
          chapters[i].url,
        );
        if (content != null && content.isNotEmpty) {
          historyChaptersContent +=
              '第${i + 1}章 ${chapters[i].title}\n$content\n\n';
        }
      }
    } else if (chapters.isEmpty && novel != null) {
      // 如果是空列表（创建第一章），提供默认的上下文信息
      historyChaptersContent = '这是小说的开始，请创建引人入胜的第一章内容。\n';
      if (novel.description?.isNotEmpty == true) {
        historyChaptersContent += '小说背景：${novel.description}\n';
      }
      historyChaptersContent += '作者：${novel.author}\n';
    }

    return historyChaptersContent;
  }

  /// 获取前文章节内容列表（用于AI上下文）
  ///
  /// 参数：
  /// - [chapters] 当前章节列表
  /// - [afterIndex] 当前章节索引
  ///
  /// 返回：前文章节内容的字符串列表
  ///
  /// 与 [getHistoryChaptersContent] 的区别：
  /// - 此方法返回列表，每个元素是一章的完整信息
  /// - 包含未缓存章节的提示
  /// - 用于大纲生成等需要区分每章的场景
  Future<List<String>> getPreviousChaptersContent({
    required List<Chapter> chapters,
    required int afterIndex,
  }) async {
    final List<String> previousChapters = [];

    // 获取前N章的内容
    final startIndex = (afterIndex - ChapterConstants.contextChapterCount)
        .clamp(0, afterIndex);

    for (int i = startIndex; i <= afterIndex && i < chapters.length; i++) {
      final chapter = chapters[i];
      // 优先从缓存获取
      final content = await _databaseService.getCachedChapter(chapter.url);
      if (content != null && content.isNotEmpty) {
        previousChapters.add('第${i + 1}章 ${chapter.title}\n$content');
      } else {
        previousChapters.add('第${i + 1}章 ${chapter.title}\n（内容未缓存）');
      }
    }

    return previousChapters;
  }

  /// 获取角色信息的 AI 格式化文本
  ///
  /// 参数：
  /// - [characterIds] 角色ID列表
  ///
  /// 返回：格式化为 AI 可读的文本
  ///
  /// 业务逻辑：
  /// - 如果没有选择角色，返回"无特定角色出场"
  /// - 如果有角色，查询数据库并格式化为 AI 可读文本
  Future<String> getRolesInfoForAI(List<int> characterIds) async {
    if (characterIds.isEmpty) {
      return '无特定角色出场';
    }

    final selectedCharacters =
        await _databaseService.getCharactersByIds(characterIds);
    return Character.formatForAI(selectedCharacters);
  }

  /// 构建章节生成的完整 inputs 参数
  ///
  /// 参数：
  /// - [novel] 小说信息
  /// - [chapters] 当前章节列表
  /// - [afterIndex] 插入位置索引
  /// - [userInput] 用户输入的内容要求
  /// - [characterIds] 选中的角色ID列表
  ///
  /// 返回：完整的 Dify 请求参数 Map
  ///
  /// 业务逻辑：
  /// - 调用 getHistoryChaptersContent() 获取历史章节
  /// - 调用 getRolesInfoForAI() 获取角色信息
  /// - 组装完整的 inputs 参数
  Future<Map<String, dynamic>> buildChapterGenerationInputs({
    required Novel novel,
    required List<Chapter> chapters,
    required int afterIndex,
    required String userInput,
    required List<int> characterIds,
  }) async {
    // 获取历史章节内容
    final historyChaptersContent = await getHistoryChaptersContent(
      chapters: chapters,
      afterIndex: afterIndex,
      novel: novel,
    );

    // 获取选中人物信息并格式化为AI可读文本
    final rolesInfo = await getRolesInfoForAI(characterIds);

    // 构建Dify请求参数
    return {
      'user_input': userInput,
      'cmd': '', // 空的cmd参数
      'current_chapter_content': '', // 空的当前章节字段
      'history_chapters_content': historyChaptersContent,
      'background_setting': novel.description ?? '',
      'ai_writer_setting': '', // 可以从设置中获取
      'next_chapter_overview': '',
      'roles': rolesInfo,
    };
  }
}
