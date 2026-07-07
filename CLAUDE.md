# Novel Builder - 全栈小说阅读平台

## 变更记录 (Changelog)

- **2025-11-13**: AI上下文初始化，重新设计架构文档，添加模块化结构
- **2026-06-11**: 文档大整理，移除 Dify 引用，更新为 DSL Engine + Scrapling + Riverpod
- **2026-07-07**: 校准爬虫站点（9→11）、DB 版本（v21→v33）、移除无依据端口；DSL Engine 统一命名

## 项目愿景

Novel Builder 是一个现代化的全栈小说阅读平台，采用微服务架构，提供跨平台的小说搜索、阅读、缓存和AI增强功能。平台整合多个小说站点资源，通过统一的API接口为用户提供无缝的阅读体验。

## 架构总览

```mermaid
graph TD
    A["(根) Novel Builder"] --> B["novel_app"];
    A --> C["backend"];
    A --> D["docker-compose.yml"];
    A --> E["PostgreSQL"];

    B --> F["Flutter移动应用"];
    B --> G["SQLite本地缓存"];

    C --> H["FastAPI后端服务"];
    C --> I["多站点爬虫系统"];
    C --> J["PostgreSQL缓存"];

    F --> K["书架管理"];
    F --> L["搜索功能"];
    F --> M["阅读界面"];
    F --> N["AI集成（DSL Engine + Agent）"];

    H --> O["搜索API"];
    H --> P["章节API"];
    H --> Q["缓存API"];
    H --> R["版本管理API"];

    I --> S["AliceSW"];
    I --> T["点点（ddxsmf）"];
    I --> U["书库（shukuge）"];
    I --> V["我的书城（wodeshucheng）"];
    I --> W["微风（wfxs）"];
    I --> X["笔趣阁543"];
    I --> Y["...共11站点"];

    click B "./novel_app/CLAUDE.md" "查看 Flutter 移动应用模块"
    click C "./backend/CLAUDE.md" "查看 Python 后端模块"
```

## 技术栈

### 前端技术
- **Flutter 3.0+**: 跨平台移动应用框架
- **Dart SDK**: 编程语言
- **SQLite**: 本地数据存储
- **Riverpod**: 状态管理
- **Material Design 3**: UI设计系统

### 后端技术
- **FastAPI**: Python Web框架
- **PostgreSQL**: 主数据库
- **SQLAlchemy**: ORM框架
- **Scrapling**: 现代网页爬虫引擎
- **Playwright**: 高级网页自动化

### 基础设施
- **Docker & Docker Compose**: 容器化部署
- **Alembic**: 数据库迁移
- **OpenAPI**: API文档生成
- **GitHub Actions**: CI/CD 自动化

## 模块索引

| 模块路径 | 类型 | 主要功能 | 状态 |
|---------|------|----------|------|
| [novel_app](./novel_app/CLAUDE.md) | Flutter移动应用 | 小说阅读器，搜索，缓存，AI功能 | ✅ 活跃 |
| [backend](./backend/CLAUDE.md) | FastAPI后端 | 多站点爬虫（11个），API服务，缓存管理 | ✅ 活跃 |

## 核心功能

### 📱 移动应用功能
- **书架管理**: 本地小说收藏与阅读进度跟踪
- **智能搜索**: 跨11个小说站点的统一搜索
- **离线阅读**: 章节内容本地缓存
- **AI增强**: DSL Engine 本地工作流 + Agent Chat 智能对话
- **场景插图**: AI生成的场景插图功能（ComfyUI 后端，支持负向提示词）
- **角色卡管理**: 智能识别和提取章节角色信息
- **人物关系图**: 可视化角色关系网络
- **提纲管理**: 小说结构和章节规划

### 🌐 后端服务功能
- **多站点爬虫**: 支持11个小说站点（基于 Scrapling）
- **智能缓存**: PostgreSQL数据库缓存 + 装饰器模式
- **实时API**: RESTful API with OpenAPI文档
- **任务管理**: 后台缓存任务与进度跟踪
- **WebSocket**: 实时进度推送
- **版本管理**: APP版本上传与分发
- **数据同步**: 小说数据导入/导出

### 🔧 基础设施功能
- **容器化部署**: Docker Compose一键部署
- **数据库管理**: PostgreSQL + Alembic迁移
- **代理支持**: 网络代理配置
- **健康检查**: 服务状态监控

## 运行与开发

### 环境要求
- Flutter SDK 3.0+
- Python 3.11+
- Docker & Docker Compose
- PostgreSQL 15+

### 快速启动

```bash
# 克隆项目
git clone git@github.com:yunkst/novel_builder.git
cd novel_builder

# 使用Docker Compose启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps
```

### 端口映射
- **后端API**: 3800 → 8000 (FastAPI)
- **调试端口**: 6678 → 5678 (debugpy)
- **数据库**: 5432 (PostgreSQL，仅容器内部，不对宿主机暴露)
- **ComfyUI**: 8188 (宿主机本地，文生图后端)

### 开发环境配置

