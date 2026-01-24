import '../models/chat_message.dart';
import '../models/character.dart';
import 'package:flutter/foundation.dart';

/// 解析结果
class ParseResult {
  final List<ChatMessage> messages;
  final bool inDialogue;

  const ParseResult({
    required this.messages,
    required this.inDialogue,
  });
}

/// 聊天流式文本解析器
///
/// 功能：
/// - 解析流式文本中的【】符号
/// - 【】内为角色对话，【】外为旁白
/// - 实时更新消息列表
class ChatStreamParser {
  /// 解析流式文本块
  ///
  /// 参数：
  /// - [chunk] 新接收的文本块
  /// - [currentMessages] 当前消息列表
  /// - [character] 角色信息
  /// - [inDialogue] 当前是否在对话模式中
  ///
  /// 返回：更新后的消息列表和新的对话状态
  static ParseResult parseChunk(
    String chunk,
    List<ChatMessage> currentMessages,
    Character character,
    bool inDialogue,
  ) {
    // 复制消息列表（避免直接修改原列表）
    List<ChatMessage> messages = List.from(currentMessages);

    // 遍历每个字符
    for (int i = 0; i < chunk.length; i++) {
      final char = chunk[i];

      if (char == '【') {
        // 切换到对话模式，创建新的对话消息（空内容）
        inDialogue = true;
        messages.add(ChatMessage.dialogue('', character));
      } else if (char == '】') {
        // 切换到旁白模式
        inDialogue = false;
      } else {
        // 普通字符，根据当前状态决定如何处理
        if (messages.isEmpty) {
          // 如果第一条消息就是普通字符，创建旁白消息
          messages.add(ChatMessage.narration(char));
        } else if (inDialogue && messages.last.type != 'dialogue') {
          // 当前不在对话中，但状态显示在对话中，创建新的对话消息
          messages.add(ChatMessage.dialogue(char, character));
        } else if (!inDialogue && messages.last.type == 'dialogue') {
          // 当前在对话中，但状态显示不在对话中，创建新的旁白消息
          messages.add(ChatMessage.narration(char));
        } else {
          // 继续追加到当前消息
          final lastMessage = messages.last;
          messages[lastMessageIndex(messages)] = lastMessage.copyWith(
            content: lastMessage.content + char,
          );
        }
      }
    }

    return ParseResult(messages: messages, inDialogue: inDialogue);
  }

  /// 解析结果
  static ParseResult parseChunkWithResult(
    String chunk,
    List<ChatMessage> currentMessages,
    Character character,
    bool inDialogue,
  ) {
    return parseChunk(chunk, currentMessages, character, inDialogue);
  }

