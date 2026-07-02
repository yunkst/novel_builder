# Novel Builder 开发者指南

本指南面向希望为 Novel Builder 贡献代码或自部署的开发者。涵盖项目架构、开发环境搭建、扩展开发等主题。

## 🏗️ 架构总览

Novel Builder 采用 monorepo 架构，包含两个主要模块：

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Flutter App   │ ←─→ │   FastAPI 后端  │ ←─→ │   PostgreSQL    │
│   (novel_app)   │     │    (backend)    │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │
        │                       ├── Scrapling 爬虫 (9 站点)
        │                       ├── ComfyUI (图片/视频生成)
        │                       └── Agent (LLM 对话)
        │
        └── SQLite 本地缓存
```

### 数据流

1. **用户搜索** → Flutter App → FastAPI → 多个 Scrapling 爬虫 → 聚合结果
2. **阅读章节** → Flutter App → FastAPI → 爬虫/缓存 → 内容返回
3. **AI 功能** → Flutter App (DSL Engine 本地执行) → OpenAI 兼容 LLM API
4. **场景插图** → Flutter App → FastAPI → ComfyUI → 图片下载/缓存

---

## 💻 开发环境搭建

### 前置要求

| 工具 | 版本 | 用途 |
|------|------|------|
| Flutter SDK | 3.0+ | 移动应用开发 |
| Dart SDK | 3.0+ | Flutter 依赖 |
| Python | 3.11+ | 后端开发 |
| Docker | 20.10+ | 容器化部署 |
| Docker Compose | 2.0+ | 多服务编排 |
| PostgreSQL | 15+ | 后端数据库 |
| Git | 2.30+ | 版本控制 |
| Node.js | 18+ | API 代码生成工具 |

### 克隆项目

```bash
git clone https://github.com/yunkst/novel_builder.git
cd novel_builder
git remote add upstream https://github.com/yunkst/novel_builder.git
```

### 后端开发环境

#### 方式 1：Docker Compose（推荐）

```bash
# 启动数据库和后端服务
docker-compose up -d postgres backend

# 查看日志
docker-compose logs -f backend
```

#### 方式 2：本地虚拟环境

```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate

# 安装依赖（含开发工具）
pip install -e ".[dev]"

# 启动开发服务器
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

#### 数据库迁移

```bash
cd backend
alembic upgrade head        # 应用所有迁移
alembic revision --autogenerate -m "描述"   # 生成新迁移
```

### 前端开发环境

```bash
cd novel_app
flutter pub get

# 生成 Riverpod Provider 代码
dart run build_runner build --delete-conflicting-outputs

# 运行应用（自动选择连接的设备）
flutter run

# 仅在特定平台运行
flutter run -d android
flutter run -d chrome
```

### OpenAPI 客户端代码生成

后端启动后，运行以下命令重新生成 Dart API 客户端：

```bash
cd novel_app
dart run tool/generate_api.dart
```

---

## 📁 项目结构

### 根目录

```
novel_builder/
├── novel_app/          # Flutter 移动应用
├── backend/            # Python FastAPI 后端
├── docs/               # 项目文档
├── docker-compose.yml  # Docker 编排
├── .github/            # GitHub Actions CI/CD
├── .env.example        # 环境变量模板
├── README.md           # 项目说明
├── CHANGELOG.md        # 变更日志
├── CONTRIBUTING.md     # 贡献指南
├── LICENSE             # MIT 许可证
└── CLAUDE.md           # AI 上下文文档
```

### novel_app/ 详细结构

```
novel_app/
├── lib/
│   ├── main.dart               # 应用入口
│   ├── core/                   # 核心基础设施
│   │   ├── di/                 # 依赖注入
│   │   ├── database/           # SQLite 数据库
│   │   ├── interfaces/         # 抽象接口
│   │   └── providers/          # Riverpod Provider（50+）
│   ├── controllers/            # 控制器层
│   ├── repositories/           # 数据仓库层（9 个）
│   ├── services/               # 业务服务
│   │   ├── dsl_engine/         # DSL Engine 核心
│   │   ├── dify/               # Dify Facade
│   │   ├── novel_agent/        # Agent Chat 引擎
│   │   └── api_service_*.dart  # API 客户端
│   ├── screens/                # 页面组件
│   ├── widgets/                # 可复用组件
│   ├── dialogs/                # 对话框
│   ├── models/                 # 数据模型
│   ├── utils/                  # 工具函数
│   ├── mixins/                 # 混入类
│   ├── extensions/             # 扩展方法
│   └── generated/              # OpenAPI 自动生成代码
├── assets/
│   ├── dsl/                    # DSL 工作流定义（YAML）
│   └── images/                 # 应用图标等
├── android/                    # Android 平台
├── ios/                        # iOS 平台
├── test/                       # 测试代码
└── CLAUDE.md                   # 模块文档
```

