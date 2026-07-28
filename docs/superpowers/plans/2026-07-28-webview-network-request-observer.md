# 网页提取场景网络请求观察工具 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 `WebViewExtractScenario` 新增 `list_network_requests` 工具,让 Agent 能观察当前 Headless WebView 页面发出的 AJAX 请求(URL / method / 请求头 / query_params),辅助编写章节提取脚本。

**Architecture:** Android 原生 `shouldInterceptRequest` 观察模式(`return null` 放行)+ ring buffer 持久化(场景拥有 `NetworkRequestRecorder`)。pool 持有 recorder 引用槽(稳定回调委托),场景在 acquire 前 set、cleanup 时 clear。零 JS、零 monkey-patch。

**Tech Stack:** Flutter / Dart / `flutter_inappwebview` 6.1.5(锁定版本)/ Riverpod / OpenAI Function Calling。

## Global Constraints

- **平台**:仅 Android。iOS 不挂工具(`Platform.isAndroid` 守卫),Agent 回退 `execute_js`。
- **采集范围**:URL(含 query)/ method / 请求头 + query_params 解析。**不采集响应体、不采集请求体**(`WebResourceRequest` 无 body 字段)、不采集 status / content-type。
- **零 JS**:不注入 UserScript、不 monkey-patch XMLHttpRequest/fetch。
- **跳转清空**:`onLoadStart` → `recorder.clear()`。
- **截断上限**:buffer cap 500 FIFO / 单 header 值 1 KB / 单次返回 50 条(可调 ≤100)。
- **包锁定**:`flutter_inappwebview` 6.1.5;`WebResourceRequest` 字段为 `url: WebUri` / `method: String?` / `headers: Map<String,String>?` / `isForMainFrame: bool?`(后三者 Android 21+,旧版为 null/默认)。
- **依赖**:项目已有 `dart:convert`(jsonEncode)/ `ToolArgParser`(`optionalInt` / `optionalString`)/ `AgentScenarioCleanupMixin` / `HeadlessWebViewPool` 单例(`headlessWebViewPoolProvider`)。

---

## 关键设计决策(实现者必读)

**为什么 pool 持有 recorder 引用槽而不是每次重建 webview:**

`shouldInterceptRequest` / `onLoadStart` 是 `HeadlessInAppWebView` 构造时参数;pool 的 `HeadlessInAppWebView` **只构造一次**(首次 `acquire()` 触发 `_ensureReady`),后续 `acquire/release` 复用同一实例。但 `NetworkRequestRecorder` 是**每场景一个实例**(场景结束即 dispose)。若回调里直接闭包捕获某次场景的 recorder,下一次场景跑会拿到已 dispose 的 recorder。

**解法**:pool 持有**稳定的 `NetworkRequestRecorder? networkRecorder` 字段**(可变),构造时的回调在**调用时**读取该字段(`networkRecorder?.add(...)` / `networkRecorder?.clear()`),而非闭包捕获。场景在 acquire 前 `pool.networkRecorder = myRecorder`,cleanup 时 `pool.networkRecorder = null`。这样无需重建 webview,且始终命中当前 recorder。

**为什么 recorder.add 接受原始类型而非 `WebResourceRequest`:**

让 `NetworkRequestRecorder` 纯 Dart 可测(不 import `flutter_inappwebview`,单测无需真 webview)。`WebResourceRequest` → 原始字段的转换(`.url.toString()` / `.method` / `.headers` / `.isForMainFrame`)放在 pool 的回调里,属平凡属性访问,不单独测。

**为什么 snapshot 返回完整 envelope:**

`snapshot(...)` 直接返回 `{total, returned, truncated_to, requests:[...]}` 完整结构,在 Task 1 充分单测。Task 3 的工具方法只是"解析 args + jsonEncode(snapshot)",逻辑薄到无需场景实例即可测。

---

## File Structure

| 文件 | 类型 | 职责 |
|---|---|---|
| `novel_app/lib/services/novel_agent/scenarios/network_request_recorder.dart` | 新建 | `NetworkRequestRecord`(数据模型)+ `NetworkRequestRecorder`(ring buffer + add/clear/snapshot/dispose);纯 Dart,无 webview 依赖 |
| `novel_app/test/unit/services/novel_agent/scenarios/network_request_recorder_test.dart` | 新建 | recorder 单测(FIFO / 过滤 / 截断 / query_params / 序列化 / Android<21 兼容) |
| `novel_app/lib/services/headless_webview_pool.dart` | 修改 | 加 `networkRecorder` 字段 + 构造时挂 `useShouldInterceptRequest` / `onLoadStart` / `shouldInterceptRequest` 委托回调 |
| `novel_app/lib/services/novel_agent/scenarios/webview_extract_scenario.dart` | 修改 | 加 recorder 字段 + `list_network_requests` 工具(schema + 实现 + 注册)+ 系统提示词说明 |
| `novel_app/lib/services/novel_agent/agent_scenario_factory.dart` | 修改 | Headless 分支:acquire 前 set pool recorder / cleanup 时 clear |

---

## Task 1: NetworkRequestRecorder 数据模型 + ring buffer(TDD)

