/// ComfyUI 健康门控单元测试
///
/// 覆盖三件事：
/// 1. AgentTools.mediaTools 集合内容
/// 2. comfyuiHealthyProvider：healthy / unhealthy / 抛异常 三路径
/// 3. WritingScenario.tools 据健康状态过滤三个媒体工具（文生图 + 图生视频）
///
/// 运行：
///   cd novel_app
///   flutter test test/unit/services/novel_agent/comfyui_gating_test.dart
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:novel_app/core/providers/comfyui_health_provider.dart';
import 'package:novel_app/core/providers/services/network_service_providers.dart';
import 'package:novel_app/services/api_service_wrapper.dart';
import 'package:novel_app/services/novel_agent/agent_tools.dart';
import 'package:novel_app/services/novel_agent/scenarios/writing_scenario.dart';

// ──────────────────────────────────────────────────────────────────────
// Fake ApiServiceWrapper（仅重写健康检查 + init no-op）
// ──────────────────────────────────────────────────────────────────────

class _FakeApiServiceWrapper extends ApiServiceWrapper {
  _FakeApiServiceWrapper();

  (bool, String)? healthResult;
  Object? healthError;

  @override
  Future<void> init() async {} // no-op：跳过真实 host/Dio 配置

  @override
  Future<(bool, String)> checkComfyuiHealth() async {
    if (healthError != null) throw healthError!;
    return healthResult ?? (false, '');
  }

  // 以下方法本测试不使用，提供兜底
  @override
  Future<List<Map<String, dynamic>>> getText2ImgModels() async => [];
  @override
  Future<String> submitText2ImgTask({
    required String prompt,
    String? modelName,
    String? negativePrompt,
  }) async =>
      '';
  @override
  Future<(Uint8List?, int)> fetchText2ImgImage(String taskId) async =>
      (null, 0);
}

// 用本地 Provider 让 ProviderContainer 暴露带 Ref 的 WritingScenario
final _writingScenarioProvider =
    Provider<WritingScenario>((ref) => WritingScenario(ref));

