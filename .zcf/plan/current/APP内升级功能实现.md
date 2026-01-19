# APP内升级功能实现计划

**任务描述**: 实现APP内升级功能，包括后端上传/查询/下载接口和Flutter端版本检查/下载/安装功能

**创建时间**: 2026-01-12

**配置确认**:
- APK存储位置: `backend/uploads/apk/`
- 版本保留策略: 仅保留最新+上一版本
- 上传接口权限: 使用现有 X-API-TOKEN 认证

---

## 技术选型

### 后端依赖
- `aiofiles`: 异步文件操作
- `packaging`: 语义化版本比较
- 现有技术栈: FastAPI + SQLAlchemy + PostgreSQL

### Flutter依赖
- `background_downloader`: ^8.0.0 - APK下载和进度监控
- `permission_handler`: ^11.0.0 - 安装权限请求
- `package_info_plus`: ^8.0.0 - 获取当前APP版本信息
- `open_file` 或 `install_plugin`: APK安装（优先使用原生方式）

---

## 执行步骤

### 阶段1: 后端实现

#### 1.1 创建数据库模型
**文件**: `backend/app/models/app_version.py`

**内容**:
```python
from sqlalchemy import Column, DateTime, Integer, String
from datetime import datetime

class AppVersion(Base):
    """APP版本管理表"""
    __tablename__ = "app_versions"

    id = Column(Integer, primary_key=True, index=True)
    version = Column(String(20), nullable=False, unique=True)  # 语义化版本号
    version_code = Column(Integer, nullable=False)  # 版本递增码
    file_path = Column(String(500), nullable=False)  # APK文件路径
    file_size = Column(Integer, nullable=False)  # 文件大小(字节)
    download_url = Column(String(500), nullable=False)  # 下载URL
    changelog = Column(String(2000), nullable=True)  # 更新日志
    force_update = Column(Integer, default=0)  # 是否强制更新 (0否 1是)
    created_at = Column(DateTime, default=datetime.now)

    __table_args__ = (
        Index("idx_version_code", "version_code"),
    )
```

**预期结果**: 新增数据模型类，支持版本元数据存储

---

#### 1.2 创建Pydantic模式
**文件**: `backend/app/schemas.py` (新增内容)

**新增模式**:
```python
class AppVersionUploadRequest(BaseModel):
    """APP版本上传请求"""
    version: str = Field(..., description="版本号 (如 1.0.1)")
    version_code: int = Field(..., ge=1, description="版本递增码")
    changelog: str | None = Field(None, description="更新日志")
    force_update: bool = Field(False, description="是否强制更新")

class AppVersionResponse(BaseModel):
    """APP版本信息响应"""
    version: str = Field(..., description="版本号")
    version_code: int = Field(..., description="版本递增码")
    download_url: str = Field(..., description="下载URL")
    file_size: int = Field(..., description="文件大小(字节)")
    changelog: str | None = Field(None, description="更新日志")
    force_update: bool = Field(False, description="是否强制更新")
    created_at: str = Field(..., description="发布时间")
```

**预期结果**: 新增API请求/响应模式，支持数据验证

---

#### 1.3 创建上传服务
**文件**: `backend/app/services/app_version_service.py`

**核心功能**:
- `upload_apk()` - 处理APK文件上传，保存到`uploads/apk/`
- `get_latest_version()` - 获取最新版本信息
- `cleanup_old_versions()` - 清理旧版本（保留最新+上一版本）
- `compare_versions()` - 版本号比较逻辑

**预期结果**: 服务层完整实现，支持文件上传和版本管理

---

#### 1.4 添加API路由
**文件**: `backend/app/main.py` (新增内容)

**新增端点**:
```python
# 1. 上传APK
@app.post("/api/app-version/upload", dependencies=[Depends(verify_token)])
async def upload_app_version(file: UploadFile, metadata: AppVersionUploadRequest, db: Session = Depends(get_db))

# 2. 查询最新版本
@app.get("/api/app-version/latest", response_model=AppVersionResponse, dependencies=[Depends(verify_token)])
async def get_latest_app_version(db: Session = Depends(get_db))

# 3. 下载APK
@app.get("/api/app-version/download/{version}", response_class=FileResponse)
async def download_app_version(version: str, db: Session = Depends(get_db))
```

**预期结果**: 3个REST API端点可用

---

#### 1.5 数据库迁移
**操作**: 生成并执行Alembic迁移

**命令**:
```bash
cd backend
alembic revision --autogenerate -m "add app_versions table"
alembic upgrade head
```

**预期结果**: 数据库新增`app_versions`表

---

#### 1.6 配置更新
**文件**: `backend/app/config.py`

**新增配置**:
```python
# APK存储配置
apk_upload_dir: str = os.getenv("APK_UPLOAD_DIR", "uploads/apk")
apk_max_size: int = int(os.getenv("APK_MAX_SIZE", "100"))  # MB
```

**预期结果**: 新增环境变量支持

---

### 阶段2: Flutter实现

#### 2.1 添加依赖
**文件**: `novel_app/pubspec.yaml`

**新增依赖**:
```yaml
dependencies:
  background_downloader: ^8.0.0
  permission_handler: ^11.0.0
  package_info_plus: ^8.0.0
```

**操作**: `flutter pub get`

**预期结果**: 依赖安装成功

---

#### 2.2 创建版本模型
**文件**: `novel_app/lib/models/app_version.dart`

