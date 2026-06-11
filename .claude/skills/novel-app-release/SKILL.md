---
name: novel-app-release
description: Use this skill when building and releasing the Novel Flutter app. This skill provides automated APK building, version management, changelog generation, and backend upload functionality. Trigger this skill when user asks to "release app", "build and upload APK", "publish new version", or "deploy app update".
---

# Novel App Release Skill

## Overview

此技能用于自动化 Novel Flutter 应用的发布流程，包括：
- 自动读取版本信息
- 分析代码变更生成更新日志
- 构建 Release APK
- 上传到后端服务器
- 自动提交代码变更

## 何时使用

- 用户请求发布新版本应用
- 用户需要构建并上传 APK
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

### 环境变量配置

在项目根目录创建 `.env` 文件：

```env
# API 配置
NOVEL_API_URL=http://localhost:3800
NOVEL_API_TOKEN=your_api_token_here

# 可选配置
FORCE_UPDATE=false          # 是否强制更新
CHANGELOG=自定义更新日志    # 可选，不设置则自动生成
```

## 发布流程

### 完整发布流程

执行完整的构建和上传流程：

```bash
python .claude/skills/novel-app-release/scripts/build_and_upload.py
```

流程步骤：
1. **读取版本信息** - 从 `pubspec.yaml` 解析版本号
2. **生成更新日志** - 分析 `novel_app/lib` 目录的 git diff
3. **构建 APK** - 执行 `flutter build apk --release`
4. **上传到后端** - 调用后端 API 上传 APK
5. **提交代码并打 tag** - 自动创建 git commit + `v{version}` annotated tag

### 仅上传已有 APK

如果 APK 已经构建完成，只想上传：

```bash
python .claude/skills/novel-app-release/upload_apk.py
```

> 注意：需要先修改脚本中的配置项（VERSION, VERSION_CODE, CHANGELOG）

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

## API 接口

### 上传接口

```
POST /api/app-version/upload
```

**Headers:**
```
X-API-TOKEN: your_token
```

**Form Data:**
| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| file | File | 是 | APK 文件 |
| version | String | 是 | 版本名称，如 "1.3.7" |
| version_code | String | 是 | 版本代码，如 "25" |
| changelog | String | 否 | 更新日志 |
| force_update | String | 否 | "true" 或 "false" |

### 下载接口

```
GET /api/app-version/download/{version}
```

## 输出文件

### APK 文件位置

```
novel_app/build/app/outputs/flutter-apk/app-release.apk
```

### 文件大小参考

- 典型大小：50-60 MB
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

### Q: 上传失败，提示认证错误

检查 `.env` 文件中的 `NOVEL_API_TOKEN`：

```env
NOVEL_API_TOKEN=正确的_token_值
```

### Q: 上传超时

APK 文件较大（约 60MB），可能需要调整超时时间。默认超时为 300 秒。

检查：
1. 网络连接状态
2. 后端服务是否正常运行
3. 服务器磁盘空间是否充足

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

## 发布后操作

### 推送到远程仓库

脚本会自动创建本地 commit 和 tag，需要手动推送tag：

```bash
git push
git push origin v1.3.8
```

### 验证发布

1. 检查后端日志确认上传成功
2. 在应用中测试更新功能
3. 验证下载链接是否有效

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
- 网络请求超时处理
- Git 命令编码兼容（Windows GBK/UTF-8）

## 文件结构

```
.claude/skills/novel-app-release/
├── SKILL.md                          # 本文档
├── FIXES.md                          # 修复记录
├── scripts/
│   └── build_and_upload.py           # 完整发布脚本
└── upload_apk.py                     # 简单上传脚本
```