---
name: novel-app-release
description: Use this skill when building and releasing the Novel Flutter app. This skill provides version management, changelog generation, pre-publish validation (analyze + unit tests + APK build), and git commit + tag + push. APK release build is handled by GitHub Actions automatically. Trigger this skill when user asks to "release app", "publish new version", or "deploy app update".
---

# Novel App Release Skill

## Overview

此技能用于自动化 Novel Flutter 应用的发布流程，**严格遵循 CI 流程**：
1. **预检环节** — 在 `git commit` 之前先跑 `flutter analyze` + 单元测试 + 本地 APK 打包，与 GitHub Actions 检查项保持一致
2. 从 `pubspec.yaml` 读取版本信息
3. 分析 git diff 生成更新日志
4. 提交代码并创建 `v{version}` annotated tag
5. 推送 commit 和 tag 到远程仓库

> **预检目的**：任何会导致 GitHub Actions 失败的问题都要在本地先发现，避免推送后再修。
> 推送 tag 后，**GitHub Actions**（`.github/workflows/flutter-release.yml`）会自动完成 Release APK 构建并创建 GitHub Release。

## 何时使用

- 用户请求发布新版本应用
- 用户说"发布 APP"、"publish new version"、"deploy app update"

## 环境要求

- **Git** — 需要能 push 到 origin
- **Python 3.10+** — 运行发布脚本
- **Flutter SDK 3.x (stable)** — **需要本地 Flutter**，用于预检 (analyze + test + build apk)

## 发布流程

### 一键发布

```bash
python .claude/skills/novel-app-release/scripts/build_and_upload.py
```

脚本执行 **3 个阶段**：

#### 阶段 1：预检（preflight）— 模拟 CI 流程

| 步骤 | 命令 | 失败处理 |
|------|------|----------|
| 1.1 静态分析 | `flutter analyze --no-fatal-infos` | 失败则中断，提示修复 |
| 1.2 单元测试 | `flutter test --no-pub test/unit/ test/bug/ test/verification/` | 失败则中断，提示修复 |
| 1.3 本地 Release APK 打包 | `flutter build apk --release` | 失败则中断，提示修复 |

> 上述三个命令与 `.github/workflows/flutter-ci.yml` + `flutter-release.yml` 中的步骤完全一致。
> 任一失败都意味着 GitHub Actions 也会失败，必须先修复再发布。

#### 阶段 2：版本识别与变更日志

1. 解析 `novel_app/pubspec.yaml` 中的 `version: x.y.z+code`
2. 从 `novel_app/lib` 的 git diff 分析自动生成更新日志（可用 `CHANGELOG` 环境变量覆盖）

#### 阶段 3：git 操作

1. `git add .` — 添加所有变更文件
2. `git commit -m "chore: 发布版本 {version}"` — 提交
3. `git tag -a v{version} -m "Release {version}"` — 创建 annotated tag
4. `git push` — 推送 commit
5. `git push origin v{version}` — 推送 tag，触发 GitHub Actions

### 自定义更新日志

```bash
# Windows CMD
set CHANGELOG=修复登录问题、优化阅读体验

# Windows PowerShell
$env:CHANGELOG="修复登录问题、优化阅读体验"

# Linux/Mac
CHANGELOG="修复登录问题、优化阅读体验" python ...
```

不设置 `CHANGELOG` 环境变量时，脚本会分析 `novel_app/lib` 的 git diff 自动生成。

### 跳过预检（不推荐）

如果想跳过预检步骤（例如紧急修复、已知 CI 失败点）：

```bash
SKIP_PREFLIGHT=1 python .claude/skills/novel-app-release/scripts/build_and_upload.py
```

> ⚠️ 跳过预检后 GitHub Actions 仍会运行同样的检查；如失败 tag 推上去也没用，发布实际上会失败。

## 版本管理

### 版本号格式

`pubspec.yaml` 中：`version: 1.7.9+58`

- `1.7.9` — 版本名称
- `58` — 版本代码，必须递增

### 更新版本号

发布前手动修改 `novel_app/pubspec.yaml`：

```yaml
# 小版本更新
version: 1.7.8+57  →  version: 1.7.9+58

# 大版本更新
version: 1.7.8+57  →  version: 2.0.0+58
```

## GitHub Actions 流程

tag `v*` 推送后自动触发（`.github/workflows/flutter-release.yml`）：

| 步骤 | 说明 | 本地是否预跑 |
|------|------|--------------|
| Checkout | 检出代码 | — |
| Extract version | 从 tag 提取版本号 | — |
| Setup Flutter | 安装 Flutter SDK | — |
| Install dependencies | `flutter pub get` | — |
| Generate code | `dart run build_runner build` | — |
| **Build release APK** | `flutter build apk --release` | ✅ |
| Create GitHub Release | 上传 APK，生成 Release Notes | — |

PR / push 到 main 时（`.github/workflows/flutter-ci.yml`）还会跑：

| 步骤 | 说明 | 本地是否预跑 |
|------|------|--------------|
| **Analyze** | `flutter analyze --no-fatal-infos` | ✅ |
| **Run unit tests** | `flutter test --no-pub test/unit/ test/bug/ test/verification/` | ✅ |

## 常见问题

### Q: 预检失败了怎么办？

1. 阅读脚本输出，定位是 analyze / test / build apk 哪一步失败
2. 修复代码（不要尝试跳过预检来掩盖问题）
3. 重新运行脚本

### Q: 脚本执行后怎么确认 Release 是否成功？

1. 查看本地 tag：`git tag -l "v*"`
2. 查看 GitHub Actions：`https://github.com/yunkst/novel_builder/actions`
3. 查看 Release 页面：`https://github.com/yunkst/novel_builder/releases`

### Q: 推送失败怎么办？

通常是网络问题或远程仓库有新 commit。先 `git pull --rebase` 再重新运行脚本。

如果 tag 已创建但推送失败：
```bash
git push origin v1.7.9
```

### Q: 想回退一个错误发布？

```bash
# 删除本地 tag
git tag -d v1.7.9

# 删除远程 tag
git push origin :refs/tags/v1.7.9

# 回退 commit
git reset --soft HEAD~1
```

## 文件结构

```
.claude/skills/novel-app-release/
├── SKILL.md                    # 本文档
├── FIXES.md                    # 修复记录
└── scripts/
    └── build_and_upload.py     # 发布脚本（preflight + commit + tag + push）
```

## 变更记录

- **2026-06-13**: 新增预检阶段（flutter analyze + unit test + 本地 APK 打包），与 CI 流程完全对齐；支持 `SKIP_PREFLIGHT=1` 跳过；强化文档说明
- **2026-06-12**: 移除本地 APK 构建和后端上传，改为纯 git 操作 + 依赖 GitHub Actions 构建；增加 commit push
- **2026-06-12**: 初版：构建 APK + 上传到 backend
