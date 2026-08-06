# ci-code-reviewer GitHub 平台化与开源设计

**状态**：设计中
**日期**：2026-08-06
**作者**：Claude（协作设计）
**关联**：[ci-code-reviewer](D:\work\ci-code-reviewer)（待迁移源码），[novel_builder](D:\my_space\novel_builder)（消费方）

---

## 1. 背景与目标

### 现状

`D:\work\ci-code-reviewer` 是一个基于 GitLab CI 的 AI 代码审查工具，三 Agent（A 功能 / B 质量 / C 修复检测）+ 企业微信通知 + GitLab issue 闭环。它有五个跟 GitLab/公司内部硬耦合的点：

| 耦合点 | 文件 | 现状 |
|---|---|---|
| 必填环境变量 `CODE_REVIEWER_TOKEN` / `CI_API_V4_URL` / `CI_PROJECT_ID` | `config.py:67-70` | GitLab 平台特有 |
| 启动时强制调 `gitlab_client.list_issues()`，失败 exit 1 | `__main__.py:286` | 无平台分支 |
| `dispatch_ctx` 注入 GitLab API 凭证 | `agent.py:96-98` | 工具链绑定 |
| `assignee_id` 解析走 GitLab `users?username=` | `__main__.py:298` | GitLab 特有 |
| 审查结果归档到 GitLab `devtools/weekly_reports` (id=178) | `archive.py:46-51` + `config.py:74` | 公司内部项目 |
| 通知出口**只有**企业微信 | `notifier.py` 整体 | 无平台分支 |
| 镜像仓库 `ccr.ccs.tencentyun.com/c2h4/code_review` | README, templates, .gitlab-ci.yml | 公司内部 CCR |
| 构建/发布走 GitLab CI + `release:` 关键字 + glab | `.gitlab-ci.yml` | 公司内部 CI |

### 目标

把 `ci-code-reviewer` 改造成**双平台 + 开源**工具：

1. **GitHub 平台支持**：PR 评论 + issue 闭环，鉴权走 PAT，镜像发 GHCR
2. **保持 GitLab 平台完全兼容**：现有 GitLab 消费方零改动（仅镜像换源到 GHCR）
3. **企业微信通知保留为可选**：GitLab 平台可继续发企微，GitHub 平台不接企微
4. **代码开源到 `github.com/yedazhi/code-reviewer`**：去所有公司内部硬编码
5. **novel_builder 项目接入 GitHub Actions**：复用现有 PR 流程触发 AI 审查

### 非目标

- 不改 AI 审查 prompt 内容（agent_a / agent_b / agent_c 三 prompt 文本不变，仅术语替换）
- 不改报告 Markdown 结构（`build_multi_section_report` 输出格式不变）
- 不改 LLM 工具集（仍 11 个工具，仅 issue 相关工具实现切平台）
- 不改 `.cr-ignore.md` 解析协议（`issue: <iid>` 纯数字，GitHub `number` 通过抽象层映射成 `iid`，零改动）
- 不改 Agent A/B/C 串行 + 并行编排逻辑
- 不改 LLM 重试 / 指数退避策略

---

## 2. 架构总览

### 2.1 双平台 + 三层抽象

```
                    ┌─────────────────────────────────────┐
                    │      code_review/__main__           │
                    └─────────────────────────────────────┘
                                  │
                  ┌───────────────┼───────────────┐
                  │               │               │
              IssueClient     Notifier       Archive
                  │               │               │
        ┌─────────┴────────┐      │      ┌────────┴────────┐
        │                  │      │      │                 │
   GitLabClient    GithubClient  │  WecomNotifier  GithubPrCommentNotifier
                                 │      │                 │
                                 │   WecomWebhook     NullNotifier
                                 │   (GitLab 可选)   (兜底静默)
                                 │
                            Archive 现状：
                            GitLab → 推 weekly_reports
                            GitHub → 跳过
```

### 2.2 新仓库结构（`github.com/yedazhi/code-reviewer`）

