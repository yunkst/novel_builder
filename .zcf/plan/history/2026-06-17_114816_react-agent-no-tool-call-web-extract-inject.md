# 任务：react agent 无 tool_call 时 Web 提取场景的提示注入

## 上下文

在 `D:\opensource\hermes-agent\` 的 react agent 主循环中，当 LLM 响应没有 `tool_calls` 时，agent 进入"完成"分支并 `break` 退出循环。

**问题场景**：在 web 信息提取流程中，agent 经常先调用 `web_extract` / `web_crawl` / `browser_navigate` 等工具拿到页面内容，本应继续调用 `write_file` / `save_*` 保存结果，但却直接给出文字总结后结束，导致提取的数据没有持久化。

**目标**：在"无 tool_call"分支首次触发时，如果历史消息中存在 web 类工具调用、但没有对应的保存操作，主动注入一条 user 消息提醒 agent 主动保存，迫使其再进入一轮推理。注入最多一次，第二次仍无 tool_call 则按原本逻辑 break 结束（受 `max_iterations` 兜底）。

## 方案概览

采用**通用钩子链 + 场景 hook**的方案 A：

1. 在 `AIAgent` 上新增 `self._no_tool_call_hooks: list[Callable]` 字段
2. 在 `run_conversation` 的"无 tool_call 分支"中、`break` 退出前调用钩子链
3. 钩子返回 `(role, content)` 时，注入 user 消息并 `continue` 回到循环
4. 创建一个具体的 `WebExtractNoToolCallHook` 处理 web 场景

## 详细步骤

### 步骤 1：创建钩子模块

**新建文件**：`D:\opensource\hermes-agent\hooks\no_tool_call_hooks.py`

**类结构**：

```python
"""No-tool-call hooks: 注入式提示钩子"""

from typing import Callable, List, Optional, Tuple, Dict, Any

# 钩子签名：(messages, assistant_message) -> Optional[Tuple[str, str]]
#   None: 不注入，继续下一个钩子
#   (role, content): 注入消息并 continue 循环
NoToolCallHook = Callable[[List[Dict[str, Any]], Any], Optional[Tuple[str, str]]]


class WebExtractNoToolCallHook:
    """
    Web 信息提取场景：当 agent 提取了网页信息但没有保存时，
    注入一次提示消息，迫使其调用 write_file/save 工具。
    
    注入规则：
    - 仅在"无 tool_call"分支触发
    - 历史消息中存在 web 类工具调用但未产生 write_file/save_* 时触发
    - 每次 AIAgent 实例仅注入一次（_injected 标记）
    """
    
    # web 类脚本生成工具
    WEB_TOOL_NAMES = frozenset({
        "web_search", "web_extract", "web_crawl",
        "browser_navigate", "browser_snapshot",
        "browser_vision", "browser_console", "browser_get_images",
    })
    
    # 保存类工具
    SAVE_TOOL_NAMES = frozenset({
        "write_file", "patch", "memory",
    })
    
    NUDGE_MESSAGE = (
        "你刚刚从网页中提取了信息，但似乎没有调用保存工具。\n\n"
        "请使用 write_file（或其他保存工具）将提取到的内容持久化。"
        "如果网站确实无法成功提取信息，请说明具体原因（例如：网络超时、"
        "反爬限制、页面无目标内容等），以便后续处理。\n\n"
        "请继续完成保存操作或明确说明提取失败的原因。"
    )
    
    def __init__(self):
        self._injected: bool = False
    
    def __call__(self, messages, assistant_message) -> Optional[Tuple[str, str]]:
        if self._injected:
            return None
        if not self._has_web_tool_in_history(messages):
            return None
        if self._has_save_tool_in_history(messages):
            return None  # 已经保存过了，无需提示
        self._injected = True
        return ("user", self.NUDGE_MESSAGE)
    
    def _has_web_tool_in_history(self, messages) -> bool:
        for msg in messages:
            if msg.get("role") != "assistant":
                continue
            for tc in msg.get("tool_calls") or []:
                if isinstance(tc, dict):
                    name = tc.get("function", {}).get("name", "")
                else:
                    name = getattr(getattr(tc, "function", None), "name", "")
                if name in self.WEB_TOOL_NAMES:
                    return True
        return False
    
    def _has_save_tool_in_history(self, messages) -> bool:
        for msg in messages:
            if msg.get("role") != "assistant":
                continue
            for tc in msg.get("tool_calls") or []:
                if isinstance(tc, dict):
                    name = tc.get("function", {}).get("name", "")
                else:
                    name = getattr(getattr(tc, "function", None), "name", "")
                if name in self.SAVE_TOOL_NAMES:
                    return True
        return False
```

**预期结果**：模块可独立 import，单元测试可覆盖各类边界。

---

### 步骤 2：在 `run_agent.py` 中注册钩子调用点

**文件**：`D:\opensource\hermes-agent\run_agent.py`

**2.1 添加 imports**（在文件顶部 imports 区域）：

```python
from hooks.no_tool_call_hooks import NoToolCallHook, WebExtractNoToolCallHook
```

**2.2 在 `AIAgent.__init__` 中初始化**（行 1477 附近，紧跟 `_budget_grace_call = False` 之后）：

```python
# No-tool-call hooks: 在 agent 给出最终文本响应前，可选择注入
# 一次提示消息给 agent 重新推理（例如：提醒保存 web 提取结果）。
# 钩子签名：NoToolCallHook = (messages, assistant_message) -> Optional[(role, content)]
# 返回 None 跳过；返回 (role, content) 时注入并 continue 循环。
self._no_tool_call_hooks: list[NoToolCallHook] = []
self._register_default_no_tool_call_hooks()
```

新增方法（放在 `__init__` 之后或类底部）：

```python
def _register_default_no_tool_call_hooks(self) -> None:
    """注册内置的 no-tool-call 钩子"""
    self._no_tool_call_hooks.append(WebExtractNoToolCallHook())
