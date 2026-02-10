[根目录](../../CLAUDE.md) > **novel_app**

# Flutter移动应用模块

## 变更记录 (Changelog)

- **2026-02-04**: 完整更新项目架构文档，反映 Riverpod 状态管理、Repository 模式和数据库 v21
- **2025-11-13**: 模块文档初始化，详细描述应用架构和核心功能

## 模块职责

Flutter移动应用是Novel Builder平台的前端客户端，提供跨平台的小说阅读体验。主要负责：
- 小说搜索与发现
- 本地书架管理
- 离线阅读体验
- AI增强功能（角色聊天、特写生成）
- 大纲管理（全书大纲、章节细纲）
- TTS朗读功能
- 用户偏好设置

## 入口与启动

### 主入口文件
- **路径**: `lib/main.dart`
- **应用类**: `NovelReaderApp`
- **主页**: `HomePage` 底部导航结构

### 应用启动流程
1. **初始化Flutter绑定**: `WidgetsFlutterBinding.ensureInitialized()`
2. **API服务初始化**: `ApiServiceWrapper().init()`
3. **Provider容器初始化**: `ProviderContainer` 创建 Riverpod 容器
4. **Material3主题设置**: 默认暗色主题
5. **底部导航**: 书架、搜索、设置三个标签页

## 项目架构

### 架构层次

```
┌─────────────────────────────────────────────────────────┐
│                    UI Layer (Screens)                    │
│  ConsumerWidget + Riverpod Watch/Read                   │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                  State Management (Providers)            │
│  flutter_riverpod + riverpod_annotation                 │
└─────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────┬──────────────────────────────────┐
│  Controller Layer    │         Repository Layer         │
│  业务逻辑协调         │         数据访问层               │
└──────────────────────┴──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                   Service Layer                          │
│              网络请求、文件操作、业务服务                  │
└─────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────┬──────────────────────────────────┐
│    SQLite Database   │      Backend API Service         │
│   本地数据存储        │        远程数据服务               │
└──────────────────────┴──────────────────────────────────┘
```

### 目录结构

#### lib/ 目录详解

**核心架构目录**:
- `core/` - 核心架构组件
  - `di/` - 依赖注入（API服务Provider）
  - `database/` - 数据库连接和初始化
  - `interfaces/` - 接口定义（IDatabaseConnection等）
  - `providers/` - Riverpod状态管理Providers（50+个文件）
    - `service_providers.dart` - 服务层Provider
    - `repository_providers.dart` - Repository层Provider
    - `reader_screen_providers.dart` - 阅读器状态Provider
    - `bookshelf_providers.dart` - 书架状态Provider
    - `chapter_list_providers.dart` - 章节列表状态Provider
    - `services/` - 各类服务Provider

**业务逻辑层**:
- `controllers/` - 控制器层（8个文件）
  - `pagination_controller.dart` - 分页控制器
  - `reader_content_controller.dart` - 阅读器内容控制器
  - `reader_interaction_controller.dart` - 阅读器交互控制器
  - `chapter_list/` - 章节列表相关控制器
    - `chapter_action_handler.dart` - 章节操作处理器
    - `chapter_reorder_controller.dart` - 章节重排控制器
    - `chapter_loader.dart` - 章节加载器
    - `outline_integration_handler.dart` - 大纲集成处理器

- `repositories/` - 数据访问层（9个Repository类）
  - `base_repository.dart` - Repository基类
  - `novel_repository.dart` - 小说数据访问
  - `chapter_repository.dart` - 章节数据访问
  - `character_repository.dart` - 角色数据访问
  - `character_relation_repository.dart` - 角色关系数据访问
  - `illustration_repository.dart` - 插图数据访问
  - `outline_repository.dart` - 大纲数据访问
  - `chat_scene_repository.dart` - 聊天场景数据访问
  - `bookshelf_repository.dart` - 书架分类数据访问

- `services/` - 业务服务层（45+个文件）
  - `chapter_service.dart` - 章节业务服务
  - `chapter_history_service.dart` - 章节历史服务
  - `chapter_search_service.dart` - 章节搜索服务
  - `character_avatar_service.dart` - 角色头像服务
  - `character_card_service.dart` - 角色卡片服务
  - `tts_service.dart` - TTS朗读服务
  - `tts_player_service.dart` - TTS播放服务
  - `rewrite_service.dart` - 内容改写服务
  - `outline_service.dart` - 大纲业务服务
  - `scene_illustration_service.dart` - 场景插图服务
  - `backup_service.dart` - 备份服务
  - `preferences_service.dart` - 偏好设置服务
  - `theme_service.dart` - 主题服务
  - `database_service.dart` - 数据库服务（@Deprecated，使用Repository Providers）
  - `dify_service.dart` - Dify AI服务
  - `dify_sse_parser.dart` - SSE流式解析器
  - `stream_state_manager.dart` - 流式状态管理器

**UI层**:
- `screens/` - 完整页面界面（25+个Screen）
- `widgets/` - 可复用UI组件（60+个Widget）
- `dialogs/` - 对话框组件（4个对话框）