```
code-reviewer/
├── src/code_review/
│   ├── __main__.py
│   ├── config.py
│   ├── orchestrator.py
│   ├── agent.py
│   ├── agents.py
│   ├── archive.py                   # 仅 GitLab 平台调用
│   ├── notifier/                    # 拆目录
│   │   ├── __init__.py              # Notifier 接口 + build_multi_section_report + 工厂
│   │   ├── base.py                  # NullNotifier
│   │   ├── wecom.py                 # WecomNotifier（行为字节级兼容）
│   │   └── github_pr.py             # GithubPrCommentNotifier
│   ├── platform/                    # 拆目录
│   │   ├── __init__.py              # IssueClient 抽象 + get_issue_client 工厂
│   │   ├── base.py                  # IssueClient ABC
│   │   ├── gitlab.py                # 现 gitlab_client.py 搬入
│   │   └── github.py                # 新增
│   ├── tools/
│   │   ├── create_issue.py          # 改调 ctx["issue_client"]
│   │   ├── close_issue.py           # 改调 ctx["issue_client"]
│   │   └── ...                      # 其他 9 个工具不动
│   ├── prompts/
│   │   ├── agent_a_feature.md       # 不动
│   │   ├── agent_b_quality.md       # 术语替换（GitLab issue → issue（GitHub））
│   │   ├── agent_c_repair.md        # 术语替换
│   │   └── weekly_member.md         # 不动
│   ├── cr_ignore.py                 # 不动（iid 抽象统一）
│   ├── log.py
│   └── prompt.py
├── tests/
│   ├── platform/
│   │   ├── test_factory.py          # 新
│   │   ├── test_github_client.py    # 新
│   │   └── test_gitlab_client.py    # 现 test_gitlab_client.py 迁入
│   ├── notifier/
│   │   ├── test_wecom.py            # 现 test_notifier.py 拆
│   │   ├── test_github_pr.py        # 新
│   │   ├── test_factory.py          # 新
│   │   └── test_report.py           # 新
│   ├── test_config.py               # 加 GitHub 必填项 case
│   ├── test_agents.py               # 加 prompt 平台分支 case
│   ├── test_tool_create_issue.py    # 改 fixture，加 issue_client key
│   ├── test_tool_close_issue.py     # 同上
│   └── ...                          # 其他测试不动
├── .github/workflows/
│   ├── build.yml                    # 镜像构建 + 推 GHCR
│   ├── test.yml                     # pytest
│   ├── release.yml                  # 发 GitHub Release
│   └── lint.yml                     # 可选，验证 templates 完整性
├── templates/
│   └── code-review.yml              # 默认 image_tag="latest" + platform input
├── ci/
│   └── include.yml                  # include:remote 兼容模板（GitHub raw URL）
├── docs/
├── README.md                        # 重写，去内网痕迹
├── CHANGELOG.md                     # 标注 v2.0.0 BREAKING
├── Dockerfile                       # 不变
├── pyproject.toml                   # 不变
└── requirements.txt
```

### 2.3 镜像版本管理策略（简化）

**采用方案 B：去掉自动 bump，仅打三个 tag**：

- `:sha-xxxxxxx`（短 SHA，可复现锁定）
- `:latest`（默认分支最新）
- `:main`（默认分支别名）

消费方默认 `:latest`，要复现显式锁 `:sha-xxxxxxx`。**彻底删除** `ci/bump_tag.sh` 和 GitLab `[skip ci]` commit 机制。

---

## 3. IssueClient 抽象

### 3.1 接口契约

```python
# src/code_review/platform/base.py
from typing import Protocol, runtime_checkable

@runtime_checkable
class IssueClient(Protocol):
    def list_open_issues(self, labels: list[str]) -> list[dict]:
        """返回 [{"iid", "title", "description", "web_url", "labels"}, ...]
        iid 字段在 GitLab 侧是 issue iid，在 GitHub 侧映射自 issue number。
        """

    def create_issue(self, title: str, description: str,
                     labels: list[str], assignee_id=None) -> dict:
        """返回 {"iid", "web_url"}"""

    def close_issue(self, iid: int) -> dict: ...

    def add_comment(self, iid: int, body: str) -> dict: ...

    def update_description(self, iid: int, description: str) -> dict: ...

    def lookup_assignee(self, username: str) -> str | int | None:
        """GitLab 侧返回 user id（数字），GitHub 侧返回 username 字符串。
        失败（非 collaborator / 用户不存在）返回 None。"""
```

### 3.2 工厂

```python
# src/code_review/platform/__init__.py
def get_issue_client(cfg: dict) -> IssueClient:
    if cfg["platform"] == "github":
        from .github import GithubIssueClient
        return GithubIssueClient(token=cfg["gh_token"], repo=cfg["github_repository"])
    from .gitlab import GitlabIssueClient
    return GitlabIssueClient(
        api_url=cfg["gitlab_api_url"],
        token=cfg["gitlab_token"],
        project_id=cfg["gitlab_project_id"],
    )
```