**Files:**
- Create: `novel_app/lib/services/novel_agent/scenarios/network_request_recorder.dart`
- Test: `novel_app/test/unit/services/novel_agent/scenarios/network_request_recorder_test.dart`

**Interfaces:**
- Consumes: `dart:convert`(jsonEncode)、`dart:collection`(ListQueue 用于 FIFO,可选)
- Produces: `class NetworkRequestRecord`(字段见下)、`class NetworkRequestRecorder`(方法:`add(...)` / `void clear()` / `void dispose()` / `Map<String,dynamic> snapshot({String? urlContains, String? method, int? sinceIndex, int limit = 50})`)

`NetworkRequestRecord` 字段(对应 spec §5.1,去掉 body):
```dart
final int index;
final String method;
final String url;
final Map<String, String> queryParams;
final Map<String, String> requestHeaders;  // 已截断
final bool isForMainFrame;
final int tsMs;
```

`NetworkRequestRecorder`:
```dart
final int maxCapacity;           // 默认 500
final int maxHeaderValueBytes;   // 默认 1024
final List<NetworkRequestRecord> _records = [];
int _nextIndex = 0;
bool _disposed = false;
```

- [ ] **Step 1: 写失败测试(基础 add + snapshot)**

创建 `novel_app/test/unit/services/novel_agent/scenarios/network_request_recorder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/novel_agent/scenarios/network_request_recorder.dart';

void main() {
  test('add 后 snapshot 能返回该记录', () {
    final r = NetworkRequestRecorder();
    r.add(
      method: 'GET',
      url: 'https://api.x.com/chapter/list?novelId=123&page=1',
      headers: {'referer': 'https://api.x.com/'},
      isForMainFrame: false,
    );
    final snap = r.snapshot();
    expect(snap['total'], 1);
    expect(snap['returned'], 1);
    expect(snap['truncated_to'], 50);
    final reqs = snap['requests'] as List;
    expect(reqs.length, 1);
    final first = reqs[0] as Map<String, dynamic>;
    expect(first['method'], 'GET');
    expect(first['url'], 'https://api.x.com/chapter/list?novelId=123&page=1');
    expect(first['query_params'], {'novelId': '123', 'page': '1'});
    expect(first['request_headers'], {'referer': 'https://api.x.com/'});
    expect(first['is_for_main_frame'], false);
    expect(first['index'], 0);
    expect(first['ts_ms'], isA<int>());
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/unit/services/novel_agent/scenarios/network_request_recorder_test.dart`
Expected: FAIL,target_of_file_doesn't_exist / 类未定义。

- [ ] **Step 3: 写最小实现**

创建 `novel_app/lib/services/novel_agent/scenarios/network_request_recorder.dart`:

```dart
import 'dart:convert';

/// 单条网络请求记录(已截断、已解析 query_params)
class NetworkRequestRecord {
  final int index;
  final String method;
  final String url;
  final Map<String, String> queryParams;
  final Map<String, String> requestHeaders;
  final bool isForMainFrame;
  final int tsMs;

  const NetworkRequestRecord({
    required this.index,
    required this.method,
    required this.url,
    required this.queryParams,
    required this.requestHeaders,
    required this.isForMainFrame,
    required this.tsMs,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'method': method,
        'url': url,
        'query_params': queryParams,
        'request_headers': requestHeaders,
        'is_for_main_frame': isForMainFrame,
        'ts_ms': tsMs,
      };
}

/// Headless WebView 网络请求观察器(场景级)
///
/// 通过 [add] 累积请求,FIFO 淘汰,[snapshot] 返回过滤后的快照。
class NetworkRequestRecorder {
  NetworkRequestRecorder({
    this.maxCapacity = 500,
    this.maxHeaderValueBytes = 1024,
  });

  final int maxCapacity;
  final int maxHeaderValueBytes;

  final List<NetworkRequestRecord> _records = [];
  int _nextIndex = 0;
  bool _disposed = false;

  /// 添加一条请求记录。
  ///
  /// [method] / [headers] 可为 null(Android < 21),默认 method='GET'、headers={}。
  void add({
    required String url,
    String? method,
    Map<String, String>? headers,
    bool isForMainFrame = false,
  }) {
    if (_disposed) return;

    final parsed = _parseQueryParams(url);
    final truncatedHeaders = _truncateHeaders(headers ?? const {});

    final record = NetworkRequestRecord(
      index: _nextIndex++,
      method: method ?? 'GET',
      url: url,
      queryParams: parsed,
      requestHeaders: truncatedHeaders,
      isForMainFrame: isForMainFrame,
      tsMs: DateTime.now().millisecondsSinceEpoch,
    );

    _records.add(record);
    if (_records.length > maxCapacity) {
      _records.removeAt(0);
    }
  }

  /// 清空所有记录,重置 index 计数器(页面跳转时调用)
  void clear() {
    if (_disposed) return;
    _records.clear();
    _nextIndex = 0;
  }

  /// 释放:dispose 后 add/clear 静默 no-op。
  void dispose() {
    _disposed = true;
    _records.clear();
    _nextIndex = 0;
  }

  /// 返回过滤后的快照 envelope。
  ///
  /// 返回结构:{ total, returned, truncated_to, requests:[...] }
  /// - [urlContains]:URL 子串过滤(大小写敏感)
  /// - [method]:HTTP method 过滤(大小写不敏感)
  /// - [sinceIndex]:只返回 index > sinceIndex 的
  /// - [limit]:最多返回条数(默认 50,内部 clamp 到 [1,100])
  Map<String, dynamic> snapshot({
    String? urlContains,
    String? method,
    int? sinceIndex,
    int limit = 50,
  }) {
    final effectiveLimit = limit.clamp(1, 100);

    Iterable<NetworkRequestRecord> filtered = _records;
    if (urlContains != null && urlContains.isNotEmpty) {
      filtered = filtered.where((r) => r.url.contains(urlContains));
    }
    if (method != null && method.isNotEmpty) {
      final upper = method.toUpperCase();
      filtered = filtered.where((r) => r.method.toUpperCase() == upper);
    }
    if (sinceIndex != null) {
      filtered = filtered.where((r) => r.index > sinceIndex);
    }

    // 按时间顺序(老的在前)截取最近 effectiveLimit 条
    final all = filtered.toList();
    final total = _records.length;
    final subset = all.length > effectiveLimit
        ? all.sublist(all.length - effectiveLimit)
        : all;

    return {
      'total': total,
      'returned': subset.length,
      'truncated_to': effectiveLimit,
      'requests': subset.map((r) => r.toJson()).toList(),
    };
  }

  /// 从 URL 解析 query_params。URL 解析失败时返回 {}。
  Map<String, String> _parseQueryParams(String url) {
    try {
      final uri = Uri.parse(url);
      return Map<String, String>.from(uri.queryParameters);
    } catch (_) {
      return const {};
    }
  }

  /// 截断单个 header 值(按 UTF-8 字节数计),超长标 `_truncated`。
  Map<String, String> _truncateHeaders(Map<String, String> headers) {
    final result = <String, String>{};
    headers.forEach((key, value) {
      final bytes = utf8.encode(value);
      if (bytes.length <= maxHeaderValueBytes) {
        result[key] = value;
      } else {
        final truncated = utf8.decode(bytes.sublist(0, maxHeaderValueBytes),
            allowMalformed: true);
        result[key] = '$truncated...';
        result['_${key}_truncated'] = 'true';
      }
    });
    return result;
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/unit/services/novel_agent/scenarios/network_request_recorder_test.dart`
Expected: PASS。