**辅助层**:
- `models/` - 数据模型（19个Model类）
- `utils/` - 工具类（20+个工具类）
- `constants/` - 常量定义
- `config/` - 配置文件
- `mixins/` - Mixin复用代码（6个Mixin）
- `extensions/` - API扩展方法（3个Extension）

**生成代码**:
- `generated/` - OpenAPI生成的API客户端代码（70+个文件）

## 状态管理架构

### Riverpod状态管理

应用使用 **Riverpod** 作为状态管理方案，而非文档早期版本的Provider。

### 核心依赖

```yaml
dependencies:
  flutter_riverpod: ^2.4.9        # Riverpod核心
  riverpod_annotation: ^2.3.3     # 注解支持
  equatable: ^2.0.5                # 对象比较

dev_dependencies:
  riverpod_generator: ^2.3.9      # 代码生成器
  riverpod_lint: ^2.3.7           # Lint规则
```

### Provider类型

#### 1. Service Providers (`core/providers/service_providers.dart`)

```dart
// 服务单例Providers
final apiServiceProvider = Provider<ApiServiceWrapper>((ref) {
  return ApiServiceWrapper();
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService();
});

final loggerServiceProvider = Provider<LoggerService>((ref) {
  return LoggerService.instance;
});
```

#### 2. Repository Providers (`core/providers/repository_providers.dart`)

```dart
// Repository Providers（通过DatabaseConnection注入）
final databaseConnectionProvider = Provider<IDatabaseConnection>((ref) {
  return DatabaseConnection();
});

final novelRepositoryProvider = Provider<NovelRepository>((ref) {
  final dbConnection = ref.watch(databaseConnectionProvider);
  return NovelRepository(dbConnection: dbConnection);
});

final chapterRepositoryProvider = Provider<ChapterRepository>((ref) {
  final dbConnection = ref.watch(databaseConnectionProvider);
  return ChapterRepository(dbConnection: dbConnection);
});
```

#### 3. StateNotifierProviders（状态管理）

```dart
// 示例：章节列表状态管理
final chapterListProvider = StateNotifierProvider.family<
    ChapterList, ChapterListState, Novel>((ref, novel) {
  return ChapterList(ref, novel);
});

// 使用方式
class ChapterListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chapterListProvider(widget.novel));
    final notifier = ref.read(chapterListProvider(widget.novel).notifier);

    return Scaffold(...);
  }
}
```

### 状态管理模式

- **ConsumerWidget**: 使用 `ref.watch()` 读取状态
- **ConsumerStatefulWidget**: 使用 `ref.watch()` 和 `ref.listen()`
- **StateNotifierProvider**: 可变状态管理
- **Provider**: 不可变服务/依赖
- **FutureProvider**: 异步数据加载
- **StreamProvider**: 流式数据监听

## 对外接口

### API服务层

#### Backend API Service
**文件**: `lib/services/backend_api_service.dart`（已弃用，使用ApiServiceWrapper）

**功能**:
- 搜索小说 (`GET /search`)
- 获取章节列表 (`GET /chapters`)
- 获取章节内容 (`GET /chapter-content`)

#### API Service Wrapper（推荐）
**文件**: `lib/services/api_service_wrapper.dart`

**职责**:
- OpenAPI生成代码的包装器
- 自动初始化和配置
- 统一错误处理
- 认证Token管理

**使用方式**:
```dart
final apiService = ref.watch(apiServiceProvider);
final novels = await apiService.searchNovels(keyword);
```

### AI集成接口

#### Dify Service
**文件**: `lib/services/dify_service.dart`

**功能**:
- 流式AI响应处理
- 特写内容生成
- 角色聊天对话
- 大纲生成辅助

**SSE处理**:
- `lib/services/dify_sse_parser.dart` - SSE流式解析器
- `lib/services/stream_state_manager.dart` - 流式状态管理器
- `lib/mixins/dify_streaming_mixin.dart` - 流式响应Mixin

## 关键依赖与配置

### 核心依赖

#### UI框架与渲染
```yaml
flutter:
  sdk: flutter
flutter_markdown: ^0.6.14    # Markdown渲染
video_player: ^2.8.0          # 视频播放
visibility_detector: ^0.4.0+2 # 可见性检测
```

#### 状态管理
```yaml
flutter_riverpod: ^2.4.9      # Riverpod状态管理
riverpod_annotation: ^2.3.3   # Riverpod注解
equatable: ^2.0.5             # 对象比较
```

#### 网络请求
```yaml
http: ^1.1.0                  # HTTP客户端
dio: ^5.4.0                   # Dio HTTP客户端
```

#### 数据序列化
```yaml
built_value: ^8.9.0           # 不可变值类型
built_collection: ^5.1.1      # 不可变集合
json_annotation: ^4.8.0       # JSON注解
```

#### 数据库与存储
```yaml
sqflite: ^2.3.0               # SQLite数据库
path_provider: ^2.1.1         # 文件路径
shared_preferences: ^2.2.2    # 键值存储
```

#### HTML解析
```yaml
html: ^0.15.4                 # HTML解析
```

#### 图片与媒体
```yaml
image_cropper: ^8.0.2         # 图片裁剪
```

#### 应用功能
```yaml
fluttertoast: ^8.2.4          # Toast消息
background_downloader: ^8.0.0 # 后台下载
permission_handler: ^11.0.0   # 权限请求
package_info_plus: ^8.0.0     # 包信息
```

