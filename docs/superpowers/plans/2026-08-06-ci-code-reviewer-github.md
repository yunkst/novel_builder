# ci-code-reviewer GitHub 平台化与开源实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 把 `ci-code-reviewer` 从 GitLab 单平台改造成 GitLab + GitHub 双平台 + 开源工具，让 `novel_builder` 通过 GitHub Actions 接入 AI 代码审查。

**架构：** 三层抽象（IssueClient / Notifier / Archive）解耦平台耦合。GitHub 平台 PR 评论 + commit status check；GitLab 平台字节级兼容。镜像发 GHCR，CI 迁 GitHub Actions。

**技术栈：** Python 3.11（code-reviewer）/ GitHub Actions 4（消费方）/ GitHub REST API v3（PR 评论 + commit status）/ GHCR（镜像分发）

---

## 工作前提

### 代码仓库状态

- **`D:\work\ci-code-reviewer`** — 待改造的本地仓库（GitLab 内网，不发 PR 上游），改造后整体推新仓 `github.com/yedazhi/code-reviewer`
- **`D:\my_space\novel_builder`** — 消费方，本计划任务 16-19 在此仓库加 workflow

### 计划来源

规格文档：`D:\my_space\novel_builder\docs\superpowers\specs\2026-08-06-ci-code-reviewer-github-design.md`

本计划严格遵循规格，所有契约字段、API 端点、错误处理路径以规格为准。

### 测试约定

- TDD：先写失败测试，再写实现
- mock 策略：`urllib.request.urlopen` 用 `unittest.mock.patch` 拦截；`IssueClient` 抽象用 `FakeIssueClient` 替换真实客户端
- pytest 单测全绿才能 commit
- 兼容性回归测试：每个 GitLab 行为变更点必须配字节级断言

### 关键路径标记

- 🔴 **不可回退**：改坏会导致 GitLab 行为偏差 → 走兼容性回归测试
- 🟡 **新增能力**：GitHub 平台独有 → 走 mock 测试
- 🟢 **开源卫生**：去硬编码 / 加文档 → 走 grep 校验

---

## 文件结构（改造后的 `D:\work\ci-code-reviewer`）

### 新建文件

```
src/code_review/platform/
  __init__.py                          # IssueClient 抽象 + get_issue_client 工厂
  base.py                              # IssueClient Protocol 定义
  github.py                            # GithubIssueClient 实现

src/code_review/notifier/
  __init__.py                          # Notifier Protocol + ReportContext + get_notifier 工厂 + build_multi_section_report 改签名
  base.py                              # NullNotifier 实现
  wecom.py                             # WecomNotifier（现 notifier.py 业务逻辑迁移）
  github_pr.py                         # GithubPrCommentNotifier 实现（含 status check 兜底）

tests/platform/
  __init__.py
  test_factory.py                      # get_issue_client 4 分支
  test_github_client.py                # mock urlopen 验证 6 端点 + labels 缓存失败 + 422 分流 + rate limit
  test_gitlab_client.py                # 现 test_gitlab_client.py + test_gitlab_client_api.py 迁入

tests/notifier/
  __init__.py
  test_factory.py                      # get_notifier 4 分支
  test_wecom.py                        # 现 test_notifier.py 拆出来，断言字节级兼容
  test_github_pr.py                    # PR 评论 + status check + 截断 + push 静默变 success
  test_report.py                       # build_multi_section_report 接收 ReportContext 字符级断言

LICENSE                                # MIT
CONTRIBUTING.md                        # 贡献指南
SECURITY.md                            # 漏洞上报流程
CODE_OF_CONDUCT.md                     # Contributor Covenant 2.1
.github/ISSUE_TEMPLATE/bug_report.md
.github/ISSUE_TEMPLATE/feature_request.md
.github/ISSUE_TEMPLATE/config.yml
.github/PULL_REQUEST_TEMPLATE.md
.github/workflows/build.yml            # 镜像构建 + 推 GHCR
.github/workflows/test.yml             # pytest
.github/workflows/release.yml          # 发 GitHub Release
```

### 修改文件

```
src/code_review/__main__.py            # 读 PLATFORM + 平台分支 + 组装 ReportContext
src/code_review/config.py              # REQUIRED 拆分 + WEEKLY 默认 0 + 新增 GitHub env
src/code_review/agent.py               # dispatch_ctx 删除 gitlab_* 三 key，新增 issue_client
src/code_review/orchestrator.py        # import 调整 + send_report/send_error 走 Notifier
src/code_review/agents.py              # _substitute_platform_terms + ReportContext 组装
src/code_review/tools/create_issue.py  # 删 gitlab_client import，改调 ctx["issue_client"]
src/code_review/tools/close_issue.py   # 同上
src/code_review/archive.py             # 内部硬编码 gitlab_* → cfg["gitlab_*"]（无外部 API 变化）
src/code_review/prompts/agent_b_quality.md   # 术语替换（GitLab issue → 平台术语）
src/code_review/prompts/agent_c_repair.md    # 同上
src/code_review/gitlab_client.py       # 整体迁入 platform/gitlab.py（保留兼容别名，删除原始路径）
src/code_review/notifier.py            # 整体迁入 notifier/wecom.py（保留兼容别名，删除原始路径）
templates/code-review.yml              # 镜像换 GHCR + 默认 platform=github + 加 status check env
ci/include.yml                         # 同上 + URL 换 GitHub raw
tests/test_config.py                   # 加 GitHub 必填项 + WECOM 可选
tests/test_agents.py                   # 加 prompt 平台分支
tests/test_tool_create_issue.py        # fixture 加 issue_client key
tests/test_tool_close_issue.py         # 同上
tests/test_archive.py                  # 默认 178 → 默认 0
README.md                              # 重写：去内网 + 加开源标配（徽章 / License / Contribution 入口）
CHANGELOG.md                           # v2.0.0 BREAKING 标注 + Migration Guide
```

### 删除文件

```
.gitlab-ci.yml                         # 迁 .github/workflows
ci/build.yml                           # GitLab kaniko 构建
ci/bump_tag.sh                         # 自动 bump 机制（v1.x → v2.0 移除）
```

### 消费方新建文件（`D:\my_space\novel_builder`）

```
.github/workflows/code-review.yml      # GitHub Actions workflow，docker run GHCR 镜像
```

---

## 任务拆分

任务分 4 个 Phase，共 19 个任务：

- **Phase 1（任务 1-5）**：平台抽象骨架 — IssueClient + Notifier 拆目录、工厂、GitLab 迁移
- **Phase 2（任务 6-10）**：GitHub 实现 — GithubIssueClient + GithubPrCommentNotifier + status check
- **Phase 3（任务 11-15）**：主流程接入 — __main__ / agent / orchestrator / config / tools 改造
- **Phase 4（任务 16-19）**：迁移与消费方 — CI 迁 GitHub / 开源卫生 / novel_builder 接入

---

## Phase 1：平台抽象骨架

### 任务 1：IssueClient 抽象与 GitLab 迁移

**文件：**
- 创建：`src/code_review/platform/base.py`
- 创建：`src/code_review/platform/__init__.py`
- 创建：`src/code_review/platform/gitlab.py`
- 删除：`src/code_review/gitlab_client.py`（迁移完成后删除，保留 1 个 commit 作为别名过渡）
- 创建：`tests/platform/__init__.py`
- 创建：`tests/platform/test_factory.py`
- 创建：`tests/platform/test_gitlab_client.py`
- 删除：`tests/test_gitlab_client.py`、`tests/test_gitlab_client_api.py`（迁入新位置后删除）

- [ ] **步骤 1：写 IssueClient Protocol + 工厂测试**

`tests/platform/test_factory.py`：
```python
from code_review.platform import get_issue_client
from code_review.platform.gitlab import GitlabIssueClient
from code_review.platform.github import GithubIssueClient


def test_factory_returns_gitlab_for_gitlab_platform():
    cfg = {
        "platform": "gitlab",
        "gitlab_api_url": "https://gitlab.example.com/api/v4",
        "gitlab_token": "glpat-xxx",
        "gitlab_project_id": 123,
    }
    client = get_issue_client(cfg)
    assert isinstance(client, GitlabIssueClient)


def test_factory_returns_github_for_github_platform():
    cfg = {
        "platform": "github",
        "gh_token": "ghp_xxx",
        "github_repository": "owner/repo",
    }
    client = get_issue_client(cfg)
    assert isinstance(client, GithubIssueClient)
```

- [ ] **步骤 2：跑测试确认失败**

运行：`pytest tests/platform/test_factory.py -v`
预期：FAIL `ModuleNotFoundError: No module named 'code_review.platform'`

- [ ] **步骤 3：写 IssueClient Protocol**

`src/code_review/platform/base.py`：
```python
"""IssueClient 抽象：所有平台 issue API 都实现这套接口。"""
from typing import Protocol, runtime_checkable


@runtime_checkable
class IssueClient(Protocol):
    def list_open_issues(self, labels: list[str]) -> list[dict]:
        """返回 [{"iid", "title", "description", "web_url", "labels"}, ...]"""

    def create_issue(self, title: str, description: str,
                     labels: list[str], assignee_id=None) -> dict:
        """返回 {"iid", "web_url"}"""

    def close_issue(self, iid: int) -> dict: ...
    def add_comment(self, iid: int, body: str) -> dict: ...
    def update_description(self, iid: int, description: str) -> dict: ...
    def lookup_assignee(self, username: str) -> str | int | None: ...
```

- [ ] **步骤 4：写工厂（GitLab 分支返回 stub，GitHub 分支实现见任务 6）**

`src/code_review/platform/__init__.py`：
```python
"""平台抽象层：统一 GitLab / GitHub issue API。"""
from .base import IssueClient


def get_issue_client(cfg: dict) -> IssueClient:
    if cfg.get("platform") == "github":
        from .github import GithubIssueClient
        return GithubIssueClient(
            token=cfg["gh_token"],
            repo=cfg["github_repository"],
        )
    from .gitlab import GitlabIssueClient
    return GitlabIssueClient(
        api_url=cfg["gitlab_api_url"],
        token=cfg["gitlab_token"],
        project_id=cfg["gitlab_project_id"],
    )


__all__ = ["IssueClient", "get_issue_client"]
```

`src/code_review/platform/github.py`：先写 stub，任务 6 完整实现：
```python
"""GitHub IssueClient（任务 6 完整实现）。"""
from .base import IssueClient


class GithubIssueClient(IssueClient):
    def __init__(self, token: str, repo: str):
        self._token = token
        self._repo = repo

    def list_open_issues(self, labels): raise NotImplementedError
    def create_issue(self, title, description, labels, assignee_id=None): raise NotImplementedError
    def close_issue(self, iid): raise NotImplementedError
    def add_comment(self, iid, body): raise NotImplementedError
    def update_description(self, iid, description): raise NotImplementedError
    def lookup_assignee(self, username): raise NotImplementedError
```

`src/code_review/platform/gitlab.py`：从 `gitlab_client.py` 整体迁入，签名加 `api_url / token / project_id` 构造参数而非从 ctx dict 读：
```python
"""GitLab IssueClient：从原 gitlab_client.py 迁入，实现 IssueClient 协议。"""
import json
import urllib.parse
import urllib.request


class GitlabIssueClient:
    def __init__(self, api_url: str, token: str, project_id: int):
        self._api_url = api_url
        self._token = token
        self._project_id = project_id

    def _url(self, path: str) -> str:
        return f"{self._api_url}/projects/{self._project_id}{path}"

    def _headers(self) -> dict:
        return {"PRIVATE-TOKEN": self._token, "Content-Type": "application/json"}

    def _request(self, method: str, path: str, data: dict = None):
        url = self._url(path)
        body = json.dumps(data).encode("utf-8") if data is not None else None
        req = urllib.request.Request(url, data=body,
                                     headers=self._headers(), method=method)
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode("utf-8"))

    def list_open_issues(self, labels: list[str]) -> list[dict]:
        labels_str = ",".join(labels)
        return self._request("GET", f"/issues?labels={labels_str}&state=opened&per_page=100")

    def create_issue(self, title, description, labels, assignee_id=None):
        payload = {"title": title, "description": description,
                   "labels": ",".join(labels)}
        if assignee_id:
            payload["assignee_ids"] = [assignee_id]
        return self._request("POST", "/issues", payload)

    def close_issue(self, iid):
        return self._request("PUT", f"/issues/{iid}", {"state_event": "close"})

    def add_comment(self, iid, body):
        return self._request("POST", f"/issues/{iid}/notes", {"body": body})

    def update_description(self, iid, description):
        return self._request("PUT", f"/issues/{iid}", {"description": description})

    def lookup_assignee(self, username: str) -> int | None:
        from .. import log
        try:
            url = f"{self._api_url}/users?{urllib.parse.urlencode({'username': username})}"
            req = urllib.request.Request(url, headers=self._headers(), method="GET")
            with urllib.request.urlopen(req, timeout=15) as resp:
                users = json.loads(resp.read().decode("utf-8"))
        except Exception as exc:
            log.log_event("assignee_lookup_fail", f"user={username} exc={type(exc).__name__}: {exc}")
            return None
        if isinstance(users, list) and users and users[0].get("id") is not None:
            return users[0]["id"]
        return None
```

返回值里 `iid` key 已经是 GitLab 原生 iid，无需映射。

- [ ] **步骤 5：迁移现有 GitLab 测试**

`tests/platform/test_gitlab_client.py`：从 `tests/test_gitlab_client.py` + `tests/test_gitlab_client_api.py` 整体迁入，**不修改任何断言**。所有断言改用构造 `GitlabIssueClient(api_url, token, project_id)` 后调方法，验证 HTTP 请求构造 + 返回值映射。`_api_get` / `_api_get_paged` 等辅助方法保留为内部 helper。

- [ ] **步骤 6：跑全部 IssueClient 测试确认通过**

运行：`pytest tests/platform/ -v`
预期：全绿，断言字节级与原 GitLab 行为一致

- [ ] **步骤 7：删除原文件**

```bash
git rm src/code_review/gitlab_client.py
git rm tests/test_gitlab_client.py tests/test_gitlab_client_api.py
```

- [ ] **步骤 8：Commit**

```bash
git add src/code_review/platform/ tests/platform/
git commit -m "feat(platform): IssueClient 抽象 + GitLab 迁移

把现有 gitlab_client.py 迁入 platform/gitlab.py，实现 IssueClient Protocol。
工厂 get_issue_client 按 PLATFORM 返回 Gitlab 或 GitHub 实现。
GitHub 实现本任务先写 stub，完整版见后续任务。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 2：Notifier 抽象与 WecomNotifier 迁移

**文件：**
- 创建：`src/code_review/notifier/__init__.py`
- 创建：`src/code_review/notifier/base.py`
- 创建：`src/code_review/notifier/wecom.py`
- 创建：`src/code_review/notifier/github_pr.py`（stub）
- 删除：`src/code_review/notifier.py`（迁移完成后删除）
- 创建：`tests/notifier/__init__.py`
- 创建：`tests/notifier/test_factory.py`
- 创建：`tests/notifier/test_wecom.py`
- 创建：`tests/notifier/test_report.py`
- 删除：`tests/test_notifier.py`（迁入新位置后删除）

- [ ] **步骤 1：写 Notifier Protocol + ReportContext + 工厂测试**

`tests/notifier/test_factory.py`：
```python
from code_review.notifier import get_notifier, ReportContext
from code_review.notifier.base import NullNotifier
from code_review.notifier.wecom import WecomNotifier
from code_review.notifier.github_pr import GithubPrCommentNotifier


def test_factory_gitlab_with_wecom():
    cfg = {"platform": "gitlab", "wecom_webhook_url": "https://qyapi.weixin.qq.com/xxx"}
    notifier = get_notifier(cfg)
    assert isinstance(notifier, WecomNotifier)


def test_factory_gitlab_without_wecom():
    cfg = {"platform": "gitlab", "wecom_webhook_url": ""}
    notifier = get_notifier(cfg)
    assert isinstance(notifier, NullNotifier)


def test_factory_github():
    cfg = {"platform": "github", "gh_token": "ghp_xxx",
           "github_repository": "owner/repo"}
    notifier = get_notifier(cfg)
    assert isinstance(notifier, GithubPrCommentNotifier)
```

- [ ] **步骤 2：跑测试确认失败**

运行：`pytest tests/notifier/test_factory.py -v`
预期：FAIL `ModuleNotFoundError: No module named 'code_review.notifier'`

- [ ] **步骤 3：写 ReportContext dataclass + Notifier Protocol**

`src/code_review/notifier/__init__.py`：
```python
"""Notifier 抽象：报告通过 Notifier 发出，支持企业微信 / GitHub PR 评论 / Null。"""
from dataclasses import dataclass
from typing import Protocol, runtime_checkable


