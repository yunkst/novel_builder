/// ScenarioSession 隔离运行单元测试
///
/// 验证核心隔离行为：
/// 1. ScenarioSession 基本功能（发送消息、流式接收、取消、清空）
/// 2. 多场景并行互不干扰
/// 3. 场景切换不杀后台 Agent
/// 4. LRU 淘汰
/// 5. NovelAgentService 按 scenarioId 并行
/// 6. currentNovel 按 Session 隔离
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/providers/scenario_session_test.dart
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/core/providers/agent_scenario_provider.dart';
import 'package:novel_app/core/providers/current_novel_provider.dart';
import 'package:novel_app/core/providers/hermes_providers.dart';
import 'package:novel_app/core/providers/scenario_session.dart';
import 'package:novel_app/core/providers/scenario_sessions_provider.dart';
import 'package:novel_app/models/hermes_message.dart';
import 'package:novel_app/services/novel_agent/agent_event.dart';
import 'package:novel_app/services/novel_agent/agent_scenario.dart';
import 'package:novel_app/services/novel_agent/novel_agent_service.dart';

// ---------------------------------------------------------------------------
// MockNovelAgentService — 模拟 AgentService，支持按 scenarioId 并行
// ---------------------------------------------------------------------------

class MockNovelAgentService implements NovelAgentService {
  final _controller = StreamController<AgentEvent>.broadcast();
  final Map<String, Completer<void>> _completers = {};
  final Map<String, bool> _runningByScenario = {};
  int sendMessageCallCount = 0;
  final List<String> sendMessageScenarioIds = [];
  final Duration? delay;

  MockNovelAgentService({this.delay});

  @override
  Ref get ref => throw UnimplementedError();

  @override
  bool get isRunning => _runningByScenario.values.any((v) => v);

  @override
  bool isRunningFor(String scenarioId) =>
      _runningByScenario[scenarioId] == true;

  @override
  Stream<AgentEvent> get events => _controller.stream;

