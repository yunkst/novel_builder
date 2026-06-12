/// webview_add_novel_providers 单元测试
///
/// 测试三个反应式 Provider：
///   - webviewCurrentDomainProvider：URL → host 提取
///   - webviewCurrentSiteScriptProvider：host → SiteScript 查询
///   - webviewHasAddNovelButtonProvider：派生按钮可见性
///
/// 运行：
///   flutter test test/unit/providers/webview_add_novel_providers_test.dart
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:novel_app/core/database/database_connection.dart';
import 'package:novel_app/core/database/database_migrations.dart';
import 'package:novel_app/core/providers/database_providers.dart';
import 'package:novel_app/core/providers/webview_add_novel_providers.dart';
import 'package:novel_app/core/providers/webview_providers.dart';

void main() {
  // ===================================================================
  // 基础设施
  // ===================================================================
  late ProviderContainer container;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // 创建内存数据库 + 完整迁移
    final db = await openDatabase(
      ':memory:',
      version: DatabaseMigrations.currentVersion,
      singleInstance: false,
    );
    await DatabaseMigrations.createV1Tables(db);
    await DatabaseMigrations.upgrade(db, 1, DatabaseMigrations.currentVersion);

    final dbConnection = DatabaseConnection.forTesting(db);

    container = ProviderContainer(overrides: [
      databaseConnectionProvider.overrideWithValue(dbConnection),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  // ===================================================================
  // webviewCurrentDomainProvider
  // ===================================================================
  group('webviewCurrentDomainProvider', () {
    test('https URL → 提取 host', () {
      container
          .read(webviewCurrentUrlProvider.notifier)
          .state = 'https://www.alicesw.com/book/123';
      final domain = container.read(webviewCurrentDomainProvider);
      expect(domain, equals('www.alicesw.com'));
    });

    test('http URL → 提取 host', () {
      container
          .read(webviewCurrentUrlProvider.notifier)
          .state = 'http://example.com/page';
      final domain = container.read(webviewCurrentDomainProvider);
      expect(domain, equals('example.com'));
    });

    test('带路径和查询参数的 URL → 提取 host', () {
      container.read(webviewCurrentUrlProvider.notifier).state =
          'https://www.biquge543.com/book/123/chapter.html?page=2&sort=asc';
      final domain = container.read(webviewCurrentDomainProvider);
      expect(domain, equals('www.biquge543.com'));
    });

    test('about:blank → null', () {
      container
          .read(webviewCurrentUrlProvider.notifier)
          .state = 'about:blank';
      final domain = container.read(webviewCurrentDomainProvider);
      expect(domain, isNull);
    });

    test('空字符串 → null', () {
      container.read(webviewCurrentUrlProvider.notifier).state = '';
      final domain = container.read(webviewCurrentDomainProvider);
      expect(domain, isNull);
    });

    test('无效 URL → null', () {
      container.read(webviewCurrentUrlProvider.notifier).state = 'not a url';
      final domain = container.read(webviewCurrentDomainProvider);
      expect(domain, isNull);
    });

    test('file:// 协议 → null', () {
      container.read(webviewCurrentUrlProvider.notifier).state =
          'file:///C:/test.html';
      final domain = container.read(webviewCurrentDomainProvider);
      expect(domain, isNull);
    });

    test('javascript: 伪协议 → null', () {
      container
          .read(webviewCurrentUrlProvider.notifier)
          .state = 'javascript:void(0)';
      final domain = container.read(webviewCurrentDomainProvider);
      expect(domain, isNull);
    });
  });

  // ===================================================================
  // webviewCurrentSiteScriptProvider
  // ===================================================================
  group('webviewCurrentSiteScriptProvider', () {
    test('domain 为 null → 返回 null（同步，不触发 DB 查询）', () async {
      container.read(webviewCurrentUrlProvider.notifier).state = '';
      final script = await container.read(
        webviewCurrentSiteScriptProvider.future,
      );
      expect(script, isNull);
    });

    test('无匹配脚本 → 返回 null', () async {
      container.read(webviewCurrentUrlProvider.notifier).state =
          'https://unknown-site.com/book/123';
      final script = await container.read(
        webviewCurrentSiteScriptProvider.future,
      );
      expect(script, isNull);
    });

    test('有匹配脚本 → 返回 SiteScript', () async {
      // 预插入一条 site_script
      final db = container.read(databaseConnectionProvider).database;
      await db.then((d) => d.insert('site_scripts', {
            'id': 'test-script-1',
            'domain': 'www.alicesw.com',
            'url_pattern': '',
            'chapter_list_js': '(async function(){ return JSON.stringify({title:"test",chapters:[]}); })()',
            'chapter_content_js': '',
            'sample_url': 'https://www.alicesw.com/book/123',
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'last_used_at': DateTime.now().millisecondsSinceEpoch,
            'use_count': 0,
            'verified': 0,
          }));

      container.read(webviewCurrentUrlProvider.notifier).state =
          'https://www.alicesw.com/book/123';
      final script = await container.read(
        webviewCurrentSiteScriptProvider.future,
      );
      expect(script, isNotNull);
      expect(script!.domain, equals('www.alicesw.com'));
      expect(script.hasChapterListJs, isTrue);
      expect(script.hasChapterContentJs, isFalse);
    });

    test('URL 变化 → 重新查询（Provider 自动失效）', () async {
      final db = container.read(databaseConnectionProvider).database;
      await db.then((d) => d.insert('site_scripts', {
            'id': 'test-script-2',
            'domain': 'www.alicesw.com',
            'url_pattern': '',
            'chapter_list_js': '...',
            'chapter_content_js': '',
            'sample_url': '',
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'last_used_at': DateTime.now().millisecondsSinceEpoch,
            'use_count': 0,
            'verified': 0,
          }));

      // 初始 URL：有脚本
      container.read(webviewCurrentUrlProvider.notifier).state =
          'https://www.alicesw.com/book/123';
      var script = await container.read(
        webviewCurrentSiteScriptProvider.future,
      );
      expect(script, isNotNull);

      // 切换 URL：无脚本
      container.read(webviewCurrentUrlProvider.notifier).state =
          'https://no-script-site.com/book/456';
      script = await container.read(
        webviewCurrentSiteScriptProvider.future,
      );
      expect(script, isNull);
    });
  });

  // ===================================================================
  // webviewHasAddNovelButtonProvider
  // ===================================================================
  group('webviewHasAddNovelButtonProvider', () {
    test('无脚本 → false', () {
      container.read(webviewCurrentUrlProvider.notifier).state =
          'https://no-script-site.com/book/123';
      // 等待 FutureProvider 完成
      final show = container.read(webviewHasAddNovelButtonProvider);
      expect(show, isFalse);
    });

    test('有脚本但 chapterListJs 为空 → false', () async {
      final db = container.read(databaseConnectionProvider).database;
      await db.then((d) => d.insert('site_scripts', {
            'id': 'test-script-3',
            'domain': 'www.example.com',
            'url_pattern': '',
            'chapter_list_js': '', // 空！
            'chapter_content_js': '...',
            'sample_url': '',
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'last_used_at': DateTime.now().millisecondsSinceEpoch,
            'use_count': 0,
            'verified': 0,
          }));

      container.read(webviewCurrentUrlProvider.notifier).state =
          'https://www.example.com/book/123';
      // 等待 FutureProvider 完成
      await container.read(webviewCurrentSiteScriptProvider.future);
      final show = container.read(webviewHasAddNovelButtonProvider);
      expect(show, isFalse);
    });

    test('有脚本且 chapterListJs 非空 → true', () async {
      final db = container.read(databaseConnectionProvider).database;
      await db.then((d) => d.insert('site_scripts', {
            'id': 'test-script-4',
            'domain': 'www.alicesw.com',
            'url_pattern': '',
            'chapter_list_js': '(async function(){ return JSON.stringify({title:"test",chapters:[]}); })()',
            'chapter_content_js': '',
            'sample_url': '',
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'last_used_at': DateTime.now().millisecondsSinceEpoch,
            'use_count': 0,
            'verified': 0,
          }));

      container.read(webviewCurrentUrlProvider.notifier).state =
          'https://www.alicesw.com/book/123';
      // 等待 FutureProvider 完成
      await container.read(webviewCurrentSiteScriptProvider.future);
      final show = container.read(webviewHasAddNovelButtonProvider);
      expect(show, isTrue);
    });

    test('loading 状态 → false（不闪烁）', () {
      // 刚设置 URL，FutureProvider 还在加载中
      container.read(webviewCurrentUrlProvider.notifier).state =
          'https://www.alicesw.com/book/123';
      // 不 await，直接读派生 Provider
      final show = container.read(webviewHasAddNovelButtonProvider);
      // loading 状态应返回 false
      expect(show, isFalse);
    });
  });
}
