# 场面绘制重新生成功能实现方案

## 1. 后端接口实现

### 1.1 添加新的 Schema 定义
在 `backend/app/schemas.py` 中添加：

```python
class SceneRegenerateRequest(BaseModel):
    """场面绘制重新生成请求"""
    task_id: str  # 原始任务ID
    count: int = Field(3, ge=1, le=20, description="生成图片数量")  # 生成数量
    model: Optional[str] = Field(None, description="指定使用的模型名称（可选）")

class SceneRegenerateResponse(BaseModel):
    """场面绘制重新生成响应"""
    task_id: str
    total_prompts: int
    message: str
```

### 1.2 添加场面绘制服务方法
在 `backend/app/services/scene_illustration_service.py` 中添加：

```python
async def regenerate_scene_images(
    self,
    request: SceneRegenerateRequest,
    db: Session
) -> SceneRegenerateResponse:
    """基于现有任务重新生成场面图片

    Args:
        request: 重新生成请求
        db: 数据库会话

    Returns:
        生成响应

    Raises:
        ValueError: 当任务不存在或参数无效时
    """
    try:
        # 1. 查找原始任务
        original_task = db.query(SceneIllustrationTask).filter(
            SceneIllustrationTask.task_id == request.task_id
        ).first()

        if not original_task:
            raise ValueError("原始任务不存在")

        if original_task.status != "completed":
            raise ValueError("只能基于已完成的任务重新生成图片")

        # 2. 获取原始任务的提示词
        original_prompt = original_task.prompts
        if not original_prompt:
            raise ValueError("原始任务的提示词不存在")

        logger.info(f"基于任务 {request.task_id} 重新生成 {request.count} 张图片")

        # 3. 创建ComfyUI客户端
        if original_task.model_name:
            logger.info(f"使用指定模型重新生成图片: {original_task.model_name}")
            comfyui_client = create_comfyui_client_for_model(original_task.model_name)
        else:
            from ..workflow_config.workflow_config import workflow_config_manager
            default_workflow = workflow_config_manager.get_default_t2i_workflow()
            logger.info(f"使用默认模型重新生成图片: {default_workflow.title}")
            comfyui_client = create_comfyui_client_for_model(default_workflow.title)

        # 4. 生成多个相似的提示词（可以在这里添加提示词变体逻辑）
        prompts = [original_prompt] * request.count

        # 5. 批量生成图片
        image_filenames = []
        for i in range(request.count):
            logger.info(f"重新生成第 {i+1}/{request.count} 张图片")

            # 提交生成任务
            comfyui_task_id = await comfyui_client.generate_image(prompts)
            if comfyui_task_id:
                # 等待任务完成并获取图片文件名
                completed_filenames = await comfyui_client.wait_for_completion(comfyui_task_id)
                if completed_filenames and len(completed_filenames) > 0:
                    media_file = completed_filenames[0]
                    filename = media_file.filename
                    image_filenames.append(filename)
                    logger.info(f"第 {i+1} 张图片重新生成成功，文件名: {filename}")

        if not image_filenames:
            logger.error("ComfyUI未生成任何图片")
            return SceneRegenerateResponse(
                task_id=request.task_id,
                total_prompts=len(prompts),
                message="图片生成失败"
            )

        logger.info(f"成功重新生成 {len(image_filenames)} 张图片")

        # 6. 保存新图片到数据库
        saved_count = 0
        for filename in image_filenames:
            try:
                # 检查是否已存在相同的图片
                existing_image = db.query(SceneImageGallery).filter(
                    SceneImageGallery.task_id == request.task_id,
                    SceneImageGallery.img_url == filename
                ).first()

                if existing_image:
                    logger.warning(f"图片 {filename} 已存在，跳过保存")
                    continue

                # 保存新图片记录
                scene_image = SceneImageGallery(
                    task_id=request.task_id,
                    img_url=filename,
                    prompt=original_prompt,
                    created_at=datetime.now()
                )

                db.add(scene_image)
                saved_count += 1

            except Exception as e:
                logger.error(f"保存图片 {filename} 失败: {e}")
                continue

        # 提交数据库事务
        try:
            db.commit()
            logger.info(f"成功保存 {saved_count} 张重新生成的图片到数据库")
        except SQLAlchemyError as e:
            db.rollback()
            logger.error(f"数据库提交失败: {e}")
            return SceneRegenerateResponse(
                task_id=request.task_id,
                total_prompts=len(prompts),
                message="图片生成成功，但数据库保存失败"
            )

        return SceneRegenerateResponse(
            task_id=request.task_id,
            total_prompts=len(prompts),
            message=f"成功重新生成并保存 {saved_count} 张图片"
        )

    except ValueError as e:
        logger.error(f"参数错误: {e}")
        raise
    except Exception as e:
        logger.error(f"重新生成场面图片失败: {e}")
        raise ValueError(f"重新生成图片失败: {str(e)}")
```

