# code-reviewer 独立 GitHub 仓库设计

**状态**：设计中
**日期**：2026-08-06
**作者**：Claude（协作设计）
**取代**：`2026-08-06-ci-code-reviewer-github-design.md`（双平台方案，已废弃——方向改为独立 GitHub 专用仓）

---

## 1. 背景与目标

### 现状

`D:\work\ci-code-reviewer` 是一个基于 GitLab CI 的 AI 代码审查工具（三 Agent：A 功能 / B 质量 / C 修复检测 + 企业微信通知 + GitLab issue 闭环 + 归档到 weekly_reports）。它跟 GitLab/公司内部强耦合，服务公司内网项目。

### 新方向

**独立新建一个 GitHub 专用开源仓库**，不改造现有 `ci-code-reviewer`。

- 新仓库位置：`D:\my_space\code-reviewer`
- GitHub 仓库：`github.com/yedazhi/code-reviewer`（开源）
- 定位：**纯 GitHub 专用**，删掉所有 GitLab 代码

### 与现有 ci-code-reviewer 的关系

- **现有 `D:\work\ci-code-reviewer` 完全不动**，继续在内网 GitLab 服务公司项目
- 新仓库从 `ci-code-reviewer` **复制核心代码**（三 agent 编排 + prompt + 只读工具集 + .cr-ignore + LLM 重试），**删除 GitLab 专用部分**（gitlab_client / 企微 / archive 归档 / GitLab CI / weekly 周报），**新写 GitHub 实现**
- 两仓库互不干扰，各走各的演进路线

### 目标

1. **GitHub 原生**：PR 评论 + issue 闭环（PAT 鉴权）+ push 场景 commit status check 兜底
2. **开源就绪**：LICENSE / CONTRIBUTING / SECURITY / CODE_OF_CONDUCT / Issue+PR 模板，镜像发 GHCR，CI 走 GitHub Actions
3. **novel_builder 接入**：通过 GitHub Actions 复用，PR 触发 AI 审查

### 非目标

- **不支持 GitLab**（纯 GitHub，无平台抽象层）
- **不接企业微信**（GitHub 原生用 PR 评论 + status check）
- **不做归档**（无 weekly_reports）
- **不做周报**（无 weekly/ 模块）
- **不改 AI 审查 prompt 核心内容**（仅术语替换 GitLab issue → GitHub issue）
- **不改报告 Markdown 结构**
- **不改 LLM 工具集**（仍 11 个工具，issue 工具实现切 GitHub）
- **不改 `.cr-ignore.md` 协议**（`issue: <iid>` 纯数字，GitHub `number` 直接用）
- **不改 Agent A/B/C 编排**（A→B 串行 + C 并行）
- **不改 LLM 重试策略**

---

## 2. 仓库结构（`D:\my_space\code-reviewer`）

