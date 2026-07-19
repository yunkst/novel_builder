import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

/// PP-OCRv6 rec 离线识别器（仅用于番茄字体反爬 PoC）。
///
/// 模型：assets/models/inference.onnx — 番茄字体反爬 PUA 单字识别
/// 字典：assets/models/ppocrv6_dict.txt — 18708 行 CTC 字符表
///
/// 用法：
///   final ocr = OcrPredictor(family: 'FanqieAntiCrawl');
///   await ocr.load();
///   final decoded = await ocr.recognizeGlyph(0xE3E8);
///
/// 流水线（与 fanqie-evidence/ppocr_full_decode.py 1:1）：
///   1. TextPainter 渲染 PUA 到 ui.Image（白底黑字 + 大字号）
///   2. ui.Image → rawRgba bytes → image.Image → copyResize 到 (W, 48)
///   3. NCHW float32 tensor，2x-1 归一化（PP-OCR 标准 mean=0.5/std=0.5）
///   4. onnxruntime 推理 → [1, T, 18710] logits
///   5. CTC greedy decode，blank=index 0，dict idx = ctc_idx - 1
class OcrPredictor {
  OcrPredictor({this.family = '', this.fontSize = 80, this.canvasSize = 120});

  /// 番茄反爬字体 family（已通过 ui.loadFontFromList 注册）。
  final String family;

  /// TextPainter 渲染时的字号。与 fanqie-evidence/ppocr_full_decode.py
  /// 的 `ImageFont.truetype(font, 80)` 1:1 对齐，保证 PoC 能复现 PC 82.9%。
  final double fontSize;

  /// TextPainter 渲染时的画布尺寸。与 Python 脚本的 `canvas=120` 1:1 对齐。
  final double canvasSize;

  OrtSession? _session;
  List<String> _vocab = const [];
  int _vocabSize = 0;

  bool get isLoaded => _session != null && _vocab.isNotEmpty;

  /// 从 asset 加载模型与字典。可重复调用以热重载。
  Future<void> load({
    String modelAsset = 'assets/models/inference.onnx',
    String dictAsset = 'assets/models/ppocrv6_dict.txt',
  }) async {
    // 加载字典
    final dictStr = await rootBundle.loadString(dictAsset);
    _vocab = [
      for (final line in dictStr.split('\n'))
        if (line.isNotEmpty) line.trim(),
    ];
    _vocabSize = _vocab.length;
    if (_vocabSize < 1000) {
      throw StateError('字典加载异常：仅 $_vocabSize 行');
    }

    // 加载模型并创建 session
    final ort = OnnxRuntime();
    _session = await ort.createSessionFromAsset(modelAsset);
  }

  /// 确保模型已加载，否则抛 [StateError]（防御 _session 空指针 → native crash）。
  void _ensureLoaded() {
    if (_session == null) {
      throw StateError('OCR 模型尚未加载完成，请稍后重试');
    }
  }

  /// 识别单个字符（PUA 码点或真字都可用）。
  /// 返回 (decodedText, rawIndexSequence)。
  @Deprecated('PoC 用，产品路径用 recognizeImage(base64Png)。Task 15 清理时移除。')
  Future<(String, List<int>)> recognizeGlyph(int codepoint) async {
    _ensureLoaded();
    final img = await _render(codepoint);
    if (img == null) return ('', <int>[]);

    final (tensor, w) = await _preprocess(img);
    final outputs = await _session!.run({
      'x': await OrtValue.fromList(tensor, [1, 3, 48, w]),
    });
    final value = outputs.values.first;
    final nested = await value.asList();
    // nested 形状：[1, T, C]；逐层 cast 成 List<List<double>>
    final logits = (nested[0] as List)
        .map((e) => (e as List).map((x) => (x as num).toDouble()).toList())
        .toList();
    final (text, raw) = _ctcDecode(logits);
    return (text, raw);
  }

