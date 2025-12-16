# Novel Builder 文档

欢迎使用 Novel Builder 文档！这里包含了项目的详细技术文档、用户指南和部署说明。

## 📚 文档目录

### 用户文档
- [📖 用户指南](user-guide.md) - 如何安装和使用 Novel Builder
- [❓ 常见问题](user-guide.md#常见问题) - 常见问题解答
- [🔧 故障排除](user-guide.md#故障排除) - 问题诊断和解决

### 开发者文档
- [🏗️ 系统架构](architecture.md) - 项目架构设计说明
- [📡 API 文档](接口文档.md) - 后端 API 接口文档
- [🐳 部署指南](deployment.md) - 生产环境部署说明
- [🔄 后端实现计划](backend_implementation_plan.md) - 后端开发计划

### 技术文档
- [🎨 场景插图增强](scene_illustration_enhancement_summary.md) - AI 插图功能说明
- [🔗 ComfyUI 工作流](comfyui_workflow.json) - AI 工作流配置
- [🐛 调试页面](debug_page.html) - 开发调试工具

### 历史文档
- [📋 函数测试报告](_mergeContextsByOrder_函数测试报告.md) - 测试报告
- [📝 架构设计](架构.md) - 中文架构文档
- [📖 章节示例](ch1.txt) - 章节内容示例
- [✅ 待办事项](todo.md) - 开发待办清单

## 🚀 快速开始

### 新用户
1. 阅读 [用户指南](user-guide.md) 了解基本功能
2. 按照 [安装指南](user-guide.md#安装指南) 部署应用
3. 查看 [常见问题](user-guide.md#常见问题) 解决使用问题

### 开发者
1. 阅读 [系统架构](architecture.md) 了解项目结构
2. 查看 [API 文档](接口文档.md) 了解接口规范
3. 参考 [部署指南](deployment.md) 进行开发环境搭建

### 运维人员
1. 按照 [部署指南](deployment.md) 部署生产环境
2. 配置监控和日志
3. 定期备份数据

## 🏗️ 项目结构

```
docs/
├── README.md                           # 文档索引（本文件）
├── user-guide.md                       # 用户指南
├── deployment.md                       # 部署指南
├── architecture.md                     # 系统架构
├── 接口文档.md                          # API 文档
├── backend_implementation_plan.md     # 后端实现计划
├── scene_illustration_enhancement_summary.md  # AI 插图功能
├── comfyui_workflow.json               # ComfyUI 工作流
├── debug_page.html                     # 调试页面
├── _mergeContextsByOrder_函数测试报告.md # 测试报告
├── 架构.md                              # 中文架构文档
├── ch1.txt                             # 章节示例
└── todo.md                             # 待办事项
```

## 📖 文档规范

### 文档格式
- 使用 Markdown 格式
- 遵循 Google 文档风格指南
- 包含目录、代码示例、图片说明

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

- **项目主页**：https://github.com/yedazhi/novel_builder
- **问题反馈**：https://github.com/yedazhi/novel_builder/issues
- **讨论区**：https://github.com/yedazhi/novel_builder/discussions
- **API 文档**：http://localhost:3800/docs

## 📞 获取帮助

如果您在使用文档过程中遇到问题：

1. 📧 邮件支持：yedazhi@c2h4.cn
2. 💬 GitHub Issues：报告文档问题或建议
3. 📖 GitHub Discussions：参与社区讨论

---

**最后更新**：2025-12-16
**文档版本**：v1.0.0