### backend/ 详细结构

```
backend/
├── app/
│   ├── main.py                 # FastAPI 应用入口
│   ├── config.py               # 配置管理
│   ├── database.py             # 数据库连接
│   ├── exceptions.py           # 自定义异常
│   ├── logging_config.py       # 日志配置
│   ├── constants.py            # 常量定义
│   ├── api/
│   │   └── routes/             # 路由模块
│   │       ├── backup.py       # 备份 API
│   │       ├── novel_sync.py   # 小说同步
│   │       └── logs.py         # 日志查询
│   ├── deps/                   # FastAPI 依赖
│   ├── models/                 # SQLAlchemy 模型
│   ├── schemas/                # Pydantic 模式
│   └── services/               # 业务服务
│       ├── crawler_factory.py  # 爬虫工厂
│       ├── base_crawler.py     # 爬虫基类
│       ├── scrapling_*.py      # Scrapling 引擎
│       ├── *_crawler.py        # 9 个站点爬虫
│       ├── cache_*.py          # 缓存系统
│       ├── dify_client.py      # Dify 客户端
│       ├── comfyui_*.py        # ComfyUI 客户端
│       └── *.py                # 其他服务
├── alembic/                    # 数据库迁移
├── tests/                      # 测试
└── CLAUDE.md                   # 模块文档
```

---

## 🎨 前端架构

### 状态管理：Riverpod