```
code-reviewer/
├── src/code_review/
│   ├── __init__.py
│   ├── __main__.py                  # 改造：去 GitLab ctx，用 github_client + notifier
│   ├── agent.py                     # 复制 + 改 dispatch_ctx（gitlab_* → issue_client）
│   ├── agents.py                    # 复制 + prompt 术语替换
│   ├── config.py                    # 重写：GitHub 必填项
│   ├── cr_ignore.py                 # 复制（不改，iid 抽象统一）
│   ├── github_client.py             # 新写：GitHub issue API
│   ├── log.py                       # 复制（不改）
│   ├── notifier.py                  # 新写：PR 评论 + status check
│   ├── orchestrator.py              # 复制 + send_report 改调 notifier 实例
│   ├── prompt.py                    # 复制 + 加平台术语替换
│   ├── tools/
│   │   ├── __init__.py              # 复制（get_tool_definitions / dispatch）
│   │   ├── close_issue.py           # 复制 + 改调 github_client
│   │   ├── create_issue.py          # 复制 + 改调 github_client
│   │   ├── git_diff.py              # 复制（不改）
│   │   ├── git_log.py               # 复制（不改）
│   │   ├── git_show.py              # 复制（不改）
│   │   ├── grep.py                  # 复制（不改）
│   │   ├── list_directory.py        # 复制（不改）
│   │   ├── list_files.py            # 复制（不改）
│   │   ├── notes_store.py           # 复制（不改）
│   │   ├── read_file.py             # 复制（不改）
│   │   └── read_notes.py            # 复制（不改）
│   └── prompts/
│       ├── agent_a_feature.md       # 复制（不改）
│       ├── agent_b_quality.md       # 复制 + 术语替换
│       └── agent_c_repair.md        # 复制 + 术语替换
├── tests/
│   ├── test_github_client.py        # 新写
│   ├── test_notifier.py             # 新写
│   ├── test_config.py               # 新写
│   ├── test_main.py                 # 新写
│   ├── test_agent.py                # 复制 + 改 fixture
│   ├── test_orchestrate.py          # 复制 + 改 fixture
│   ├── test_agents.py               # 复制 + 加平台术语 case
│   ├── test_tool_create_issue.py    # 复制 + 改 fixture
│   ├── test_tool_close_issue.py     # 复制 + 改 fixture
│   ├── test_tool_*.py               # 复制其他工具测试（不改）
│   ├── test_cr_ignore.py            # 复制（不改）
│   ├── test_log.py                  # 复制（不改）
│   ├── test_prompt.py               # 复制（不改）
│   └── test_helpers.py              # 新写：FakeGithubClient + FakeNotifier
├── .github/
│   ├── workflows/
│   │   ├── build.yml                # 镜像构建 + 推 GHCR
│   │   ├── test.yml                 # pytest
│   │   └── release.yml              # 发 GitHub Release
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   ├── feature_request.md
│   │   └── config.yml
│   └── PULL_REQUEST_TEMPLATE.md
├── docs/
├── scripts/
│   └── verify_notifier.py           # 手动验证 notifier 出口
├── Dockerfile                       # 复制（不改）
├── entrypoint.sh                    # 复制（不改）
├── pyproject.toml                   # 复制（不改）
├── requirements.txt                 # 复制（不改）
├── README.md                        # 新写
├── CHANGELOG.md                     # 新写（v1.0.0，无 BREAKING）
├── CONTRIBUTING.md                  # 新写
├── SECURITY.md                      # 新写
├── CODE_OF_CONDUCT.md               # 新写
└── LICENSE                          # 新写（MIT）
```

---

## 3. 代码来源清单

### 从 `D:\work\ci-code-reviewer` 复制（保留核心，几乎不改）

| 文件 | 改动 |
|------|------|
| `agent.py` | 改 `dispatch_ctx`：删 `gitlab_token/gitlab_api_url/gitlab_project_id` 三 key，加 `issue_client` |
| `agents.py` | 加 `_substitute_platform_terms`（GitLab issue → GitHub issue） |
| `orchestrator.py` | `send_report`/`send_error` 改调 `notifier` 实例（不再模块级函数） |
| `prompt.py` | `build_prompt` 末尾调术语替换 |
| `cr_ignore.py` | 不改 |
| `log.py` | 不改 |
| `tools/__init__.py` | 不改 |
| `tools/{git_diff,git_log,git_show,grep,list_directory,list_files,notes_store,read_file,read_notes,take_note}.py` | 不改（10 个只读/笔记工具） |
| `prompts/agent_a_feature.md` | 不改 |
| `Dockerfile` | 不改 |
| `entrypoint.sh` | 不改 |
| `pyproject.toml` / `requirements.txt` | 不改 |

### 删除（不复制，GitLab/公司专用）

| 文件 | 原因 |
|------|------|
| `gitlab_client.py` | 换成 `github_client.py` |
| `notifier.py`（企微） | 换成新 `notifier.py`（PR 评论 + status check） |
| `archive.py` | 不归档 |
| `weekly/` 整个目录 | 周报功能，公司内部 |
| `entrypoint_weekly.sh` | 周报入口 |
| `prompts/weekly_member.md` | 周报专用 |
| `.gitlab-ci.yml` | 换 GitHub Actions |
| `ci/` 整个目录（build.yml / include.yml / bump_tag.sh） | GitLab CI 专用 |
| `templates/code-review.yml` | GitLab CI 组件（新仓不需要 include 机制） |
| `bump_test/` | 与 bump_tag 相关 |

