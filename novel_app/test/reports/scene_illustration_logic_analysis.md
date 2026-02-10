# 文章插图功能完整逻辑分析

## 📅 分析日期
2025-01-30

## 🎯 功能概述

在文章阅读器中创建场景插图，支持用户选择段落、配置角色、调用AI生成图片，并将插图标记插入到章节内容中。

## 🔄 完整流程

### 1. 用户触发创建插图

**入口**：`reader_screen.dart` 长按段落

```dart
// reader_screen.dart 第313-391行
void _handleLongPress(int index) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Container(
        child: ListTile(
          leading: Icon(Icons.add_photo_alternate),
          title: Text('创建插图'),
          onTap: () {
            Navigator.pop(context);
            _showIllustrationDialog(paragraph, index);
          },
        ),
      );
    },
  );
}
```

**关键信息传递**：
- `paragraphText`: 段落文本
- `paragraphIndex`: 段落索引
- `novelUrl`: 小说URL
- `chapterId`: 章节ID

### 2. 显示插图配置对话框

**文件**：`scene_illustration_dialog.dart`

**流程**：
1. 加载小说角色列表
2. 预选章节中出现的角色（使用CharacterMatcher）
3. 用户配置：
   - 选择角色（多选）
   - 选择图片数量（1-4张）
   - 选择AI模型
   - 确认生成

**核心方法**：
```dart
// 预选角色
_preselectAppearingCharacters() {
  // 1. 获取章节内容
  final chapterContent = await _databaseService.getCachedChapter(chapterId);

  // 2. 获取可匹配内容（当前段落及之前）
  final matchableContent = _getMatchableContent(chapterContent, paragraphIndex);

  // 3. 使用CharacterMatcher查找出现的角色
  final appearingIds = CharacterMatcher.findAppearingCharacterIds(
    matchableContent,
    _characters,
  );

  // 4. 自动预选
  _selectedCharacterIds = appearingIds;
}
```

### 3. 创建插图任务

**文件**：`scene_illustration_service.dart`

**核心方法**：`createSceneIllustrationWithMarkup()`

**流程**：

```
┌─────────────────────────────────────────────────────────┐
│ 1. 预生成 taskId                                       │
│    taskId = SceneIllustration.generateTaskId()          │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 2. 插入插图标记到章节内容                               │
│    _insertIllustrationMarkup()                          │
│    - 获取章节内容                                        │
│    - 分割为段落                                          │
│    - 在指定位置插入: [!插图!](taskId)                    │
│    - 保存章节内容                                        │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 3. 创建本地数据库记录                                   │
│    illustration = SceneIllustration(                     │
│      taskId: taskId,                                    │
│      content: paragraphText,                            │
│      status: 'pending',                                  │
│      images: [],                                        │
│    )                                                     │
│    _databaseService.insertSceneIllustration(illustration)│
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 4. 调用后端API生成图片                                  │
│    _apiService.createSceneIllustration(                 │
│      chaptersContent: paragraphText,                    │
│      taskId: taskId,                                    │
│      roles: selectedRoles,                              │
│      num: imageCount,                                   │
│    )                                                     │
└─────────────────────────────────────────────────────────┘
```

### 4. 插入标记到章节内容

**方法**：`_insertIllustrationMarkup()`

**标记格式**：`[!插图!](taskId)`

**插入位置选项**：
- `before`: 在段落之前插入
- `after`: 在段落之后插入
- `replace`: 替换段落

**实现细节**：
```dart
// 1. 获取章节内容
final currentContent = await _databaseService.getCachedChapter(chapterId);

// 2. 分割为段落
final paragraphs = currentContent.split('\n')
    .where((p) => p.trim().isNotEmpty)
    .toList();

// 3. 创建标记
final illustrationMarkup = MediaMarkupParser.createIllustrationMarkup(taskId);
// 结果: "[!插图!](20250130_123456_abc123)"

// 4. 根据位置插入
switch (insertionPosition) {
  case 'before':
    paragraphs.insert(targetIndex, illustrationMarkup);
    break;
  case 'after':
    paragraphs.insert(targetIndex + 1, illustrationMarkup);
    break;
  case 'replace':
    paragraphs[targetIndex] = illustrationMarkup;
    break;
}

// 5. 保存
final newContent = paragraphs.join('\n');
await _databaseService.updateChapterContent(chapterId, newContent);
```

