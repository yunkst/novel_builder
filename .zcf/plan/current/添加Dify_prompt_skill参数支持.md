# 执行计划：为 Dify 交互添加 prompt_skill 参数支持

## 任务概述
- **任务描述**：在和 Dify 交互的部分增加 prompt_skill 参数，如果选择的模型带了 prompt_skill，就把这个信息一起发送给 Dify，如果没有就不发送
- **实施时间**：2025-01-24
- **方案选择**：方案 1 - 直接修改 DifyClient 方法签名

## 上下文信息

### 相关文件
- **配置文件**：`backend/workflows.yaml`
- **核心客户端**：`backend/app/services/dify_client.py`
- **工作流配置**：`backend/app/workflow_config/workflow_config.py`
- **服务层**：
  - `backend/app/services/role_card_service.py`
  - `backend/app/services/scene_illustration_service.py`
  - `backend/app/services/image_to_video_service.py`

### prompt_skill 结构
- **类型**：多行字符串（YAML `|` 语法）
- **位置**：工作流配置中的顶层字段
- **示例**：`workflows.yaml` 中的 "写实2" 模型配置了详细的 prompt_skill

## 实施步骤

### ✅ 步骤 1：检查并修改工作流配置管理
**文件**：`backend/app/workflow_config/workflow_config.py`

**操作**：
- 在 `WorkflowInfo` 类中添加 `prompt_skill: str | None = Field(None, description="AI提示词增强技巧")` 字段

**结果**：✅ 已完成

---

### ✅ 步骤 2-5：修改 DifyClient 所有方法
**文件**：`backend/app/services/dify_client.py`

**修改的方法**：
1. `generate_prompts()` - 文生图提示词生成
2. `generate_photo_prompts()` - 人物卡拍照提示词生成
3. `generate_scene_prompts()` - 场面绘制提示词生成
4. `generate_video_prompts()` - 图生视频提示词生成

**操作**：
- 为每个方法添加参数：`prompt_skill: str | None = None`
- 在构建 `request_data["inputs"]` 后添加条件判断：
  ```python
  if prompt_skill:
      request_data["inputs"]["prompt_skill"] = prompt_skill
  ```
- 更新方法文档字符串

**结果**：✅ 已完成

---

### ✅ 步骤 6：修改 RoleCardService
**文件**：`backend/app/services/role_card_service.py`
**方法**：`generate_role_images()`

**操作**：
- 获取工作流配置：`workflow = workflow_config_manager.get_t2i_workflow_by_title(selected_model)`
- 提取 prompt_skill：`prompt_skill = workflow.prompt_skill if workflow else None`
- 传递给 Dify：`await self.dify_client.generate_photo_prompts(roles=request.roles, prompt_skill=prompt_skill)`

**结果**：✅ 已完成

---

### ✅ 步骤 7：修改 SceneIllustrationService
**文件**：`backend/app/services/scene_illustration_service.py`
**方法**：`_generate_prompts()`

**操作**：
- 获取工作流配置：`workflow = workflow_config_manager.get_t2i_workflow_by_title(request.model_name)`
- 提取 prompt_skill：`prompt_skill = workflow.prompt_skill if workflow else None`
- 传递给 Dify：`await self.dify_client.generate_scene_prompts(..., prompt_skill=prompt_skill)`

**结果**：✅ 已完成

---

### ✅ 步骤 8：修改 ImageToVideoService
**文件**：`backend/app/services/image_to_video_service.py`
**方法**：`_process_video_generation_async()`

**操作**：
- 获取工作流配置：`workflow = workflow_config_manager.get_i2v_workflow_by_title(model_name)`
- 提取 prompt_skill：`prompt_skill = workflow.prompt_skill if workflow else None`
- 传递给 Dify：`await self.dify_client.generate_video_prompts(..., prompt_skill=prompt_skill)`

**结果**：✅ 已完成

## 修改清单

| # | 文件 | 函数/方法 | 状态 |
|---|------|----------|------|
| 1 | `workflow_config.py` | `WorkflowInfo` 类 | ✅ 完成 |
| 2 | `dify_client.py` | `generate_prompts()` | ✅ 完成 |
| 3 | `dify_client.py` | `generate_photo_prompts()` | ✅ 完成 |
| 4 | `dify_client.py` | `generate_scene_prompts()` | ✅ 完成 |
| 5 | `dify_client.py` | `generate_video_prompts()` | ✅ 完成 |
| 6 | `role_card_service.py` | `generate_role_images()` | ✅ 完成 |
| 7 | `scene_illustration_service.py` | `_generate_prompts()` | ✅ 完成 |
| 8 | `image_to_video_service.py` | `_process_video_generation_async()` | ✅ 完成 |

## 技术细节

### 请求格式示例
```json
{
  "inputs": {
    "chapters_content": "...",
    "roles": "...",
    "user_input": "...",
    "cmd": "文生图",
    "prompt_skill": "多行提示词增强技巧..."  // 条件添加
  },
  "response_mode": "blocking",
  "user": "xxx_user"
}
```

### 向后兼容性
- 所有 `prompt_skill` 参数都是可选的（`str | None = None`）
- 当模型没有配置 prompt_skill 时，传递 `None`
- Dify 请求中只有 `prompt_skill` 非空时才会添加该字段

## 测试建议

### 单元测试（可选）
- 测试 prompt_skill 为 None 时不发送
- 测试 prompt_skill 有值时正确发送

### 集成测试
1. **使用 "写实2" 模型**（有 prompt_skill）：
   - 生成人物卡/场面绘制
   - 检查 Dify 请求日志是否包含 prompt_skill
   - 验证生成的效果

2. **使用 "动漫风" 模型**（无 prompt_skill）：
   - 生成人物卡/场面绘制
   - 确保不报错
   - 验证正常工作

3. **图生视频**：
   - 检查 I2V 工作流是否支持 prompt_skill
   - 测试视频生成功能

## 风险评估
- ✅ **低风险**：向后兼容，可选参数不影响现有功能
- ✅ **易回滚**：修改集中，易于定位和回滚
- ⚠️ **注意事项**：
  - 确保工作流配置正确加载 prompt_skill
  - 测试时检查 Dify 后端是否正确处理 prompt_skill

## 完成状态
🎉 **所有步骤已完成** - 8/8 文件修改完成
