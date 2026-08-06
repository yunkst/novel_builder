# code-reviewer 独立 GitHub 仓库实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 新建独立 GitHub 专用开源仓库 `D:\my_space\code-reviewer`（从 `D:\work\ci-code-reviewer` 复制核心 + 删 GitLab 部分 + 新写 GitHub 实现），让 `novel_builder` 通过 GitHub Actions 接入 AI 代码审查。

**架构：** 纯 GitHub，无平台抽象。`github_client.py` 直接实现 issue API，`notifier.py` 直接实现 PR 评论 + commit status check。三 agent 编排（A→B 串行 + C 并行）从老仓复制。

**技术栈：** Python 3.11 / GitHub Actions / GitHub REST API v3 / GHCR

---

## 工作前提

### 代码仓库

- **源仓库（只读参考）**：`D:\work\ci-code-reviewer` — GitLab 内网，复制核心代码的来源，**完全不动**
- **新仓库（工作区）**：`D:\my_space\code-reviewer` — 本计划任务 1-7 在此新建
- **消费方**：`D:\my_space\novel_builder` — 任务 8 在此加 workflow

### 计划来源

规格：`D:\my_space\novel_builder\docs\superpowers\specs\2026-08-06-code-reviewer-github-standalone-design.md`

### 测试约定

- TDD：先写失败测试，再写实现（任务 2-5）
- mock 策略：`urllib.request.urlopen` 用 `unittest.mock.patch`；`GithubClient` 用 `FakeGithubClient`
- pytest 全绿才能 commit
- 任务 1（复制）无 TDD，跑复制的测试确认绿即可

---

## 文件结构（`D:\my_space\code-reviewer`）

详见规格 §2。核心：
- **复制**（任务 1）：`agent.py` / `agents.py` / `orchestrator.py` / `prompt.py` / `cr_ignore.py` / `log.py` / `tools/{__init__,git_diff,git_log,git_show,grep,list_directory,list_files,notes_store,read_file,read_notes,take_note}.py` / `prompts/agent_a_feature.md` / `Dockerfile` / `entrypoint.sh` / `pyproject.toml` / `requirements.txt` + 对应的不改测试
- **新写**（任务 2-5）：`config.py` / `github_client.py` / `notifier.py` / `__main__.py` / 改 `tools/create_issue.py` + `close_issue.py` + `agent.py` dispatch_ctx + `orchestrator.py` + `agents.py`/`prompt.py` 术语
- **新写**（任务 6-7）：`.github/workflows/{build,test,release}.yml` + 开源 7 文件
- **新写**（任务 8，在 novel_builder）：`.github/workflows/code-review.yml`

---

## 任务拆分

8 个任务，3 个 Checkpoint：

- **任务 1**：建仓 + 复制核心 + 删 GitLab 文件
- **任务 2**：config.py（GitHub 必填项）
- **任务 3**：github_client.py
- **任务 4**：notifier.py
- **任务 5**：主流程接入（__main__ + orchestrator + agent + tools + prompts）
- **任务 6**：CI（GitHub Actions + GHCR）
- **任务 7**：开源基础设施
- **任务 8**：novel_builder 接入

---

### 任务 1：建仓 + 复制核心 + 删 GitLab 文件 + Dockerfile/pyproject 新写

**目标**：在 `D:\my_space\code-reviewer` 建立新 git 仓库，从 `D:\work\ci-code-reviewer` 复制核心代码，改 Dockerfile（去内网镜像）、新写 pyproject.toml（老仓没有），跑能跑的测试确认绿。

**关键事实**（源仓库实际状态，已核实）：
- 源仓**无 `pyproject.toml`**（只有 `requirements.txt`，内容 `openai>=1.0`）
- 源仓 `Dockerfile` 用 `ccr.ccs.tencentyun.com/comms/python:3.11-slim` 内网镜像 + aliyun 换源 + `COPY entrypoint_weekly.sh`（新仓不复制 weekly，必须删这行）
- 源仓 prompts 在**根目录** `prompts/`（不是 `src/code_review/prompts/`），`agents.py._PROMPTS_DIR` 和 `test_prompt.py._PROMPT_DIR` 都按根 `prompts/` 计算
- 源仓 `prompt.py` 用 `{{XXX}}` 双大括号占位符 + `extra` 参数（**不是** `.format()`）

**文件：**
- 新建目录：`D:\my_space\code-reviewer`
- 复制（从 `D:\work\ci-code-reviewer` → `D:\my_space\code-reviewer`）：
  - `src/code_review/__init__.py`
  - `src/code_review/agent.py`（任务 5 改 dispatch_ctx）
  - `src/code_review/agents.py`（任务 5 加术语替换）
  - `src/code_review/orchestrator.py`（任务 5 改）
  - `src/code_review/prompt.py`（**保留老仓实现**，任务 5 仅末尾追加术语替换）
  - `src/code_review/cr_ignore.py`
  - `src/code_review/log.py`
  - `src/code_review/tools/__init__.py`
  - `src/code_review/tools/{git_diff,git_log,git_show,grep,list_directory,list_files,notes_store,read_file,read_notes,take_note}.py`（10 个不改）
  - `src/code_review/tools/create_issue.py`（任务 5 重写 handler）
  - `src/code_review/tools/close_issue.py`（任务 5 重写 handler）
  - `prompts/agent_a_feature.md` / `agent_b_quality.md` / `agent_c_repair.md`（**复制到根 `prompts/`**，不是 src 下）
  - `entrypoint.sh` / `requirements.txt`
  - `Dockerfile`（**复制后改造**，见步骤 4）
  - `tests/__init__.py`
  - `tests/test_cr_ignore.py` / `test_log.py` / `test_prompt.py`（不改）
  - `tests/test_tool_{git_diff,git_log,git_show,grep,list_directory,list_files,notes,read_file,registry}.py`（9 个，含 registry，不改）
  - `tests/test_agent.py` / `test_orchestrate.py` / `test_agents.py` / `test_tool_create_issue.py` / `test_tool_close_issue.py`（任务 5 改 fixture 后才能跑，先复制）
- **新写**（老仓没有）：`pyproject.toml`
- **不复制**（GitLab/公司专用）：`gitlab_client.py` / `notifier.py`（企微）/ `archive.py` / `config.py` / `__main__.py` / `weekly/` / `entrypoint_weekly.sh` / `prompts/weekly_member.md` / `.gitlab-ci.yml` / `ci/` / `templates/` / `bump_test/` / `test_gitlab_client*.py` / `test_archive.py` / `test_weekly_*.py` / `test_review_cache.py`

- [ ] **步骤 1：建仓 + 目录结构**

```bash
mkdir -p D:/my_space/code-reviewer/src/code_review/tools D:/my_space/code-reviewer/prompts D:/my_space/code-reviewer/tests
cd D:/my_space/code-reviewer
git init
```

注意：prompts 在**根目录**（与老仓一致，`agents.py._PROMPTS_DIR` 往上三层到根再进 `prompts/`）。

- [ ] **步骤 2：复制核心代码**

PowerShell 示例：
```powershell
$src = "D:\work\ci-code-reviewer"
$dst = "D:\my_space\code-reviewer"
# src 核心
foreach ($f in @("__init__","agent","agents","orchestrator","prompt","cr_ignore","log")) {
    Copy-Item "$src\src\code_review\$f.py" "$dst\src\code_review\"
}
# tools（10 个不改 + 2 个待改）
Copy-Item "$src\src\code_review\tools\__init__.py" "$dst\src\code_review\tools\"
foreach ($t in @("git_diff","git_log","git_show","grep","list_directory","list_files","notes_store","read_file","read_notes","take_note","create_issue","close_issue")) {
    Copy-Item "$src\src\code_review\tools\$t.py" "$dst\src\code_review\tools\"
}
# prompts（到根 prompts/，不是 src 下）
foreach ($p in @("agent_a_feature","agent_b_quality","agent_c_repair")) {
    Copy-Item "$src\prompts\$p.md" "$dst\prompts\"
}
# 根文件
Copy-Item "$src\entrypoint.sh" "$dst\"
Copy-Item "$src\requirements.txt" "$dst\"
Copy-Item "$src\Dockerfile" "$dst\"  # 步骤 4 改造
# 测试
Copy-Item "$src\tests\__init__.py" "$dst\tests\"
foreach ($t in @("test_cr_ignore","test_log","test_prompt","test_tool_git_diff","test_tool_git_log","test_tool_git_show","test_tool_grep","test_tool_list_directory","test_tool_list_files","test_tool_notes","test_tool_read_file","test_tool_registry","test_agent","test_orchestrate","test_agents","test_tool_create_issue","test_tool_close_issue")) {
    Copy-Item "$src\tests\$t.py" "$dst\tests\"
}
```