**内容**:
```dart
class AppVersion {
  final String version;
  final int versionCode;
  final String downloadUrl;
  final int fileSize;
  final String? changelog;
  final bool forceUpdate;
  final DateTime createdAt;
}
```

**预期结果**: 版本数据模型

---

#### 2.3 创建更新服务
**文件**: `novel_app/lib/services/app_update_service.dart`

**核心功能**:
- `checkForUpdate()` - 检查是否有新版本
- `downloadUpdate()` - 下载APK（带进度）
- `installUpdate()` - 安装APK
- `requestInstallPermission()` - 请求安装权限
- `compareVersions()` - 版本比较

**预期结果**: 完整的更新服务

---

#### 2.4 创建更新对话框组件
**文件**: `novel_app/lib/widgets/app_update_dialog.dart`

**功能**:
- 显示有新版本提示
- 展示更新日志
- 下载进度条
- 立即更新/稍后提醒按钮

**预期结果**: 可复用的更新对话框组件

---

#### 2.5 在设置页面添加入口
**文件**: `novel_app/lib/screens/settings_screen.dart`

**修改内容**:
- 新增"检查更新"菜单项
- 显示当前版本号
- 点击后检查更新

**预期结果**: 设置页面新增版本检查入口

---

#### 2.6 创建更新详情页面
**文件**: `novel_app/lib/screens/app_update_screen.dart`

**功能**:
- 显示当前版本 vs 最新版本
- 更新日志详情
- 下载按钮和进度显示
- 下载完成后安装按钮

**预期结果**: 独立的更新页面

---

### 阶段3: 权限配置

#### 3.1 Android权限配置
**文件**: `novel_app/android/app/src/main/AndroidManifest.xml`

**新增权限**:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
```

**预期结果**: Android权限配置完成

---

#### 3.2 文件提供者配置
**文件**: `novel_app/android/app/src/main/AndroidManifest.xml`

**新增provider**:
```xml
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

**预期结果**: FileProvider配置完成

---

#### 3.3 创建file_paths.xml
**文件**: `novel_app/android/app/src/main/res/xml/file_paths.xml`

**内容**:
```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <cache-path name="apk_cache" path="apk/" />
    <files-path name="apk_files" path="apk/" />
    <external-path name="apk_external" path="apk/" />
</paths>
```

**预期结果**: 文件路径配置完成

---

### 阶段4: 测试验证

#### 4.1 后端测试
- 上传测试APK文件
- 验证版本信息正确存储
- 测试下载接口
- 验证旧版本自动清理

#### 4.2 前端测试
- 版本检查功能
- 下载进度显示
- 权限请求流程
- APK安装功能

#### 4.3 端到端测试
- 完整的更新流程
- 强制更新场景
- 网络异常处理

---

## 新增依赖清单

### Python后端
```txt
aiofiles>=23.0.0
packaging>=23.0.0
```

### Flutter前端
```yaml
background_downloader: ^8.0.0
permission_handler: ^11.0.0
package_info_plus: ^8.0.0
```

---

## 文件清单

### 后端文件
- `backend/app/models/app_version.py` (新建)
- `backend/app/services/app_version_service.py` (新建)
- `backend/app/schemas.py` (修改)
- `backend/app/main.py` (修改)
- `backend/app/config.py` (修改)
- `backend/uploads/apk/` (新建目录)

### Flutter文件
- `novel_app/lib/models/app_version.dart` (新建)
- `novel_app/lib/services/app_update_service.dart` (新建)
- `novel_app/lib/widgets/app_update_dialog.dart` (新建)
- `novel_app/lib/screens/app_update_screen.dart` (新建)
- `novel_app/lib/screens/settings_screen.dart` (修改)
- `novel_app/android/app/src/main/AndroidManifest.xml` (修改)
- `novel_app/android/app/src/main/res/xml/file_paths.xml` (新建)
- `novel_app/pubspec.yaml` (修改)

---

## API接口规范

### 1. 上传APK
```
POST /api/app-version/upload
Content-Type: multipart/form-data
Headers: X-API-TOKEN

Body:
- file: APK文件
- metadata: JSON字符串
  {
    "version": "1.0.1",
    "version_code": 2,
    "changelog": "修复bug，优化性能",
    "force_update": false
  }

Response:
{
    "message": "上传成功",
    "version": "1.0.1",
    "download_url": "/api/app-version/download/1.0.1"
}
```

### 2. 查询最新版本
```
GET /api/app-version/latest
Headers: X-API-TOKEN

Response:
{
    "version": "1.0.1",
    "version_code": 2,
    "download_url": "/api/app-version/download/1.0.1",
    "file_size": 15728640,
    "changelog": "修复bug，优化性能",
    "force_update": false,
    "created_at": "2026-01-12T10:00:00"
}
```

### 3. 下载APK
```
GET /api/app-version/download/{version}
Headers: X-API-TOKEN

Response: APK文件 (application/vnd.android.package-archive)
```

---

## 注意事项

1. **文件大小限制**: 默认100MB，可通过环境变量配置
2. **版本号格式**: 遵循语义化版本规范 (major.minor.patch)
3. **权限处理**: Android需要用户授权安装应用权限
4. **网络超时**: 大文件下载需要合理的超时配置
5. **存储空间**: 后端需要监控磁盘空间使用情况
6. **安全性**: 上传接口建议增加管理员认证
7. **兼容性**: 仅支持Android平台的APK安装
