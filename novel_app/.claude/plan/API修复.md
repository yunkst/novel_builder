# API修复执行计划

## 任务描述
修复Flutter项目中的API方法不匹配问题，遵循原则：
1. 以生成API为准，修改所有涉及的地方
2. 方法不存在时，直接删掉相关逻辑

## 上下文分析
- 项目：novel_app Flutter应用
- 问题：重新生成API后，方法名、参数签名发生变化
- 冲突：本地模型与API模型命名冲突
- 状态：现有42个Flutter分析错误需要修复

## 实施方案
采用渐进式适配策略：
- 保持现有业务逻辑结构
- 逐步适配新的API接口
- 对不存在的方法直接删除相关逻辑
- 解决类型冲突问题

## 执行步骤
1. 解决类型冲突问题
2. 检查新生成API方法
3. 修复character_edit_screen中的API调用
4. 修复reader_screen中的API调用
5. 修复scene_illustration_dialog中的API调用
6. 修复model_selector中的API调用
7. 修复其他widget文件的API调用
8. 清理未使用的导入
9. 验证修复结果

## 预期结果
- 所有Flutter分析错误已解决
- 保留现有业务逻辑结构
- 对不可用功能提供优雅降级
- 代码编译通过