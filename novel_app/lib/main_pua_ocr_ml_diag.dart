/// 诊断：ML Kit 对"单字重复"和"更大画布"的识别能力。
/// 测试：1 个 PUA / 5 个 PUA 重复 / 大字号 三种输入，看 ML Kit 是否返回结果。
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('[ML_DIAG] start');

  const family = 'FanqieAntiCrawl';
  final fontData = await rootBundle.load('tool/ocr_test_assets/font.ttf');
  await ui.loadFontFromList(fontData.buffer.asUint8List(), fontFamily: family);

  final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
  final tmpDir = await getTemporaryDirectory();
  final tmpPng = File('${tmpDir.path}/ml_diag.png');
  final pua = 0xE3E8; // 已知有字形的 PUA
  final char = String.fromCharCode(pua);

  // 3 种测试
  final tests = <({String label, String text, double width, double height, double fontSize, String? useFamily})>[
    (label: 'pua_single', text: char, width: 96, height: 96, fontSize: 72, useFamily: family),
    (label: 'pua_single_big', text: char, width: 256, height: 256, fontSize: 180, useFamily: family),
    (label: 'pua_repeat5', text: char * 5, width: 400, height: 96, fontSize: 72, useFamily: family),
    // 关键对照：系统字体真字单字，验证中文模型本身是否工作
    (label: 'real_sys_白', text: '白', width: 96, height: 96, fontSize: 72, useFamily: null),
    (label: 'real_sys_的', text: '的', width: 96, height: 96, fontSize: 72, useFamily: null),
    (label: 'real_sys_line', text: '苍白雷光', width: 400, height: 96, fontSize: 72, useFamily: null),
  ];

  for (final t in tests) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    final tp = TextPainter(
      text: TextSpan(text: t.text, style: TextStyle(fontFamily: t.useFamily, fontSize: t.fontSize, color: Colors.black)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, const Offset(10, 10));
    final picture = recorder.endRecording();
    final img = await picture.toImage(t.width.toInt(), t.height.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    await tmpPng.writeAsBytes(bytes!.buffer.asUint8List());

    final input = InputImage.fromFilePath(tmpPng.path);
    final result = await recognizer.processImage(input);
    print('[ML_DIAG] ${t.label}: result="${result.text}" blocks=${result.blocks.length}');
  }
  await recognizer.close();
  print('[ML_DIAG] done');
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('ml diag done')))));
}
