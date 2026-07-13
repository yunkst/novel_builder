# Agent Chat 图片上传设计

- **日期**：2026-07-13
- **作者**：yedazhi（与 Claude Code 协同设计）
- **状态**：草案，待用户审阅
- **范围**：仅 Flutter 端（`novel_app`），后端零改动、AI 工具链零改动

## 1. 背景与目标

### 1.1 现状

Agent Chat（`lib/widgets/agent_chat/agent_chat_dialog.dart`）目前是纯文本对话界面：输入栏只有 `TextField` + 发送/停止按钮，**没有任何附件/图片入口**。整条消息链路从 UI 到 LLM HTTP body 全是纯字符串：

- `AgentChatMessage` 的 `segments` 只有 `TextSegment` / `ToolCallSegment`，无任何图片/附件字段
- 底层 `ChatMessage.toJson()`（`llm_provider.dart:184`）`content` 永远是字符串，不支持 `image_url` / 多模态
- `ScenarioSession.sendMessage(String content)`（`scenario_session.dart:314`）签名只吃纯文本

与此同时，"把本地图片字节注册成 mediaId"的能力**已经齐备但无人接线**：

- `MediaProxy.upload(Uint8List bytes, MediaKind kind)`（`services/media/media_proxy.dart:110`）—— 生成 `local_xxx` 前缀 mediaId + 存字节到 `MediaStore` + 写 `media_items` 表（`localOnly=1`），当前 lib 内 **0 个调用方**
- `MediaStore.saveBytes / getBytes`（`services/media/media_store.dart`）—— 文件存 `<app_docs>/media/<mediaId>.png`
- `MediaView`（`widgets/media/media_view.dart`）—— 通用媒体渲染 widget，吃 `mediaId + MediaKind`

另外 `image_cropper: ^8.0.2` 已在 `pubspec.yaml` 声明但全项目零调用；`image_picker` 连依赖都没加。

### 1.2 目标

在 Agent Chat 输入栏增加微信式"上传图片"入口，让用户能把一张本地图片作为**素材**交给 Agent：

- 点输入栏左侧 `+` → 系统相册选图 → 1:1 裁剪 → 输入框上方出现缩略图预览（带 `×` 移除）
- 发送时图片注册为 mediaId，user 气泡里展示该图，并把 mediaId 以占位文本形式送进 agent loop
- Agent 据此可调用 `create_image_to_video(sourceMediaId=...)` 让图"动起来"，或 `update_character(avatarMediaId=...)` 用作角色头像
- 重启 App 后历史消息里的图片气泡仍能渲染（落库持久化）

### 1.3 非目标（显式排除）

| 项 | 理由 |
|---|---|
| 多模态 LLM（让 AI 真正"看懂"图片内容） | 改造面跨 5+ 文件（`ChatMessage` / `toJson` / `LlmProvider.buildRequestBody` / OpenAI image_url 协议），本轮明确不做。留作 future work，但本轮的消息模型设计为未来扩展预留接口。 |
| 拍照来源 | 本轮只要相册 |
| 多图队列 | 本轮单选单图，简化状态机 |
| 语音 / 文件 / 视频附件 | 本轮只做图片 |
| 拖拽 / 复制粘贴图片入输入框 | 本轮只走 `+` 按钮 |
| 后端改动 | 后端 API、AI 工具链零改动 |
| `sendMessage` 多模态签名重构 | 占位文本方案足够，不重载底层 LLM 消息结构 |

## 2. 关键设计决策（已与用户确认）

| 维度 | 决策 | 依据 |
|------|------|------|
| 图片用途 | **当素材**（轻量路线） | 用户确认。不改造多模态链路，LLM 看不到图内容，只知道 mediaId |
| 图片来源 | **相册 + 1:1 裁剪** | 用户确认。`image_picker` 加依赖，`image_cropper` 终于有调用点 |
| 选图数量 | **单选单图** | 用户确认。一次一张，裁剪完发送即清空 |
| 流转方式 | **自动占位文本** | 用户确认。不依赖用户写 prompt，后台自动拼 `[用户上传了图片 mediaId=xxx]` |
| 持久化 | **落库** | 用户确认。要动 `AgentChatMessage` 序列化 |
| 气泡渲染 | **user 气泡展示图片** | 用户明确要求 |
| 扩展点 | **新增 `ImageSegment` 子类**（方案 A） | 与现有 `TextSegment` / `ToolCallSegment` sealed-class 套路一致，渲染/序列化/未来多模态扩展都单点 |

## 3. 方案选择

考虑过三个候选：