- [ ] **Step 5: 补充剩余单测(FIFO / 过滤 / 截断 / 清空 / Android<21 兼容)**

在测试文件 `main()` 内追加(在第一个 test 之后):

```dart
  test('FIFO 淘汰:超过 maxCapacity 丢最老', () {
    final r = NetworkRequestRecorder(maxCapacity: 3);
    for (var i = 0; i < 4; i++) {
      r.add(method: 'GET', url: 'https://x.com/$i', headers: const {});
    }
    final snap = r.snapshot(limit: 100);
    expect(snap['total'], 3);
    final reqs = (snap['requests'] as List).cast<Map<String, dynamic>>();
    expect(reqs.first['url'], 'https://x.com/1');  // index 0 已被淘汰
    expect(reqs.last['url'], 'https://x.com/3');
  });

  test('snapshot url_contains 过滤', () {
    final r = NetworkRequestRecorder();
    r.add(method: 'GET', url: 'https://x.com/api/chapter', headers: const {});
    r.add(method: 'GET', url: 'https://x.com/static/main.js', headers: const {});
    final snap = r.snapshot(urlContains: 'chapter', limit: 100);
    expect(snap['returned'], 1);
    expect(
      ((snap['requests'] as List).single as Map<String, dynamic>)['url'],
      'https://x.com/api/chapter',
    );
  });

  test('snapshot method 过滤(大小写不敏感)', () {
    final r = NetworkRequestRecorder();
    r.add(method: 'GET', url: 'https://x.com/a', headers: const {});
    r.add(method: 'POST', url: 'https://x.com/b', headers: const {});
    final snap = r.snapshot(method: 'post', limit: 100);
    expect(snap['returned'], 1);
    expect(
      ((snap['requests'] as List).single as Map<String, dynamic>)['method'],
      'POST',
    );
  });

  test('snapshot since_index 过滤', () {
    final r = NetworkRequestRecorder();
    r.add(method: 'GET', url: 'https://x.com/a', headers: const {});  // index 0
    r.add(method: 'GET', url: 'https://x.com/b', headers: const {});  // index 1
    r.add(method: 'GET', url: 'https://x.com/c', headers: const {});  // index 2
    final snap = r.snapshot(sinceIndex: 0, limit: 100);
    final reqs = (snap['requests'] as List).cast<Map<String, dynamic>>();
    expect(reqs.length, 2);
    expect(reqs.first['url'], 'https://x.com/b');
  });

  test('snapshot limit clamp 到 [1,100]', () {
    final r = NetworkRequestRecorder();
    r.add(method: 'GET', url: 'https://x.com/a', headers: const {});
    expect((r.snapshot(limit: 0) as Map)['truncated_to'], 1);
    expect((r.snapshot(limit: 999) as Map)['truncated_to'], 100);
  });

  test('header 值超 maxHeaderValueBytes 标 truncated', () {
    final r = NetworkRequestRecorder(maxHeaderValueBytes: 10);
    r.add(
      method: 'GET',
      url: 'https://x.com/a',
      headers: {'cookie': 'a-very-long-cookie-value-that-exceeds-limit'},
    );
    final snap = r.snapshot(limit: 100);
    final headers = (((snap['requests'] as List).single
        as Map<String, dynamic>)['request_headers']) as Map<String, dynamic>;
    expect(headers['_cookie_truncated'], 'true');
    expect((headers['cookie'] as String).endsWith('...'), isTrue);
  });

  test('query_params 多值取末个', () {
    final r = NetworkRequestRecorder();
    r.add(method: 'GET', url: 'https://x.com/?a=1&a=2', headers: const {});
    final snap = r.snapshot(limit: 100);
    final qp = (((snap['requests'] as List).single
        as Map<String, dynamic>)['query_params']) as Map;
    expect(qp['a'], '2');  // Uri.queryParameters 多值取末个（标准行为）
  });

  test('clear 清空记录 + 重置 index', () {
    final r = NetworkRequestRecorder();
    r.add(method: 'GET', url: 'https://x.com/a', headers: const {});
    r.clear();
    r.add(method: 'GET', url: 'https://x.com/b', headers: const {});
    final snap = r.snapshot(limit: 100);
    expect(snap['total'], 1);
    expect(
      ((snap['requests'] as List).single as Map<String, dynamic>)['index'],
      0,  // clear 后 index 从 0 重新计
    );
  });

  test('method/headers 为 null(Android<21)不崩 + 默认值', () {
    final r = NetworkRequestRecorder();
    r.add(method: null, url: 'https://x.com/a', headers: null);
    final snap = r.snapshot(limit: 100);
    final first = ((snap['requests'] as List).single) as Map<String, dynamic>;
    expect(first['method'], 'GET');
    expect(first['request_headers'], {});
  });

  test('dispose 后 add 静默 no-op', () {
    final r = NetworkRequestRecorder();
    r.add(method: 'GET', url: 'https://x.com/a', headers: const {});
    r.dispose();
    r.add(method: 'GET', url: 'https://x.com/b', headers: const {});
    final snap = r.snapshot(limit: 100);
    expect(snap['total'], 0);
  });
```