```

**2.3 在"无 tool_call"分支插入钩子调用**（行 15295-15357 之间的 `if self._has_content_after_think_block(final_response):` 分支，在 codex intermediate ack 检查之后、清理脚手架之前）：

```python
# ── No-tool-call hooks ──────────────────────────────
# 在"正常文本响应"之前，给注册的钩子一次机会注入提示消息。
# 例如：Web 提取场景下，agent 调了 web_extract 但没调 write_file，
# 钩子会注入 user 消息提醒保存，迫使其再推理一次。
if self._no_tool_call_hooks:
    _hook_assistant_msg = self._build_assistant_message(assistant_message, finish_reason)
    _hook_injected = False
    for _hook in self._no_tool_call_hooks:
        try:
            _result = _hook(messages, _hook_assistant_msg)
        except Exception as _hook_err:
            logger.debug("no_tool_call_hook error: %s", _hook_err)
            continue
        if _result is None:
            continue
        _role, _content = _result
        # 把当前 assistant 消息先 append（保证对话交替结构合法）
        messages.append(_hook_assistant_msg)
        messages.append({"role": _role, "content": _content,
                        "_no_tool_call_hook": True})
        _hook_injected = True
        break  # 一次只注入一个 hook，避免重复提示
    if _hook_injected:
        self._save_session_log(messages)
        continue
```

**预期结果**：
- web 提取场景：第一次无 tool_call → 注入保存提示 → 回到循环 → agent 调 write_file → 正常 break
- 非 web 场景：钩子跳过，按原逻辑 break
- 第二次进入"无 tool_call"：钩子 `_injected=True` 跳过，按原逻辑 break
- `max_iterations` 兜底：若 agent 一直不调保存，循环耗尽后正常退出

---

### 步骤 3：单元测试

**新建文件**：`D:\opensource\hermes-agent\tests\test_no_tool_call_hooks.py`

**测试用例**：

1. `test_web_hook_triggers_after_web_tool_call` — 消息历史中有 `web_extract` 调用，无保存类工具 → 返回 `(user, ...)`
2. `test_web_hook_skips_when_no_web_tool` — 消息历史中无 web 工具 → 返回 `None`
3. `test_web_hook_skips_when_already_saved` — 已有 `write_file` 调用 → 返回 `None`
4. `test_web_hook_only_injects_once` — 连续两次调用 → 第一次返回注入，第二次返回 `None`
5. `test_web_hook_handles_dict_and_object_tool_calls` — 兼容 `tool_calls` 字段为 dict 或 SDK 对象两种形式
6. `test_web_hook_integration_with_run_conversation` — 模拟 `run_conversation` 注入后，验证 messages 中包含 `_no_tool_call_hook=True` 标记

**预期结果**：所有测试通过；与现有测试无冲突。

---

### 步骤 4：执行与验证

1. **静态检查**：
   - `python -c "import hooks.no_tool_call_hooks"` — 验证模块可导入
   - `python -c "from hooks.no_tool_call_hooks import WebExtractNoToolCallHook; h = WebExtractNoToolCallHook(); print(h.NUDGE_MESSAGE)"` — 验证常量正确

2. **运行测试**：
   - `pytest tests/test_no_tool_call_hooks.py -v` — 新增测试
   - `pytest tests/ -x -k "agent or hook or budget"` — 回归测试，确认原有逻辑未受影响

3. **手动验证脚本**（可选）：
   - 构造一个简化的 mock `assistant_message`，验证钩子在不同 `messages` 历史下的行为

---

## 关键文件清单

| 文件 | 类型 | 说明 |
|------|------|------|
| `hooks/__init__.py` | 新建（如果不存在） | 包标识 |
| `hooks/no_tool_call_hooks.py` | 新建 | 钩子定义和 `WebExtractNoToolCallHook` |
| `run_agent.py` | 修改 | 添加 imports、初始化、调用点 |
| `tests/test_no_tool_call_hooks.py` | 新建 | 单元测试 |

## 风险与回退

- **风险 1**：钩子注入导致对话历史膨胀 → 通过 `_injected` 标记保证单次注入
- **风险 2**：钩子异常导致主循环崩溃 → 钩子调用包在 `try/except` 中
- **风险 3**：`messages.append` 顺序错误导致 API 报错 → 先 append 当前 assistant 消息再 append user 提示，保持对话交替结构
- **回退方案**：若新逻辑引发问题，将 `AIAgent.__init__` 中 `self._register_default_no_tool_call_hooks()` 改为注释即可禁用

## 上下文

- 工作目录：`D:\opensource\hermes-agent\`
- 主循环入口：`run_agent.py` 行 12275 (`while ...`)
- "无 tool_call" 分支：`run_agent.py` 行 15027-15357
- AIAgent 类：`run_agent.py` 行 1098
- 相关上下文：现有 _post_tool_empty_retried（行 11923）/_budget_grace_call（行 1478）/_handle_max_iterations（行 11612）注入模式可参考