#### 图可视化
```yaml
flutter_force_directed_graph: ^1.0.8  # 力导向图
```

#### 加密工具
```yaml
crypto: ^3.0.7                # 加密算法
```

#### OpenAPI生成代码
```yaml
novel_api:
  path: generated/api         # 本地路径依赖
```

### 开发工具依赖

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter

  # Lint规则
  flutter_lints: ^5.0.0

  # 测试依赖
  sqflite_common_ffi: ^2.3.0  # 桌面平台SQLite
  mockito: ^5.4.0             # Mock框架
  coverage: ^1.6.0            # 代码覆盖率
  integration_test:
    sdk: flutter              # 集成测试

  # 代码生成
  build_runner: ^2.4.7        # 代码生成工具
  json_serializable: ^6.7.0   # JSON序列化生成
  built_value_generator: ^8.9.0  # built_value生成

  # Riverpod代码生成
  riverpod_generator: ^2.3.9  # Provider生成器
  riverpod_lint: ^2.3.7       # Riverpod Lint
```

### 配置文件

- **pubspec.yaml** - 项目依赖和配置
- **analysis_options.yaml** - 代码分析配置
- **openapi-config.yaml** - API客户端生成配置
- **dart_test.yaml** - Dart测试配置
- **coverage_config.yaml** - 覆盖率配置

## 数据模型

### Novel模型
**文件**: `lib/models/novel.dart`

```dart
class Novel {
  final String title;              // 小说标题
  final String author;             // 作者
  final String url;                // 小说URL（唯一标识）
  final bool isInBookshelf;        // 是否在书架
  final String? coverUrl;          // 封面URL
  final String? description;       // 简介
  final String? backgroundSetting; // 背景设定
}
```

### Chapter模型
**文件**: `lib/models/chapter.dart`

```dart
class Chapter {
  final String title;          // 章节标题
  final String url;            // 章节URL
  final String? content;       // 章节内容
  final bool isCached;         // 是否已缓存
  final int? chapterIndex;     // 章节索引
  final bool isUserInserted;   // 是否用户插入
  final int? readAt;           // 阅读时间戳
  final bool isAccompanied;    // 是否有AI特写

  /// 是否已读
  bool get isRead => readAt != null;
}
```

### Character模型
**文件**: `lib/models/character.dart`

角色数据模型，支持角色管理和多角色聊天。

### SceneIllustration模型
**文件**: `lib/models/scene_illustration.dart`

场景插图模型，用于AI生成的场景图片管理。

### Outline模型
**文件**: `lib/models/outline.dart`

```dart
class Outline {
  final int? id;
  final String novelUrl;       // 关联小说URL
  final String title;          // 大纲标题
  final String content;        // 大纲内容（JSON/Markdown）
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ChapterOutlineDraft {
  final String title;          // 章节细纲标题
  final String content;        // 章节细纲内容
  final List<String> keyPoints; // 关键点列表
}
```

### ChatScene模型
**文件**: `lib/models/chat_scene.dart`

聊天场景模型，用于角色对话场景管理。

### CharacterRelationship模型
**文件**: `lib/models/character_relationship.dart`

角色关系模型，支持人物关系图可视化。

### AI模型

#### AIAccompanimentSettings
**文件**: `lib/models/ai_accompaniment_settings.dart`

AI特写设置（API配置、提示词等）。

#### AICompanionResponse
**文件**: `lib/models/ai_companion_response.dart`

AI伴侣响应模型。

### 其他模型

- **SearchResult** - 搜索结果封装
- **Bookshelf** - 书架分类模型（id, name, icon, color）
- **ChatMessage** - 聊天消息模型
- **RoleGallery** - 角色画廊模型
- **TTSTimerConfig** - TTS定时器配置
- **AppVersion** - 应用版本信息

## 数据库设计

### 本地数据库

- **类型**: SQLite
- **版本**: v21
- **文件名**: novel_reader.db
- **位置**: 应用私有目录（通过`path_provider`获取）

### 表结构

#### 重要命名说明

- `bookshelf` 表：物理表，存储小说元数据（历史遗留命名）
- `novels` 视图：bookshelf表的别名视图，提供更清晰的语义
- `bookshelves` 表：书架分类表（注意复数形式）
- `Bookshelf` 模型：书架分类功能（id, name, icon, color）

#### 物理表列表

1. **bookshelf** (小说表)
   - 存储小说元数据、阅读进度
   - 字段：id, title, author, url, cover_url, description, background_setting
   - 索引：url（唯一）、last_read_at、is_in_bookshelf

2. **bookshelves** (书架分类表)
   - 书架分类功能（如"我的收藏"、"玄幻小说"）
   - 字段：id, name, icon, color, created_at

3. **novel_bookshelves** (小说-书架关联表)
   - 多对多关系表
   - 字段：novel_url, bookshelf_id
   - 支持一本小说属于多个书架

4. **chapter_cache** (章节内容缓存)
   - 章节内容、索引、缓存时间
   - 字段：id, novel_url, chapter_url, title, content, chapter_index, cached_at
   - 特性：支持 `isUserInserted` 章节保护

5. **novel_chapters** (章节列表元数据)
   - 章节索引自动管理
   - 字段：id, novel_url, title, url, chapter_index, is_user_inserted, read_at, is_accompanied

6. **characters** (角色表)
   - 角色基本信息和头像
   - 字段：id, novel_url, name, avatar_url, description

7. **character_relationships** (角色关系表)
   - 人物关系图数据
   - 字段：id, novel_url, character1_name, character2_name, relationship_type

8. **scene_illustrations** (场景插图表)
   - AI生成的场景插图
   - 字段：id, novel_url, chapter_url, scene_description, image_url, created_at

9. **outlines** (大纲表)
   - 小说全书大纲
   - 字段：id, novel_url, title, content, created_at, updated_at

10. **chat_scenes** (聊天场景表)
    - 角色对话场景
    - 字段：id, title, characters_json, created_at

#### 逻辑视图

- **novels**: bookshelf表的别名视图
  - 推荐新代码使用此视图进行查询
  - 保持数据兼容性

### 数据库连接

**接口**: `lib/core/interfaces/i_database_connection.dart`

**实现**: `lib/core/database/database_connection.dart`

```dart
class DatabaseConnection implements IDatabaseConnection {
  @override
  Future<Database> get database async {
    // 单例模式，返回SQLite实例
    // 版本: v21
    // onCreate: 创建所有表
    // onUpgrade: 执行数据库迁移
  }
}
```

### Repository模式

**架构说明**:

DatabaseService 现在作为门面类（Facade），将所有数据库操作委托给专门的Repository类：

#### Repository层列表

**文件**: `lib/repositories/`

1. **base_repository.dart** - Repository基类
   - 定义通用数据库操作接口
   - 提供事务处理方法

2. **novel_repository.dart** - 小说Repository
   - CRUD操作
   - 阅读进度更新
   - 书架状态管理

3. **chapter_repository.dart** - 章节Repository
   - 章节缓存管理
   - 章节列表维护
   - 用户插入章节保护

4. **character_repository.dart** - 角色Repository
   - 角色信息管理
   - 角色头像存储

5. **character_relation_repository.dart** - 角色关系Repository
   - 关系图数据管理
   - 关系查询和更新

6. **illustration_repository.dart** - 插图Repository
   - 场景插图缓存
   - 图片URL管理

7. **outline_repository.dart** - 大纲Repository
   - 全书大纲CRUD
   - 大纲版本管理

8. **chat_scene_repository.dart** - 聊天场景Repository
   - 对话场景管理
   - 多角色对话历史

9. **bookshelf_repository.dart** - 书架分类Repository
   - 书架分类CRUD
   - 小说-书架关联管理

#### 使用方式

**推荐方式（Riverpod Providers）**:
```dart
class NovelListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(novelRepositoryProvider);

