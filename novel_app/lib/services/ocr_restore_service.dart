/// OCR 还原服务：对文本中出现的 PUA（私用区）码点走 PP-OCRv6 识别还原。
///
/// 设计背景：番茄小说等站点用 PUA 码点 + @font-face 自定义字体做反爬，
/// DOM innerText 是乱码。本服务对 PUA 逐字 canvas 渲染 → 识别 → 替换。
///
/// 本文件先只放纯函数 [isPua]；后续任务往里加 [OcrRestoreService] 类。
library;

/// 判断码点是否落在 PUA（私用区）三段之一。
/// - U+E000-F8FF   PUA-A
/// - U+F0000-FFFFD PUA-B
/// - U+100000-10FFFD PUA-C
bool isPua(int cp) =>
    (cp >= 0xE000 && cp <= 0xF8FF) ||
    (cp >= 0xF0000 && cp <= 0xFFFFD) ||
    (cp >= 0x100000 && cp <= 0x10FFFD);