  /// 调试：打印消息列表状态
  static void debugPrintMessages(List<ChatMessage> messages, String title) {
    debugPrint('=== $title ===');
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      debugPrint('[$i] ${msg.type} (${msg.isUser ? "用户" : "AI"}): ${msg.content}');
    }
    debugPrint('================');
  }

  /// 获取最后一条消息的索引
  static int lastMessageIndex(List<ChatMessage> messages) {
    return messages.length - 1;
  }

  /// 格式化聊天历史为字符串
  ///
  /// 直接用 \n 连接历史记录列表中的所有条目
  static String formatChatHistory(List<String> chatHistory) {
    return chatHistory.join('\n');
  }

  /// 格式化角色信息为自然语言（不使用JSON）
  static String formatRoleInfo(Character character) {
    final buffer = StringBuffer();
    buffer.writeln('角色名：${character.name}');
    buffer.writeln('性别：${character.gender ?? '未知'}');
    if (character.age != null) {
      buffer.writeln('年龄：${character.age}');
    }
    if (character.occupation != null && character.occupation!.isNotEmpty) {
      buffer.writeln('职业：${character.occupation}');
    }
    if (character.personality != null && character.personality!.isNotEmpty) {
      buffer.writeln('性格：${character.personality}');
    }
    if (character.bodyType != null && character.bodyType!.isNotEmpty) {
      buffer.writeln('体型：${character.bodyType}');
    }
    if (character.clothingStyle != null &&
        character.clothingStyle!.isNotEmpty) {
      buffer.writeln('服装：${character.clothingStyle}');
    }
    if (character.appearanceFeatures != null &&
        character.appearanceFeatures!.isNotEmpty) {
      buffer.writeln('外貌：${character.appearanceFeatures}');
    }
    if (character.backgroundStory != null &&
        character.backgroundStory!.isNotEmpty) {
      buffer.writeln('背景：${character.backgroundStory}');
    }

    return buffer.toString().trim();
  }

  /// 解析多角色流式文本
  ///
  /// 支持格式：
  /// - 纯文本 → 旁白
  /// - <角色名>内容</角色名> → 角色对话
  ///
  /// 参数：
  /// - [chunk] 新接收的文本块
  /// - [currentMessages] 当前消息列表
  /// - [allCharacters] 所有角色列表
  /// - [inDialogue] 当前是否在对话模式中
  ///
  /// 返回：更新后的消息列表和新的对话状态
  static ParseResult parseChunkForMultiRole(
    String chunk,
    List<ChatMessage> currentMessages,
    List<Character> allCharacters,
    bool inDialogue,
  ) {
    List<ChatMessage> messages = List.from(currentMessages);
    Character? currentCharacter;

    // 如果已经在对话中，找到当前角色
    if (inDialogue && messages.isNotEmpty && messages.last.type == 'dialogue') {
      currentCharacter = messages.last.character;
    }

    // 逐字符解析
    for (int i = 0; i < chunk.length; i++) {
      final char = chunk[i];

      if (char == '<') {
        // 检测标签
        final tagContent = _extractTag(chunk, i);
        if (tagContent != null) {
          final tagLength = tagContent.length + 2; // 包括 < 和 >
          i += tagLength - 1; // 跳过标签（循环会+1）

          if (tagContent.startsWith('/')) {
            // 闭合标签 </角色名>
            final tagName = tagContent.substring(1);
            if (currentCharacter?.name == tagName) {
              // 移除最后的空对话消息（如果有）
              if (messages.isNotEmpty &&
                  messages.last.type == 'dialogue' &&
                  messages.last.content.isEmpty) {
                messages.removeLast();
              }
              currentCharacter = null; // 结束对话
            } else {
              // 标签不匹配，作为普通文本追加到当前消息
              if (currentCharacter != null) {
                _appendToDialogue(messages, '</$tagName>', currentCharacter);
              } else {
                _appendToNarration(messages, '</$tagName>');
              }
            }
          } else {
            // 开放标签 <角色名>
            final character = _findCharacter(tagContent, allCharacters);
            if (character != null) {
              currentCharacter = character;
              messages.add(ChatMessage.dialogue('', character));
            } else {
              // 未知角色，作为普通文本处理
              _appendToNarration(messages, '<$tagContent>');
            }
          }
          continue;
        }
      }

      // 处理普通字符
      if (currentCharacter != null) {
        // 角色对话模式
        _appendToDialogue(messages, char, currentCharacter);
      } else {
        // 旁白模式
        _appendToNarration(messages, char);
      }
    }

    return ParseResult(
      messages: messages,
      inDialogue: currentCharacter != null,
    );
  }

  /// 提取标签内容
  /// 返回: 标签名（不包含 < 和 >），如果不是有效标签返回 null
  static String? _extractTag(String chunk, int startIndex) {
    if (startIndex >= chunk.length || chunk[startIndex] != '<') return null;

    final endIndex = chunk.indexOf('>', startIndex);
    if (endIndex == -1) return null;

    return chunk.substring(startIndex + 1, endIndex);
  }

  /// 查找角色
  static Character? _findCharacter(String name, List<Character> characters) {
    try {
      return characters.firstWhere((c) => c.name == name);
    } catch (e) {
      debugPrint('⚠️ 未找到角色: $name');
      return null;
    }
  }

  /// 追加到对话
  static void _appendToDialogue(
    List<ChatMessage> messages,
    String char,
    Character character,
  ) {
    if (messages.isEmpty ||
        messages.last.type != 'dialogue' ||
        messages.last.character != character) {
      messages.add(ChatMessage.dialogue(char, character));
    } else {
      final lastMessage = messages.last;
      messages[lastMessageIndex(messages)] = ChatMessage.dialogue(
        lastMessage.content + char,
        character,
      );
    }
  }

  /// 追加到旁白
  static void _appendToNarration(List<ChatMessage> messages, String char) {
    if (messages.isEmpty || messages.last.type != 'narration') {
      messages.add(ChatMessage.narration(char));
    } else {
      final lastMessage = messages.last;
      // 检查最后一条消息是否为空（避免累积空消息）
      if (lastMessage.content.isEmpty) {
        messages[lastMessageIndex(messages)] = ChatMessage.narration(char);
      } else {
        messages[lastMessageIndex(messages)] = ChatMessage.narration(
          lastMessage.content + char,
        );
      }
    }
  }
}