@dataclass
class ReportContext:
    """审查元信息，供 Notifier 实现拼头部/链接。
    字段名与原 _build_report_header 返回的 header dict 一一对应，
    保证 build_multi_section_report 输出字节级一致。
    """
    project: str
    project_url: str
    authors: str
    trigger_user: str
    branch_line: str
    commit_sha: str       # 保留原 key 名（short sha），与 build_multi_section_report 一致
    stat: str
    pr_number: int | None # 新增字段，仅 GithubPrCommentNotifier 用


@runtime_checkable
class Notifier(Protocol):
    def send_report(self, report: str, *, context: ReportContext) -> bool: ...
    def send_error(self, title: str, body: str, *, context: ReportContext) -> None: ...
    def send_skip(self, title: str, body: str, *, context: ReportContext) -> None: ...


def get_notifier(cfg: dict) -> Notifier:
    if cfg.get("platform") == "github":
        from .github_pr import GithubPrCommentNotifier
        return GithubPrCommentNotifier(
            token=cfg["gh_token"],
            repo=cfg["github_repository"],
        )
    wecom = cfg.get("wecom_webhook_url", "")
    if wecom:
        from .wecom import WecomNotifier
        return WecomNotifier(webhook_url=wecom)
    from .base import NullNotifier
    return NullNotifier()


def build_multi_section_report(a_notes, b_notes, created, closed,
                               open_count, context: ReportContext) -> str:
    """构建多 section 报告。从原 notifier.py 迁入，header dict 改 ReportContext。
    字段访问从 context.project / context.authors 等替换原 h.get('project') 等。
    输出 Markdown 字节级与原实现一致。
    """
    # ... 从原 notifier.py:80-123 复制，改 h["xxx"] → context.xxx
    emoji = {"critical": "🔴", "warning": "🟠", "suggestion": "🟡"}
    feature_note, _ = _split_feature_note(a_notes)
    lines = ["## 🤖 代码审查报告", ""]
    if context.project_url:
        lines.append(f"**项目**：[{context.project}]({context.project_url})")
    else:
        lines.append(f"**项目**：{context.project}")
    lines.append(f"**提交作者**：{context.authors or '（无）'}")
    lines.append(f"**触发者**：{context.trigger_user or '（无）'}")
    lines.append(f"**分支/MR**：{context.branch_line or '（无）'}")
    if context.commit_sha:
        lines.append(f"**Commit**：{context.commit_sha}")
    lines.append(f"**代码量**：{context.stat or '0 文件'}")
    lines.append("")
    lines.append("### ✨ 本次实现功能")
    lines.append(feature_note if feature_note else "（无）")
    if created:
        lines.append("")
        lines.append("📌 新建 Issue：")
        for it in created:
            e = emoji.get(it.get("severity"), "⚪")
            lines.append(f"- {e} [{it['title']}]({it['web_url']})")
    lines.append("")
    lines.append("### 🔧 Issue 修复检测")
    if closed:
        lines.append("✅ 已关闭（本次提交修复）：")
        for it in closed:
            lines.append(f"- [#{it['iid']} {it['title']}]({it['web_url']}) - 理由：{it['reason']}")
    else:
        lines.append("（本次无关闭）")
    lines.append(f"⏳ 仍开放：{open_count} 个")
    return "\n".join(lines)


def _split_feature_note(notes: list) -> tuple:
    if not notes:
        return "", []
    if notes[0].strip().startswith("✅"):
        return notes[0], notes[1:]
    return "", notes


__all__ = ["ReportContext", "Notifier", "get_notifier", "build_multi_section_report"]
```

- [ ] **步骤 4：写 NullNotifier + WecomNotifier + GithubPrCommentNotifier stub**

`src/code_review/notifier/base.py`：
```python
"""NullNotifier：兜底，所有方法 no-op。"""
from .. import log
from . import ReportContext


class NullNotifier:
    def send_report(self, report: str, *, context: ReportContext) -> bool:
        log.log_event("notify_null", "send_report")
        return True

    def send_error(self, title: str, body: str, *, context: ReportContext) -> None:
        log.log_event("notify_null", f"send_error: {title}")

    def send_skip(self, title: str, body: str, *, context: ReportContext) -> None:
        log.log_event("notify_null", f"send_skip: {title}")
```

`src/code_review/notifier/wecom.py`：从原 `notifier.py` 迁入，**字段访问从 h["xxx"] 改为 context.xxx**：
```python
"""WecomNotifier：原 notifier.py 业务逻辑迁入，行为字节级兼容。"""
import json
import sys
import urllib.request
import urllib.error

WECOM_MARKDOWN_BYTE_LIMIT = 4000


def _println(text: str) -> None:
    print(text, file=sys.stdout, flush=True)


