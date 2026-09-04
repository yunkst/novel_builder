# OCR 内存泄露修复 (2026-09-04)

## Context

番茄等字体反爬站点的 PUA 码点还原链路（`OcrRestoreService.restorePuaInText` → `OcrPredictor.recognizeImage`）每识别一个 PUA 字符约 634KB 的 OnnxValue native 内存被永久驻留，**单章约 200 PUA 字符 → 单章 ~127MB native 内存 leak**，**。读几章番茄小说即逼近 Android 进程 native heap 上限。

### 根因（已通过读源码确认）

读 `D:\PubCache\hosted\pub.flutter-io.cn\flutter_onnxruntime-1.8.3\android\src\main\kotlin\com\masicai\flutteronnxruntime\FlutterOnnxruntimePlugin.kt`：

- **L143** `private val ortValues = ConcurrentHashMap<String, OnnxValue>()` —— 插件级注册表，整个 App 生命周期常驻。
- **L452** `runInference` 把输出 tensor 写入 `ortValues[valueId] = outputTensor`，**从不删除**。
- **L477-496** `closeSession` 只关 session + 从 `sessions` 移除，**不会清空 `ortValues`**。
- **L1152** `releaseOrtValue` 是唯一清理入口，但 `OcrPredictor` 端从未调用。

`OcrPredictor.recognizeImage`（`lib/poc/ocr_predictor.dart:169-266`）的每次推理：
```dart
final outputs = await _session!.run({
  'x': await OrtValue.fromList(tensor, [1, 3, 48, w]),  // 输入句柄 → 注册表
});
final value = outputs.values.first;                       // 输出句柄 → 注册表
final nested = await value.asList();                       // 仅拷数据到 Dart, native 不释放
```
`OrtValue` 在 Dart 侧只是持有 `id: String` 的瘦壳（`ort_value.dart:42-54`），native OnnxValue 是 Java 对象持有 C++ OrtValue 句柄，Dart GC 触不到 native 那侧 → 永久 leak。

### 次要问题

- **P1** `OcrPredictor.load()`（`lib/poc/ocr_predictor.dart:103`）注释"可重复调用以热重载"，但未先关闭旧 `_session` → 旧 OrtSession + 10MB model buffer 永久驻留 native `sessions` 注册表。
- **P2** deprecated `recognizeGlyph` + `_render`（PoC 路径，番茄场景已切到 `recognizeImage`）永不调用但保留：
  - `PictureRecorder` / `Picture` / `ui.Image` 三件套不释放。
  - CLAUDE.md "2026-07-15" 条目里写了"Task 15 清理时移除"，未做。

## 修复方案

### 提交拆分（遵循 CLAUDE.md "一个提交只做一件事"）

**commit 1**：`fix(ocr): release OrtValue after each inference + close previous session on reload`
- P0 + P1 同文件同主题，一起落

**commit 2**：`refactor(ocr): remove deprecated recognizeGlyph PoC path`
- P2 清理，独立 refactor

### commit 1 — P0 + P1 修改

#### 文件：`novel_app/lib/poc/ocr_predictor.dart`

**P1**：`load()` 顶部（约 L77 `final ort = OnnxRuntime();` 之前）加：
```dart
// 防止重复调用 load() 时旧 session 驻留 native sessions 注册表。
if (_session != null) {
  await _session!.close();
  _session = null;
}
```

**P0**：`recognizeImage`（L220-265），把 `_preprocess` 之后的 `run`/`asList`/`CTC` 三段包到 try/finally 释放 input + 全部 outputs：
```dart
final (tensor, w) = await _preprocess(image);
final inputValue = await OrtValue.fromList(tensor, [1, 3, 48, w]);
Map<String, OrtValue> outputs = const {};
try {
  outputs = await _session!.run({'x': inputValue});
  // 现有 ONNX 推理 + CTC 解码逻辑保留不动 ...
  return text;
} finally {
  await inputValue.dispose();
  for (final v in outputs.values) {
    await v.dispose();
  }
}
```
- `outputs` 初始化 `const {}` 兜底 run 抛异常前未赋值；try/finally 保留现有 `_preprocess` 后的 codec/image 释放链不变。
- **错误路径覆盖**：
  - `fromList` 成功后 `run` 抛 → input 已创建但未进 try 块外层 — 调整：将 input 创建也挪进 try 块，外层 try 块改为从 `inputValue` 创建开始包到 try/finally；`run` 抛 → finally 仍 dispose input；outputs 仍是 `const {}` 跳过循环。
  - 现有 `catch (e, st) { ...rethrow; }` 包在外面不动 — 一旦它 rethrow 仍走 finally 释放。