### 3.3 GitHub 实现细节

**鉴权**：`Authorization: Bearer <token>` header（GitHub 推荐），PAT fine-grained，scope `repo`。

**端点映射**：

| 方法 | GitHub endpoint |
|------|-----------------|
| `list_open_issues` | `GET /repos/{o}/{r}/issues?labels=...&state=open&per_page=100` |
| `create_issue` | `POST /repos/{o}/{r}/issues` |
| `close_issue` | `PATCH /repos/{o}/{r}/issues/{n}` body `{"state":"closed"}` |
| `add_comment` | `POST /repos/{o}/{r}/issues/{n}/comments` |
| `update_description` | `PATCH /repos/{o}/{r}/issues/{n}` body `{"body":...}` |
| `lookup_assignee` | `GET /repos/{o}/{r}/collaborators/{u}/permission` |

**关键设计点**：

1. **`iid` ↔ `number` 映射**：所有 GitHub 响应里的 `number` 在内部立刻改 key 为 `iid`，工具层/`.cr-ignore.md` 解析层零改动
2. **labels 预过滤**：构造函数调用一次 `GET /labels` 缓存现有 label 集合；`create_issue` 过滤掉不存在的（GitHub 422 报错，GitLab 自动建）
3. **assignee 静默降级**：`create_issue` 时若 422 含 "assignee" → 自动去掉 `assignees` 字段重试一次，记 warning 日志
4. **rate limit 防御**：解析 `X-RateLimit-Remaining` / `X-RateLimit-Reset`，< 50 时 sleep 到 reset（≤ 5 分钟）；429/502/503 指数退避重试 3 次
5. **README 前置要求**：GitHub 接入前需手动创建 4 个 label（`reviewer-generated` / `severity::critical` / `severity::warning` / `severity::suggestion`），双保险机制

### 3.4 GitLab 实现迁移

现 `gitlab_client.py` 内容整体迁入 `platform/gitlab.py`，实现同一套 `IssueClient` 接口。**行为字节级不变**，原所有测试直接迁移不修改。

---

## 4. Notifier 抽象

### 4.1 接口契约

```python
# src/code_review/notifier/__init__.py
from typing import Protocol, runtime_checkable
from dataclasses import dataclass

@dataclass
class ReportContext:
    """本次审查的元信息，供 Notifier 实现拼头部/链接用。"""
    project: str
    project_url: str
    pr_number: int | None        # None 表示 push 场景
    head_sha: str
    branch_line: str
    authors: str
    stat: str
    trigger_user: str

@runtime_checkable
class Notifier(Protocol):
    def send_report(self, report: str, *, context: ReportContext) -> bool: ...
    def send_error(self, title: str, body: str, *, context: ReportContext) -> None: ...
    def send_skip(self, title: str, body: str, *, context: ReportContext) -> None: ...

def get_notifier(cfg: dict) -> Notifier: ...
```

### 4.2 `build_multi_section_report` 字段替换

原 `build_multi_section_report(..., header: dict)` 改成接收 `context: ReportContext`。`ReportContext` 字段跟原 `header` dict key 一一对应，**输出 Markdown 字节级一致**。

### 4.3 三种实现

#### `WecomNotifier`（保留，行为字节级兼容）

- 接收 `webhook_url`
- 复用现 `_split_to_chunks` / `_post_markdown` / `send_error` / `send_skip` / `send_report` 全部逻辑
- 原所有 `test_notifier.py` 用例迁移到 `tests/notifier/test_wecom.py`，不修改断言

#### `GithubPrCommentNotifier`（新增）

