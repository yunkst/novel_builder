/// save_script 工具的 unit 测试（方案 G：直接测静态 validateAndPersistScript，
/// 绕开 HeadlessWebViewPool / InAppWebViewController）。
///
/// _saveScript executor 涉及 WebView 平台依赖（HeadlessWebViewPool + InAppWebViewController
/// + callAsyncJavaScript），纯 Dart 测试无法构造。把核心验证逻辑抽成 static
/// `validateAndPersistScript` 后，可注入 jsResult/repo/restoreService 完成单测覆盖。
///
/// 覆盖：
/// - 结构校验失败（content 太短）→ reason=content_too_short，不落库
/// - ocr=true 字体无效 → reason=font_family_invalid，不落库
/// - ocr=true readable_ratio 不达标 → reason=readable_ratio_below_threshold
/// - 全部验证通过 → success=true，repo.updateScriptPart 调一次（参数正确）
/// - ocr=false 结构通过 → success=true，ocr=false 直接落库，restoreService 不被调
/// - 结构校验：chapters_empty / chapter_missing_field / font_family_missing / invalid_structure
/// - 落库：domain_not_found → 失败返回，不抛
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/repositories/site_script_repository.dart';
import 'package:novel_app/services/novel_agent/scenarios/webview_extract_scenario.dart';
import 'package:novel_app/services/ocr_restore_service.dart';

import 'save_script_tool_test.mocks.dart';

