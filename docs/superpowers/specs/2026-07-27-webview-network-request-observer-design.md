# 网页提取场景 — 网络请求观察工具设计

- **日期**: 2026-07-27
- **场景**: `WebViewExtractScenario`（`novel_app/lib/services/novel_agent/scenarios/webview_extract_scenario.dart`）
- **目标**: 给 Agent 提供一个工具，用于观察当前 WebView 页面的网络请求模式，辅助编写章节提取脚本。

## 1. 背景与动机

`WebViewExtractScenario` 当前有 10 个工具（`get_page_info` / `execute_js` / `navigate_to` / `get_current_url` / `get_cached_script` / `save_script` / `list_cached_scripts` / `inspect_script` / `get_script_logs` / `patch_memory`），Agent 在编写章节列表/正文提取脚本时，只能通过 `execute_js` 探测 DOM，看不到页面实际往哪些接口发请求、传了什么参数。

Agent 写提取器时，最有价值的信号之一是"网页的接口模式"——章节列表是哪个 AJAX 接口、参数叫什么名、是否需要特殊请求头。本工具补齐这块观察能力。

## 2. 范围

### 2.1 采集什么

- **请求侧（无 body）**：URL（含 query）/ HTTP method / 请求头
- **解析后的 query_params**：从 URL query 解析成 `{key: value}` map，方便 Agent 直接抄参数名
- **不采集请求体**：`flutter_inappwebview` v6 的 `WebResourceRequest` **无 body 字段**（Android 平台 API 限制，原生 `WebViewClient.shouldInterceptRequest` 也不给 POST body），故无法采集。POST 章节接口仅能看到 URL + 请求头。
- **不采集响应体**：约定不采集（响应体大多可由 Agent 用 `execute_js` 从 DOM 读取；省内存、省上下文、避免敏感正文落 buffer）
- **不采集 status / content-type**：观察模式下 `shouldInterceptRequest` 拿不到（见 §4.2）。若后续确实高频需要，可加 `onLoadResource` 原生回调补齐，本期不做（YAGNI）

### 2.2 平台范围

- **仅 Android**：采集层基于 `flutter_inappwebview` 的 `shouldInterceptRequest`，该 API 是 Android `WebViewClient.shouldInterceptRequest` 的 Dart 包装，iOS 无对应。
- **iOS 不提供此工具**：`WebViewExtractScenario.tools` getter 加 `Platform.isAndroid` 守卫，iOS 上 Agent 看不到该工具，回退到现有 `execute_js` 路径。

### 2.3 非目标

- 不拦截/改写任何请求（只读观察）
- 不采集响应体
- 不支持 iOS
- 不做 `shouldInterceptRequest` 之外的 service worker 拦截（小说站场景不需要）

## 3. 架构

```
WebViewExtractScenario (持有 NetworkRequestRecorder)
  ├ webview 构造点接线（Android）:
  │   InAppWebViewSettings(useShouldInterceptRequest: true)
  │   onLoadStart → recorder.clear()                  // 页面跳转即清空
  │   shouldInterceptRequest → recorder.add(request)   // return null,观察不拦截
  └ tools: [..., list_network_requests]                // iOS 不挂
       └ query recorder buffer
            └ List<NetworkRequestRecord> FIFO, cap 500
```

**新增 3 个文件**：

| 文件 | 职责 |
|---|---|
| `lib/services/novel_agent/scenarios/network_request_recorder.dart` | `NetworkRequestRecorder`：ring buffer + add/clear/snapshot/dispose；`NetworkRequestRecord` 数据模型 + 截断逻辑 |
| `lib/services/novel_agent/scenarios/network_request_recorder_test.dart` | 单测：FIFO 淘汰、过滤、截断、序列化 |
| （工具 schema 与实现） | 内联在 `webview_extract_scenario.dart`，仿 `inspect_script` 模板 |

**改动 2 类文件**：

- `webview_extract_scenario.dart`：
  - 持有一个 `NetworkRequestRecorder` 实例
  - `tools` getter 加 `list_network_requests`（仅 Android，`Platform.isAndroid` 守卫）
  - `executeTool` switch 加 `case 'list_network_requests'`
  - `_listNetworkRequests(args)` 实现 + `_listNetworkRequestsTool` schema 常量
  - `buildSystemPrompt` 补工具说明
  - 场景 cleanup / dispose 时 `recorder.dispose()`
