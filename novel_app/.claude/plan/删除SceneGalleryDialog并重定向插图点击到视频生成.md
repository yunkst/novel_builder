# 删除SceneGalleryDialog并重定向插图点击到视频生成

## 任务背景
完全删除SceneGalleryDialog组件，并将插图点击事件重定向到视频生成功能。

## 执行计划

### 阶段1：分析和准备
- [x] 分析SceneGalleryDialog的所有引用和依赖关系
- [ ] 创建新的视频生成处理方法
- [ ] 修改插图点击事件

### 阶段2：清理和删除
- [ ] 移除导入语句
- [ ] 删除scene_gallery_dialog.dart文件
- [ ] 清理相关代码

### 阶段3：测试验证
- [ ] Flutter分析和构建测试

## 关键发现
- SceneGalleryDialog主要在reader_screen.dart中被引用
- 插图点击事件通过_showIllustrationGalleryByTaskId方法处理
- VideoInputDialog组件可以独立使用
- 视频生成API通过ApiServiceWrapper调用

## 风险控制
- 保留VideoInputDialog组件
- 确保API调用逻辑完整
- 分步骤验证功能