# Novel Builder

<div align="center">

![Novel Builder](https://img.shields.io/badge/Novel-Builder-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Flutter](https://img.shields.io/badge/flutter-3.0+-blue.svg)
![Python](https://img.shields.io/badge/python-3.11+-blue.svg)
![FastAPI](https://img.shields.io/badge/FastAPI-0.104+-red.svg)
![CI](https://github.com/yunkst/novel_builder/actions/workflows/flutter-ci.yml/badge.svg)

**AI 原生小说阅读平台**

本地书架 + Headless WebView 章节提取 + Agent Chat + ComfyUI 文生图/图生视频 + 字体反爬 OCR 还原

[快速开始](#-快速开始) • [功能特性](#-功能特性) • [文档](#-文档) • [在线演示](https://yunkst.github.io/novel_builder/) • [贡献](#-贡献)

</div>

## ✨ 功能特性

### 📱 Flutter 移动应用（Flutter 3.0+）
- **离线优先**：本地 SQLite（v39）做唯一权威存储
- **Headless WebView 章节提取**：前端 JS 提取脚本（`site_scripts` 表），不依赖服务端爬虫
- **PP-OCRv6 字体反爬还原**：番茄小说等 PUA 编码正文可读
- **本地搜索**：章节内容全文搜索（`chapter_search_service.dart`）
- **AI 增强**：DSL Engine + Agent Chat + Subagent + 上下文压缩 + LLM 重试横幅

### 🌐 FastAPI 后端（17 个端点）
- **AI 接口**：ComfyUI 文生图 / 图生视频（提交 + 单接口轮询；支持 negative_prompt）
- **模型管理**：列出工作流 + 模型目录浏览 + 模型分块上传（init/chunk/status/complete/cancel）
- **数据库备份**：客户端 .db 上传/列表/下载/删除
- **客户端日志**：批量 1–50 条/次持久化
- **Docker 部署**：docker compose 一键启动后端 + PostgreSQL（容器内不暴露）

### 🤖 AI 集成（DSL Engine + Agent Chat + ComfyUI）
- **DSL Engine**：本地 LLM 工作流引擎（OpenAI 兼容 API；2026-06-09 已与 Dify 完全解耦）
- **Agent Chat**：写作 / 浏览器 / 多角色场景 + Subagent + 上下文压缩（`novel_agent/`）
- **ComfyUI 文生图 / 图生视频**：场景插图 + 角色配图，`create_images` / `create_image_to_video` 工具
- **角色卡管理**：智能识别 + 人物关系图（`flutter_force_directed_graph`）

## 🚀 快速开始

### 环境要求
- Flutter SDK 3.0+
- Python 3.11+
- Docker & Docker Compose
- PostgreSQL 15+

### 使用 Docker Compose（推荐）

```bash
# 克隆项目
git clone https://github.com/yunkst/novel_builder.git
cd novel_builder

# 配置环境变量
cp .env.example .env
# 编辑 .env，至少设置 NOVEL_API_TOKEN

# 启动所有服务（默认不含个人机挂载）
docker compose up -d

# 查看服务状态
docker compose ps

# 可选：挂载本机 ComfyUI 模型目录 / novel_sync 目录
# cp docker-compose.override.yml.example docker-compose.override.yml
# 编辑 .env 填入 COMFYUI_MODELS_HOST_DIR / NOVEL_SYNC_HOST_DIR，或直接在 override 里硬编码
```

### 手动安装

#### 后端服务
```bash
cd backend
pip install -e .
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

#### 移动应用
```bash
cd novel_app
flutter pub get
flutter run
```

### 端口映射
- **后端 API**：3800 → 8000（FastAPI）
- **debugpy**：6678 → 5678（Dockerfile.debug；生产部署不需要）
- **PostgreSQL**：5432（仅 Docker 容器内部，不对宿主机暴露）
- **ComfyUI**：8188（宿主机本地，文生图后端，通过 `host.docker.internal` 引用）
- **API 文档（Swagger UI）**：http://localhost:3800/docs

> 移动应用不使用固定端口，由 `flutter run` 决定。

## 📖 文档

### 用户文档
- [使用指南](docs/user-guide.md)
- [功能介绍](docs/APP功能介绍.md)（截图反映旧版 UI，待重生成）
- [🌐 在线介绍页](https://yunkst.github.io/novel_builder/)（GitHub Pages，含 APK 下载）

### 开发者文档
- [开发者指南](docs/developer-guide.md)
- [部署指南](docs/deployment.md)
- [后端 API 文档（Swagger UI）](http://localhost:3800/docs)
- [Flutter 模块](novel_app/CLAUDE.md)（模块 CLAUDE.md）
- [后端模块](backend/CLAUDE.md)
- [日志指南](docs/logging-guidelines.md)
- [内部决策追溯](docs/superpowers/)（AI 上下文，不对外展示）

### 文档索引
- [文档中心](docs/README.md)

## 🛠️ 技术栈

### 前端技术
- **Flutter 3.0+**：跨平台移动应用框架
- **Dart SDK**：编程语言
- **SQLite**：本地数据存储
- **Riverpod**：状态管理
- **Material Design 3**：UI设计系统

### 后端技术
- **FastAPI**：Python Web 框架（17 端点；alembic head `20260708_drop_cache_tables`）
- **SQLAlchemy + Alembic**：ORM + 迁移（head = `20260708_drop_cache_tables`）
- **PostgreSQL 15**（生产）/**SQLite**（本地 dev 默认）：通过 `DATABASE_URL` 切换
- **ComfyUI 客户端**：工作流占位符递归替换 + HTTP 提交 / 轮询

### 基础设施
- **Docker & Docker Compose**：容器化部署
- **Alembic**：数据库迁移
- **OpenAPI**：API文档生成
- **GitHub Actions**：CI/CD 自动化

## 🏗️ 项目结构

```
novel_builder/
├── 📱 novel_app/          # Flutter 移动应用（v39 SQLite，24+ screens，48+ services）
│   ├── lib/               # 应用源代码
│   │   ├── core/          # 核心基础设施（database + interfaces + providers）
│   │   ├── screens/       # 页面组件（24+）
│   │   ├── widgets/       # 可复用组件（50+，含 agent_chat/reader/character 等）
│   │   ├── services/      # 业务服务（DSL Engine / Agent / Headless WebView / OCR 等）
│   │   ├── repositories/  # 数据仓库层（12 个 Repository）
│   │   ├── models/        # 数据模型（25 个 Model）
│   │   └── utils/         # 工具函数
│   ├── android/           # Android 平台配置
│   ├── ios/               # iOS 平台配置
│   ├── assets/            # 字体（Noto SC）+ OCR 模型（inference.onnx + dict）
│   └── CLAUDE.md          # 模块文档
├── 🌐 backend/            # Python FastAPI 后端（17 端点）
│   ├── app/               # API 源代码
│   │   ├── api/routes/    # API 路由（backup / logs / models）
│   │   ├── services/      # 业务服务（comfyui_client / text2img / image_to_video）
│   │   └── models/        # ORM 模型（text2img_task / image_to_video_task / client_logs）
│   ├── tests/             # 测试文件
│   ├── alembic/           # 数据库迁移（head = 20260708_drop_cache_tables）
│   └── CLAUDE.md          # 模块文档
├── 📚 docs/               # 项目文档（含 user-guide / deployment / APP功能介绍 / superpowers/ 等）
├── 🐳 docker-compose.yml  # Docker 编排（后端 + PostgreSQL；个人挂载见 override）
├── 📄 README.md           # 项目说明
├── 📜 LICENSE             # MIT 许可证
└── 🤝 CONTRIBUTING.md     # 贡献指南
```

## 🤝 贡献

我们欢迎所有形式的贡献！请查看 [贡献指南](CONTRIBUTING.md) 了解如何参与项目开发。

### 贡献方式
- 🐛 报告 Bug
- 💡 提出新功能建议
- 📝 改进文档
- 🔧 提交代码修复
- 🌟 为项目添加 Stars

### 开发流程
1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'feat: add amazing feature'`)
4. 推送分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE) - 详见 LICENSE 文件。

## 🙏 致谢

感谢所有为这个项目做出贡献的开发者和用户！

## 📞 联系我们

- 项目主页：https://github.com/yunkst/novel_builder
- 问题反馈：https://github.com/yunkst/novel_builder/issues
- 讨论区：https://github.com/yunkst/novel_builder/discussions

---

<div align="center">

**如果这个项目对你有帮助，请考虑给一个 ⭐️**

Made with ❤️ by [yunkst](https://github.com/yunkst)

</div>
