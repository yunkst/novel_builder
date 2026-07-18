# save_script 超时与 ocr 参数设计

## 背景

在网页小说提取场景里，`save_script` 工具负责把 Agent 调试好的 JS 提取脚本落库。近期 OCR 提取器产品化后，出现两个问题：

1. 验证阶段脚本执行 60s、页面等待 30s 的默认时长，在慢网络 / 重脚本场景下容易触发 TimeoutException，导致脚本明明正确却被误判为超时。
2. `ocr` 参数语义是 boolean，但 description 仍偏经验描述，Agent 在普通站点也会顺手传 `true` 造成不必要的 OCR 验证。

本设计只改 `save_script` 自身，不改动其他场景（如阅读器里的正文抓取、FAB 的目录提取）的超时。

## 需求

- **延长 `save_script` 的超时时间**：让脚本验证和页面加载都有足够余量。
- **明确 `ocr` 参数用途并避免滥用**：让 `true` 只能用于确实出现字体反爬（PUA 私用区码点）的站点，否则拒绝落库。
- **删除 Agent 对话框中的快捷输入**“为这个网站生成提取脚本”，避免用户误触进入已废弃/不推荐的旧流程。

## 设计

### 1. 超时调整

| 超时点 | 当前值 | 新值 | 位置/常量 |
|---|---|---|---|
| 脚本验证执行 `callAsyncJavaScript` 硬超时 | 60s | **120s** | `webview_extract_scenario.dart` `_saveScript` 内 `.timeout(const Duration(seconds: 60))` |
| 页面加载等待（共用常量） | 30s | **60s** | `webview_extract_scenario.dart` 顶层 `_pageLoadTimeout` 常量 |
| TimeoutException 错误文案中的数字 | 60s | 同步改为 120s | 同一 `_saveScript` 的 `test_timeout` 分支 |
| OCR 单码点渲染超时 | 30s | **不变** | `_renderPuaViaController` 保持 30s |

> 说明：`_pageLoadTimeout` 是 `_navigateTo`、`_ensureHeadlessPageLoaded`、`_waitControllerForUrl` 三者共用的常量。提升到 60s 会一并让 navigate_to 等待更久，这属于可接受的副作用——对章节页/目录页慢加载也有好处。

### 2. `ocr` 参数防滥用：自动检测 + 校验双闸

保留 `ocr` 为 `required boolean`，但增加两层闸。

#### 2.1 第一层：运行时 PUA 存在性校验（ocr=true 时强制）

在 `validateAndPersistScript` 的 ocr=true 分支里，先扫描脚本返回的待还原文本中是否含 PUA 码点（U+E000–F8FF）。若零个，直接返回：

```json
{
  "success": false,
  "reason": "ocr_no_pua",
  "diagnostic": "ocr=true 但脚本返回文本中未检测到 PUA 码点（U+E000-F8FF），不符合字体反爬判定条件",
  "suggestion": "请重新确认该站点是否真的有字体反爬。若无 PUA，调用 save_script 时传 ocr=false；若有 PUA 但检测失败，请检查脚本是否正确返回了带 PUA 的原始文本（不要在 JS 里替换）"
}
```

实现要点：

- 只扫描文本，不调用 OCR 模型，不触发渲染，开销极小。
- 扫描范围：
  - `script_type == 'chapter_content'`：扫描 `content` 字段。
  - `script_type == 'chapter_list'`：扫描 `title` + 所有 `chapters[i].title` 的拼接文本。
- 命中阈值：只要 **≥ 1 个 PUA 码点** 即放行。因为字体反爬站点即便正文里只有标题受影响，也足以判定需要 OCR 模式。

#### 2.2 第二层：收紧工具描述

把 `_saveScriptTool` 中 `ocr` 的 description 改得更具硬性，让模型明确“传 true 会被校验”：

```text
ocr 字段是“该站点是否启用 OCR 字体反爬还原”的开关，必须严格按事实填写：
- 当且仅当脚本返回的文本中出现 PUA 私用区码点（U+E000–F8FF，表现为乱码方块）时，传 true。
- 若页面文本正常可读，必须传 false。
- ocr=true 时，save_script 会先检测文本中是否存在 PUA 码点；若检测不到，拒绝落库并返回 ocr_no_pua。
- chapter_list 与 chapter_content 的 ocr 各自独立判定，按各自页面是否真有 PUA 传值，不必一致
  （典型如番茄小说：目录页 title/chapter.title 是正常汉字传 false，正文页 content 有 PUA 传 true）。
  落库后分别存为该 script_type 的 ocr 标记（site_scripts.chapter_list_ocr / chapter_content_ocr 两列），互不覆盖。
```

### 3. 删除快捷输入

`agent_scenario.dart` 中 `ScenarioQuickPrompts._webviewExtract` 目前只包含一条：

```dart
ScenarioQuickPrompt(
  label: '为这个网站生成提取脚本',
  text: '请为当前网站编写可复用的提取脚本...',
)
```

直接删除这一条即可。`_webviewExtract` 变为空列表，`forScenario` 返回空列表，UI 层 `if (quickPrompts.isNotEmpty)` 会自动不渲染 chip 行。`ScenarioQuickPrompt` 类与 `_buildQuickPrompts` widget 保持原样，便于未来新增其他快捷词。

## 影响范围

- `webview_extract_scenario.dart`：修改超时常量、保存脚本执行 timeout、错误文案、ocr 校验逻辑。
- `agent_scenario.dart`：删除 `_webviewExtract` 列表里的唯一快捷输入。
- 测试：
  - `test/unit/services/save_script_tool_test.dart` 需要更新 ocr 相关断言。
  - 如果测试里有硬编码的超时文案，需要同步改 120s。

## 验收标准

1. `save_script` 在慢加载 / 重脚本站点上不再因 60s 超时失败，120s 内可完成验证。
2. `ocr=true` 时，若返回文本无 PUA 码点，save_script 返回 `success=false, reason=ocr_no_pua`，且不落库。
3. `ocr=false` 时，原有结构校验逻辑不变，正常站点可正常落库。
4. Agent 对话框输入区上方不再出现“为这个网站生成提取脚本” chip。
5. `flutter analyze` 无错误；相关单测通过。