- **webview 构造点**（`headless_webview_pool.dart` 的 `HeadlessInAppWebView` 构造点，可见屏路径本期不动）：
  - `initialSettings` 加 `useShouldInterceptRequest: true`（Android 条件）
  - `onLoadStart` 回调里 `recorder.clear()`
  - `shouldInterceptRequest` 回调里 `recorder.add(...)` + `return null`
  - 详见 §8 接线说明

## 4. 采集层：`shouldInterceptRequest`（原生观察模式）

### 4.1 机制

```dart
InAppWebViewSettings(useShouldInterceptRequest: true)

shouldInterceptRequest: (controller, request) async {
  // request: WebResourceRequest（flutter_inappwebview v6，无 body 字段）
  //   .url              WebUri
  //   .method           String? ("GET"/"POST"/...)，Android 21+
  //   .headers          Map<String, String>?，Android 21+
  //   .isForMainFrame   bool?
  //   .isRedirect       bool?
  //   .hasGesture       bool?
  recorder.add(request);
  return null;   // 官方"放行"语义：返回 null = 不拦截，WebView 照常发
}
```

### 4.2 能拿到 / 拿不到

| 字段 | 拿到? | 说明 |
|---|---|---|
| URL（含 query） | ✅ | `request.url` |
| method | ✅ | `request.method`（Android 21+，否则为 "GET"） |
| 请求头 | ✅ | `request.headers`（Referer / Cookie / UA / 自定义头全有；Android 21+） |
| **请求体 body** | ❌ | `WebResourceRequest` **无 body 字段**（Android 平台 API 限制；若要看 POST body 需另加 JS hook，本期不做） |
| isForMainFrame | ✅ | 用于区分主文档 vs 子资源 |
| status 状态码 | ❌ | 观察模式拿不到响应 |
| content-type | ❌ | 同上 |
| 响应头 / 响应体 | ❌ | 同上 |

### 4.3 采集范围决策:记录所有子资源,不启发式过滤

`shouldInterceptRequest` 的 `WebResourceRequest` **无 `initiatorType` 字段**(v6 API 限制),无法精确区分 xhr/fetch vs img/css/js。启发式判定(扩展名黑名单)不可靠(很多 API URL 无扩展名,如 `/api/chapter/list`),且增加复杂度。

**决策:本工具记录所有请求**(含 img/css/js/字体等子资源),由 Agent 通过工具的 `url_contains` 参数(如 `"api"`、`"chapter"`)自行过滤。Agent 拿到原始全量数据更灵活,过滤责任在调用方。

> 已知噪音影响:页面静态资源多时 `total` 可能上百条,但 `limit` 默认 50 + `url_contains` 即可精准拉到 API 请求。Buffer cap 500 FIFO 兜底防内存膨胀。

### 4.4 清空时机：页面跳转即清空

- **机制**：`onLoadStart` 原生回调 → `recorder.clear()`
- **语义**：Agent 在每个页面阶段（列表页 / 正文页）只关心当前页的接口；`navigate_to` 跳走后旧请求自动清空
- **SPA 边界**：`history.pushState` 式路由不触发 `onLoadStart`，不会清空——但 `cap 500` FIFO 兜底不会爆；Agent 需要重抓时可手动 `navigate_to` 同 URL 触发清空

## 5. 数据模型 + 截断策略

### 5.1 `NetworkRequestRecord`

```dart
class NetworkRequestRecord {
  final int index;                    // 全局递增序号（recorder 内计数器）
  final String method;                // "GET" / "POST" / ...
  final String url;                   // 完整 URL
  final Map<String, String> queryParams;  // 从 URL query 解析
  final Map<String, String> requestHeaders;  // 已截断
  final bool isForMainFrame;
  final int tsMs;                     // 入库时间戳（毫秒）
}
```

### 5.2 截断上限

| 维度 | 上限 | 标记 |
|---|---|---|
| recorder ring buffer | 500 条 FIFO | 超出丢最老 |
| 单个 header 值（Cookie 等） | 1 KB | 截断标 `_truncated: true` |
| 工具单次返回 | 50 条（默认，可调 ≤ 100） | 标 `truncated_to` |

