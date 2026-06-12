---
name: novel-app-release
description: Use this skill when building and releasing the Novel Flutter app. This skill provides version management, changelog generation, git commit + tag + push. APK building is handled by GitHub Actions automatically. Trigger this skill when user asks to "release app", "publish new version", or "deploy app update".
---

# Novel App Release Skill

## Overview

此技能用于自动化 Novel Flutter 应用的发布流程：
1. 从 `pubspec.yaml` 读取版本信息
2. 分析 git diff 生成更新日志
3. 提交代码并创建 `v{version}` annotated tag
4. 推送 commit 和 tag 到远程仓库

推送 tag 后，**GitHub Actions**（`.github/workflows/flutter-release.yml`）会自动完成 APK 构建并创建 GitHub Release。

> **此 skill 不在本地构建 APK**，所有构建由 CI 完成。

## 何时使用

- 用户请求发布新版本应用
- 用户说"发布 APP"、"publish new version"、"deploy app update"

## 环境要求

- **Git** — 需要能 push 到 origin
- **Python 3.10+** — 运行发布脚本
- **Flutter SDK** — 不需要（CI 会构建）

## 发布流程

### 一键发布

```bash
python .claude/skills/novel-app-release/scripts/build_and_upload.py
```

脚本执行 5 个步骤：
1. **添加变更文件** — `git add .`
2. **提交代码** — `git commit -m "chore: 发布版本 {version}"`
3. **创建标签** — `git tag -a v{version} -m "Release {version}"`
4. **推送 commit** — `git push`
5. **推送标签** — `git push origin v{version}`

完成后 GitHub Actions 自动触发：
- 构建 Flutter Release APK
- 创建 GitHub Release（含 APK 下载链接）

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

| 步骤 | 说明 |
|------|------|
| Checkout | 检出代码 |
| Extract version | 从 tag 提取版本号 |
| Setup Flutter | 安装 Flutter SDK |
| Install dependencies | `flutter pub get` |
| Generate code | `dart run build_runner build` |
| Build release APK | `flutter build apk --release` |
| Create GitHub Release | 上传 APK，生成 Release Notes |

## 常见问题

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
    └── build_and_upload.py     # 发布脚本（commit + tag + push）
```

## 变更记录

- **2026-06-12**: 移除本地 APK 构建和后端上传，改为纯 git 操作 + 依赖 GitHub Actions 构建；增加 commit push
- **2026-06-12**: 初版：构建 APK + 上传到 backend