### 5. 显示插图内容

**文件**：`paragraph_widget.dart`

**流程**：
```dart
Widget build(BuildContext context) {
  // 1. 检查是否为媒体标记
  if (MediaMarkupParser.isMediaMarkup(widget.paragraph)) {
    return _buildIllustrationWidget();
  }

  // 2. 否则显示普通文本
  return _buildTextWidget();
}
```

**插图Widget结构**：
```
_buildIllustrationWidget()
├── 插图标题 ("场景插图 1/4")
├── 插图内容
│   ├── 加载中状态
│   ├── 图片网格 (1-4张图片)
│   └── 错误提示
└── 编辑模式：显示标记文本
```

### 6. 图片交互操作

**Mixin**：`IllustrationHandlerMixin`

**支持的交互**：

#### 6.1 点击图片
```dart
handleImageTap(taskId, imageUrl, imageIndex) {
  // 显示功能对话框
  IllustrationActionDialog.show()
    ├─ 再来几张 (regenerate)
    └─ 生成视频 (video)
}
```

#### 6.2 再来几张
```dart
regenerateMoreImages(taskId) {
  // 1. 显示数量选择对话框
  GenerateMoreDialog.show()

  // 2. 调用API重新生成
  _apiService.regenerateSceneIllustrationImages(
    taskId: taskId,
    count: count,
    modelName: modelName,
  )

  // 3. 更新状态为processing
}
```

#### 6.3 生成视频
```dart
generateVideoFromSpecificImage(taskId, imageUrl, imageIndex) {
  // 1. 显示视频输入对话框
  VideoInputDialog.show()

  // 2. 调用API生成视频
  _apiService.generateVideoFromImage(
    imgName: fileName,
    userInput: userInput,
  )
}
```

#### 6.4 删除插图
```dart
deleteIllustrationByTaskId(taskId) {
  // 1. 从章节内容中移除标记
  _removeIllustrationMarkup(taskId)

  // 2. 删除数据库记录
  _databaseService.deleteSceneIllustration(id)
}
```

## 🗂️ 数据模型

### SceneIllustration
```dart
class SceneIllustration {
  final int id;
  final String novelUrl;
  final String chapterId;
  final String taskId;        // 唯一任务ID
  final String content;        // 用户输入的场景描述
  final String roles;          // JSON字符串（不常用）
  final int imageCount;        // 图片数量
  final String status;         // pending | processing | completed | failed
  final List<String> images;   // 图片URL列表
  final String? prompts;      // AI生成的提示词
  final DateTime createdAt;
  final DateTime? completedAt;
}
```

### MediaMarkup
```dart
class MediaMarkup {
  final String type;      // 媒体类型：插图、视频
  final String id;        // 媒体ID：taskId、videoId
  final String fullMarkup; // 完整标记：[!插图!](xxx)
  final int start;        // 在文本中的起始位置
  final int end;          // 在文本中的结束位置

  bool get isIllustration => type == '插图';
  bool get isVideo => type == '视频';
}
```

## 🔧 核心工具类

### MediaMarkupParser

**职责**：解析和处理媒体标记

**主要方法**：
```dart
// 解析文本中的所有标记
List<MediaMarkup> parseMediaMarkup(String text)

// 创建插图标记
String createIllustrationMarkup(String taskId)
// 返回: "[!插图!](taskId)"

// 检查是否为标记
bool isMediaMarkup(String text)

// 移除所有标记
String removeMediaMarkup(String text)
```

**正则表达式**：
```dart
static final RegExp _mediaMarkupRegex =
    RegExp(r'\[!([^!]+)!\]\(([^)]+)\)');
// 匹配: [!类型!](ID)
```

### CharacterMatcher

**职责**：查找章节中出现的角色

**方法**：
```dart
static List<int> findAppearingCharacterIds(
  String content,
  List<Character> characters,
)
```

## 📊 数据库表结构

### scene_illustrations
```sql
CREATE TABLE scene_illustrations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  novel_url TEXT NOT NULL,
  chapter_id TEXT NOT NULL,
  task_id TEXT NOT NULL UNIQUE,
  content TEXT NOT NULL,
  roles TEXT,
  image_count INTEGER NOT NULL,
  status TEXT NOT NULL,
  images TEXT,  -- JSON数组
  prompts TEXT,
  created_at INTEGER NOT NULL,
  completed_at INTEGER
);
```