### 5.3 query_params 解析

`Uri.parse(url).queryParameters` 直接拿到 `{key: value}` map。多值 key 取首个。

## 6. 工具：`list_network_requests`

### 6.1 Schema（OpenAI Function Calling）

```yaml
list_network_requests:
  description: |
    列出当前 WebView 自进入本页面以来捕获的 AJAX 请求（XHR/fetch），
    用于分析网页的接口模式、辅助编写章节提取脚本。
    返回完整 URL / 请求参数 / 请求头（响应体与请求体均不采集）。
    页面跳转后历史自动清空。
  parameters:           # 全部可选
    url_contains:       # string, URL 子串过滤（如 "chapter" / "/api/"）
    method:             # string, "GET"/"POST"...
    since_index:        # integer, 只返回 index > 此值的（查增量）
    limit:              # integer, 默认 50, 上限 100
```

### 6.2 返回

```json
{
  "total": 23,
  "returned": 23,
  "truncated_to": 50,
  "requests": [
    {
      "index": 0,
      "method": "GET",
      "url": "https://api.x.com/chapter/list?novelId=123&page=1",
      "query_params": { "novelId": "123", "page": "1" },
      "request_headers": { "referer": "...", "cookie": "..." },
      "is_for_main_frame": false,
      "ts_ms": 1722...
    }
  ]
}
```

请求按 `index` 升序（老的在前，方便 Agent 顺时间读）。

### 6.3 实现位置

- **Schema**：`webview_extract_scenario.dart` 内新增 `static const _listNetworkRequestsTool`，仿 `inspect_script` 的 `_inspectScriptTool`（行 2203-2224）模板
- **实现**：`webview_extract_scenario.dart` 内新增 `Future<String> _listNetworkRequests(args)`，仿 `_inspectScript`（行 1855-1886）
- **注册**：`tools` getter（行 252-263）加一行 + `executeTool` switch（行 316-340）加 `case 'list_network_requests'`
- **iOS 守卫**：`tools` getter 里该工具用 `if (Platform.isAndroid)` 包裹

## 7. 系统提示词更新

`webview_extract_scenario.dart` 的 `buildSystemPrompt`（行 95-190）在 `## 工具` 段补一句：

> `list_network_requests`：查看当前页面发出的 AJAX 请求（URL / 参数 / 请求头），用于分析接口模式。响应体不采集；POST body 因平台 API 限制也不采集——若需看响应内容或 POST body，用 `execute_js` 读取 DOM 或重发请求。页面跳转后历史清空。

## 8. 生命周期与接线

> **关键约束**：`flutter_inappwebview` 的 `shouldInterceptRequest` / `onLoadStart` 都是 **webview 构造时的 widget 回调参数**（`InAppWebView` / `HeadlessInAppWebView` 构造函数入参），不是 controller 创建后能动态注册的方法；`useShouldInterceptRequest` 也是 `InAppWebViewSettings` 构造参数。因此**回调与 settings 都在 webview 构造点接线**，不存在"运行时 attach"。

### 8.1 Recorder 归属

`NetworkRequestRecorder` 由 **`WebViewExtractScenario` 拥有**（一个场景一个实例），webview 构造点通过引用拿到它来接线回调。

### 8.2 接线位置

`WebViewExtractScenario` 在 Headless 模式下使用 **`HeadlessWebViewPool` 提供的 `HeadlessInAppWebView`**（该 pool 被 extract 场景独占 acquire/release）。所有 `shouldInterceptRequest` / `onLoadStart` / `useShouldInterceptRequest` 接线均在 **`headless_webview_pool.dart` 的 `HeadlessInAppWebView` 构造点**完成；可见屏路径（`webview_browser_screen.dart`）本期不动。

接线方式：场景持有 `NetworkRequestRecorder`；pool 在构造 `HeadlessInAppWebView` 时通过回调闭包或回调钩子把 `onLoadStart` / `shouldInterceptRequest` 指向 recorder（具体注入方式——回调参数 vs pool 内部 recorder 引用——实现期根据 pool 现有架构二选一，但 recorder 实例唯一来源是场景）。

### 8.3 时序

