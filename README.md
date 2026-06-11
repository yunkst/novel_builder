# Novel Builder

<div align="center">

![Novel Builder](https://img.shields.io/badge/Novel-Builder-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Flutter](https://img.shields.io/badge/flutter-3.0+-blue.svg)
![Python](https://img.shields.io/badge/python-3.11+-blue.svg)
![FastAPI](https://img.shields.io/badge/FastAPI-0.104+-red.svg)
![CI](https://github.com/yunkst/novel_builder/actions/workflows/flutter-ci.yml/badge.svg)

**现代化的全栈小说阅读平台**

提供跨平台的小说搜索、阅读、缓存和AI增强功能

[快速开始](#-快速开始) • [功能特性](#-功能特性) • [文档](#-文档) • [贡献](#-贡献)

</div>

## ✨ 功能特性

### 📱 跨平台移动应用
- **Flutter 构建**：支持 Android、iOS、Windows
- **Material Design 3**：现代化 UI 设计
- **离线阅读**：本地 SQLite 缓存
- **智能搜索**：跨 9 个小说站点统一搜索
- **AI 增强**：DSL Engine 本地工作流 + Hermes Agent 智能对话

### 🌐 强大的后端服务
- **FastAPI 驱动**：高性能异步 API
- **多站点爬虫**：支持 9 个小说站点（7 个活跃 + 2 个禁用）
- **智能缓存**：PostgreSQL + 本地缓存双重策略
- **实时通信**：WebSocket 进度推送
- **Docker 部署**：一键容器化部署

### 🤖 AI 集成功能
- **DSL Engine**：客户端 Dify 工作流复刻，支持结构化信息提取、创意写作等
- **Hermes Agent**：基于 OpenAI 兼容 API 的智能对话助手
- **场景插图**：AI 生成的场景插图功能（ComfyUI 后端）
- **角色卡提取**：智能识别和分析章节角色

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
# 编辑 .env 文件，设置必要的环境变量

# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps
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
- **移动应用**：3154 (开发调试)
- **后端API**：3800 → 8000 (FastAPI)
- **数据库**：5432 (PostgreSQL)
- **API文档**：http://localhost:3800/docs

## 📖 文档

### 用户文档
- [使用指南](docs/user-guide.md)
- [功能介绍](docs/APP功能介绍.md)

### 开发者文档
- [开发者指南](docs/developer-guide.md)
- [API 文档](http://localhost:3800/docs)
- [部署指南](docs/deployment.md)
- [Flutter 模块](novel_app/CLAUDE.md)
- [后端模块](backend/CLAUDE.md)
- [日志指南](docs/logging-guidelines.md)

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
- **FastAPI**：Python Web框架
- **PostgreSQL**：主数据库
- **SQLAlchemy**：ORM框架
- **Scrapling**：现代网页爬虫库
- **Playwright**：高级网页自动化

### 基础设施
- **Docker & Docker Compose**：容器化部署
- **Alembic**：数据库迁移
- **OpenAPI**：API文档生成
- **GitHub Actions**：CI/CD 自动化

## 🏗️ 项目结构

```
novel_builder/
├── 📱 novel_app/          # Flutter 移动应用
│   ├── lib/               # 应用源代码
│   │   ├── core/          # 核心基础设施（DI、数据库、Provider）
│   │   ├── screens/       # 页面组件
│   │   ├── widgets/       # 可复用组件
│   │   ├── services/      # 业务服务（DSL Engine、爬虫适配等）
│   │   ├── repositories/  # 数据仓库层
│   │   ├── models/        # 数据模型
│   │   └── utils/         # 工具函数
│   ├── android/           # Android 平台配置
│   ├── ios/               # iOS 平台配置
│   ├── assets/            # 静态资源（DSL 工作流定义）
│   └── CLAUDE.md          # 模块文档
├── 🌐 backend/            # Python 后端服务
│   ├── app/               # API 源代码
│   │   ├── api/routes/    # API 路由（备份、Hermes、同步、日志）
│   │   ├── services/      # 业务服务（爬虫、缓存、AI客户端）
│   │   └── models/        # 数据模型
│   ├── tests/             # 测试文件
│   ├── alembic/           # 数据库迁移
│   └── CLAUDE.md          # 模块文档
├── 📚 docs/               # 项目文档
├── 🐳 docker-compose.yml  # Docker 编排文件
├── 📄 README.md           # 项目说明
├── 📜 LICENSE             # 开源许可证
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