### chapter_cache
```sql
CREATE TABLE chapter_cache (
  chapter_id TEXT PRIMARY KEY,
  content TEXT NOT NULL,  -- 包含插图标记
  cached_at INTEGER NOT NULL
);
```

## 🌐 API交互

### 1. 创建插图
```http
POST /api/scene-illustration/create
Content-Type: application/json

{
  "chapters_content": "段落文本内容",
  "task_id": "20250130_123456_abc123",
  "roles": [
    {"name": "张三", "gender": "男", "age": 25},
    {"name": "李四", "gender": "女", "age": 23}
  ],
  "num": 2,
  "model_name": "FLUX.1-schnell"
}

Response:
{
  "status": "pending",
  "message": "任务已创建"
}
```

### 2. 重新生成图片
```http
POST /api/scene-illustration/regenerate
Content-Type: application/json

{
  "task_id": "20250130_123456_abc123",
  "count": 2,
  "model_name": "FLUX.1-schnell"
}
```

### 3. 生成视频
```http
POST /api/video/generate-from-image
Content-Type: application/json

{
  "img_name": "image_001.png",
  "user_input": "视频描述",
  "model_name": ""
}
```

## 🔄 状态流转

### 插图任务状态
```
pending → processing → completed
                   ↓
                 failed
```

### 视频生成状态
```
空闲 → 生成中 → 完成/失败
```

## 🎨 UI组件层次

```
ReaderScreen
  └─ ParagraphWidget
       ├─ _buildTextWidget()        // 普通段落
       └─ _buildIllustrationWidget() // 插图标记
            ├─ 标题
            ├─ SceneImagePreview     // 图片预览
            │    ├─ 加载状态
            │    ├─ 图片网格
            │    └─ 错误状态
            └─ 标记文本（编辑模式）
```

## 📝 关键设计决策

### 1. 为什么使用标记系统？
- ✅ 轻量级：纯文本存储，无需二进制数据
- ✅ 可读性：章节内容易于查看和编辑
- ✅ 灵活性：支持多种媒体类型（插图、视频等）
- ✅ 易维护：删除时直接移除标记即可

### 2. 为什么基于段落索引？
- ✅ 精确定位：避免文本匹配误差
- ✅ 性能优秀：无需遍历查找
- ✅ 稳定可靠：段落内容改变时仍然有效

### 3. 为什么分离Service和Mixin？
- ✅ 职责分离：
  - Service：业务逻辑（创建、删除、更新）
  - Mixin：UI交互（对话框、状态管理）
- ✅ 复用性：Service可在其他地方使用
- ✅ 测试友好：Service易于单元测试

## ❌ 当前缺失的单元测试

### 核心服务测试
- ❌ `scene_illustration_service_test.dart`
  - 创建插图任务
  - 插入标记逻辑
  - 删除插图逻辑
  - API调用Mock

### 工具类测试
- ❌ `media_markup_parser_test.dart`
  - 标记解析
  - 标记生成
  - 边界情况

### Widget测试
- ❌ `scene_illustration_dialog_test.dart`
  - 对话框UI
  - 角色预选逻辑
  - 表单提交

### 模型测试
- ❌ `scene_illustration_test.dart`
  - 模型序列化/反序列化
  - taskId生成

## ✅ 测试建议优先级

### P0 - 核心逻辑（必须）
1. **MediaMarkupParser测试**
   - 标记解析准确性
   - 标记生成格式
   - 边界情况处理

2. **SceneIllustrationService测试**
   - 插入标记逻辑
   - 段落索引验证
   - 错误处理

### P1 - 重要功能（推荐）
3. **SceneIllustration模型测试**
   - 数据序列化
   - taskId生成唯一性

4. **IllustrationHandlerMixin测试**
   - 交互流程
   - API调用

### P2 - 可选功能
5. **Widget测试**
   - UI组件渲染
   - 用户交互

## 📋 下一步行动

请确认：
1. 是否需要我为上述缺失的测试创建单元测试？
2. 优先级是否合理？需要调整吗？
3. 是否有其他特定的测试场景需要覆盖？