- `dispose()` 自身（L269-275）不改 — 现有 close session 已足够，因为 P0 修完后 recognizeImage 不会留 OrtValue 残骸。

**最终结构**（`recognizeImage` L220-265 区域）：
```dart
try {                                                            // 外层 codec/image 释放
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {                                                          // 中层 image 释放
    final (tensor, w) = await _preprocess(image);
    final inputValue = await OrtValue.fromList(tensor, [1, 3, 48, w]);
    Map<String, OrtValue> outputs = const {};
    try {                                                        // ★ 内层: OrtValue 释放
      outputs = await _session!.run({'x': inputValue});
      final value = outputs.values.first;
      final nested = await value.asList();
      // ...现有日志 + CTC 解码...
      return text;
    } finally {
      await inputValue.dispose();
      for (final v in outputs.values) {
        await v.dispose();
      }
    }
  } finally {
    image.dispose();
  }
} finally {
  codec.dispose();
}
```

#### 新增文件：`novel_app/test/unit/services/ocr_predictor_dispose_test.dart`

平台通道 mock 验证 dispose 契约（**新模式**，但只新增一个文件，不污染已有 `ocr_predictor_test.dart` 的 skip-on-native-unavailable 风格）。

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/poc/ocr_predictor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 计数 platform channel 调用
  final counts = <String, int>{};
  int nextValueId = 0;

  setUp(() {
    counts.clear();
    nextValueId = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_onnxruntime'),
            (call) async {
      counts[call.method] = (counts[call.method] ?? 0) + 1;
      switch (call.method) {
        case 'getAvailableProviders':
          return ['CPUExecutionProvider'];
        case 'createSession':
          return {'sessionId': 'sess-test'};
        case 'getInputInfo':
          return [];
        case 'getOutputInfo':
          return [];
        case 'createOrtValue':
          return {
            'valueId': 'inp-${nextValueId++}',
            'dataType': 'float32',
            'shape': [1, 3, 48, 64],
          };
        case 'runInference':
          // 输出 valueId 用同一序列,固定 shape 让 CTC 解码走空路径
          final outId = 'out-${nextValueId++}';
          return {'output': [outId, 'float32', [1, 1, 18710]]};
        case 'getOrtValueData':
          return {
            'data': List.filled(18710, 0.0),  // 全零 → argmax=0 → blank → ""
            'shape': [1, 1, 18710],
          };
        case 'releaseOrtValue':
        case 'closeSession':
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_onnxruntime'), null);
  });

  test('recognizeImage 200 次调用后 releaseOrtValue 次数 == createOrtValue 次数',
      () async {
    final ocr = OcrPredictor();
    await ocr.load();
    // 提供一个有效 base64 PNG 让 recognizeImage 走完整路径
    final pngBytes = base64Decode(_blankPngBase64);  // 1x1 透明 PNG 即可
    final base64Png = base64Encode(pngBytes);

    for (var i = 0; i < 200; i++) {
      await ocr.recognizeImage(base64Png);
    }
    await ocr.dispose();

    final created = counts['createOrtValue'] ?? 0;
    final released = counts['releaseOrtValue'] ?? 0;
    expect(released, equals(created),
        reason: 'P0 回归: release($released) 必须等于 create($created)');
  });
}
```

- **断言语义**：每个 `recognizeImage` 产生 1 input + 1 output OrtValue；`run` 抛异常时 input 也会进 finally；`run` 成功时 input + output 都释放 → `released == created`。
- 用 `_blankPngBase64`（可复用 `test/unit/services/ocr_predictor_test.dart` 已有的 `_encodeBlankPng()` 工厂 — 实际从该文件抽出移到一个 `test_helpers/ocr_test_helpers.dart` 或直接内联 1x1 PNG base64 字符串）。
- mock 数据让 `asList` 返回全零 → CTC argmax=0 → blank → 返回空 text；不影响 dispose 断言。

#### 不改动的文件（这次 PR 不涉及）
- `lib/main_ppocr_demo.dart`（PoC demo 入口 — commit 2 再处理）
- `lib/main_pua_ocr_diag.dart`（独立 debug 入口，与本次清理无符号依赖 — 单独评估）
- `lib/services/ocr_restore_service.dart` / `ocr_pua_renderer.dart` / `ocr_render_js.dart` / `ocr_providers.dart` — 无 native 资源持有，无 bug
- `lib/services/headless_webview_*.dart` — 单例 + dispose 已正确

### commit 2 — P2 清理

#### 文件 1：`novel_app/lib/poc/ocr_predictor.dart`
- 删除 L140-160 `recognizeGlyph` 方法（含 `@Deprecated` 注解 + `_render(codepoint)` 调用）
- 删除 L279-320 `_render` 方法
- 删除/更新 L21-22 类示例
- 更新 L162-166 `recognizeImage` 注释，去掉"与 recognizeGlyph 的区别"措辞
- 顶部注释 `// _render` 不再被引用 → 检查 import 是否还要 `dart:math` / `dart:ui` / `flutter/material.dart` — `_render` 删后只 `recognizeImage` 仍用 `dart:ui`（`ui.instantiateImageCodec` / `ui.Codec`），保留；`material.dart` 仅 `Colors` 用 → `_render` 删后不再用 → 移除该 import

#### 文件 2：`novel_app/lib/main_ppocr_demo.dart`
- L71 循环里 `final decoded = await ocr.recognizeGlyph(cp);` 改为本地 TextPainter 渲染出 base64 PNG → `await ocr.recognizeImage(b64)`（保留 PoC demo 入口可用）

#### 文件 3：`novel_app/test/unit/services/ocr_predictor_test.dart`
- L34-39 `recognizeGlyph 仍保留（标 @Deprecated）` 反射用例 → 改为反向断言（"源文件不含 `recognizeGlyph` 字符串"）
- L46-49 `@Deprecated` 字符串断言 → 改为反向断言
- L5 顶部注释更新
- L121 注释中"复用 PoC _render 的 PictureRecorder + TextPainter 思路" → 中性化（不提 `_render`，描述为"本地 TextPainter 渲染单字 base64 PNG"）

## 验证

### 静态检查
```
cd novel_app
flutter analyze
flutter analyze --no-fatal-infos  # 严格模式
```
预期：0 告警。

### 单元测试
```
flutter test test/unit/services/ocr_predictor_test.dart
flutter test test/unit/services/ocr_predictor_dispose_test.dart  # 新增
flutter test test/unit/services/ocr_restore_service_test.dart
flutter test test/unit/services/ocr_render_js_test.dart
flutter test test/unit/providers/ocr_providers_test.dart
```
预期：新增 dispose 契约测试在桌面环境（无 onnxruntime native lib）也能跑通（mock platform channel）；其它测试维持现有 skip 行为。

### 真机集成测试（验证 P0 修复有效性）
1. 番茄小说场景，扫一个章节触发 OCR 还原
2. `adb shell dumpsys meminfo <package> | grep -E "Native|onnxruntime"`
3. 连续读 5 章（约 1000+ PUA）后重看 meminfo，**native heap 应收敛在 ~MB 级而非线性增长到 GB**（修复前 ~127MB/章，5 章 ~640MB+）
4. logcat 检查 `LoggerService` `ocr/onnx/recognize-done` 日志，每条记录耗时稳定（~50-200ms），无 native abort

### 不回归
- 阅读器其它功能（无 OCR 站点）行为不变
- Headless WebView list/content 提取流程不变

## 关键文件清单

| 文件 | commit 1 | commit 2 |
|---|---|---|
| `novel_app/lib/poc/ocr_predictor.dart` | ✏️ P0 + P1 | ✏️ 删除 `_render`/`recognizeGlyph` |
| `novel_app/lib/main_ppocr_demo.dart` | — | ✏️ 切到 `recognizeImage` |
| `novel_app/test/unit/services/ocr_predictor_test.dart` | — | ✏️ 反向断言 |
| `novel_app/test/unit/services/ocr_predictor_dispose_test.dart` | 🆕 新增 | — |
| 根 `CLAUDE.md` + `novel_app/CLAUDE.md` | ✏️ 加 2026-09-04 changelog | 同上 |

## 不在本次清理范围（明确写出避免误判）

- `lib/main_pua_ocr_diag.dart`（PUA 字体渲染独立诊断入口，与 `OcrPredictor` 无符号依赖），未来若决定清理单开 commit。
- iOS 端 `flutter_onnxruntime` 行为（项目已确认无 iOS 用户）。

## 风险与回滚

- **commit 1** 是行为修复，回滚即恢复 leak。mock 测试与真机集成测试构成双层防护。
- **commit 2** 是死代码删除，回滚即恢复文件；`main_ppocr_demo.dart` 是 debug 入口，不影响产品功能。
- `_session!.close()`（L437 在 dispose）保持原样 — 修完后 recognizeImage 不会留 OrtValue 残骸，无需额外清 ortValues 注册表。