- [ ] **Step 6: 运行全部测试确认通过**

Run: `flutter test test/unit/services/novel_agent/scenarios/network_request_recorder_test.dart`
Expected: PASS(全部用例)。

- [ ] **Step 7: 提交**

```bash
cd novel_app
git add lib/services/novel_agent/scenarios/network_request_recorder.dart \
        test/unit/services/novel_agent/scenarios/network_request_recorder_test.dart
git commit -m "feat(webview-extract): 新建 NetworkRequestRecorder 网络请求观察器

ring buffer(cap 500 FIFO)+ header 截断(1KB)+ query_params 解析;
纯 Dart 可测,add 接受原始类型(不依赖 flutter_inappwebview);
snapshot 返回 {total,returned,truncated_to,requests} 完整 envelope。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: HeadlessWebViewPool 挂 recorder 槽 + 委托回调

**Files:**
- Modify: `novel_app/lib/services/headless_webview_pool.dart`(构造在 `_ensureReady` 行 179-192)

**Interfaces:**
- Consumes: `NetworkRequestRecorder`(Task 1 产出)、`flutter_inappwebview`(`InAppWebViewSettings` / `WebResourceRequest` / `WebResourceResponse` / `HeadlessInAppWebView`)、`dart:io`(`Platform`)
- Produces: `HeadlessWebViewPool.networkRecorder`(可空字段,场景 set/clear)

**实现要点:**
- pool 新增 `NetworkRequestRecorder? networkRecorder` 字段(可空、可变、public)。
- 构造 `HeadlessInAppWebView` 时:
  - `initialSettings` 加 `useShouldInterceptRequest: Platform.isAndroid`
  - 新增 `onLoadStart: (c, url) { networkRecorder?.clear(); }`
  - 新增 `shouldInterceptRequest: (c, request) { _recordRequest(request); return null; }`(Android 才有意义,但 v6 在 iOS 是 no-op,可不额外守卫;为保险用 `if (!Platform.isAndroid) return null;` 短路)
- `_recordRequest` 私有方法:从 `WebResourceRequest` 提取原始字段调 `networkRecorder?.add(...)`;try/catch 兜底(异常打日志不阻断,见 spec §9)。

- [ ] **Step 1: 读现状,确认构造点行号**

Run(用 Read 工具):读 `novel_app/lib/services/headless_webview_pool.dart`,确认 `_ensureReady` 内 `HeadlessInAppWebView(...)` 构造块当前内容(预期 `initialSettings` 仅 `javaScriptEnabled` / `loadsImagesAutomatically` / `mediaPlaybackRequiresUserGesture` 三项,只有 `onWebViewCreated` 回调)。

- [ ] **Step 2: 加 import**

在 `headless_webview_pool.dart` 顶部 import 区加(若 `dart:io` 已存在则跳过):

```dart
import 'dart:io' show Platform;
import 'novel_agent/scenarios/network_request_recorder.dart';
```

> 注意:确认现有 import 里 `flutter_inappwebview` 的具体导入形式(应为 `import 'package:flutter_inappwebview/flutter_inappwebview.dart';`),`InAppWebViewSettings` / `WebResourceRequest` / `WebResourceResponse` 均从此包导出。

- [ ] **Step 3: 在 HeadlessWebViewPool 类内加 networkRecorder 字段**

在类字段区(行 33-49 附近,`_isInUse` 之后)加:

```dart
    /// 当前绑定的网络请求观察器(可空)。
    ///
    /// 由 WebViewExtractScenario 在 acquire 前设置、cleanup 时置 null。
    /// 构造时的 shouldInterceptRequest / onLoadStart 回调在调用时读取本字段,
    /// 始终命中当前场景的 recorder(无需重建 webview)。
    NetworkRequestRecorder? networkRecorder;
