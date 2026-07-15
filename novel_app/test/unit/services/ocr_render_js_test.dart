import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/ocr_render_js.dart';

void main() {
  group('buildOcrRenderJs', () {
    test('替换 CODEPOINT 占位符', () {
      final js = buildOcrRenderJs(0xE3E8, 'MyFont');
      expect(js, contains('const cp = 0xE3E8;'));
      // ctx.font 行：fontFamily 是 JS 变量名，buildOcrRenderJs 不替换它，
      // 只替换 const fontFamily = "..." 那行的字符串字面量值。
      expect(js, contains('const fontFamily = "MyFont";'));
      expect(js, contains("'80px ' + fontFamily"));
    });

    test('替换 FONT_FAMILY 占位符', () {
      final js = buildOcrRenderJs(0xE3E9, 'AntiCrawlFont');
      expect(js, contains('const fontFamily = "AntiCrawlFont";'));
      expect(js, contains("'80px ' + fontFamily"));
    });

    test('保留 await document.fonts.ready', () {
      final js = buildOcrRenderJs(0xE3E8, 'F');
      expect(js, contains('await document.fonts.ready'));
    });

    test('返回 base64 不带前缀', () {
      final js = buildOcrRenderJs(0xE3E8, 'F');
      expect(js, contains("toDataURL('image/png').split(',')[1]"));
    });

    test('不出现具体站点选择器', () {
      final js = buildOcrRenderJs(0xE3E8, 'F');
      expect(js, isNot(contains('muye-reader')));
      expect(js, isNot(contains('fanqie')));
    });
  });
}
