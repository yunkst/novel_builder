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

**重要**：在 Windows 上请使用 Python requests 库上传，避免 curl 的 UTF-8 编码问题。

**方法1: 使用 Python requests（推荐）**

```python
import requests

url = 'http://localhost:3800/api/app-version/upload'
headers = {'X-API-TOKEN': 'your_token'}
files = {'file': open('build/app/outputs/flutter-apk/app-release.apk', 'rb')}
data = {
    'version': '1.0.1',
    'version_code': 2,
    'changelog': '修复bug和性能优化',  # Python 默认使用 UTF-8
    'force_update': 'false'
}

response = requests.post(url, headers=headers, files=files, data=data)
print(response.json())
```

**方法2: 使用自动化脚本**

```bash
# 设置环境变量
export CHANGELOG="修复bug和性能优化"

# 执行脚本（会自动读取 .env 中的 NOVEL_API_TOKEN）
python .claude/skills/novel-app-release/scripts/build_and_upload.py
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

## 获取 API Token

### 方法1: 从 Docker 容器获取（推荐）

```bash
# 查看后端容器的环境变量
docker exec novel_builder-backend-1 printenv | grep NOVEL_API_TOKEN
```

输出示例：
```
NOVEL_API_TOKEN=test_token_123
```

### 方法2: 从 .env 文件读取

```bash
# 查看项目根目录的 .env 文件
cat .env | grep NOVEL_API_TOKEN
```

### 方法3: 从容器内直接获取（用于验证）

```bash
# 进入容器验证配置
docker exec novel_builder-backend-1 python -c "from app.config import settings; print(f'api_token={settings.api_token}')"
```

## 常见问题

### Q: Flutter环境未配置怎么办？
A: 确保Flutter SDK已安装并在PATH中，运行 `flutter doctor` 检查环境

### Q: 构建失败如何调试？
A: 检查 `novel_app/android/app/build.gradle.kts` 配置，确保 `compileSdk` 和 `targetSdk` 版本正确

### Q: 上传时 changelog 出现乱码怎么办？
A: **重要**：避免使用 curl 命令上传，因为 Windows 下 curl 的 `-F` 参数可能不正确处理 UTF-8 编码。请使用以下方法：

**推荐方法：使用 Python requests 库**

```python
import requests

url = 'http://localhost:3800/api/app-version/upload'
headers = {'X-API-TOKEN': 'your_token'}
files = {'file': open('app-release.apk', 'rb')}
data = {
    'version': '1.0.4',
    'version_code': 5,
    'changelog': '修复翻页后自动阅读功能失效的问题',  # Python 默认使用 UTF-8
    'force_update': 'false'
}

response = requests.post(url, headers=headers, files=files, data=data)
print(response.json())
```

**为什么会出现乱码？**
- Windows 终端默认使用 GBK/CP936 编码
- curl 在 Windows 上可能不正确转换 UTF-8 编码
- Python requests 库默认使用 UTF-8，能正确处理中文

### Q: 上传失败提示 "API_TOKEN not set"？
A: 这通常是因为后端容器的环境变量未正确加载。解决方法：

1. 确认 `.env` 文件中设置了 `NOVEL_API_TOKEN`
2. 重启后端容器：`docker restart novel_builder-backend-1`
3. 验证配置：`docker exec novel_builder-backend-1 python -c "from app.config import settings; print(settings.api_token)"`

### Q: 版本已存在错误？
A: 需要在 `pubspec.yaml` 中更新版本号和版本码：
```yaml
version: 1.0.5+6  # 版本号和版本码都需要递增
```

## 相关文件

- `scripts/build_and_upload.py` - 自动化脚本
- `novel_app/pubspec.yaml` - 版本配置
- `backend/app/main.py:764-827` - 上传API实现
- `backend/app/services/app_version_service.py` - 版本管理服务
