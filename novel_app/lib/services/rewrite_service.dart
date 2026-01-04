import '../models/character.dart';

/// 段落改写相关的业务逻辑服务
///
/// 职责：
/// - 处理段落改写的业务逻辑
/// - 构建改写功能的 AI 请求参数
/// - 提供角色信息格式化
class RewriteService {
  /// 构建段落改写的完整 inputs 参数（简化版）
  ///
  /// 参数：
  /// - [selectedText] 用户选中的文本
  /// - [userInput] 用户输入的要求
  /// - [fullContext] 当前章节及之前的内容（作为上下文）
  /// - [characters] 选中的角色列表
  ///
  /// 返回：完整的 Dify 请求参数 Map
  Map<String, dynamic> buildRewriteInputs({
    required String selectedText,
    required String userInput,
    required String fullContext,
    required List<Character> characters,
  }) {
    return {
      'current_chapter_content': fullContext,
      'selected_text': selectedText,
      'user_input': userInput,
      'roles': Character.formatForAI(characters),
      'cmd': '特写',
    };
  }

  /// 构建段落改写的完整 inputs 参数（完整版，支持历史章节和AI设定）
  ///
  /// 参数：
  /// - [selectedText] 用户选中的文本
  /// - [userInput] 用户输入的要求
  /// - [currentChapterContent] 当前章节内容
  /// - [historyChaptersContent] 历史章节内容（多章拼接）
  /// - [backgroundSetting] 小说背景设定
  /// - [aiWriterSetting] AI作家设定
  /// - [rolesInfo] 角色信息文本
  ///
  /// 返回：完整的 Dify 请求参数 Map
  Map<String, dynamic> buildRewriteInputsWithHistory({
    required String selectedText,
    required String userInput,
    required String currentChapterContent,
    required String historyChaptersContent,
    required String backgroundSetting,
    required String aiWriterSetting,
    required String rolesInfo,
  }) {
    return {
      'user_input': userInput,
      'cmd': '特写',
      'ai_writer_setting': aiWriterSetting,
      'history_chapters_content': historyChaptersContent,
      'current_chapter_content': currentChapterContent,
      'choice_content': selectedText,
      'background_setting': backgroundSetting,
      'roles': rolesInfo,
    };
  }
}