```

- [ ] **Step 4: 改 HeadlessInAppWebView 构造块,加 settings 字段 + 两个回调**

定位 `_ensureReady` 内的 `HeadlessInAppWebView(...)` 构造(行 179-192),改为:

```dart
        _headlessWebView = HeadlessInAppWebView(
          onWebViewCreated: (controller) {
            if (!completer.isCompleted) {
              completer.complete(controller);
            }
          },
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            // 不加载图片，节省流量和时间
            loadsImagesAutomatically: false,
            // 禁用不需要的功能
            mediaPlaybackRequiresUserGesture: true,
            // 启用网络请求观察(Android 专属;iOS 该 setting 为 no-op)
            useShouldInterceptRequest: Platform.isAndroid,
          ),
          // 页面跳转即清空 recorder(仅 Android 有意义)
          onLoadStart: (controller, url) {
            networkRecorder?.clear();
          },
          // 观察所有请求,return null 放行不打断页面
          shouldInterceptRequest: (controller, request) {
            _recordRequest(request);
            return null;
          },
        );
```

- [ ] **Step 5: 加 _recordRequest 私有方法(含 try/catch 兜底)**

在 `HeadlessWebViewPool` 类内(任意位置,建议 `_ensureReady` 之后)加:

```dart
  /// 把一条 WebResourceRequest 记入 networkRecorder(观察模式,return null 放行)。
  ///
  /// 异常时丢弃该条 + 打日志,不阻断页面加载(回调仍返回 null)。
  void _recordRequest(WebResourceRequest request) {
    final recorder = networkRecorder;
    if (recorder == null) return;
    try {
      recorder.add(
        url: request.url.toString(),
        method: request.method,
        headers: request.headers,
        isForMainFrame: request.isForMainFrame ?? false,
      );
    } catch (e, stackTrace) {
      LoggerService.instance.w(
        'HeadlessWebViewPool 网络请求记录失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['headless-webview-pool', 'network-record', 'failed'],
      );
    }
  }
```

> 确认 `LoggerService` / `LogCategory.network` 在本文件已 import(现有 `acquire/release` 已用 `LoggerService.instance.*`,应已导入;`LogCategory.network` 若未用则需确认 enum 存在,否则用现有 category)。

- [ ] **Step 6: flutter analyze + 编译确认**

Run: `cd novel_app && flutter analyze lib/services/headless_webview_pool.dart`
Expected: no issues(或仅 info 级)。

> 此 Task 不写单测:`shouldInterceptRequest` 回调需真 Headless webview 触发(见 spec §10.2)。委托逻辑(字段读取 + add)由 Task 1 已覆盖的 recorder.add 保证;`_recordRequest` 是平凡属性转换 + try/catch,靠 analyze + 实现期手动验证(打开一个网页 → 调 list_network_requests 看是否有记录)。

- [ ] **Step 7: 提交**

```bash
cd novel_app
git add lib/services/headless_webview_pool.dart
git commit -m "feat(headless-pool): 挂 networkRecorder 槽 + shouldInterceptRequest/onLoadStart 委托回调

pool 持有稳定 NetworkRequestRecorder? 字段,构造时回调在调用时读取
(无需重建 webview 即可命中当前场景 recorder);useShouldInterceptRequest
仅 Android 启用;onLoadStart 清空;shouldInterceptRequest return null 放行。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: WebViewExtractScenario 加 list_network_requests 工具 + 工厂接线

**Files:**
- Modify: `novel_app/lib/services/novel_agent/scenarios/webview_extract_scenario.dart`(字段 / `tools` getter 行 251-263 / `executeTool` switch 行 316-340 / `buildSystemPrompt` 行 95-190 / 新增 schema 常量 + 方法)
- Modify: `novel_app/lib/services/novel_agent/agent_scenario_factory.dart`(Headless 分支行 30-54)

**Interfaces:**
- Consumes: `NetworkRequestRecorder`(Task 1)、`HeadlessWebViewPool.networkRecorder`(Task 2)、`ToolArgParser.optionalString/optionalInt`、`Platform.isAndroid`、`dart:convert`
- Produces: `list_network_requests` 工具(仅 Android 挂载)、scenario 暴露 `networkRecorder` getter 供工厂 set