    return FutureBuilder(
      future: repository.getNovelsInBookshelf(),
      builder: (context, snapshot) {
        // ...
      },
    );
  }
}
```

**兼容方式（@Deprecated）**:
```dart
// ⚠️ 已弃用，建议使用Repository Providers
final databaseService = DatabaseService();
final novels = await databaseService.novelRepository.getNovelsInBookshelf();
```

### 数据库服务

**文件**: `lib/services/database_service.dart`

**职责**:
- 管理数据库连接和初始化
- 提供统一的对外接口（向后兼容）
- 协调各个Repository的数据库实例
- 处理数据库迁移

**状态**: @Deprecated - 新代码应该直接使用Repository Providers

## 核心功能

### 1. 书架管理

**Screen**: `lib/screens/bookshelf_screen.dart`

**功能**:
- 小说收藏与管理
- 阅读进度跟踪
- 书架分类（多个书架）
- 批量操作（删除、移动）

**状态管理**: `core/providers/bookshelf_providers.dart`

**数据存储**: 本地SQLite

### 2. 搜索功能

**Screen**: `lib/screens/search_screen.dart`

**Service**:
- `chapter_search_service.dart` - 章节搜索
- `cache_search_service.dart` - 缓存搜索

**Provider**: `core/providers/search_screen_providers.dart`

**支持**: 跨站点搜索、结果过滤、搜索历史

### 3. 章节列表

**Screen**: `lib/screens/chapter_list_screen_riverpod.dart`

**Controller**:
- `chapter_list/chapter_action_handler.dart` - 章节操作
- `chapter_list/chapter_reorder_controller.dart` - 章节重排
- `chapter_list/chapter_loader.dart` - 章节加载
- `chapter_list/outline_integration_handler.dart` - 大纲集成

**Provider**: `core/providers/chapter_list_providers.dart`

**功能**:
- 章节列表展示（分页，每页100章）
- 自动滚动到上次阅读位置
- 章节重排序
- 大纲集成显示
- 章节搜索和过滤

**Bug修复**:
- ✅ 异步加载时序问题已修复（使用-1作为未加载默认值）

### 4. 阅读体验

**Screen**: `lib/screens/reader_screen.dart`

**Controller**:
- `reader_content_controller.dart` - 内容管理
- `reader_interaction_controller.dart` - 交互处理

**Provider**: `core/providers/reader_screen_providers.dart`

**功能**:
- 章节阅读（段落式渲染）
- AI特写生成
- 场景插图请求
- TTS朗读
- 阅读进度自动保存
- 编辑模式（段落改写、删除）

**特色**:
- 支持用户插入章节保护
- 自动滚动控制（`mixins/reader/auto_scroll_mixin.dart`）
- 流式AI响应显示

### 5. 角色管理

**Screens**:
- `character_management_screen.dart` - 角色列表
- `character_edit_screen.dart` - 角色编辑
- `character_chat_screen.dart` - 单角色聊天
- `multi_role_chat_screen.dart` - 多角色聊天
- `character_relationship_screen.dart` - 关系图

**Repository**: `character_repository.dart`, `character_relation_repository.dart`

**功能**:
- 角色信息管理
- 角色头像（AI生成/自定义）
- 角色关系可视化（力导向图）
- 多角色对话

### 6. 大纲管理

**Screens**:
- `outline/create_outline_screen.dart` - 创建大纲
- `outline/outline_management_screen.dart` - 大纲管理

**Repository**: `outline_repository.dart`

**功能**:
- 全书大纲生成（AI辅助）
- 章节细纲草稿
- 大纲与章节集成

### 7. 设置管理

**Screen**: `lib/screens/settings_screen.dart`

**子页面**:
- `backend_settings_screen.dart` - 后端API配置
- `dify_settings_screen.dart` - Dify AI配置

**存储**: SharedPreferences

**功能**:
- API地址配置
- Dify工作流配置
- 阅读设置（字体、字号、行间距）
- 主题设置

### 8. TTS朗读

**Screen**: `lib/screens/tts_player_screen.dart`

**Service**:
- `tts_service.dart` - TTS引擎
- `tts_player_service.dart` - 播放控制

**功能**:
- 章节朗读
- 语速调节
- 定时关闭
- 后台播放

### 9. 插图管理

**Screen**: `lib/screens/illustration_debug_screen.dart`

**Service**:
- `scene_illustration_service.dart` - 插图业务服务
- `scene_illustration_cache_service.dart` - 插图缓存服务

**Repository**: `illustration_repository.dart`

**功能**:
- AI场景插图生成
- 插图缓存管理
- 插图与章节关联

### 10. 备份与恢复

**Service**: `lib/services/backup_service.dart`

**功能**:
- 数据库备份
- 恢复功能
- 备份文件管理

## 缓存系统

### 章节内容缓存

**本地SQLite**:
- 表：`chapter_cache`, `novel_chapters`
- Repository: `ChapterRepository`
- 特性：支持用户插入章节保护

**服务端PostgreSQL**:
- API: `POST /api/cache/create`
- 查询: `GET /api/cache/status/{task_id}`

### 缓存策略

- **章节内容**: 本地SQLite + 服务端PostgreSQL双缓存
- **搜索结果**: 内存缓存
- **图片资源**: 文件系统缓存（`utils/image_cache_manager.dart`）
- **视频资源**: 文件系统缓存（`utils/video_cache_manager.dart`）

### 缓存相关服务

- `chapter_service.dart` - 章节缓存协调
- `chapter_manager.dart` - 章节管理器（已弃用）
- `preload_service.dart` - 预加载服务

## AI集成功能

### Dify工作流集成

**Service**: `lib/services/dify_service.dart`

**配置**:
- URL: Dify工作流API地址
- Token: API认证Token
- 提示词模板

**模式**:
- **流式响应**: SSE协议，实时生成
- **阻塞响应**: 等待完整结果

**用途**:
- "特写"内容生成（场景描述、细节补充）
- 角色对话
- 大纲生成辅助

### SSE处理

**Parser**: `lib/services/dify_sse_parser.dart`
- 解析SSE流式数据
- 事件处理（message, end, error）

**状态管理**: `lib/services/stream_state_manager.dart`
- 流式状态追踪
- 连接状态管理

**Mixin**: `lib/mixins/dify_streaming_mixin.dart`
- 流式响应处理复用
- 错误处理和重连

### AI相关Widget

- `widgets/streaming_content_display.dart` - 流式内容显示
- `widgets/streaming_status_indicator.dart` - 状态指示器
- `widgets/reader/ai_companion_confirm_dialog.dart` - AI特写确认对话框
- `widgets/illustration_request_dialog.dart` - 插图请求对话框
- `widgets/illustration_action_dialog.dart` - 插图操作对话框

## 控制器层

### Controller职责

Controller负责协调业务逻辑，连接UI层和数据层。

### Controller列表

**文件位置**: `lib/controllers/`

1. **pagination_controller.dart** - 分页控制器
   - 通用分页逻辑
   - 加载状态管理
   - 支持下拉刷新和上拉加载

2. **reader_content_controller.dart** - 阅读器内容控制器
   - 章节内容管理
   - 段落渲染控制
   - 编辑模式切换

3. **reader_interaction_controller.dart** - 阅读器交互控制器
   - 用户交互处理
   - AI功能触发
   - 手势控制

4. **chapter_list/chapter_action_handler.dart** - 章节操作处理器
   - 章节删除、缓存等操作
   - 批量操作支持

5. **chapter_list/chapter_reorder_controller.dart** - 章节重排控制器
   - 拖拽重排序
   - 重排序状态管理

6. **chapter_list/chapter_loader.dart** - 章节加载器
   - 章节列表加载
   - 最后阅读位置加载

7. **chapter_list/outline_integration_handler.dart** - 大纲集成处理器
   - 大纲数据集成
   - 章节细纲显示

## Mixins

### Mixin列表

**文件位置**: `lib/mixins/`

1. **dify_streaming_mixin.dart** - Dify流式响应Mixin
   - SSE流式处理
   - 状态更新

2. **loading_state_mixin.dart** - 加载状态Mixin
   - 统一加载状态管理

3. **reader/auto_scroll_mixin.dart** - 阅读器自动滚动Mixin
   - 自动滚动控制
   - 滚动速度调节

4. **stream_subscription_mixin.dart** - 流订阅Mixin
   - Stream生命周期管理

5. **text_editing_controller_mixin.dart** - 文本编辑器Mixin
   - TextEditingController管理

## 扩展方法

### API扩展

**文件位置**: `lib/extensions/`

1. **api_novel_extension.dart** - Novel模型扩展
   - API Novel → 本地Novel转换
   - 便捷构造方法

2. **api_chapter_extension.dart** - Chapter模型扩展
   - API Chapter → 本地Chapter转换
   - 缓存状态判断

3. **api_source_site_extension.dart** - 源站点扩展
   - 站点信息处理

## 测试与质量

### 测试结构

**test/** 目录:

```
test/
├── helpers/              # 测试辅助工具
├── mocks/               # Mock对象
├── factories/           # 测试数据工厂
├── unit/                # 单元测试
│   ├── repositories/    # Repository测试
│   ├── services/        # Service测试
│   ├── providers/       # Provider测试
│   ├── screens/         # Screen测试
│   └── widgets/         # Widget测试
├── bug/                 # Bug修复验证测试
├── verification/        # 功能验证测试
├── experiments/         # 实验性测试
└── reports/             # 测试报告
```

### 主要测试文件

- `test/widget_test.dart` - 主测试文件
- `test/unit/screens/chapter_list_auto_scroll_test.dart` - 自动滚动测试（23个用例）
- `test/unit/screens/chapter_list_scroll_bug_verification_test.dart` - Bug验证测试（7个用例）

### 测试配置

- `dart_test.yaml` - Dart测试配置
- `coverage_config.yaml` - 覆盖率配置
- `playwright.config.ts` - E2E测试配置（Playwright集成）

### 代码质量

**静态分析**:
```bash
flutter analyze                    # 代码分析
flutter analyze --no-fatal-infos   # 严格模式
```

**代码格式化**:
```bash
flutter format lib/                # 格式化代码
flutter format --set-exit-if-changed lib/  # CI检查
```

**依赖管理**:
```bash
flutter pub get                    # 获取依赖
flutter pub upgrade               # 升级依赖
flutter pub outdated              # 检查过时依赖
```

### 开发工具

**API生成**:
```bash
# 生成OpenAPI客户端代码
dart run tool/generate_api.dart
flutter pub get
```

**数据库工具**:
```bash
# 清理测试数据库
dart run tool/clean_test_database.dart

