[根目录](../../CLAUDE.md) > **novel_app**

# Flutter移动应用模块

## 变更记录 (Changelog)

- **2025-11-13**: 模块文档初始化，详细描述应用架构和核心功能

## 模块职责

Flutter移动应用是Novel Builder平台的前端客户端，提供跨平台的小说阅读体验。主要负责：
- 小说搜索与发现
- 本地书架管理
- 离线阅读体验
- AI增强功能
- 用户偏好设置

## 入口与启动

### 主入口文件
- **路径**: `lib/main.dart`
- **应用类**: `NovelReaderApp`
- **主页**: `HomePage` 底部导航结构

### 应用启动流程
1. **初始化Flutter绑定**: `WidgetsFlutterBinding.ensureInitialized()`
2. **API服务初始化**: `ApiServiceWrapper().init()`
3. **Material3主题设置**: 默认暗色主题
4. **底部导航**: 书架、搜索、设置三个标签页

## 对外接口

### API服务层
- **Backend API Service**: `lib/services/backend_api_service.dart`
  - 搜索小说 (`/search`)
  - 获取章节列表 (`/chapters`)
  - 获取章节内容 (`/chapter-content`)
- **API Service Wrapper**: `lib/services/api_service_wrapper.dart`
  - OpenAPI生成代码的包装器
  - 自动初始化和错误处理

### AI集成接口
- **Dify Service**: `lib/services/dify_service.dart`
  - 流式AI响应处理
  - 特写功能内容生成
  - SSE解析器支持

## 关键依赖与配置

### 核心依赖
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  http: ^1.1.0
  dio: ^5.4.0
  built_value: ^8.9.0
  html: ^0.15.4
  json_annotation: ^4.8.0
  sqflite: ^2.3.0
  path_provider: ^2.1.1
  provider: ^6.1.1
  shared_preferences: ^2.2.2
```

### 代码生成工具
```yaml
dev_dependencies:
  build_runner: ^2.4.0
  json_serializable: ^6.7.0
  built_value_generator: ^8.9.0
```

### 配置文件
- **pubspec.yaml**: 项目依赖和配置
- **analysis_options.yaml**: 代码分析配置
- **openapi-config.yaml**: API客户端生成配置

## 数据模型

### Novel模型 (`lib/models/novel.dart`)
```dart
class Novel {
  final String title;
  final String author;
  final String url;
  final bool isInBookshelf;
  final String? coverUrl;
  final String? description;
  final String? backgroundSetting;
}
```

### Chapter模型 (`lib/models/chapter.dart`)
```dart
class Chapter {
  final String title;
  final String url;
  final String? content;
  final bool isCached;
  final int? chapterIndex;
  final bool isUserInserted;
}
```

### 其他模型
- **SearchResult**: 搜索结果封装
- **CacheTask**: 缓存任务状态管理

## 数据库设计

### 本地数据库
- **类型**: SQLite
- **版本**: v3
- **位置**: 应用私有目录

### 表结构
1. **bookshelf**: 用户书架
   - 小说元数据、阅读进度
   - 添加时间、最后阅读时间

2. **chapter_cache**: 章节内容缓存
   - 章节内容、索引
   - 缓存时间管理

3. **novel_chapters**: 章节列表元数据
   - 支持用户插入章节 (`isUserInserted`)
   - 章节索引自动管理

### 数据库服务
- **Database Service**: `lib/services/database_service.dart`
  - 单例模式管理
  - 自动迁移支持
  - 事务处理

## 核心功能

### 1. 书架管理
- **Screen**: `bookshelf_screen.dart`
- **功能**: 小说收藏、进度跟踪、批量操作
- **状态**: 本地SQLite存储

### 2. 搜索功能
- **Screen**: `search_screen.dart`
- **Service**: `chapter_search_service.dart`
- **支持**: 跨站点搜索、结果过滤

### 3. 阅读体验
- **Screen**: `reader_screen.dart`
- **功能**: 章节阅读、AI特写、缓存管理
- **特色**: 支持用户插入章节

### 4. 设置管理
- **Screen**: `settings_screen.dart`
- **子页面**:
  - `backend_settings_screen.dart`
  - `dify_settings_screen.dart`
- **存储**: SharedPreferences

## 缓存系统

### 缓存管理器
- **Cache Manager**: `lib/services/cache_manager.dart`
  - 应用生命周期管理
  - 服务端缓存同步
  - 存储空间优化

### 缓存策略
- **章节内容**: 本地SQLite + 服务端PostgreSQL
- **搜索结果**: 内存缓存
- **图片资源**: 文件系统缓存

## AI集成功能

### Dify工作流
- **配置**: URL、Token、提示词
- **模式**: 流式响应 + 阻塞响应
- **用途**: "特写"内容生成

### SSE处理
- **Parser**: `dify_sse_parser.dart`
- **状态管理**: `stream_state_manager.dart`
- **错误处理**: 自动重连机制

## 测试与质量

### 测试文件
- **主测试**: `test/widget_test.dart`
- **E2E测试**: Playwright集成

### 代码质量
- **静态分析**: `flutter analyze`
- **代码格式**: `flutter format`
- **依赖管理**: `flutter pub get`

### 开发工具
- **API生成**: `tool/generate_api.dart`
- **E2E脚本**: `run-e2e-tests.sh`

## 构建与部署

### 构建配置
```bash
# Android
flutter build apk
flutter build appbundle

# Windows
flutter build windows

# iOS (仅macOS)
flutter build ios
```

### 平台支持
- **Android**: 完整支持
- **iOS**: 支持开发(需要macOS)
- **Windows**: 支持开发
- **Web**: 实验性支持

## 常见问题 (FAQ)

### Q: 如何解决API连接失败？
A: 检查后端服务状态和网络配置，在设置页面重新配置API地址。

### Q: 用户插入章节如何保护？
A: 数据库操作中 `isUserInserted=1` 的章节不会被自动删除。

### Q: 如何更新API客户端代码？
A: 运行 `dart run tool/generate_api.dart` 后执行 `flutter pub get`。

## 相关文件清单

### 核心文件
- `lib/main.dart` - 应用入口
- `lib/models/` - 数据模型
- `lib/services/` - 业务服务
- `lib/screens/` - UI界面

### 配置文件
- `pubspec.yaml` - 项目配置
- `analysis_options.yaml` - 代码规范
- `.gitignore` - Git忽略规则

### 工具和脚本
- `tool/generate_api.dart` - API代码生成
- `test/` - 测试文件
- `android/` - Android平台配置

### 构建产物
- `build/` - 构建输出(忽略提交)
- `lib/generated/` - API生成代码(忽略提交)

## 开发工作流

### 新功能开发
1. 创建功能分支
2. 更新相关模型和服务
3. 编写UI界面
4. 添加测试用例
5. 运行代码检查
6. 提交代码审查

### API集成更新
1. 确保后端服务运行
2. 重新生成API客户端
3. 更新API包装器
4. 测试集成功能
5. 验证错误处理

### 数据库变更
1. 更新Database Service
2. 添加迁移逻辑
3. 测试数据兼容性
4. 更新模型定义
5. 验证回滚机制