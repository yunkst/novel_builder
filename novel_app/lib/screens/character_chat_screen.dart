import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/character.dart';
import '../models/chat_message.dart';
import '../services/dify_service.dart';
import '../services/character_avatar_service.dart';
import '../utils/chat_stream_parser.dart';
import '../utils/toast_utils.dart';
import '../screens/providers/dify_provider.dart';
import '../core/providers/services/cache_service_providers.dart';
import 'dart:io';

/// 角色聊天屏幕 (Riverpod版本)
class CharacterChatScreen extends ConsumerStatefulWidget {
  final Character character;
  final String initialScene;

  const CharacterChatScreen({
    super.key,
    required this.character,
    required this.initialScene,
  });

  @override
  ConsumerState<CharacterChatScreen> createState() =>
      _CharacterChatScreenState();
}

class _CharacterChatScreenState extends ConsumerState<CharacterChatScreen> {
  List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  bool _inDialogue = false; // 解析状态：是否在对话中
  final List<String> _chatHistory = []; // 聊天历史记录列表（维护时序）
  String _currentAiResponse = ''; // 当前 AI 回复的累积内容
  late String _scene;
  final TextEditingController _actionController = TextEditingController();
  final TextEditingController _speechController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 通过Provider获取服务实例
  late DifyService _difyService;
  late CharacterAvatarService _avatarService;

  @override
  void initState() {
    super.initState();
    _scene = widget.initialScene;
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
    super.dispose();
  }

