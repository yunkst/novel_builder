# 日志规范检查工具

## 功能

检测项目中 `debugPrint` 的使用情况，生成迁移进度报告。

## 使用方法

在项目根目录运行：

```bash
dart run tool/lint/logging_rules.dart
```

## 输出示例

```
🔍 开始检查日志使用规范...

📊 检查结果:

  总 debugPrint 使用次数: 976
  涉及文件数: 69
  需要迁移的文件: 64

🔴 高优先级 - 核心服务（必须迁移）:
  • services/database_service.dart (38 处)
  • services/dify_service.dart (45 处)
  • services/api_service_wrapper.dart (67 处)

🟡 中优先级 - 业务服务（建议迁移）:
  • services/tts_player_service.dart (29 处)
  • services/character_card_service.dart (15 处)

💡 迁移建议:
  1. 优先迁移高优先级文件（核心服务）
  2. 参考 docs/logging-guidelines.md 获取详细指南
```

## 优先级分类

### 🔴 高优先级
- 核心服务文件
- 数据库、网络、AI 相关
- 错误和异常处理

### 🟡 中优先级
- 其他业务服务
- 重要功能模块

### 🟢 低优先级
- UI 组件
- 临时调试代码
- 测试文件

## 注意事项

- 工具会忽略 `.g.dart` 生成的文件
- 检测时会查找附近的 LoggerService 调用（前后2行）
- 如果已有 LoggerService 调用，不会标记为问题
