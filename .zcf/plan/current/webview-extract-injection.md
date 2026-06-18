# WebView 提取场景 — 无 tool_call 时注入脚本检查提示

## 背景

在 `webview_extract` 场景中，Agent 的 ReAct 循环在"无 tool_calls 返回"时直接结束。
但存在一种情况：Agent 已经通过 `execute_js` 成功生成了提取脚本，却没有调用 `save_script` 保存。

## 改动范围

| 文件 | 改动类型 | 改动量 |
|------|---------|--------|
| `lib/services/novel_agent/agent_scenario.dart` | 新增接口方法 | +8 行 |
| `lib/services/novel_agent/agent_loop.dart` | 修改无 tool_call 分支 | ~15 行 |
| `lib/services/novel_agent/scenarios/webview_extract_scenario.dart` | 实现注入逻辑 | ~50 行 |
| `lib/services/novel_agent/scenarios/run_store.dart` | 新增 getter | +3 行 |

## 核心逻辑

```
Agent 本轮无 tool_calls → onNoToolCalls() 钩子
  ├─ 已注入过？ → 返回 null，正常结束
  ├─ RunStore 有成功条目？ → 注入 "请调 save_script 保存"
  ├─ 有工具调用但无成功脚本？ → 注入 "说明无法提取的原因"
  └─ 从未调工具？ → 注入 "说明网站无法提取的原因"
```

## 防重复机制

- `_scriptInjectionDone` 标记，注入一次后置 true
- 第二次无 tool_call 时 `onNoToolCalls` 返回 null，正常结束
- `maxRounds` 限制兜底

## 时间

2026-06-17 12:08
