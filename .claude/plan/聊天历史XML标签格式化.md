# 聊天历史XML标签格式化

## 任务概述

修改角色聊天功能的 `chat_history` 组装逻辑，使用 XML 标签包裹用户输入和 AI 返回内容。

## 需求描述

### 核心需求
1. **用户输入**：用 `<用户></用户>` 包裹，格式为 `<用户>行为:xxx\n对话:xxx</用户>`
2. **AI 输出**：用 `<角色名></角色名>` 包裹，包含旁白和对话
3. **排除规则**：用户最近的一条输入不要加入到 `chat_history` 中（已有逻辑）

### 技术要点
- 不需要使用 `message.type` 区分 AI 内容类型
- AI 的旁白和对话都合并到同一个 `<角色名>` 标签中
- 用户的行为和对话合并到同一个 `<用户>` 标签中

## 实现方案

### 修改文件
1. `novel_app/lib/utils/chat_stream_parser.dart` - 重写 `formatChatHistory` 方法
2. `novel_app/lib/screens/character_chat_screen.dart` - 更新方法调用

### 核心逻辑

```dart
static String formatChatHistory(
  List<ChatMessage> messages,
  String characterName,
) {
  final buffer = StringBuffer();
  String userContent = '';
  String aiContent = '';

  // 遍历消息，收集用户内容和AI内容
  for (final message in messages) {
    if (message.isUser) {
      // 收集用户内容
      if (message.type == 'user_action') {
        userContent += '行为:${message.content}\n';
      } else if (message.type == 'user_speech') {
        userContent += '对话:${message.content}\n';
      }
    } else {
      // 累积 AI 内容（旁白+对话）
      aiContent += message.content;
    }
  }

  // 输出用户内容
  if (userContent.isNotEmpty) {
    final trimmed = userContent.trimRight();
    buffer.write('<用户>$trimmed</用户>\n');
  }

  // 输出 AI 内容
  if (aiContent.isNotEmpty) {
    buffer.write('<$characterName>$aiContent</$characterName>\n');
  }

  return buffer.toString().trimRight();
}
```

## 输出示例

### 输入数据
```dart
messagesForHistory = [
  ChatMessage(type='user_action', content='举起酒杯', isUser=true),
  ChatMessage(type='user_speech', content='你好', isUser=true),
  ChatMessage(type='narration', content='夜色渐深，灯火摇曳', isUser=false),
  ChatMessage(type='dialogue', content='【很高兴见到你】', isUser=false),
]
characterName = '上官冰儿'
```

### 输出结果
```xml
<用户>行为:举起酒杯
对话:你好</用户>
<上官冰儿>夜色渐深，灯火摇曳【很高兴见到你】</上官冰儿>
```

## 执行步骤

1. ✅ 修改 `formatChatHistory` 方法签名，添加 `characterName` 参数
2. ✅ 重写 `formatChatHistory` 核心逻辑，实现 XML 标签包裹
3. ✅ 更新方法注释，说明新格式
4. ✅ 更新 `character_chat_screen.dart` 调用处，传入角色名
5. ✅ 运行 `flutter analyze` 代码检查
6. ✅ 创建执行计划文档

## 测试场景

### 场景 1：用户只有行为
**输入**：用户行为"举起酒杯"
**预期输出**：
```xml
<用户>行为:举起酒杯</用户>
```

### 场景 2：用户只有对话
**输入**：用户对话"你好"
**预期输出**：
```xml
<用户>对话:你好</用户>
```

### 场景 3：用户既有行为又有对话
**输入**：用户行为"举起酒杯"，对话"你好"
**预期输出**：
```xml
<用户>行为:举起酒杯
对话:你好</用户>
```

### 场景 4：AI 只有旁白
**输入**：AI 旁白"夜色渐深"
**预期输出**：
```xml
<上官冰儿>夜色渐深</上官冰儿>
```

### 场景 5：AI 旁白+对话混合
**输入**：AI 旁白"夜色渐深"，对话"【你好】"
**预期输出**：
```xml
<上官冰儿>夜色渐深【你好】</上官冰儿>
```

## 完成状态

- ✅ 所有代码修改已完成
- ✅ 代码质量检查通过（No issues found）
- ✅ 文档已创建

## 相关文件

- `novel_app/lib/utils/chat_stream_parser.dart` - 聊天流式解析器
- `novel_app/lib/screens/character_chat_screen.dart` - 角色聊天屏幕
- `novel_app/lib/models/chat_message.dart` - 聊天消息模型

## 注意事项

1. 用户最近的一条输入已在 `character_chat_screen.dart` 的第 192-198 行排除
2. AI 内容不区分旁白和对话，全部合并到一个标签中
3. 用户内容区分行为和对话，但都在一个 `<用户>` 标签中
4. 传给 Dify 的参数分为两部分：
   - `user_input`: 用户当前输入（单独参数）
   - `chat_history`: 历史对话记录（XML 格式）