### 1.3 添加 API 路由
在 `backend/app/main.py` 中添加：

```python
from .schemas import SceneRegenerateRequest, SceneRegenerateResponse

@app.post("/api/scene-illustration/regenerate", dependencies=[Depends(verify_token)])
async def regenerate_scene_images(
    request: SceneRegenerateRequest,
    db: Session = Depends(get_db)
):
    """
    基于现有任务重新生成场面图片

    - **task_id**: 原始任务ID
    - **count**: 生成图片数量
    - **model**: 指定使用的模型名称（可选，会使用原始任务的模型）
    """
    try:
        result = await scene_illustration_service.regenerate_scene_images(request, db)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"重新生成场面图片失败: {e}")
        raise HTTPException(status_code=500, detail="重新生成图片失败")
```

## 2. 前端实现

### 2.1 修改 SceneImagePreview 组件
在 `novel_app/lib/widgets/scene_image_preview.dart` 中修改 `onImageTap` 的处理：

```dart
// 在 _buildImagePageView 方法中，修改图片的点击处理
Widget _buildPageImage(String imageUrl) {
  return Stack(
    children: [
      // 原有的图片组件
      _buildImageWidget(
        imageUrl: imageUrl,
        onTap: widget.onImageTap ?? () => _showGenerateMoreDialog(), // 修改这里
        heightRange: (50.0, 400.0),
        placeholderHeight: 200.0,
      ),
      // ... 其他代码保持不变
    ],
  );
}

// 添加生成更多图片的对话框方法
void _showGenerateMoreDialog() {
  if (widget.taskId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('无法获取任务ID')),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (context) => GenerateMoreDialog(
      onConfirm: (count) => _generateMoreImages(count),
    ),
  );
}

Future<void> _generateMoreImages(int count) async {
  if (widget.taskId == null) return;

  try {
    // 显示加载提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在生成更多图片，请稍候...'),
        duration: Duration(seconds: 3),
      ),
    );

    final apiService = ApiServiceWrapper();

    // 调用重新生成API
    final result = await apiService.regenerateSceneIllustration(
      taskId: widget.taskId!,
      count: count,
    );

    // 刷新图片列表
    await _loadIllustrationFromBackend();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? '图片生成完成'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    debugPrint('生成更多图片失败: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('生成图片失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

### 2.2 扩展 ApiServiceWrapper
在 `novel_app/lib/services/api_service_wrapper.dart` 中添加：

```dart
/// 重新生成场面插图
Future<Map<String, dynamic>> regenerateSceneIllustration({
  required String taskId,
  required int count,
}) async {
  try {
    final response = await _postRequest(
      '/api/scene-illustration/regenerate',
      {
        'task_id': taskId,
        'count': count,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  } catch (e) {
    debugPrint('重新生成场面插图失败: $e');
    rethrow;
  }
}
```

## 3. 交互流程设计

### 3.1 用户操作流程
1. 用户在阅读界面看到图片
2. 点击图片 → 触发 `onImageTap` 回调
3. 弹出 `GenerateMoreDialog` 对话框
4. 用户选择要生成的图片数量（1-20张）
5. 点击确认 → 调用后端重新生成API
6. 显示生成进度提示
7. 生成完成后刷新图片列表
8. 显示成功/失败提示

### 3.2 错误处理
- 网络错误：显示网络连接失败提示
- API错误：显示具体错误信息
- 生成失败：显示生成失败原因
- 重复点击：防止重复提交

### 3.3 用户体验优化
- 生成过程中显示加载状态
- 自动刷新图片列表
- 保持用户当前查看的图片位置
- 提供快速选择选项（1, 3, 5, 10张）

## 4. 测试计划

### 4.1 单元测试
- 测试新增的后端服务方法
- 测试API参数验证
- 测试数据库操作

### 4.2 集成测试
- 测试完整的重新生成流程
- 测试错误处理机制
- 测试前端界面交互

### 4.3 用户测试
- 测试生成图片的视觉效果
- 测试不同数量的生成请求
- 测试网络异常情况的处理

## 5. 部署注意事项

### 5.1 数据库兼容性
确保新的数据库操作与现有数据结构兼容

### 5.2 性能考虑
- 限制单次生成的最大数量（建议20张）
- 考虑添加生成队列机制
- 监控ComfyUI服务的负载

### 5.3 安全性
- 验证用户权限
- 防止API滥用
- 记录生成操作日志

这个实现方案充分利用了现有的基础设施，只需要添加场面绘制的重新生成功能，用户体验流畅，技术实现简单可靠。