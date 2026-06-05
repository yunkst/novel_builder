# 任务：阅读界面 AI 提取标签功能

## 时间
2026-06-05

## 上下文
在 novel_app 的阅读界面（reader_screen）右上角增加 AI 提取标签功能：
- 入口：ReaderAppBar 的 PopupMenuButton 新增菜单项 "AI 提取标签"
- 点击弹出 AIPromptTagExtractSheet（全屏 BottomSheet）
- 用户输入"提取想法"，提交后调用 Dify 阻塞式工作流（cmd=提取标签）
- Dify 入参：user_input, current_chapter_content, tag_categories（格式化字符串）
- Dify 出参：outputs.tags[]，每项含 提示词/类型/tag
- 列表展示提取结果：每行可勾选/编辑（标签名/类型/提示词）
- 确认保存：按"类型"映射到现有 PromptTagCategory，找不到则自动新建
- 写入 PromptTag（允许重复添加）

## 计划执行情况

### 完成项
1. ✅ 新建 `lib/widgets/reader/ai_prompt_tag_extract_sheet.dart`
   - 输入区：多行 TextField + 提取按钮
   - 加载态：圆形进度 + 提示文字
   - 结果列表：每项包含 Checkbox + 类型/标签/提示词 三个可编辑字段
   - 保存逻辑：批量插入 PromptTag，类型映射到现有类别（不存在则新建），允许重复
2. ✅ 修改 `lib/widgets/reader/reader_app_bar.dart`
   - 新增 PopupMenuItem value='ai_extract_tags'，图标 Icons.auto_awesome，文案"AI 提取标签"
3. ✅ 修改 `lib/screens/reader_screen.dart`
   - 在 _handleMenuAction 中处理 'ai_extract_tags' 分支
   - 校验章节内容非空
   - showModalBottomSheet 弹出 AIPromptTagExtractSheet
   - 添加 import
4. ✅ flutter analyze 通过（仅 1 个 info 级提示，无 error/warning）

## 关键设计点
- Dify 输入 cmd: "提取标签"（与已有 cmd 命名风格一致）
- tag_categories 格式：类别名用"、"分隔的字符串（如"风格、场景、人物、情节"）
- current_chapter_content 截断到 8000 字符以避免超长
- 默认全选，用户可取消勾选或编辑后再保存
- 类别下拉改为可编辑文本框，更灵活（用户可输入新类别名）
- 保存时按 (类型) 在 PromptTagCategory 中查 id，不存在则新建后映射

## 后续使用
提取的标签可在以下场景使用：
- InsertChapterScreen 中通过 PromptTagService.buildMergedUserInput 拼接
- 任何需要"写作技巧"提示词注入的地方
- 在 PromptTagManagementScreen 中可管理/删除