# 强制重建数据库
dart run tool/run tool/force_rebuild_database.dart
```

**Python迁移脚本**:
- `tool/migrate_database_log.py` - 数据库日志迁移
- `tool/migrate_dify_log.py` - Dify日志迁移
- `tool/migrate_api_log.py` - API日志迁移
- `tool/fix_logger_calls.py` - 修复Logger调用
- `tool/fix_screen_toast_calls.py` - 修复Screen Toast调用
- `tool/extract_repository.py` - 提取Repository代码
- `tool/fix_import_paths.py` - 修复导入路径

## 构建与部署

### 构建配置

```bash
# Android
flutter build apk                              # APK调试版
flutter build apk --release                    # APK发布版
flutter build appbundle --release              # App Bundle（Google Play）

# Windows
flutter build windows                          # Windows可执行文件

# iOS (仅macOS)
flutter build ios                              # iOS应用
flutter build ios --release                    # iOS发布版

# Web（实验性）
flutter build web                              # Web应用
```

### 平台支持

| 平台 | 支持状态 | 说明 |
|------|---------|------|
| Android | ✅ 完整支持 | APK + App Bundle |
| iOS | ✅ 支持开发 | 需要macOS开发环境 |
| Windows | ✅ 支持开发 | 桌面应用（SQLite FFI） |
| Web | ⚠️ 实验性 | sqflite不支持，需替代方案 |

### 版本管理

**当前版本**: 1.3.9+28

**版本号规则**: `major.minor.patch+build`

## 常见问题 (FAQ)

### Q: 如何解决API连接失败？

**A**: 检查以下项目：
1. 后端服务是否运行（`http://localhost:3800`）
2. 在设置页面重新配置API地址
3. 检查API Token是否正确
4. 查看日志：`lib/screens/log_viewer_screen.dart`