- [ ] **步骤 3：临时 stub 让 import 不破 + 临时禁用 create_issue/close_issue 注册**

复制过来的代码 import 链：`agent.py`/`orchestrator.py` import config/notifier；`tools/create_issue.py`/`close_issue.py` import `gitlab_client`（未复制）。策略：**最小 stub + 临时禁用两个 issue 工具注册**。

stub 文件（任务 2-4 填充真实实现）：

`src/code_review/config.py`：
```python
class ConfigError(Exception): ...
def load_config(): raise NotImplementedError("任务 2 实现")
```

`src/code_review/github_client.py`：
```python
class GithubClient:
    def __init__(self, token, repo): ...
```

`src/code_review/notifier.py`（orchestrator.py 复制后会 import，需提供符号）：
```python
class GithubPrNotifier: ...
class ReportContext: ...
def build_multi_section_report(*a, **kw): raise NotImplementedError("任务 4 实现")
```

`src/code_review/__main__.py`：
```python
def main(): raise NotImplementedError("任务 5 实现")
```

**临时禁用 create_issue/close_issue**（因为它们 `from .. import gitlab_client` 会失败）：

打开 `src/code_review/tools/__init__.py`，找到 TOOL_REGISTRY（或工具注册字典）里 `create_issue` / `close_issue` 两行，**临时注释掉**（加 `# 任务 5 恢复` 注释）。这样 `tools/__init__.py` 能加载，`test_tool_registry.py` 会因少 2 个工具失败——**暂时跳过它**（任务 5 恢复注册后才跑）。步骤 5 的测试命令不含 test_tool_registry。

- [ ] **步骤 4：新写 pyproject.toml + 改造 Dockerfile**

`pyproject.toml`（新写，老仓无）：
```toml
[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"

[project]
name = "code-reviewer"
version = "1.0.0"
description = "AI code reviewer for GitHub (PR comments + issue tracking)"
requires-python = ">=3.11"
dependencies = ["openai>=1.0"]

[project.optional-dependencies]
dev = ["pytest>=7"]

[project.scripts]
code-reviewer = "code_review.__main__:main"

[tool.setuptools.packages.find]
where = ["src"]

[tool.pytest.ini_options]
pythonpath = ["src"]
```

`Dockerfile` 改造（复制后改 3 处）：
- 第 2 行：`FROM ccr.ccs.tencentyun.com/comms/python:3.11-slim` → `FROM python:3.11-slim`
- 第 13-27 行（aliyun apt + pip 换源段）：**删除**（开源镜像走默认源）
- 第 38 行：`COPY entrypoint_weekly.sh ./` → **删除**（新仓无此文件）
- 第 39 行 `chmod +x entrypoint.sh entrypoint_weekly.sh` → `chmod +x entrypoint.sh`

改造后 Dockerfile 关键段：
```dockerfile
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/
COPY prompts/ ./prompts/
COPY entrypoint.sh ./
RUN chmod +x entrypoint.sh

ENV PYTHONPATH=/app/src
WORKDIR /repo
ENTRYPOINT ["/app/entrypoint.sh"]
```

- [ ] **步骤 5：安装 + 跑能跑的测试确认绿**

```bash
cd D:/my_space/code-reviewer
pip install -e ".[dev]"
pytest tests/test_cr_ignore.py tests/test_log.py tests/test_prompt.py tests/test_tool_git_diff.py tests/test_tool_git_log.py tests/test_tool_git_show.py tests/test_tool_grep.py tests/test_tool_list_directory.py tests/test_tool_list_files.py tests/test_tool_notes.py tests/test_tool_read_file.py -v
```

预期：全绿（这些测试不依赖 config/github_client/notifier/main，且 test_prompt 验证 `{{XXX}}` 占位符 + extra 契约能过，因为 prompt.py 原样复制）

**预期失败（任务 5 后才绿）**：`test_agent.py` / `test_orchestrate.py` / `test_agents.py` / `test_tool_create_issue.py` / `test_tool_close_issue.py` / `test_tool_registry.py`（registry 因临时禁用 2 工具而失败，任务 5 恢复）。

- [ ] **步骤 6：写 .gitignore + Commit**

`.gitignore`：
```
__pycache__/
*.pyc
.venv/
.pytest_cache/
*.egg-info/
```

```bash
cd D:/my_space/code-reviewer
git add -A
git commit -m "init: 从 ci-code-reviewer 复制核心 + Dockerfile/pyproject 改造

从 D:\work\ci-code-reviewer 复制三 agent 编排 + prompt + 只读工具集 +
.cr-ignore + LLM 重试 + 测试。prompts 放根目录（与老仓 _PROMPTS_DIR 一致）。
不复制 GitLab 专用代码（gitlab_client/notifier/archive/weekly/GitLab CI）。
config/github_client/notifier/__main__ 临时 stub，任务 2-5 填充。
tools/__init__ 临时禁用 create_issue/close_issue 注册（任务 5 恢复）。
Dockerfile 改：基础镜像 python:3.11-slim、删 aliyun 换源、删 weekly 入口。
pyproject.toml 新写（老仓无）。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 2：config.py（GitHub 必填项）

**文件：**
- 修改：`src/code_review/config.py`（替换 stub）
- 修改：`tests/test_config.py`（从老仓复制后改，或新写）

- [ ] **步骤 1：写测试**

`tests/test_config.py`：
```python
import os
import pytest
from code_review.config import load_config, ConfigError


def _set_required_env(monkeypatch):
    monkeypatch.setenv("LLM_BASE_URL", "https://llm/x")
    monkeypatch.setenv("LLM_API_KEY", "sk")
    monkeypatch.setenv("LLM_MODEL", "m")
    monkeypatch.setenv("REVIEW_BASE_SHA", "abc")
    monkeypatch.setenv("REVIEW_HEAD_SHA", "def")
    monkeypatch.setenv("GH_TOKEN", "ghp_x")
    monkeypatch.setenv("GITHUB_REPOSITORY", "owner/repo")


def test_load_config_success(monkeypatch):
    _set_required_env(monkeypatch)
    cfg = load_config()
    assert cfg["gh_token"] == "ghp_x"
    assert cfg["github_repository"] == "owner/repo"
    assert cfg["review_base_sha"] == "abc"
    assert cfg["review_head_sha"] == "def"
    assert cfg["platform"] == "github"  # 固定值


def test_missing_github_token_raises(monkeypatch):
    _set_required_env(monkeypatch)
    monkeypatch.delenv("GH_TOKEN")
    with pytest.raises(ConfigError, match="GH_TOKEN"):
        load_config()


def test_missing_llm_raises(monkeypatch):
    _set_required_env(monkeypatch)
    monkeypatch.delenv("LLM_API_KEY")
    with pytest.raises(ConfigError, match="LLM_API_KEY"):
        load_config()


def test_pr_number_optional_defaults_none(monkeypatch):
    _set_required_env(monkeypatch)
    monkeypatch.delenv("PR_NUMBER", raising=False)
    cfg = load_config()
    assert cfg["pr_number"] is None


def test_pr_number_parsed(monkeypatch):
    _set_required_env(monkeypatch)
    monkeypatch.setenv("PR_NUMBER", "42")
    cfg = load_config()
    assert cfg["pr_number"] == 42


def test_trigger_user_from_github_actor(monkeypatch):
    _set_required_env(monkeypatch)
    monkeypatch.setenv("GITHUB_ACTOR", "alice")
    cfg = load_config()
    assert cfg["trigger_user"] == "alice"


def test_no_wecom_no_weekly_no_gitlab_vars(monkeypatch):
    """新仓不应有 wecom/weekly/gitlab 相关 key。"""
    _set_required_env(monkeypatch)
    cfg = load_config()
    assert "wecom_webhook_url" not in cfg
    assert "weekly_report_project_id" not in cfg
    assert "gitlab_token" not in cfg
    assert "gitlab_api_url" not in cfg
    assert "gitlab_project_id" not in cfg
```

- [ ] **步骤 2：跑测试确认失败**

运行：`pytest tests/test_config.py -v`
预期：FAIL（stub raise NotImplementedError）

- [ ] **步骤 3：实现 config.py**

`src/code_review/config.py`：
```python
"""环境变量解析。GitHub 专用，无平台分支。"""
import os
import sys