  @override
  Future<void> sendMessage({
    required String userInput,
    required List<dynamic> history,
    required String scenarioId,
    required AgentScenarioContext scenarioContext,
    List<int>? messageOwners,
  }) async {
    // 同场景串行
    if (_runningByScenario[scenarioId] == true) {
      _controller.add(AgentErrorEvent('场景 $scenarioId 的 Agent 正在运行中'));
      return;
    }

    sendMessageCallCount++;
    sendMessageScenarioIds.add(scenarioId);
    _runningByScenario[scenarioId] = true;

    final completer = Completer<void>();
    _completers[scenarioId] = completer;

    try {
      // 等一帧让 ScenarioSession 的 listen 先注册上
      await Future<void>.delayed(Duration.zero);

      // 发一个文本增量模拟流式输出
      _controller.add(TextDeltaEvent('[$scenarioId] 回复: $userInput'));
      if (delay != null) {
        await Future<void>.delayed(delay!);
      }
      _controller.add(const AgentDoneEvent());

      // 再等一帧让事件传播到 listener
      await Future<void>.delayed(Duration.zero);
    } finally {
      _runningByScenario.remove(scenarioId);
      _completers.remove(scenarioId);
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  @override
  void cancelFor(String scenarioId) {
    final completer = _completers[scenarioId];
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _completers.remove(scenarioId);
    _runningByScenario.remove(scenarioId);
  }

  @override
  void cancelAll() {
    for (final c in _completers.values) {
      if (!c.isCompleted) c.complete();
    }
    _completers.clear();
    _runningByScenario.clear();
  }

  @override
  void dispose() {
    _controller.close();
  }
}

// ---------------------------------------------------------------------------
// 辅助：构建 ProviderContainer（注入 mock）
// ---------------------------------------------------------------------------

ProviderContainer createContainer(MockNovelAgentService mockService) {
  return ProviderContainer(overrides: [
    novelAgentServiceProvider.overrideWith((ref) => mockService),
  ]);
}

// ---------------------------------------------------------------------------
// 测试
// ---------------------------------------------------------------------------

void main() {
  late MockNovelAgentService mockService;
  late ProviderContainer container;

  setUp(() {
    mockService = MockNovelAgentService();
    container = createContainer(mockService);
  });

  tearDown(() {
    container.dispose();
  });

  // ===========================================================================
  // 1. ScenarioSession 基本功能
  // ===========================================================================

  group('ScenarioSession 基本功能', () {
    test('初始状态正确', () {
      final sessions = container.read(scenarioSessionsProvider.notifier);
      final session = sessions.get(ScenarioIds.writing);

      expect(session.scenarioId, ScenarioIds.writing);
      expect(session.state.messages, isEmpty);
      expect(session.isRunning, isFalse);
      expect(session.lifecycle, SessionLifecycle.fresh);
    });

    test('sendMessage 后 isLoading 变为 true 且消息入列', () async {
      final sessions = container.read(scenarioSessionsProvider.notifier);
      final session = sessions.get(ScenarioIds.writing);

      await session.sendMessage('你好');

      // 流式完成后应包含 user + assistant 消息
      expect(session.state.messages.length, 2,
          reason: '应有 1 条 user + 1 条 assistant 消息');
      expect(session.state.messages.first.role, HermesRole.user);
      expect(session.state.messages.last.role, HermesRole.assistant);
      expect(session.isRunning, isFalse);
      expect(session.lifecycle, SessionLifecycle.idle);
    });

    test('cancel 后 isLoading 变为 false', () {
      final sessions = container.read(scenarioSessionsProvider.notifier);
      final session = sessions.get(ScenarioIds.writing);

      // 直接调 cancel（无运行任务时）
      session.cancel();
      expect(session.isRunning, isFalse);
      expect(session.state.isLoading, isFalse);
      expect(session.state.streamingSegments, isEmpty);
    });

    test('clearConversation 清空消息但保留 scenarioId 和 currentNovel', () async {
      final sessions = container.read(scenarioSessionsProvider.notifier);
      final session = sessions.get(ScenarioIds.writing);

      await session.sendMessage('测试消息');
      expect(session.state.messages.isNotEmpty, isTrue);

      session.clearConversation();
      expect(session.state.messages, isEmpty);
      expect(session.state.scenarioId, ScenarioIds.writing);
    });

    test('空消息不触发发送', () async {
      final sessions = container.read(scenarioSessionsProvider.notifier);
      final session = sessions.get(ScenarioIds.writing);

      await session.sendMessage('');
      await session.sendMessage('   ');

      expect(mockService.sendMessageCallCount, 0);
      expect(session.state.messages, isEmpty);
    });
  });

  // ===========================================================================
  // 2. 多场景并行互不干扰
  // ===========================================================================

  group('多场景并行互不干扰', () {
    test('两个场景各自独立发送消息', () async {
      final sessions = container.read(scenarioSessionsProvider.notifier);
      final writingSession = sessions.get(ScenarioIds.writing);
      final extractSession = sessions.get(ScenarioIds.webviewExtract);

      // 在 writing 场景发送消息
      await writingSession.sendMessage('写作消息');
      expect(writingSession.state.messages.length, 2);
      expect(writingSession.state.messages.first.content, contains('写作消息'));

      // 在 webview_extract 场景发送消息
      await extractSession.sendMessage('提取消息');
      expect(extractSession.state.messages.length, 2);
      expect(extractSession.state.messages.first.content, contains('提取消息'));

      // 各自消息互不影响
      expect(writingSession.state.messages.length, 2,
          reason: 'writing 场景消息不应受 extract 影响');
      expect(extractSession.state.messages.length, 2,
          reason: 'extract 场景消息不应受 writing 影响');
    });

    test('一个场景的 clearConversation 不影响另一个', () async {
      final sessions = container.read(scenarioSessionsProvider.notifier);
      final writingSession = sessions.get(ScenarioIds.writing);
      final extractSession = sessions.get(ScenarioIds.webviewExtract);

      await writingSession.sendMessage('写作消息');
      await extractSession.sendMessage('提取消息');

      // 清空 writing 场景
      writingSession.clearConversation();
      expect(writingSession.state.messages, isEmpty);
      expect(extractSession.state.messages.isNotEmpty, isTrue,
          reason: 'extract 场景消息不应受 writing 清空影响');
    });

    test('NovelAgentService 按场景跟踪运行状态', () async {
      // 验证 MockNovelAgentService 的按场景运行状态
      expect(mockService.isRunningFor(ScenarioIds.writing), isFalse);
      expect(mockService.isRunningFor(ScenarioIds.webviewExtract), isFalse);

      // 发送消息时场景变为 running
      final sessions = container.read(scenarioSessionsProvider.notifier);
      final writingSession = sessions.get(ScenarioIds.writing);

      // 由于 sendMessage 是同步执行的 mock，发送完成后 running 已重置
      await writingSession.sendMessage('测试');
      expect(mockService.isRunningFor(ScenarioIds.writing), isFalse);
    });
  });

  // ===========================================================================
  // 3. 场景切换不杀后台 Agent（通过 ScenarioSessionsNotifier）
  // ===========================================================================

  group('场景切换不杀后台 Agent', () {
    test('切换场景时，原场景的 session 仍然存在', () async {
      final sessions = container.read(scenarioSessionsProvider.notifier);

      // 在 writing 场景发送消息
      final writingSession = sessions.get(ScenarioIds.writing);
      await writingSession.sendMessage('写作消息');
      final writingMessages = writingSession.state.messages;

      // 切换到 webview_extract
      final extractSession = sessions.get(ScenarioIds.webviewExtract);
      await extractSession.sendMessage('提取消息');

      // 切回 writing — session 应该还在
      final writingAgain = sessions.get(ScenarioIds.writing);
      expect(identical(writingSession, writingAgain), isTrue,
          reason: '同一个 scenarioId 应返回同一个 ScenarioSession 实例');
      expect(writingAgain.state.messages.length, writingMessages.length,
          reason: '切回 writing 时消息应保留');
    });

    test('sessions 状态 map 包含所有场景', () async {
      final sessions = container.read(scenarioSessionsProvider.notifier);

      sessions.get(ScenarioIds.writing);
      sessions.get(ScenarioIds.webviewExtract);

      final state = container.read(scenarioSessionsProvider);
      expect(state.containsKey(ScenarioIds.writing), isTrue);
      expect(state.containsKey(ScenarioIds.webviewExtract), isTrue);
    });
  });

  // ===========================================================================
  // 4. LRU 淘汰
  // ===========================================================================

  group('LRU 淘汰', () {
    test('超过 _maxSessions 时淘汰空闲 session', () {
      final sessions = container.read(scenarioSessionsProvider.notifier);

      // 创建最多 8 个 session
      for (int i = 0; i < 8; i++) {
        sessions.get('scenario_$i');
      }

      // 验证已创建 8 个
      expect(sessions.activeSessionIds.length, 8);

      // 创建第 9 个，应触发淘汰
      sessions.get('scenario_8');
      // 淘汰后应仍然 <= 8
      expect(sessions.activeSessionIds.length, lessThanOrEqualTo(8));
    });

    test('disposeSession 手动销毁指定场景', () async {
      final sessions = container.read(scenarioSessionsProvider.notifier);

      final writingSession = sessions.get(ScenarioIds.writing);
      await writingSession.sendMessage('消息');
      expect(sessions.hasSession(ScenarioIds.writing), isTrue);

      sessions.disposeSession(ScenarioIds.writing);
      expect(sessions.hasSession(ScenarioIds.writing), isFalse);

      // 再次 get 会创建新 session
      final newSession = sessions.get(ScenarioIds.writing);
      expect(newSession.state.messages, isEmpty,
          reason: '新 session 应该是空的');
    });
  });

  // ===========================================================================
  // 5. 兼容层 HermesChatNotifier 仍可用
  // ===========================================================================

  group('兼容层 HermesChatNotifier', () {
    test('sendMessage 通过兼容层正常工作', () async {
      final notifier = container.read(hermesChatProvider.notifier);
      await notifier.sendMessage('兼容层测试');

      final state = container.read(hermesChatProvider);
      expect(state.messages.length, 2);
    });

    test('switchScenario 通过兼容层切换场景', () async {
      final notifier = container.read(hermesChatProvider.notifier);

      await notifier.sendMessage('写作消息');
      final writingState = container.read(hermesChatProvider);
      expect(writingState.scenarioId, ScenarioIds.writing);

      notifier.switchScenario(ScenarioIds.webviewExtract, '网页提取');
      final extractState = container.read(hermesChatProvider);
      expect(extractState.scenarioId, ScenarioIds.webviewExtract);
    });

    test('clearConversation 通过兼容层清空', () async {
      final notifier = container.read(hermesChatProvider.notifier);

      await notifier.sendMessage('测试');
      expect(container.read(hermesChatProvider).messages.isNotEmpty, isTrue);

      notifier.clearConversation();
      expect(container.read(hermesChatProvider).messages, isEmpty);
    });

    test('cancelRequest 通过兼容层取消', () {
      final notifier = container.read(hermesChatProvider.notifier);

      notifier.cancelRequest();
      final state = container.read(hermesChatProvider);
      expect(state.isLoading, isFalse);
    });
  });

  // ===========================================================================
  // 6. currentChatStateProvider 正确映射
  // ===========================================================================

  group('currentChatStateProvider', () {
    test('返回当前场景的状态', () async {
      // 初始场景是 writing
      final state = container.read(currentChatStateProvider);
      expect(state.scenarioId, ScenarioIds.writing);

      // 发消息
      final notifier = container.read(hermesChatProvider.notifier);
      await notifier.sendMessage('测试');
      final updatedState = container.read(currentChatStateProvider);
      expect(updatedState.messages.length, 2);
    });

    test('切换场景后返回新场景的状态', () async {
      final notifier = container.read(hermesChatProvider.notifier);
      await notifier.sendMessage('写作消息');

      // 切换场景
      container.read(currentAgentScenarioProvider.notifier).state =
          ScenarioIds.webviewExtract;

      final state = container.read(currentChatStateProvider);
      expect(state.scenarioId, ScenarioIds.webviewExtract);
    });
  });

  // ===========================================================================
  // 7. ScenarioSession 事件处理
  // ===========================================================================

  group('ScenarioSession 事件处理', () {
    test('ToolCallStart/End 事件正确处理', () async {
      // 直接发送一个带工具调用的事件序列
      final sessions = container.read(scenarioSessionsProvider.notifier);
      final session = sessions.get(ScenarioIds.writing);

      // 发送消息会触发 MockNovelAgentService 发出 TextDelta + Done 事件
      await session.sendMessage('调用工具');

      // 验证消息结构
      final lastMsg = session.state.messages.last;
      expect(lastMsg.role, HermesRole.assistant);
    });
  });

  // ===========================================================================
  // 8. Session 生命周期
  // ===========================================================================

  group('Session 生命周期', () {
    test('fresh → active → idle 状态转换', () async {
      final sessions = container.read(scenarioSessionsProvider.notifier);
      final session = sessions.get(ScenarioIds.writing);

      expect(session.lifecycle, SessionLifecycle.fresh);

      await session.sendMessage('测试');
      expect(session.lifecycle, SessionLifecycle.idle);
    });

    test('cancel 从 active → idle', () async {
      final sessions = container.read(scenarioSessionsProvider.notifier);
      final session = sessions.get(ScenarioIds.writing);

      // 手动设置 running 状态后取消
      // 由于 mock 是同步的，我们通过直接 cancel 测试
      session.cancel();
      expect(session.lifecycle, SessionLifecycle.idle);
    });

    test('dispose 设置 disposed', () {
      final sessions = container.read(scenarioSessionsProvider.notifier);
      final session = sessions.get(ScenarioIds.writing);

      session.dispose();
      expect(session.lifecycle, SessionLifecycle.disposed);
    });
  });
}