```python
class GithubPrCommentNotifier:
    def __init__(self, token: str, repo: str):
        self._token = token
        self._repo = repo
        self._api = "https://api.github.com"

    def send_report(self, report, *, context):
        if context.pr_number is None:
            log.log_event("notify_skip", "reason=no_pr_push_scenario")
            return True
        body = self._truncate(report, 65000)
        self._post_comment(context.pr_number, body)
        return True

    def send_error(self, title, body, *, context):
        if context.pr_number is None:
            return  # push 场景静默
        msg = f"## ⚠️ {title}\n\n{body}"
        self._post_comment(context.pr_number, self._truncate(msg, 65000))

    def send_skip(self, title, body, *, context):
        if context.pr_number is None:
            return
        msg = f"## ℹ️ {title}\n\n{body}"
        self._post_comment(context.pr_number, self._truncate(msg, 65000))

    def _post_comment(self, issue_number: int, body: str):
        url = f"{self._api}/repos/{self._repo}/issues/{issue_number}/comments"
        req = urllib.request.Request(url, data=json.dumps({"body": body}).encode(),
                                     headers={**self._headers()}, method="POST")
        with urllib.request.urlopen(req, timeout=15) as resp:
            resp.read()

    def _truncate(self, text, limit):
        return text if len(text) <= limit else text[:limit] + "\n\n…（报告超长已截断）"
```

**关键设计点**：

1. **PR 场景**：直接发评论，不分片（GitHub 评论上限 65536 字符远超企微 4000）
2. **push 场景**：`pr_number is None` → 静默（GitHub Actions job 红/绿足够）
3. **复用**：直接调 `_post_comment` 不复用 `GithubIssueClient._request`（避免 PR 评论请求共享 issue 客户端的 rate limit 计数）

#### `NullNotifier`（新增）

所有方法 no-op + log。GitLab + 不配企微 / GitHub + push 场景时兜底返回，永不抛异常。

### 4.4 工厂决策树

```python
def get_notifier(cfg: dict) -> Notifier:
    if cfg["platform"] == "github":
        return GithubPrCommentNotifier(
            token=cfg["gh_token"],
            repo=cfg["github_repository"],
        )
    wecom = cfg.get("wecom_webhook_url", "")
    if wecom:
        return WecomNotifier(webhook_url=wecom)
    return NullNotifier()
```

### 4.5 orchestrator.py 改动

```python
# 原
ok = send_report(cfg["wecom_webhook_url"], report)
# 新
notifier = get_notifier(cfg)
ok = notifier.send_report(report, context=ctx_for_notifier)
```

`__main__.py` 同步改造：`send_error` / `send_skip` 全部走 notifier。`cfg["wecom_webhook_url"]` 在 GitHub 平台不被 `get_notifier` 消费。

---

## 5. Config 改造

### 5.1 必填项拆分

```python
# config.py
GITLAB_REQUIRED = [
    "LLM_BASE_URL", "LLM_API_KEY", "LLM_MODEL", "WECOM_WEBHOOK_URL",  # 移到可选
    "REVIEW_BASE_SHA", "REVIEW_HEAD_SHA",
    "CODE_REVIEWER_TOKEN", "CI_API_V4_URL", "CI_PROJECT_ID",
]
GITHUB_REQUIRED = [
    "LLM_BASE_URL", "LLM_API_KEY", "LLM_MODEL",
    "REVIEW_BASE_SHA", "REVIEW_HEAD_SHA",
    "GH_TOKEN", "GITHUB_REPOSITORY",
]
COMMON_REQUIRED = ["LLM_BASE_URL", "LLM_API_KEY", "LLM_MODEL",
                   "REVIEW_BASE_SHA", "REVIEW_HEAD_SHA"]

# WECOM_WEBHOOK_URL 从必填改为可选（GitLab 可选 + GitHub 不需要）
# CODE_REVIEWER_TOKEN / CI_API_V4_URL / CI_PROJECT_ID 仅 GitLab 平台必填
# GH_TOKEN / GITHUB_REPOSITORY 仅 GitHub 平台必填
```

### 5.2 `PLATFORM` 环境变量

- 默认 `"gitlab"`（向后兼容）
- 取值：`"gitlab"` | `"github"`
- 决定 `IssueClient` / `Notifier` / `Archive` 三处平台分支

### 5.3 `WEEKLY_REPORT_PROJECT_ID` 默认值改 0 ⚠️ BREAKING

- **旧**：默认 178 = `devtools/weekly_reports`，GitLab 消费方自动归档
- **新**：默认 0 = 跳过归档
- **迁移**：现有 GitLab 消费方需要在 env 显式配 `WEEKLY_REPORT_PROJECT_ID=178` 保留归档行为
- **CHANGELOG**：v2.0.0 BREAKING 标注

### 5.4 新增 env