- **方案 A（采用）**：扩展 `AgentChatSegment` 新增 `ImageSegment { String mediaId }`。user 消息按 segments 渲染，遇 `ImageSegment` 走 `MediaView`。
- **方案 B（弃）**：在 `AgentChatMessage` 顶层加 `attachments: List<String>`，segments 不动。出现"两种附件表达"（text 走 segments，image 走 attachments），扩展性差。
- **方案 C（弃）**：把图片 base64 拼进 `ChatMessage.content` 字符串，渲染时正则解析。hack，破坏 `content` 语义，DB 体积爆炸。

**选 A 的理由**：现有 `TextSegment` / `ToolCallSegment` 就是为此设计的，加 `ImageSegment` 顺其自然；user 气泡渲染只动一处；落库 / 重启 / 未来多模态扩展都有现成路径（未来给 LLM 看图，只需在 `NovelAgentService` 喂 `ChatMessage` 时把 `ImageSegment` 转成 `image_url`，不动 UI 和持久化）。

## 4. 架构

```
┌──────────────────────────────────────────────────────────────┐
│ AgentChatDialog (_buildInputBar)                             │
│   [+ 附件按钮]  →  ImagePickerService.pickAndCrop()          │
│                       │                                       │
│                       ▼ Uint8List (PNG, 已 1:1 裁剪)          │
│            MediaProxy.upload(bytes, MediaKind.image)         │
│                  返回 "local_xxx" mediaId                      │
│                       │                                       │
│                       ▼                                       │
│   预览缩略图（输入框上方，带 × 移除）                           │
│   发送时 → ScenarioSession.sendMessage(content, imageMediaIds)│
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ ScenarioSession.sendMessage(content, imageMediaIds: [mediaId])│
│   构造 user AgentChatMessage:                                │
│     segments: [ImageSegment(mediaId), TextSegment(...)]      │
│   落库 chat_messages → 触发 _beginAgentRun                   │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ AgentMessageBubble._buildContent（user 气泡）                 │
│   遍历 segments:                                            │
│     ImageSegment → MediaView(mediaId, kind: image) 缩略图    │
│     TextSegment   → Text                                    │
└──────────────────────────────────────────────────────────────┘
```

**不变的部分**：
- agent 工具链路（`create_image_to_video`、`update_character` 等不动）
- 后端 API
- 多模态 LLM 视角（本轮保持纯文本，不喂 `image_url`；占位文本里带 mediaId，agent 看到后自行调工具）

## 5. 组件 / 文件改动

### 5.1 改动清单

| # | 文件 | 改动 | 估算行数 |
|---|---|---|---|
| 1 | `pubspec.yaml` | 加 `image_picker: ^1.1.2` | +1 |
| 2 | `lib/services/image_picker_service.dart` 🆕 | 封装 `pickAndCrop()`：相册 → `ImageCropper` 1:1 → 返回 `Uint8List?` | ~50 |
| 3 | `lib/models/agent_chat_message.dart` | 加 `ImageSegment` 子类 + `segmentsToJson`/`segmentsFromJson` 加 `type:'image'` 分支 | +15 |
| 4 | `lib/services/novel_agent/scenario_session.dart` | `sendMessage` 加可选参 `List<String> imageMediaIds`，user 消息拼 `ImageSegment` + 占位 `TextSegment` | +20 |
| 5 | `lib/widgets/agent_chat/agent_chat_dialog.dart` | 输入栏左侧加 `+` 按钮、预览缩略图行、调用 `ImagePickerService` + `MediaProxy.upload` | +60 |
| 6 | `lib/widgets/agent_chat/agent_message_bubble.dart` | `_buildContent` 按 segments 分支：`ImageSegment` → `MediaView`；`TextSegment` → `Text` | +25 |
| 7 | `ios/Runner/Info.plist`（如缺） | 补 `NSPhotoLibraryUsageDescription` | +1 |

总计约 +170 行，**1 个新文件，5-6 处编辑**。

### 5.2 新组件：`ImagePickerService`

```dart
class ImagePickerService {
  /// 相册选图 → image_cropper 1:1 裁剪 → 返回 PNG bytes。
  /// 任一步骤用户取消返回 null。
  /// 图片 >10MB 拒绝并抛 ImageTooLargeException。
  /// 相册/裁剪平台异常抛 ImagePickerException。
  Future<Uint8List?> pickAndCrop({
    CropAspectRatio ratio = CropAspectRatio.square,
  });
}
```

放 `lib/services/image_picker_service.dart`。Web 平台守卫：`if (kIsWeb) return null`。

### 5.3 `ImageSegment` 模型

```dart
class ImageSegment extends AgentChatSegment {
  final String mediaId;
  const ImageSegment({required this.mediaId});
  // toJson / fromJson / equals / hashCode
}
```

序列化形状：`{"type": "image", "mediaId": "local_xxx"}`。