**实现要点:**
- 场景加 `final NetworkRequestRecorder _networkRecorder = NetworkRequestRecorder();` 字段 + public getter `networkRecorder`(供工厂 set 到 pool)。
- `tools` getter:仅 `Platform.isAndroid` 时追加 `_listNetworkRequestsTool`。
- `executeTool` switch 加 `case 'list_network_requests': result = await _listNetworkRequests(args);`。
- `_listNetworkRequests`:用 `ToolArgParser` 解析可选参数,调 `jsonEncode(_networkRecorder.snapshot(...))`。
- 工厂 Headless 分支:`acquire()` 前(或构造 scenario 后立即)`pool.networkRecorder = scenario.networkRecorder;`;cleanup task 扩展为先 `pool.networkRecorder = null` 再 `pool.release()`。

- [ ] **Step 1: 在 webview_extract_scenario.dart 加 import + recorder 字段**

顶部 import 区加(若已有则跳过):

```dart
import 'dart:io' show Platform;
import 'network_request_recorder.dart';
```

在场景字段区(`_scriptSavedThisSession` 行 72 之后,构造函数行 75 之前)加:

```dart
  /// 当前场景的网络请求观察器。
  ///
  /// 仅 Android Headless 模式下由工厂绑定到 HeadlessWebViewPool;
  /// 工具 list_network_requests 从此读取本页面的 AJAX 请求历史。
  final NetworkRequestRecorder _networkRecorder = NetworkRequestRecorder();

  /// 供 AgentScenarioFactory 在 Headless 模式下绑定到 pool(回调委托到此)。
  NetworkRequestRecorder get networkRecorder => _networkRecorder;
```

- [ ] **Step 2: 改 tools getter,Android 守卫追加工具**

定位 `tools` getter(行 251-263),改为:

```dart
  @override
  List<Map<String, dynamic>> get tools {
    final base = <Map<String, dynamic>>[
      _getPageInfoTool,
      _executeJsTool,
      _navigateToTool,
      _getCurrentUrlTool,
      _getCachedScriptTool,
      _saveScriptTool,
      _listCachedScriptsTool,
      _inspectScriptTool,
      _getScriptLogsTool,
      patchMemoryToolDefinition,
    ];
    // 网络请求观察仅 Android 支持(iOS 无 shouldInterceptRequest)
    if (Platform.isAndroid) {
      base.add(_listNetworkRequestsTool);
    }
    return base;
  }
```

- [ ] **Step 3: executeTool switch 加 case**

定位 `executeTool` 的 switch(行 316-340),在 `case 'get_script_logs':` 之后、`default:` 之前加:

```dart
          case 'list_network_requests':
            result = await _listNetworkRequests(args);
```

- [ ] **Step 4: 加 _listNetworkRequests 实现**

在 `_inspectScript` 方法(行 1855-1886)之后,加:

```dart
  /// 列出当前 WebView 捕获的 AJAX 请求(URL / 参数 / 请求头)。
  ///
  /// 用于分析网页接口模式、辅助编写章节提取脚本。
  /// 不采集响应体;POST body 因平台限制也不采集。
  /// 页面跳转后历史自动清空。
  Future<String> _listNetworkRequests(Map<String, dynamic> args) async {
    final parser = ToolArgParser(args);
    final (urlContains, urlErr) = parser.optionalString('url_contains');
    if (urlErr != null) return urlErr;
    final (method, methodErr) = parser.optionalString('method');
    if (methodErr != null) return methodErr;
    final (sinceIndex, sinceErr) = parser.optionalInt('since_index');
    if (sinceErr != null) return sinceErr;
    final (limit, limitErr) = parser.optionalInt('limit');
    if (limitErr != null) return limitErr;

    final snap = _networkRecorder.snapshot(
      urlContains: urlContains,
      method: method,
      sinceIndex: sinceIndex,
      limit: limit ?? 50,
    );
    return jsonEncode(snap);
  }
```

> 确认 `ToolArgParser` 已在本文件 import(现有 `_saveScript` 已用,应已导入);`jsonEncode` 已 import。

- [ ] **Step 5: 加 _listNetworkRequestsTool schema 常量**

定位 `_inspectScriptTool`(行 2203-2224)之后,加:

```dart
  static const _listNetworkRequestsTool = {
    'type': 'function',
    'function': {
      'name': 'list_network_requests',
      'description':
          '列出当前页面自加载以来捕获的 AJAX 请求（XHR/fetch），'
          '用于分析网页接口模式、辅助编写章节提取脚本。'
          '返回每条请求的 URL / method / 请求参数（query_params）/ 请求头。'
          '⚠️ 响应体与 POST body 均不采集：若需看返回内容，用 execute_js 读 DOM 或重发请求。'
          '页面跳转后历史自动清空。',
      'parameters': {
        'type': 'object',
        'properties': {
          'url_contains': {
            'type': 'string',
            'description': 'URL 子串过滤（大小写敏感）。如 "chapter"、"/api/"。',
          },
          'method': {
            'type': 'string',
            'description': 'HTTP method 过滤（GET/POST，大小写不敏感）。',
          },
          'since_index': {
            'type': 'integer',
            'description': '只返回 index 大于此值的记录（用于翻页/查增量）。',
          },
          'limit': {
            'type': 'integer',
            'description': '最多返回条数，默认 50，上限 100。',
          },
        },
        'required': <String>[],
      },
    },
  };
```

- [ ] **Step 6: buildSystemPrompt 加工具使用说明**

