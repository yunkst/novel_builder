# Novel Builder 文档

欢迎使用 Novel Builder 文档！这里包含了项目的详细技术文档、用户指南和部署说明。

## 📚 文档目录

### 用户文档
- [📖 用户指南](user-guide.md) - 如何安装和使用 Novel Builder
- [📱 APP 功能介绍](APP功能介绍.md) - 应用功能特性详解

### 开发者文档
- [🛠️ 开发者指南](developer-guide.md) - 架构设计、环境搭建、扩展开发
- [📝 后端模块文档](../backend/CLAUDE.md) - Python 后端架构
- [📱 前端模块文档](../novel_app/CLAUDE.md) - Flutter 应用架构
- [🪵 日志系统使用指南](logging-guidelines.md) - LoggerService 使用方法

### 运维文档
- [🐳 部署指南](deployment.md) - 生产环境部署说明

### 架构图表
- [🖼️ Flutter 架构图](diagrams/flutter_architecture_diagram.png) - 架构可视化

## 🚀 快速开始

### 新用户
1. 阅读 [用户指南](user-guide.md) 了解基本功能
2. 按照 [安装指南](user-guide.md#安装) 下载安装 APP
3. 查看 [常见问题](user-guide.md#常见问题) 解决使用问题

### 开发者
1. 阅读 [开发者指南](developer-guide.md) 了解项目结构
2. 查看 API 文档（http://localhost:3800/docs）了解接口规范
3. 参考 [部署指南](deployment.md) 进行开发环境搭建

### 运维人员
1. 按照 [部署指南](deployment.md) 部署生产环境
2. 配置监控和日志
3. 定期备份数据

## 🏗️ 项目结构

```
docs/
├── README.md                  # 文档索引（本文件）
├── user-guide.md              # 用户使用指南
├── APP功能介绍.md              # APP 功能介绍
├── developer-guide.md         # 开发者指南
├── deployment.md              # 部署指南
├── logging-guidelines.md      # 日志系统使用指南
├── diagrams/                  # 架构图
│   ├── flutter_architecture_diagram.png
│   ├── flutter_architecture_diagram.pdf
│   └── flutter_architecture_diagram_4k.png
└── plans/                     # 历史设计计划
    ├── 2025-01-25-logger-service-enhancement.md
    └── 2026-01-26-enhanced-relationship-graph-design.md
```

## 📖 文档规范

### 文档格式
- 使用 Markdown 格式
- 包含目录、代码示例、图片说明
- 保持中英文混排一致性

### 更新频率
- **用户指南**：随版本更新
- **API 文档**：接口变更时更新
- **部署文档**：部署方式变更时更新
- **架构文档**：重大架构调整时更新

### 贡献文档
欢迎贡献文档改进！请遵循以下流程：

1. Fork 项目仓库
2. 创建文档分支：`git checkout -b docs/update-guide`
3. 修改文档内容
4. 提交 Pull Request

详细的贡献指南请参考 [CONTRIBUTING.md](../CONTRIBUTING.md)

## 🔗 相关链接

- **项目主页**：https://github.com/yunkst/novel_builder
- **问题反馈**：https://github.com/yunkst/novel_builder/issues
- **讨论区**：https://github.com/yunkst/novel_builder/discussions
- **API 文档**：http://localhost:3800/docs
- **最新发布**：https://github.com/yunkst/novel_builder/releases

## 📞 获取帮助

如果您在使用文档过程中遇到问题：

1. 📧 邮件支持：kfeb4@outlook.com
2. 💬 GitHub Issues：报告文档问题或建议
3. 📖 GitHub Discussions：参与社区讨论

---

**最后更新**：2026-06-11
**文档版本**：v1.7.6