| 时机 | 动作 |
|---|---|
| webview 构造（Android） | `initialSettings` 加 `useShouldInterceptRequest: true`；`onLoadStart` → `recorder.clear()`；`shouldInterceptRequest` → `recorder.add(request)` + `return null` |
| `onLoadStart`（每次新文档） | `recorder.clear()` |
| `shouldInterceptRequest`（每个请求） | `recorder.add(request)` + `return null` |
| `navigate_to` 跳转 | 由 `onLoadStart` 自动清空，无需特殊处理 |
| 场景 cleanup / dispose | `recorder.dispose()`（释放 buffer，断回调引用） |
| iOS | 构造点不加 settings / 不挂回调；`tools` getter 不挂工具 |

## 9. 错误处理

- **`shouldInterceptRequest` 回调异常**：try/catch 包裹 `recorder.add`，异常时丢弃该条 + 打 `LogCategory.network` 日志，**不影响页面加载**（回调仍 `return null`）
- **URL 解析失败**：`query_params = {}`，url 保留原值
- **method / headers 为 null**（Android < 21）：method 默认 "GET"，headers 默认 `{}`
- **recorder 已 dispose**：`add` 静默 no-op

## 10. 测试

### 10.1 单测（`network_request_recorder_test.dart`）

- FIFO 淘汰：cap=500 边界（add 501 条，第 1 条被丢）
- `snapshot` 过滤：`url_contains` / `method` / `since_index` / `limit` 四个参数独立 + 组合
- 截断：header 值 > 1KB 标 truncated
- `query_params` 解析：正常 / 多值 / 无 query / URL 解析失败
- `clear`：清空 buffer + 重置 index 计数器
- 序列化：`NetworkRequestRecord` → JSON 字段完整
- Android < 21 兼容：`method == null` / `headers == null` 输入下不崩、默认值正确

### 10.2 不测

- `shouldInterceptRequest` 回调本身（需真 webview，靠实现期手动在提取场景里点几个页面验证）
- iOS 守卫（靠 `flutter analyze` + 代码审查）

## 11. 实现参考

### 11.1 新增工具的抄写模板

- 零参/有参无副作用工具：`inspect_script`（`webview_extract_scenario.dart:2203` schema + `:1855` 实现）
- 工具聚合：`tools` getter（行 252-263）
- 工具分发：`executeTool` switch（行 316-340）

### 11.2 webview 回调挂载参考

- `shouldInterceptRequest` 是 webview **构造时**的回调参数（非 controller 运行时方法），接线位置与方式见 **§8**
- 现有 `onLoadStart` / `onLoadStop` / `onProgressChanged` / `onReceivedError` 均在构造点注册，可作为回调写法模板参考：`webview_browser_screen.dart`、`headless_webview_content_service.dart`、`headless_webview_chapter_list_service.dart`、`headless_webview_pool.dart`

## 12. 已知限制

1. **iOS 不支持**：工具仅在 Android 提供，iOS Agent 回退 `execute_js`
2. **POST body 采不到**：`flutter_inappwebview` v6 的 `WebResourceRequest` 无 body 字段（Android 平台 API 限制）；POST 章节接口只能看 URL + 请求头，看不到请求体
3. **无 status / content-type**：观察模式拿不到响应侧信息；后续可加 `onLoadResource` 补齐（YAGNI）
4. **不预过滤 AJAX,记录所有子资源**:`shouldInterceptRequest` 的 `WebResourceRequest` 无 `initiatorType`,启发式过滤不可靠;改为记录全部(img/css/js/xhr/fetch),Agent 用 `url_contains` 自行过滤。静态资源多的页面 `total` 可能上百,靠 `limit` + `url_contains` 精准拉取
5. **SPA 路由不清空**：`history.pushState` 不触发 `onLoadStart`，buffer 不清；`cap 500` FIFO 兜底
6. **跨域请求头受限**：浏览器对跨域请求的某些头（如 Cookie）可能不暴露给 `shouldInterceptRequest`，取决于 webview 实现
7. **Android < 21 字段退化**：`method` / `headers` 字段仅 Android 21+ 可用，旧版会得到 null/默认值

## 13. 不在本期范围

- iOS 版本（需 `onLoadResource` + 不同采集策略，单独 spec）
- 响应体采集（需 `onLoadResource` 或自重发，单独 spec）
- service worker 拦截
- 请求改写/重放能力