  /// 识别 WebView canvas 渲染好的单字图（base64 PNG，不带 data:image/png;base64, 前缀）。
  ///
  /// 与 recognizeGlyph 的区别：本方法不自己渲染（渲染在 WebView canvas），
  /// 只做 base64 → ui.Image → 预处理 → onnx 推理 → CTC 解码。
  /// 预处理 / CTC 解码完全复用 PoC 已验证的 [_preprocess] / [_ctcDecode]。
  ///
  /// 抛出 [StateError] 如果模型尚未加载（防御 _session 空指针崩溃）。
  Future<String> recognizeImage(String base64Png) async {
    _ensureLoaded();
    final bytes = base64Decode(base64Png);
    final codec = await ui.instantiateImageCodec(bytes);
    // 用 try/finally 释放 GPU 资源：codec 持有解码器状态，frame.image 持有
    // GPU 纹理（Dart GC 不回收 GPU 纹理，必须显式 dispose）。否则每章 200+ PUA
    // 字符累积 ~11MB 不可回收 GPU 内存，低内存设备可能 OOM。
    // toByteData 返回的是拷贝，dispose image 不影响 _preprocess 已读出的字节。
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final (tensor, w) = await _preprocess(image);
        final outputs = await _session!.run({
          'x': await OrtValue.fromList(tensor, [1, 3, 48, w]),
        });
        final value = outputs.values.first;
        final nested = await value.asList();
        final logits = (nested[0] as List)
            .map((e) => (e as List).map((x) => (x as num).toDouble()).toList())
            .toList();
        final (text, _) = _ctcDecode(logits);
        return text;
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  /// 释放 session。
  Future<void> dispose() async {
    final s = _session;
    _session = null;
    if (s != null) {
      await s.close();
    }
  }

  // --- 渲染 ---

  Future<ui.Image?> _render(int codepoint) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final fillColor = Colors.black;
    canvas.drawColor(Colors.white, BlendMode.src);

    final char = String.fromCharCode(codepoint);
    final tp = TextPainter(
      text: TextSpan(
        text: char,
        style: TextStyle(
          fontFamily: family,
          fontSize: fontSize,
          color: fillColor,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    if (tp.width == 0 || tp.height == 0) return null;

    // 将字形画到画布中心
    final dx = (canvasSize - tp.width) / 2;
    final dy = (canvasSize - tp.height) / 2;
    tp.paint(canvas, Offset(dx, dy));

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());

    // 检查是否真的渲染出字形（非白像素比例太低视为空白）
    final rgba = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = rgba!.buffer.asUint8List();
    int dark = 0;
    for (int i = 0; i < bytes.length; i += 4) {
      final r = bytes[i], g = bytes[i + 1], b = bytes[i + 2];
      if ((r + g + b) / 3 < 128) dark++;
    }
    final total = rendered.width * rendered.height;
    if (dark / total < 0.005) return null;
    return rendered;
  }

  // --- 预处理：rawRgba → Float32List NCHW，2x-1 归一化 ---

  Future<(Float32List, int)> _preprocess(ui.Image rendered) async {
    // ui.Image (canvasSize x canvasSize, RGBA) → image.Image
    final rgba = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
    final src = rgba!.buffer.asUint8List();
    final srcImg = img.Image.fromBytes(
      width: rendered.width,
      height: rendered.height,
      bytes: src.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );

    // resize 到 (W, 48)，W = ceil(canvasSize * 48 / canvasSize / 32) * 32
    final scale = 48.0 / rendered.height;
    final w = (max(1, rendered.width * scale) / 32).ceil() * 32;
    final resized = img.copyResize(
      srcImg,
      width: w,
      height: 48,
      interpolation: img.Interpolation.linear,
    );

    // NCHW float32，2x-1
    final pixels = resized.getBytes(order: img.ChannelOrder.rgb);
    final tensor = Float32List(1 * 3 * 48 * w);
    final hw = 48 * w;
    for (int y = 0; y < 48; y++) {
      for (int x = 0; x < w; x++) {
        final p = (y * w + x) * 3;
        final r = pixels[p] / 255.0;
        final g = pixels[p + 1] / 255.0;
        final b = pixels[p + 2] / 255.0;
        tensor[0 * hw + y * w + x] = 2.0 * r - 1.0;
        tensor[1 * hw + y * w + x] = 2.0 * g - 1.0;
        tensor[2 * hw + y * w + x] = 2.0 * b - 1.0;
      }
    }
    return (tensor, w);
  }

  // --- CTC greedy decode ---

  (String, List<int>) _ctcDecode(List<List<double>> logits) {
    final raw = <int>[];
    final out = StringBuffer();
    int lastIdx = -1;
    for (final timestep in logits) {
      // argmax
      int bestIdx = 0;
      double bestVal = timestep[0];
      for (int i = 1; i < timestep.length; i++) {
        if (timestep[i] > bestVal) {
          bestVal = timestep[i];
          bestIdx = i;
        }
      }
      raw.add(bestIdx);
      if (bestIdx != 0 && bestIdx != lastIdx) {
        // vocab index = ctc_idx - 1
        final vIdx = bestIdx - 1;
        if (vIdx >= 0 && vIdx < _vocabSize) {
          out.write(_vocab[vIdx]);
        }
      }
      lastIdx = bestIdx;
    }
    return (out.toString(), raw);
  }
}