### Q: 用户插入章节如何保护？

**A**: 数据库操作中 `isUserInserted=1` 的章节：
- 不会被自动删除
- 不会被爬虫更新
- 保留用户编辑内容

### Q: 如何更新API客户端代码？

**A**:
```bash
# 1. 确保后端服务运行
# 2. 运行生成工具
dart run tool/generate_api.dart

# 3. 更新依赖
flutter pub get

# 4. 验证生成代码
flutter analyze lib/generated/api/
```

### Q: Riverpod vs Provider，应该用哪个？

**A**: **使用Riverpod**。
- ✅ 项目已迁移到Riverpod（`flutter_riverpod: ^2.4.9`）
- ❌ Provider已弃用（`pubspec.yaml`中已注释）
- 使用 `ConsumerWidget` + `ref.watch()`
- 查看 `lib/core/providers/` 了解Provider定义

### Q: 如何添加新的Repository？

**A**:
1. 创建 `lib/repositories/your_repository.dart`
2. 继承 `BaseRepository`
3. 注入 `IDatabaseConnection`
4. 在 `lib/core/providers/repository_providers.dart` 中添加Provider
5. 使用 `ref.watch(yourRepositoryProvider)` 访问

### Q: 数据库版本如何升级？

**A**:
1. 修改 `lib/core/database/database_connection.dart` 中的版本号
2. 在 `_onUpgrade()` 方法中添加迁移逻辑
3. 测试数据库迁移
4. 更新文档中的版本号

