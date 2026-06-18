import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/character.dart';
import '../models/chat_message.dart';
import '../services/dify_service.dart';
import '../services/character_avatar_service.dart';
import '../services/logger_service.dart';
import '../utils/chat_stream_parser.dart';
import '../utils/role_color_manager.dart';
import '../utils/toast_utils.dart';
import '../core/providers/services/ai_service_providers.dart';
import '../core/providers/services/cache_service_providers.dart';
import '../core/theme/app_colors.dart';

/// 多角色聊天屏幕 (Riverpod版本)
///
/// 本页面实现了一个多角色对话系统，AI 会同时扮演多个角色进行互动对话。
///
/// ## 核心功能
/// - **多角色支持**：一次对话可涉及多个角色，每个角色有独立的颜色标识
/// - **流式响应**：实时显示 AI 生成的旁白和角色对话
/// - **标签解析**：智能解析 `<旁白>`、`<角色名>` 等 XML 风格标签
/// - **历史记录**：维护完整的对话历史，支持上下文关联
/// - **用户参与**：用户可选择扮演某个角色，或作为旁观者
///
/// ## 标签格式
/// AI 输出的流式数据使用以下标签格式：
/// - `<旁白>内容</旁白>` - 旁白内容（灰色背景）
/// - `<角色名>内容</角色名>` - 角色对话（彩色气泡）
///
/// 标签解析支持跨 chunk 的情况，例如标签开始和结束可能在不同的数据块中。
///
/// ## 消息类型
/// - **用户动作**：用户输入的动作描述（蓝色气泡）
/// - **用户对话**：用户输入的台词（绿色气泡）
/// - **角色对话**：AI 生成的角色台词（彩色气泡）
/// - **旁白**：AI 生成的旁白描述（灰色气泡）
///
/// ## 状态管理
/// - 使用 Riverpod 管理服务依赖
/// - 使用 StatefulWidget 管理页面状态
/// - 使用 TagParserState 管理跨 chunk 的标签解析状态
///
/// ## 数据流
/// 1. 用户输入动作/对话
/// 2. 发送到 Dify 服务
/// 3. 接收流式响应（SSE）
/// 4. 解析标签并更新 UI
/// 5. 保存到历史记录
class MultiRoleChatScreen extends ConsumerStatefulWidget {
  final List<Character> characters; // 多个角色
  final String play; // 剧本内容
  final List<Map<String, dynamic>> roleStrategy; // 角色策略
  final String? userRole; // 用户选择的角色名(可选)

  const MultiRoleChatScreen({
    super.key,
    required this.characters,
    required this.play,
    required this.roleStrategy,
    this.userRole,
  });

  @override
  ConsumerState<MultiRoleChatScreen> createState() =>
      _MultiRoleChatScreenState();
}

class _MultiRoleChatScreenState extends ConsumerState<MultiRoleChatScreen> {
  // ========================================================================
  // 状态管理
  // ========================================================================

  /// 消息列表（包含用户消息和 AI 响应）
  List<ChatMessage> _messages = [];

  /// 是否正在生成 AI 响应
  bool _isGenerating = false;

  /// 是否在角色对话标签中（用于标签解析）
  bool _inDialogue = false;

  /// 标签解析状态（用于跨 chunk 标签解析）
  final TagParserState _tagParserState = TagParserState();

  /// AI 响应累积（用于历史记录）
  String _currentAiResponse = '';

  /// 聊天历史（用于发送给 AI 的上下文）
  final List<String> _chatHistory = [];

  // ========================================================================
  // 控制器和焦点
  // ========================================================================

  /// 动作输入控制器
  final TextEditingController _actionController = TextEditingController();

  /// 对话输入控制器
  final TextEditingController _speechController = TextEditingController();

  /// 滚动控制器
  final ScrollController _scrollController = ScrollController();

  /// 动作输入焦点
  final FocusNode _actionFocusNode = FocusNode();

  /// 对话输入焦点
  final FocusNode _speechFocusNode = FocusNode();

  // ========================================================================
  // 服务和颜色管理
  // ========================================================================

  /// Dify 服务实例（通过 Riverpod 获取）
  late DifyService _difyService;

  /// 角色头像服务实例（通过 Riverpod 获取）
  late CharacterAvatarService _avatarService;