class ConfigError(Exception):
    """配置错误。"""


REQUIRED = [
    "LLM_BASE_URL",
    "LLM_API_KEY",
    "LLM_MODEL",
    "REVIEW_BASE_SHA",
    "REVIEW_HEAD_SHA",
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
    missing = [k for k in REQUIRED if not os.environ.get(k)]
    if missing:
        raise ConfigError(f"缺少必填环境变量: {', '.join(missing)}")

    pr_number = _int_env("PR_NUMBER", 0)
    return {
        "platform": "github",  # 固定
        "llm_base_url": os.environ["LLM_BASE_URL"],
        "llm_api_key": os.environ["LLM_API_KEY"],
        "llm_model": os.environ["LLM_MODEL"],
        "review_base_sha": os.environ["REVIEW_BASE_SHA"],
        "review_head_sha": os.environ["REVIEW_HEAD_SHA"],
        "gh_token": os.environ["GH_TOKEN"],
        "github_repository": os.environ["GITHUB_REPOSITORY"],
        "repo_path": os.environ.get("REPO_PATH", "/repo"),
        "max_turns": max(1, _int_env("MAX_TURNS", 200)),
        "max_diff_bytes": _int_env("MAX_DIFF_BYTES", 50000),
        "report_lang": os.environ.get("REPORT_LANG", "zh"),
        "pr_number": pr_number or None,
        "trigger_user": os.environ.get("GITHUB_ACTOR", ""),
        # 报告头部渲染用（可选）
        "ci_pipeline_url": os.environ.get("GITHUB_SERVER_URL", "") + "/" + os.environ.get("GITHUB_REPOSITORY", "") + "/actions/runs/" + os.environ.get("GITHUB_RUN_ID", "") if os.environ.get("GITHUB_RUN_ID") else "",
        "ci_project_path": os.environ.get("GITHUB_REPOSITORY", ""),
        "ci_project_url": (os.environ.get("GITHUB_SERVER_URL", "") + "/" + os.environ.get("GITHUB_REPOSITORY", "")) if os.environ.get("GITHUB_REPOSITORY") else "",
        "commit_short_sha": os.environ.get("GITHUB_SHA", "")[:8],
        "commit_branch": os.environ.get("GITHUB_REF_NAME", ""),
        "pipeline_source": os.environ.get("GITHUB_EVENT_NAME", ""),
    }
```

- [ ] **步骤 4：跑测试确认通过**

运行：`pytest tests/test_config.py -v`
预期：全绿

- [ ] **步骤 5：Commit**

```bash
cd D:/my_space/code-reviewer
git add src/code_review/config.py tests/test_config.py
git commit -m "feat(config): GitHub 必填项配置

7 个必填 env（LLM_* / REVIEW_* / GH_TOKEN / GITHUB_REPOSITORY）
PR_NUMBER 可选（push 场景 None），trigger_user 从 GITHUB_ACTOR 读
无 wecom/weekly/gitlab 字段

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 3：github_client.py

**文件：**
- 修改：`src/code_review/github_client.py`（替换 stub）
- 创建：`tests/test_github_client.py`
- 创建：`tests/test_helpers.py`（FakeGithubClient）

- [ ] **步骤 1：写测试**

`tests/test_helpers.py`：
```python
"""测试辅助：FakeGithubClient + FakeNotifier。"""
from dataclasses import dataclass, field
from typing import Any


@dataclass
class FakeGithubClient:
    """测试用 GithubClient 桩。"""
    list_open_issues_result: list = field(default_factory=list)
    create_issue_result: dict = field(default_factory=lambda: {"iid": 1, "web_url": "https://x/1"})
    close_issue_result: dict = field(default_factory=lambda: {"iid": 1})
    add_comment_result: dict = field(default_factory=lambda: {"web_url": "https://x/c1"})
    update_description_result: dict = field(default_factory=lambda: {"iid": 1})
    lookup_assignee_result: Any = None

    list_open_issues_called_with: list = field(default_factory=list)
    create_issue_called_with: tuple = None
    close_issue_called_with: list = field(default_factory=list)
    add_comment_called_with: list = field(default_factory=list)
    update_description_called_with: list = field(default_factory=list)
    lookup_assignee_called_with: list = field(default_factory=list)

    def list_open_issues(self, labels):
        self.list_open_issues_called_with.append(labels)
        return self.list_open_issues_result

    def create_issue(self, title, description, labels, assignee=None):
        self.create_issue_called_with = (title, description, labels, assignee)
        return self.create_issue_result

    def close_issue(self, number):
        self.close_issue_called_with.append(number)
        return self.close_issue_result

    def add_comment(self, number, body):
        self.add_comment_called_with.append((number, body))
        return self.add_comment_result

    def update_description(self, number, description):
        self.update_description_called_with.append((number, description))
        return self.update_description_result

    def lookup_assignee(self, username):
        self.lookup_assignee_called_with.append(username)
        return self.lookup_assignee_result


@dataclass
class FakeNotifier:
    """测试用 Notifier 桩。"""
    send_report_return: bool = True
    send_report_called: bool = False
    send_report_called_with: list = field(default_factory=list)
    send_error_called_with: list = field(default_factory=list)
    send_skip_called_with: list = field(default_factory=list)

    def send_report(self, report, *, context=None):
        self.send_report_called = True
        self.send_report_called_with.append((report, context))
        return self.send_report_return

    def send_error(self, title, body, *, context=None):
        self.send_error_called_with.append((title, body, context))

    def send_skip(self, title, body, *, context=None):
        self.send_skip_called_with.append((title, body, context))
```

`tests/test_github_client.py`：
```python
from unittest.mock import patch, MagicMock
import json
import urllib.error
from code_review.github_client import GithubClient


def _mock_response(data, headers=None):
    resp = MagicMock()
    resp.read.return_value = json.dumps(data).encode("utf-8")
    resp.headers = headers or {}
    resp.__enter__ = lambda s: s
    resp.__exit__ = lambda s, *a: None
    return resp


@patch("urllib.request.urlopen")
def test_list_open_issues_maps_number_to_iid(mock_urlopen):
    mock_urlopen.return_value = _mock_response([
        {"number": 42, "title": "bug", "body": "desc", "html_url": "https://gh/x/42",
         "labels": [{"name": "reviewer-generated"}]}
    ])
    client = GithubClient(token="ghp_x", repo="owner/repo")
    issues = client.list_open_issues(["reviewer-generated"])
    assert issues[0]["iid"] == 42
    url = mock_urlopen.call_args.args[0].full_url
    assert "repos/owner/repo/issues" in url
    assert "labels=reviewer-generated" in url


@patch("urllib.request.urlopen")
def test_create_issue_returns_iid_and_url(mock_urlopen):
    mock_urlopen.return_value = _mock_response(
        {"number": 99, "html_url": "https://gh/x/99"}, {"X-RateLimit-Remaining": "100"})
    client = GithubClient(token="ghp_x", repo="owner/repo")
    result = client.create_issue("t", "d", ["reviewer-generated", "severity::critical"])
    assert result["iid"] == 99
    assert result["web_url"] == "https://gh/x/99"


@patch("urllib.request.urlopen")
def test_assignee_422_retries_without_assignee(mock_urlopen):
    err = MagicMock()
    err.read.return_value = json.dumps({
        "errors": [{"resource": "Issue", "field": "assignees", "code": "invalid"}]
    }).encode("utf-8")
    err.__enter__ = lambda s: s
    err.__exit__ = lambda s, *a: None
    ok = _mock_response({"number": 5, "html_url": "https://gh/x/5"})
    mock_urlopen.side_effect = [
        urllib.error.HTTPError("u", 422, "x", {}, err),
        ok,
    ]
    client = GithubClient(token="ghp_x", repo="owner/repo")
    result = client.create_issue("t", "d", ["reviewer-generated"], assignee="alice")
    assert result["iid"] == 5
    assert mock_urlopen.call_count == 2
    second_body = json.loads(mock_urlopen.call_args_list[1].args[0].data)
    assert "assignees" not in second_body


@patch("urllib.request.urlopen")
def test_labels_422_retries_without_labels(mock_urlopen):
    err = MagicMock()
    err.read.return_value = json.dumps({
        "errors": [{"resource": "Issue", "field": "labels", "code": "invalid"}]
    }).encode("utf-8")
    err.__enter__ = lambda s: s
    err.__exit__ = lambda s, *a: None
    ok = _mock_response({"number": 6, "html_url": "https://gh/x/6"})
    mock_urlopen.side_effect = [
        urllib.error.HTTPError("u", 422, "x", {}, err),
        ok,
    ]
    client = GithubClient(token="ghp_x", repo="owner/repo")
    result = client.create_issue("t", "d", ["nonexistent"])
    assert result["iid"] == 6


@patch("urllib.request.urlopen")
def test_other_422_does_not_retry(mock_urlopen):
    err = MagicMock()
    err.read.return_value = json.dumps({
        "errors": [{"resource": "Issue", "field": "title", "code": "missing"}]
    }).encode("utf-8")
    err.__enter__ = lambda s: s
    err.__exit__ = lambda s, *a: None
    mock_urlopen.side_effect = urllib.error.HTTPError("u", 422, "x", {}, err)
    client = GithubClient(token="ghp_x", repo="owner/repo")
    try:
        client.create_issue("t", "d", ["reviewer-generated"])
    except urllib.error.HTTPError:
        pass
    else:
        raise AssertionError("should raise")
    assert mock_urlopen.call_count == 1


@patch("urllib.request.urlopen")
def test_labels_cache_failure_empty_set(mock_urlopen):
    err = MagicMock()
    err.__enter__ = lambda s: s
    err.__exit__ = lambda s, *a: None
    mock_urlopen.side_effect = urllib.error.HTTPError("u", 403, "x", {}, err)
    client = GithubClient(token="ghp_x", repo="owner/repo")
    assert client._available_labels == set()


@patch("urllib.request.urlopen")
def test_empty_labels_cache_lets_422_trigger_fallback(mock_urlopen):
    """GET /labels 失败 → 空集 → 不过滤 → 422 → labels 降级（防死循环）。"""
    err = MagicMock()
    err.read.return_value = json.dumps({
        "errors": [{"resource": "Issue", "field": "labels", "code": "invalid"}]
    }).encode("utf-8")
    err.__enter__ = lambda s: s
    err.__exit__ = lambda s, *a: None
    mock_urlopen.side_effect = [
        urllib.error.HTTPError("u", 403, "x", {}, err),  # GET /labels
        urllib.error.HTTPError("u", 422, "x", {}, err),  # create_issue #1
        _mock_response({"number": 7, "html_url": "https://gh/x/7"}),  # 降级重试
    ]
    client = GithubClient(token="ghp_x", repo="owner/repo")
    assert client._available_labels == set()
    result = client.create_issue("t", "d", ["severity::critical"])
    assert result["iid"] == 7


@patch("urllib.request.urlopen")
def test_lookup_assignee_collaborator_returns_username(mock_urlopen):
    mock_urlopen.return_value = _mock_response({"permission": "write"})
    client = GithubClient(token="ghp_x", repo="owner/repo")
    assert client.lookup_assignee("alice") == "alice"


@patch("urllib.request.urlopen")
def test_lookup_assignee_non_collaborator_returns_none(mock_urlopen):
    err = MagicMock()
    err.__enter__ = lambda s: s
    err.__exit__ = lambda s, *a: None
    mock_urlopen.side_effect = urllib.error.HTTPError("u", 404, "x", {}, err)
    client = GithubClient(token="ghp_x", repo="owner/repo")
    assert client.lookup_assignee("outsider") is None


@patch("urllib.request.urlopen")
def test_close_issue_patches_state(mock_urlopen):
    mock_urlopen.return_value = _mock_response({"number": 8, "html_url": "https://gh/x/8"})
    client = GithubClient(token="ghp_x", repo="owner/repo")
    client.close_issue(8)
    req = mock_urlopen.call_args.args[0]
    assert req.method == "PATCH"
    body = json.loads(req.data)
    assert body == {"state": "closed"}


@patch("urllib.request.urlopen")
def test_add_comment_posts(mock_urlopen):
    mock_urlopen.return_value = _mock_response({"html_url": "https://gh/c/1"})
    client = GithubClient(token="ghp_x", repo="owner/repo")
    client.add_comment(8, "body text")
    req = mock_urlopen.call_args.args[0]
    assert req.method == "POST"
    assert "repos/owner/repo/issues/8/comments" in req.full_url


@patch("urllib.request.urlopen")
def test_update_description_patches_body(mock_urlopen):
    mock_urlopen.return_value = _mock_response({"number": 8, "html_url": "https://gh/x/8"})
    client = GithubClient(token="ghp_x", repo="owner/repo")
    client.update_description(8, "new body")
    req = mock_urlopen.call_args.args[0]
    assert req.method == "PATCH"
    assert "repos/owner/repo/issues/8" in req.full_url
    body = json.loads(req.data)
    assert body == {"body": "new body"}
```

- [ ] **步骤 2：跑测试确认失败**

运行：`pytest tests/test_github_client.py -v`
预期：FAIL（stub）

- [ ] **步骤 3：实现 github_client.py**

`src/code_review/github_client.py`：
```python
"""GitHub issue API 客户端（REST API v3）。"""
import json
import time
import urllib.error
import urllib.request

from . import log


class GithubClient:
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
            log.log_event("labels_fetch_fail", f"exc={type(exc).__name__}: {exc}")
            return set()

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

    def create_issue(self, title, description, labels, assignee=None) -> dict:
        body = {"title": title, "body": description,
                "labels": [l for l in labels if l in self._available_labels]}
        if assignee:
            body["assignees"] = [assignee]
        try:
            r = self._request("POST", "/issues", body)
        except urllib.error.HTTPError as exc:
            if exc.code != 422:
                raise
            err_body = json.loads(exc.read().decode("utf-8"))
            fields = {e.get("field") for e in err_body.get("errors", [])}
            if "assignees" in fields or "assignee" in fields:
                log.log_event("assignee_fallback", "retry_without_assignee")
                body.pop("assignees", None)
                r = self._request("POST", "/issues", body)
            elif "labels" in fields:
                log.log_event("labels_fallback", "retry_without_labels")
                body.pop("labels", None)
                r = self._request("POST", "/issues", body)
            else:
                raise
        return {"iid": r["number"], "web_url": r["html_url"]}

    def close_issue(self, number: int) -> dict:
        r = self._request("PATCH", f"/issues/{number}", {"state": "closed"})
        return {"iid": r["number"], "web_url": r["html_url"]}

    def add_comment(self, number: int, body: str) -> dict:
        r = self._request("POST", f"/issues/{number}/comments", {"body": body})
        return {"iid": number, "web_url": r["html_url"]}

    def update_description(self, number: int, description: str) -> dict:
        r = self._request("PATCH", f"/issues/{number}", {"body": description})
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

运行：`pytest tests/test_github_client.py tests/test_helpers.py -v`
预期：全绿

- [ ] **步骤 5：Commit**

```bash
cd D:/my_space/code-reviewer
git add src/code_review/github_client.py tests/test_github_client.py tests/test_helpers.py
git commit -m "feat(github_client): GitHub issue API 客户端

6 方法：list_open_issues / create_issue / close_issue / add_comment /
update_description / lookup_assignee
iid = GitHub number 别名（下游代码零改动）
labels 预过滤 + GET /labels 失败兜底（空集）
422 三分支：assignee/labels 静默降级，其他抛回 LLM
rate limit 防御

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 4：notifier.py（PR 评论 + status check）

**文件：**
- 修改：`src/code_review/notifier.py`（替换 stub）
- 创建：`tests/test_notifier.py`

- [ ] **步骤 1：写测试**

`tests/test_notifier.py`：
```python
from unittest.mock import patch, MagicMock
import json
from code_review.notifier import GithubPrNotifier, ReportContext, build_multi_section_report


def _ctx(pr_number=None, commit_sha="abc1234"):
    return ReportContext(
        project="proj", project_url="https://gh/owner/repo",
        authors="alice", trigger_user="bob",
        branch_line="feat→main", commit_sha=commit_sha,
        stat="3 +20 -5", pr_number=pr_number,
    )


@patch("urllib.request.urlopen")
def test_send_report_pr_posts_comment(mock_urlopen):
    mock_urlopen.return_value = MagicMock(__enter__=lambda s: s, __exit__=lambda s, *a: None)
    n = GithubPrNotifier(token="ghp_x", repo="owner/repo")
    n.send_report("# report", context=_ctx(pr_number=42))
    assert mock_urlopen.call_count == 1
    assert "repos/owner/repo/issues/42/comments" in mock_urlopen.call_args.args[0].full_url


@patch("urllib.request.urlopen")
def test_send_report_truncates_long_body(mock_urlopen):
    mock_urlopen.return_value = MagicMock(__enter__=lambda s: s, __exit__=lambda s, *a: None)
    n = GithubPrNotifier(token="ghp_x", repo="owner/repo")
    n.send_report("x" * 70000, context=_ctx(pr_number=42))
    body = json.loads(mock_urlopen.call_args.args[0].data)["body"]
    assert len(body) <= 65000 + len("\n\n…（报告超长已截断）")


@patch("urllib.request.urlopen")
def test_send_report_push_posts_status_success(mock_urlopen):
    mock_urlopen.return_value = MagicMock(__enter__=lambda s: s, __exit__=lambda s, *a: None)
    n = GithubPrNotifier(token="ghp_x", repo="owner/repo")
    n.send_report("# report", context=_ctx(pr_number=None, commit_sha="deadbeef"))
    assert mock_urlopen.call_count == 1
    assert "/repos/owner/repo/statuses/deadbeef" in mock_urlopen.call_args.args[0].full_url
    payload = json.loads(mock_urlopen.call_args.args[0].data)
    assert payload["state"] == "success"
    assert payload["context"] == "ci-code-reviewer/ai"


@patch("urllib.request.urlopen")
def test_send_error_push_posts_status_failure(mock_urlopen):
    mock_urlopen.return_value = MagicMock(__enter__=lambda s: s, __exit__=lambda s, *a: None)
    n = GithubPrNotifier(token="ghp_x", repo="owner/repo")
    n.send_error("审查未完成", "agent 失败", context=_ctx(pr_number=None))
    payload = json.loads(mock_urlopen.call_args.args[0].data)
    assert payload["state"] == "failure"
    assert "审查未完成" in payload["description"]


@patch("urllib.request.urlopen")
def test_status_description_truncated_140(mock_urlopen):
    mock_urlopen.return_value = MagicMock(__enter__=lambda s: s, __exit__=lambda s, *a: None)
    n = GithubPrNotifier(token="ghp_x", repo="owner/repo")
    n.send_error("title", "x" * 500, context=_ctx(pr_number=None))
    payload = json.loads(mock_urlopen.call_args.args[0].data)
    assert len(payload["description"]) <= 140


@patch("urllib.request.urlopen")
def test_status_check_failure_swallowed(mock_urlopen):
    """status check 抛异常不能阻塞主流程。"""
    mock_urlopen.side_effect = Exception("network down")
    n = GithubPrNotifier(token="ghp_x", repo="owner/repo")
    n.send_error("title", "body", context=_ctx(pr_number=None))  # 不抛


@patch("urllib.request.urlopen")
def test_send_skip_push_no_status(mock_urlopen):
    """push + skip 不发 status（不是失败）。"""
    n = GithubPrNotifier(token="ghp_x", repo="owner/repo")
    n.send_skip("跳过", "无 diff", context=_ctx(pr_number=None))
    assert mock_urlopen.call_count == 0


@patch("urllib.request.urlopen")
def test_send_skip_pr_posts_comment(mock_urlopen):
    """PR + skip 发评论（与 push 不发对照）。"""
    mock_urlopen.return_value = MagicMock(__enter__=lambda s: s, __exit__=lambda s, *a: None)
    n = GithubPrNotifier(token="ghp_x", repo="owner/repo")
    n.send_skip("跳过", "无 diff", context=_ctx(pr_number=42))
    assert mock_urlopen.call_count == 1
    assert "repos/owner/repo/issues/42/comments" in mock_urlopen.call_args.args[0].full_url


@patch("urllib.request.urlopen")
def test_send_error_pr_posts_comment(mock_urlopen):
    """PR + error 发评论（与 push status failure 对照）。"""
    mock_urlopen.return_value = MagicMock(__enter__=lambda s: s, __exit__=lambda s, *a: None)
    n = GithubPrNotifier(token="ghp_x", repo="owner/repo")
    n.send_error("title", "body", context=_ctx(pr_number=42))
    assert mock_urlopen.call_count == 1
    assert "repos/owner/repo/issues/42/comments" in mock_urlopen.call_args.args[0].full_url
    # 不发 status check（PR 场景避免双重通知）
    assert "/statuses/" not in mock_urlopen.call_args.args[0].full_url


@patch("urllib.request.urlopen")
def test_send_report_pr_no_status_check(mock_urlopen):
    """PR + report 发评论，不发 status check（避免双重通知）。"""
    mock_urlopen.return_value = MagicMock(__enter__=lambda s: s, __exit__=lambda s, *a: None)
    n = GithubPrNotifier(token="ghp_x", repo="owner/repo")
    n.send_report("# report", context=_ctx(pr_number=42))
    assert mock_urlopen.call_count == 1
    assert "/statuses/" not in mock_urlopen.call_args.args[0].full_url


def test_build_multi_section_report_renders_header():
    ctx = _ctx(pr_number=42)
    report = build_multi_section_report(
        a_notes=["✅ 功能 A"], b_notes=[],
        created=[{"title": "bug", "web_url": "https://gh/x/1", "severity": "critical"}],
        closed=[], open_count=1, context=ctx,
    )
    assert "代码审查报告" in report
    assert "功能 A" in report
    assert "bug" in report
```

- [ ] **步骤 2：跑测试确认失败**

运行：`pytest tests/test_notifier.py -v`
预期：FAIL（stub）

- [ ] **步骤 3：实现 notifier.py**

`src/code_review/notifier.py`：
```python
"""GitHub PR 评论 + commit status check 通知器。"""
import json
import urllib.request
from dataclasses import dataclass

from . import log


@dataclass
class ReportContext:
    """审查元信息，供报告头部 + Notifier 链接用。"""
    project: str
    project_url: str
    authors: str
    trigger_user: str
    branch_line: str
    commit_sha: str
    stat: str
    pr_number: int | None


class GithubPrNotifier:
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
            self._send_status_check(context.commit_sha, "failure", f"{title}: {body}")

    def send_skip(self, title: str, body: str, *, context: ReportContext) -> None:
        if context.pr_number is not None:
            msg = f"## ℹ️ {title}\n\n{body}"
            self._post_comment(context.pr_number, self._truncate(msg, self.COMMENTS_LIMIT))
        # push + skip 不发 status

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


def build_multi_section_report(a_notes, b_notes, created, closed,
                               open_count, context: ReportContext) -> str:
    """构建多 section 报告。从 ci-code-reviewer 迁入，header dict 改 ReportContext。"""
    emoji = {"critical": "🔴", "warning": "🟠", "suggestion": "🟡"}
    feature_note, _ = _split_feature_note(a_notes)
    lines = ["## 🤖 代码审查报告", ""]
    if context.project_url:
        lines.append(f"**项目**：[{context.project}]({context.project_url})")
    else:
        lines.append(f"**项目**：{context.project}")
    lines.append(f"**提交作者**：{context.authors or '（无）'}")
    lines.append(f"**触发者**：{context.trigger_user or '（无）'}")
    lines.append(f"**分支**：{context.branch_line or '（无）'}")
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
```

- [ ] **步骤 4：跑测试确认通过**

运行：`pytest tests/test_notifier.py -v`
预期：全绿

- [ ] **步骤 5：Commit**

```bash
cd D:/my_space/code-reviewer
git add src/code_review/notifier.py tests/test_notifier.py
git commit -m "feat(notifier): GithubPrNotifier PR 评论 + status check

PR 场景发评论（65000 截断）；push 场景发 commit status check
context=ci-code-reviewer/ai，description 140 截断，失败吞异常
build_multi_section_report 从老仓迁入，header dict 改 ReportContext

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 5：主流程接入（__main__ + orchestrator + agent + tools + prompts）

**目标**：把 stub 的 `__main__.py` 写完，改造复制过来的 `orchestrator.py` / `agent.py` dispatch_ctx / `tools/create_issue.py` / `close_issue.py` / `agents.py`+`prompt.py` 术语，让全测试绿。新仓从零组装，**不存在中间态 break 问题**，一次性接入。

**文件：**
- 修改：`src/code_review/__main__.py`（替换 stub）
- 修改：`src/code_review/orchestrator.py`（send_report/send_error 走 notifier 实例）
- 修改：`src/code_review/agent.py`（dispatch_ctx 删 gitlab_* 加 issue_client）
- 修改：`src/code_review/tools/create_issue.py`（改调 ctx["issue_client"]）
- 修改：`src/code_review/tools/close_issue.py`（同上）
- 修改：`src/code_review/agents.py` + `prompt.py`（术语替换）
- 修改：`tests/test_main.py` / `test_orchestrate.py` / `test_agent.py` / `test_tool_create_issue.py` / `test_tool_close_issue.py` / `test_agents.py`（改 fixture）

- [ ] **步骤 1：写/改测试**

`tests/test_main.py`（新写）：
```python
from unittest.mock import patch, MagicMock
from code_review.__main__ import main, build_context
from code_review.notifier import ReportContext
from tests.test_helpers import FakeGithubClient


def _cfg(**over):
    base = {
        "platform": "github", "gh_token": "ghp_x", "github_repository": "o/r",
        "llm_base_url": "x", "llm_api_key": "k", "llm_model": "m",
        "review_base_sha": "a", "review_head_sha": "b",
        "repo_path": "/repo", "max_turns": 1, "max_diff_bytes": 50000,
        "report_lang": "zh", "pr_number": 42,
        "ci_project_path": "o/r", "ci_project_url": "https://gh/o/r",
        "trigger_user": "alice", "commit_short_sha": "abc1234",
        "commit_branch": "main", "pipeline_source": "pull_request",
    }
    base.update(over)
    return base


def test_main_assembles_github_client_and_fetches_open_issues():
    fake = FakeGithubClient()
    fake.list_open_issues_result = []
    with patch("code_review.__main__.load_config", return_value=_cfg()), \
         patch("code_review.__main__.GithubClient", return_value=fake), \
         patch("code_review.__main__.GithubPrNotifier"), \
         patch("code_review.__main__.gather_commit_metadata", return_value={
             "authors": "", "stat": "0", "author_list": "",
             "files_changed": "0", "commit_summary": "（无）",
         }), \
         patch("code_review.__main__.orchestrate") as mock_orch:
        main()
    assert fake.list_open_issues_called_with == [["reviewer-generated"]]
    ctx = mock_orch.call_args.args[2]  # 第 3 个位置参数是 ctx
    assert ctx["issue_client"] is fake


def test_main_empty_range_send_skip():
    fake = FakeGithubClient()
    with patch("code_review.__main__.load_config", return_value=_cfg(review_base_sha="x", review_head_sha="x")), \
         patch("code_review.__main__.GithubClient", return_value=fake), \
         patch("code_review.__main__.GithubPrNotifier") as mock_n_cls:
        mock_n = mock_n_cls.return_value
        result = main()
    assert result == 0
    assert mock_n.send_skip_called_with  # 调了 send_skip


def test_main_list_issues_failure_send_error():
    fake = FakeGithubClient()
    def raise_exc(labels): raise Exception("api down")
    fake.list_open_issues = raise_exc
    with patch("code_review.__main__.load_config", return_value=_cfg()), \
         patch("code_review.__main__.GithubClient", return_value=fake), \
         patch("code_review.__main__.GithubPrNotifier") as mock_n_cls, \
         patch("code_review.__main__.gather_commit_metadata", return_value={
             "authors": "", "stat": "0", "author_list": "",
             "files_changed": "0", "commit_summary": "（无）",
         }):
        result = main()
    assert result == 1
    assert mock_n_cls.return_value.send_error_called_with


def test_build_context_returns_reportcontext_with_pr_number():
    cfg = _cfg(pr_number=99)
    meta = {"authors": "alice", "stat": "3 +1 -1"}
    ctx = build_context(cfg, meta)
    assert isinstance(ctx, ReportContext)
    assert ctx.pr_number == 99
    assert ctx.trigger_user == "alice"
```

`tests/test_orchestrate.py`（改 fixture）：从老仓复制后，**3 处改造**——cfg 字段、notifier patch 路径、send_report/send_error 断言。

老仓 `_CFG` 含 `wecom_webhook_url`/`gitlab_token`/`gitlab_api_url`/`gitlab_project_id`；新仓改：
```python
_CFG = {
    "platform": "github",
    "gh_token": "ghp_x", "github_repository": "owner/repo",
    "llm_base_url": "x", "llm_api_key": "k", "llm_model": "m",
    "max_turns": 1, "max_diff_bytes": 50000, "report_lang": "zh",
    "ci_pipeline_url": "",
}
```
老仓 `patch("code_review.orchestrator.send_report")` / `send_error`（模块级函数）→ 新仓改 patch notifier 类：
```python
from tests.test_helpers import FakeNotifier

def test_orchestrate_calls_notifier_send_report():
    fake_n = FakeNotifier()
    ctx = {"repo_path": "/repo", "base_sha": "a", "head_sha": "b",
           "issue_client": None, "assignee_id": None}
    with patch("code_review.orchestrator.GithubPrNotifier", return_value=fake_n), \
         patch("code_review.orchestrator.run_agent") as mock_run:
        mock_run.return_value = AgentResult(notes=[], created_issues=[],
                                            closed_issues=[], failed=False)
        orchestrate(_CFG, ctx, {"authors": "x", "stat": "0", "author_list": "",
                                "files_changed": "0", "commit_summary": "（无）"},
                    [], context=None)
    assert fake_n.send_report_called
```
所有 `send_report`/`send_error` 模块级 patch 改 `GithubPrNotifier` 类 patch + FakeNotifier 断言。

`tests/test_agent.py`（改 fixture）：**2 处改造**——cfg 字段（同上去 gitlab/wecom 加 gh_token/github_repository）+ patch 路径。

老仓 `test_run_agent_propagates_assignee_id_to_create_issue` 用 `patch("code_review.tools.create_issue.gitlab_client.create_issue")`；新仓 create_issue.py 改调 `ctx["issue_client"]`，patch 路径失效，改为构造 FakeGithubClient 注入 dispatch_ctx：
```python
from tests.test_helpers import FakeGithubClient

def test_run_agent_propagates_assignee_to_create_issue():
    fake_client = FakeGithubClient()
    fake_client.create_issue_result = {"iid": 42, "web_url": "https://gh/x/42"}
    ctx = {
        "repo_path": "/repo", "base_sha": "a", "head_sha": "b",
        "issue_client": fake_client, "assignee_id": "alice",  # username 非 id list
    }
    # ... 跑 run_agent，触发 create_issue tool_call ...
    assert fake_client.create_issue_called_with[1] == ...  # assignee="alice" 单值
```
老仓断言 `kwargs["assignee_ids"] == [42]`（list）→ 新仓 `assignee == "alice"`（单值字符串）。所有 `gitlab_client.xxx` patch 改 FakeGithubClient 注入。

`tests/test_tool_create_issue.py`（改 fixture）：**3 处改造**——patch 路径、方法名、assignee 形态。

老仓 9 个测试全 `patch("code_review.tools.create_issue.gitlab_client.create_issue" / .update_issue_description)`；新仓改：
```python
from tests.test_helpers import FakeGithubClient

def test_create_issue_calls_client_and_records_ops():
    fake = FakeGithubClient()
    fake.create_issue_result = {"iid": 7, "web_url": "https://gh/x/7"}
    ctx = {"issue_client": fake, "issue_ops": [], "assignee_id": None}
    obs = handler({"title": "t", "description": "d", "severity": "critical"}, ctx)
    assert "已创建 issue #7" in obs
    assert fake.create_issue_called_with == ("t", "d",
        ["reviewer-generated", "severity::critical"], None)  # assignee 单值 None
```
方法名映射：`update_issue_description` → `update_description`，`add_issue_comment` → `add_comment`。assignee：老 `assignee_ids=[42]` → 新 `assignee="alice"`（单值）。

`tests/test_tool_close_issue.py`（改 fixture）：同上模式，`gitlab_client.add_issue_comment`/`close_issue` patch → FakeGithubClient 注入，方法名 `add_issue_comment` → `add_comment`。

`tests/test_agents.py`（加术语 case）：
```python
def test_substitute_platform_terms_github():
    from code_review.agents import _substitute_platform_terms
    text = "在 GitLab 项目创建一个 issue"
    out = _substitute_platform_terms(text)
    assert "GitHub issue" in out
    assert "GitLab issue" not in out


def test_substitute_adds_label_precreate_hint():
    from code_review.agents import _substitute_platform_terms
    text = "会自动打上 reviewer-generated 和 severity 标签。"
    out = _substitute_platform_terms(text)
    assert "GitHub 需要仓库预创建这些 label" in out
```

- [ ] **步骤 2：跑测试确认失败**

运行：`pytest tests/test_main.py tests/test_orchestrate.py tests/test_agent.py tests/test_tool_create_issue.py tests/test_tool_close_issue.py tests/test_agents.py -v`
预期：FAIL（stub / 老 fixture）

- [ ] **步骤 3：实现 __main__.py**

`src/code_review/__main__.py`：
```python
"""入口：校验配置 → 拉 issue → 编排三 agent。"""
import os
import subprocess
import sys
import re
from collections import defaultdict

from . import log
from .config import load_config, ConfigError
from .github_client import GithubClient
from .notifier import GithubPrNotifier, ReportContext


def _git(repo: str, *args: str) -> str:
    result = subprocess.run(["git", "-C", repo, *args],
                            capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"git {args[0]} 失败: {result.stderr.strip()}")
    return result.stdout.strip()


def _format_shortstat(stat: str) -> str:
    if not stat.strip():
        return "0 文件"
    files = re.search(r"(\d+) files? changed", stat)
    insertions = re.search(r"(\d+) insertions?\(\+\)", stat)
    deletions = re.search(r"(\d+) deletions?\(-\)", stat)
    f = files.group(1) if files else "0"
    parts = [f"{f} 文件"]
    if insertions:
        parts.append(f"+{insertions.group(1)}")
    if deletions:
        parts.append(f"-{deletions.group(1)}")
    return "，".join(parts)


def gather_commit_metadata(repo: str, base: str, head: str) -> dict:
    _git(repo, "rev-parse", "--git-dir")
    raw = _git(repo, "log", "--pretty=format:%H|%an|%ae|%s", f"{base}..{head}")
    authors = defaultdict(list)
    commit_summary = []
    if raw:
        for line in raw.splitlines():
            sha, name, email, subj = line.split("|", 3)
            authors[(name, email)].append((sha, subj))
            commit_summary.append(f"{sha[:8]}|{subj}")
    files = _git(repo, "diff", "--name-only", base, head)
    file_list = files.splitlines() if files else []
    stat = _git(repo, "diff", "--shortstat", base, head)
    author_lines = []
    for (name, email), commits in authors.items():
        author_lines.append(f"{name} <{email}>")
        for sha, subj in commits:
            author_lines.append(f"  - {sha[:8]} {subj}")
    return {
        "author_list": "\n".join(author_lines) if author_lines else "（无）",
        "files_changed": f"{len(file_list)}\n" + "\n".join(file_list),
        "commit_summary": "\n".join(commit_summary) if commit_summary else "（无）",
        "authors": ", ".join(name for name, _ in authors.keys()) if authors else "（无）",
        "stat": _format_shortstat(stat),
    }


def build_context(cfg: dict, meta: dict) -> ReportContext:
    """组装 ReportContext。"""
    branch_line = cfg.get("commit_branch") or cfg.get("pipeline_source") or "（无）"
    return ReportContext(
        project=cfg.get("ci_project_path") or "（未知项目）",
        project_url=cfg.get("ci_project_url", ""),
        authors=meta.get("authors", "（无）"),
        trigger_user=cfg.get("trigger_user", ""),
        branch_line=branch_line,
        commit_sha=cfg.get("commit_short_sha", ""),
        stat=meta.get("stat", "0 文件"),
        pr_number=cfg.get("pr_number"),
    )


def main() -> int:
    try:
        cfg = load_config()
    except ConfigError as exc:
        print(f"[fatal] {exc}", file=sys.stderr)
        return 1

    # 空 range
    if cfg["review_base_sha"] == cfg["review_head_sha"]:
        log.log_event("review_range_empty",
                      f"base==head={cfg['review_base_sha'][:8]}, 无 diff 可审查")
        notifier = GithubPrNotifier(cfg["gh_token"], cfg["github_repository"])
        ctx = build_context(cfg, {})
        notifier.send_skip("本次无变更，跳过代码审查",
                           f"base == head ({cfg['review_base_sha'][:8]})，无可审查 diff。",
                           context=ctx)
        return 0

    log.log_init(f"repo={cfg['repo_path']}, range={cfg['review_base_sha'][:8]}.."
                 f"{cfg['review_head_sha'][:8]}, lang={cfg['report_lang']}")
    try:
        meta = gather_commit_metadata(cfg["repo_path"],
                                      cfg["review_base_sha"], cfg["review_head_sha"])
    except RuntimeError as exc:
        print(f"[fatal] {exc}", file=sys.stderr)
        notifier = GithubPrNotifier(cfg["gh_token"], cfg["github_repository"])
        notifier.send_error("审查未完成", f"初始化失败：{exc}",
                            context=build_context(cfg, {}))
        return 1

    client = GithubClient(cfg["gh_token"], cfg["github_repository"])
    try:
        open_issues = client.list_open_issues(labels=["reviewer-generated"])
    except Exception as exc:
        print(f"[fatal] 拉取 issue 列表失败: {exc}", file=sys.stderr)
        notifier = GithubPrNotifier(cfg["gh_token"], cfg["github_repository"])
        notifier.send_error("审查未完成", f"拉取 issue 列表失败：{exc}",
                            context=build_context(cfg, meta))
        return 1
    log.log_event("open_issues_pulled", f"count={len(open_issues)}")

    # assignee（非 collaborator 返回 None，不指派）
    assignee = client.lookup_assignee(cfg.get("trigger_user", ""))
    if assignee:
        log.log_event("assignee_resolved", f"user={cfg.get('trigger_user')} assignee={assignee}")
    else:
        log.log_event("assignee_skip", f"user={cfg.get('trigger_user')} reason=not_collaborator")

    ctx = {
        "repo_path": cfg["repo_path"],
        "base_sha": cfg["review_base_sha"],
        "head_sha": cfg["review_head_sha"],
        "issue_client": client,
        "assignee_id": assignee,
    }
    report_context = build_context(cfg, meta)

    from .orchestrator import orchestrate
    result = orchestrate(cfg, ctx, meta, open_issues, context=report_context)
    return result.exit_code


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **步骤 4：改 orchestrator.py（send_report/send_error 走 notifier 实例）**

`src/code_review/orchestrator.py` 改 import + orchestrate 内部：
```python
# import 改：
from .notifier import GithubPrNotifier, build_multi_section_report, ReportContext

# orchestrate 内（替换原模块级 send_report/send_error 调用）：
notifier = GithubPrNotifier(cfg["gh_token"], cfg["github_repository"])
report = build_multi_section_report(a_notes, b_notes, created, closed, open_count, context)
ok = notifier.send_report(report, context=context)
# 失败路径：
notifier.send_error("审查未完成", f"agent 失败：{reasons}", context=context)
```

删除原 `from .notifier import send_report, send_error`（模块级函数已不存在）。`orchestrate` 签名加 `context: ReportContext = None` 第 5 参数。

- [ ] **步骤 5：改 agent.py dispatch_ctx**

`src/code_review/agent.py` 第 92-103 行 `dispatch_ctx`：
```python
# 删 gitlab_token/gitlab_api_url/gitlab_project_id 三 key，加 issue_client
dispatch_ctx = {
    "repo_path": ctx["repo_path"],
    "base_sha": ctx["base_sha"],
    "head_sha": ctx["head_sha"],
    "issue_client": ctx["issue_client"],
    "notes_store": notes_inst,
    "issue_ops": [],
    "open_issues": open_issues or [],
    "assignee_id": ctx.get("assignee_id"),
}
```

- [ ] **步骤 6：改 tools/create_issue.py + close_issue.py**

删除 `from .. import gitlab_client`，handler 体改为调 `ctx["issue_client"]`。**完整改造代码见规格 §8**（含方法名映射 `update_issue_description`→`update_description`、`add_issue_comment`→`add_comment`、assignee 单值非 list、占位符机制保留）。

同时**恢复任务 1 步骤 3 临时注释的 `tools/__init__.py` 里 create_issue/close_issue 注册**（去掉 `# 任务 5 恢复` 注释），让 `test_tool_registry.py` 重新通过（验证 11 工具注册）。

- [ ] **步骤 7：改 agents.py + prompt.py（术语替换）**

`src/code_review/agents.py` 加：
```python
PLATFORM_TERMS = {
    "issue_system": "GitHub issue",
    "issue_label_intro": "会自动打上 reviewer-generated 和 severity 标签（GitHub 需要仓库预创建这些 label）。",
}


def _substitute_platform_terms(text: str) -> str:
    return (text
            .replace("在 GitLab 项目创建一个 issue", f"在 {PLATFORM_TERMS['issue_system']} 创建一个 issue")
            .replace("关闭一个已确认被本次提交修复的 GitLab issue",
                     f"关闭一个已确认被本次提交修复的 {PLATFORM_TERMS['issue_system']}")
            .replace("GitLab issue（带 severity）", f"{PLATFORM_TERMS['issue_system']}（带 severity）")
            .replace("会自动打上 reviewer-generated 和 severity 标签。", PLATFORM_TERMS["issue_label_intro"])
            .replace("GitLab issue", PLATFORM_TERMS["issue_system"]))
```

`src/code_review/prompt.py`：**保留老仓 `build_prompt(ctx, template_path, extra)` 实现不动**（`{{XXX}}` 占位符 + extra 字典注入，`test_prompt.py` 依赖此契约），仅在函数**末尾返回前**追加术语替换：

```python
def build_prompt(ctx: dict, template_path: str, extra: dict = None) -> str:
    """读取指定模板并替换占位符。extra 的 kv 合并到 mapping。"""
    with open(template_path, "r", encoding="utf-8") as f:
        tmpl = f.read()
    mapping = {
        "{{REPO_PATH}}": ctx.get("repo_path", ""),
        # ... 老仓原 11 个占位符映射保持不变 ...
    }
    if extra:
        for k, v in extra.items():
            mapping[f"{{{{{k}}}}}"] = str(v)
    out = tmpl
    for k, v in mapping.items():
        out = out.replace(k, str(v))
    # === 新增：平台术语替换（仅末尾这两行）===
    from .agents import _substitute_platform_terms
    return _substitute_platform_terms(out)
```

**关键**：不用 `.format(**context)`（会破坏 `{{XXX}}` 占位符 + extra 契约，导致 `test_prompt.py` 全红）。老仓的 `str.replace` 循环原样保留，只在 return 前套一层术语替换。

- [ ] **步骤 8：跑全测试确认通过**

运行：`pytest tests/ -v`
预期：全绿，0 失败

- [ ] **步骤 9：Commit**

```bash
cd D:/my_space/code-reviewer
git add -A
git commit -m "feat(main): 主流程接入 github_client + notifier

__main__.py：组装 GithubClient + GithubPrNotifier + ReportContext
orchestrator.py：send_report/send_error 走 notifier 实例
agent.py：dispatch_ctx 删 gitlab_* 加 issue_client
tools/create_issue+close_issue：改调 ctx[issue_client]
agents.py+prompt.py：术语替换 GitLab issue → GitHub issue + label 预创建提示

新仓从零组装，无中间态 break，全测试绿。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 6：CI（GitHub Actions + GHCR）

**文件：**
- 创建：`.github/workflows/build.yml`
- 创建：`.github/workflows/test.yml`
- 创建：`.github/workflows/release.yml`

- [ ] **步骤 1：创建三个 workflow**

`.github/workflows/build.yml` / `test.yml` / `release.yml` 内容见规格 §10。

- [ ] **步骤 2：本地验证 Dockerfile 能构建**

```bash
cd D:/my_space/code-reviewer
docker build -t code-reviewer:test .
docker run --rm code-reviewer:test python -c "from code_review import main; print('ok')"
```

预期：镜像构建成功，import 不报错

- [ ] **步骤 3：yaml lint（可选）**

```bash
# 如有 yamllint
yamllint .github/workflows/
```

- [ ] **步骤 4：Commit**

```bash
cd D:/my_space/code-reviewer
git add .github/workflows/
git commit -m "ci: GitHub Actions 构建链（GHCR + test + release）

build.yml：镜像构建 + 推 GHCR（:sha/:latest/:main）
test.yml：pytest
release.yml：softprops/action-gh-release 发 GitHub Release

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 7：开源基础设施

**文件：**
- 创建：`LICENSE` / `README.md` / `CONTRIBUTING.md` / `SECURITY.md` / `CODE_OF_CONDUCT.md` / `CHANGELOG.md`
- 创建：`.github/ISSUE_TEMPLATE/{bug_report,feature_request,config.yml}.md`
- 创建：`.github/PULL_REQUEST_TEMPLATE.md`

内容见规格 §11（LICENSE 用 MIT，CODE_OF_CONDUCT 用 Contributor Covenant 2.1 中文版，其余标准模板）。

- [ ] **步骤 1：创建 LICENSE / CHANGELOG / 4 个社区文件 / 4 个模板**

按规格 §11 内容。CHANGELOG 标 v1.0.0（新仓首发）。

- [ ] **步骤 2：写 README.md**

结构：徽章 + 简介 + 特性 + 快速接入（GitHub 消费者）+ env 表 + 工具集 + 退出码 + Contributing + License。镜像源用 `ghcr.io/yedazhi/code-reviewer`。

- [ ] **步骤 3：grep 校验无内网痕迹**

```bash
cd D:/my_space/code-reviewer
grep -rE "ccr\.ccs\.tencentyun\.com|c2h4|git\.c2h4\.cn|devtools|kaniko|glab|gitlab_client" --include="*.md" --include="*.yml" --include="*.yaml" --include="*.py" .
```

预期：无匹配（gitlab_client 不应出现在文档/配置；src 里也不应有，任务 1 没复制）

- [ ] **步骤 4：Commit**

```bash
cd D:/my_space/code-reviewer
git add LICENSE README.md CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md CHANGELOG.md .github/
git commit -m "docs: 开源基础设施

LICENSE(MIT) / README / CONTRIBUTING / SECURITY / CODE_OF_CONDUCT
4 个 issue/PR 模板 / CHANGELOG v1.0.0

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### 任务 8：novel_builder 接入 GitHub Actions

**文件（`D:\my_space\novel_builder`）：**
- 创建：`.github/workflows/code-review.yml`

- [ ] **步骤 1：创建 workflow**

内容见规格 §12.1（PR + push + dispatch，docker run GHCR 镜像，4 个 secrets）。

- [ ] **步骤 2：Commit**

```bash
cd D:/my_space/novel_builder
git add .github/workflows/code-review.yml
git commit -m "ci: 接入 code-reviewer GitHub Actions

docker run ghcr.io/yedazhi/code-reviewer:latest
PR 场景发评论 + 建 issue，push 场景发 commit status check
触发：PR + push 到 main/master + 手动 dispatch

Co-Authored-By: Claude <noreply@anthropic.com>"
```

- [ ] **步骤 3：（部署后）在 novel_builder 仓库预创建 4 个 label + 配 4 个 GitHub Secrets**

手动操作：Settings → Labels 加 `reviewer-generated` / `severity::critical` / `severity::warning` / `severity::suggestion`；Settings → Secrets 加 `GH_TOKEN` / `LLM_BASE_URL` / `LLM_API_KEY` / `LLM_MODEL`。

---

## 任务依赖图

```
Task 1 (建仓 + 复制核心)
  ↓
Task 2 (config.py) ─── Task 3 (github_client.py) ─── Task 4 (notifier.py)
                              ↓
                    Task 5 (主流程接入：__main__ + orchestrator + agent + tools + prompts)
                              ↓
                    Task 6 (CI) ─── Task 7 (开源基础设施)
                              ↓
                    Task 8 (novel_builder 接入)
```

## 执行检查点

- **Checkpoint A（任务 4 完成）**：github_client + notifier 就绪，可单测验证 6 端点 + PR 评论 + status check。Review 一遍。
- **Checkpoint B（任务 5 完成）**：主流程跑通，全测试绿。Review 一遍。
- **Checkpoint C（任务 8 完成）**：消费方接入，整体可发布。

## 风险与缓解

1. **复制时漏文件**：任务 1 步骤 4 跑 8 个只读工具测试 + cr_ignore/log/prompt 测试，import 失败立即暴露
2. **GitHub 422 分流误判**：任务 3 用真实 GitHub 错误响应体 mock，覆盖 assignee/labels/其他三分支
3. **commit status check 140 字符截断丢语义**：任务 4 description 截断保留关键词
4. **新仓首次推送 GHCR 权限**：任务 6 用 `secrets.GITHUB_TOKEN`，需 repo Settings → Actions → General → Workflow permissions 设 "Read and write"
5. **novel_builder PAT scope 不足**：fine-grained PAT 必须含 `repo`（issue + PR 评论 + status）

## 不在范围

- 镜像体积优化（多阶段构建/alpine）— 后续 issue
- GitHub App 替代 PAT — 后续 issue
- GitLab 平台支持 — 永不（现有 ci-code-reviewer 继续服务）
- 周报功能 — 永不