| Key | 平台 | 必填 | 说明 |
|-----|------|------|------|
| `PLATFORM` | - | 否 | 默认 `gitlab` |
| `GH_TOKEN` | GitHub | 是 | Fine-grained PAT，scope `repo` |
| `GITHUB_REPOSITORY` | GitHub | 是 | GitHub Actions 默认注入，格式 `owner/repo` |
| `PR_NUMBER` | GitHub | 否 | GitHub Actions 注入 PR 编号，push 场景为空 |
| `WECOM_WEBHOOK_URL` | GitLab | 否 | 配了才发企微；不配走 `NullNotifier` |

---

## 6. Prompt 改造

### 6.1 改造方式

不维护两份 prompt 文件。在 `agents.py` 加：

```python
PLATFORM_TERMS = {
    "gitlab": {
        "issue_system": "GitLab issue",
        "issue_label_intro": "会自动打上 reviewer-generated 和 severity 标签",
    },
    "github": {
        "issue_system": "GitHub issue",
        "issue_label_intro": "会自动打上 reviewer-generated 和 severity 标签（GitHub 需要仓库预创建这些 label）",
    },
}

def _substitute_platform_terms(text: str, platform: str) -> str:
    terms = PLATFORM_TERMS[platform]
    return (text
            .replace("GitLab issue", terms["issue_system"])
            .replace("在 GitLab 项目创建一个 issue", f"在 {terms['issue_system']} 创建一个 issue")
            .replace("GitLab issue（带 severity）", f"{terms['issue_system']}（带 severity）")
            .replace("关闭一个已确认被本次提交修复的 GitLab issue",
                     f"关闭一个已确认被本次提交修复的 {terms['issue_system']}")
            )
```

`build_prompt` 末尾调用一次。

### 6.2 不改动的部分

- 4 个 review 维度（复用/简化/效率/层次）
- take_note 格式（🟡/🟠/🔴 emoji）
- `<CR_IGNORE_IID_HASH>` / `<CR_IGNORE_IID_NUM>` 占位符机制（iid 抽象统一）
- `.cr-ignore.md` 协议
- 注释前缀表

---

## 7. 工具层改造

### 7.1 `tools/create_issue.py`

```python
from .. import platform

def handler(args: dict, ctx: dict) -> str:
    title = args["title"]
    severity = args["severity"]
    base_desc = args["description"] or ""
    client: IssueClient = ctx["issue_client"]
    assignee = ctx.get("assignee_id")  # 平台相关：GitLab 是数字 id，GitHub 是 username 字符串

    result = client.create_issue(
        title=title,
        description=base_desc,
        labels=["reviewer-generated", f"severity::{severity}"],
        assignee_id=assignee,
    )
    iid = result["iid"]
    final_desc = (base_desc
                  .replace(_IID_PLACEHOLDER_HASH, f"#{iid}")
                  .replace(_IID_PLACEHOLDER_NUM, f"{iid}"))
    if final_desc != base_desc:
        try:
            client.update_description(iid, final_desc)
        except Exception:
            pass
    ctx.setdefault("issue_ops", []).append({
        "op": "created", "iid": iid, "web_url": result["web_url"],
        "severity": severity, "title": title,
    })
    return f"已创建 issue #{iid}: {result['web_url']}"
```

### 7.2 `tools/close_issue.py`

同 7.1 模式：`ctx["issue_client"]` 取代直接 import `gitlab_client`。

### 7.3 其他 9 个工具

不动（`list_files` / `read_file` / `list_directory` / `git_diff` / `git_log` / `git_show` / `grep` / `take_note` / `read_notes`）。

---

## 8. Archive 处理

### 8.1 GitHub 平台

`__main__.py:_try_archive_review()` 已在 `if not cfg.get("weekly_report_project_id"): return` 守护。`__main__.py` 启动时显式置 0：

```python
if cfg["platform"] == "github":
    cfg["weekly_report_project_id"] = 0
```

### 8.2 GitLab 平台

`archive.py` 不动，逻辑保留。GitLab 消费方需要归档时显式配 `WEEKLY_REPORT_PROJECT_ID`（见 5.3 BREAKING 迁移）。

---

## 9. CI 构建链迁移

### 9.1 `.github/workflows/build.yml`

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
  IMAGE_NAME: ${{ github.repository }}

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

**镜像 tag**：
- `:sha-xxxxxxx` — 短 SHA，可复现锁定
- `:latest` — 默认分支最新
- `:main` — 默认分支别名

