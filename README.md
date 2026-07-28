# 随心阅读

<div align="center">

![随心阅读](https://img.shields.io/badge/随心阅读-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Flutter](https://img.shields.io/badge/flutter-3.0+-blue.svg)
![Python](https://img.shields.io/badge/python-3.11+-blue.svg)
![FastAPI](https://img.shields.io/badge/FastAPI-0.104+-red.svg)
![CI](https://github.com/yunkst/novel_builder/actions/workflows/flutter-ci.yml/badge.svg)

**读喜欢的，改不爽的，<em>写</em>自己的。**

本地书架 · 离线阅读 · AI 改写 · AI 创作 · 角色关系图

[⬇ 下载 APK](https://github.com/yunkst/novel_builder/releases/latest) · [🌐 在线介绍](https://yunkst.github.io/novel_builder/)

[快速开始](#-快速开始) · [功能特性](#-功能特性) · [在线演示](https://yunkst.github.io/novel_builder/) · [文档](#-文档) · [贡献](#-贡献)

</div>

---

## ✨ 功能特性

随心阅读 是一个 **Flutter 离线优先的小说阅读 App**。本地书架 + Headless WebView 章节提取 + Agent Chat + 角色关系图是核心，后端只承担 AI 文生图、备份、日志上报等轻量配套。

### 📖 读 · 沉浸阅读

- **多书架管理**：本地书架分组 + 阅读进度追踪 + 封面媒体化
- **离线阅读**：章节内容本地缓存，无网也能看
- **Headless WebView 章节提取**：前端 JS 提取脚本（`site_scripts` 表，v39），不依赖服务端爬虫
- **PP-OCRv6 字体反爬还原**：番茄小说等 PUA 编码正文自动还原可读
- **本地全文搜索**：章节内容全文索引（`chapter_search_service`）
- **阅读风主题**：Material 3 + 衬线字体 + 琥珀/纸张色系

### ✏️ 改 · AI 改写与角色

- **AI 改写章节剧情**：OpenAI 兼容 LLM 驱动，章节内容一键重写
- **章节版本留档**：每次 AI 改写生成历史版本（`chapter_versions` 表），可回滚
- **角色卡智能识别**：自动从章节提取人物信息（姓名/描述/首次出场）
- **人物关系图**：可视化角色关系网络（`flutter_force_directed_graph`）
- **提纲管理**：章节结构与剧情规划

### 🖋️ 创 · AI 写作助手

- **Agent Chat**：写作 / 浏览器 / 多角色场景，多 Subagent 协作驱动
- **Subagent 多角色协作**：让多个"角色 Agent"协同完成复杂写作任务
- **上下文压缩**：长会话自动剪枝（`ContextCompactor` 预剪枝层），支持千轮级对话
- **LLM 重试横幅**：传输/回合级重试状态可视化（无打断）
- **场景插图 / 角色配图**：ComfyUI 文生图 / 图生视频（可选后端）
- **写作标签库**：prompt 历史 + 标签分类管理

### 📱 跨平台

- **Android**：arm64-v8a / armeabi-v7a / x86_64 三 ABI
- **iOS**：原生支持
- **离线优先架构**：SQLite v39 本地权威存储，所有数据可导出备份

## 🚀 快速开始

### 📱 下载体验（推荐）

直接下载预编译 APK，无需配置环境：

| ABI | 适用设备 | 下载 |
|---|---|---|
| arm64-v8a | 主流手机（推荐） | [下载](https://github.com/yunkst/novel_builder/releases/latest) |
| armeabi-v7a | 旧款手机 | [下载](https://github.com/yunkst/novel_builder/releases/latest) |
| x86_64 | 模拟器 | [下载](https://github.com/yunkst/novel_builder/releases/latest) |

下载后在手机上安装即可。SHA256 校验值见 [Release 页面](https://github.com/yunkst/novel_builder/releases/latest)。完整发布说明与历史版本：[Releases](https://github.com/yunkst/novel_builder/releases)。

### 💻 源码运行 App

需要 Flutter SDK 3.0+ 和 Dart 3.0+：

```bash
# 克隆项目
git clone https://github.com/yunkst/novel_builder.git
cd novel_builder/novel_app

# 安装依赖
flutter pub get

# 运行（自动选择已连接设备/模拟器）
flutter run
```

> App 默认离线可用。本地书架、章节阅读、Agent Chat、角色关系图均无需后端。

### 🔧 可选：启动后端

后端只承担 **AI 文生图 / 场景插图 / 客户端备份 / 日志上报** 四个轻量功能。如果你只用本地书架、离线阅读、角色卡、Agent Chat 本地工作流，**完全不需要启动后端**。

需要时再启动：

```bash
# 回到仓库根目录
cd ..

# 配置环境变量
cp .env.example .env
# 编辑 .env，至少设置 NOVEL_API_TOKEN

# 启动后端 + PostgreSQL
docker compose up -d

# 查看服务状态
docker compose ps
```

需要挂载本机 ComfyUI 模型目录或 novel_sync 目录时，复制 `docker-compose.override.yml.example` 为 `docker-compose.override.yml` 并填入 host 路径，docker compose 会自动 merge。

### 端口映射

- **后端 API**：3800 → 8000（FastAPI）
- **debugpy**：6678 → 5678（Dockerfile.debug；生产部署不需要）
- **PostgreSQL**：5432（仅 Docker 容器内部，不对宿主机暴露）
- **ComfyUI**：8188（宿主机本地，文生图后端，通过 `host.docker.internal` 引用）
- **API 文档（Swagger UI）**：http://localhost:3800/docs

> 移动应用不使用固定端口，由 `flutter run` 决定。

## 🛠️ 技术栈

### 前端 App（核心）

- **Flutter 3.0+**：跨平台移动应用框架
- **Dart ≥3.0**：编程语言
- **SQLite v39**：本地权威存储（`novel_reader.db`）
- **Riverpod**：状态管理
- **Material Design 3**：UI 设计系统
- **PP-OCRv6**：端侧 OCR 推理（`onnxruntime` + 本地模型）
- **flutter_inappwebview**：Headless WebView 章节提取
- **flutter_force_directed_graph**：人物关系图

### 后端（轻量配套）

- **FastAPI**：20 个端点（4 backup + 6 models + 1 logs + 9 main）
- **PostgreSQL 15**（生产）/**SQLite**（dev 默认）：通过 `DATABASE_URL` 切换
- **ComfyUI 客户端**：工作流占位符递归替换 + HTTP 提交 / 轮询
- **Alembic**：数据库迁移（head = `20260708_drop_cache_tables`）

## 🏗️ 项目结构

```
novel_builder/
├── 📱 novel_app/          # Flutter 移动应用（SQLite v39，26 screens，75 services，63 widgets，13 repos）
│   ├── lib/
│   │   ├── core/          # 核心基础设施（database + interfaces + providers）
│   │   ├── screens/       # 页面组件（26）
│   │   ├── widgets/       # 可复用组件（63，含 agent_chat/reader/character 等）
│   │   ├── services/      # 业务服务（75：DSL Engine / Agent / Headless WebView / OCR 等）
│   │   ├── repositories/  # 数据仓库层（13 个 Repository，剔除 base_repository）
│   │   ├── models/        # 数据模型（25）
│   │   └── utils/         # 工具函数
│   ├── android/           # Android 平台配置
│   ├── ios/               # iOS 平台配置
│   ├── assets/            # 字体（Noto SC）+ OCR 模型（inference.onnx + dict）
│   └── CLAUDE.md          # 模块文档
├── 🌐 backend/            # Python FastAPI 后端（20 端点 · 轻量配套）
│   ├── app/
│   │   ├── api/routes/    # API 路由（backup / logs / models）
│   │   ├── services/      # 业务服务（comfyui_client / text2img / image_to_video）
│   │   └── models/        # ORM 模型
│   ├── alembic/           # 数据库迁移
│   └── CLAUDE.md          # 模块文档
├── 📚 docs/               # 用户文档（user-guide / deployment / APP功能介绍 / logging-guidelines 等）
├── 🐳 docker-compose.yml  # Docker 编排（后端 + PostgreSQL；个人挂载见 override）
├── 📄 README.md           # 项目说明
├── 📜 LICENSE             # MIT 许可证
└── 🤝 CONTRIBUTING.md     # 贡献指南
```

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
