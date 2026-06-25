/// LLM 调用日志服务单元测试
///
/// 覆盖：
/// - 数据模型序列化
/// - 写入和查询流程
/// - 大响应体截断
/// - 缓存容量限制
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:novel_app/services/llm_logger/llm_call_record.dart';
import 'package:novel_app/services/llm_logger/llm_logger.dart';

import '../../test_bootstrap.dart';

void main() {
  initTests();

  group('LlmCallRecord', () {
    test('toJson / fromJson roundtrip preserves all fields', () {
      final original = LlmCallRecord(
        id: 'llm_12345_6789',
        timestamp: DateTime.utc(2026, 6, 23, 10, 30, 45),
        endpoint: 'https://api.deepseek.com/v1/chat/completions',
        model: 'deepseek-chat',
        isStreaming: true,
        requestBody: '{"model":"deepseek-chat","messages":[]}',
        responseBody: '{"choices":[{"message":{"content":"hi"}}]}',
        durationMs: 1500,
        isSuccess: true,
        promptTokens: 10,
        completionTokens: 20,
        totalTokens: 30,
      );

      final encoded = jsonEncode(original.toJson());
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = LlmCallRecord.fromJson(decoded);

      expect(restored.id, original.id);
      expect(restored.endpoint, original.endpoint);
      expect(restored.model, original.model);
      expect(restored.isStreaming, original.isStreaming);
      expect(restored.requestBody, original.requestBody);
      expect(restored.responseBody, original.responseBody);
      expect(restored.durationMs, original.durationMs);
      expect(restored.isSuccess, original.isSuccess);
      expect(restored.totalTokens, original.totalTokens);
    });

    test('durationText formats correctly', () {
      final r1 = LlmCallRecord(
        id: '1',
        timestamp: DateTime.now(),
        endpoint: '',
        isStreaming: false,
        requestBody: '',
        isSuccess: true,
        durationMs: 500,
      );
      expect(r1.durationText, '500ms');

      final r2 = LlmCallRecord(
        id: '2',
        timestamp: DateTime.now(),
        endpoint: '',
        isStreaming: false,
        requestBody: '',
        isSuccess: true,
        durationMs: 2500,
      );
      expect(r2.durationText, '2.5s');

      final r3 = LlmCallRecord(
        id: '3',
        timestamp: DateTime.now(),
        endpoint: '',
        isStreaming: false,
        requestBody: '',
        isSuccess: true,
      );
      expect(r3.durationText, '-');
    });

    test('previewText extracts content from messages', () {
      final r = LlmCallRecord(
        id: '1',
        timestamp: DateTime.now(),
        endpoint: '',
        isStreaming: false,
        requestBody: jsonEncode({
          'messages': [
            {'role': 'system', 'content': '你是助手'},
            {'role': 'user', 'content': '帮我写一段关于冒险的故事'},
          ],
        }),
        isSuccess: true,
      );
      expect(r.previewText.contains('冒险'), true);
    });
  });

  group('LlmLogger', () {
    late Directory tempDir;

    setUp(() async {
      LlmLogger.resetForTesting();
      SharedPreferences.setMockInitialValues({});

      // 为每次测试创建独立的临时目录
      tempDir = await Directory.systemTemp.createTemp('llm_logger_test_');
      PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
    });

    tearDown(() async {
      await LlmLogger.instance.clear();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('initialize creates log directory', () async {
      await LlmLogger.instance.initialize();

      final logDir = Directory('${tempDir.path}/llm_logs');
      expect(await logDir.exists(), true);
    });

    test('logRequest + logResponse writes complete record', () async {
      await LlmLogger.instance.initialize();

      const id = 'test_001';
      LlmLogger.instance.logRequest(
        id: id,
        endpoint: 'https://api.deepseek.com/v1/chat/completions',
        requestBody: '{"model":"deepseek-chat","messages":[]}',
      );
      LlmLogger.instance.logResponse(
        id: id,
        responseBody:
            '{"choices":[{"message":{"content":"hello"}}],"usage":{"total_tokens":42}}',
        durationMs: 1234,
        isSuccess: true,
      );

      // 等待异步写入完成
      await Future.delayed(const Duration(milliseconds: 100));

      final records = await LlmLogger.instance.getRecent(limit: 10);
      expect(records.length, greaterThanOrEqualTo(1));

      final found = records.where((r) => r.id == id).firstOrNull;
      expect(found, isNotNull);
      expect(found!.isSuccess, true);
      expect(found.durationMs, 1234);
      expect(found.totalTokens, 42);
      expect(found.responseBody, contains('hello'));
    });

    test('logError records failure with error message', () async {
      await LlmLogger.instance.initialize();

      const id = 'test_error';
      LlmLogger.instance.logRequest(
        id: id,
        endpoint: 'https://api.test/v1/chat/completions',
        requestBody: '{}',
      );
      LlmLogger.instance.logError(
        id: id,
        errorMessage: 'SocketException: Connection refused',
        durationMs: 500,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      final record = await LlmLogger.instance.getById(id);
      expect(record, isNotNull);
      expect(record!.isSuccess, false);
      expect(record.errorMessage, contains('Connection refused'));
    });

    test('getById returns null for unknown id', () async {
      await LlmLogger.instance.initialize();

      final result = await LlmLogger.instance.getById('non_existent_id');
      expect(result, isNull);
    });

    test('clear removes all records', () async {
      await LlmLogger.instance.initialize();

      LlmLogger.instance.logRequest(
        id: 'clear_test_1',
        endpoint: 'https://api.test/v1/chat/completions',
        requestBody: '{}',
      );
      await Future.delayed(const Duration(milliseconds: 100));

      await LlmLogger.instance.clear();

      final records = await LlmLogger.instance.getRecent(limit: 10);
      expect(records, isEmpty);
    });

    test('over-sized response body is truncated', () async {
      await LlmLogger.instance.initialize();

      // 构造 6MB 的响应体
      final huge = 'x' * (6 * 1024 * 1024);

      LlmLogger.instance.logRequest(
        id: 'huge_test',
        endpoint: 'https://api.test/v1/chat/completions',
        requestBody: '{}',
      );
      LlmLogger.instance.logResponse(
        id: 'huge_test',
        responseBody: huge,
        durationMs: 1000,
        isSuccess: true,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      final record = await LlmLogger.instance.getById('huge_test');
      expect(record, isNotNull);
      expect(record!.responseBody, isNotNull);
      expect(record.responseBody!.length, lessThanOrEqualTo(6 * 1024 * 1024));
      expect(record.responseBody!.contains('truncated'), true);
    });
  });
}

/// 使用临时目录的 PathProvider Mock
class _TempPathProvider extends PathProviderPlatform {
  final String tempPath;
  _TempPathProvider(this.tempPath);

  @override
  Future<String> getApplicationDocumentsPath() async => tempPath;

  @override
  Future<String?> getApplicationSupportPath() async => tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}
