# 沉浸式体验 Dify 参数修复

## 任务概述

修复沉浸式体验功能中与Dify交互的3个问题:
1. roles 需要格式化的角色信息而非仅人名列表
2. 参数名从 `chapter_content` 改为 `chapters_content`
3. 适配新的 `role_strategy` 返回格式 `[{name, strategy}]`

## 上下文信息

**涉及文件:**
- `novel_app/lib/widgets/immersive/immersive_setup_dialog.dart` - 配置对话框
- `novel_app/lib/widgets/immersive/immersive_init_screen.dart` - 初始化页面
- `novel_app/lib/services/dify_service.dart` - Dify服务
- `novel_app/lib/models/character.dart` - 角色模型(已有formatForAI方法)

**关键发现:**
- ✅ `Character.formatForAI()` 静态方法已存在并用于场景描写功能
- ✅ 该方法生成AI友好的格式化文本,包含角色完整信息

## 实施方案

采用**方案1: 最小改动方案**
- 在 `ImmersiveConfig` 中同时保留 `roleNames` (UI用) 和 `characters` (AI用)
- 仅修改 DifyService 中的参数名,不影响其他调用
- 适配新的 `role_strategy` 数据结构并优化UI展示

## 执行步骤

### 1. 修改 ImmersiveConfig 数据模型 ✅
**文件:** `immersive_setup_dialog.dart`
- 添加 `List<Character> characters` 字段
- 保留 `roleNames` 用于UI展示

### 2. 修改配置对话框返回逻辑 ✅
**文件:** `immersive_setup_dialog.dart`
- `_validateAndReturn()` 方法同时返回两份数据

### 3. 修改 DifyService.generateImmersiveScript() ✅
**文件:** `dify_service.dart`
- 参数类型: `dynamic roles` → `List<Character> characters`
- 使用 `Character.formatForAI()` 格式化角色信息
- 参数名: `chapter_content` → `chapters_content`
- 参数类型: `List<String>? existingRoleStrategy` → `List<Map<String, dynamic>>?`

### 4. 修改 ImmersiveInitScreen 类型声明 ✅
**文件:** `immersive_init_screen.dart`
- `_roleStrategy` 类型: `List<String>?` → `List<Map<String, dynamic>>?`
- 添加 `dart:io` 和 `Character` 导入

### 5. 修改 _generateScript() 方法 ✅
**文件:** `immersive_init_screen.dart`
- 传递 `characters` 而非 `roleNames`
- 适配新的数据结构解析逻辑

### 6. 修改 _regenerateWithFeedback() 方法 ✅
**文件:** `immersive_init_screen.dart`
- 传递正确的参数类型和结构

### 7. 修改角色策略展示UI ✅
**文件:** `immersive_init_screen.dart`
- 根据新格式 `{name, strategy}` 解析数据
- 显示角色头像(如果有缓存)
- 优化UI展示效果

## 修改清单

| 文件 | 修改内容 | 状态 |
|------|---------|------|
| `immersive_setup_dialog.dart` | 添加characters字段,修改返回值 | ✅ |
| `dify_service.dart` | 修改参数类型和格式化逻辑 | ✅ |
| `immersive_init_screen.dart` | 修改类型、调用逻辑、展示UI | ✅ |

## 技术细节

### Character.formatForAI() 输出格式
```
【出场人物】
1. 张三
   基本信息：男，25岁，侦探
   性格特点：冷静、理性
   外貌特征：待补充
   身材体型：待补充
   穿衣风格：待补充
   背景经历：待补充
2. 李四
   ...
```

### role_strategy 新格式
```dart
// 旧格式: List<String>
['策略1', '策略2']

// 新格式: List<Map<String, dynamic>>
[
  {'name': '张三', 'strategy': '张三的策略描述...'},
  {'name': '李四', 'strategy': '李四的策略描述...'}
]
```

### Dify API 最终参数
```json
{
  "inputs": {
    "cmd": "生成剧本",
    "chapters_content": "章节内容...",
    "roles": "【出场人物】\n1. 张三\n   基本信息：男，25岁，侦探\n...",
    "user_input": "用户要求",
    "user_choice_role": "张三"
  },
  "response_mode": "blocking",
  "user": "novel-builder-app"
}
```

## 测试计划

- [ ] 单元测试: ImmersiveConfig 包含完整角色对象
- [ ] 集成测试: Dify API 接收正确的参数
- [ ] UI测试: 角色策略展示包含头像和详细信息

## 回滚计划

如遇问题,使用 Git revert 恢复修改的3个文件

## 完成状态

✅ 所有代码修改已完成
⏳ 等待代码检查和用户测试