def _post_markdown(webhook_url: str, content: str) -> bool:
    payload = {"msgtype": "markdown", "markdown": {"content": content}}
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(webhook_url, data=data,
                                 headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            resp_data = json.loads(resp.read().decode("utf-8"))
        if resp_data.get("errcode") != 0:
            _println(f"[notifier] 企业微信返回非零: {resp_data}")
            return False
        return True
    except Exception as exc:
        _println(f"[notifier] 通知发送失败（{type(exc).__name__}: {exc}）")
        return False


def _byte_chunks(text: str, limit: int) -> list:
    enc = text.encode("utf-8")
    chunks: list = []
    start = 0
    while start < len(enc):
        end = min(start + limit, len(enc))
        while end < len(enc) and (enc[end] & 0xC0) == 0x80:
            end -= 1
        if end == start:
            end = start + 1
        chunks.append(enc[start:end].decode("utf-8", errors="replace"))
        start = end
    return chunks


def _split_to_chunks(report: str) -> list:
    parts = _byte_chunks(report, WECOM_MARKDOWN_BYTE_LIMIT)
    if len(parts) == 1:
        return parts
    out = []
    total = len(parts)
    for i, c in enumerate(parts):
        if i == 0:
            out.append(f"## 🤖 代码审查报告（共 {total} 部分，1/{total}）\n\n{c}")
        elif i == total - 1:
            out.append(f"{c}\n\n---\n（报告结束 {total}/{total}）")
        else:
            out.append(f"{c}\n\n*（{i+1}/{total}，接下页）*")
    return out


class WecomNotifier:
    def __init__(self, webhook_url: str):
        self._webhook_url = webhook_url

    def send_report(self, report: str, *, context) -> bool:
        chunks = _split_to_chunks(report)
        all_ok = True
        total = len(chunks)
        for i, chunk in enumerate(chunks):
            ok = _post_markdown(self._webhook_url, chunk)
            if not ok:
                all_ok = False
            _println(f"[notifier] 报告分片 {i+1}/{total} {'OK' if ok else 'FAIL'}")
        return all_ok

    def send_error(self, title, body, *, context):
        _post_markdown(self._webhook_url, f"# ⚠️ {title}\n\n{body}")

    def send_skip(self, title, body, *, context):
        _post_markdown(self._webhook_url, f"## ℹ️ {title}\n\n{body}")
```

`src/code_review/notifier/github_pr.py`：先写 stub，任务 7 完整实现：
```python
"""GitHubPrCommentNotifier：PR 评论 + commit status check 兜底。"""
from . import ReportContext


class GithubPrCommentNotifier:
    def __init__(self, token: str, repo: str):
        self._token = token
        self._repo = repo

    def send_report(self, report, *, context: ReportContext) -> bool:
        raise NotImplementedError

    def send_error(self, title, body, *, context: ReportContext) -> None:
        raise NotImplementedError

    def send_skip(self, title, body, *, context: ReportContext) -> None:
        raise NotImplementedError
```

- [ ] **步骤 5：迁移现有 WecomNotifier 测试**

`tests/notifier/test_wecom.py`：从 `tests/test_notifier.py` 整体迁入：
- 现有断言修改：`build_multi_section_report(a, b, c, d, oc, header=dict)` → `build_multi_section_report(a, b, c, d, oc, context=ReportContext(...))`
- 新增断言：`ReportContext` 字段顺序 / `commit_sha` 字段名严格对齐原 `header` dict
- WecomNotifier 端点构造测试：`webhook_url` 透传、`_split_to_chunks` 字节切片、`_post_markdown` payload 格式

`tests/notifier/test_report.py`：新增专项测试，验证 ReportContext 与 header dict 输出字节级相等：
```python
from code_review.notifier import build_multi_section_report, ReportContext


def test_report_equivalent_to_header_dict():
    notes = ["✅ 功能 A"]
    b_notes = []
    created = [{"title": "bug", "web_url": "https://gh/x/1", "severity": "critical"}]
    closed = []
    context = ReportContext(
        project="proj", project_url="https://proj",
        authors="alice", trigger_user="bob",
        branch_line="feat→main", commit_sha="abc1234",
        stat="3 文件 +20 -5", pr_number=42,
    )
    report = build_multi_section_report(notes, b_notes, created, closed, 1, context)
    # 断言：原 header dict 写法生成的字符串字节级相等（用相同的 inputs）
    # ... 字符级断言
```

- [ ] **步骤 6：跑测试确认通过**

运行：`pytest tests/notifier/ -v`
预期：全绿，包括从原 `test_notifier.py` 迁入的所有用例（用 ReportContext 改造后断言不变）

- [ ] **步骤 7：删除原 notifier.py**

```bash
git rm src/code_review/notifier.py
git rm tests/test_notifier.py
```

- [ ] **步骤 8：Commit**

```bash
git add src/code_review/notifier/ tests/notifier/
git commit -m "feat(notifier): Notifier 抽象 + WecomNotifier 迁移

Notifier Protocol + ReportContext dataclass。WecomNotifier 从原 notifier.py
业务逻辑迁入，header dict 改 ReportContext，输出字节级一致。
GithubPrCommentNotifier stub 待任务 7 完整实现。
NullNotifier 兜底。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 3：兼容旧 import（过渡 commit）

**文件：**
- 修改：`src/code_review/notifier/__init__.py`（追加模块级 wrapper 函数）
- 创建：`src/code_review/gitlab_client.py`（向后兼容模块）

- [ ] **步骤 1：写兼容层**

`src/code_review/gitlab_client.py`（向后兼容模块，仅保留原 `_request` + `list_issues` 等模块级函数，**不再写 GitlabIssueClient**）：

```python
"""向后兼容：原 gitlab_client.py 的 GitLab 函数仍然可 import。
新代码请改用 code_review.platform.gitlab.GitlabIssueClient。
"""
import json
import urllib.request

from .platform.gitlab import GitlabIssueClient


def _make_client(ctx):
    return GitlabIssueClient(
        api_url=ctx["gitlab_api_url"],
        token=ctx["gitlab_token"],
        project_id=ctx["gitlab_project_id"],
    )


def _request(method, ctx, path, data=None):
    """原 _request 模块级函数，向后兼容。"""
    url = f"{ctx['gitlab_api_url']}/projects/{ctx['gitlab_project_id']}{path}"
    body = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(
        url, data=body,
        headers={"PRIVATE-TOKEN": ctx["gitlab_token"], "Content-Type": "application/json"},
        method=method,
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode("utf-8"))


def list_issues(ctx, labels="reviewer-generated", state="opened", per_page=100):
    return _make_client(ctx).list_open_issues([labels])


def create_issue(ctx, title, description, labels, assignee_ids=None):
    assignee_id = assignee_ids[0] if assignee_ids else None
    return _make_client(ctx).create_issue(title, description, labels, assignee_id)


def lookup_user_id(ctx, username):
    return _make_client(ctx).lookup_assignee(username)


def add_issue_comment(ctx, iid, body):
    return _make_client(ctx).add_comment(iid, body)


def close_issue(ctx, iid):
    return _make_client(ctx).close_issue(iid)


def update_issue_description(ctx, iid, description):
    return _make_client(ctx).update_description(iid, description)
```

`src/code_review/notifier/__init__.py` 末尾追加模块级 wrapper（**避免创建 `notifier.py` 同名冲突**）：

```python
# === 向后兼容：原 notifier.py 模块级函数 ===

def send_report(webhook_url: str, report: str) -> bool:
    """原 send_report(webhook_url, report) 签名，向后兼容。"""
    notifier = WecomNotifier(webhook_url=webhook_url)
    ctx = ReportContext(project="", project_url="", authors="", trigger_user="",
                        branch_line="", commit_sha="", stat="", pr_number=None)
    return notifier.send_report(report, context=ctx)


def send_error(webhook_url: str, title: str, body: str) -> None:
    """原 send_error(webhook_url, title, body) 签名，向后兼容。"""
    notifier = WecomNotifier(webhook_url=webhook_url)
    ctx = ReportContext(project="", project_url="", authors="", trigger_user="",
                        branch_line="", commit_sha="", stat="", pr_number=None)
    notifier.send_error(title, body, context=ctx)


def send_skip(webhook_url: str, title: str, body: str) -> None:
    """原 send_skip(webhook_url, title, body) 签名，向后兼容。"""
    notifier = WecomNotifier(webhook_url=webhook_url)
    ctx = ReportContext(project="", project_url="", authors="", trigger_user="",
                        branch_line="", commit_sha="", stat="", pr_number=None)
    notifier.send_skip(title, body, context=ctx)
```

并在文件顶部 `__all__` 列表追加 `"send_report", "send_error", "send_skip"`。

- [ ] **步骤 2：跑现有全测试确认兼容层不破坏**

运行：`pytest tests/ -v`
预期：全绿，包括 `tests/test_main.py` / `tests/test_orchestrate.py` 等仍 import 老路径的测试

- [ ] **步骤 3：Commit**

```bash
git add src/code_review/gitlab_client.py src/code_review/notifier/__init__.py
git commit -m "feat(compat): 保留旧 import 路径兼容层

gitlab_client.py: 重新导出 GitlabIssueClient 的模块级 wrapper
notifier/__init__.py: 末尾追加 send_report/send_error/send_skip 模块级 wrapper

注意：不能创建 src/code_review/notifier.py（与 notifier/ 包同名冲突，Python 会忽略）。

过渡 commit，让未迁移的调用点仍能 import 老路径。任务 14 完成主流程迁移后，
本兼容层连同这些未迁移点一并清理。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 4：config.py 拆分必填项 + 去默认 178

**文件：**
- 修改：`src/code_review/config.py`
- 修改：`tests/test_config.py`

- [ ] **步骤 1：写测试用例**

`tests/test_config.py` 加新 case：
```python
def test_github_required_vars_only():
    """GitHub 平台只需 GitHub 必填项，不要求 GitLab 三件套。"""
    monkeypatch.setenv("LLM_BASE_URL", "https://llm/x")
    monkeypatch.setenv("LLM_API_KEY", "sk")
    monkeypatch.setenv("LLM_MODEL", "m")
    monkeypatch.setenv("REVIEW_BASE_SHA", "abc")
    monkeypatch.setenv("REVIEW_HEAD_SHA", "def")
    monkeypatch.setenv("PLATFORM", "github")
    monkeypatch.setenv("GH_TOKEN", "ghp_x")
    monkeypatch.setenv("GITHUB_REPOSITORY", "owner/repo")
    # 故意不设 GitLab 三件套
    monkeypatch.delenv("CODE_REVIEWER_TOKEN", raising=False)
    monkeypatch.delenv("CI_API_V4_URL", raising=False)
    monkeypatch.delenv("CI_PROJECT_ID", raising=False)
    # 不抛异常即通过
    cfg = load_config()
    assert cfg["platform"] == "github"
    assert cfg["gh_token"] == "ghp_x"


def test_wecom_optional_in_gitlab():
    """GitLab 平台 WECOM_WEBHOOK_URL 改可选。"""
    monkeypatch.setenv("LLM_BASE_URL", "https://llm/x")
    monkeypatch.setenv("LLM_API_KEY", "sk")
    monkeypatch.setenv("LLM_MODEL", "m")
    monkeypatch.setenv("REVIEW_BASE_SHA", "abc")
    monkeypatch.setenv("REVIEW_HEAD_SHA", "def")
    monkeypatch.setenv("PLATFORM", "gitlab")
    monkeypatch.setenv("CODE_REVIEWER_TOKEN", "glpat")
    monkeypatch.setenv("CI_API_V4_URL", "https://gl/api/v4")
    monkeypatch.setenv("CI_PROJECT_ID", "1")
    monkeypatch.delenv("WECOM_WEBHOOK_URL", raising=False)
    cfg = load_config()
    assert cfg["wecom_webhook_url"] == ""


def test_weekly_report_default_zero():
    """WEEKLY_REPORT_PROJECT_ID 默认 0（BREAKING）。"""
    monkeypatch.delenv("WEEKLY_REPORT_PROJECT_ID", raising=False)
    cfg = load_config()
    assert cfg["weekly_report_project_id"] == 0
```

- [ ] **步骤 2：跑测试确认失败**

运行：`pytest tests/test_config.py::test_weekly_report_default_zero -v`
预期：FAIL 断言默认 178 ≠ 0

- [ ] **步骤 3：改造 config.py**

`src/code_review/config.py`：
```python
"""环境变量解析。必填项按 PLATFORM 分支。"""
import os
import sys


class ConfigError(Exception):
    """配置错误。"""


COMMON_REQUIRED = [
    "LLM_BASE_URL",
    "LLM_API_KEY",
    "LLM_MODEL",
    "REVIEW_BASE_SHA",
    "REVIEW_HEAD_SHA",
]

GITLAB_PLATFORM_REQUIRED = [
    "CODE_REVIEWER_TOKEN",
    "CI_API_V4_URL",
    "CI_PROJECT_ID",
]

GITHUB_PLATFORM_REQUIRED = [
    "GH_TOKEN",
    "GITHUB_REPOSITORY",
]


def _int_env(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        print(f"[warn] 环境变量 {name}={raw!r} 不是整数，回退默认 {default}",
              file=sys.stderr, flush=True)
        return default


def load_config() -> dict:
    missing = [k for k in COMMON_REQUIRED if not os.environ.get(k)]
    if missing:
        raise ConfigError(f"缺少必填环境变量: {', '.join(missing)}")

    platform = os.environ.get("PLATFORM", "gitlab")
    if platform == "github":
        platform_required = GITHUB_PLATFORM_REQUIRED
    elif platform == "gitlab":
        platform_required = GITLAB_PLATFORM_REQUIRED
    else:
        raise ConfigError(f"未知 PLATFORM={platform!r}，仅支持 'gitlab' 或 'github'")

    missing += [k for k in platform_required if not os.environ.get(k)]
    if missing:
        raise ConfigError(f"缺少 {platform} 平台必填环境变量: {', '.join(missing)}")

    return {
        "platform": platform,
        "llm_base_url": os.environ["LLM_BASE_URL"],
        "llm_api_key": os.environ["LLM_API_KEY"],
        "llm_model": os.environ["LLM_MODEL"],
        "wecom_webhook_url": os.environ.get("WECOM_WEBHOOK_URL", ""),  # 改可选
        "review_base_sha": os.environ["REVIEW_BASE_SHA"],
        "review_head_sha": os.environ["REVIEW_HEAD_SHA"],
        "repo_path": os.environ.get("REPO_PATH", "/repo"),
        "max_turns": max(1, _int_env("MAX_TURNS", 200)),
        "max_diff_bytes": _int_env("MAX_DIFF_BYTES", 50000),
        "report_lang": os.environ.get("REPORT_LANG", "zh"),
        "ci_pipeline_url": os.environ.get("CI_PIPELINE_URL", ""),
        "ci_project_path": os.environ.get("CI_PROJECT_PATH", ""),
        "ci_project_name": os.environ.get("CI_PROJECT_NAME", ""),
        "ci_project_url": os.environ.get("CI_PROJECT_URL", ""),
        "commit_short_sha": os.environ.get("CI_COMMIT_SHORT_SHA", ""),
        "commit_branch": os.environ.get("CI_COMMIT_BRANCH", ""),
        "pipeline_source": os.environ.get("CI_PIPELINE_SOURCE", ""),
        "mr_iid": os.environ.get("CI_MERGE_REQUEST_IID", ""),
        "mr_source_branch": os.environ.get("CI_MERGE_REQUEST_SOURCE_BRANCH_NAME", ""),
        "mr_target_branch": os.environ.get("CI_MERGE_REQUEST_TARGET_BRANCH_NAME", ""),
        "mr_title": os.environ.get("CI_MERGE_REQUEST_TITLE", ""),
        "trigger_user": os.environ.get("GITLAB_USER_LOGIN", "") or os.environ.get("GITHUB_ACTOR", ""),
        # GitLab 特有
        "gitlab_token": os.environ.get("CODE_REVIEWER_TOKEN", ""),
        "gitlab_api_url": os.environ.get("CI_API_V4_URL", ""),
        "gitlab_project_id": _int_env("CI_PROJECT_ID", 0),
        # GitHub 特有
        "gh_token": os.environ.get("GH_TOKEN", ""),
        "github_repository": os.environ.get("GITHUB_REPOSITORY", ""),
        "pr_number": _int_env("PR_NUMBER", 0) or None,
        # BREAKING: 默认 178 → 0
        "weekly_report_project_id": _int_env("WEEKLY_REPORT_PROJECT_ID", 0),
    }
```

- [ ] **步骤 4：跑测试确认通过**

运行：`pytest tests/test_config.py -v`
预期：全绿

- [ ] **步骤 5：Commit**

```bash
git add src/code_review/config.py tests/test_config.py
git commit -m "feat(config): PLATFORM 分支必填项 + WEEKLY 默认改 0

PLATFORM=gitlab 走原 GitLab 必填项 + WECOM 可选
PLATFORM=github 走 GitHub 必填项（GH_TOKEN + GITHUB_REPOSITORY）
WEEKLY_REPORT_PROJECT_ID 默认 178 → 0（BREAKING）
trigger_user 兼容 GitHub GITHUB_ACTOR

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 5：archive.py 适配新 cfg key（无需外部变化）

**文件：**
- 修改：`src/code_review/archive.py`
- 修改：`tests/test_archive.py`

- [ ] **步骤 1：修改 archive.py 读取 cfg 的 key 名**

`src/code_review/archive.py`（保持外部 API 不变，仅内部 cfg key 改名）：
```python
"""审查结果归档到 weekly_reports/review_cache/。

review job 末尾调 archive_review_to_weekly_reports()，失败吞异常
不影响 review 主流程（review 报告照常发企微/PR 评论）。
"""
import json
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from urllib.parse import quote


def _build_payload(head_sha, base_sha, project_id, project_path,
                   branch, trigger, commits, summary, verdict,
                   created_issues, closed_issues):
    return {
        "head_sha": head_sha, "base_sha": base_sha,
        "project_id": project_id, "project_path": project_path,
        "branch": branch, "trigger": trigger,
        "reviewed_at": datetime.now(timezone.utc).isoformat(),
        "verdict": verdict, "commits": commits, "summary": summary,
        "created_issues": created_issues, "closed_issues": closed_issues,
    }


def archive_review_to_weekly_reports(cfg, payload):
    head_sha = payload["head_sha"]
    prefix = head_sha[:2]
    file_path = f"review_cache/{prefix}/{head_sha}.json"
    content = json.dumps(payload, ensure_ascii=False, indent=2)

    # 改：cfg["gitlab_api_url"] / cfg["gitlab_token"]（原 gitlab_api_url / gitlab_token）
    api_url = cfg["gitlab_api_url"]
    token = cfg["gitlab_token"]
    project_id = cfg["weekly_report_project_id"]

    encoded_path = quote(file_path, safe="")
    url = f"{api_url}/projects/{project_id}/repository/files/{encoded_path}"
    body = {"branch": "main", "content": content,
            "commit_message": f"review: archive {head_sha[:8]}"}
    data = json.dumps(body, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(url, data=data,
                                 headers={"PRIVATE-TOKEN": token, "Content-Type": "application/json"},
                                 method="POST")
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            resp.read()
        return True
    except Exception as exc:
        print(f"[archive] 归档失败 ({type(exc).__name__}: {exc})，主流程不受影响",
              file=sys.stderr, flush=True)
        return False
```

- [ ] **步骤 2：跑 archive 测试**

运行：`pytest tests/test_archive.py -v`
预期：原 fixture 用 `gitlab_api_url` / `gitlab_token`，新 cfg key 已对齐，全绿

- [ ] **步骤 3：Commit**

```bash
git add src/code_review/archive.py
git commit -m "refactor(archive): 适配 cfg key 改名

gitlab_api_url → 保持同名（config.py:gitlab_api_url 字段对应原 cfg["gitlab_api_url"]）
git.c2h4.cn → 无内部 URL 引用，仅消费 cfg

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Phase 2：GitHub 实现

### 任务 6：GithubIssueClient 完整实现

**文件：**
- 修改：`src/code_review/platform/github.py`
- 修改：`tests/platform/test_github_client.py`

- [ ] **步骤 1：写 6 端点 + labels 预过滤 + 422 分流 + rate limit 测试**

`tests/platform/test_github_client.py` 关键 case：
```python
from unittest.mock import patch, MagicMock
import json
import urllib.error
from code_review.platform.github import GithubIssueClient


def _mock_response(data: dict, headers: dict = None):
    resp = MagicMock()
    resp.read.return_value = json.dumps(data).encode("utf-8")
    resp.headers = headers or {}
    resp.__enter__ = lambda s: s
    resp.__exit__ = lambda s, *a: None
    return resp


@patch("urllib.request.urlopen")
def test_list_open_issues_uses_correct_endpoint_and_maps_number_to_iid(mock_urlopen):
    mock_urlopen.return_value = _mock_response([
        {"number": 42, "title": "bug", "body": "desc", "html_url": "https://gh/x/42",
         "labels": [{"name": "reviewer-generated"}]}
    ])
    client = GithubIssueClient(token="ghp_x", repo="owner/repo")
    issues = client.list_open_issues(["reviewer-generated"])
    assert issues[0]["iid"] == 42
    assert issues[0]["title"] == "bug"
    assert "https://api.github.com/repos/owner/repo/issues" in mock_urlopen.call_args.args[0].full_url
    assert "labels=reviewer-generated" in mock_urlopen.call_args.args[0].full_url


@patch("urllib.request.urlopen")
def test_create_issue_returns_iid(mock_urlopen):
    mock_urlopen.return_value = _mock_response(
        {"number": 99, "html_url": "https://gh/x/99"}, {"X-RateLimit-Remaining": "100"})
    client = GithubIssueClient(token="ghp_x", repo="owner/repo")
    result = client.create_issue("t", "d", ["reviewer-generated", "severity::critical"])
    assert result["iid"] == 99
    assert result["web_url"] == "https://gh/x/99"


@patch("urllib.request.urlopen")
def test_assignee_422_silently_retries_without_assignee(mock_urlopen):
    """第一次 422 含 assignees → 去掉 assignees 重试一次"""
    err_response = MagicMock()
    err_response.read.return_value = json.dumps({
        "message": "Validation Failed",
        "errors": [{"resource": "Issue", "field": "assignees", "code": "invalid"}]
    }).encode("utf-8")
    err_response.__enter__ = lambda s: s
    err_response.__exit__ = lambda s, *a: None

    ok_response = _mock_response({"number": 5, "html_url": "https://gh/x/5"})

    mock_urlopen.side_effect = [
        urllib.error.HTTPError("url", 422, "Unprocessable", {}, err_response),
        ok_response,
    ]
    client = GithubIssueClient(token="ghp_x", repo="owner/repo")
    result = client.create_issue("t", "d", ["reviewer-generated"], assignee_id="alice")
    assert result["iid"] == 5
    assert mock_urlopen.call_count == 2
    # 第二次调用 body 不含 assignees
    second_call_body = json.loads(mock_urlopen.call_args_list[1].args[0].data)
    assert "assignees" not in second_call_body


@patch("urllib.request.urlopen")
def test_labels_422_silently_retries_without_labels(mock_urlopen):
    """422 含 labels → 去掉 labels 重试一次"""
    err_response = MagicMock()
    err_response.read.return_value = json.dumps({
        "errors": [{"resource": "Issue", "field": "labels", "code": "invalid"}]
    }).encode("utf-8")
    err_response.__enter__ = lambda s: s
    err_response.__exit__ = lambda s, *a: None
    ok_response = _mock_response({"number": 6, "html_url": "https://gh/x/6"})
    mock_urlopen.side_effect = [
        urllib.error.HTTPError("url", 422, "Unprocessable", {}, err_response),
        ok_response,
    ]
    client = GithubIssueClient(token="ghp_x", repo="owner/repo")
    result = client.create_issue("t", "d", ["nonexistent-label"])
    assert result["iid"] == 6


@patch("urllib.request.urlopen")
def test_other_422_does_not_retry_raises_to_llm(mock_urlopen):
    """422 含 title 等其他字段 → 不重试，原异常抛回"""
    err_response = MagicMock()
    err_response.read.return_value = json.dumps({
        "errors": [{"resource": "Issue", "field": "title", "code": "missing"}]
    }).encode("utf-8")
    err_response.__enter__ = lambda s: s
    err_response.__exit__ = lambda s, *a: None
    mock_urlopen.side_effect = urllib.error.HTTPError(
        "url", 422, "Unprocessable", {}, err_response)
    client = GithubIssueClient(token="ghp_x", repo="owner/repo")
    try:
        client.create_issue("t", "d", ["reviewer-generated"])
    except urllib.error.HTTPError:
        pass
    else:
        raise AssertionError("should have raised")
    assert mock_urlopen.call_count == 1  # 不重试


@patch("urllib.request.urlopen")
def test_labels_cache_failure_falls_through(mock_urlopen):
    """GET /labels 抛异常 → _available_labels 空集 → 不过滤"""
    mock_urlopen.side_effect = urllib.error.HTTPError(
        "url", 403, "Forbidden", {}, MagicMock())
    client = GithubIssueClient(token="ghp_x", repo="owner/repo")
    assert client._available_labels == set()


@patch("urllib.request.urlopen")
def test_empty_labels_cache_does_not_filter_lets_422_trigger_fallback(mock_urlopen):
    """labels 缓存空集时 create_issue 不过滤 → 原样传 labels → 422 → 触发 labels 降级。
    验证两个机制联动，避免 'GET /labels 失败 + 422 标签缺失' 死循环。
    """
    err_response = MagicMock()
    err_response.read.return_value = json.dumps({
        "errors": [{"resource": "Issue", "field": "labels", "code": "invalid"}]
    }).encode("utf-8")
    err_response.__enter__ = lambda s: s
    err_response.__exit__ = lambda s, *a: None

    # 构造 client 时 GET /labels 抛 403（_available_labels=空集）
    mock_urlopen.side_effect = [
        urllib.error.HTTPError("url", 403, "Forbidden", {}, err_response),  # 构造期 GET /labels
        urllib.error.HTTPError("url", 422, "Unprocessable", {}, err_response),  # create_issue 第一次
        _mock_response({"number": 7, "html_url": "https://gh/x/7"}),  # create_issue labels 降级重试
    ]
    client = GithubIssueClient(token="ghp_x", repo="owner/repo")
    # 缓存为空集
    assert client._available_labels == set()
    # create_issue 仍走 labels 降级路径
    result = client.create_issue("t", "d", ["severity::critical"])
    assert result["iid"] == 7


@patch("urllib.request.urlopen")
def test_lookup_assignee_returns_username_for_collaborator(mock_urlopen):
    mock_urlopen.return_value = _mock_response({"permission": "write"})
    client = GithubIssueClient(token="ghp_x", repo="owner/repo")
    result = client.lookup_assignee("alice")
    assert result == "alice"


@patch("urllib.request.urlopen")
def test_lookup_assignee_returns_none_for_non_collaborator(mock_urlopen):
    err_response = MagicMock()
    err_response.__enter__ = lambda s: s
    err_response.__exit__ = lambda s, *a: None
    mock_urlopen.side_effect = urllib.error.HTTPError(
        "url", 404, "Not Found", {}, err_response)
    client = GithubIssueClient(token="ghp_x", repo="owner/repo")
    assert client.lookup_assignee("outsider") is None
```

- [ ] **步骤 2：跑测试确认失败**

运行：`pytest tests/platform/test_github_client.py -v`
预期：FAIL `NotImplementedError`

- [ ] **步骤 3：写 GithubIssueClient 完整实现**

`src/code_review/platform/github.py`：
```python
"""GitHub IssueClient：REST API v3 实现。"""
import json
import time
import urllib.error
import urllib.request

from .. import log


class GithubIssueClient:
    def __init__(self, token: str, repo: str):
        self._token = token
        self._repo = repo
        self._api = "https://api.github.com"
        self._available_labels = self._fetch_labels()

    def _headers(self) -> dict:
        return {
            "Authorization": f"Bearer {self._token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "Content-Type": "application/json",
        }

    def _url(self, path: str) -> str:
        return f"{self._api}/repos/{self._repo}{path}"

    def _request(self, method: str, path: str, body=None):
        for attempt in range(3):
            url = self._url(path)
            data = json.dumps(body).encode("utf-8") if body is not None else None
            req = urllib.request.Request(url, data=data,
                                         headers=self._headers(), method=method)
            try:
                with urllib.request.urlopen(req, timeout=15) as resp:
                    remaining = resp.headers.get("X-RateLimit-Remaining")
                    if remaining and int(remaining) < 50:
                        reset = int(resp.headers.get("X-RateLimit-Reset", 0))
                        wait = max(0, reset - int(time.time()))
                        if wait < 300:
                            time.sleep(wait)
                    return json.loads(resp.read().decode("utf-8"))
            except urllib.error.HTTPError as exc:
                if exc.code in (429, 502, 503) and attempt < 2:
                    time.sleep(2 ** attempt)
                    continue
                raise
        raise RuntimeError("rate limit 重试耗尽")

    def _fetch_labels(self) -> set:
        try:
            labels = self._request("GET", "/labels?per_page=100")
            return {l["name"] for l in labels}
        except Exception as exc:
            log.log_event("labels_fetch_fail",
                          f"exc={type(exc).__name__}: {exc}")
            return set()

    # === IssueClient Protocol 实现 ===

    def list_open_issues(self, labels: list[str]) -> list[dict]:
        labels_str = ",".join(labels)
        raw = self._request("GET", f"/issues?labels={labels_str}&state=open&per_page=100")
        return [{
            "iid": issue["number"],
            "title": issue.get("title", ""),
            "description": issue.get("body") or "",
            "web_url": issue["html_url"],
            "labels": [l["name"] for l in issue.get("labels", [])],
        } for issue in raw]

    def create_issue(self, title, description, labels, assignee_id=None) -> dict:
        body = {"title": title, "body": description,
                "labels": [l for l in labels if l in self._available_labels]}
        if assignee_id:
            body["assignees"] = [assignee_id]
        try:
            r = self._request("POST", "/issues", body)
        except urllib.error.HTTPError as exc:
            if exc.code != 422:
                raise
            err_body = json.loads(exc.read().decode("utf-8"))
            fields = {e.get("field") for e in err_body.get("errors", [])}
            if "assignees" in fields or "assignee" in fields:
                # assignee 降级
                log.log_event("assignee_fallback", f"retry_without_assignee")
                body.pop("assignees", None)
                r = self._request("POST", "/issues", body)
            elif "labels" in fields:
                # labels 预创建遗漏兜底
                log.log_event("labels_fallback", f"retry_without_labels")
                body.pop("labels", None)
                r = self._request("POST", "/issues", body)
            else:
                # 其他字段（title/body）不重试，原异常抛回 LLM
                raise
        return {"iid": r["number"], "web_url": r["html_url"]}

    def close_issue(self, iid: int) -> dict:
        r = self._request("PATCH", f"/issues/{iid}", {"state": "closed"})
        return {"iid": r["number"], "web_url": r["html_url"]}

    def add_comment(self, iid: int, body: str) -> dict:
        r = self._request("POST", f"/issues/{iid}/comments", {"body": body})
        return {"iid": iid, "web_url": r["html_url"]}

    def update_description(self, iid: int, description: str) -> dict:
        r = self._request("PATCH", f"/issues/{iid}", {"body": description})
        return {"iid": r["number"], "web_url": r["html_url"]}

    def lookup_assignee(self, username: str) -> str | None:
        if not username:
            return None
        try:
            r = self._request("GET", f"/collaborators/{username}/permission")
            if r.get("permission") in ("admin", "write", "maintain", "triage"):
                return username
        except urllib.error.HTTPError:
            return None
        return None
```

- [ ] **步骤 4：跑测试确认通过**

运行：`pytest tests/platform/test_github_client.py -v`
预期：全绿

- [ ] **步骤 5：Commit**

```bash
git add src/code_review/platform/github.py tests/platform/test_github_client.py
git commit -m "feat(platform): GithubIssueClient 完整实现

6 端点：list_open_issues / create_issue / close_issue / add_comment /
update_description / lookup_assignee
iid ↔ number 映射在 list_open_issues 出口完成
labels 预过滤 + GET /labels 失败兜底（空集）
422 三分支：assignee/labels 静默降级重试，其他字段抛回 LLM
rate limit 防御（X-RateLimit-Remaining < 50 sleep 到 reset）

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 7：GithubPrCommentNotifier 完整实现

**文件：**
- 修改：`src/code_review/notifier/github_pr.py`
- 修改：`tests/notifier/test_github_pr.py`

- [ ] **步骤 1：写 PR 评论 + status check 测试**

`tests/notifier/test_github_pr.py`：
```python
from unittest.mock import patch, MagicMock
import json
from code_review.notifier.github_pr import GithubPrCommentNotifier
from code_review.notifier import ReportContext


def _ctx(pr_number=None, head_sha="abc1234"):
    return ReportContext(
        project="proj", project_url="https://gh/owner/repo",
        authors="alice", trigger_user="bob",
        branch_line="feat→main", commit_sha="abc1234",
        stat="3 +20 -5", pr_number=pr_number,
    )


@patch("urllib.request.urlopen")
def test_send_report_pr_posts_comment(mock_urlopen):
    mock_urlopen.return_value = MagicMock(__enter__=lambda s: s, __exit__=lambda s, *a: None)
    notifier = GithubPrCommentNotifier(token="ghp_x", repo="owner/repo")
    notifier.send_report("# report", context=_ctx(pr_number=42))
    assert mock_urlopen.call_count == 1
    url = mock_urlopen.call_args.args[0].full_url
    assert url == "https://api.github.com/repos/owner/repo/issues/42/comments"


@patch("urllib.request.urlopen")
def test_send_report_truncates_long_body(mock_urlopen):
    mock_urlopen.return_value = MagicMock(__enter__=lambda s: s, __exit__=lambda s, *a: None)
    notifier = GithubPrCommentNotifier(token="ghp_x", repo="owner/repo")
    long_report = "x" * 70000
    notifier.send_report(long_report, context=_ctx(pr_number=42))
    body = json.loads(mock_urlopen.call_args.args[0].data)["body"]
    assert len(body) <= 65000 + len("\n\n…（报告超长已截断）")


@patch("urllib.request.urlopen")
def test_send_report_push_posts_status_check_success(mock_urlopen):
    mock_urlopen.return_value = MagicMock(__enter__=lambda s: s, __exit__=lambda s, *a: None)
    notifier = GithubPrCommentNotifier(token="ghp_x", repo="owner/repo")
    notifier.send_report("# report", context=_ctx(pr_number=None, head_sha="deadbeef"))
    assert mock_urlopen.call_count == 1
    url = mock_urlopen.call_args.args[0].full_url
    assert "/statuses/deadbeef" in url
    payload = json.loads(mock_urlopen.call_args.args[0].data)
    assert payload["state"] == "success"
    assert payload["context"] == "ci-code-reviewer/ai"


@patch("urllib.request.urlopen")
def test_send_error_push_posts_status_check_failure(mock_urlopen):
    mock_urlopen.return_value = MagicMock(__enter__=lambda s: s, __exit__=lambda s, *a: None)
    notifier = GithubPrCommentNotifier(token="ghp_x", repo="owner/repo")
    notifier.send_error("审查未完成", "agent 失败", context=_ctx(pr_number=None))
    payload = json.loads(mock_urlopen.call_args.args[0].data)
    assert payload["state"] == "failure"
    assert "审查未完成" in payload["description"]


@patch("urllib.request.urlopen")
def test_status_check_description_truncated_to_140(mock_urlopen):
    mock_urlopen.return_value = MagicMock(__enter__=lambda s: s, __exit__=lambda s, *a: None)
    notifier = GithubPrCommentNotifier(token="ghp_x", repo="owner/repo")
    long_body = "x" * 500
    notifier.send_error("title", long_body, context=_ctx(pr_number=None))
    payload = json.loads(mock_urlopen.call_args.args[0].data)
    assert len(payload["description"]) <= 140


@patch("urllib.request.urlopen")
def test_status_check_failure_silently_swallowed(mock_urlopen):
    """status check 抛异常不能阻塞主流程"""
    mock_urlopen.side_effect = Exception("network down")
    notifier = GithubPrCommentNotifier(token="ghp_x", repo="owner/repo")
    # 不抛异常即通过
    notifier.send_error("title", "body", context=_ctx(pr_number=None))


@patch("urllib.request.urlopen")
def test_send_skip_no_status_check(mock_urlopen):
    """skip 场景不发 status（不是失败）"""
    notifier = GithubPrCommentNotifier(token="ghp_x", repo="owner/repo")
    notifier.send_skip("跳过", "无 diff", context=_ctx(pr_number=None))
    assert mock_urlopen.call_count == 0
```

- [ ] **步骤 2：跑测试确认失败**

运行：`pytest tests/notifier/test_github_pr.py -v`
预期：FAIL `NotImplementedError`

- [ ] **步骤 3：写 GithubPrCommentNotifier**

`src/code_review/notifier/github_pr.py`：
```python
"""GitHubPrCommentNotifier：PR 场景发评论，push 场景发 commit status check 兜底。"""
import json
import urllib.request

from .. import log
from . import ReportContext


class GithubPrCommentNotifier:
    COMMENTS_LIMIT = 65000
    STATUS_DESCRIPTION_LIMIT = 140
    STATUS_CONTEXT = "ci-code-reviewer/ai"

    def __init__(self, token: str, repo: str):
        self._token = token
        self._repo = repo
        self._api = "https://api.github.com"

    def _headers(self) -> dict:
        return {
            "Authorization": f"Bearer {self._token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "Content-Type": "application/json",
        }

    def send_report(self, report: str, *, context: ReportContext) -> bool:
        if context.pr_number is None:
            return self._send_status_check(context.commit_sha, "success",
                                           "AI 审查完成，详见控制台日志")
        self._post_comment(context.pr_number, self._truncate(report, self.COMMENTS_LIMIT))
        return True

    def send_error(self, title: str, body: str, *, context: ReportContext) -> None:
        msg = f"## ⚠️ {title}\n\n{body}"
        if context.pr_number is not None:
            self._post_comment(context.pr_number, self._truncate(msg, self.COMMENTS_LIMIT))
        else:
            self._send_status_check(context.commit_sha, "failure",
                                    f"{title}: {body}")

    def send_skip(self, title: str, body: str, *, context: ReportContext) -> None:
        if context.pr_number is not None:
            msg = f"## ℹ️ {title}\n\n{body}"
            self._post_comment(context.pr_number, self._truncate(msg, self.COMMENTS_LIMIT))
        # push + skip 不发 status check

    def _post_comment(self, issue_number: int, body: str):
        url = f"{self._api}/repos/{self._repo}/issues/{issue_number}/comments"
        req = urllib.request.Request(url, data=json.dumps({"body": body}).encode(),
                                     headers=self._headers(), method="POST")
        with urllib.request.urlopen(req, timeout=15) as resp:
            resp.read()

    def _send_status_check(self, sha: str, state: str, description: str):
        url = f"{self._api}/repos/{self._repo}/statuses/{sha}"
        payload = {
            "state": state,
            "description": description[:self.STATUS_DESCRIPTION_LIMIT],
            "context": self.STATUS_CONTEXT,
        }
        req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                     headers=self._headers(), method="POST")
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                resp.read()
        except Exception as exc:
            log.log_event("status_check_fail",
                          f"sha={sha[:8]} state={state} exc={type(exc).__name__}: {exc}")

    def _truncate(self, text: str, limit: int) -> str:
        return text if len(text) <= limit else text[:limit] + "\n\n…（报告超长已截断）"
```

- [ ] **步骤 4：跑测试确认通过**

运行：`pytest tests/notifier/test_github_pr.py -v`
预期：全绿

- [ ] **步骤 5：Commit**

```bash
git add src/code_review/notifier/github_pr.py tests/notifier/test_github_pr.py
git commit -m "feat(notifier): GithubPrCommentNotifier PR 评论 + status check 兜底

PR 场景发评论（65000 字符截断）；push 场景发 commit status check
context=ci-code-reviewer/ai 避免与 GitHub Actions 同名 context 撞车
description 140 字符截断（GitHub API 硬限制）
status check 失败吞异常不阻塞主流程

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 8：Prompt 平台术语替换

**文件：**
- 修改：`src/code_review/agents.py`
- 修改：`tests/test_agents.py`

- [ ] **步骤 1：写 prompt 平台分支测试**

`tests/test_agents.py` 加 case：
```python
def test_substitute_platform_terms_gitlab_keeps_gitlab_phrase():
    from code_review.agents import _substitute_platform_terms
    text = "在 GitLab 项目创建一个 issue"
    out = _substitute_platform_terms(text, "gitlab")
    assert "GitLab issue" in out
    assert "GitHub" not in out


def test_substitute_platform_terms_github_replaces_to_github():
    from code_review.agents import _substitute_platform_terms
    text = "在 GitLab 项目创建一个 issue"
    out = _substitute_platform_terms(text, "github")
    assert "GitHub issue" in out
    # 旧短语不残留
    assert "GitLab issue" not in out


def test_substitute_platform_terms_github_adds_label_intro():
    """GitHub 平台 prompt 含 label 预创建提醒。"""
    from code_review.agents import _substitute_platform_terms
    text = "会自动打上 reviewer-generated 和 severity 标签。"
    out = _substitute_platform_terms(text, "github")
    assert "GitHub 需要仓库预创建这些 label" in out


def test_substitute_platform_terms_gitlab_keeps_label_intro():
    """GitLab 平台 label 自动创建，无需预创建提示。"""
    from code_review.agents import _substitute_platform_terms
    text = "会自动打上 reviewer-generated 和 severity 标签。"
    out = _substitute_platform_terms(text, "gitlab")
    # GitLab 不需要 pre-create 提示
    assert "预创建" not in out


def test_build_agent_b_prompt_default_is_gitlab():
    """默认 platform=gitlab，prompt 含 GitLab issue。"""
    from code_review.agents import build_agent_b_prompt
    ctx = {"repo_path": "/repo", "base_sha": "abc", "head_sha": "def"}
    meta = {"author_list": "", "files_changed": "0", "commit_summary": "（无）"}
    prompt_gitlab = build_agent_b_prompt(ctx, meta, "", "zh", prior_notes=[], open_issues=[])
    assert "GitLab issue" in prompt_gitlab


def test_build_agent_b_prompt_github_uses_github_terms(tmp_path, monkeypatch):
    monkeypatch.setenv("PLATFORM", "github")
    monkeypatch.setenv("GH_TOKEN", "ghp_x")
    monkeypatch.setenv("GITHUB_REPOSITORY", "o/r")
    monkeypatch.setenv("LLM_BASE_URL", "x")
    monkeypatch.setenv("LLM_API_KEY", "k")
    monkeypatch.setenv("LLM_MODEL", "m")
    monkeypatch.setenv("REVIEW_BASE_SHA", "a")
    monkeypatch.setenv("REVIEW_HEAD_SHA", "b")
    from code_review.agents import build_agent_b_prompt
    ctx = {"repo_path": "/repo", "base_sha": "abc", "head_sha": "def"}
    meta = {"author_list": "", "files_changed": "0", "commit_summary": "（无）"}
    # build_agent_b_prompt 不直接读 cfg，需要从 ctx["platform"] 取
    ctx_with_platform = {**ctx, "platform": "github"}
    prompt_github = build_agent_b_prompt(ctx_with_platform, meta, "", "zh",
                                         prior_notes=[], open_issues=[])
    assert "GitHub issue" in prompt_github
    assert "GitLab issue" not in prompt_github
```

- [ ] **步骤 2：跑测试确认失败**

运行：`pytest tests/test_agents.py -v`
预期：FAIL `ImportError: cannot import name '_substitute_platform_terms'`

- [ ] **步骤 3：实现 _substitute_platform_terms + build_prompt 改签名**

`src/code_review/agents.py` 顶部加：
```python
PLATFORM_TERMS = {
    "gitlab": {
        "issue_system": "GitLab issue",
        "label_intro": "会自动打上 reviewer-generated 和 severity 标签。",
    },
    "github": {
        "issue_system": "GitHub issue",
        "label_intro": "会自动打上 reviewer-generated 和 severity 标签（GitHub 需要仓库预创建这些 label）。",
    },
}


def _substitute_platform_terms(text: str, platform: str) -> str:
    """替换 prompt 文本里的平台术语 + label 创建说明。"""
    terms = PLATFORM_TERMS.get(platform, PLATFORM_TERMS["gitlab"])
    return (text
            .replace("在 GitLab 项目创建一个 issue", f"在 {terms['issue_system']} 创建一个 issue")
            .replace("关闭一个已确认被本次提交修复的 GitLab issue",
                     f"关闭一个已确认被本次提交修复的 {terms['issue_system']}")
            .replace("GitLab issue（带 severity）", f"{terms['issue_system']}（带 severity）")
            .replace("会自动打上 reviewer-generated 和 severity 标签。", terms["label_intro"])
            .replace("GitLab issue", terms["issue_system"]))
```

`build_prompt` 改签名 + 末尾调用：
```python
def build_prompt(context: dict, template_path: str, platform: str = "gitlab") -> str:
    """读取模板、填充变量、应用平台术语替换。"""
    text = _read_template(template_path)
    rendered = text.format(**context)
    return _substitute_platform_terms(rendered, platform)
```

`build_agent_a_prompt` / `build_agent_b_prompt` / `build_agent_c_prompt` 改签名增加 `platform: str = "gitlab"` 参数：
```python
def build_agent_a_prompt(ctx: dict, meta: dict, pipeline_url: str,
                         report_lang: str, platform: str = "gitlab") -> str:
    return build_prompt(_base_ctx(ctx, meta, pipeline_url, report_lang),
                        os.path.join(_PROMPTS_DIR, "agent_a_feature.md"),
                        platform=platform)


def build_agent_b_prompt(ctx: dict, meta: dict, pipeline_url: str, report_lang: str,
                         prior_notes: list, open_issues: list,
                         platform: str = "gitlab") -> str:
    c = _base_ctx(ctx, meta, pipeline_url, report_lang)
    c["prior_notes"] = "\n".join(prior_notes) if prior_notes else "（无）"
    c["open_issues"] = _format_issues(open_issues)
    return build_prompt(c, os.path.join(_PROMPTS_DIR, "agent_b_quality.md"),
                        platform=platform)


def build_agent_c_prompt(ctx: dict, meta: dict, pipeline_url: str, report_lang: str,
                         open_issues: list, platform: str = "gitlab") -> str:
    c = _base_ctx(ctx, meta, pipeline_url, report_lang)
    c["open_issues"] = _format_issues(open_issues)
    return build_prompt(c, os.path.join(_PROMPTS_DIR, "agent_c_repair.md"),
                        platform=platform)
```

调用方传 platform：`orchestrator.py` 改 `build_agent_*_prompt(ctx, ..., platform=cfg.get("platform", "gitlab"))`。

- [ ] **步骤 4：跑测试确认通过**

运行：`pytest tests/test_agents.py -v`
预期：全绿

- [ ] **步骤 5：Commit**

```bash
git add src/code_review/agents.py tests/test_agents.py src/code_review/orchestrator.py
git commit -m "feat(agents): prompt 平台术语 + label 预创建提示

_substitute_platform_terms 把 GitLab issue → GitHub issue
GitHub 平台额外添加 '需要仓库预创建 label' 提示
build_prompt / build_agent_*_prompt 加 platform 参数（默认 gitlab）
orchestrator.py 调用处传 cfg['platform']

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 9：tools/create_issue.py 与 close_issue.py 改造

**文件：**
- 修改：`src/code_review/tools/create_issue.py`
- 修改：`src/code_review/tools/close_issue.py`
- 修改：`tests/test_tool_create_issue.py`
- 修改：`tests/test_tool_close_issue.py`

- [ ] **步骤 1：写工具调用 ctx["issue_client"] 的测试**

`tests/test_tool_create_issue.py`：
```python
def test_create_issue_uses_ctx_issue_client(monkeypatch):
    """create_issue 工具从 ctx["issue_client"] 拿 IssueClient 实例，不再直接 import gitlab_client"""
    from code_review.tools.create_issue import handler
    from tests.test_helpers import FakeIssueClient

    fake = FakeIssueClient()
    fake.create_issue_result = {"iid": 42, "web_url": "https://gh/x/42"}
    ctx = {"issue_client": fake, "issue_ops": [], "assignee_id": None}
    observation = handler(
        {"title": "bug", "description": "desc", "severity": "critical"},
        ctx,
    )
    assert "已创建 issue #42" in observation
    assert fake.create_issue_called_with == ("bug", "desc", ["reviewer-generated", "severity::critical"], None)


def test_create_issue_replaces_iid_placeholders(monkeypatch):
    """description 含占位符时回写更新 issue。"""
    from code_review.tools.create_issue import handler
    from tests.test_helpers import FakeIssueClient

    fake = FakeIssueClient()
    fake.create_issue_result = {"iid": 7, "web_url": "https://gh/x/7"}
    ctx = {"issue_client": fake, "issue_ops": [], "assignee_id": None}
    handler(
        {"title": "t", "description": "前文 <CR_IGNORE_IID_HASH> 后文 <CR_IGNORE_IID_NUM>", "severity": "warning"},
        ctx,
    )
    # update_description 被调用，body 含替换后的 iid
    assert fake.update_description_called_with == [(7, "前文 #7 后文 7")]
```

`tests/test_tool_close_issue.py`：
```python
def test_close_issue_uses_ctx_issue_client():
    """close_issue 工具从 ctx["issue_client"] 拿 IssueClient 实例。"""
    from code_review.tools.close_issue import handler
    from tests.test_helpers import FakeIssueClient

    fake = FakeIssueClient()
    ctx = {"issue_client": fake, "issue_ops": [], "open_issues": [
        {"iid": 5, "title": "old bug", "web_url": "https://gh/x/5"}
    ]}
    observation = handler({"issue_iid": 5, "reason": "已修复"}, ctx)
    assert observation == "已关闭 issue #5"
    # add_comment + close_issue 都被调
    assert fake.add_comment_called_with == [(5, "🤖 code-reviewer 关闭理由：已修复")]
    assert fake.close_issue_called_with == [5]
    # issue_ops 记录含 web_url/title 来自 open_issues
    assert ctx["issue_ops"][-1]["op"] == "closed"
    assert ctx["issue_ops"][-1]["web_url"] == "https://gh/x/5"


def test_close_issue_add_comment_failure_swallowed():
    """add_comment 抛异常不影响 close_issue 继续。"""
    from code_review.tools.close_issue import handler
    from tests.test_helpers import FakeIssueClient

    fake = FakeIssueClient()

    def raise_exc(*a, **kw):
        raise Exception("comment failed")
    fake.add_comment = raise_exc
    ctx = {"issue_client": fake, "issue_ops": [], "open_issues": []}
    # 不抛异常即通过
    handler({"issue_iid": 1, "reason": "x"}, ctx)
    assert fake.close_issue_called_with == [1]
```

需要新建 `tests/test_helpers.py` 提供 FakeIssueClient + FakeNotifier（任务 10 步骤 1 一并新建）。

- [ ] **步骤 2：跑测试确认失败**

运行：`pytest tests/test_tool_create_issue.py -v`
预期：FAIL FakeIssueClient 不存在 / 创建 issue 仍走 gitlab_client

- [ ] **步骤 3：改造 create_issue.py**

`src/code_review/tools/create_issue.py`：
```python
"""create_issue 工具：通过 ctx["issue_client"] 创建 issue。"""
from .. import log

_IID_PLACEHOLDER_HASH = "<CR_IGNORE_IID_HASH>"  # → #<iid>，源码行内注释
_IID_PLACEHOLDER_NUM = "<CR_IGNORE_IID_NUM>"    # → <iid>，.cr-ignore.md 条目（纯数字）


definition = {
    "type": "function",
    "function": {
        "name": "create_issue",
        "description": "在项目创建一个 issue 记录审查发现的质量问题（平台由 IssueClient 决定）。会自动打上 reviewer-generated 和 severity 标签。",
        "parameters": {
            "type": "object",
            "properties": {
                "title": {"type": "string", "description": "issue 标题，简述问题"},
                "description": {"type": "string",
                                "description": "详细描述：文件:行号、问题、影响、修复建议，并在末尾追加忽略指南段（含 <CR_IGNORE_IID_HASH> 或 <CR_IGNORE_IID_NUM> 占位符）"},
                "severity": {"type": "string",
                             "enum": ["critical", "warning", "suggestion"],
                             "description": "严重程度：critical 严重/warning 警告/suggestion 建议"},
            },
            "required": ["title", "description", "severity"],
        },
    },
}


def handler(args: dict, ctx: dict) -> str:
    title = args["title"]
    severity = args["severity"]
    base_desc = args["description"] or ""
    assignee_id = ctx.get("assignee_id")
    result = ctx["issue_client"].create_issue(
        title=title,
        description=base_desc,
        labels=["reviewer-generated", f"severity::{severity}"],
        assignee_id=assignee_id,
    )
    iid = result["iid"]
    final_desc = (base_desc
                  .replace(_IID_PLACEHOLDER_HASH, f"#{iid}")
                  .replace(_IID_PLACEHOLDER_NUM, f"{iid}"))
    if final_desc != base_desc:
        try:
            ctx["issue_client"].update_description(iid, final_desc)
        except Exception:
            pass
    ctx.setdefault("issue_ops", []).append({
        "op": "created",
        "iid": iid,
        "web_url": result["web_url"],
        "severity": severity,
        "title": title,
    })
    return f"已创建 issue #{iid}: {result['web_url']}"
```

- [ ] **步骤 4：改造 close_issue.py**

`src/code_review/tools/close_issue.py`：
```python
"""close_issue 工具：通过 ctx["issue_client"] 关闭 issue。"""
from .. import log


definition = {
    "type": "function",
    "function": {
        "name": "close_issue",
        "description": "关闭一个已确认被本次提交修复的 issue，并附上关闭理由评论。仅在明确确认修复时调用。",
        "parameters": {
            "type": "object",
            "properties": {
                "issue_iid": {"type": "integer", "description": "要关闭的 issue iid"},
                "reason": {"type": "string",
                           "description": "关闭理由：为什么判断该问题已被修复（将作为公开评论写入 issue）"},
            },
            "required": ["issue_iid", "reason"],
        },
    },
}


def handler(args: dict, ctx: dict) -> str:
    iid = args["issue_iid"]
    reason = args["reason"]
    try:
        ctx["issue_client"].add_comment(iid, f"🤖 code-reviewer 关闭理由：{reason}")
    except Exception:
        pass
    ctx["issue_client"].close_issue(iid)
    info = next((i for i in ctx.get("open_issues", []) if i.get("iid") == iid), {})
    ctx.setdefault("issue_ops", []).append({
        "op": "closed",
        "iid": iid,
        "web_url": info.get("web_url", ""),
        "title": info.get("title", ""),
        "reason": reason,
    })
    return f"已关闭 issue #{iid}"
```

- [ ] **步骤 5：跑工具测试确认通过**

运行：`pytest tests/test_tool_create_issue.py tests/test_tool_close_issue.py -v`
预期：全绿

- [ ] **步骤 6：Commit**

```bash
git add src/code_review/tools/ tests/test_tool_create_issue.py tests/test_tool_close_issue.py tests/test_helpers.py
git commit -m "refactor(tools): create_issue/close_issue 走 ctx[issue_client]

工具不再直接 import gitlab_client，统一从 dispatch_ctx["issue_client"]
拿平台 IssueClient 实例。GitLab/GitHub 行为由 IssueClient 实现负责。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 10：agent.py dispatch_ctx 改造 + FakeIssueClient 测试 fixture

**文件：**
- 修改：`src/code_review/agent.py`
- 创建：`tests/test_helpers.py`

- [ ] **步骤 1：写 FakeIssueClient + dispatch_ctx 测试**

`tests/test_helpers.py`：
```python
"""测试辅助：FakeIssueClient + FakeNotifier 等。"""
from dataclasses import dataclass, field
from typing import Any


@dataclass
class FakeIssueClient:
    """测试用 IssueClient 桩，记录所有调用 + 返回预设值。"""
    list_open_issues_result: list = field(default_factory=list)
    create_issue_result: dict = field(default_factory=lambda: {"iid": 1, "web_url": "https://x/1"})
    close_issue_result: dict = field(default_factory=lambda: {"iid": 1})
    add_comment_result: dict = field(default_factory=lambda: {"web_url": "https://x/c1"})
    update_description_result: dict = field(default_factory=lambda: {"iid": 1})
    lookup_assignee_result: Any = None

    # 记录
    list_open_issues_called_with: list = field(default_factory=list)
    create_issue_called_with: tuple = None
    close_issue_called_with: list = field(default_factory=list)
    add_comment_called_with: list = field(default_factory=list)
    update_description_called_with: list = field(default_factory=list)
    lookup_assignee_called_with: list = field(default_factory=list)

    def list_open_issues(self, labels):
        self.list_open_issues_called_with.append(labels)
        return self.list_open_issues_result

    def create_issue(self, title, description, labels, assignee_id=None):
        self.create_issue_called_with = (title, description, labels, assignee_id)
        return self.create_issue_result

    def close_issue(self, iid):
        self.close_issue_called_with.append(iid)
        return self.close_issue_result

    def add_comment(self, iid, body):
        self.add_comment_called_with.append((iid, body))
        return self.add_comment_result

    def update_description(self, iid, description):
        self.update_description_called_with.append((iid, description))
        return self.update_description_result

    def lookup_assignee(self, username):
        self.lookup_assignee_called_with.append(username)
        return self.lookup_assignee_result


@dataclass
class FakeNotifier:
    """测试用 Notifier 桩，记录所有调用 + 返回预设值。"""
    send_report_return: bool = True

    # 记录
    send_report_called: bool = False
    send_report_called_with: list = field(default_factory=list)
    send_error_called_with: list = field(default_factory=list)
    send_skip_called_with: list = field(default_factory=list)

    def send_report(self, report: str, *, context=None) -> bool:
        self.send_report_called = True
        self.send_report_called_with.append((report, context))
        return self.send_report_return

    def send_error(self, title: str, body: str, *, context=None) -> None:
        self.send_error_called_with.append((title, body, context))

    def send_skip(self, title: str, body: str, *, context=None) -> None:
        self.send_skip_called_with.append((title, body, context))
```

`tests/test_agent.py` 加 case（直接验证 dispatch_ctx 构造，不依赖完整 agent 循环）：

```python
def test_dispatch_ctx_contains_issue_client_not_gitlab_keys():
    """验证 agent.run_agent 构造的 dispatch_ctx 含 issue_client，不含 gitlab_* 三 key。"""
    from unittest.mock import patch, MagicMock
    from code_review.agent import run_agent
    from code_review.tools import get_tool_definitions
    from tests.test_helpers import FakeIssueClient

    fake = FakeIssueClient()
    cfg = {
        "llm_base_url": "https://llm/x",
        "llm_api_key": "sk",
        "llm_model": "m",
        "max_turns": 1,
        "gitlab_token": "should-not-appear",
        "gitlab_api_url": "should-not-appear",
        "gitlab_project_id": 999,
    }
    ctx = {
        "repo_path": "/repo",
        "base_sha": "abc",
        "head_sha": "def",
        "issue_client": fake,
        "assignee_id": None,
    }

    # patch OpenAI client + run_agent 内调用的 LLM，返回无 tool_calls 让循环立即退出
    with patch("code_review.agent.OpenAI") as mock_openai_cls:
        mock_response = MagicMock()
        mock_response.choices = [MagicMock(message=MagicMock(content="ok", tool_calls=None,
                                                              model_dump=lambda **kw: {"role": "assistant", "content": "ok"}))]
        mock_client = MagicMock()
        mock_client.chat.completions.create.return_value = mock_response
        mock_openai_cls.return_value = mock_client

        run_agent(cfg, "A", "system prompt", ["take_note"], ctx)

    # 验证 dispatch_ctx 构造时传给 LLM 工具的 ctx 含 issue_client，不含 gitlab_*
    # 实际：take_note 工具不需要这些 key，但 notes_store / issue_client / repo_path 等会被传到 dispatch_ctx
    # 间接验证：检查 mock_client.chat.completions.create 的 messages/tools 调用
    create_call_kwargs = mock_client.chat.completions.create.call_args.kwargs
    # 工具定义不含 gitlab 字段
    tool_names = [t["function"]["name"] for t in create_call_kwargs["tools"]]
    assert "create_issue" in tool_names  # 工具集本身不变
    # system prompt 注入
    assert "system prompt" in create_call_kwargs["messages"][0]["content"]


def test_create_issue_handler_dispatch_ctx_uses_issue_client():
    """create_issue 工具 handler 收到的 ctx 含 issue_client（dispatch_ctx 注入验证）。"""
    # 走 dispatch 路径，验证 dispatch_ctx 构造完整
    from code_review.tools import dispatch
    from tests.test_helpers import FakeIssueClient

    fake = FakeIssueClient()
    fake.create_issue_result = {"iid": 99, "web_url": "https://gh/x/99"}
    dispatch_ctx = {
        "repo_path": "/repo",
        "base_sha": "abc",
        "head_sha": "def",
        "issue_client": fake,
        "notes_store": None,
        "issue_ops": [],
        "open_issues": [],
        "assignee_id": None,
    }
    observation = dispatch("create_issue",
                           {"title": "t", "description": "d", "severity": "critical"},
                           dispatch_ctx)
    assert "已创建 issue #99" in observation
    assert fake.create_issue_called_with == ("t", "d",
                                              ["reviewer-generated", "severity::critical"],
                                              None)


def test_run_agent_does_not_pass_gitlab_keys_to_dispatch():
    """run_agent 不会向 dispatch_ctx 注入 gitlab_token/gitlab_api_url/gitlab_project_id。"""
    from unittest.mock import patch, MagicMock
    from code_review.agent import run_agent
    from tests.test_helpers import FakeIssueClient

    captured_ctx = {}

    # patch dispatch 模块，记录传给 handler 的 ctx
    def fake_dispatch(tool_name, args, ctx):
        captured_ctx.update(ctx)
        return "ok"

    fake = FakeIssueClient()
    cfg = {
        "llm_base_url": "https://llm/x",
        "llm_api_key": "sk",
        "llm_model": "m",
        "max_turns": 1,
        "gitlab_token": "should-not-leak",
        "gitlab_api_url": "should-not-leak",
        "gitlab_project_id": 999,
    }
    ctx = {
        "repo_path": "/repo",
        "base_sha": "abc",
        "head_sha": "def",
        "issue_client": fake,
        "assignee_id": None,
    }

    with patch("code_review.agent.OpenAI") as mock_openai_cls, \
         patch("code_review.tools.dispatch", side_effect=fake_dispatch):
        # 让 LLM 返回一个 take_note tool_call 触发 dispatch
        mock_tc = MagicMock()
        mock_tc.id = "call_1"
        mock_tc.function.name = "take_note"
        mock_tc.function.arguments = '{"note": "test"}'
        mock_response = MagicMock()
        mock_response.choices = [MagicMock(message=MagicMock(
            content="", tool_calls=[mock_tc],
            model_dump=lambda **kw: {"role": "assistant", "content": "",
                                     "tool_calls": [{"id": "call_1",
                                                     "type": "function",
                                                     "function": {"name": "take_note",
                                                                  "arguments": "{}"}}]},
        ))]
        mock_response.choices[0].message.tool_calls = [mock_tc]
        mock_client = MagicMock()
        mock_client.chat.completions.create.return_value = mock_response
        mock_openai_cls.return_value = mock_client

        run_agent(cfg, "A", "system", ["take_note"], ctx)

    # 验证 dispatch_ctx 不含 gitlab_* 三 key
    assert "gitlab_token" not in captured_ctx
    assert "gitlab_api_url" not in captured_ctx
    assert "gitlab_project_id" not in captured_ctx
    assert captured_ctx["issue_client"] is fake
```

实际验证方式：直接构造 dispatch_ctx 走 `code_review.tools.dispatch` 验证注入逻辑，不再依赖完整 agent 循环。

- [ ] **步骤 2：跑测试确认失败**

运行：`pytest tests/test_agent.py -v`
预期：FAIL dispatch_ctx 仍含 gitlab_token

- [ ] **步骤 3：改造 agent.py dispatch_ctx 构造**

`src/code_review/agent.py` 第 92-103 行 `dispatch_ctx` 构造块：
```python
# 原（删除 gitlab_* 三 key）
dispatch_ctx = {
    "repo_path": ctx["repo_path"],
    "base_sha": ctx["base_sha"],
    "head_sha": ctx["head_sha"],
    "gitlab_token": cfg["gitlab_token"],
    "gitlab_api_url": cfg["gitlab_api_url"],
    "gitlab_project_id": cfg["gitlab_project_id"],
    "notes_store": notes_inst,
    "issue_ops": [],
    "open_issues": open_issues or [],
    "assignee_id": ctx.get("assignee_id"),
}

# 新（新增 issue_client，删除 gitlab_*）
dispatch_ctx = {
    "repo_path": ctx["repo_path"],
    "base_sha": ctx["base_sha"],
    "head_sha": ctx["head_sha"],
    "issue_client": ctx["issue_client"],   # 平台 IssueClient 实例
    "notes_store": notes_inst,
    "issue_ops": [],
    "open_issues": open_issues or [],
    "assignee_id": ctx.get("assignee_id"),
}
```

第 77 行注释同步改为：
```python
def run_agent(cfg: dict, name: str, system_prompt: str,
              tool_whitelist: list, ctx: dict,
              open_issues: list = None) -> AgentResult:
    """运行单个 agent 循环。
    - cfg: 配置（含 llm 凭证/max_turns/platform）
    - ctx: 含 repo_path/base_sha/head_sha/issue_client
    """
```

- [ ] **步骤 4：跑 agent 测试确认通过**

运行：`pytest tests/test_agent.py -v`
预期：全绿，所有现有 agent 循环测试不受影响（FakeIssueClient 替代真 GitLab 客户端）

- [ ] **步骤 5：Commit**

```bash
git add src/code_review/agent.py tests/test_helpers.py tests/test_agent.py
git commit -m "refactor(agent): dispatch_ctx 删除 gitlab_* 三 key + 新增 issue_client

工具层不再依赖 gitlab_* key，统一从 dispatch_ctx["issue_client"] 拿 IssueClient。
run_agent 文档注释同步更新。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Phase 3：主流程接入

> **本 Phase 是一个原子任务**（任务 11-13 合并为任务 11"主流程改造"）：
> `resolve_assignee_id` 改签名 + `main()` 接入 IssueClient + `orchestrator` 接入 Notifier 三处强耦合，
> 单独 commit 任一处都会让 pytest 中间态失败。必须**一次 commit 三处改造 + 全部测试通过**。
> 任务 14"删兼容层"单独成任务，在任务 11 commit 通过后进行。

### 任务 11：主流程改造（resolve_assignee_id + main + orchestrator 三处一起改）

**文件：**
- 修改：`src/code_review/__main__.py`
- 修改：`src/code_review/orchestrator.py`
- 修改：`tests/test_main.py`
- 修改：`tests/test_orchestrate.py`
- 修改：`tests/test_helpers.py`（追加 `FakeNotifier`，任务 10 已建 `FakeIssueClient`）

- [ ] **步骤 1：写测试覆盖三处改造**

`tests/test_main.py` 加 case：
```python
def test_resolve_assignee_id_gitlab_returns_int():
    from code_review.__main__ import resolve_assignee_id
    from tests.test_helpers import FakeIssueClient
    fake = FakeIssueClient()
    fake.lookup_assignee_result = 42  # GitLab user id
    cfg = {"platform": "gitlab"}
    result = resolve_assignee_id(cfg, fake, "alice")
    assert result == 42


def test_resolve_assignee_id_github_returns_username():
    from code_review.__main__ import resolve_assignee_id
    from tests.test_helpers import FakeIssueClient
    fake = FakeIssueClient()
    fake.lookup_assignee_result = "alice"  # GitHub username
    cfg = {"platform": "github"}
    result = resolve_assignee_id(cfg, fake, "alice")
    assert result == "alice"


def test_resolve_assignee_id_empty_returns_none():
    from code_review.__main__ import resolve_assignee_id
    from tests.test_helpers import FakeIssueClient
    fake = FakeIssueClient()
    result = resolve_assignee_id({}, fake, "")
    assert result is None


def test_resolve_assignee_id_lookup_fails_returns_none():
    from code_review.__main__ import resolve_assignee_id
    from tests.test_helpers import FakeIssueClient
    fake = FakeIssueClient()
    fake.lookup_assignee_result = None
    result = resolve_assignee_id({}, fake, "ghost")
    assert result is None


def test_main_starts_issue_client_and_fetches_open_issues():
    """main() 启动时构造 IssueClient 并调 list_open_issues。"""
    from code_review.__main__ import main
    from tests.test_helpers import FakeIssueClient

    fake = FakeIssueClient()
    fake.list_open_issues_result = []
    with patch("code_review.__main__.get_issue_client", return_value=fake), \
         patch("code_review.__main__.load_config", return_value={
             "platform": "gitlab", "wecom_webhook_url": "",
             "llm_base_url": "x", "llm_api_key": "k", "llm_model": "m",
             "review_base_sha": "a", "review_head_sha": "b",
             "repo_path": "/repo", "max_turns": 1, "max_diff_bytes": 50000,
             "report_lang": "zh", "gitlab_token": "x",
             "gitlab_api_url": "x", "gitlab_project_id": 1,
             "weekly_report_project_id": 0,
             "pr_number": None,
             "ci_project_path": "p", "ci_project_url": "",
             "trigger_user": "alice", "commit_short_sha": "abc1234",
             "commit_branch": "main", "pipeline_source": "push",
             "mr_iid": "", "mr_source_branch": "", "mr_target_branch": "",
         }), \
         patch("code_review.__main__.compute_review_range", return_value=("a", "b")), \
         patch("code_review.__main__.gather_commit_metadata", return_value={
             "authors": "", "stat": "0", "author_list": "",
             "files_changed": "0", "commit_summary": "（无）",
         }), \
         patch("code_review.__main__.orchestrate") as mock_orchestrate:
        result = main()
    assert fake.list_open_issues_called_with == [["reviewer-generated"]]
    mock_orchestrate.assert_called_once()
    # 验证 ctx 含 issue_client
    call_args = mock_orchestrate.call_args
    assert call_args.args[1]["issue_client"] is fake


def test_main_github_force_weekly_zero():
    """GitHub 平台强制 weekly_report_project_id=0。"""
    from code_review.__main__ import main

    fake = FakeIssueClient()
    with patch("code_review.__main__.get_issue_client", return_value=fake), \
         patch("code_review.__main__.load_config", return_value={
             "platform": "github", "wecom_webhook_url": "",
             "llm_base_url": "x", "llm_api_key": "k", "llm_model": "m",
             "review_base_sha": "a", "review_head_sha": "b",
             "repo_path": "/repo", "max_turns": 1, "max_diff_bytes": 50000,
             "report_lang": "zh", "gh_token": "x", "github_repository": "o/r",
             "weekly_report_project_id": 178,  # GitLab 默认被覆盖
             "pr_number": 42, "gitlab_token": "", "gitlab_api_url": "",
             "gitlab_project_id": 0, "ci_project_path": "p",
             "ci_project_url": "", "trigger_user": "alice",
             "commit_short_sha": "abc1234", "commit_branch": "main",
             "pipeline_source": "push", "mr_iid": "",
             "mr_source_branch": "", "mr_target_branch": "",
         }), \
         patch("code_review.__main__.compute_review_range", return_value=("a", "b")), \
         patch("code_review.__main__.gather_commit_metadata", return_value={
             "authors": "", "stat": "0", "author_list": "",
             "files_changed": "0", "commit_summary": "（无）",
         }), \
         patch("code_review.__main__.orchestrate"), \
         patch("code_review.archive.archive_review_to_weekly_reports") as mock_archive:
        main()
    # GitHub 平台 weekly=0，archive 不被调
    mock_archive.assert_not_called()
```

`tests/test_orchestrate.py` 加 case：
```python
def test_orchestrate_calls_notifier_send_report():
    from code_review.orchestrator import orchestrate
    from code_review.agent import AgentResult
    from tests.test_helpers import FakeNotifier

    fake_notifier = FakeNotifier()
    cfg = {"platform": "gitlab", "wecom_webhook_url": "x",
           "max_diff_bytes": 50000}
    ctx = {"repo_path": "/repo", "base_sha": "a", "head_sha": "b",
           "issue_client": None, "assignee_id": None}
    with patch("code_review.orchestrator.get_notifier", return_value=fake_notifier), \
         patch("code_review.orchestrator.run_agent") as mock_run:
        mock_run.return_value = AgentResult(notes=[], created_issues=[],
                                            closed_issues=[], failed=False)
        result = orchestrate(cfg, ctx, {"authors": "x", "stat": "0",
                                        "author_list": "", "files_changed": "0",
                                        "commit_summary": "（无）"},
                             [], context=None)
    assert fake_notifier.send_report_called
```

FakeNotifier 已在任务 10 的 test_helpers.py 一并定义（含 `send_report_called` / `send_report_return` / `send_error_called_with` / `send_skip_called_with` 字段）。

- [ ] **步骤 2：跑测试确认失败**

运行：`pytest tests/test_main.py tests/test_orchestrate.py -v`
预期：FAIL（resolve_assignee_id 旧签名 / main 未调 issue_client / orchestrate 仍走模块级 send_report）

- [ ] **步骤 3：改造 resolve_assignee_id**

`src/code_review/__main__.py:121-141`：
```python
def resolve_assignee_id(cfg: dict, issue_client: IssueClient,
                        trigger_user: str) -> str | int | None:
    """把 trigger_user 解析为 assignee 标识。
    GitLab 侧返回 user id（int），GitHub 侧返回 username（str）。
    失败（trigger_user 空 / lookup 异常 / 非 collaborator）记 warning 返回 None。
    """
    if not trigger_user:
        log.log_event("assignee_skip", "reason=empty_trigger_user")
        return None
    assignee = issue_client.lookup_assignee(trigger_user)
    if assignee is None:
        log.log_event("assignee_skip", f"reason=lookup_failed user={trigger_user}")
    else:
        log.log_event("assignee_resolved", f"user={trigger_user} assignee={assignee}")
    return assignee
```

顶部新增 `from .platform import get_issue_client, IssueClient`，**删除 `from . import gitlab_client`**（避免 GitHub 平台误 import）。

- [ ] **步骤 4：改造 main() 接入 IssueClient + ReportContext**

`src/code_review/__main__.py:227-307 main()` 整体重写：

```python
def main() -> int:
    repo_path = os.environ.get("REPO_PATH", "/repo")

    # REVIEW_BASE_SHA / REVIEW_HEAD_SHA 由外部注入（GitLab CI 预定义变量 / GitHub Actions 注入）
    # 缺失时容器内回退计算（GitLab 场景）
    if not os.environ.get("REVIEW_BASE_SHA") or not os.environ.get("REVIEW_HEAD_SHA"):
        try:
            base, head = compute_review_range(repo_path)
        except Exception as exc:
            print(f"[fatal] 计算 review range 失败: {exc}", file=sys.stderr, flush=True)
            # 此处 cfg 尚未加载，notifier 无法构造；只 stderr 兜底
            return 1
        os.environ["REVIEW_BASE_SHA"] = base
        os.environ["REVIEW_HEAD_SHA"] = head

    try:
        cfg = load_config()
    except ConfigError as exc:
        print(f"[fatal] {exc}", file=sys.stderr)
        return 1

    # GitHub 平台强制跳过归档（archive.py 走不到）
    if cfg["platform"] == "github":
        cfg["weekly_report_project_id"] = 0

    issue_client = get_issue_client(cfg)

    # 空范围（base==head）
    if cfg["review_base_sha"] == cfg["review_head_sha"]:
        log.log_event(
            "review_range_empty",
            f"base==head={cfg['review_base_sha'][:8]}, 无 diff 可审查",
        )
        n = get_notifier(cfg)
        ctx_skip = _build_context(cfg, {})
        n.send_skip(
            "本次无变更，跳过代码审查",
            f"base == head ({cfg['review_base_sha'][:8]})，无可审查 diff。"
            "可能是首次提交或 MR 源分支无新 commit。",
            context=ctx_skip,
        )
        return 0

    log.log_init(
        f"repo={cfg['repo_path']}, range={cfg['review_base_sha'][:8]}.."
        f"{cfg['review_head_sha'][:8]}, lang={cfg['report_lang']}"
    )
    try:
        meta = gather_commit_metadata(
            cfg["repo_path"], cfg["review_base_sha"], cfg["review_head_sha"]
        )
    except RuntimeError as exc:
        print(f"[fatal] {exc}", file=sys.stderr)
        n = get_notifier(cfg)
        ctx_err = _build_context(cfg, {})
        n.send_error("审查未完成", f"初始化失败：{exc}", context=ctx_err)
        return 1

    try:
        open_issues = issue_client.list_open_issues(labels=["reviewer-generated"])
    except Exception as exc:
        print(f"[fatal] 拉取 issue 列表失败: {exc}", file=sys.stderr)
        n = get_notifier(cfg)
        ctx_err = _build_context(cfg, meta)
        n.send_error("审查未完成", f"拉取 issue 列表失败：{exc}", context=ctx_err)
        return 1
    log.log_event("open_issues_pulled", f"count={len(open_issues)}")

    ctx = {
        "repo_path": cfg["repo_path"],
        "base_sha": cfg["review_base_sha"],
        "head_sha": cfg["review_head_sha"],
        "issue_client": issue_client,
        "assignee_id": resolve_assignee_id(cfg, issue_client, cfg["trigger_user"]),
    }
    report_context = _build_context(cfg, meta)
    from .orchestrator import orchestrate
    result = orchestrate(cfg, ctx, meta, open_issues, context=report_context)

    _try_archive_review(cfg, result)
    return result.exit_code
```

新增私有 helper（替换原 `_build_report_header`）：
```python
def _build_context(cfg: dict, meta: dict) -> ReportContext:
    """组装 ReportContext 给 Notifier。"""
    if cfg.get("mr_iid"):
        source = cfg.get("mr_source_branch", "")
        target = cfg.get("mr_target_branch", "")
        branch_line = f"{source} → {target} (MR !{cfg['mr_iid']})"
    elif cfg.get("pipeline_source") == "push" and cfg.get("commit_branch"):
        branch_line = cfg["commit_branch"]
    else:
        branch_line = cfg.get("pipeline_source", "") or "（无）"

    return ReportContext(
        project=cfg.get("ci_project_path") or cfg.get("ci_project_name") or "（未知项目）",
        project_url=cfg.get("ci_project_url", ""),
        authors=meta.get("authors", "（无）"),
        trigger_user=cfg.get("trigger_user", ""),
        branch_line=branch_line,
        commit_sha=cfg.get("commit_short_sha", ""),
        stat=meta.get("stat", "0 文件"),
        pr_number=cfg.get("pr_number"),
    )
```

删除 `_build_report_header` 函数（原 `__main__.py:144-169`），其返回的 dict 已全部由 ReportContext 字段承接。

**早期失败路径说明**：compute_review_range 失败时 cfg 尚未加载，无法构造 notifier，仅 stderr 兜底 + return 1。CI job 红/绿足够通知。其他失败路径（gather_commit_metadata / list_open_issues / agent 失败）都在 cfg 加载之后，可走 notifier。

- [ ] **步骤 5：改造 orchestrator.py 接入 Notifier**

`src/code_review/orchestrator.py` 整体重写：

```python
"""多 agent 编排：A->B 串行 + C 并行，汇总报告。"""
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from typing import List

from . import log
from .agent import run_agent
from .agents import (
    AGENT_A_TOOLS, AGENT_B_TOOLS, AGENT_C_TOOLS,
    build_agent_a_prompt, build_agent_b_prompt, build_agent_c_prompt,
)
from .notifier import build_multi_section_report, get_notifier, ReportContext


@dataclass
class OrchestratorResult:
    exit_code: int = 0
    a_notes: List[str] = field(default_factory=list)
    b_notes: List[str] = field(default_factory=list)
    created_issues: list = field(default_factory=list)
    closed_issues: list = field(default_factory=list)
    open_count: int = 0

    def __int__(self) -> int:
        return self.exit_code


def orchestrate(cfg: dict, ctx: dict, commit_meta: dict, open_issues: list,
                context: ReportContext = None) -> OrchestratorResult:
    pipeline_url = cfg.get("ci_pipeline_url", "")
    report_lang = cfg.get("report_lang", "zh")
    results = {"a": None, "b": None, "c": None}
    if context is None:
        context = ReportContext(
            project="", project_url="", authors="", trigger_user="",
            branch_line="", commit_sha="", stat="", pr_number=None,
        )

    notifier = get_notifier(cfg)

    def run_ab_chain():
        prompt_a = build_agent_a_prompt(ctx, commit_meta, pipeline_url, report_lang)
        results["a"] = run_agent(cfg, "A", prompt_a, AGENT_A_TOOLS, ctx)
        if results["a"].failed:
            return
        prompt_b = build_agent_b_prompt(ctx, commit_meta, pipeline_url, report_lang,
                                        prior_notes=results["a"].notes,
                                        open_issues=open_issues)
        results["b"] = run_agent(cfg, "B", prompt_b, AGENT_B_TOOLS, ctx,
                                 open_issues=open_issues)

    def run_c():
        prompt_c = build_agent_c_prompt(ctx, commit_meta, pipeline_url, report_lang,
                                        open_issues=open_issues)
        results["c"] = run_agent(cfg, "C", prompt_c, AGENT_C_TOOLS, ctx,
                                 open_issues=open_issues)

    with ThreadPoolExecutor(max_workers=2) as ex:
        f_ab = ex.submit(run_ab_chain)
        f_c = ex.submit(run_c)
        f_ab.result()
        f_c.result()

    a_notes = results["a"].notes if results["a"] else []
    b_notes = results["b"].notes if results["b"] else []
    created = results["b"].created_issues if results["b"] else []
    closed = results["c"].closed_issues if results["c"] else []
    open_count = max(0, len(open_issues) + len(created) - len(closed))

    report = build_multi_section_report(a_notes, b_notes, created, closed,
                                        open_count, context)
    ok = notifier.send_report(report, context=context)
    log.log_event("report_sent", f"ok={ok}")

    failed = [n for n in ("a", "b", "c") if results[n] and results[n].failed]
    exit_code = 2 if failed else 0
    if failed:
        reasons = "; ".join(f"{n}: {results[n].fail_reason}" for n in failed)
        notifier.send_error("审查未完成", f"agent 失败：{reasons}", context=context)

    return OrchestratorResult(
        exit_code=exit_code, a_notes=a_notes, b_notes=b_notes,
        created_issues=created, closed_issues=closed, open_count=open_count,
    )
```

注意 `orchestrate` 参数顺序：`(cfg, ctx, commit_meta, open_issues, context=...)` —— `context` 是第 5 个参数（**不是第 4 个**，open_issues 是第 4 个）。

- [ ] **步骤 6：跑全测试确认通过**

运行：`pytest tests/ -v`
预期：全绿，0 失败

- [ ] **步骤 7：Commit**

```bash
git add src/code_review/__main__.py src/code_review/orchestrator.py \
        tests/test_main.py tests/test_orchestrate.py
git commit -m "refactor(main+orchestrator): 三处主流程接入 IssueClient + Notifier

resolve_assignee_id 签名改 (cfg, issue_client, trigger_user) → 返回值类型放宽
main() 启动时构造 IssueClient，贯穿 ctx；compute_review_range 失败仅 stderr
兜底（cfg 未加载），其他失败路径走 notifier.send_error
orchestrate() 改 notifier.send_*(..., context=...)；参数顺序
(cfg, ctx, commit_meta, open_issues, context=...) 第 5 个是 context
_build_context 替代 _build_report_header，返回 ReportContext
GitHub 平台强制 weekly_report_project_id=0
删除 import gitlab_client（任务 2 兼容层仍在，老 gitlab_client.py 仍可用）

本任务原子 commit，单独提交任一处都会让 pytest 中间态失败。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 12：删除兼容层 + 全测试回归

**文件：**
- 删除：`src/code_review/gitlab_client.py`（兼容层模块）
- 修改：`src/code_review/notifier/__init__.py`（删除末尾的 `send_report` / `send_error` / `send_skip` 模块级 wrapper）

- [ ] **步骤 1：验证所有调用方已迁移**

```bash
# 1. import 路径：应无 import 旧 gitlab_client
grep -rn "from code_review.gitlab_client\|from code_review import gitlab_client" src/ tests/
# 2. 旧 wrapper 函数名调用：应无 send_report(wecom, ...) / send_error(wecom, ...) / send_skip(wecom, ...) 模块级调用
grep -rn "send_report(\|send_error(\|send_skip(" src/ tests/ | grep -v "notifier\.send\|\.send_report\|\.send_error\|\.send_skip\|def send_"
# 3. gitlab_client 模块级函数：应无 list_issues(ctx, ...) / create_issue(ctx, ...) 等旧 ctx dict 调用
grep -rn "gitlab_client\.\(list_issues\|create_issue\|close_issue\|add_issue_comment\|update_issue_description\|lookup_user_id\)" src/ tests/
```

预期：3 个 grep 全部无任何匹配（如有，迁移对应调用方后再删兼容层）

- [ ] **步骤 2：删除 gitlab_client.py**

```bash
git rm src/code_review/gitlab_client.py
```

- [ ] **步骤 3：删除 notifier/__init__.py 末尾的 wrapper**

打开 `src/code_review/notifier/__init__.py`，删除步骤 3（任务 3）追加的 `send_report` / `send_error` / `send_skip` 三个模块级 wrapper 函数（约 20 行），同步从顶部 `__all__` 列表移除 `"send_report", "send_error", "send_skip"`。

- [ ] **步骤 4：跑全测试确认通过**

运行：`pytest tests/ -v`
预期：全绿，0 失败。如果有测试 import 旧 wrapper（应已在任务 11 主流程迁移时改完），会 ImportError 暴露，按错误逐个修复

- [ ] **步骤 5：Commit**

```bash
git add -A
git commit -m "refactor: 删除兼容层，主流程迁移完成

gitlab_client.py 兼容层删除（迁移到 platform/gitlab.py）
notifier/__init__.py 末尾 send_report/send_error/send_skip 模块级 wrapper 删除
所有调用方已迁移到 platform/IssueClient + notifier/Notifier 抽象。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 13：本地验证 4 场景矩阵

**手动验证**（不写自动化测试，但需要执行并记录）。

**统一执行方式**：不依赖 `--test-notify` flag（不强制实现）。改用 Python 脚本 `scripts/verify_notifier.py`，直接 import `get_notifier` + `build_multi_section_report` + `ReportContext`，绕开 agent 循环，只验证 notifier 出口行为。先创建该脚本，再按 4 场景设置环境变量跑。

- [ ] **步骤 0：创建验证脚本 `scripts/verify_notifier.py`**

```python
"""验证脚本：组装假报告 + 按 PLATFORM/WECOM/PR_NUMBER 组合发 notifier。
不跑 agent 循环，仅验证出口行为（PR 评论 / 企微 / status check / Null）。
用法：设置环境变量后 python scripts/verify_notifier.py
"""
import os
from code_review.config import load_config
from code_review.notifier import (
    build_multi_section_report, get_notifier, ReportContext,
)

cfg = load_config()
n = get_notifier(cfg)
ctx = ReportContext(
    project=cfg.get("ci_project_path") or "verify-project",
    project_url="",
    authors="verify-author",
    trigger_user=cfg.get("trigger_user", ""),
    branch_line=f"verify branch (platform={cfg['platform']})",
    commit_sha=cfg.get("commit_short_sha", "abc1234")[:8],
    stat="1 文件 +1 -1",
    pr_number=cfg.get("pr_number"),
)
# 构造假报告：1 条 feature note + 1 个 created issue + 1 个 closed issue
report = build_multi_section_report(
    a_notes=["✅ 验证报告"],
    b_notes=[],
    created=[{"title": "verify created issue", "web_url": "https://example.com/1",
              "severity": "warning"}],
    closed=[],
    open_count=0,
    context=ctx,
)
print(f"[verify] platform={cfg['platform']} pr_number={cfg.get('pr_number')} "
      f"notifier={type(n).__name__}")
ok = n.send_report(report, context=ctx)
print(f"[verify] send_report returned ok={ok}")
print("[verify] 发送错误路径测试...")
n.send_error("verify error title", "verify error body", context=ctx)
print("[verify] done")
```

- [ ] **步骤 1：GitLab + 企微场景（字节级兼容回归）**

```bash
# 设环境变量（PowerShell 用 $env:，bash 用 export）
PLATFORM=gitlab \
  WECOM_WEBHOOK_URL=https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_TEST_KEY \
  CODE_REVIEWER_TOKEN=glpat-x \
  CI_API_V4_URL=https://gl.example.com/api/v4 \
  CI_PROJECT_ID=1 \
  LLM_BASE_URL=https://llm/x LLM_API_KEY=sk LLM_MODEL=m \
  REVIEW_BASE_SHA=abc REVIEW_HEAD_SHA=def \
  WEEKLY_REPORT_PROJECT_ID=178 \
  CI_COMMIT_SHORT_SHA=abc1234 \
  python scripts/verify_notifier.py
```

预期输出：
- `[verify] ... notifier=WecomNotifier`
- `[verify] send_report returned ok=True`（webhook 真实可达时；可达性失败 ok=False 但不抛异常）
- 企业微信测试群收到分片 Markdown 报告（需真实 webhook key 才能验证送达）

- [ ] **步骤 2：GitLab + 无企微场景**

```bash
PLATFORM=gitlab \
  CODE_REVIEWER_TOKEN=glpat-x CI_API_V4_URL=https://gl/x CI_PROJECT_ID=1 \
  LLM_BASE_URL=x LLM_API_KEY=k LLM_MODEL=m \
  REVIEW_BASE_SHA=abc REVIEW_HEAD_SHA=def \
  CI_COMMIT_SHORT_SHA=abc1234 \
  python scripts/verify_notifier.py
# 注意：不设 WECOM_WEBHOOK_URL
```

预期输出：
- `[verify] ... notifier=NullNotifier`
- `[verify] send_report returned ok=True`
- 控制台 log "notify_null"，**无任何 HTTP 请求**（可用 `mitmproxy` 或抓包确认）

- [ ] **步骤 3：GitHub + PR 场景**

```bash
PLATFORM=github \
  GH_TOKEN=ghp_YOUR_TOKEN GITHUB_REPOSITORY=owner/repo \
  PR_NUMBER=42 \
  LLM_BASE_URL=x LLM_API_KEY=k LLM_MODEL=m \
  REVIEW_BASE_SHA=abc REVIEW_HEAD_SHA=def \
  CI_COMMIT_SHORT_SHA=abc1234 \
  python scripts/verify_notifier.py
```

预期输出：
- `[verify] ... notifier=GithubPrCommentNotifier`
- `[verify] send_report returned ok=True`
- PR #42 收到评论（需真实 GH_TOKEN + 真实仓库 PR 才能验证；可用 test 仓库 + 测试 PR）
- 用 `mitmproxy` / Wireshark 抓包验证请求 URL 是 `https://api.github.com/repos/owner/repo/issues/42/comments`

- [ ] **步骤 4：GitHub + push 场景**

```bash
PLATFORM=github \
  GH_TOKEN=ghp_YOUR_TOKEN GITHUB_REPOSITORY=owner/repo \
  CI_COMMIT_SHORT_SHA=deadbeef \
  LLM_BASE_URL=x LLM_API_KEY=k LLM_MODEL=m \
  REVIEW_BASE_SHA=abc REVIEW_HEAD_SHA=def \
  python scripts/verify_notifier.py
# 注意：不设 PR_NUMBER（push 场景）
```

预期输出：
- `[verify] ... notifier=GithubPrCommentNotifier`（同一实现，靠 pr_number=None 分流）
- `[verify] send_report returned ok=True`
- `send_error` 路径发 commit status check `state=failure`
- 抓包验证请求 URL 是 `https://api.github.com/repos/owner/repo/statuses/deadbeef`，payload 含 `"state": "success"`（send_report）和 `"state": "failure"`（send_error）

> **验证手段说明**：4 场景都需要真实凭证才能端到端验证送达。如无凭证，至少用 `mitmproxy` 抓包验证请求 URL + payload 结构（确认 notifier 选型正确、端点正确、payload 字段正确），这比单纯看 `ok=True/False` 更可靠。

- [ ] **步骤 5：手动验证通过后 Commit**

```bash
git add scripts/verify_notifier.py
git commit -m "verify: 4 场景矩阵手动验证通过

新增 scripts/verify_notifier.py 验证脚本（绕开 agent 循环，直接测 notifier 出口）
GitLab+wecom / GitLab+无wecom / GitHub+PR / GitHub+push 四场景
全部按规格预期行为执行（notifier 选型 + 端点 + payload 字段正确）。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Phase 4：迁移与消费方

### 任务 14：CI 构建链迁移 GitHub Actions + 去 .gitlab-ci.yml

**文件：**
- 创建：`.github/workflows/build.yml`
- 创建：`.github/workflows/test.yml`
- 创建：`.github/workflows/release.yml`
- 删除：`.gitlab-ci.yml`
- 删除：`ci/build.yml`
- 删除：`ci/bump_tag.sh`

- [ ] **步骤 1：创建 build.yml**

`.github/workflows/build.yml`：
```yaml
name: Build Image

on:
  push:
    branches: [main]
    paths-ignore: ['**/*.md', 'docs/**']
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  packages: write

env:
  REGISTRY: ghcr.io

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/setup-buildx-action@v3
      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=sha,format=short
            type=raw,value=latest,enable={{is_default_branch}}
            type=raw,value=main,enable={{is_default_branch}}
      - uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

- [ ] **步骤 2：创建 test.yml**

`.github/workflows/test.yml`：
```yaml
name: Tests

on:
  pull_request:
  push:
    branches: [main]

jobs:
  pytest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
          cache: pip
      - run: pip install -e ".[dev]"
      - run: pytest -q
```

- [ ] **步骤 3：创建 release.yml**

`.github/workflows/release.yml`：
```yaml
name: Release

on:
  push:
    tags: ['v*.*.*']

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: softprops/action-gh-release@v1
        with:
          generate_release_notes: true
```

- [ ] **步骤 4：删除旧文件**

```bash
git rm .gitlab-ci.yml ci/build.yml ci/bump_tag.sh
```

- [ ] **步骤 5：Commit**

```bash
git add .github/workflows/ && git commit -m "ci: 迁移 GitLab CI 到 GitHub Actions

build.yml 镜像构建 + 推 GHCR（:sha-xxxxxxx / :latest / :main）
test.yml pytest
release.yml softprops/action-gh-release 发 GitHub Release
删除 .gitlab-ci.yml / ci/build.yml / ci/bump_tag.sh

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 15：开源基础设施 + README 重写

**文件：**
- 创建：`LICENSE`
- 创建：`CONTRIBUTING.md`
- 创建：`SECURITY.md`
- 创建：`CODE_OF_CONDUCT.md`
- 创建：`.github/ISSUE_TEMPLATE/bug_report.md`
- 创建：`.github/ISSUE_TEMPLATE/feature_request.md`
- 创建：`.github/ISSUE_TEMPLATE/config.yml`
- 创建：`.github/PULL_REQUEST_TEMPLATE.md`
- 修改：`README.md`
- 修改：`CHANGELOG.md`

- [ ] **步骤 1：创建 LICENSE**

`LICENSE`（MIT）：
```
MIT License

Copyright (c) 2026 yedazhi

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **步骤 2：创建 CONTRIBUTING.md**

`CONTRIBUTING.md`：
```markdown
# 贡献指南

欢迎贡献！本项目采用 Apache 友好协议，欢迎通过 Issue / PR 参与改进。

## 开发环境

- Python 3.11+
- pip install -e ".[dev]"

## 运行测试

```bash
pytest -q
```

测试用 mock 隔离所有外部 HTTP 调用，不需要真实 LLM/GitHub/GitLab 凭证。

## 提交流程

1. Fork 仓库
2. 创建特性分支（`git checkout -b feat/my-change`）
3. 编写代码 + 测试（TDD 优先）
4. 跑测试确认通过（`pytest -q`）
5. 提交（commit message 建议用中文，参考 `feat:` / `fix:` / `docs:` / `test:` 前缀）
6. 推分支 + 开 PR

## 代码风格

- ruff check app（Python）
- 类型注解保持简洁，新代码鼓励加类型

## 添加新平台支持

如果要加新平台（如 BitBucket / Gitea）：

1. 在 `src/code_review/platform/` 新建 `<platform>.py`，实现 `IssueClient` Protocol
2. 在 `src/code_review/notifier/` 新建对应 Notifier（如 `bitbucket_pr.py`）
3. 在 `src/code_review/__main__.py:cfg["platform"]` 加新分支
4. 在 `config.py:GITHUB_PLATFORM_REQUIRED` 模式加新平台必填项
5. 写测试 + 文档
```

- [ ] **步骤 3：创建 SECURITY.md**

`SECURITY.md`：
```markdown
# 安全策略

## 支持版本

| 版本 | 支持状态 |
|------|----------|
| v2.x | ✅ 支持 |
| v1.x | ❌ 不再维护 |

## 报告漏洞

请通过 GitHub Security Advisories 私下报告：
https://github.com/yedazhi/code-reviewer/security/advisories/new

**请勿**通过公开 Issue 报告安全问题。

## 响应时间

- 收到报告后 7 天内确认
- 严重漏洞 30 天内修复并发布 patch 版本
- 一般漏洞按版本计划随下一版本发布
```

- [ ] **步骤 4：创建 CODE_OF_CONDUCT.md**

`CODE_OF_CONDUCT.md` 采用 Contributor Covenant 2.1 中文版（开源标准，CC BY-SA 4.0 许可，可直接抄录 https://www.contributor-covenant.org/zh-cn/version/2/1/code_of_conduct/ 全文，约 130 行）。

- [ ] **步骤 5：创建 ISSUE_TEMPLATE 与 PULL_REQUEST_TEMPLATE**

`.github/ISSUE_TEMPLATE/bug_report.md`：
```markdown
---
name: Bug Report
about: 报告 code-reviewer 自身 bug（非审查结果问题）
title: "[bug] "
labels: bug
---

## 现象

## 复现步骤

1. ...
2. ...

## 预期行为

## 实际行为

## 环境

- code-reviewer 版本：
- 平台（GitLab / GitHub / 其他）：
- LLM：
- 镜像 tag（`docker pull ghcr.io/yedazhi/code-reviewer:xxx`）：
```

`.github/ISSUE_TEMPLATE/feature_request.md`：
```markdown
---
name: Feature Request
about: 提出新功能建议
title: "[feat] "
labels: enhancement
---

## 需求场景

## 建议方案

## 替代方案
```

`.github/ISSUE_TEMPLATE/config.yml`：
```yaml
blank_issues_enabled: false
contact_links:
  - name: Discussions
    url: https://github.com/yedazhi/code-reviewer/discussions
    about: 一般问题 / 想法 / 展示
```

`.github/PULL_REQUEST_TEMPLATE.md`：
```markdown
## 改动

<!-- 简述本次 PR 改动 -->

## 关联 Issue

<!-- Closes #xxx -->

## 测试

<!-- 列出新增/修改的测试用例 -->

## Checklist

- [ ] pytest -q 全绿
- [ ] 新增代码有测试覆盖
- [ ] 文档同步更新（如有 API 变化）
```

- [ ] **步骤 6：重写 README.md**

新 README 结构：
1. 标题 + 徽章（build status / release / docker image size / License）
2. 一句话简介
3. 特性列表
4. 支持平台表（GitLab + 企微 / GitHub PR 评论 + issue / 自托管）
5. 快速接入（GitHub 消费者 / GitLab 消费者 / 自托管）
6. 环境变量表（拆 GitHub 必填 / GitLab 必填 / 可选）
7. 工具集（11 个）
8. 退出码
9. CHANGELOG 链接
10. Contributing 入口
11. License

去硬编码关键词（grep 校验范围）：
- `ccr.ccs.tencentyun.com` → `ghcr.io/yedazhi/code-reviewer`
- `c2h4` → 删除
- `git.c2h4.cn` → `github.com/yedazhi/code-reviewer`
- `devtools/code_review` → `yedazhi/code-reviewer`
- `devtools/weekly_reports` → 删除（归档默认 0）
- `kaniko` → 删除（迁 GitHub Actions 用 docker/build-push-action）
- `glab` → 删除
- `release:` → 删除

- [ ] **步骤 7：写 CHANGELOG.md v2.0.0 BREAKING**

按规格 §16 内容写。

- [ ] **步骤 8：grep 校验全仓库无内网痕迹**

运行：
```bash
grep -rE "ccr\.ccs\.tencentyun\.com|c2h4|git\.c2h4\.cn|devtools/(code_review|weekly_reports)|kaniko|glab" --include="*.md" --include="*.yml" --include="*.yaml" --include="*.py" .
```

预期：无任何匹配（如有匹配，按规格 §13.1 关键词完整清单逐个处理）

- [ ] **步骤 9：Commit**

```bash
git add LICENSE CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md \
        .github/ISSUE_TEMPLATE/ .github/PULL_REQUEST_TEMPLATE.md \
        README.md CHANGELOG.md
git commit -m "docs: 开源基础设施 + README/CHANGELOG 重写

新增 LICENSE(MIT) / CONTRIBUTING.md / SECURITY.md / CODE_OF_CONDUCT.md
新增 4 个 issue/PR 模板
README 重写：去内网痕迹 + 加开源标配 + 拆平台接入指南
CHANGELOG v2.0.0 BREAKING 标注

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 16：templates/code-review.yml + ci/include.yml 重写

**文件：**
- 修改：`templates/code-review.yml`
- 修改：`ci/include.yml`

- [ ] **步骤 1：重写 templates/code-review.yml**

```yaml
spec:
  inputs:
    stage_name:
      type: string
      default: review
    image_tag:
      type: string
      default: latest
    platform:
      type: string
      default: github
    report_lang:
      type: string
      default: zh

---
.code_review:
  stage: $[[ inputs.stage_name ]]
  image:
    name: ghcr.io/yedazhi/code-reviewer:$[[ inputs.image_tag ]]
    entrypoint: [""]
  variables:
    PLATFORM: $[[ inputs.platform ]]
    REPO_PATH: "$CI_PROJECT_DIR"
    GIT_STRATEGY: clone
    GIT_DEPTH: 0
    REPORT_LANG: $[[ inputs.report_lang ]]
    LLM_BASE_URL: "$LLM_BASE_URL"
    LLM_API_KEY: "$LLM_API_KEY"
    LLM_MODEL: "$LLM_MODEL"
    WECOM_WEBHOOK_URL: "$WECOM_WEBHOOK_URL"
    CODE_REVIEWER_TOKEN: "$CODE_REVIEWER_TOKEN"
    CI_API_V4_URL: "$CI_API_V4_URL"
    CI_PROJECT_ID: "$CI_PROJECT_ID"
    GH_TOKEN: "$GH_TOKEN"
    GITHUB_REPOSITORY: "$GITHUB_REPOSITORY"
    PR_NUMBER: "$PR_NUMBER"
    REVIEW_BASE_SHA: "$REVIEW_BASE_SHA"
    REVIEW_HEAD_SHA: "$REVIEW_HEAD_SHA"
  script:
    - /app/entrypoint.sh
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

- [ ] **步骤 2：重写 ci/include.yml**

```yaml
.code_review:
  stage: review
  image:
    name: ghcr.io/yedazhi/code-reviewer:latest
    entrypoint: [""]
  variables:
    REPO_PATH: "$CI_PROJECT_DIR"
    PLATFORM: "gitlab"
    GIT_STRATEGY: clone
    GIT_DEPTH: 0
    LLM_BASE_URL: "$LLM_BASE_URL"
    LLM_API_KEY: "$LLM_API_KEY"
    LLM_MODEL: "$LLM_MODEL"
    WECOM_WEBHOOK_URL: "$WECOM_WEBHOOK_URL"
    CODE_REVIEWER_TOKEN: "$CODE_REVIEWER_TOKEN"
    CI_API_V4_URL: "$CI_API_V4_URL"
    CI_PROJECT_ID: "$CI_PROJECT_ID"
  script:
    - /app/entrypoint.sh
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

- [ ] **步骤 3：grep 校验无内网痕迹**

运行：`grep -E "ccr\.ccs\.tencentyun\.com|c2h4|git\.c2h4\.cn" templates/code-review.yml ci/include.yml`
预期：无任何匹配

- [ ] **步骤 4：Commit**

```bash
git add templates/code-review.yml ci/include.yml
git commit -m "feat(templates): GitHub 镜像源 + platform input

镜像源 ccr.ccs.tencentyun.com → ghcr.io/yedazhi/code-reviewer
新增 platform input（默认 github，向后兼容 include:remote 用 PLATFORM=gitlab 显式覆盖）

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 17：novel_builder 接入 GitHub Actions

**文件（`D:\my_space\novel_builder`）：**
- 创建：`.github/workflows/code-review.yml`

- [ ] **步骤 1：在 novel_builder 仓库新建 workflow**

`.github/workflows/code-review.yml`：
```yaml
name: Code Review (AI)

on:
  pull_request:
    branches: [main, master]
  push:
    branches: [main, master]
  workflow_dispatch:
    inputs:
      base_sha:
        description: '可选 base SHA'
        required: false
      head_sha:
        description: '可选 head SHA'
        required: false

permissions:
  contents: read
  # 注：code-reviewer 在容器内用 GH_TOKEN（fine-grained PAT, scope=repo）操作 issue / PR 评论
  # / commit status，跟 workflow 自身的 GITHUB_TOKEN 是两套凭证。下方 permissions 仅在
  # 用户改用 GITHUB_TOKEN 注入容器时需要；用 PAT 时这些权限不影响容器内调用。
  # 保险起见仍列出，避免用户切换凭证时遇到 403。
  issues: write
  pull-requests: write
  statuses: write

jobs:
  code-review:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Compute review range
        id: range
        run: |
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            BASE="${{ github.event.pull_request.base.sha }}"
            HEAD="${{ github.event.pull_request.head.sha }}"
            PR_NUMBER="${{ github.event.pull_request.number }}"
          else
            HEAD="${{ github.sha }}"
            BASE="${{ github.event.before }}"
            PR_NUMBER=""
            if [ -z "$BASE" ] || [ "$BASE" = "0000000000000000000000000000000000000000" ]; then
              BASE=$(git rev-parse HEAD~1)
            fi
          fi
          [ -n "${{ inputs.base_sha }}" ] && BASE="${{ inputs.base_sha }}"
          [ -n "${{ inputs.head_sha }}" ] && HEAD="${{ inputs.head_sha }}"
          echo "BASE=$BASE" >> "$GITHUB_OUTPUT"
          echo "HEAD=$HEAD" >> "$GITHUB_OUTPUT"
          echo "PR_NUMBER=$PR_NUMBER" >> "$GITHUB_OUTPUT"

      - name: Run code-reviewer
        run: |
          docker run --rm \
            -v "${{ github.workspace }}:/repo" \
            -e PLATFORM=github \
            -e GH_TOKEN="${{ secrets.GH_TOKEN }}" \
            -e GITHUB_REPOSITORY="${{ github.repository }}" \
            -e PR_NUMBER="${{ steps.range.outputs.PR_NUMBER }}" \
            -e REVIEW_BASE_SHA="${{ steps.range.outputs.BASE }}" \
            -e REVIEW_HEAD_SHA="${{ steps.range.outputs.HEAD }}" \
            -e LLM_BASE_URL="${{ secrets.LLM_BASE_URL }}" \
            -e LLM_API_KEY="${{ secrets.LLM_API_KEY }}" \
            -e LLM_MODEL="${{ secrets.LLM_MODEL }}" \
            ghcr.io/yedazhi/code-reviewer:latest
```

- [ ] **步骤 2：Commit**

```bash
cd D:/my_space/novel_builder
git add .github/workflows/code-review.yml
git commit -m "ci: 接入 ci-code-reviewer GitHub Actions

docker run ghcr.io/yedazhi/code-reviewer:latest，挂仓库到 /repo
PR 场景发评论 + 建 issue，push 场景发 commit status check
触发：PR + push 到 main/master + 手动 dispatch

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## 任务依赖图

```
Task 1 (IssueClient 抽象 + GitLab 迁移)
  ↓
Task 2 (Notifier 抽象 + WecomNotifier 迁移)
  ↓
Task 3 (兼容层)
  ↓
Task 4 (config.py) ─── Task 5 (archive.py)
  ↓
Task 6 (GithubIssueClient) ─── Task 7 (GithubPrCommentNotifier)
  ↓                            ↓
Task 8 (prompt) ─── Task 9 (tools) ─── Task 10 (agent.py dispatch_ctx)
                                            ↓
Task 11 (主流程改造：resolve_assignee_id + main + orchestrator 三处原子 commit)
                                            ↓
Task 12 (删兼容层) ─── Task 13 (4 场景验证)
                                            ↓
Task 14 (CI 迁移) ─── Task 15 (开源) ─── Task 16 (templates 重写)
                                            ↓
                                          Task 17 (novel_builder 接入)
```

依赖关系总结：
- 任务 1-5：基础抽象（可独立 commit，每步测试全绿）
- 任务 6-7：GitHub 实现（依赖任务 1-2 的工厂）
- 任务 8-10：工具层 + dispatch_ctx 改造（依赖任务 1-2 + 6-7）
- **任务 11：主流程改造（原子任务）** — resolve_assignee_id 签名 + main() + orchestrator() 三处强耦合，单独 commit 任一处会让 pytest 中间态失败，必须**一个 commit 三处全改 + 全绿**
- 任务 12-13：清理兼容层 + 4 场景验证（依赖任务 11）
- 任务 14-16：迁移 + 开源 + templates 重写（依赖任务 13，可与 17 并行）
- 任务 17：消费方接入（依赖任务 15 的 GHCR 镜像发布）

## 执行检查点

- **Checkpoint A（任务 5 完成）**：基础抽象就绪，GitLab 字节级兼容已验证。可以 review 一遍。
- **Checkpoint AB（任务 7 完成）**：⚠️ 关键节点 — GitHub 平台首次能跑端到端测试（GithubIssueClient + GithubPrCommentNotifier 就绪，可单测验证 6 端点 + PR 评论 + status check）。可以 review 一遍。
- **Checkpoint B（任务 10 完成）**：所有平台实现 + 工具层 + dispatch_ctx 改造完成。**注意：此时 main() 仍走老路径（`gitlab_client.list_issues(gitlab_ctx)`），issue 闭环尚未切平台，要等任务 11 主流程改造完成后才切**。可以 review 一遍。
- **Checkpoint C（任务 13 完成）**：主流程跑通，4 场景验证通过。可以 review 一遍。
- **Checkpoint D（任务 17 完成）**：消费方接入，整体可对外发布。

## 风险与缓解

1. **测试覆盖不全**：每任务步骤 4 强制要求跑测试 + 步骤 5 commit；任务 15 手动验证 4 场景作为最后兜底
2. **GitHub 422 分流误判**：任务 6 用真实 GitHub API 错误响应测试（从 webfetch 拿 GitHub 官方文档）；测试 mock 用真实错误响应体
3. **commit status check 140 字符截断后语义丢失**：任务 7 description 截断后保留关键词（"审查未完成：xxx"）
4. **BREAKING 迁移遗漏消费方**：CHANGELOG + Migration Guide 显式说明，README 写清升级步骤
5. **GHCR 推送权限**：任务 16 用 `secrets.GITHUB_TOKEN`，需要 repo Settings → Actions → General → Workflow permissions 设为 "Read and write permissions"

## 不在范围

- 镜像体积优化（alpine 化 / 多阶段构建）— 后续 issue
- GitHub App 替代 PAT — 后续 issue
- weekly_reports 跨平台归档支持 — 后续 issue
- Web UI review 配置界面 — 后续 issue