  /// 角色颜色映射（每个角色分配独特的颜色）
  late Map<String, Color> _roleColors;

  @override
  void initState() {
    super.initState();
    // initState 无 context，使用暗色调色板兜底；
    // build 中将根据主题重新分配。
    _roleColors = RoleColorManager.assignColors(widget.characters);
    // 延迟初始化聊天，确保服务已加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _difyService = ref.read(difyServiceProvider);
      _avatarService = ref.watch(characterAvatarServiceProvider);
      _startInitialChat();
    });
  }

  @override
  void dispose() {
    _actionController.dispose();
    _speechController.dispose();
    _scrollController.dispose();
    _actionFocusNode.dispose();
    _speechFocusNode.dispose();
    super.dispose();
  }

  // ========================================================================
  // 聊天初始化
  // ========================================================================

  /// 开始初始聊天
  Future<void> _startInitialChat() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      await _difyService.runWorkflowStreaming(
        inputs: {
          'cmd': '聊天',
          'roles': _formatAllCharacters(),
          'scene': widget.play,
          'user_input': '', // 初始聊天没有用户输入
          'chat_history': '',
          'choice_content': widget.userRole ?? '', // 用户选择的角色名
        },
        onData: (chunk) => _handleStreamChunk(chunk),
        onError: (error) {
          setState(() {
            _isGenerating = false;
          });
          LoggerService.instance.e(
            '多角色初始聊天失败: $error',
            category: LogCategory.ai,
            tags: ['chat', 'multi-role', 'init', 'failed'],
          );
          _showErrorSnackBar(error);
        },
        onDone: () {
          setState(() {
            _isGenerating = false;

            // 重置标签解析状态
            _tagParserState.reset();

            // 将AI响应添加到历史（无包裹标签）
            if (_currentAiResponse.isNotEmpty) {
              _chatHistory.add(_currentAiResponse);
              _currentAiResponse = '';
            }
          });
        },
      );
    } catch (e, stackTrace) {
      setState(() {
        _isGenerating = false;
      });
      LoggerService.instance.e(
        '多角色初始聊天异常: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['chat', 'multi-role', 'init', 'error'],
      );
      _showErrorSnackBar(e.toString());
    }
  }

  /// 格式化所有角色信息
  String _formatAllCharacters() {
    final buffer = StringBuffer();

    for (final character in widget.characters) {
      final strategy = widget.roleStrategy.firstWhere(
        (s) => s['name'] == character.name,
        orElse: () => {'strategy': ''},
      );

      buffer.writeln('角色：${character.name}');

      // 基本信息
      if (character.gender != null) {
        buffer.writeln('性别：${character.gender}');
      }
      if (character.age != null) {
        buffer.writeln('年龄：${character.age}');
      }
      if (character.occupation != null && character.occupation!.isNotEmpty) {
        buffer.writeln('职业：${character.occupation}');
      }
      if (character.personality != null && character.personality!.isNotEmpty) {
        buffer.writeln('性格：${character.personality}');
      }

      // 外貌
      if (character.bodyType != null && character.bodyType!.isNotEmpty) {
        buffer.writeln('体型：${character.bodyType}');
      }
      if (character.appearanceFeatures != null &&
          character.appearanceFeatures!.isNotEmpty) {
        buffer.writeln('外貌：${character.appearanceFeatures}');
      }

      // 服装：从 role_strategy 中获取当前场景的服装
      final clothes = strategy['clothes'] as String?;
      if (clothes != null && clothes.isNotEmpty) {
        buffer.writeln('服装：$clothes');
      }

      // 角色策略
      buffer.writeln('策略：${strategy['strategy'] ?? ''}');
      buffer.writeln('---');
    }

    return buffer.toString().trim();
  }

  /// 处理流式文本块
  void _handleStreamChunk(String chunk) {
    // 累积原始AI响应（用于历史记录）
    _currentAiResponse += chunk;

    final displayChunk =
        chunk.length > 50 ? '${chunk.substring(0, 50)}...' : chunk;
    LoggerService.instance.d(
      '收到chunk: "$displayChunk", 标签状态: ${_tagParserState.toString()}',
      category: LogCategory.ai,
      tags: ['chat', 'multi-role', 'chunk'],
    );

    // 解析显示（传递标签状态）
    final result = ChatStreamParser.parseChunkForMultiRole(
      chunk,
      _messages,
      widget.characters,
      _inDialogue,
      tagState: _tagParserState,
    );

    setState(() {
      // 限制消息数量（保留最新100条）
      _messages = result.messages.length > 100
          ? result.messages.sublist(result.messages.length - 100)
          : result.messages;
      _inDialogue = result.inDialogue;
    });

    // 自动滚动到底部
    _scrollToBottom();
  }

  // ========================================================================
  // UI 辅助方法
  // ========================================================================

  /// 滚动到底部
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// 显示错误提示
  void _showErrorSnackBar(String error) {
    if (mounted) {
      ToastUtils.showError('生成失败: $error');
    }
  }

  /// 获取当前聚焦的输入框控制器
  TextEditingController? _getCurrentFocusedController() {
    if (_actionFocusNode.hasFocus) {
      return _actionController;
    } else if (_speechFocusNode.hasFocus) {
      return _speechController;
    }
    return null;
  }

  /// 插入角色名到当前聚焦的输入框
  void _insertCharacterName(String characterName) {
    // 获取当前聚焦的控制器
    TextEditingController? controller = _getCurrentFocusedController();

    // 如果没有聚焦的输入框，默认使用对话输入框
    if (controller == null) {
      _speechFocusNode.requestFocus();
      controller = _speechController;
    }

    // 获取当前文本和光标位置
    final text = controller.text;
    final selection = controller.selection;
    final cursorPosition =
        selection.baseOffset >= 0 ? selection.baseOffset : text.length;

    // 在光标位置插入角色名
    final newText = text.replaceRange(
      cursorPosition,
      cursorPosition,
      characterName,
    );

    // 更新文本和光标位置
    controller.text = newText;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: cursorPosition + characterName.length),
    );

    // 显示插入成功提示
    if (mounted) {
      ToastUtils.showInfo('已插入: $characterName');
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 根据当前主题重新分配角色色
    _roleColors = RoleColorManager.assignColors(
      widget.characters,
      context: context,
    );
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('沉浸式对话'),
            const SizedBox(height: 4),
            Text(
              '角色：${widget.characters.map((c) => c.name).join('、')}',
              style: TextStyle(
                fontSize: 12,
                color: context.appColors.chatSecondaryText,
              ),
            ),
          ],
        ),
        backgroundColor: context.appColors.chatInputBackground,
        foregroundColor: context.appColors.chatPrimaryText,
        actions: [
          // 角色策略查看按钮
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '角色策略',
            onPressed: _showRoleStrategyDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 聊天消息列表
          Expanded(
            child: _messages.isEmpty ? _buildEmptyState() : _buildMessageList(),
          ),

          // 用户输入区域
          _buildInputArea(),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: _isGenerating
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  '正在建立连接...',
                  style: TextStyle(
                    color: context.appColors.chatSecondaryText,
                    fontSize: 16,
                  ),
                ),
              ],
            )
          : Text(
              '开始你们的对话吧！',
              style: TextStyle(
                color: context.appColors.chatHintText,
                fontSize: 18,
              ),
            ),
    );
  }

  /// 构建消息列表
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  /// 构建消息气泡
  Widget _buildMessageBubble(ChatMessage message) {
    switch (message.type) {
      case 'narration':
        return _buildNarrationBubble(message);
      case 'dialogue':
        return _buildDialogueBubble(message);
      case 'user_action':
      case 'user_speech':
        return _buildUserBubble(message);
      default:
        return const SizedBox.shrink();
    }
  }

  /// 构建旁白气泡
  Widget _buildNarrationBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        message.content,
        style: TextStyle(
          color: context.appColors.chatHintText,
          fontStyle: FontStyle.italic,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  /// 构建角色对话气泡
  Widget _buildDialogueBubble(ChatMessage message) {
    final character = message.character!;
    final color =
        _roleColors[character.name] ?? context.appColors.chatRoleBubble;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 角色头像
          _buildCharacterAvatar(character, color),
          const SizedBox(width: 8),

          // 对话气泡
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      message.content,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            height: 1.5,
                            color: context.appColors.chatPrimaryText,
                          ),
                    ),
                  ),
                  // 流式输出指示器
                  if (_isGenerating && message == _messages.last)
                    _buildTypingIndicator(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建用户消息气泡
  Widget _buildUserBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.appColors.chatUserBubble,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.appColors.chatUserBubbleBorder,
              width: 2,
            ),
          ),
          child: Text(
            message.content,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  height: 1.5,
                  color: context.appColors.chatPrimaryText,
                ),
          ),
        ),
      ),
    );
  }

  /// 构建角色头像
  Widget _buildCharacterAvatar(Character character, Color color) {
    return FutureBuilder<String?>(
      future: character.id != null
          ? _avatarService.getCharacterAvatarPath(character.id!)
          : Future.value(null),
      builder: (context, snapshot) {
        final avatarPath = snapshot.data;

        if (avatarPath != null && File(avatarPath).existsSync()) {
          // 使用InkWell包裹头像，添加点击交互
          return Tooltip(
            message: '点击插入 ${character.name}',
            child: InkWell(
              onTap: () => _insertCharacterName(character.name),
              customBorder: const CircleBorder(),
              splashColor: color.withValues(alpha: 0.5),
              hoverColor: color.withValues(alpha: 0.3),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: ClipOval(
                  child: Image.file(
                    File(avatarPath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildFallbackAvatar(character, color);
                    },
                  ),
                ),
              ),
            ),
          );
        }

        // 备用头像也添加点击交互
        return Tooltip(
          message: '点击插入 ${character.name}',
          child: InkWell(
            onTap: () => _insertCharacterName(character.name),
            customBorder: const CircleBorder(),
            splashColor: color.withValues(alpha: 0.5),
            hoverColor: color.withValues(alpha: 0.3),
            child: _buildFallbackAvatar(character, color),
          ),
        );
      },
    );
  }

  /// 构建备用头像（首字母）
  Widget _buildFallbackAvatar(Character character, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          character.name.isNotEmpty ? character.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  /// 构建打字指示器（三个跳动的小圆点）
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor:
              AlwaysStoppedAnimation<Color>(context.appColors.chatButtonPrimary),
        ),
      ),
    );
  }

  /// 构建输入区域
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.chatInputBackground,
        border: Border(
          top: BorderSide(color: context.appColors.chatDivider),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 角色选择提示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  context.appColors.chatRoleBubble.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.appColors.chatDivider,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people,
                  size: 16,
                  color: context.appColors.chatSecondaryText,
                ),
                const SizedBox(width: 8),
                Text(
                  '正在与 ${widget.characters.map((c) => c.name).join('、')} 对话',
                  style: TextStyle(
                    color: context.appColors.chatSecondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 行为输入框
          TextField(
            controller: _actionController,
            focusNode: _actionFocusNode,
            decoration: InputDecoration(
              labelText: '行为（可选）',
              hintText: '例如：举起酒杯，微笑着说',
              border: OutlineInputBorder(
                borderSide: BorderSide(color: context.appColors.chatDivider),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: context.appColors.chatDivider),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: context.appColors.chatButtonPrimary),
              ),
              labelStyle: TextStyle(color: context.appColors.chatSecondaryText),
              hintStyle: TextStyle(color: context.appColors.chatHintText),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: TextStyle(color: context.appColors.chatPrimaryText),
            maxLines: null,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),

          // 对话输入框
          TextField(
            controller: _speechController,
            focusNode: _speechFocusNode,
            decoration: InputDecoration(
              labelText: '对话（可选）',
              hintText: '例如：大家好，最近怎么样？',
              border: OutlineInputBorder(
                borderSide: BorderSide(color: context.appColors.chatDivider),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: context.appColors.chatDivider),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: context.appColors.chatButtonPrimary),
              ),
              labelStyle: TextStyle(color: context.appColors.chatSecondaryText),
              hintStyle: TextStyle(color: context.appColors.chatHintText),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: TextStyle(color: context.appColors.chatPrimaryText),
            maxLines: 3,
            minLines: 1,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _canSend() ? _sendMessage() : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),

          // 发送按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSend() ? _sendMessage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appColors.chatButtonPrimary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                disabledBackgroundColor: context.appColors.chatButtonDisabled,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(_isGenerating ? '生成中...' : '发送'),
            ),
          ),
        ],
      ),
    );
  }

  /// 判断是否可以发送消息
  bool _canSend() {
    return (_actionController.text.trim().isNotEmpty ||
            _speechController.text.trim().isNotEmpty) &&
        !_isGenerating;
  }

  /// 显示角色策略对话框
  void _showRoleStrategyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.people, color: context.appColors.info),
            const SizedBox(width: 8),
            Text('角色策略'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.roleStrategy.length,
            itemBuilder: (context, index) {
              final strategy = widget.roleStrategy[index];
              final characterName = strategy['name'] as String? ?? '未知角色';
              final strategyText = strategy['strategy'] as String? ?? '';

              final color = _roleColors[characterName] ?? Theme.of(context).colorScheme.outline;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                              border: Border.all(color: color),
                            ),
                            child: Center(
                              child: Text(
                                characterName.isNotEmpty
                                    ? characterName[0]
                                    : '?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            characterName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strategyText.isNotEmpty ? strategyText : '暂无策略',
                        style: TextStyle(
                          fontSize: 14,
                          color: strategyText.isNotEmpty
                              ? context.appColors.chatPrimaryText
                              : context.appColors.chatHintText,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 发送用户消息
  Future<void> _sendMessage() async {
    final action = _actionController.text.trim();
    final speech = _speechController.text.trim();

    if (action.isEmpty && speech.isEmpty) return;
    if (_isGenerating) return;

    // 保存用户输入
    final userAction = action;
    final userSpeech = speech;

    // 清空输入框
    _actionController.clear();
    _speechController.clear();

    // 调用Dify流式API
    await _callDifyStreaming(userAction: userAction, userSpeech: userSpeech);
  }

  /// 调用Dify流式API
  Future<void> _callDifyStreaming({
    String userAction = '',
    String userSpeech = '',
  }) async {
    // 如果有用户输入，先显示用户消息
    if (userAction.isNotEmpty || userSpeech.isNotEmpty) {
      setState(() {
        if (userAction.isNotEmpty) {
          _messages.add(ChatMessage.userAction(userAction));
        }
        if (userSpeech.isNotEmpty) {
          _messages.add(ChatMessage.userSpeech(userSpeech));
        }

        // 添加空白旁白消息，为AI流式输出做准备
        _messages.add(ChatMessage.narration(''));
        _isGenerating = true;
        _inDialogue = false;

        // 将用户输入添加到历史记录（带XML标签）
        final userInput = '<用户>行为:$userAction\n对话:$userSpeech</用户>';
        _chatHistory.add(userInput);
      });
    } else {
      setState(() {
        _isGenerating = true;
        _inDialogue = false;
      });
    }

    // 格式化历史记录
    final chatHistory = _chatHistory.join('\n');
    final userInput = _formatUserInput(userAction, userSpeech);

    try {
      await _difyService.runWorkflowStreaming(
        inputs: {
          'cmd': '聊天',
          'roles': _formatAllCharacters(),
          'scene': widget.play,
          'user_input': userInput,
          'chat_history': chatHistory,
          'choice_content': widget.userRole ?? '', // 用户选择的角色名
        },
        onData: (chunk) => _handleStreamChunk(chunk),
        onError: (error) {
          setState(() {
            _isGenerating = false;
          });
          LoggerService.instance.e(
            '多角色聊天流式响应失败: $error',
            category: LogCategory.ai,
            tags: ['chat', 'multi-role', 'stream', 'failed'],
          );
          _showErrorSnackBar(error);
        },
        onDone: () {
          setState(() {
            _isGenerating = false;

            // 重置标签解析状态
            _tagParserState.reset();

            // AI响应添加到历史（无包裹标签）
            if (_currentAiResponse.isNotEmpty) {
              _chatHistory.add(_currentAiResponse);
              _currentAiResponse = '';
            }
          });
        },
      );
    } catch (e, stackTrace) {
      setState(() {
        _isGenerating = false;
      });
      LoggerService.instance.e(
        '多角色聊天流式响应异常: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['chat', 'multi-role', 'stream', 'error'],
      );
      _showErrorSnackBar(e.toString());
    }
  }

  /// 格式化用户输入
  String _formatUserInput(String action, String speech) {
    final buffer = StringBuffer();
    if (action.isNotEmpty) buffer.write('行为：$action');
    if (speech.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write('对话：$speech');
    }
    return buffer.toString();
  }
}