定位 `buildSystemPrompt` 的 `## 工作流程` 段(行 108-114),在第 2 步(`get_cached_script`)之后插入一行网络请求观察说明(放在工作流程的合适位置,例如作为可选的第 1.5 步):

```dart
    buf.writeln('0. (可选) list_network_requests → 看当前页面发了哪些 AJAX 请求（URL/参数/请求头），用于推断章节接口模式，辅助编写提取脚本。注意：响应体与 POST body 不采集。');
```

> 确认插在 `buf.writeln('1. get_page_info ...');` 之前,保持流程顺序合理。

- [ ] **Step 7: 改工厂 Headless 分支,绑定 + 清理 recorder**

定位 `agent_scenario_factory.dart` 行 31-54 的 Headless 分支,改为:

```dart
        if (context.useHeadlessWebView) {
          // Headless 模式：从池获取 controller（排他占用）
          final pool = _ref.read(headlessWebViewPoolProvider);
          final controller = await pool.acquire();
          WebViewExtractScenario? scenario;
          try {
            scenario = WebViewExtractScenario.headless(
              _ref,
              controller,
              context.currentUrl ?? '',
            );
            // 绑定网络请求观察器到 pool（构造时回调委托到此 recorder）
            pool.networkRecorder = scenario.networkRecorder;
            // 注入清理钩子：先解绑 recorder，再释放 pool 使用权
            scenario.setCleanupTask(() async {
              pool.networkRecorder = null;
              scenario?._networkRecorder.dispose();
              pool.release();
            });
            return scenario;
          } catch (e, stackTrace) {
            // 构造失败也要释放，避免阻塞后续 acquire
            pool.networkRecorder = null;
            pool.release();
            LoggerService.instance.e(
              'WebViewExtractScenario.headless 构造失败: $e',
              stackTrace: stackTrace.toString(),
              category: LogCategory.ai,
              tags: ['agent', 'scenario', 'headless', 'init', 'failed'],
            );
            rethrow;
          }
        }
```

> 注意:`scenario?._networkRecorder` 访问私有字段——同文件同包内可访问(都在 `package:novel_app` 内),但跨文件访问私有字段 Dart 允许(库级私有是文件级,跨文件不行)。**修正**:用 public getter `scenario?.disposeNetworkRecorder()` 或直接让 cleanup 通过 `pool.networkRecorder = null` 后由场景自身 GC,recorder.dispose 由场景自己负责。**采用**:给场景加 public 方法 `void disposeNetworkRecorder() => _networkRecorder.dispose();`,工厂 cleanup 调 `scenario?.disposeNetworkRecorder()`。

**修正 Step 7**(用 public 方法替代私有字段访问):

先在 `webview_extract_scenario.dart` 加 public 方法(Step 1 已加 getter 的位置附近):

```dart
  /// 释放网络请求观察器(由 AgentScenarioFactory 在 cleanup 时调用)。
  void disposeNetworkRecorder() => _networkRecorder.dispose();
```

工厂 cleanup task 改为:

```dart
            scenario.setCleanupTask(() async {
              pool.networkRecorder = null;
              final s = scenario;
              s?.disposeNetworkRecorder();
              pool.release();
            });
```

catch 块也加解绑(已在上面 Step 7 代码里含 `pool.networkRecorder = null`)。

- [ ] **Step 8: flutter analyze 全量确认**

Run: `cd novel_app && flutter analyze lib/services/novel_agent/scenarios/webview_extract_scenario.dart lib/services/novel_agent/agent_scenario_factory.dart`
Expected: no issues。

- [ ] **Step 9: 跑现有场景相关测试,确认无回归**

Run: `cd novel_app && flutter test test/unit/services/novel_agent/ 2>&1 | tail -20`
Expected: 现有用例全过(本 Task 未改 recorder 逻辑,只加工具 + 接线)。

- [ ] **Step 10: 提交**

```bash
cd novel_app
git add lib/services/novel_agent/scenarios/webview_extract_scenario.dart \
        lib/services/novel_agent/agent_scenario_factory.dart
git commit -m "feat(webview-extract): 新增 list_network_requests 工具 + Headless 模式 recorder 接线

工具(仅 Android)列出当前页面 AJAX 请求(URL/method/请求头/query_params);
场景持有 NetworkRequestRecorder,工厂在 acquire 前绑定到 pool、cleanup 时解绑+dispose;
system prompt 加工具使用说明。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: 端到端手动验证 + 收尾

**Files:**
- 验证用,不改文件(除非发现 bug 回 Task 1-3 修)

**目的:** 在真 Headless webview 上确认 `shouldInterceptRequest` 真的把请求喂进 recorder、`list_network_requests` 真能返回。

- [ ] **Step 1: 启动 App,进入网页提取场景**

在 Android 设备/模拟器上跑 `cd novel_app && flutter run`,触发 webview_extract 场景(Agent Chat → 网页小说提取,Headless 模式)。

- [ ] **Step 2: 让 Agent 调 list_network_requests**

在场景里让 Agent 打开一个有 AJAX 的小说站(如番茄/笔趣阁),然后调 `list_network_requests`(可带 `url_contains` 过滤)。

Expected: 返回非空 `requests` 数组,含章节列表接口的 URL + query_params。

- [ ] **Step 3: 验证跳转清空**

让 Agent `navigate_to` 到另一页面,再调 `list_network_requests`。

Expected: 返回的新页面请求,旧页面请求已清空(`total` 反映新页面)。

- [ ] **Step 4: 验证 iOS 不挂工具(可选,若有 iOS 环境)**

iOS 上跑,确认 Agent 的 `tools` 列表里没有 `list_network_requests`。

- [ ] **Step 5: 更新根 CLAUDE.md changelog**

在根 `CLAUDE.md` 的 `## 变更记录` 顶部加一条(日期 2026-07-28):

