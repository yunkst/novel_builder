[根目录](../../CLAUDE.md) > **backend**

# Python后端API模块

## 变更记录 (Changelog)

- **2025-11-13**: 模块文档初始化，详细描述API架构和爬虫系统

## 模块职责

Python后端是Novel Builder平台的核心服务，提供FastAPI驱动的小说爬取和缓存服务。主要负责：
- 多站点小说内容爬取
- 统一RESTful API接口
- PostgreSQL数据库缓存
- 后台任务管理
- WebSocket实时通信

## 入口与启动

### 主入口文件
- **路径**: `app/main.py`
- **应用类**: `FastAPI`
- **版本**: 0.2.0
- **端口**: 8000 (Docker映射为3800)

### 启动流程
1. **应用初始化**: FastAPI实例创建
2. **中间件配置**: CORS支持
3. **数据库初始化**: SQLAlchemy + Alembic
4. **爬虫注册**: 动态加载可用的爬虫
5. **健康检查**: 启动状态验证

## 对外接口

### 核心API端点

#### 小说搜索
- **路径**: `GET /search`
- **参数**:
  - `keyword`: 搜索关键词
  - `sites`: 指定站点(可选)
- **响应**: `list[Novel]`
- **认证**: X-API-TOKEN

#### 章节管理
- **获取章节列表**: `GET /chapters`
- **获取章节内容**: `GET /chapter-content`
- **参数**: `url`, `force_refresh`

#### 源站信息
- **获取站点列表**: `GET /source-sites`
- **响应**: `list[SourceSite]`

### 缓存管理API
- **创建缓存任务**: `POST /api/cache/create`
- **查询任务状态**: `GET /api/cache/status/{task_id}`
- **获取任务列表**: `GET /api/cache/tasks`
- **取消缓存任务**: `POST /api/cache/cancel/{task_id}`
- **下载缓存内容**: `GET /api/cache/download/{task_id}`

### WebSocket接口
- **缓存进度推送**: `WS /ws/cache/{task_id}`
- **实时状态更新**: 任务进度、错误信息

## 关键依赖与配置

### 项目配置
- **配置文件**: `pyproject.toml`
- **Python版本**: >=3.11
- **构建系统**: Hatchling

### 核心依赖
```python
dependencies = [
    "fastapi>=0.104.0",
    "uvicorn[standard]>=0.24.0",
    "requests>=2.31.0",
    "beautifulsoup4>=4.12.0",
    "lxml>=4.9.0",
    "pydantic>=2.4.0",
    "sqlalchemy>=2.0.0",
    "psycopg2-binary>=2.9.0",
    "alembic>=1.12.0",
    "playwright>=1.55.0",
]
```

### 开发工具
```python
dev = [
    "pytest>=7.4.0",
    "pytest-asyncio>=0.21.0",
    "pytest-cov>=4.1.0",
    "ruff>=0.1.0",
    "pylint>=3.0.0",
    "mypy>=1.6.0",
]
```

### 环境变量
- `NOVEL_API_TOKEN`: API访问令牌
- `NOVEL_ENABLED_SITES`: 启用的爬虫站点
- `DATABASE_URL`: PostgreSQL连接字符串
- `DEBUG`: 调试模式开关

## 数据模型

### Pydantic模式 (`app/schemas.py`)
```python
class Novel(BaseModel):
    title: str
    author: str
    url: str

class Chapter(BaseModel):
    title: str
    url: str

class ChapterContent(BaseModel):
    title: str
    content: str
    from_cache: bool = False

class SourceSite(BaseModel):
    id: str
    name: str
    base_url: str
    description: str
    enabled: bool
    search_enabled: bool
```

### SQLAlchemy模型 (`app/models.py`)
- **ChapterCache**: 章节内容缓存表
- **CacheTask**: 缓存任务管理表

## 爬虫系统架构

### 爬虫工厂模式
- **工厂类**: `app/services/crawler_factory.py`
- **基类**: `BaseCrawler`
- **注册机制**: 动态加载和站点配置

### 支持的小说站点
1. **AliceSW** (轻小说文库)
   - 爬虫类: `AliceSWCrawlerRefactored`
   - 特点: 专业的轻小说网站

2. **书库** (Shukuge)
   - 爬虫类: `ShukugeCrawlerRefactored`
   - 特点: 综合性小说书库

3. **小说网** (Xspsw)
   - 爬虫类: `XspswCrawlerRefactored`
   - 特点: 移动端优化

4. **我的书城** (Wdscw)
   - 爬虫类: `WdscwCrawlerRefactored`
   - 特点: 精品小说免费阅读


### 爬虫接口规范
```python
class BaseCrawler:
    async def search_novels(self, keyword: str) -> list[dict]
    async def get_chapter_list(self, novel_url: str) -> list[dict]
    async def get_chapter_content(self, chapter_url: str) -> dict
```

## 数据库设计

