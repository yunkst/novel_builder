/// 方案 A PoC 入口：PUA 单字 OCR 还原番茄字体反爬正文。
///
/// 流程：
///   1. 加载反爬字体 font.ttf（自定义 family）
///   2. 对 pua_list.json 里每个 PUA 码点：用 Canvas 渲染成单字 PNG -> ML Kit 中文 OCR
///   3. 构建 {pua: 真字} 映射表
///   4. 读 chapter_raw_text.txt（带 PUA 的 DOM 原文），用映射表替换 PUA -> 还原正文
///   5. print 还原正文 + 映射表命中统计
///
/// 用法：flutter run -t lib/main_pua_ocr.dart -d emulator-5554
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('[PUA_OCR] start');

  final sw = Stopwatch()..start();

  // 1. 加载反爬字体 -> 用 loadFontFromList 注册自定义 family
  const family = 'FanqieAntiCrawl';
  final fontData = await rootBundle.load('tool/ocr_test_assets/font.ttf');
  final fontBytes = fontData.buffer.asUint8List();
  await ui.loadFontFromList(fontBytes, fontFamily: family);
  print('[PUA_OCR] font loaded: $family, ${fontData.lengthInBytes} bytes');

  // 2. 读 PUA 列表
  final puaListStr = await rootBundle.loadString('tool/ocr_test_assets/pua_list.json');
  final puaList = (jsonDecode(puaListStr) as List).cast<int>();
  print('[PUA_OCR] pua count: ${puaList.length}');

  // 3. 读 DOM 原文（带 PUA）
  final rawText = await rootBundle.loadString('tool/ocr_test_assets/chapter_raw_text.txt');
  print('[PUA_OCR] raw text length: ${rawText.length}');

  // 4. ML Kit 中文识别器
  final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
  final tmpDir = await getTemporaryDirectory();

  // 5. 逐个 PUA 渲染单字图 + OCR
  final map = <int, String>{}; // pua codepoint -> 真字
  final tmpPng = File('${tmpDir.path}/glyph.png');
  int ocrEmpty = 0;
  int ocrMulti = 0;

  for (var i = 0; i < puaList.length; i++) {
    final cp = puaList[i];
    final char = String.fromCharCode(cp);

    // 5a. Canvas 渲染单字 PNG（白底黑字，大字号）。TextPainter 比 ParagraphBuilder 可靠
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 96.0;
    canvas.drawColor(Colors.white, BlendMode.src);
    final tp = TextPainter(
      text: TextSpan(
        text: char,
        style: TextStyle(fontFamily: family, fontSize: 72, color: Colors.black),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, const Offset(12, 8));
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    await tmpPng.writeAsBytes(byteData!.buffer.asUint8List());

    // 5b. ML Kit OCR
    final input = InputImage.fromFilePath(tmpPng.path);
    final result = await recognizer.processImage(input);
    final text = result.text.trim();

    if (text.isEmpty) {
      ocrEmpty++;
    } else if (text.length > 1) {
      // 多字：取第一个非空白字符
      final cleaned = text.replaceAll(RegExp(r'\s'), '');
      if (cleaned.isNotEmpty) {
        map[cp] = cleaned[0];
        if (cleaned.length > 1) ocrMulti++;
      } else {
        ocrEmpty++;
      }
    } else {
      map[cp] = text;
    }

    if ((i + 1) % 50 == 0) {
      print('[PUA_OCR] progress ${i + 1}/${puaList.length}');
    }
  }
  await recognizer.close();
  print('[PUA_OCR] ocr done: mapped=${map.length}, empty=$ocrEmpty, multi=$ocrMulti');

  // 6. 还原正文
  final sb = StringBuffer();
  int hit = 0;
  int miss = 0;
  for (final ch in rawText.runes) {
    if (0xE000 <= ch && ch <= 0xF8FF) {
      final real = map[ch];
      if (real != null) {
        sb.write(real);
        hit++;
      } else {
        sb.write('□'); // 未识别占位
        miss++;
      }
    } else {
      sb.writeCharCode(ch);
    }
  }
  final restored = sb.toString();

  sw.stop();
  print('[PUA_OCR] elapsed_ms=${sw.elapsedMilliseconds}');
  print('[PUA_OCR] pua hit=$hit miss=$miss (hit rate=${hit / (hit + miss) * 100}%)');
  print('[PUA_OCR] ===RESTORED_BEGIN===');
  print(restored);
  print('[PUA_OCR] ===RESTORED_END===');

  // 7. 映射表样本（前 30 条）便于人工核对
  final sample = map.entries.take(30).map((e) => 'U+${e.key.toRadixString(16).toUpperCase()}->${e.value}').join(' ');
  print('[PUA_OCR] map_sample: $sample');

  runApp(MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'PUA OCR done\nmapped=${map.length}/${puaList.length}\nhit=$hit miss=$miss\nelapsed=${sw.elapsedMilliseconds}ms\nsee logcat [PUA_OCR]',
            style: const TextStyle(color: Colors.white, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  ));
}