创建 `.env` 文件：
```env
NOVEL_API_TOKEN=your_api_token_here
NOVEL_ENABLED_SITES=alice_sw,ddxsmf,shukuge,xspsw,wdscw,wodeshucheng,smxku,wfxs,shuhaoxs,biquge543,xqishen
DATABASE_URL=postgresql://novel_user:novel_pass@postgres:5432/novel_db
```

## 测试策略

### 测试原则
- **功能优先**: 先实现功能，再补充测试
- **渐进测试**: 从单元测试开始，逐步增加复杂度
- **维护可控**: 测试代码维护成本不高于业务代码

### 测试覆盖率
- **Flutter应用**: 核心业务逻辑单元测试 + Riverpod Provider 测试
- **后端服务**: API端点集成测试
- **爬虫功能**: 模拟站点测试

## 编码规范

### Python后端
```bash
# 代码质量检查
ruff check .          # 快速检查
pylint app/           # 深度检查
mypy app/             # 类型检查

# 代码格式化
ruff format .         # 自动格式化
isort .               # 导入排序
```

### Flutter应用
```bash
# 代码分析
flutter analyze

# 代码格式化
flutter format lib/

# 测试
flutter test

# 代码生成（Riverpod）
dart run build_runner build --delete-conflicting-outputs
```

## AI使用指引

### Claude Code集成
- 使用根级和模块级CLAUDE.md获取上下文
- 通过Mermaid图理解系统架构
- 遵循各模块的具体开发规范

### 技能系统
- 使用 `.claude/skills/` 中的技能进行开发辅助
- 提交时使用 chinese-commit-conventions 技能
- 代码审查使用 chinese-code-review 技能

## 部署指南

### 生产环境部署
1. 配置环境变量
2. 设置数据库连接
3. 启用HTTPS
4. 配置反向代理
5. 设置监控和日志

### Docker部署
```bash
# 生产环境构建
docker-compose -f docker-compose.yml up -d --build

# 查看日志
docker-compose logs -f
```

## 数据库设计

### 主要表结构
- **bookshelf**: 小说元数据（历史命名，含阅读进度）
- **chapter_cache**: 章节内容缓存
- **novel_chapters**: 章节列表元数据
- **chapter_versions**: 章节历史版本（AI 编辑/重写留档）
- **cache_tasks**: 缓存任务管理
- **characters / character_relationships**: 角色与关系图
- **outlines**: 大纲数据
- **chat_sessions / chat_scenes**: Agent 对话会话与场景
- **prompt_tags / prompt_tag_categories**: 写作标签库
- **agent_memories**: Agent 经验记忆
- **llm_configs**: LLM 配置
- **model_downloads**: 模型分片下载
- **site_scripts**: 站点提取脚本
- **text2img_task**: 文生图任务（ComfyUI prompt_id 为 task_id，1.9.21 起含 negative_prompt）
- **image_to_video_task**: 图生视频任务（ComfyUI prompt_id 为 task_id）

### 数据库版本
- **前端SQLite**: v33 (novel_reader.db)
- **后端PostgreSQL**: Alembic 管理
- **迁移工具**: Alembic (后端) + 数据库升级服务 (前端)

## API文档

### OpenAPI规范
- **文档地址**: http://localhost:3800/docs
- **规范文件**: backend/openapi.json
- **认证方式**: X-API-TOKEN header

### 主要端点
- `GET /search`: 搜索小说
- `GET /chapters`: 获取章节列表
- `GET /chapter-content`: 获取章节内容
- `POST /api/cache/create`: 创建缓存任务
- `GET /api/cache/status/{task_id}`: 查询缓存状态
- `GET /api/source-sites`: 获取支持的站点列表
- `POST /api/text2img/generate`: 提交文生图任务（支持 negative_prompt 负向提示词），返回 task_id
- `GET /api/text2img/image/{task_id}`: 按 task_id 取文生图结果（202 pending / 200 png / 404 失败）
- `POST /api/image-to-video/generate`: 上传图片+提示词，提交图生视频任务，返回 task_id
- `GET /api/image-to-video/video/{task_id}`: 按 task_id 取视频结果（202 pending / 200 mp4 / 404 失败）
- `GET /api/models`: 获取可用文生图/图生视频模型列表
- `POST /api/app-version/upload`: 上传APP版本
- `GET /api/app-version/download/{version}`: 下载APP版本

## 故障排除

### 常见问题
1. **Flutter应用无法连接后端**: 检查API地址配置和Token
2. **爬虫失败**: 检查代理设置和站点可用性
3. **数据库连接失败**: 检查PostgreSQL服务状态
4. **DSL Engine执行失败**: 确认AI设置中已配置API URL和Key
5. **ComfyUI图片生成失败**: 确认ComfyUI服务运行正常

### 日志查看
```bash
# 查看后端日志
docker-compose logs -f backend

# 查看数据库日志
docker-compose logs -f postgres
```

## 贡献指南

### 开发流程
1. Fork项目
2. 创建功能分支
3. 编写代码和测试
4. 提交Pull Request
5. 代码审查和合并

### 代码提交规范
- 使用清晰的提交消息
- 遵循 Conventional Commits 规范
- 一个提交只做一件事
- 包含必要的测试
- 遵循代码规范

## 许可证

MIT License - 详见LICENSE文件
