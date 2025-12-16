import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/src/byte_stream.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 模拟的 HTTP 相关类
class MockHttpClient extends Mock implements http.Client {}

class MockStreamedResponse extends Mock implements http.StreamedResponse {}

class MockStreamSubscription<T> extends Mock implements StreamSubscription<T> {}

class MockStreamController<T> extends Mock implements StreamController<T> {}

class MockRequest extends Mock implements http.Request {}

// 模拟的 SharedPreferences
class MockSharedPreferences extends Mock implements SharedPreferences {
  final Map<String, dynamic> _data = {};

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  bool containsKey(String key) => _data.containsKey(key);

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _data.clear();
    return true;
  }

  @override
  Future<void> reload() async {}

  // 其他必需方法的默认实现
  @override
  dynamic get(String key) => _data[key];

  @override
  bool? getBool(String key) => _data[key] as bool?;

  @override
  int? getInt(String key) => _data[key] as int?;

  @override
  double? getDouble(String key) => _data[key] as double?;

  @override
  List<String>? getStringList(String key) => _data[key] as List<String>?;

  @override
  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _data[key] = value;
    return true;
  }

  @override
  Set<String> getKeys() => _data.keys.toSet();
}

// 模拟的 SSE 相关数据
class MockSSEData {
  /// 创建模拟的 SSE 流响应
  static http.StreamedResponse createMockStreamedResponse({
    int statusCode = 200,
    List<String> chunks = const [],
    bool includeError = false,
  }) {
    final response = MockStreamedResponse();

    when(() => response.statusCode).thenReturn(statusCode);

    if (includeError) {
      when(() => response.stream)
          .thenAnswer((_) => ByteStream(Stream.error('Network error')));
    } else {
      when(() => response.stream)
          .thenAnswer((_) => ByteStream(_createMockSSEStream(chunks)));
    }

    return response;
  }

  /// 创建模拟的 SSE 数据流
  static Stream<List<int>> _createMockSSEStream(List<String> chunks) {
    final controller = StreamController<List<int>>();

    // 添加 SSE 头部
    controller.add(utf8.encode('HTTP/1.1 200 OK\nContent-Type: text/event-stream\n\n'));

    for (final chunk in chunks) {
      // 模拟 SSE 格式
      final sseData = 'data: ${jsonEncode({"text": chunk})}\n\n';
      controller.add(utf8.encode(sseData));

      // 模拟网络延迟
      Future.delayed(const Duration(milliseconds: 10), () {
        if (!controller.isClosed) {
          final sseData = 'data: ${jsonEncode({"event": "text_chunk", "data": {"text": chunk}})}\n\n';
          controller.add(utf8.encode(sseData));
        }
      });
    }

    // 添加完成事件
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!controller.isClosed) {
        final completeEvent = 'data: ${jsonEncode({"event": "workflow_finished", "data": {}})}\n\n';
        controller.add(utf8.encode(completeEvent));
        controller.close();
      }
    });

    return controller.stream;
  }

  /// 创建错误流
  static Stream<List<int>> createErrorStream(String errorMessage) {
    final controller = StreamController<List<int>>();

    Future.delayed(const Duration(milliseconds: 10), () {
      controller.addError(errorMessage);
      controller.close();
    });

    return controller.stream;
  }

  /// 创建超时流
  static Stream<List<int>> createTimeoutStream() {
    final controller = StreamController<List<int>>();

    // 故意不关闭流，模拟超时
    return controller.stream;
  }
}

// 测试数据工厂
class TestDataFactory {
  /// 创建测试用的 StreamConfig
  static Map<String, dynamic> createTestStreamConfig({
    StreamType type = StreamType.sceneDescription,
    Map<String, dynamic>? inputs,
    bool showRealTime = true,
    bool autoScroll = true,
  }) {
    return {
      'type': type,
      'inputs': inputs ?? {'test_content': 'Hello World'},
      'showRealTime': showRealTime,
      'autoScroll': autoScroll,
      'disableEditWhileGenerating': true,
      'generatingHint': 'AI正在生成内容，请稍候...',
      'maxLines': 4,
      'minLines': 2,
    };
  }

  /// 创建测试用的配置参数
  static Map<String, String> createTestInputs({
    String content = '测试内容',
    String cmd = '场景描写',
    Map<String, String>? additionalParams,
  }) {
    final baseInputs = <String, String>{
      'user_input': content,
      'cmd': cmd,
      'current_chapter_content': content,
      'choice_content': '',
      'ai_writer_setting': '',
      'background_setting': '测试背景',
      'next_chapter_overview': '',
      'characters_info': '',
    };

    if (additionalParams != null) {
      baseInputs.addAll(additionalParams);
    }

    return baseInputs;
  }

  /// 创建测试用的流数据块
  static List<String> createTestChunks({
    List<String>? customChunks,
  }) {
    return customChunks ?? [
      '这是',
      '一个',
      '测试',
      '流式',
      '内容',
      '生成',
      '示例'
    ];
  }

  /// 创建完整的预期结果
  static String createExpectedResult(List<String> chunks) {
    return chunks.join('');
  }
}

// 流类型枚举（从实际代码中复制）
enum StreamType {
  closeUp,
  sceneDescription,
  custom,
}

// 测试工具类
class TestUtils {
  /// 等待异步操作完成
  static Future<void> waitForAsync([Duration? duration]) {
    return Future.delayed(duration ?? const Duration(milliseconds: 100));
  }

  /// 等待多个异步操作完成
  static Future<void> waitForMultipleAsync(int count) {
    return Future.delayed(Duration(milliseconds: count * 50));
  }

  /// 验证 Stream 是否被正确取消
  static bool isStreamCancelled(StreamSubscription? subscription) {
    return subscription == null || subscription.isPaused;
  }

  /// 创建测试用的 Completer
  static Completer<T> createCompleter<T>() {
    return Completer<T>();
  }

  /// 模拟网络延迟
  static Future<void> simulateNetworkDelay() {
    return Future.delayed(const Duration(milliseconds: 50));
  }

  /// 验证错误消息格式
  static bool isValidErrorMessage(String error) {
    return error.isNotEmpty && error.length > 5;
  }
}

/// 设置全局的 mocktail 回退行为
void setupMocktailFallbacks() {
  // 为所有未mock的方法提供默认行为
  registerFallbackValue(Uri());
  registerFallbackValue(http.Request('POST', Uri()));
  registerFallbackValue(StreamController<String>());
  registerFallbackValue(const Duration(milliseconds: 100));
}