### 新写

| 文件 | 职责 |
|------|------|
| `github_client.py` | GitHub REST API v3：list/create/close/comment/update_description/lookup_assignee |
| `notifier.py` | GithubPrNotifier：PR 评论 + commit status check |
| `config.py` | GitHub 必填项（GH_TOKEN / GITHUB_REPOSITORY / LLM_* / REVIEW_*） |
| `__main__.py` | 主流程（github_client + notifier，无 GitLab 分支） |
| `tools/create_issue.py` | 改调 `github_client`（直接，无抽象层） |
| `tools/close_issue.py` | 同上 |
| `.github/workflows/{build,test,release}.yml` | CI |
| 开源基础设施 7 个文件 | LICENSE / README / CONTRIBUTING / SECURITY / CODE_OF_CONDUCT / 4 个模板 |
| `tests/test_github_client.py` / `test_notifier.py` / `test_config.py` / `test_main.py` / `test_helpers.py` | 新测试 |

---

## 4. github_client.py 设计

**鉴权**：`Authorization: Bearer <token>` header，fine-grained PAT，scope `repo`。

**端点**（REST API v3）：

| 方法 | endpoint |
|------|----------|
| `list_open_issues(labels)` | `GET /repos/{o}/{r}/issues?labels=...&state=open&per_page=100` |
| `create_issue(title, body, labels, assignee)` | `POST /repos/{o}/{r}/issues` |
| `close_issue(number)` | `PATCH /repos/{o}/{r}/issues/{n}` body `{"state":"closed"}` |
| `add_comment(number, body)` | `POST /repos/{o}/{r}/issues/{n}/comments` |
| `update_description(number, body)` | `PATCH /repos/{o}/{r}/issues/{n}` body `{"body":...}` |
| `lookup_assignee(username)` | `GET /repos/{o}/{r}/collaborators/{u}/permission` |

**返回值**：直接用 GitHub 原生字段（`number` / `html_url` / `title` / `body` / `labels`）。**不做 iid 映射**——新仓从零写，工具层/prompt/`.cr-ignore` 统一用 `number` 这个词（或者沿用 `iid` 别名，见下方）。

> **`iid` 别名决策**：为最小化复制过来的代码改动（`create_issue.py` / `close_issue.py` / `.cr-ignore` / prompt / 报告模板里都写的是 `iid`），`github_client` 返回值里用 `iid` 作为 `number` 的 key 别名。这样下游代码零改动。`iid` 在新仓就是 GitHub issue number 的内部叫法。

**关键设计点**：

1. **labels 预过滤**：构造函数调一次 `GET /labels` 缓存现有 label 集合；`create_issue` 过滤掉不存在的（GitHub 422 报错）。
   - **缓存失败兜底**：`GET /labels` 抛异常 → `_available_labels` 落空集；`create_issue` 在空集时**不过滤**直接传原 labels，让 422 自然触发降级路径。不阻断启动。

2. **422 错误分流**（防止 LLM 死循环）：
   - 422 + 响应体含 `"assignees"` → 去掉 `assignees` 重试一次（assignee 静默降级）
   - 422 + 响应体含 `"labels"` → 去掉 `labels` 重试一次，记 warning 提醒补建 label
   - 422 + 其他字段（title/body） → 不重试，原异常抛回 LLM
   - 重试仍 422 → 抛回 LLM

3. **assignee 静默降级**：`create_issue` 时 422 含 assignee → 去掉 `assignees` 字段重试一次。非 collaborator 触发 422 时自动降级为不指派。

4. **rate limit 防御**：解析 `X-RateLimit-Remaining` / `X-RateLimit-Reset`，< 50 时 sleep 到 reset（≤ 5 分钟）；429/502/503 指数退避重试 3 次。

5. **README 前置要求**：接入前需手动创建 4 个 label（`reviewer-generated` / `severity::critical` / `severity::warning` / `severity::suggestion`），代码预过滤 + 文档双保险。

---

## 5. notifier.py 设计（PR 评论 + status check）

**单一类 `GithubPrNotifier`**，无抽象层、无工厂。

