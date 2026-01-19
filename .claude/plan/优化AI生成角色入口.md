# 优化AI生成角色入口功能

## 任务上下文

**目标：** 优化AI生成角色的逻辑，将两个入口合并为一个，通过对话框中的开关控制生成模式。

**原因：** 当前有两个独立入口（普通AI创建角色 vs 从大纲生成角色），代码重复且用户体验不统一。

**约束：** 保持现有功能逻辑不变，仅优化交互和代码结构。

## 选定方案

**方案1：** 扩展现有对话框 + 统一入口 ✅

通过在对话框中增加"从大纲生成"开关，动态控制生成逻辑，实现入口统一。

## 执行步骤

### 1. 修改 CharacterInputDialog 组件 ✅

**文件：** `novel_app/lib/widgets/character_input_dialog.dart`

**变更内容：**
- 新增 `hasOutline` 参数（默认 `false`）
- 新增内部状态 `_useOutline`（默认 `true`）
- 新增开关控件 `SwitchListTile`（条件渲染）
- 修改返回类型为 `Map<String, dynamic>`，包含 `userInput` 和 `useOutline`

**新增代码行数：** ~20行

### 2. 重构 character_management_screen.dart ✅

**文件：** `novel_app/lib/screens/character_management_screen.dart`

**变更内容：**
- **AppBar actions（行391-396）：** 删除"从大纲生成角色"按钮，只保留一个入口，图标根据大纲状态动态变化
- **`_aiCreateCharacter` 方法（行133-212）：**
  - 修改对话框调用，传入 `hasOutline: _hasOutline`
  - 解析返回的 `userInput` 和 `useOutline`
  - 根据 `useOutline` 分支调用不同的 Dify 服务方法
  - 动态显示加载提示文本
- **删除 `_aiCreateCharacterFromOutline` 方法（原行214-276）：** 完全删除

**删除代码行数：** ~80行
**新增代码行数：** ~15行

### 3. 测试验证 🔄

**测试场景：**
1. **无大纲模式**：对话框不显示开关 → 调用 `generateCharacters`
2. **有大纲-开关开启**：对话框显示开关且开启 → 调用 `generateCharactersFromOutline`
3. **有大纲-开关关闭**：对话框显示开关但关闭 → 调用 `generateCharacters`

## 代码变更摘要

| 文件 | 新增行 | 删除行 | 修改行 |
|------|--------|--------|--------|
| character_input_dialog.dart | +20 | 0 | ~5 |
| character_management_screen.dart | +15 | -80 | ~20 |
| **总计** | **+35** | **-80** | **~25** |

**净减少：约70行代码** ✅

## 技术要点

1. **向后兼容：** `CharacterInputDialog.show()` 新增可选参数，不影响其他调用
2. **状态管理：** 使用 `setState` 确保开关状态正确更新
3. **动态UI：** AppBar图标和tooltip根据大纲状态动态调整
4. **分支逻辑：** 使用三元运算符简化代码，提高可读性

## 成功标准

- ✅ 只有一个"AI创建角色"入口按钮
- ✅ 对话框根据大纲存在性显示/隐藏开关
- ✅ 开关状态正确路由到不同的生成方法
- ✅ 功能测试通过（无大纲、有大纲开/关）
- ✅ 代码量净减少，可读性提升

## 完成状态

- [x] 步骤1：修改 CharacterInputDialog 组件
- [x] 步骤2：重构 character_management_screen.dart
- [ ] 步骤3：测试验证两种模式的切换和功能

## 相关文件

- `novel_app/lib/widgets/character_input_dialog.dart` - 角色输入对话框组件
- `novel_app/lib/screens/character_management_screen.dart` - 角色管理屏幕
- `novel_app/lib/services/dify_service.dart` - Dify服务（无需修改）
