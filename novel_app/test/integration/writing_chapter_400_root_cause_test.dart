// =============================================================================
// 章节生成 400 诊断集成测试
//
// 背景：
//   生产日志 (2026-06-18 22:56:21) 出现 "LLM HTTP 错误: 400"，UI 卡在 loading。
//   历史日志中有两条关键线索：
//     - 15:17:39  model=deepseem-v4-pro (拼写错误), baseUrl=https://api.deepseek.com (官方, 缺 /v1)
//     - 22:56:21  LLM HTTP 错误: 400 (无调用入口日志, 走了不同的路径)
//
// 本测试用真实 API 对每个模型名 × 端点组合做实测，输出诊断矩阵，
// 明确哪个组合能工作、哪个触发错误，以及错误响应体的具体内容。
//
// 运行方式（key 不会进 git）：
//   cd novel_app
//   flutter test test/integration/writing_chapter_400_root_cause_test.dart \
//     --dart-define=TEST_API_BASE_URL=https://new-api.c2h4.cn/v1 \
//     --dart-define="TEST_API_KEY=sk-xxx"
//
// 也可指向 DeepSeek 官方测试：
//   --dart-define=TEST_API_BASE_URL=https://api.deepseek.com/v1 \
// =============================================================================
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:novel_app/services/ai/writing_service.dart';
import 'package:novel_app/services/dsl_engine/llm_provider.dart';

// ---- 配置（来自 --dart-define）----

const apiBaseUrl = String.fromEnvironment('TEST_API_BASE_URL');
const apiKey = String.fromEnvironment('TEST_API_KEY');

/// 项目内置的默认模型名（与 AiModelParams.model 保持一致）
const bundledDefaultModel = 'deepseek-v4-pro';

/// 15:17 日志中出现的拼写错误模型名
const typoModel = 'deepseem-v4-pro';

/// DeepSeek 官方模型
const officialModel = 'deepseek-chat';

/// 待测试的模型名列表
const testModels = [bundledDefaultModel, typoModel, officialModel];

// ---- 捕获 HTTP 响应的 HttpClient ----

class CapturingHttpClient implements LlmHttpClient {
  final http.Client _client = http.Client();
  int? lastStatusCode;
  String? lastResponseBody;
  String? lastUrl;

  @override
  Future<String> postJson(
      String url, Map<String, String> headers, String body) async {
    final response =
        await _client.post(Uri.parse(url), headers: headers, body: body);
    lastUrl = url;
    lastStatusCode = response.statusCode;
    lastResponseBody = response.body;
    if (response.statusCode >= 400) {
      throw _LlmHttpException(response.statusCode, response.body, url);
    }
    return response.body;
  }

  @override
  Stream<String> postJsonStream(
      String url, Map<String, String> headers, String body) async* {
    final request = http.Request('POST', Uri.parse(url));
    request.headers.addAll(headers);
    request.body = body;
    final streamed = await _client.send(request);
    lastUrl = url;
    lastStatusCode = streamed.statusCode;
    if (streamed.statusCode >= 400) {
      final errBody = await streamed.stream.bytesToString();
      lastResponseBody = errBody;
      throw _LlmHttpException(streamed.statusCode, errBody, url);
    }
    yield* streamed.stream.transform(utf8.decoder);
  }
}

class _LlmHttpException implements Exception {
  final int statusCode;
  final String body;
  final String url;
  _LlmHttpException(this.statusCode, this.body, this.url);
  @override
  String toString() => 'LLM HTTP $statusCode @ $url\n$body';
}

// ---- 探测结果 ----

class ProbeResult {
  final String model;
  final int? statusCode;
  final String? errorBody;
  final int chunkCount;
  final String contentPreview;
  final bool succeeded;

  ProbeResult({
    required this.model,
    this.statusCode,
    this.errorBody,
    this.chunkCount = 0,
    this.contentPreview = '',
    this.succeeded = false,
  });
}

// =============================================================================