```python
class GithubPrNotifier:
    COMMENTS_LIMIT = 65000
    STATUS_DESCRIPTION_LIMIT = 140
    STATUS_CONTEXT = "ci-code-reviewer/ai"

    def __init__(self, token: str, repo: str): ...

    def send_report(self, report: str, *, context: ReportContext) -> bool:
        # PR 场景（pr_number 非 None）：发评论
        # push 场景（pr_number None）：发 commit status check state=success

    def send_error(self, title: str, body: str, *, context: ReportContext) -> None:
        # PR 场景：发评论
        # push 场景：发 status check state=failure

    def send_skip(self, title: str, body: str, *, context: ReportContext) -> None:
        # PR 场景：发评论
        # push 场景：不发（skip 不是失败）
```

**关键设计点**：

1. **PR 场景**：直接发评论，不分片（GitHub 评论上限 65536 字符远超需求）。超长截断 + "…（报告超长已截断）"。
2. **push 场景兜底**：无 PR 可评论，改发 **commit status check** 让 GitHub UI / `git push` 输出立刻可见。
   - `send_report` 成功 → `state=success`
   - `send_error` → `state=failure`
   - `send_skip` → 不发 status（不是失败，只是本次无 diff）
3. **description 截断 140 字符**：GitHub API 硬限制。
4. **context 名 `ci-code-reviewer/ai`**：唯一标识避免与 GitHub Actions 的同名 context 撞车。
5. **status check 失败吞异常**：不能因为兜底通知失败把主流程崩了。

**`ReportContext` dataclass**（沿用原设计的字段，但精简）：
```python
@dataclass
class ReportContext:
    project: str
    project_url: str
    authors: str
    trigger_user: str
    branch_line: str
    commit_sha: str       # short sha，渲染报告头部用
    stat: str
    pr_number: int | None # PR 场景非 None，push 场景 None
```

**`build_multi_section_report`** 从原 `ci-code-reviewer/notifier.py` 迁入（纯字符串拼接，无 IO），接收 `ReportContext`。

---

## 6. config.py（GitHub 必填项，无 PLATFORM 分支）

```python
REQUIRED = [
    "LLM_BASE_URL",
    "LLM_API_KEY",
    "LLM_MODEL",
    "REVIEW_BASE_SHA",
    "REVIEW_HEAD_SHA",
    "GH_TOKEN",
    "GITHUB_REPOSITORY",
]
```

**可选 env**：
- `REPO_PATH`（默认 `/repo`）
- `MAX_TURNS`（默认 200）
- `MAX_DIFF_BYTES`（默认 50000）
- `REPORT_LANG`（默认 `zh`）
- `PR_NUMBER`（默认 None，push 场景不设）
- `CI_PIPELINE_URL` / `CI_PROJECT_PATH` / `CI_PROJECT_URL` / `GITHUB_ACTOR` 等（渲染报告头部用，可选）

**不要**：`PLATFORM` / `WECOM_WEBHOOK_URL` / `CODE_REVIEWER_TOKEN` / `CI_API_V4_URL` / `CI_PROJECT_ID` / `WEEKLY_REPORT_PROJECT_ID`。

**`REVIEW_BASE_SHA` / `REVIEW_HEAD_SHA` 必填**：容器内**不计算** commit range（原 `compute_review_range` 函数删除）。GitHub Actions 端算好传入。未传则 `ConfigError`。

**`trigger_user`**：从 `GITHUB_ACTOR` 读（GitHub Actions 默认注入触发者 username）。

---

## 7. __main__.py 主流程

```
load_config()
  → github_client = GithubIssueClient(GH_TOKEN, GITHUB_REPOSITORY)
  → notifier = GithubPrNotifier(GH_TOKEN, GITHUB_REPOSITORY)
  → 空 range 检查（base==head）→ notifier.send_skip
  → gather_commit_metadata（git log/diff 元信息）
  → open_issues = github_client.list_open_issues(["reviewer-generated"])
  → assignee = github_client.lookup_assignee(trigger_user)  # None 则不指派
  → ctx = {repo_path, base_sha, head_sha, issue_client: github_client, assignee_id: assignee}
  → report_context = ReportContext(...)
  → result = orchestrate(cfg, ctx, meta, open_issues, context=report_context)
  → return result.exit_code
```