### 9.2 `.github/workflows/release.yml`

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

### 9.3 `.github/workflows/test.yml`

```yaml
name: Tests
on: [pull_request, push]
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

### 9.4 删除的文件

- `.gitlab-ci.yml`（整个）
- `ci/build.yml`
- `ci/bump_tag.sh`
- `ci/include.yml`（保留**重写**为 GitHub raw URL，见 9.5）

### 9.5 `ci/include.yml` 重写

```yaml
# 兼容 include:remote 模式消费方（GitLab CI）。
# image tag 跟随 :latest；如需复现，消费方 fork 此文件并锁具体 SHA。
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

---

## 10. templates/code-review.yml 重写

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

---

## 11. novel_builder 接入

### 11.1 `.github/workflows/code-review.yml`

```yaml
name: Code Review (AI)

on:
  pull_request:
    branches: [main, master]
  push:
    branches: [main, master]
  workflow_dispatch:
    inputs:
      base_sha: { description: '可选 base SHA', required: false }
      head_sha: { description: '可选 head SHA', required: false }

permissions:
  contents: read

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

### 11.2 GitHub Secrets 配置

| Secret | 用途 |
|--------|------|
| `GH_TOKEN` | Fine-grained PAT，scope `repo`，限本仓库 |
| `LLM_BASE_URL` | OpenAI 兼容 API 根地址 |
| `LLM_API_KEY` | LLM API token |
| `LLM_MODEL` | 模型名（如 `gpt-4`、`claude-sonnet-4-5`） |

不需要 `WECOM_WEBHOOK_URL`（GitHub 平台不接企微）。

### 11.3 前置：仓库预创建 label

在 novel_builder GitHub 仓库 Settings → Labels 手动创建：
- `reviewer-generated`（颜色自定）
- `severity::critical`（红色）
- `severity::warning`（橙色）
- `severity::suggestion`（黄色）

---

## 12. 去硬编码清单

| 文件 | 旧值 | 新值 |
|------|------|------|
| `templates/code-review.yml` | `ccr.ccs.tencentyun.com/c2h4/code_review:a7a2649f` | `ghcr.io/yedazhi/code-reviewer:latest` |
| `ci/include.yml` | `ccr.ccs.tencentyun.com/c2h4/code_review:a7a2649f` | `ghcr.io/yedazhi/code-reviewer:latest` |
| `README.md` 多处 `ccr.ccs.tencentyun.com` / `git.c2h4.cn` | 删除 | 改 `ghcr.io/yedazhi/code-reviewer` / `github.com/yedazhi/code-reviewer` |
| `config.py:74` `WEEKLY_REPORT_PROJECT_ID` 默认 178 | 178 | **0**（BREAKING） |
| `.gitlab-ci.yml` | 整个文件 | 删除 |
| `ci/build.yml` | kaniko 构建 | 删除 |
| `ci/bump_tag.sh` | 自动 bump | 删除 |
| `tests/test_archive.py` | 默认 178 假设 | 改默认 0 假设 |

---

## 13. 测试策略

### 13.1 新增测试

| 测试文件 | 覆盖 |
|----------|------|
| `tests/platform/test_factory.py` | `get_issue_client` 按 PLATFORM 返回正确实现 |
| `tests/platform/test_github_client.py` | mock `urlopen`，验证 6 个端点构造、labels 预过滤、422 降级、rate limit |
| `tests/platform/test_gitlab_client.py` | 现 `tests/test_gitlab_client.py` + `test_gitlab_client_api.py` 迁入 |
| `tests/notifier/test_factory.py` | `get_notifier` 决策树 4 分支 |
| `tests/notifier/test_wecom.py` | 现 `tests/test_notifier.py` 拆出来，断言字节级兼容 |
| `tests/notifier/test_github_pr.py` | PR 评论端点构造、截断、push 场景静默 |
| `tests/notifier/test_report.py` | `build_multi_section_report` 接收 `ReportContext` 后输出字符级等于原 `header` dict |

### 13.2 修改的现有测试

- `tests/test_config.py`：加 GitHub 必填项 case + WECOM_WEBHOOK_URL 改可选 case
- `tests/test_agents.py`：加 prompt 平台分支 case（`_substitute_platform_terms` 验证）
- `tests/test_tool_create_issue.py`：改 fixture，新增 `issue_client` key
- `tests/test_tool_close_issue.py`：同上
- `tests/test_archive.py`：默认 178 → 默认 0

### 13.3 兼容性回归验证

| 场景 | 老行为 | 新行为 |
|------|--------|--------|
| `PLATFORM=gitlab` + `WECOM_WEBHOOK_URL=xxx` + 全部 GitLab env | 发企微 + GitLab issue | `WecomNotifier` + `GitlabIssueClient`，字节级一致 ✅ |
| `PLATFORM=gitlab` + 不配 `WECOM_WEBHOOK_URL` | send_report 崩 NPE | `NullNotifier`，静默 ✅ |
| `PLATFORM=github` + PR 场景 | (原本不支持) | 发 PR 评论 + GitHub issue ✅ |
| `PLATFORM=github` + push 场景 | (原本不支持) | 静默（job 红/绿） ✅ |

---

## 14. 实施顺序

```
1. 本地改造 D:\work\ci-code-reviewer（不开 PR 不推，先本地跑测试）
   ├─ platform/ 拆目录 + github.py 新增 + gitlab.py 迁入
   ├─ notifier/ 拆目录 + github_pr.py 新增 + wecom.py 迁入
   ├─ tools/create_issue.py + close_issue.py 改调 ctx["issue_client"]
   ├─ config.py 拆分必填项 + WEEKLY_REPORT_PROJECT_ID 默认改 0
   ├─ __main__.py 读 PLATFORM + 组装 ReportContext + 平台分支
   ├─ orchestrator.py 改调 notifier.send_report(..., context=...)
   ├─ agents.py + 3 个 prompt 加 _substitute_platform_terms
   └─ tests/ 全套新加 + 现有 GitLab/Wecom 测试不删 + 跑 pytest 全绿