void main() {
  final bool configured = apiBaseUrl.isNotEmpty && apiKey.isNotEmpty;

  /// 用指定模型名调用 WritingService.createChapter，返回探测结果
  Future<ProbeResult> probeModel(String model) async {
    final capturingHttp = CapturingHttpClient();
    final provider = LlmProvider(
      LlmConfig(baseUrl: apiBaseUrl, apiKey: apiKey, defaultModel: model),
      httpClient: capturingHttp,
    );
    final service = WritingService(provider: provider, defaultModel: model);

    final chunks = <String>[];
    Object? caughtError;

    try {
      await for (final chunk in service.createChapter(
        aiWriterSetting: '文风：轻松幽默',
        backgroundSetting: '修仙世界背景',
        historyChaptersContent: '',
        roles: '主角：林墨',
        nextChapterOverview: '主角初入宗门',
        userInput: '写第一章的开头',
      )) {
        chunks.add(chunk);
      }
    } catch (e) {
      caughtError = e;
    }

    final full = chunks.join();
    final isHttpError = caughtError is _LlmHttpException;

    return ProbeResult(
      model: model,
      statusCode: capturingHttp.lastStatusCode,
      errorBody: isHttpError ? (caughtError as _LlmHttpException).body : null,
      chunkCount: chunks.length,
      contentPreview: full.length > 100 ? '${full.substring(0, 100)}...' : full,
      succeeded: chunks.isNotEmpty && !isHttpError,
    );
  }

  group('章节生成 — 模型名 × 端点诊断矩阵', () {
    test('探测所有模型名，输出诊断报告', () async {
      if (!configured) {
        print('⚠️ 未配置 TEST_API_KEY / TEST_API_BASE_URL，跳过测试');
        return;
      }

      print('\n${"=" * 70}');
      print('端点: $apiBaseUrl');
      print('探测模型: ${testModels.join(", ")}');
      print('${"=" * 70}\n');

      final results = <ProbeResult>[];
      for (final model in testModels) {
        print('→ 探测模型: $model ...');
        final result = await probeModel(model);
        results.add(result);

        if (result.succeeded) {
          print('  ✅ 成功 | 状态码: ${result.statusCode} | '
              'chunk: ${result.chunkCount} | '
              '字符: ${result.contentPreview.length}');
        } else {
          print('  ❌ 失败 | 状态码: ${result.statusCode}');
          // 解析错误体中的关键信息
          if (result.errorBody != null) {
            try {
              final errJson = jsonDecode(result.errorBody!) as Map<String, dynamic>;
              final err = errJson['error'] as Map<String, dynamic>?;
              final message = err?['message'] ?? result.errorBody;
              final code = err?['code'] ?? '';
              print('  错误消息: $message');
              print('  错误代码: $code');
            } catch (_) {
              print('  原始响应: ${result.errorBody}');
            }
          }
        }
        print('');
      }

      // ---- 诊断报告 ----
      print('\n${"=" * 70}');
      print('📊 诊断报告');
      print('${"=" * 70}');
      print('');

      // 表格输出
      print('| 模型名 | 状态码 | 结果 | 备注 |');
      print('|--------|--------|------|------|');
      for (final r in results) {
        final status = r.statusCode?.toString() ?? 'N/A';
        final icon = r.succeeded ? '✅' : '❌';
        String note;
        if (r.succeeded) {
          note = 'chunk=${r.chunkCount}';
        } else if (r.errorBody != null) {
          try {
            final errJson = jsonDecode(r.errorBody!) as Map<String, dynamic>;
            final msg = (errJson['error'] as Map<String, dynamic>?)?['message'] ?? '';
            note = msg.length > 40 ? '${msg.substring(0, 40)}...' : msg;
          } catch (_) {
            note = '解析失败';
          }
        } else {
          note = '未知错误';
        }
        print('| ${r.model} | $status | $icon | $note |');
      }

      print('');
      print('💡 结论:');
      final workingModels = results.where((r) => r.succeeded).map((r) => r.model).toList();
      final failedModels = results.where((r) => !r.succeeded).map((r) => r.model).toList();

      if (workingModels.isNotEmpty) {
        print('  可用模型: ${workingModels.join(", ")}');
      }
      if (failedModels.isNotEmpty) {
        print('  不可用模型: ${failedModels.join(", ")}');
      }

      // 项目默认模型是否可用
      final bundledResult = results.firstWhere((r) => r.model == bundledDefaultModel);
      if (bundledResult.succeeded) {
        print('  ⚠️ 项目默认模型 $bundledDefaultModel 在当前端点可用，'
            '但在 DeepSeek 官方端点不可用（官方无此模型名）');
      } else {
        print('  🔴 项目默认模型 $bundledDefaultModel 不可用！'
            'AiModelParams.model 需要修改为端点支持的模型名');
      }

      // 关键断言：至少一个模型能工作
      expect(workingModels, isNotEmpty,
          reason: '至少应有一个模型名能在当前端点正常工作');

      // 关键断言：拼写错误模型不应工作
      final typoResult = results.firstWhere((r) => r.model == typoModel);
      expect(typoResult.succeeded, false,
          reason: '拼写错误的模型名 $typoModel 不应被任何端点接受');

    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('DeepSeek 官方端点对照（可选）', () {
    // 此 group 需要单独运行，指定 TEST_API_BASE_URL=https://api.deepseek.com/v1
    // 不在默认测试中强制通过，仅作手动诊断用
    test('deepseek-v4-pro 在官方端点应返回模型不存在', () async {
      // 仅当用户显式指向官方端点时执行
      if (!apiBaseUrl.contains('api.deepseek.com')) {
        print('ℹ️ 当前端点非 DeepSeek 官方，跳过官方端点对照测试');
        return;
      }
      if (!configured) return;

      final result = await probeModel(bundledDefaultModel);
      print('DeepSeek 官方端点 + $bundledDefaultModel:');
      print('  状态码: ${result.statusCode}');
      print('  错误体: ${result.errorBody}');

      expect(result.succeeded, false,
          reason: 'DeepSeek 官方不提供 deepseek-v4-pro 模型');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
