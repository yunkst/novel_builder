---
name: novel-app-release
description: 自动打包Novel App Flutter应用并上传到后端服务器的专用skill。用于版本发布流程自动化，包括从pubspec.yaml读取版本信息、构建release APK、上传到后端API。在用户需要"打包发布app"、"构建并上传新版本"时触发此skill。
---

# Novel App Release Skill

此skill用于自动化Novel Builder项目的Android应用发布流程。

## Skill用途

此skill专用于Novel Builder项目，自动化以下操作：

1. **读取版本信息**: 从 `novel_app/pubspec.yaml` 自动解析版本号和版本码
2. **构建APK**: 执行 `flutter build apk --release` 构建生产版本
3. **上传到后端**: 调用后端API上传APK并创建版本记录

## 何时使用

在以下场景中应使用此skill：

- 用户请求"打包app"或"构建发布版本"
- 用户请求"上传新版本到后端"或"发布app更新"
- 用户需要完整的构建+上传流程

## 执行流程

### 方法1: 使用自动化脚本（推荐）

使用 `scripts/build_and_upload.py` 执行完整流程：

```bash
# 设置环境变量
export NOVEL_API_URL="http://localhost:3800"
export NOVEL_API_TOKEN="your_api_token"
export CHANGELOG="修复bug和性能优化"
export FORCE_UPDATE="false"

# 执行脚本
python .claude/skills/novel-app-release/scripts/build_and_upload.py
```

### 方法2: 手动执行步骤

#### 步骤1: 读取版本信息

从 `novel_app/pubspec.yaml` 读取版本：

```yaml
version: 1.0.1+2  # 格式: version_name+version_code
```

#### 步骤2: 构建Flutter APK

```bash
cd novel_app
flutter build apk --release
```

构建产物位于: `build/app/outputs/flutter-apk/app-release.apk`

#### 步骤3: 上传到后端

使用 `curl` 或 `requests` 上传：

```bash
curl -X POST "http://localhost:3800/api/app-version/upload" \
  -H "X-API-TOKEN: your_token" \
  -F "file=@app-release.apk" \
  -F "version=1.0.1" \
  -F "version_code=2" \
  -F "changelog=更新内容" \
  -F "force_update=false"
```

## 项目结构信息

### Flutter应用配置

- **路径**: `novel_app/`
- **版本文件**: `pubspec.yaml` 第19行
- **构建命令**: `flutter build apk --release`
- **输出路径**: `build/app/outputs/flutter-apk/app-release.apk`

### 后端API配置

- **上传端点**: `POST /api/app-version/upload`
- **认证方式**: `X-API-TOKEN` header
- **支持参数**:
  - `file`: APK文件 (必需)
  - `version`: 版本号如 1.0.1 (必需)
  - `version_code`: 版本递增码 (必需)
  - `changelog`: 更新日志 (可选)
  - `force_update`: 是否强制更新 (可选，默认false)

### 环境变量配置

```bash
NOVEL_API_URL="http://localhost:3800"      # 后端API地址
NOVEL_API_TOKEN="your_api_token"           # API认证令牌
CHANGELOG="版本更新内容"                    # 更新日志
FORCE_UPDATE="false"                       # 是否强制更新
```

## 版本管理规则

1. **版本号格式**: 遵循语义化版本规范 `major.minor.patch`，如 `1.0.1`
2. **版本码**: 每次发布必须递增，如 `2`、`3`、`4`
3. **更新 pubspec.yaml**: 发布前必须更新版本号和版本码

## 常见问题

### Q: Flutter环境未配置怎么办？
A: 确保Flutter SDK已安装并在PATH中，运行 `flutter doctor` 检查环境

### Q: 构建失败如何调试？
A: 检查 `novel_app/android/app/build.gradle.kts` 配置，确保 `compileSdk` 和 `targetSdk` 版本正确

### Q: 上传失败如何处理？
A: 检查后端服务状态、API token是否正确、网络连接是否正常

## 相关文件

- `scripts/build_and_upload.py` - 自动化脚本
- `novel_app/pubspec.yaml` - 版本配置
- `backend/app/main.py:764-827` - 上传API实现
- `backend/app/services/app_version_service.py` - 版本管理服务