**失败路径**：
- `gather_commit_metadata` 失败 → `notifier.send_error("审查未完成", ...)` + return 1
- `list_open_issues` 失败 → `notifier.send_error` + return 1（拉不到 issue 列表 = 闭环不可用，硬退）
- agent 失败 → orchestrator 内部 `notifier.send_error` + exit 2

**删除的函数**：`compute_review_range`（容器内不算 range）、`resolve_assignee_id`（直接调 `github_client.lookup_assignee`，一行）、`_try_archive_review`（不归档）、GitLab ctx 构造。

---

## 8. tools/create_issue.py + close_issue.py

直接调 `ctx["issue_client"]`（`GithubIssueClient` 实例）。从原 ci-code-reviewer 复制后，把 `from .. import gitlab_client` + `gitlab_client.xxx(ctx, ...)` 改成 `ctx["issue_client"].xxx(...)`。

`<CR_IGNORE_IID_HASH>` / `<CR_IGNORE_IID_NUM>` 占位符机制保留（`iid` = GitHub number）。

---

## 9. prompts 术语替换

`agents.py` 加 `_substitute_platform_terms`：

```python
PLATFORM_TERMS = {
    "github": {
        "issue_system": "GitHub issue",
        "issue_label_intro": "会自动打上 reviewer-generated 和 severity 标签（GitHub 需要仓库预创建这些 label）。",
    },
}
```

`build_prompt` 末尾替换 prompt 文本里的"GitLab issue" → "GitHub issue" + label 预创建提示。三个 agent prompt 同步生效。

---

## 10. CI（GitHub Actions + GHCR）

### `.github/workflows/build.yml`

镜像构建 + 推 GHCR，打 3 个 tag：`:sha-xxxxxxx` / `:latest` / `:main`。用 `docker/build-push-action@v5` + `docker/metadata-action@v5`。PR 场景只构建不推。

### `.github/workflows/test.yml`

`pytest -q`，PR + push 触发。

### `.github/workflows/release.yml`

打 `v*.*.*` tag → `softprops/action-gh-release@v1` 发 GitHub Release + 自动 changelog。

---

## 11. 开源基础设施

| 文件 | 内容 |
|------|------|
| `LICENSE` | MIT |
| `README.md` | 重写：徽章 + 简介 + 特性 + 快速接入（GitHub 消费者）+ env 表 + 工具集 + 退出码 + Contributing + License |
| `CONTRIBUTING.md` | 开发环境 + 测试运行 + 提交流程 + 代码风格 |
| `SECURITY.md` | 支持版本表 + 漏洞上报（GitHub Security Advisories）+ 响应时间 |
| `CODE_OF_CONDUCT.md` | Contributor Covenant 2.1 中文版 |
| `.github/ISSUE_TEMPLATE/{bug_report,feature_request,config.yml}` | 标准 issue 模板 |
| `.github/PULL_REQUEST_TEMPLATE.md` | 标准 PR 模板 |
| `CHANGELOG.md` | v1.0.0（新仓首发，无 BREAKING） |

---

## 12. novel_builder 接入

### `.github/workflows/code-review.yml`（`D:\my_space\novel_builder`）

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
  # code-reviewer 在容器内用 GH_TOKEN（PAT）操作，permissions 仅 GITHUB_TOKEN 路径需要
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

### novel_builder GitHub Secrets

| Secret | 用途 |
|--------|------|
| `GH_TOKEN` | Fine-grained PAT，scope `repo`，限本仓库 |
| `LLM_BASE_URL` | OpenAI 兼容 API |
| `LLM_API_KEY` | LLM token |
| `LLM_MODEL` | 模型名 |

### 前置：novel_builder 仓库预创建 4 个 label

`reviewer-generated` / `severity::critical` / `severity::warning` / `severity::suggestion`。

---

## 13. 测试策略

### 新写测试