2. 本地验证 4 场景（PLATFORM + WECOM 组合矩阵）

3. 推新仓库 github.com/yedazhi/code-reviewer
   ├─ 一次性 git push（全部代码 + 重写 README + 删 .gitlab-ci.yml）
   ├─ 触发 build.yml → 推 :latest 镜像到 GHCR
   └─ 打 v2.0.0 tag → 触发 release.yml → 发 GitHub Release

4. novel_builder 接入
   ├─ 加 .github/workflows/code-review.yml
   ├─ 配 4 个 GitHub Secrets
   └─ 在 novel_builder 仓库预创建 4 个 label

5. 提交测试 PR 验证
   ├─ 测试 PR → code-reviewer 在 PR 评论 + 建 issue
   └─ 推到 master → 触发 code-reviewer，验证 push 场景静默
```

---

## 15. CHANGELOG 摘要

```markdown
## v2.0.0 (2026-08-06) — BREAKING

### Added
- **GitHub 平台支持**：通过 `PLATFORM=github` 启用。审查报告发 PR 评论，issue 走 GitHub REST API v3。
- **开源**：仓库迁至 `github.com/yedazhi/code-reviewer`，镜像发 `ghcr.io/yedazhi/code-reviewer`。
- **Notifier 抽象**：新增 `GithubPrCommentNotifier` 与 `NullNotifier`，`WecomNotifier` 保留为可选。

### Changed
- `WECOM_WEBHOOK_URL` 从必填改为可选（GitLab 平台配了才发企微）。
- 镜像 tag 策略：`:sha-xxxxxxx` / `:latest` / `:main`，去掉自动 bump。
- 目录结构：`platform/` 与 `notifier/` 子模块化。

### Removed (BREAKING)
- **`.gitlab-ci.yml` 整套构建链**：迁移到 `.github/workflows/`。
- **`ci/bump_tag.sh`**：镜像版本改为手动管理。
- **`WEEKLY_REPORT_PROJECT_ID` 默认值 178**：改为 0（跳过归档）。**需归档的 GitLab 消费方必须显式配此变量**。
- **`ccr.ccs.tencentyun.com` 镜像源**：改为 `ghcr.io/yedazhi/code-reviewer`。

### Migration Guide (v1.x → v2.0)
1. 镜像源换为 `ghcr.io/yedazhi/code-reviewer:latest`
2. 若仍需归档到 `devtools/weekly_reports`，env 加 `WEEKLY_REPORT_PROJECT_ID=178`
3. 若仅需审查+企微通知（不归档），删 `WEEKLY_REPORT_PROJECT_ID` 即可
4. CI 变量名不变，行为不变
```