Novel App 完全采用 [Riverpod](https://riverpod.dev/) 进行状态管理：

```dart
// Service Provider 示例
@Riverpod(keepAlive: true)
ApiServiceWrapper apiServiceWrapper(Ref ref) {
  return ApiServiceWrapper();
}

// State Notifier Provider 示例
@riverpod
class BookshelfState extends _$BookshelfState {
  @override
  Future<List<Bookshelf>> build() async {
    final repo = ref.watch(bookshelfRepositoryProvider);
    return repo.getAll();
  }
}
```

**Provider 分类**：
- **Service Providers** (14+) - 服务层单例
- **Repository Providers** (9) - 数据仓库
- **StateNotifierProviders** (30+) - 业务状态
- **FutureProvider / StreamProvider** - 异步数据流

### Repository 模式

所有数据访问通过 Repository 层：

```dart
class BookshelfRepository extends BaseRepository {
  Future<List<Bookshelf>> getAll();
  Future<void> add(Bookshelf bookshelf);
  Future<void> delete(int id);
}
```

### API 客户端

使用 OpenAPI 自动生成的 Dart 客户端，通过 Riverpod Provider 注入：

```dart
@riverpod
Future<List<Novel>> searchNovels(
  Ref ref,
  String keyword,
  List<String> sites,
) async {
  final api = ref.watch(apiServiceWrapperProvider);
  return api.search(keyword: keyword, sites: sites);
}
```

---

## 🌐 后端架构

### 爬虫系统

#### 爬虫基类

所有爬虫继承自 `BaseCrawler`：

```python
class BaseCrawler:
    site_id: str
    site_name: str
    base_url: str

    async def search_novels(self, keyword: str) -> list[dict]:
        """搜索小说"""
        raise NotImplementedError

    async def get_chapter_list(self, novel_url: str) -> list[dict]:
        """获取章节列表"""
        raise NotImplementedError

    async def get_chapter_content(self, chapter_url: str) -> dict:
        """获取章节内容"""
        raise NotImplementedError
```

#### 网络层：Scrapling

使用 [Scrapling](https://github.com/D4Vinci/Scrapling) 作为统一爬取引擎：

```python
from app.services.scrapling_fetcher import ScraplingFetcher, RequestStrategy

fetcher = ScraplingFetcher(strategy=RequestStrategy.STEALTH)
response = await fetcher.get(url, headers={...})

# Scrapling Selector 解析（比 BeautifulSoup 快 784x）
title = response.soup.css_first('h1.title::text').get()
```

**请求策略**：
- `SIMPLE` - 普通 HTTP 请求
- `STEALTH` - 反爬绕过

#### 缓存装饰器

使用声明式装饰器统一缓存逻辑：

```python
@cached(ttl=3600, key="chapter:{url}")
async def get_chapter_content(self, chapter_url: str) -> dict:
    return await self._fetch_chapter_content(chapter_url)
```

### 缓存系统

- **内容缓存** - PostgreSQL 存储章节内容
- **任务管理** - 后台任务跟踪
- **WebSocket 推送** - 实时进度更新
- **装饰器缓存** - 自动缓存方法调用

### AI 服务集成

#### ComfyUI 客户端

```python
from app.services.comfyui_client import ComfyUIClient

client = ComfyUIClient(base_url="http://localhost:8188")
result = await client.text_to_image(
    prompt="a beautiful landscape",
    negative_prompt="low quality",
    width=1024,
    height=1024,
)
```

---

## 🤖 AI 功能架构

### DSL Engine（前端本地执行）

Novel App 内置客户端 Dify 工作流复刻，无需后端协作即可执行 AI 工作流。

**核心组件**：

```
lib/services/dsl_engine/
├── dsl_parser.dart          # YAML DSL 解析
├── graph_engine.dart        # 工作流图执行
├── variable_pool.dart       # 变量管理
├── llm_provider.dart        # LLM 调用
├── dsl_executor.dart        # 统一执行入口
├── dsl_engine_config.dart   # 配置管理
└── workflow_nodes/          # 工作流节点类型
```

**使用示例**：

```dart
final executor = DslExecutor(
  llmConfig: LlmConfig(
    baseUrl: 'https://api.deepseek.com/v1',
    apiKey: 'sk-xxx',
  ),
  defaultModel: 'deepseek-chat',
);

// Streaming 执行
await executor.runStreaming(
  inputs: {'chapter_content': '...'},
  onData: (chunk) => print(chunk),
  onError: (e) => print(e),
  onDone: () => print('完成'),
);
```

**DSL 工作流定义**（`assets/dsl/creater.yml`）：

```yaml
app:
  name: 角色提取
  description: 从小说章节提取角色信息
workflow:
  graph:
    nodes:
      - id: start
        type: start
      - id: extract
        type: llm
        prompt: |
          从以下小说内容中提取角色信息：
          {{chapter_content}}
        model: deepseek-chat
      - id: end
        type: end
    edges:
      - from: start
        to: extract
      - from: extract
        to: end
```

---

## 🗄️ 数据库

### 前端：SQLite

- 数据库文件：`novel_reader.db`
- 版本：v21
- 主要表：bookshelf, chapter_cache, novel_chapters, characters, character_relationships, scene_illustrations, outlines, chat_scenes
- 通过 Riverpod Provider 访问

### 后端：PostgreSQL

- 表：chapter_cache, cache_tasks, app_versions, novel_sync_data
- ORM：SQLAlchemy 2.0+
- 迁移工具：Alembic

---

## 🕷️ 添加新爬虫

### 步骤 1：创建爬虫类

```python
# app/services/example_crawler.py
from app.services.base_crawler import BaseCrawler
from app.services.scrapling_fetcher import ScraplingFetcher, RequestStrategy

class ExampleCrawler(BaseCrawler):
    site_id = "example"
    site_name = "示例站点"
    base_url = "https://example.com"

    def __init__(self):
        super().__init__()
        self.fetcher = ScraplingFetcher(strategy=RequestStrategy.SIMPLE)

    async def search_novels(self, keyword: str) -> list[dict]:
        response = await self.fetcher.get(
            f"{self.base_url}/search",
            params={"q": keyword},
        )
        # 解析搜索结果
        return [...]

    async def get_chapter_list(self, novel_url: str) -> list[dict]:
        response = await self.fetcher.get(novel_url)
        # 解析章节列表
        return [...]

    async def get_chapter_content(self, chapter_url: str) -> dict:
        response = await self.fetcher.get(chapter_url)
        # 解析章节内容
        return {...}
```

### 步骤 2：注册到爬虫工厂

```python
# app/services/crawler_factory.py
from app.services.example_crawler import ExampleCrawler

def _register_crawlers():
    crawlers = {
        "example": ExampleCrawler,
        # ...
    }
```

### 步骤 3：更新站点元数据

```python
SOURCE_SITES_METADATA = [
    {
        "id": "example",
        "name": "示例站点",
        "base_url": "https://example.com",
        "description": "站点描述",
        "enabled": True,
        "search_enabled": True,
    },
    # ...
]
```

### 步骤 4：更新环境变量

```env
NOVEL_ENABLED_SITES=alice_sw,ddxsmf,shukuge,wdscw,wodeshucheng,wfxs,biquge543,example
```

### 步骤 5：编写测试

```python
# tests/test_example_crawler.py
import pytest
from app.services.example_crawler import ExampleCrawler

@pytest.mark.asyncio
async def test_search():
    crawler = ExampleCrawler()
    results = await crawler.search_novels("测试")
    assert isinstance(results, list)
```

---

## 🔄 数据库变更

### 前端 SQLite

数据库版本由 `lib/core/database/database_version.dart` 管理。修改表结构时：

1. 更新 Bump DB version
2. 实现 `onUpgrade` 迁移逻辑
3. 运行测试验证

### 后端 PostgreSQL

```bash
cd backend

# 修改 SQLAlchemy 模型
# app/models/your_model.py

# 生成迁移
alembic revision --autogenerate -m "添加新字段"

# 检查生成的迁移文件
# alembic/versions/xxxx_add_new_field.py

# 应用迁移
alembic upgrade head

# 回滚（如果需要）
alembic downgrade -1
```

---

## 🧪 代码质量

### Python 后端

```bash
cd backend

# 静态检查
ruff check .
pylint app/
mypy app/

# 格式化
ruff format .
isort .

# 测试
pytest                          # 全部测试
pytest tests/unit/              # 单元测试
pytest -k "test_crawler"        # 匹配名称
pytest --cov=app tests/         # 覆盖率
```

### Flutter 前端

```bash
cd novel_app

# 静态分析
flutter analyze

# 格式化
flutter format lib/

# 代码生成
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs   # 监听模式

# 测试
flutter test                    # 全部测试
flutter test test/unit/         # 单元测试
flutter test --coverage         # 覆盖率
```

### 提交前检查

建议在提交前运行：

```bash
# 后端
cd backend && ruff check . && mypy app/

# 前端
cd novel_app && flutter analyze && flutter test
```

---

## 🚀 CI/CD

项目使用 GitHub Actions 自动化测试和发布。

### Workflow 文件

- `.github/workflows/flutter-ci.yml` - PR/Push 到 main 时运行 CI
- `.github/workflows/flutter-release.yml` - 推送 tag 时构建并发布 APK

### CI 流程（PR/Push）

1. 检出代码
2. 安装 Flutter SDK
3. 安装依赖（`flutter pub get`）
4. 生成 Riverpod 代码
5. 静态分析（`flutter analyze`）
6. 运行单元测试（`flutter test`）

### Release 流程（tag push）

1. 检出代码
2. 安装 Flutter SDK
3. 安装依赖
4. 生成代码
5. 构建 Release APK
6. 上传到 GitHub Releases

### 创建新版本

```bash
# 1. 更新 pubspec.yaml
# version: 1.7.6+55

# 2. 提交
git add novel_app/pubspec.yaml
git commit -m "chore: 发布版本 1.7.6"

# 3. 创建 tag
git tag v1.7.6
git push origin master --tags

# 4. GitHub Actions 自动构建并发布
```

---

## 🔐 环境变量

完整环境变量参考 `.env.example`。关键变量：

| 变量名 | 必需 | 用途 |
|--------|------|------|
| `NOVEL_API_TOKEN` | ✅ | API 认证 Token |
| `NOVEL_ENABLED_SITES` | ✅ | 启用的爬虫站点列表 |
| `DATABASE_URL` | ✅ | PostgreSQL 连接字符串 |
| `COMFYUI_API_URL` | ⚠️ | ComfyUI 服务（插图功能必需） |
| `SECRET_KEY` | ✅ | JWT 密钥 |
| `DEBUG` | ❌ | 调试模式 |
| `LOG_LEVEL` | ❌ | 日志级别 |
| `CORS_ORIGINS` | ❌ | CORS 允许的源 |
| `HTTP_PROXY` / `HTTPS_PROXY` | ❌ | 网络代理 |

---

## 📚 更多资源

- **项目主页** - https://github.com/yunkst/novel_builder
- **API 文档** - http://localhost:3800/docs
- **后端模块文档** - [backend/CLAUDE.md](../backend/CLAUDE.md)
- **前端模块文档** - [novel_app/CLAUDE.md](../novel_app/CLAUDE.md)
- **用户使用指南** - [user-guide.md](user-guide.md)
- **部署指南** - [deployment.md](deployment.md)
- **日志使用指南** - [logging-guidelines.md](logging-guidelines.md)

---

## 🤝 贡献流程

1. **创建分支** - `git checkout -b feature/your-feature`
2. **编写代码** - 遵循代码规范
3. **添加测试** - 确保新功能有测试覆盖
4. **本地验证** - 运行 `flutter analyze` 和 `flutter test`
5. **提交** - 遵循 Conventional Commits
6. **推送并创建 PR** - 详细描述变更内容
7. **代码审查** - 等待维护者审查
8. **合并** - 通过 CI 后合并到 master

详细请参考 [贡献指南](../CONTRIBUTING.md)。