@GenerateMocks([SiteScriptRepository, OcrRestoreService])
void main() {
  // ─── 工具函数 ───

  /// 72 字正文（远超 50 下限）。预生成以避免在 const default 参数中使用字符串乘法。
  const longContent = '正常正文文字正常正文文字正常正文文字正常正文文字'
      '正常正文文字正常正文文字正常正文文字正常正文文字'
      '正常正文文字正常正文文字正常正文文字正常正文文字';

  /// 构造一个 chapter_content 用的合法 jsResult（含 content + font_family）
  Map<String, dynamic> contentResult({
    String content = longContent,
    String fontFamily = 'GoodFont',
    String title = '第一章',
  }) =>
      {
        'content': content,
        'title': title,
        'font_family': fontFamily,
      };

  /// 构造一个 chapter_list 用的合法 jsResult
  Map<String, dynamic> listResult({String title = '书名'}) => {
        'title': title,
        'chapters': [
          {'title': '第一章 起始', 'url': 'https://a.com/c1'},
          {'title': '第二章 发展', 'url': 'https://a.com/c2'},
        ],
      };

  /// 构造一个验证通过的 OcrRestoreService mock
  MockOcrRestoreService goodRestore() {
    final svc = MockOcrRestoreService();
    when(svc.verifyFontFamily(any)).thenAnswer((_) async => true);
    // restorePuaInText：不动 content（无 PUA），原样返回
    when(svc.restorePuaInText(any, any))
        .thenAnswer((inv) async {
      final t = inv.positionalArguments[0] as String;
      return OcrRestoreResult(t, t.length, 0);
    });
    when(svc.readableRatio(any)).thenReturn(1.0);
    return svc;
  }

  group('validateAndPersistScript - 结构校验', () {
    test('content 太短（<50 字）→ content_too_short，不落库', () async {
      final repo = MockSiteScriptRepository();
      final result = await WebViewExtractScenario.validateAndPersistScript(
        domain: 'a.com',
        scriptType: 'chapter_content',
        ocr: false,
        scriptJs: '(async function(){...})()',
        jsResult: contentResult(content: '太短啦'),
        repo: repo,
      );

      expect(result['success'], false);
      expect(result['reason'], 'content_too_short');
      verifyNever(repo.updateScriptPart(
        domain: anyNamed('domain'),
        scriptType: anyNamed('scriptType'),
        scriptJs: anyNamed('scriptJs'),
        ocr: anyNamed('ocr'),
      ));
    });

    test('chapter_list 缺 chapters 字段 → chapters_empty', () async {
      final repo = MockSiteScriptRepository();
      final result = await WebViewExtractScenario.validateAndPersistScript(
        domain: 'a.com',
        scriptType: 'chapter_list',
        ocr: false,
        scriptJs: 'js',
        jsResult: {'title': '无章节字段'},
        repo: repo,
      );
      expect(result['success'], false);
      expect(result['reason'], 'chapters_empty');
    });

    test('chapter_list 章节缺 title → chapter_missing_field', () async {
      final repo = MockSiteScriptRepository();
      final result = await WebViewExtractScenario.validateAndPersistScript(
        domain: 'a.com',
        scriptType: 'chapter_list',
        ocr: false,
        scriptJs: 'js',
        jsResult: {
          'title': '书',
          'chapters': [
            {'url': 'https://a.com/c1'}, // 缺 title
            {'title': '第二章', 'url': 'https://a.com/c2'},
          ],
        },
        repo: repo,
      );
      expect(result['success'], false);
      expect(result['reason'], 'chapter_missing_field');
    });

    test('jsResult 非 Map → invalid_structure', () async {
      final repo = MockSiteScriptRepository();
      final result = await WebViewExtractScenario.validateAndPersistScript(
        domain: 'a.com',
        scriptType: 'chapter_content',
        ocr: false,
        scriptJs: 'js',
        jsResult: 'not_a_map',
        repo: repo,
      );
      expect(result['success'], false);
      expect(result['reason'], 'invalid_structure');
    });

    test('chapter_content ocr=true 缺 font_family → font_family_missing', () async {
      final repo = MockSiteScriptRepository();
      final result = await WebViewExtractScenario.validateAndPersistScript(
        domain: 'a.com',
        scriptType: 'chapter_content',
        ocr: true,
        scriptJs: 'js',
        // 不传 fontFamily，默认为 'GoodFont'；下方覆盖为空
        jsResult: {
          'content': longContent,
          'title': '第一章',
          // 故意不写 font_family
        },
        repo: repo,
      );
      expect(result['success'], false);
      expect(result['reason'], 'font_family_missing');
    });
  });

  group('validateAndPersistScript - OCR 验证', () {
    test('ocr=true 字体无效 → font_family_invalid，不落库', () async {
      final repo = MockSiteScriptRepository();
      final svc = MockOcrRestoreService();
      when(svc.verifyFontFamily(any)).thenAnswer((_) async => false);

      final result = await WebViewExtractScenario.validateAndPersistScript(
        domain: 'a.com',
        scriptType: 'chapter_content',
        ocr: true,
        scriptJs: 'js',
        jsResult: contentResult(),
        repo: repo,
        restoreService: svc,
      );
      expect(result['success'], false);
      expect(result['reason'], 'font_family_invalid');
      verifyNever(repo.updateScriptPart(
        domain: anyNamed('domain'),
        scriptType: anyNamed('scriptType'),
        scriptJs: anyNamed('scriptJs'),
        ocr: anyNamed('ocr'),
      ));
    });

    test('ocr=true readable_ratio<0.85 → readable_ratio_below_threshold', () async {
      final repo = MockSiteScriptRepository();
      final svc = MockOcrRestoreService();
      when(svc.verifyFontFamily(any)).thenAnswer((_) async => true);
      // restorePuaInText 返回 4 个全 □，readableRatio 返 0
      when(svc.restorePuaInText(any, any))
          .thenAnswer((_) async => OcrRestoreResult('□□□□', 0, 4));
      when(svc.readableRatio('□□□□')).thenReturn(0.0);

      final result = await WebViewExtractScenario.validateAndPersistScript(
        domain: 'a.com',
        scriptType: 'chapter_content',
        ocr: true,
        scriptJs: 'js',
        jsResult: contentResult(),
        repo: repo,
        restoreService: svc,
      );
      expect(result['success'], false);
      expect(result['reason'], 'readable_ratio_below_threshold');
      verifyNever(repo.updateScriptPart(
        domain: anyNamed('domain'),
        scriptType: anyNamed('scriptType'),
        scriptJs: anyNamed('scriptJs'),
        ocr: anyNamed('ocr'),
      ));
    });
  });

  group('validateAndPersistScript - 落库', () {
    test('全部验证通过 → 落库成功，updateScriptPart 调用一次（参数正确）', () async {
      final repo = MockSiteScriptRepository();
      when(repo.updateScriptPart(
        domain: anyNamed('domain'),
        scriptType: anyNamed('scriptType'),
        scriptJs: anyNamed('scriptJs'),
        ocr: anyNamed('ocr'),
      )).thenAnswer((_) async => (success: true, id: 'site_1', reason: null));

      final result = await WebViewExtractScenario.validateAndPersistScript(
        domain: 'a.com',
        scriptType: 'chapter_content',
        ocr: true,
        scriptJs: 'script_js_content',
        jsResult: contentResult(),
        repo: repo,
        restoreService: goodRestore(),
      );

      expect(result['success'], true);
      expect(result['domain'], 'a.com');
      expect(result['script_type'], 'chapter_content');
      expect(result['ocr'], true);
      expect(result['ocr_applied'], true);
      final captured = verify(repo.updateScriptPart(
        domain: captureAnyNamed('domain'),
        scriptType: captureAnyNamed('scriptType'),
        scriptJs: captureAnyNamed('scriptJs'),
        ocr: captureAnyNamed('ocr'),
      )).captured;
      expect(captured[0], 'a.com');
      expect(captured[1], 'chapter_content');
      expect(captured[2], 'script_js_content');
      expect(captured[3], true);
    });

    test('ocr=false chapter_list 结构通过 → 直接落库（不调 restoreService）', () async {
      final repo = MockSiteScriptRepository();
      when(repo.updateScriptPart(
        domain: anyNamed('domain'),
        scriptType: anyNamed('scriptType'),
        scriptJs: anyNamed('scriptJs'),
        ocr: anyNamed('ocr'),
      )).thenAnswer((_) async => (success: true, id: 'site_2', reason: null));

      final result = await WebViewExtractScenario.validateAndPersistScript(
        domain: 'a.com',
        scriptType: 'chapter_list',
        ocr: false,
        scriptJs: 'script_js_list',
        jsResult: listResult(),
        repo: repo,
      );

      expect(result['success'], true);
      expect(result['domain'], 'a.com');
      expect(result['script_type'], 'chapter_list');
      expect(result['ocr'], false);
      expect(result.containsKey('ocr_applied'), isFalse);

      final captured = verify(repo.updateScriptPart(
        domain: captureAnyNamed('domain'),
        scriptType: captureAnyNamed('scriptType'),
        scriptJs: captureAnyNamed('scriptJs'),
        ocr: captureAnyNamed('ocr'),
      )).captured;
      expect(captured[0], 'a.com');
      expect(captured[1], 'chapter_list');
      expect(captured[3], false);
    });

    test('domain 不存在 → save 失败返回，不抛', () async {
      final repo = MockSiteScriptRepository();
      when(repo.updateScriptPart(
        domain: anyNamed('domain'),
        scriptType: anyNamed('scriptType'),
        scriptJs: anyNamed('scriptJs'),
        ocr: anyNamed('ocr'),
      )).thenAnswer((_) async =>
          (success: false, id: null, reason: 'domain_not_found'));

      final result = await WebViewExtractScenario.validateAndPersistScript(
        domain: 'not.exist',
        scriptType: 'chapter_content',
        ocr: false,
        scriptJs: 'js',
        jsResult: contentResult(),
        repo: repo,
      );
      expect(result['success'], false);
      expect(result['reason'], 'domain_not_found');
      expect(result['domain'], 'not.exist');
      expect(result['suggestion'], contains('chapter_list'));
    });
  });
}
