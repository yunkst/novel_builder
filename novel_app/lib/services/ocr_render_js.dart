/// 系统内置 OCR-JS：在已加载反爬字体的 WebView 页面上，
/// 用 canvas 渲染单个 PUA 码点 -> toDataURL -> 返回 base64 PNG（不带前缀）。
///
/// **关键**：canvas 不自动继承 @font-face，必须显式 `ctx.font = '80px <反爬字体族名>'`。
/// spike 验证：`80px sans-serif` 时四个不同 PUA 渲染出完全相同占位框（失败）；
/// `80px <反爬字体族名>` 时渲染出四个不同字形（成功）。
///
/// `{{CODEPOINT}}` 和 `{{FONT_FAMILY}}` 由 Dart 侧 [buildOcrRenderJs] 替换。
/// 本 JS **不走 `WebViewJsExecutor.validateScript`**（该函数强制 {{URL}} 会误杀），
/// 调用方直接 `callAsyncJavaScript(functionBody: js)`。
library;

const String ocrRenderJsTemplate = r'''
(async function() {
  await document.fonts.ready;
  const cp = {{CODEPOINT}};
  const fontFamily = "{{FONT_FAMILY}}";
  const canvas = document.createElement('canvas');
  canvas.width = 120; canvas.height = 120;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#FFFFFF'; ctx.fillRect(0, 0, 120, 120);
  ctx.fillStyle = '#000000';
  ctx.font = '80px ' + fontFamily;
  ctx.textBaseline = 'middle'; ctx.textAlign = 'center';
  ctx.fillText(String.fromCodePoint(cp), 60, 60);
  return canvas.toDataURL('image/png').split(',')[1];
})()
''';

/// 把 [codepoint] 和 [fontFamily] 注入模板，返回可执行的 async IIFE JS。
///
/// 调用方用 `controller.callAsyncJavaScript(functionBody: buildOcrRenderJs(...))`。
String buildOcrRenderJs(int codepoint, String fontFamily) {
  return ocrRenderJsTemplate
      .replaceAll('{{CODEPOINT}}', '0x${codepoint.toRadixString(16).toUpperCase()}')
      .replaceAll('{{FONT_FAMILY}}', fontFamily);
}
