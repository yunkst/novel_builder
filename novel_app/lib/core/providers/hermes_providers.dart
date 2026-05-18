import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/hermes_message.dart';
import '../../services/hermes_chat_service.dart';
import '../../services/hermes_sse_parser.dart';
import '../../services/preferences_service.dart';
import 'services/network_service_providers.dart';
import 'reading_context_providers.dart';

/// Hermes Chat Service Provider
final hermesChatServiceProvider = Provider<HermesChatService>((ref) {
  final apiService = ref.watch(apiServiceWrapperProvider);
  return HermesChatService(apiService: apiService);
});

/// Hermes Chat 状态
class HermesChatState {
  final List<HermesMessage> messages;
  final bool isLoading;
  final String? streamingContent;
  final List<ToolProgress> activeToolProgress;
  final String? error;
  final String? sessionId;

  const HermesChatState({
    this.messages = const [],
    this.isLoading = false,
    this.streamingContent,
    this.activeToolProgress = const [],
    this.error,
    this.sessionId,
  });

  HermesChatState copyWith({
    List<HermesMessage>? messages,
    bool? isLoading,
    String? streamingContent,
    List<ToolProgress>? activeToolProgress,
    String? error,
    String? sessionId,
  }) {
    return HermesChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      streamingContent: streamingContent,
      activeToolProgress: activeToolProgress ?? this.activeToolProgress,
      error: error,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

/// Hermes Chat Notifier
class HermesChatNotifier extends StateNotifier<HermesChatState> {
  final Ref _ref;
  String _pendingContent = '';
  static const _sessionIdKey = 'hermes_session_id';

  HermesChatNotifier(this._ref) : super(const HermesChatState()) {
    _loadSessionId();
  }

  Future<void> _loadSessionId() async {
    final saved = await PreferencesService.instance.getString(_sessionIdKey);
    if (saved.isNotEmpty) {
      state = state.copyWith(sessionId: saved);
    }
  }

  Future<String> _ensureSessionId() async {
    if (state.sessionId != null && state.sessionId!.isNotEmpty) {
      return state.sessionId!;
    }
    final id = _generateSessionId();
    state = state.copyWith(sessionId: id);
    await PreferencesService.instance.setString(_sessionIdKey, id);
    return id;
  }

  String _generateSessionId() {
    final rng = Random.secure();
    final timestamp = DateTime.now().toIso8601String().substring(0, 19).replaceAll(RegExp(r'[-:]'), '');
    final random = List.generate(8, (_) => rng.nextInt(16).toRadixString(16)).join();
    return 'hermes-${timestamp}_$random';
  }

  /// 发送消息
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final userMessage = HermesMessage.user(content.trim());
    final updatedMessages = [...state.messages, userMessage];

    // 读取阅读上下文，注入 system prompt
    final readingContext = _ref.read(readingContextProvider);
    final systemPrompt = readingContext.toSystemPrompt();

    // 构建消息 payload，有上下文时前置 system message
    List<Map<String, String>> messagesPayload;
    if (systemPrompt.isNotEmpty) {
      final systemMessage = HermesMessage.system(systemPrompt);
      messagesPayload = [
        systemMessage.toMap(),
        ...updatedMessages.map((m) => m.toMap()),
      ];
    } else {
      messagesPayload = updatedMessages.map((m) => m.toMap()).toList();
    }

    // 确保 session_id 存在
    final sessionId = await _ensureSessionId();

    // 清除之前的状态
    state = state.copyWith(
      messages: updatedMessages,
      isLoading: true,
      streamingContent: null,
      activeToolProgress: [],
      error: null,
    );

    _pendingContent = '';

    final service = _ref.read(hermesChatServiceProvider);

    await service.sendMessage(
      messages: messagesPayload,
      sessionId: sessionId,
      onContent: (chunk) {
        _pendingContent += chunk;
        state = state.copyWith(streamingContent: _pendingContent);
      },
      onToolProgress: (progress) {
        final updatedProgress = [...state.activeToolProgress, progress];
        state = state.copyWith(activeToolProgress: updatedProgress);
      },
      onDone: () {
        final assistantMessage = HermesMessage.assistant(_pendingContent);
        final finalMessages = [...state.messages, assistantMessage];
        state = state.copyWith(
          messages: finalMessages,
          isLoading: false,
          streamingContent: null,
          activeToolProgress: [],
        );
        _pendingContent = '';
      },
      onError: (error) {
        // 如果有部分内容，先保存
        if (_pendingContent.isNotEmpty) {
          final assistantMessage = HermesMessage.assistant(_pendingContent);
          final finalMessages = [...state.messages, assistantMessage];
          state = state.copyWith(
            messages: finalMessages,
            isLoading: false,
            streamingContent: null,
            error: error,
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            streamingContent: null,
            error: error,
          );
        }
        _pendingContent = '';
      },
    );
  }

  /// 清空会话（保留 sessionId）
  void clearConversation() {
    _pendingContent = '';
    state = HermesChatState(sessionId: state.sessionId);
  }
}

/// Hermes Chat Provider (keepAlive 保持全局状态)
final hermesChatProvider = StateNotifierProvider<HermesChatNotifier, HermesChatState>((ref) {
  return HermesChatNotifier(ref);
});