## 相关文件清单

### 核心文件

**应用入口**:
- `lib/main.dart` - 应用入口

**架构层**:
- `lib/core/providers/` - Riverpod状态管理（50+个文件）
- `lib/repositories/` - 数据访问层（9个Repository）
- `lib/controllers/` - 控制器层（8个Controller）
- `lib/services/` - 业务服务层（45+个Service）

**UI层**:
- `lib/screens/` - 完整页面（25+个Screen）
- `lib/widgets/` - UI组件（60+个Widget）
- `lib/dialogs/` - 对话框（4个Dialog）

**数据层**:
- `lib/models/` - 数据模型（19个Model）
- `lib/core/database/` - 数据库连接
- `lib/core/interfaces/` - 接口定义

**工具层**:
- `lib/utils/` - 工具类（20+个工具）
- `lib/constants/` - 常量定义
- `lib/config/` - 配置文件

**复用代码**:
- `lib/mixins/` - Mixin（6个）
- `lib/extensions/` - 扩展方法（3个）

### 配置文件

- `pubspec.yaml` - 项目配置和依赖
- `analysis_options.yaml` - 代码分析规则
- `.gitignore` - Git忽略规则
- `dart_test.yaml` - Dart测试配置
- `coverage_config.yaml` - 覆盖率配置
- `openapi-config.yaml` - API生成配置

### 工具和脚本

**Dart工具**:
- `tool/generate_api.dart` - API代码生成
- `tool/clean_test_database.dart` - 清理测试数据库
- `tool/force_rebuild_database.dart` - 重建数据库

**Python脚本**:
- `tool/migrate_database_log.py` - 数据库日志迁移
- `tool/migrate_dify_log.py` - Dify日志迁移
- `tool/migrate_api_log.py` - API日志迁移
- `tool/fix_logger_calls.py` - 修复Logger调用
- `tool/fix_screen_toast_calls.py` - 修复Toast调用
- `tool/extract_repository.py` - 提取Repository
- `tool/fix_import_paths.py` - 修复导入路径

**Shell脚本**:
- `tool/fix_logger_error_param.sh` - 修复Logger错误参数

### 测试文件

- `test/widget_test.dart` - 主测试文件
- `test/helpers/` - 测试辅助工具
- `test/mocks/` - Mock对象
- `test/factories/` - 测试数据工厂
- `test/unit/` - 单元测试（repositories, services, providers, screens, widgets）
- `test/bug/` - Bug修复验证
- `test/verification/` - 功能验证
- `test/reports/` - 测试报告

### 构建产物

- `build/` - 构建输出（忽略提交）
- `lib/generated/` - API生成代码（忽略提交）

### 平台配置

- `android/` - Android平台配置
- `windows/` - Windows平台配置
- `ios/` - iOS平台配置
- `web/` - Web平台配置

## 开发工作流

### 新功能开发

1. **创建功能分支**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **更新数据模型**（如需要）
   - 修改/创建 `lib/models/your_model.dart`
   - 运行 `dart run build_runner build` 生成代码

3. **创建Repository**（如需要）
   - 创建 `lib/repositories/your_repository.dart`
   - 继承 `BaseRepository`
   - 在 `repository_providers.dart` 中注册Provider

4. **创建Service**（如需要）
   - 创建 `lib/services/your_service.dart`
   - 在 `service_providers.dart` 中注册Provider

5. **创建Controller**（如需要）
   - 创建 `lib/controllers/your_controller.dart`
   - 协调业务逻辑

6. **编写UI界面**
   - 创建 `lib/screens/your_screen.dart`
   - 使用 `ConsumerWidget` 或 `ConsumerStatefulWidget`
   - 使用 `ref.watch()` 读取状态
   - 使用 `ref.read()` 调用方法

7. **添加测试用例**
   - 单元测试：`test/unit/your_test.dart`
   - Widget测试：`test/widgets/your_widget_test.dart`
   - 运行 `flutter test`