### 5.4 MediaView 复用

`lib/widgets/media/media_view.dart` 已存在，直接吃 `mediaId + MediaKind`，不写新 widget。

## 6. 消息数据流

### 6.1 选图 → 裁剪 → 上传

```
User 点 "+"
   ↓
ImagePickerService.pickAndCrop()        // 相册 → 1:1 裁剪
   ↓ Uint8List (PNG)
MediaProxy.upload(bytes, MediaKind.image)  // → "local_abc123"
   ↓
setState(_attachedMediaId = "local_abc123")
   ↓
输入框上方出现缩略图 + × 按钮
```

### 6.2 发送

```dart
_sendMessage():
  final imageIds = _attachedMediaId != null ? [_attachedMediaId!] : [];
  final text = _inputController.text.trim();
  session?.sendMessage(content: text, imageMediaIds: imageIds);
  _inputController.clear();
  setState(_attachedMediaId = null);  // 清空预览
```

### 6.3 ScenarioSession 构造 user 消息

```dart
Future<void> sendMessage({
  required String content,
  List<String> imageMediaIds = const [],
}) async {
  if (content.isEmpty && imageMediaIds.isEmpty) return;  // 双空拦截

  final userMessage = AgentChatMessage(
    role: 'user',
    timestamp: DateTime.now(),
    segments: [
      // 图在前，文本在后（视觉上图片在上、文字在下）
      for (final id in imageMediaIds) ImageSegment(mediaId: id),
      if (content.isNotEmpty) TextSegment(content: content),
      // 只有图没文字 → 追加占位文本，让 agent 知道这张图
      if (content.isEmpty && imageMediaIds.isNotEmpty)
        TextSegment(content: '[用户上传了图片 mediaId=${imageMediaIds.first}]'),
    ],
  );
  // ... 后续 _beginAgentRun / 落库照旧
}
```

### 6.4 落库（segments JSON 形状）

```json
{
  "role": "user",
  "timestamp": 1700000000000,
  "segments": [
    {"type": "image", "mediaId": "local_abc123"},
    {"type": "text", "content": "[用户上传了图片 mediaId=local_abc123]"}
  ]
}
```

> 旧库（DB v32，`chat_messages` 表）已存的纯 text/tool 消息，`fromJson` 走 default 分支即可，不破坏老数据。

### 6.5 气泡渲染

```dart
Widget _buildContent(AgentChatMessage msg) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.end,  // user 气泡右对齐
    children: [
      for (final seg in msg.segments)
        if (seg is ImageSegment)
          MediaView(
            mediaId: seg.mediaId,
            kind: MediaKind.image,
            maxWidth: 200, maxHeight: 200,
            onTap: () => _showFullScreen(seg.mediaId),  // 点开看大图
          )
        else if (seg is TextSegment)
          Text(seg.content, style: ...)
        // ToolCallSegment 在 user 消息不会出现
    ],
  );
}
```

## 7. 错误处理 & 边界

### 7.1 错误路径

| 场景 | 处理 | 用户感知 |
|---|---|---|
| 选图被取消 | `pickAndCrop` 返回 `null` | 无感，关闭 picker |
| 相册无权限 | `image_picker` 抛 `PlatformException` → SnackBar「请到系统设置授予相册权限」 | 提示一次 |
| 裁剪失败 / 用户取消裁剪 | `ImageCropper.cropImage` 返回 `null`（取消）或抛异常 | 同上 |
| 上传到 MediaProxy 失败（写盘失败） | `MediaProxy.upload` 抛异常 → SnackBar「图片上传失败，请重试」 | 提示，预览清掉 |
| 图片太大（>10MB） | `pickAndCrop` 末尾尺寸检查，>10MB 拒绝并 SnackBar | 提示「图片过大，请选择小于 10MB」 |
| 选图过程中 session 关闭 | `mounted` 检查 + `_disposed` 标记 | 无感，丢弃 |
| 已有预览时再点 `+` | **拒绝**并 SnackBar「一次只支持一张图片，发送或删除后再选」 | 简单提示，不覆盖 |
| 发送中（agent 正在跑） | 复用现有 `_interruptIfRunning` 逻辑，不变 | 不变 |

### 7.2 边界规则

1. **单选单图**：`_attachedMediaId` 永远是 `String?`（不是 `List`），简化状态
2. **来源标识**：`mediaId` 前缀 `local_`（`MediaProxy.upload` 生成），区别于 `text2img` / `imageToVideo`
3. **占位文本规则**：
   - 无文 + 有图 → `[用户上传了图片 mediaId=xxx]`
   - 有文 + 有图 → `[用户上传了图片 mediaId=xxx]\n{用户原文}`
   - 有文 + 无图 → 原文（不变）
