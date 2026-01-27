# 执行计划：人物关系页面移除"全部"Tab

**任务描述**：在人物关系页面，去掉[全部]这个tap
**创建时间**：2026-01-25 17:03:43
**用户需求**：
1. 移除"全部"Tab，保留"Ta的关系"和"关系Ta的人"
2. 默认显示"Ta的关系"（选项A）
3. 不需要加载_allRelationships数据
4. 清理相关未使用代码

## 上下文

### 当前实现
- 文件：`novel_app/lib/screens/character_relationship_screen.dart`
- 当前有3个Tab：全部、Ta的关系、关系Ta的人
- 加载3种数据：全部关系、出度关系、入度关系

### 目标状态
- 2个Tab：Ta的关系、关系Ta的人
- 加载2种数据：出度关系、入度关系
- 默认显示"Ta的关系"

## 执行步骤

### 步骤1：修改TabController配置
- **位置**：第48行
- **操作**：`TabController(length: 3, vsync: this)` → `TabController(length: 2, vsync: this)`

### 步骤2：移除TabBar中的"全部"Tab
- **位置**：第207-217行
- **操作**：删除第一个Tab(text: '全部')

### 步骤3：修改TabBarView
- **位置**：第226-233行
- **操作**：删除children数组的第一个元素

### 步骤4：删除_allRelationships变量
- **位置**：第35行
- **操作**：删除`List<CharacterRelationship> _allRelationships = [];`

### 步骤5：移除全部关系的数据加载
- **位置**：第64-70行
- **操作**：从Future.wait中移除`_databaseService.getRelationships`调用

### 步骤6：移除全部关系的状态赋值
- **位置**：第72-74, 88行
- **操作**：删除all变量和_allRelationships赋值

### 步骤7：更新角色ID收集逻辑
- **位置**：第76-82行
- **操作**：从outgoing和incoming收集角色ID

### 步骤8：清理_buildRelationshipList的isAll参数
- **位置**：第237-241行
- **操作**：移除isAll参数

### 步骤9：更新_buildRelationshipList调用
- **位置**：第229-231行
- **操作**：移除isAll: true参数

### 步骤10：清理_buildEmptyState的isAll参数
- **位置**：第259-291行
- **操作**：移除isAll参数及相关逻辑

### 步骤11：更新_buildEmptyState调用
- **位置**：第243行
- **操作**：移除isAll参数传递

## 验证清单

- [ ] 页面仅显示2个Tab
- [ ] 默认显示"Ta的关系"Tab
- [ ] 可以正常切换Tab
- [ ] 编辑和删除功能正常
- [ ] 无编译错误或警告

## 完成状态

- 状态：已完成
- 开始时间：2026-01-25 17:03:43
- 完成时间：2026-01-25 17:06:15
- 验证结果：✅ 通过（Flutter analyze无问题）

## 修改摘要

### 已完成的修改

1. ✅ 删除`_allRelationships`变量
2. ✅ 修改TabController长度从3改为2
3. ✅ 移除"全部"Tab，保留"Ta的关系"和"关系Ta的人"
4. ✅ 移除全部关系的数据加载调用
5. ✅ 更新角色ID收集逻辑（从outgoing和incoming收集）
6. ✅ 清理`_buildRelationshipList`的`isAll`参数
7. ✅ 清理`_buildEmptyState`的`isAll`参数及相关逻辑
8. ✅ 代码分析通过，无警告或错误

### 代码改进

- **性能优化**：减少1次数据库查询调用
- **代码简洁**：删除未使用的变量和参数
- **逻辑清晰**：Tab数量与数据加载一致

### 影响范围

- 仅修改1个文件：`character_relationship_screen.dart`
- 不影响其他模块
- 不需要数据库迁移
- 向后兼容（已有数据不受影响）
