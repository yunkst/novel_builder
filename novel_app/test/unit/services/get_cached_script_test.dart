/// get_cached_script 工具的 unit 测试（script_type + present/missing 增量反馈）
///
/// 用真实内存 SQLite（TestDatabaseSetup.createInMemoryDatabase 跑全迁移，
/// site_scripts 表含 v37 ocr 列）+ MockInAppWebViewController 构造真实
/// WebViewExtractScenario，调 executeTool('get_cached_script', ...) 端到端验证。
///
/// _getCachedScript 是纯数据库工具（不在 _webviewRequiredTools 内），不触发
/// 任何 WebView 操作，因此 controller 用 mock 即可。
///
/// 覆盖：
/// - 全查 + 两段都有 → present 双全 / missing 空，两 run_id 都是 db_*
/// - 全查 + 只有 list → missing=[content]，content_run_id 为 null
/// - 全查 + 只有 content → missing=[list]，list_run_id 为 null
/// - 全查 + 两段都空（异常数据）→ found=false，双 missing
/// - 单查 chapter_content 缺失 → found=false，script_type 回显
/// - 单查 chapter_list 存在 → found=true，仅返回 list_run_id
/// - 整域名无记录 → found=false，双 missing
/// - 向后兼容：不传 script_type 时 list_run_id/content_run_id 仍都存在
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:novel_app/core/database/database_connection.dart';
import 'package:novel_app/core/providers/database_providers.dart';
import 'package:novel_app/services/novel_agent/scenarios/webview_extract_scenario.dart';

import '../../helpers/test_database_setup.dart' as test_db;
import 'webview_extract_prompt_test.mocks.dart';

void main() {
  late Database db;
  late ProviderContainer container;
  late WebViewExtractScenario scenario;

  setUp(() async {
    db = await test_db.TestDatabaseSetup.createInMemoryDatabase();
    final dbConnection = DatabaseConnection.forTesting(db);
    container = ProviderContainer(
      overrides: [
        databaseConnectionProvider.overrideWithValue(dbConnection),
      ],
    );
    final controller = MockInAppWebViewController();
    when(controller.getUrl()).thenAnswer((_) async => null);
    final scenarioProvider =
        Provider<WebViewExtractScenario>((ref) => WebViewExtractScenario(
              ref,
              controller,
              'https://example.com/list',
            ));
    scenario = container.read(scenarioProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// 往 site_scripts 插一条记录
  Future<void> insertScript({
    required String domain,
    String listJs = '',
    String contentJs = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('site_scripts', {
      'id': now.toString(),
      'domain': domain,
      'url_pattern': '',
      'chapter_list_js': listJs,
      'chapter_content_js': contentJs,
      'sample_url': '',
      'created_at': now,
      'last_used_at': now,
      'use_count': 0,
      'verified': 0,
      'ocr': 0,
    });
  }

  /// 调 get_cached_script，返回解码后的 JSON
  Future<Map<String, dynamic>> get({
    String? domain,
    String? scriptType,
  }) async {
    final args = <String, dynamic>{
      if (domain != null) 'domain': domain,
      if (scriptType != null) 'script_type': scriptType,
    };
    final raw = await scenario.executeTool('get_cached_script', args);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  group('get_cached_script - 全查模式（不传 script_type）', () {
    test('两段都有 → present 双全 / missing 空', () async {
      await insertScript(
        domain: 'both.com',
        listJs: '/*list*/',
        contentJs: '/*content*/',
      );

      final json = await get(domain: 'both.com');

      expect(json['found'], isTrue);
      expect(json['present'], ['chapter_list', 'chapter_content']);
      expect(json['missing'], isEmpty);
      expect(json['list_run_id'], startsWith('db_'));
      expect(json['content_run_id'], startsWith('db_'));
    });

    test('只有 list → missing=[content]，content_run_id 为 null', () async {
      await insertScript(domain: 'only-list.com', listJs: '/*list*/');

      final json = await get(domain: 'only-list.com');

      expect(json['found'], isTrue);
      expect(json['present'], ['chapter_list']);
      expect(json['missing'], ['chapter_content']);
      expect(json['list_run_id'], startsWith('db_'));
      expect(json['content_run_id'], isNull);
      expect(json['message'].toString(), contains('chapter_content'));
    });

    test('只有 content → missing=[list]，list_run_id 为 null', () async {
      await insertScript(domain: 'only-content.com', contentJs: '/*content*/');

      final json = await get(domain: 'only-content.com');

      expect(json['found'], isTrue);
      expect(json['present'], ['chapter_content']);
      expect(json['missing'], ['chapter_list']);
      expect(json['content_run_id'], startsWith('db_'));
      expect(json['list_run_id'], isNull);
    });

    test('两段都空（异常数据）→ found=false，双 missing', () async {
      await insertScript(domain: 'empty.com');

      final json = await get(domain: 'empty.com');

      expect(json['found'], isFalse);
      expect(json['present'], isEmpty);
      expect(json['missing'], ['chapter_list', 'chapter_content']);
    });

    test('向后兼容：list_run_id/content_run_id 键始终存在', () async {
      await insertScript(domain: 'compat.com', listJs: '/*list*/');

      final json = await get(domain: 'compat.com');

      // 缺失项的键不能"消失"，值应为 null，避免下游判空逻辑踩空
      expect(json.containsKey('list_run_id'), isTrue);
      expect(json.containsKey('content_run_id'), isTrue);
    });
  });

  group('get_cached_script - 单查模式（传 script_type）', () {
    test('chapter_content 缺失 → found=false，script_type 回显', () async {
      await insertScript(domain: 'miss-content.com', listJs: '/*list*/');

      final json = await get(
        domain: 'miss-content.com',
        scriptType: 'chapter_content',
      );

      expect(json['found'], isFalse);
      expect(json['script_type'], 'chapter_content');
      expect(json['missing'], ['chapter_content']);
      expect(json['present'], ['chapter_list']);
      expect(json['message'].toString(), contains('chapter_content'));
    });

    test('chapter_list 存在 → found=true，仅 list_run_id 有值', () async {
      await insertScript(
        domain: 'has-list.com',
        listJs: '/*list*/',
        contentJs: '/*content*/',
      );

      final json = await get(
        domain: 'has-list.com',
        scriptType: 'chapter_list',
      );

      expect(json['found'], isTrue);
      expect(json['script_type'], 'chapter_list');
      expect(json['list_run_id'], startsWith('db_'));
      // 单查不请求的另一类型不应返回 run_id
      expect(json['content_run_id'], isNull);
      expect(json['present'], ['chapter_list', 'chapter_content']);
      expect(json['missing'], isEmpty);
    });

    test('非法 script_type 走全查兜底', () async {
      await insertScript(
        domain: 'bogus.com',
        listJs: '/*list*/',
        contentJs: '/*content*/',
      );

      final json = await get(domain: 'bogus.com', scriptType: 'wat');

      // 非法值应被当作全查，不回显 script_type，两段都注册
      expect(json['found'], isTrue);
      expect(json.containsKey('script_type'), isFalse);
      expect(json['list_run_id'], startsWith('db_'));
      expect(json['content_run_id'], startsWith('db_'));
    });
  });

  test('整域名无记录 → found=false，双 missing', () async {
    final json = await get(domain: 'nope.com');

    expect(json['found'], isFalse);
    expect(json['present'], isEmpty);
    expect(json['missing'], ['chapter_list', 'chapter_content']);
  });
}