4. **老消息兼容**：纯文本 / 纯 tool 的旧消息走 sealed 模式匹配时走不到 `ImageSegment` 分支，渲染不变
5. **图片本地存储**：`MediaProxy.upload` 已把字节写到 `<app_docs>/media/local_xxx.png`，卸载 App 前不丢
6. **iOS 权限**：实施时确认 `ios/Runner/Info.plist` 有 `NSPhotoLibraryUsageDescription`，没有就补一行（标准做法）

### 7.3 降级

如果 `image_picker` 或 `image_cropper` 在某平台初始化失败（例如 Linux 不支持原生 picker）：`+` 按钮 hidden 或点击后提示「当前平台暂不支持上传图片」，不阻塞其他功能。

## 8. 测试 & 验收

### 8.1 测试矩阵

| # | 场景 | 类型 | 关键断言 |
|---|---|---|---|
| 1 | 选图 → 裁剪 → 上传 happy path | `ImagePickerService` test (mock MethodChannel) | 返回 `Uint8List`；mediaId 形如 `local_xxx` |
| 2 | 选图被取消 | 同上 | 返回 `null`，不抛 |
| 3 | `AgentChatMessage` `ImageSegment` 序列化 round-trip | unit | `{type:'image', mediaId:'local_x'}` ↔ `ImageSegment` |
| 4 | 老数据 `fromJson` 兼容（无 image 段） | unit | 老 JSON 解析不出错，segments 只有 text/tool |
| 5 | `sendMessage` 双空拦截 | `ScenarioSession` unit | 空 content + 空 imageMediaIds → 早返，不入栈 |
| 6 | `sendMessage` 单图无文 → 占位文本 | 同上 | segments = `[ImageSegment, TextSegment("[用户上传了图片 mediaId=...]")]` |
| 7 | `sendMessage` 单图有文 → 图文共存 | 同上 | segments 顺序 = 图 → 占位行 → 用户原文 |
| 8 | `sendMessage` 有文无图 → 不变 | 同上 | 行为完全等同于旧版 |
| 9 | user 气泡渲染：有图无文 | `AgentMessageBubble` widget test | MediaView 出现 1 次，Text 出现 1 次（占位文本） |
| 10 | user 气泡渲染：有图有文 | 同上 | MediaView + 占位 Text + 用户 Text 共 3 个子项 |
| 11 | user 气泡渲染：纯文本（回归） | 同上 | Text 出现 1 次，MediaView 0 次 |
| 12 | 缩略图点击放大 | widget test (tap) | 触发全屏查看回调 |
| 13 | 已有预览时再点 `+` | `AgentChatDialog` widget test | SnackBar 出现，「一次只支持一张图片」 |
| 14 | 移除预览（点 ×） | 同上 | 预览区消失，`_attachedMediaId == null` |
| 15 | 发送后预览自动清空 | 同上 | 发送后预览区消失，文本框清空 |

### 8.2 验收标准（DoD）

- [ ] `pubspec.yaml` 加 `image_picker`
- [ ] `ios/Runner/Info.plist` 含 `NSPhotoLibraryUsageDescription`（如缺失则补）
- [ ] 6 个文件按第 5 节改动完成
- [ ] 上 15 个测试全部通过
- [ ] `flutter analyze` 干净
- [ ] `flutter format lib/` 已跑
- [ ] 手动验收（桌面 dev 环境）：
  - 打开 agent chat dialog → 输入栏左侧出现 `+` 按钮
  - 点 `+` → 系统相册弹出 → 选图 → 进入裁剪页 → 裁完确认
  - 输入框上方出现缩略图 + `×`
  - 不打字直接点发送 → user 气泡展示图片 + 占位文本
  - 再开一段会话打字「把这张图变成水墨风视频」→ 发送 → agent 收到占位文本 + 用户原文
  - 重启 App，历史消息里的图片气泡仍能渲染
  - 在已有预览时再点 `+` → 看到「一次只支持一张图片」SnackBar

## 9. 未来扩展（不在本轮范围）

- **多模态 LLM**：未来要让 AI 真正"看懂"图片，只需在 `NovelAgentService.sendMessage` 构造 `ChatMessage` 时，把 `ImageSegment` 的 mediaId 解析成本地字节 → base64 / `image_url`，喂进 OpenAI vision 格式。UI 和持久化层不动。
- **多图队列**：`_attachedMediaId` 升级为 `List<String>`，预览行支持横向滚动。
- **拍照来源**：`ImagePickerService` 加 `ImageSource.camera` 路径。
- **拖拽 / 粘贴**：输入框加 `onDrop` / 粘贴监听。
- **音频 / 文件附件**：新增 `AudioSegment` / `FileSegment`，沿用 sealed-class 套路。