Set<String> _toolNames(List<Map<String, dynamic>> tools) =>
    tools.map((t) => t['function']['name'] as String).toSet();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // =========================================================================
  // AgentTools.imageTools 常量
  // =========================================================================
  group('AgentTools.mediaTools 常量', () {
    test('包含三个媒体工具名（文生图 + 图生视频）', () {
      expect(AgentTools.mediaTools, contains('list_text2img_models'));
      expect(AgentTools.mediaTools, contains('create_images'));
      expect(AgentTools.mediaTools, contains('create_image_to_video'));
      expect(AgentTools.mediaTools.length, 3);
    });

    test('这三个工具确实在 allTools 中注册', () {
      final allNames = _toolNames(AgentTools.allTools);
      expect(allNames.containsAll(AgentTools.mediaTools), true,
          reason: 'mediaTools 集合必须是 allTools 的子集');
    });
  });

  // =========================================================================
  // comfyuiHealthyProvider
  // =========================================================================
  group('comfyuiHealthyProvider', () {
    test('checkComfyuiHealth 返回 healthy → true', () async {
      final fakeApi = _FakeApiServiceWrapper()..healthResult = (true, 'ok');
      final container = ProviderContainer(overrides: [
        apiServiceWrapperProvider.overrideWithValue(fakeApi),
      ]);
      addTearDown(container.dispose);

      expect(await container.read(comfyuiHealthyProvider.future), true);
    });

    test('checkComfyuiHealth 返回 unhealthy → false', () async {
      final fakeApi = _FakeApiServiceWrapper()
        ..healthResult = (false, 'comfyui down');
      final container = ProviderContainer(overrides: [
        apiServiceWrapperProvider.overrideWithValue(fakeApi),
      ]);
      addTearDown(container.dispose);

      expect(await container.read(comfyuiHealthyProvider.future), false);
    });

    test('checkComfyuiHealth 抛异常 → false（不向上抛）', () async {
      final fakeApi = _FakeApiServiceWrapper()
        ..healthError = Exception('network timeout');
      final container = ProviderContainer(overrides: [
        apiServiceWrapperProvider.overrideWithValue(fakeApi),
      ]);
      addTearDown(container.dispose);

      expect(await container.read(comfyuiHealthyProvider.future), false,
          reason: '探测异常应被吞掉，安全降级为 false');
    });

    test('keepAlive：同一 container 多次 read 只探测一次', () async {
      var probeCount = 0;
      final fakeApi = _FakeApiServiceWrapper()
        ..healthResult = (true, '');
      // 包装计数：通过子类拦截
      final countingApi = _CountingApi(fakeApi, () => probeCount++);

      final container = ProviderContainer(overrides: [
        apiServiceWrapperProvider.overrideWithValue(countingApi),
      ]);
      addTearDown(container.dispose);

      await container.read(comfyuiHealthyProvider.future);
      await container.read(comfyuiHealthyProvider.future);
      await container.read(comfyuiHealthyProvider.future);

      expect(probeCount, 1, reason: 'keepAlive Provider 应缓存结果只执行一次');
    });
  });

  // =========================================================================
  // WritingScenario.tools 健康过滤
  // =========================================================================
  group('WritingScenario.tools 健康过滤', () {
    test('healthy=true 时含三个媒体工具', () async {
      final container = ProviderContainer(overrides: [
        comfyuiHealthyProvider.overrideWith((ref) async => true),
      ]);
      addTearDown(container.dispose);

      await container.read(comfyuiHealthyProvider.future); // 等 provider 完成
      final scenario = container.read(_writingScenarioProvider);
      final names = _toolNames(scenario.tools);

      expect(names.contains('list_text2img_models'), true);
      expect(names.contains('create_images'), true);
      expect(names.contains('create_image_to_video'), true);
      // patch_memory 是 writing 场景专属，应始终存在
      expect(names.contains('patch_memory'), true);
      // 基础工具也未丢失
      expect(names.contains('list_novels'), true);
      expect(names.contains('create_chapter'), true);
    });

    test('healthy=false 时过滤掉三个媒体工具', () async {
      final container = ProviderContainer(overrides: [
        comfyuiHealthyProvider.overrideWith((ref) async => false),
      ]);
      addTearDown(container.dispose);

      await container.read(comfyuiHealthyProvider.future);
      final scenario = container.read(_writingScenarioProvider);
      final names = _toolNames(scenario.tools);

      expect(names.contains('list_text2img_models'), false,
          reason: 'ComfyUI 不健康时不应注入 list_text2img_models');
      expect(names.contains('create_images'), false,
          reason: 'ComfyUI 不健康时不应注入 create_images');
      expect(names.contains('create_image_to_video'), false,
          reason: 'ComfyUI 不健康时不应注入 create_image_to_video');
      // 基础工具不受影响
      expect(names.contains('list_novels'), true);
      expect(names.contains('create_chapter'), true);
      expect(names.contains('patch_memory'), true);
    });

    test('healthy=false 时 tools 数量 = allTools - 媒体工具数 + patch_memory', () async {
      final container = ProviderContainer(overrides: [
        comfyuiHealthyProvider.overrideWith((ref) async => false),
      ]);
      addTearDown(container.dispose);

      await container.read(comfyuiHealthyProvider.future);
      final scenario = container.read(_writingScenarioProvider);

      final expectedLen =
          AgentTools.allTools.length - AgentTools.mediaTools.length + 1;
      expect(scenario.tools.length, expectedLen,
          reason: '基础工具去掉媒体工具，再加 patch_memory');
    });

    test('healthy=true 时 tools 数量 = allTools + patch_memory', () async {
      final container = ProviderContainer(overrides: [
        comfyuiHealthyProvider.overrideWith((ref) async => true),
      ]);
      addTearDown(container.dispose);

      await container.read(comfyuiHealthyProvider.future);
      final scenario = container.read(_writingScenarioProvider);

      expect(scenario.tools.length, AgentTools.allTools.length + 1);
    });
  });
}

/// 包装一层用于统计 checkComfyuiHealth 调用次数
class _CountingApi extends ApiServiceWrapper {
  final _FakeApiServiceWrapper inner;
  final void Function() onProbe;

  _CountingApi(this.inner, this.onProbe);

  @override
  Future<void> init() async {}

  @override
  Future<(bool, String)> checkComfyuiHealth() async {
    onProbe();
    return inner.checkComfyuiHealth();
  }
}