### PostgreSQL缓存系统
- **连接管理**: SQLAlchemy连接池
- **迁移工具**: Alembic
- **表结构**: 自动创建和更新

### 核心表结构
1. **chapter_cache**: 章节内容缓存
   - URL哈希索引
   - 内容和元数据
   - 访问统计

2. **cache_tasks**: 缓存任务
   - 任务状态管理
   - 进度跟踪
   - 错误处理

### 数据库服务
- **初始化**: `app/database.py`
- **依赖注入**: FastAPI依赖系统
- **事务处理**: 自动提交和回滚

## 服务层架构

### 搜索服务 (`app/services/search_service.py`)
- **多站点并行搜索**
- **结果聚合和去重**
- **错误处理和重试**

### 缓存服务 (`app/services/novel_cache_service.py`)
- **后台任务管理**
- **进度跟踪**
- **WebSocket推送**

### HTTP客户端 (`app/services/http_client.py`)
- **统一请求处理**
- **代理支持**
- **重试机制**

## 认证与安全

### Token认证
- **Header**: `X-API-TOKEN`
- **验证**: `app/deps/auth.py`
- **配置**: 环境变量管理

### 安全措施
- **SQL注入防护**: SQLAlchemy ORM
- **请求限制**: 可配置的访问频率
- **CORS配置**: 跨域请求控制

## 测试与质量

### 测试框架
- **单元测试**: pytest + pytest-asyncio
- **集成测试**: httpx客户端
- **测试工厂**: factory-boy
- **覆盖率**: pytest-cov

### 测试配置
```ini
[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py", "*_test.py"]
asyncio_mode = "auto"
```

### 代码质量工具
- **静态检查**: ruff, pylint, mypy
- **格式化**: ruff format, black, isort
- **类型检查**: strict mypy配置

## 部署与运维

### Docker部署
- **基础镜像**: Python 3.11
- **多阶段构建**: 优化镜像大小
- **健康检查**: 容器状态监控

### 环境配置
```yaml
services:
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "3800:8000"
    environment:
      - DATABASE_URL=postgresql://...
      - NOVEL_API_TOKEN=${NOVEL_API_TOKEN}
```

### 监控与日志
- **应用日志**: 结构化日志输出
- **健康检查**: `/health` 端点
- **性能指标**: 缓存命中率、响应时间

## 性能优化

### 缓存策略
- **内容缓存**: PostgreSQL持久化
- **智能刷新**: 基于内容长度的有效性检查
- **后台更新**: 异步缓存刷新

### 并发处理
- **异步IO**: FastAPI + asyncio
- **连接池**: 数据库连接复用
- **任务队列**: 后台缓存任务

## 错误处理

### 异常分类
- **网络错误**: 超时和连接失败
- **解析错误**: 网页结构变化
- **数据库错误**: 连接和查询失败

### 错误响应
- **标准格式**: HTTP状态码 + 错误详情
- **日志记录**: 详细的错误上下文
- **用户友好**: 可理解的错误消息

## 常见问题 (FAQ)

### Q: 如何添加新的小说站点？
A: 继承BaseCrawler类，实现三个核心方法，然后在crawler_factory.py中注册。

### Q: 缓存任务失败如何处理？
A: 查看任务状态和错误消息，支持重试机制和部分失败容错。

### Q: 如何优化爬虫性能？
A: 使用异步IO、连接池、智能重试，避免频繁请求。

## 相关文件清单

### 核心文件
- `app/main.py` - FastAPI应用入口
- `app/config.py` - 配置管理
- `app/database.py` - 数据库连接
- `app/models.py` - 数据模型
- `app/schemas.py` - API模式

### 服务层
- `app/services/` - 业务逻辑
  - `crawler_factory.py` - 爬虫工厂
  - `search_service.py` - 搜索服务
  - `novel_cache_service.py` - 缓存服务
  - `http_client.py` - HTTP客户端

### 爬虫实现
- `app/services/*_crawler.py` - 各站点爬虫实现
- `app/services/base_crawler.py` - 爬虫基类

### 依赖与工具
- `app/deps/` - FastAPI依赖
- `tests/` - 测试文件
- `alembic/` - 数据库迁移

### 配置文件
- `pyproject.toml` - 项目配置
- `alembic.ini` - 数据库迁移配置
- `Dockerfile` - 容器构建
- `.env.example` - 环境变量模板

## 开发工作流

### 新爬虫开发
1. 分析目标站点结构
2. 继承BaseCrawler实现接口
3. 编写单元测试
4. 注册到crawler_factory
5. 更新站点元数据

### API功能扩展
1. 定义Pydantic模式
2. 实现业务逻辑
3. 添加路由和认证
4. 编写集成测试
5. 更新OpenAPI文档

### 数据库变更
1. 创建SQLAlchemy模型
2. 生成Alembic迁移
3. 测试迁移脚本
4. 更新依赖注入
5. 验证数据完整性