  /// 开始初始聊天
  Future<void> _startInitialChat() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      await _difyService.runWorkflowStreaming(
        inputs: {
          'cmd': '聊天',
          'roles': ChatStreamParser.formatRoleInfo(widget.character),
          'scene': _scene,
          'user_input': '', // 初始聊天没有用户输入
          'chat_history': '',
        },
        onData: (chunk) {
          _handleStreamChunk(chunk);
        },
        onError: (error) {
          setState(() {
            _isGenerating = false;
          });
          _showErrorSnackBar(error);
        },
        onDone: () {
          setState(() {
            _isGenerating = false;

            // 将 AI 回复添加到历史记录
            if (_currentAiResponse.isNotEmpty) {
              final aiHistory =
                  '<${widget.character.name}>$_currentAiResponse</${widget.character.name}>';
              _chatHistory.add(aiHistory);
              _currentAiResponse = ''; // 清空累积内容
            }
          });
        },
      );
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      _showErrorSnackBar(e.toString());
    }
  }

  /// 处理流式文本块
  void _handleStreamChunk(String chunk) {
    // 累积 AI 回复内容（用于后续添加到历史记录）
    _currentAiResponse += chunk;

    // 调试：打印接收到的chunk
    debugPrint('🔥 收到chunk: "$chunk"');
    debugPrint('当前状态: _inDialogue=$_inDialogue');

    final result = ChatStreamParser.parseChunk(
      chunk,
      _messages,
      widget.character,
      _inDialogue,
    );

    // 调试：打印更新后的消息列表
    ChatStreamParser.debugPrintMessages(result.messages, '解析后消息');

    setState(() {
      // 更新消息列表和解析状态
      _messages = result.messages.length > 100
          ? result.messages.sublist(result.messages.length - 100)
          : result.messages;
      _inDialogue = result.inDialogue;
    });

    // 自动滚动到底部
    _scrollToBottom();
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

    // 调用Dify流式API（传递用户输入和历史记录）
    await _callDifyStreaming(
      userAction: userAction,
      userSpeech: userSpeech,
    );
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
        // 立即插入空白的旁白消息，为 AI 流式输出做准备
        _messages.add(ChatMessage.narration(''));
        _isGenerating = true;
        _inDialogue = false; // 重置对话状态，让AI从旁白开始

        // 将用户输入添加到历史记录
        final userHistory = _formatUserHistory(userAction, userSpeech);
        _chatHistory.add(userHistory);
      });
    } else {
      setState(() {
        _isGenerating = true;
        _inDialogue = false; // 重置对话状态，让AI从旁白开始
      });
    }

    // 格式化历史记录（直接用 \n 连接）
    final chatHistory = ChatStreamParser.formatChatHistory(_chatHistory);

    // 组合用户输入
    final userInput = _formatUserInput(userAction, userSpeech);

    try {
      await _difyService.runWorkflowStreaming(
        inputs: {
          'cmd': '聊天',
          'roles': ChatStreamParser.formatRoleInfo(widget.character),
          'scene': _scene,
          'user_input': userInput, // 新增：用户当前输入
          'chat_history': chatHistory,
        },
        onData: (chunk) {
          _handleStreamChunk(chunk);
        },
        onError: (error) {
          setState(() {
            _isGenerating = false;
          });
          _showErrorSnackBar(error);
        },
        onDone: () {
          setState(() {
            _isGenerating = false;

            // 将 AI 回复添加到历史记录
            if (_currentAiResponse.isNotEmpty) {
              final aiHistory =
                  '<${widget.character.name}>$_currentAiResponse</${widget.character.name}>';
              _chatHistory.add(aiHistory);
              _currentAiResponse = ''; // 清空累积内容
            }
          });
        },
      );
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      _showErrorSnackBar(e.toString());
    }
  }

  /// 格式化用户输入
  String _formatUserInput(String action, String speech) {
    final buffer = StringBuffer();

    if (action.isNotEmpty) {
      buffer.write('行为：$action');
    }
    if (speech.isNotEmpty) {
      if (buffer.isNotEmpty) {
        buffer.write('\n');
      }
      buffer.write('对话：$speech');
    }

    return buffer.toString();
  }

  /// 格式化用户输入为历史记录格式（带 XML 标签）
  String _formatUserHistory(String action, String speech) {
    final buffer = StringBuffer();

    if (action.isNotEmpty) {
      buffer.write('行为:$action');
    }
    if (speech.isNotEmpty) {
      if (buffer.isNotEmpty) {
        buffer.write('\n');
      }
      buffer.write('对话:$speech');
    }

    return '<用户>${buffer.toString()}</用户>';
  }

  /// 判断是否可以发送消息
  bool _canSend() {
    return (_actionController.text.trim().isNotEmpty ||
            _speechController.text.trim().isNotEmpty) &&
        !_isGenerating;
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('与 ${widget.character.name} 聊天'),
            const SizedBox(height: 4),
            Text(
              '场景：$_scene',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                ),
              ],
            )
          : Text(
              '开始你们的对话吧！',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
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
    if (message.type == 'narration' || message.type == 'user_action') {
      // 旁白和用户行为都显示为灰色斜体
      return _buildNarrationBubble(message);
    } else if (message.type == 'dialogue') {
      return _buildDialogueBubble(message);
    } else {
      // 仅用户对话显示为绿色气泡
      return _buildUserBubble(message);
    }
  }

  /// 构建旁白气泡
  Widget _buildNarrationBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      child: Text(
        message.content,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          fontStyle: FontStyle.italic,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  /// 构建角色对话气泡
  Widget _buildDialogueBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 角色头像
          _buildCharacterAvatar(message.character!),
          const SizedBox(width: 8),

          // 对话气泡
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
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
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建角色头像
  Widget _buildCharacterAvatar(Character character) {
    return FutureBuilder<String?>(
      future: character.id != null
          ? _avatarService.getCharacterAvatarPath(character.id!)
          : Future.value(null),
      builder: (context, snapshot) {
        final avatarPath = snapshot.data;

        if (avatarPath != null && File(avatarPath).existsSync()) {
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: Image.file(
                File(avatarPath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallbackAvatar(character);
                },
              ),
            ),
          );
        }

        return _buildFallbackAvatar(character);
      },
    );
  }

  /// 构建备用头像（首字母）
  Widget _buildFallbackAvatar(Character character) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          character.name.isNotEmpty ? character.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
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
          valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  /// 构建输入区域
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 行为输入框
          TextField(
            controller: _actionController,
            decoration: InputDecoration(
              labelText: '行为（可选）',
              hintText: '例如：举起酒杯，微笑着说',
              border: OutlineInputBorder(
                borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: Theme.of(context).colorScheme.primary),
              ),
              labelStyle: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7)),
              hintStyle: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6)),
              contentPadding: EdgeInsets.all(12),
            ),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            maxLines: null,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}), // 触发重建更新按钮状态
          ),
          const SizedBox(height: 8),

          // 对话输入框
          TextField(
            controller: _speechController,
            decoration: InputDecoration(
              labelText: '对话（可选）',
              hintText: '例如：你好，最近怎么样？',
              border: OutlineInputBorder(
                borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: Theme.of(context).colorScheme.primary),
              ),
              labelStyle: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7)),
              hintStyle: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6)),
              contentPadding: EdgeInsets.all(12),
            ),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            maxLines: 3,
            minLines: 1,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _canSend() ? _sendMessage() : null,
            onChanged: (_) => setState(() {}), // 触发重建更新按钮状态
          ),
          const SizedBox(height: 8),

          // 发送按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSend() ? _sendMessage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                disabledBackgroundColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.12),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(_isGenerating ? '生成中...' : '发送'),
            ),
          ),
        ],
      ),
    );
  }
}