```markdown
- **2026-07-28**: **网页提取场景网络请求观察工具**。`WebViewExtractScenario` 新增 `list_network_requests` 工具(仅 Android),用 `flutter_inappwebview` 的 `shouldInterceptRequest` 原生观察模式(`return null` 放行)捕获当前 Headless WebView 页面的 AJAX 请求(URL/method/请求头/query_params)。新建 `NetworkRequestRecorder`(ring buffer cap 500 FIFO + header 值截断 1KB + query_params 解析,纯 Dart 可测,snapshot 返回完整 envelope);`HeadlessWebViewPool` 加 `networkRecorder` 引用槽,构造时挂 `shouldInterceptRequest`/`onLoadStart`(调用时读槽委托,无需重建 webview);`AgentScenarioFactory` Headless 分支 acquire 前绑定 recorder、cleanup 时解绑+dispose;`onLoadStart` 跳转即清空。不采集响应体(约定)、不采集 POST body(`WebResourceRequest` 无 body 字段,平台限制)、不采集 status/content-type(观察模式拿不到)。iOS 工具不挂。零 JS、零 monkey-patch。详见 spec + plan。
```

- [ ] **Step 6: 最终全量测试 + analyze**

Run:
```bash
cd novel_app && flutter analyze && flutter test test/unit/services/novel_agent/scenarios/network_request_recorder_test.dart
```
Expected: analyze no issues / 测试全过。

- [ ] **Step 7: 提交收尾**

```bash
cd novel_app && cd ..
git add CLAUDE.md novel_app/CLAUDE.md
git commit -m "docs: CLAUDE.md changelog 记录网络请求观察工具

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Self-Review(已执行)

**1. Spec coverage:**
- §2.1 采集范围(URL/method/headers/query_params,不含 body)→ Task 1 `add` 签名 + `NetworkRequestRecord` 字段 ✓
- §2.2 仅 Android / iOS 不挂 → Task 3 Step 2 `Platform.isAndroid` 守卫 ✓
- §4 shouldInterceptRequest 观察模式 + return null → Task 2 Step 4 ✓
- §4.4 跳转清空(onLoadStart→clear)→ Task 2 Step 4 `onLoadStart` ✓
- §5.1 数据模型 → Task 1 ✓
- §5.2 截断(cap 500 / header 1KB / 单次 50)→ Task 1 ✓
- §6 工具 schema + 实现 + 注册 → Task 3 ✓
- §7 系统提示词 → Task 3 Step 6 ✓
- §8 接线(pool 持槽 + 场景 set/clear + 工厂)→ Task 2 + Task 3 Step 7 ✓
- §9 错误处理(try/catch + Android<21 null 兜底)→ Task 2 Step 5 + Task 1 ✓
- §10 测试(单测 + 不测 shouldInterceptRequest)→ Task 1 Step 5 + Task 2 Step 6 备注 ✓
- §11 实现参考(抄 inspect_script 模板)→ Task 3 Step 4/5 ✓

**2. Placeholder scan:** 已清——每步含真实代码或明确指令;`_ensureReady` 行号基于探索结果(行 179-192),工厂行号基于 Read 结果(行 30-54)。Step 1(T1)/Step 1(T2)的"读现状确认行号"是防漂移的安全步,非占位符。

**3. Type consistency:** `NetworkRequestRecorder.add` 签名(`url: String, method: String?, headers: Map?, isForMainFrame: bool`)在 Task 1 定义、Task 2 `_recordRequest` 调用一致;`snapshot` 返回 `Map<String,dynamic>` 在 Task 1 定义、Task 3 `_listNetworkRequests` 消费一致;`networkRecorder` getter / `disposeNetworkRecorder()` 在 Task 3 Step 1 定义、Step 7 消费一致(Task 3 内闭环,不跨 Task)。✓

**未覆盖项(已知,接受):**
- §4.3 AJAX 启发式过滤——**已确认不实现(用户选 A)**:Task 2 的 `_recordRequest` 记录所有请求(含 img/css/js 噪音),靠工具的 `url_contains` 让 Agent 自行过滤。原因:`WebResourceRequest` 无 `initiatorType`,扩展名启发式不可靠;Agent 用 `url_contains="api"` 过滤更准更灵活。spec §4.3 / §12 已同步更新为"记录所有 + Agent 过滤"。

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-28-webview-network-request-observer.md`. Two execution options:

**1. Subagent-Driven (recommended)** — 我每个 Task 派一个新 subagent 实现,Task 间审查,快速迭代。

**2. Inline Execution** — 在本会话用 executing-plans 批量执行,带检查点审查。

哪种?
