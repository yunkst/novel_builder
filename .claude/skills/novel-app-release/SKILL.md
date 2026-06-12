---
name: novel-app-release
description: Use this skill when building and releasing the Novel Flutter app. This skill provides automated APK building, version management, and changelog generation. Trigger this skill when user asks to "release app", "build APK", "publish new version", or "deploy app update".
---

# Novel App Release Skill

## Overview

此技能用于自动化 Novel Flutter 应用的本地发布流程，包括：
- 自动读取版本信息
- 分析代码变更生成更新日志
- 构建 Release APK
- 自动提交代码变更并打 tag

> **注意**: 此 skill **不再上传 APK 到后端服务器**。构建产物保留在本地路径，如需上传请手动处理。

## 何时使用

- 用户请求发布新版本应用
- 用户需要构建 Release APK
- 用户想要自动化应用发布流程
- 需要生成版本更新日志

## 环境要求

### 必需工具
- Flutter SDK 3.0+
- Python 3.10+
- Git

### Python 依赖
```bash
pip install requests
```

> `requests` 不再被脚本实际使用，但保留以兼容可能的扩展，按需可卸载。

### 环境变量配置

在项目根目录创建 `.env` 文件（可选，脚本不依赖环境变量运行）：

```env
# 可选：自定义更新日志（不设置则自动生成）
CHANGELOG=自定义更新日志
```

## 发布流程

### 完整发布流程

执行完整的本地构建与提交流程：

```bash
python .claude/skills/novel-app-release/scripts/build_and_upload.py
```

流程步骤：
1. **读取版本信息** - 从 `pubspec.yaml` 解析版本号
2. **生成更新日志** - 分析 `novel_app/lib` 目录的 git diff
3. **构建 APK** - 执行 `flutter build apk --release`
4. **提交代码并打 tag** - 自动创建 git commit + `v{version}` annotated tag

## 版本管理

### 版本号格式

Flutter 使用 `pubspec.yaml` 管理版本：

```yaml
version: 1.3.7+25
```

- `1.3.7` - 版本名称（version name）
- `25` - 版本代码（version code），必须递增

### 更新版本

手动更新 `novel_app/pubspec.yaml`：

```yaml
# 小版本更新
version: 1.3.7+25  →  version: 1.3.8+26

# 大版本更新
version: 1.3.7+25  →  version: 1.4.0+26
```

## 更新日志生成

### 自动生成

脚本会分析 `novel_app/lib` 目录的变更，按模块分类：

| 模块 | 目录 | 描述示例 |
|------|------|---------|
| screens | lib/screens/ | 界面功能增强 |
| widgets | lib/widgets/ | 组件优化 |
| services | lib/services/ | 服务层优化 |
| providers | lib/providers/ | 状态管理优化 |
| repositories | lib/repositories/ | 数据层优化 |

### 自定义更新日志

设置环境变量覆盖自动生成：

```bash
# Windows CMD
set CHANGELOG=修复登录问题、优化阅读体验
python scripts/build_and_upload.py

# Windows PowerShell
$env:CHANGELOG="修复登录问题、优化阅读体验"
python scripts/build_and_upload.py

# Linux/Mac
CHANGELOG="修复登录问题、优化阅读体验" python scripts/build_and_upload.py
```

## 输出文件

### APK 文件位置

```
novel_app/build/app/outputs/flutter-apk/app-release.apk
```

### 文件大小参考

- 典型大小：50-70 MB
- 构建时间：约 2 分钟

## 常见问题

### Q: 构建失败，提示找不到 Flutter

确保 Flutter 在 PATH 中：

```bash
# 验证
flutter --version

# Windows 添加到 PATH
# 系统属性 → 高级 → 环境变量 → Path
```

### Q: Windows 终端显示乱码

脚本输出在 Windows CMD 中可能出现中文乱码（GBK 编码问题）。

解决方案：
1. **推荐使用 PowerShell** 代替 CMD
2. 设置编码：`chcp 65001`
3. 设置环境变量：`set PYTHONIOENCODING=utf-8`

> 注意：乱码不影响实际功能，发布流程仍会正常完成。脚本内部已处理 Git 命令的编码兼容问题。

### Q: APK 文件找不到

确认构建是否成功完成，检查路径：

```
novel_app/build/app/outputs/flutter-apk/app-release.apk
```

### Q: 想把 APK 分发到用户

此 skill **不包含自动上传功能**。如需分发 APK：
1. 脚本会在 `novel_app/build/app/outputs/flutter-apk/app-release.apk` 生成构建产物
2. 手动上传到分发平台（GitHub Release、网盘、自己的 CDN 等）
3. 或在 `git push` 时把 tag 推上去，让用户通过 GitHub Releases 下载

## 发布后操作

### 推送到远程仓库

脚本会自动创建本地 commit 和带注释的 tag。tag 会自动 push 到 origin，commit 需要手动 push：

```bash
git push
```

如果 tag 推送失败，也可以手动推送：

```bash
git push origin v1.7.9
```

### 验证发布

1. 检查 `novel_app/build/app/outputs/flutter-apk/app-release.apk` 是否存在
2. 检查 git log 和 tag 是否正确：
   ```bash
   git log --oneline -1
   git tag -l "v*"
   ```

## 技术细节

### 构建命令

```bash
cd novel_app
flutter build apk --release
```

### Git 分析逻辑

脚本分析 `git diff --name-only novel_app/lib` 获取变更文件列表，然后根据文件路径分类生成更新描述。

### 错误处理

- 文件不存在检查
- Git 命令编码兼容（Windows GBK/UTF-8）

## 文件结构

```
.claude/skills/novel-app-release/
├── SKILL.md                          # 本文档
├── FIXES.md                          # 修复记录
└── scripts/
    └── build_and_upload.py           # 本地打包并提交脚本
```

## 变更记录

- **2026-06-12**: 移除上传到 backend 的功能，简化脚本为本地构建 + git 提交 + 打 tag
- **2025-XX-XX**: 初始版本：构建 APK + 上传到 backend + git 提交