| 测试文件 | 覆盖 |
|----------|------|
| `test_github_client.py` | mock `urlopen`：6 端点构造、labels 预过滤（含 GET /labels 失败兜底）、422 三分支（assignee/labels/其他）、labels 空集→422 联动降级、rate limit、lookup_assignee（collaborator/非 collaborator） |
| `test_notifier.py` | PR 评论端点 + 65000 截断、push 场景 status check（success/failure/skip 不发）、description 140 截断、status check 失败吞异常 |
| `test_config.py` | GitHub 必填项校验、可选 env 默认值、PR_NUMBER 解析（None） |
| `test_main.py` | main() 启动组装 github_client + notifier + ctx 含 issue_client、空 range send_skip、list_open_issues 失败 send_error |
| `test_helpers.py` | FakeGithubClient + FakeNotifier 桩 |

### 复制 + 改 fixture 的测试

| 测试文件 | 改动 |
|----------|------|
| `test_agent.py` | dispatch_ctx 含 `issue_client`，不含 gitlab_* |
| `test_orchestrate.py` | send_report 走 notifier 实例（FakeNotifier） |
| `test_agents.py` | 加 `_substitute_platform_terms` case（GitHub issue） |
| `test_tool_create_issue.py` | fixture 用 FakeGithubClient |
| `test_tool_close_issue.py` | 同上 |
| `test_tool_*.py`（其他 9 个工具） | 不改 |
| `test_cr_ignore.py` / `test_log.py` / `test_prompt.py` | 不改 |

### 不复制的测试（对应删除的代码）

`test_gitlab_client*.py` / `test_notifier.py`（企微）/ `test_archive.py` / `test_weekly_*.py`。

---

## 14. 实施顺序

```
Phase 1：仓库初始化 + 核心复制（任务 1-2）
  ├─ 任务 1：新建 D:\my_space\code-reviewer + 复制核心代码 + 删 GitLab 文件 + git init
  └─ 任务 2：config.py（GitHub 必填项）

Phase 2：GitHub 实现（任务 3-4）
  ├─ 任务 3：github_client.py（6 端点 + labels + 422 + rate limit）
  └─ 任务 4：notifier.py（PR 评论 + status check）

Phase 3：主流程接入（任务 5）
  └─ 任务 5：__main__.py + orchestrator.py + agent.py dispatch_ctx + tools/create_issue + close_issue + prompts 术语（一次性接入，新仓无中间态 break 问题）

Phase 4：CI + 开源 + 接入（任务 6-8）
  ├─ 任务 6：CI（build.yml / test.yml / release.yml）
  ├─ 任务 7：开源基础设施（LICENSE / README / CONTRIBUTING / SECURITY / CODE_OF_CONDUCT / 模板）
  └─ 任务 8：novel_builder 接入（.github/workflows/code-review.yml）
```

**共 8 个任务**（vs 双平台方案的 17 个），无原子任务、无兼容层、无 GitLab 兼容回归。

### 执行检查点

- **Checkpoint A（任务 4 完成）**：GitHub client + notifier 就绪，可单测验证 6 端点 + PR 评论 + status check。Review 一遍。
- **Checkpoint B（任务 5 完成）**：主流程跑通，全测试绿。Review 一遍。
- **Checkpoint C（任务 8 完成）**：消费方接入，整体可发布。

---

## 15. 与旧双平台方案的关键差异

| 维度 | 旧方案（双平台，已废弃） | 新方案（独立 GitHub 仓） |
|------|--------------------------|--------------------------|
| 仓库 | 改造 `D:\work\ci-code-reviewer` | 新建 `D:\my_space\code-reviewer`，老仓不动 |
| 平台 | GitLab + GitHub 双平台 | 纯 GitHub |
| IssueClient | 抽象层 + GitLab/GitHub 两实现 | 直接 `github_client.py`，无抽象 |
| Notifier | 抽象层 + Wecom/GitHub/Null 三实现 | 直接 `GithubPrNotifier`，无抽象 |
| 企微 | 保留为可选 | 不要 |
| 归档 | weekly_reports（BREAKING 迁移） | 不要 |
| 兼容层 | 任务 3 加 + 任务 12 删 | 无 |
| PLATFORM 分支 | 有 | 无 |
| GitLab 兼容回归 | 大量测试 | 无 |
| 任务数 | 17 | 8 |
| 原子任务 | 任务 11（三处一起改） | 无（新仓从零组装） |
| 复杂度 | 高 | 低 |