8. **运行代码检查**
   ```bash
   flutter analyze
   flutter format lib/
   flutter test
   ```

9. **提交代码审查**
   ```bash
   git add .
   git commit -m "feat: add your feature"
   git push origin feature/your-feature-name
   ```

### API集成更新

1. **确保后端服务运行**
   ```bash
   # 启动后端服务
   cd ../backend
   python -m uvicorn app.main:app --reload
   ```

2. **重新生成API客户端**
   ```bash
   dart run tool/generate_api.dart
   flutter pub get
   ```

3. **更新API包装器**（如需要）
   - 修改 `lib/services/api_service_wrapper.dart`
   - 适配新的API变更

4. **添加扩展方法**（如需要）
   - 修改 `lib/extensions/api_xxx_extension.dart`
   - 方便API模型转换

5. **测试集成功能**
   - 单元测试：Mock API响应
   - 集成测试：连接真实API
   - E2E测试：Playwright自动化

6. **验证错误处理**
   - 网络错误
   - API错误响应
   - 数据解析错误

### 数据库变更

1. **更新Repository**
   - 修改对应的Repository类
   - 添加新方法或字段

2. **添加迁移逻辑**
   ```dart
   // lib/core/database/database_connection.dart
   Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
     if (oldVersion < 22) {
       // 添加新表或修改表结构
       await db.execute('ALTER TABLE xxx ADD COLUMN yyy TEXT');
     }
   }
   ```

3. **更新数据库版本**
   ```dart
   version: 22, // 增加版本号
   ```

4. **测试数据兼容性**
   - 测试从旧版本升级
   - 验证数据迁移正确性

5. **更新模型定义**
   - 修改 `lib/models/your_model.dart`
   - 确保与数据库表结构匹配

6. **验证回滚机制**
   - 测试降级场景
   - 确保不丢失数据

### Riverpod Provider开发

1. **定义状态类**
   ```dart
   class YourState {
     final bool isLoading;
     final List<Item> items;
     final String? error;

     const YourState({
       this.isLoading = false,
       this.items = const [],
       this.error,
     });

     YourState copyWith({...}) => ...;
   }
   ```

2. **创建StateNotifier**
   ```dart
   class YourNotifier extends StateNotifier<YourState> {
     YourNotifier(this.ref) : super(const YourState());

     final Ref ref;

     Future<void> loadData() async {
       state = state.copyWith(isLoading: true);
       try {
         final repository = ref.watch(yourRepositoryProvider);
         final items = await repository.getItems();
         state = state.copyWith(items: items, isLoading: false);
       } catch (e) {
         state = state.copyWith(error: e.toString(), isLoading: false);
       }
     }
   }
   ```

3. **创建Provider**
   ```dart
   final yourProvider = StateNotifierProvider.family<YourNotifier, YourState, String>(
     (ref, id) => YourNotifier(ref),
   );
   ```

4. **使用Provider**
   ```dart
   class YourScreen extends ConsumerWidget {
     @override
     Widget build(BuildContext context, WidgetRef ref) {
       final state = ref.watch(yourProvider('id'));
       final notifier = ref.read(yourProvider('id').notifier);

       return Scaffold(
         body: state.isLoading
           ? CircularProgressIndicator()
           : ListView.builder(
               itemCount: state.items.length,
               itemBuilder: (context, index) => ...,
             ),
       );
     }
   }
   ```

5. **生成代码**（使用注解时）
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

### Bug修复流程

1. **创建Bug分支**
   ```bash
   git checkout -b fix/bug-name
   ```

2. **编写测试用例**
   - 在 `test/bug/` 中创建复现测试
   - 在 `test/unit/` 中编写修复验证测试

3. **修复Bug**
   - 修改相关代码
   - 运行测试验证

4. **更新文档**（如需要）
   - 在 `test/reports/` 中添加Bug报告
   - 更新CLAUDE.md

5. **提交修复**
   ```bash
   git add .
   git commit -m "fix: resolve bug-name"
   git push origin fix/bug-name
   ```

## 架构演进历史

### Phase 1: 初始架构
- Provider状态管理
- DatabaseService单例
- 紧耦合的Service层

### Phase 2: 代码质量改进（当前）
- ✅ 迁移到Riverpod状态管理
- ✅ 引入Repository模式
- ✅ DatabaseConnection接口化
- ✅ Controller层解耦
- ✅ 依赖注入通过Providers

### 未来计划
- 添加更多集成测试
- 优化性能和内存使用
- 增强错误处理和日志
- 改进离线功能

## 参考资源

### 官方文档
- [Flutter Documentation](https://flutter.dev/docs)
- [Riverpod Documentation](https://riverpod.dev)
- [sqflite Documentation](https://pub.dev/packages/sqflite)

### 内部文档
- 根目录CLAUDE.md - 项目总览
- backend/CLAUDE.md - 后端服务文档

### 测试报告
- `test/reports/chapter_list_auto_scroll_test_report.md` - 自动滚动测试报告
- `test/reports/chapter_list_scroll_bug_report.md` - Bug分析报告

---

**文档维护**: 本文档应随代码变更同步更新
**最后更新**: 2026-02-04
**文档状态**: ✅ 已验证
