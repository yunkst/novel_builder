import '../../models/chapter.dart';
import '../../models/character.dart';
import '../../models/novel.dart';
import '../../services/database_service.dart';
import '../../services/dify_service.dart';

/// AI章节生成器
/// 负责调用AI服务生成章节内容
class ChapterGenerator {
  final DatabaseService _databaseService;
  final DifyService _difyService;

  ChapterGenerator({
    required DatabaseService databaseService,
    required DifyService difyService,
  })  : _databaseService = databaseService,
        _difyService = difyService;

  /// 生成章节内容
  /// [novel] 小说信息
  /// [chapters] 当前章节列表
  /// [afterIndex] 插入位置索引
  /// [userInput] 用户输入的内容要求
  /// [characterIds] 选中的角色ID列表
  /// [onData] 数据回调（流式输出）
  /// [onError] 错误回调
  /// [onDone] 完成回调
  Future<void> generateChapter({
    required Novel novel,
    required List<Chapter> chapters,
    required int afterIndex,
    required String userInput,
    required List<int> characterIds,
    required Function(String) onData,
    required Function(String) onError,
    required Function() onDone,
  }) async {
    // 获取历史章节内容（最近5章）
    final historyChaptersContent = await _getHistoryChaptersContent(
      novel: novel,
      chapters: chapters,
      afterIndex: afterIndex,
    );

    // 获取选中人物信息并格式化为AI可读文本
    final rolesInfo = await _getRolesInfo(characterIds);

    // 构建Dify请求参数
    final inputs = {
      'user_input': userInput,
      'cmd': '', // 空的cmd参数
      'current_chapter_content': '', // 空的当前章节字段
      'history_chapters_content': historyChaptersContent,
      'background_setting': novel.description ?? '',
      'ai_writer_setting': '', // 可以从设置中获取
      'next_chapter_overview': '',
      'roles': rolesInfo,
    };

    // 调用Dify流式生成
    await _difyService.runWorkflowStreaming(
      inputs: inputs,
      onData: onData,
      onError: onError,
      onDone: onDone,
    );
  }

  /// 获取历史章节内容（用于上下文）
  Future<String> _getHistoryChaptersContent({
    required Novel novel,
    required List<Chapter> chapters,
    required int afterIndex,
  }) async {
    String historyChaptersContent = '';

    // 安全检查：确保chapters不为空且索引有效
    if (chapters.isNotEmpty &&
        afterIndex >= 0 &&
        afterIndex < chapters.length) {
      int startIndex = (afterIndex - 4).clamp(0, chapters.length - 1);
      for (int i = startIndex; i <= afterIndex; i++) {
        final content = await _databaseService.getCachedChapter(
          chapters[i].url,
        );
        if (content != null && content.isNotEmpty) {
          historyChaptersContent +=
              '第${i + 1}章 ${chapters[i].title}\n$content\n\n';
        }
      }
    } else if (chapters.isEmpty) {
      // 如果是空列表（创建第一章），提供一些默认的上下文信息
      historyChaptersContent = '这是小说的开始，请创建引人入胜的第一章内容。\n';
      if (novel.description?.isNotEmpty == true) {
        historyChaptersContent += '小说背景：${novel.description}\n';
      }
      historyChaptersContent += '作者：${novel.author}\n';
    }

    return historyChaptersContent;
  }

  /// 获取角色信息并格式化为AI可读文本
  Future<String> _getRolesInfo(List<int> characterIds) async {
    if (characterIds.isEmpty) {
      return '无特定角色出场';
    }

    final selectedCharacters =
        await _databaseService.getCharactersByIds(characterIds);
    return Character.formatForAI(selectedCharacters);
  }
}
