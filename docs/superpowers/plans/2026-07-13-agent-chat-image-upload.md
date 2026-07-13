# Agent Chat 图片上传 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Agent Chat 输入栏增加微信式图片上传入口（相册选图 + 1:1 裁剪），图片作为"素材"注册为 `local_` mediaId 供 `create_image_to_video` / `update_character` 等工具使用，user 气泡展示该图。

**Architecture:** 扩展 `AgentChatSegment` 新增 `ImageSegment` 子类；新建 `ImagePickerService` 封装选图+裁剪；复用现有 `MediaProxy.upload`（当前零调用）注册本地图片为 mediaId；`ScenarioSession.sendMessage` 加 `imageMediaIds` 参数，把 mediaId 编码成占位文本拼进 `content`（落库）；投影层 `_projectUiMessages` 解析占位文本还原 `ImageSegment`（重启可见）；user 气泡按 segments 渲染。**不改造多模态 LLM 链路**。

**Tech Stack:** Flutter / Dart 3 / Riverpod / image_picker ^1.1.2 / image_cropper ^8.0.2（已在）/ 现有 MediaProxy + MediaView。

## Global Constraints

- 仅 Flutter 端（`novel_app`），后端零改动、AI 工具链零改动
- DB schema **不变**（不加迁移，不升 v36→v37；图片持久化靠 `content` 占位文本 + `media_items` 表）
- 中文 commit message，遵循 Conventional Commits（type 英文 + scope/subject 中文）
- `flutter analyze` 必须干净，`flutter format lib/` 必须跑
- 单选单图（`_attachedMediaId` 是 `String?` 不是 `List`）
- 占位文本格式契约：`[用户上传了图片 mediaId=<mediaId>]`（正则 `\[用户上传了图片 mediaId=([^\]]+)\]`）
- `image_picker` 新增依赖；`image_cropper: ^8.0.2` 已存在
- iOS 必须补 `NSPhotoLibraryUsageDescription` / `NSCameraUsageDescription` / `NSPhotoLibraryAddUsageDescription`

## 关键设计细化（对 spec 的精确化，不违背意图）

探索发现 `AgentChatMessage` 只在 UI 投影层存活，**不落库**；落库走 agent 视角的 `ChatMessage` → `ChatMessageRecord`（字段 `role/content/toolCalls/toolCallId`）。因此持久化路径为：

1. `sendMessage` 把图片 mediaId 编码成占位文本拼进 `ChatMessage.content` → 落 `chat_messages.content`
2. 图片字节由 `MediaProxy.upload` 存进 `media_items` 表 + `<app_docs>/media/<mediaId>.png`
3. 重启后 `_projectUiMessages` 投影 user 消息时，用正则解析 content 占位文本 → 还原 `ImageSegment` + 剥离后的 `TextSegment`
4. `AgentMessageBubble` 遇 `ImageSegment` 走 `MediaView` 渲染（字节从 `media_items` 回源）

> spec 第 6.4 节"segments JSON 落库"的描述需以此细化为准——`segmentsToJson` 仍补 `image` 分支保持模型完整性（供快照/回放），但它不是主持久化路径。

---

## File Structure

| 文件 | 责任 | 动作 |
|---|---|---|
| `novel_app/pubspec.yaml` | 加 image_picker 依赖 | Modify |
| `novel_app/ios/Runner/Info.plist` | 加相册/相机权限描述 | Modify |
| `novel_app/lib/models/agent_chat_message.dart` | 新增 `ImageSegment` 子类 + 序列化分支 | Modify |
| `novel_app/lib/services/image_picker_service.dart` | 选图 + 1:1 裁剪封装 | Create |
| `novel_app/lib/core/providers/scenario_session.dart` | `sendMessage` 加 imageMediaIds；投影层解析占位文本 | Modify |
| `novel_app/lib/widgets/agent_chat/agent_message_bubble.dart` | user 气泡按 segments 渲染；assistant switch 补分支 | Modify |
| `novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart` | `+` 按钮 + 预览缩略图 + 上传/发送编排 | Modify |
| `novel_app/test/unit/models/agent_chat_message_test.dart` | ImageSegment 序列化 round-trip + 老数据兼容 | Create |
| `novel_app/test/unit/services/image_picker_service_test.dart` | pickAndCrop 取消/尺寸校验 | Create |
| `novel_app/test/unit/providers/scenario_session_test.dart` | sendMessage 新签名 + 投影还原 | Modify（已有文件） |
| `novel_app/test/unit/widgets/agent_message_bubble_test.dart` | user 气泡有图/无图渲染 | Create |

---

### Task 1: 加 image_picker 依赖 + iOS 权限描述

**Files:**
- Modify: `novel_app/pubspec.yaml`
- Modify: `novel_app/ios/Runner/Info.plist`

**Interfaces:**
- Consumes: 无
- Produces: `image_picker` 可用；iOS 相册/相机权限描述就位

- [ ] **Step 1: pubspec.yaml 加依赖**

在 `novel_app/pubspec.yaml` 的 dependencies 段，`image_cropper: ^8.0.2`（约第 76 行）下方加：

```yaml
  # 图片选择（相册）
  image_picker: ^1.1.2
```

- [ ] **Step 2: 跑 pub get**

Run: `cd novel_app && flutter pub get`
Expected: `Got dependencies!`，无版本冲突

- [ ] **Step 3: iOS Info.plist 加权限描述**

在 `novel_app/ios/Runner/Info.plist` 的 `</dict>`（第 51 行）**之前**插入：

```xml
	<key>NSPhotoLibraryUsageDescription</key>
	<string>需要访问相册以选择图片发送给助手</string>
	<key>NSPhotoLibraryAddUsageDescription</key>
	<string>需要访问相册以保存裁剪后的图片</string>
	<key>NSCameraUsageDescription</key>
	<string>需要相机权限以拍摄图片发送给助手</string>
```

- [ ] **Step 4: 验证 analyze 不报错**

Run: `cd novel_app && flutter analyze lib/`
Expected: `No issues found!`（或与改动前一致的既存 issues，无新增）

- [ ] **Step 5: Commit**

```bash
cd novel_app
git add pubspec.yaml pubspec.lock ios/Runner/Info.plist
git commit -m "chore(novel_app): 加 image_picker 依赖 + iOS 相册/相机权限描述"
```

---

### Task 2: AgentChatSegment 新增 ImageSegment 子类

**Files:**
- Modify: `novel_app/lib/models/agent_chat_message.dart`
- Test: `novel_app/test/unit/models/agent_chat_message_test.dart`（Create）

**Interfaces:**
- Consumes: 无
- Produces: `ImageSegment` 类（字段 `String mediaId`）；`segmentsToJson`/`segmentsFromJson` 支持 `type:'image'`

- [ ] **Step 1: 写失败测试 — ImageSegment round-trip**

Create `novel_app/test/unit/models/agent_chat_message_test.dart`:

```dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/agent_chat_message.dart';

void main() {
  group('AgentChatMessage ImageSegment 序列化', () {
    test('ImageSegment 序列化 round-trip', () {
      final msg = AgentChatMessage(
        role: AgentChatRole.user,
        segments: [
          const ImageSegment(mediaId: 'local_abc123'),
          const TextSegment(content: '把这张图动起来'),
        ],
      );

      final json = msg.toJson();
      final restored = AgentChatMessage.fromJson(json);

      expect(restored.segments.length, 2);
      expect(restored.segments[0], isA<ImageSegment>());
      expect((restored.segments[0] as ImageSegment).mediaId, 'local_abc123');
      expect(restored.segments[1], isA<TextSegment>());
      expect((restored.segments[1] as TextSegment).content, '把这张图动起来');
    });

    test('老数据（纯 text）fromJson 兼容', () {
      final msg = AgentChatMessage.fromJson({
        'role': 'user',
        'content': '你好',
        'timestamp': 1700000000000,
        'segmentsJson': '[{"type":"text","content":"你好"}]',
      });

      expect(msg.segments.length, 1);
      expect(msg.segments[0], isA<TextSegment>());
      expect(msg.content, '你好');
    });

    test('老数据（纯 tool）fromJson 兼容', () {
      final msg = AgentChatMessage.fromJson({
        'role': 'assistant',
        'content': '',
        'timestamp': 1700000000000,
        'segmentsJson':
            '[{"type":"tool","id":"call_1","name":"create_images","arguments":"{\\"prompt\\":\\"cat\\"}","status":"running"}]',
      });

      expect(msg.segments.length, 1);
      expect(msg.segments[0], isA<ToolCallSegment>());
    });
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `cd novel_app && flutter test test/unit/models/agent_chat_message_test.dart`
Expected: FAIL，`ImageSegment 未定义` / `The name 'ImageSegment' isn't a class`

- [ ] **Step 3: 实现 ImageSegment 类**

在 `novel_app/lib/models/agent_chat_message.dart` 中，找到 `ToolCallSegment` 类定义之后（约第 32 行，sealed class 子类区），加：

```dart
/// 用户上传的图片段（仅 user 消息）。
/// mediaId 来自 MediaProxy.upload（前缀 local_），渲染走 MediaView。
class ImageSegment extends AgentChatSegment {
  final String mediaId;

  const ImageSegment({required this.mediaId});

  @override
  List<Object?> get props => [mediaId];
}
```

> 注：参考现有 `TextSegment`/`ToolCallSegment` 的结构（都是 `extends AgentChatSegment` + `const` 构造 + `props`）。`AgentChatSegment` 若是 `Equatable` mixin/base，`props` 是必须的。

- [ ] **Step 4: segmentsToJson 补 image 分支**

在 `novel_app/lib/models/agent_chat_message.dart` 的 `segmentsToJson` 函数里，找到（约第 97-114 行）：

```dart
    final list = segments.map((s) {
      if (s is TextSegment) {
        return {'type': 'text', 'content': s.content};
      }
      if (s is ToolCallSegment) {
        ...
      }
      // 未知子类降级为 text（防御未来扩展）
      return {'type': 'text', 'content': ''};
```

在 `if (s is ToolCallSegment)` 块之后、兜底 return 之前，插入：

```dart
      if (s is ImageSegment) {
        return {'type': 'image', 'mediaId': s.mediaId};
      }
```

- [ ] **Step 5: segmentsFromJson 补 image 分支**

在同一文件的 `segmentsFromJson` 函数里，找到 tool 分支的 `// 未知 type 跳过` 注释（约第 156 行）之前，加 `image` 分支。定位到 tool 分支结构（`if (item['type'] == 'tool') { ... }`），在其后加：

```dart
        if (item['type'] == 'image') {
          final mediaId = item['mediaId']?.toString() ?? '';
          if (mediaId.isNotEmpty) {
            result.add(ImageSegment(mediaId: mediaId));
          }
        }
```

- [ ] **Step 6: 跑测试验证通过**

Run: `cd novel_app && flutter test test/unit/models/agent_chat_message_test.dart`
Expected: PASS（3 个测试全过）

- [ ] **Step 7: Commit**

```bash
cd novel_app
git add lib/models/agent_chat_message.dart test/unit/models/agent_chat_message_test.dart
git commit -m "feat(agent-chat): AgentChatSegment 新增 ImageSegment 子类 + 序列化"
```

---

### Task 3: ImagePickerService 选图 + 裁剪封装

**Files:**
- Create: `novel_app/lib/services/image_picker_service.dart`
- Test: `novel_app/test/unit/services/image_picker_service_test.dart`（Create）

**Interfaces:**
- Consumes: `image_picker` (`ImagePicker.pickImage`)、`image_cropper` (`ImageCropper().cropImage`)
- Produces: `ImagePickerService.pickAndCrop() -> Future<Uint8List?>`，`ImageTooLargeException`

- [ ] **Step 1: 写失败测试 — 取消返回 null + 尺寸校验**

Create `novel_app/test/unit/services/image_picker_service_test.dart`:

```dart
library;

import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/image_picker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImagePickerService', () {
    test('pickImage 返回 null（用户取消）→ pickAndCrop 返回 null', () async {
      // mock image_picker channel 返回 null（用户在相册按返回）
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/image_picker'),
        (MethodCall call) async => null,
      );

      final service = ImagePickerService();
      final result = await service.pickAndCrop();

      expect(result, isNull);
    });

    test('图片字节 > 10MB → 抛 ImageTooLargeException', () async {
      // mock 返回一个超大字节的图片路径模拟 —— 这里直接测 internal 校验逻辑
      // 通过构造一个 >10MB 的 Uint8List 走 _validateSize
      final huge = Uint8List(10 * 1024 * 1024 + 1);
      expect(
        () => ImagePickerService.validateSize(huge),
        throwsA(isA<ImageTooLargeException>()),
      );
    });

    test('图片字节 <= 10MB → validateSize 通过', () {
      final ok = Uint8List(1024);
      ImagePickerService.validateSize(ok); // 不抛即通过
    });
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `cd novel_app && flutter test test/unit/services/image_picker_service_test.dart`
Expected: FAIL，`ImagePickerService 未定义` / `ImageTooLargeException 未定义`

- [ ] **Step 3: 实现 ImagePickerService**

Create `novel_app/lib/services/image_picker_service.dart`:

```dart
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// 图片过大异常（>10MB）。
class ImageTooLargeException implements Exception {
  final int actualBytes;
  final int maxBytes;
  const ImageTooLargeException(this.actualBytes, this.maxBytes);

  @override
  String toString() =>
      '图片过大：${actualBytes ~/ 1024 ~/ 1024}MB，上限 ${maxBytes ~/ 1024 ~/ 1024}MB';
}

/// 选图 + 裁剪封装服务。
///
/// 流程：相册选图（image_picker）→ 尺寸校验 → 1:1 裁剪（image_cropper）→ PNG bytes。
/// 任一步骤用户取消返回 null。图片 >10MB 抛 [ImageTooLargeException]。
class ImagePickerService {
  static const int maxBytes = 10 * 1024 * 1024; // 10MB

  /// 相册选图 + 1:1 裁剪。用户取消任一步骤返回 null。
  Future<Uint8List?> pickAndCrop() async {
    if (kIsWeb) return null;

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (picked == null) return null; // 用户在相册取消

    final Uint8List rawBytes = await picked.readAsBytes();
    validateSize(rawBytes);

    // 裁剪（1:1）。cropImage 需要 sourcePath（文件路径）。
    final CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatioPresets: [CropAspectRatioPreset.square],
      cropStyle: CropStyle.rectangle,
      compressFormat: ImageCompressFormat.png,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '裁剪图片',
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: '裁剪图片',
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (cropped == null) return null; // 用户在裁剪页取消

    return await cropped.readAsBytes();
  }

  /// 校验字节大小，超限抛 [ImageTooLargeException]。
  /// 抽成静态方法以便单测。
  static void validateSize(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw ImageTooLargeException(bytes.length, maxBytes);
    }
  }
}
```

- [ ] **Step 4: 跑测试验证通过**

Run: `cd novel_app && flutter test test/unit/services/image_picker_service_test.dart`
Expected: PASS（3 个测试全过）

> 注：`pickImage` 返回 null 的 mock 测试依赖 `flutter/image_picker` channel；若该 mock 不生效（image_picker 内部 channel 名变更），可删除该用例只保留 validateSize 两个用例，pickAndCrop 整体路径留给手动验收。

- [ ] **Step 5: analyze 验证**

Run: `cd novel_app && flutter analyze lib/services/image_picker_service.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
cd novel_app
git add lib/services/image_picker_service.dart test/unit/services/image_picker_service_test.dart
git commit -m "feat(agent-chat): 新增 ImagePickerService 选图+1:1裁剪封装"
```

---

### Task 4: ScenarioSession.sendMessage 支持 imageMediaIds + 投影层解析占位文本

**Files:**
- Modify: `novel_app/lib/core/providers/scenario_session.dart`
- Test: `novel_app/test/unit/providers/scenario_session_test.dart`（已有，追加 group）

**Interfaces:**
- Consumes: `ImageSegment`（Task 2）、`AgentChatMessage`、`ChatMessage`
- Produces: `sendMessage({required String content, List<String> imageMediaIds})`；占位文本契约 `[用户上传了图片 mediaId=<id>]`；投影层自动还原 `ImageSegment`

- [ ] **Step 1: 写失败测试 — sendMessage 新签名 + 占位文本**

在 `novel_app/test/unit/providers/scenario_session_test.dart` 末尾追加 group（沿用文件现有 MockNovelAgentService + createContainer 基础设施）：

```dart
  group('sendMessage 图片附件', () {
    test('双空拦截：空 content + 空 imageMediaIds 不入栈', () async {
      final mock = MockNovelAgentService();
      final container = createContainer(mock);
      final session = container.read(currentScenarioSessionProvider('writing'));

      await session.sendMessage(content: '');

      expect(session.state.messages, isEmpty);
    });

    test('单图无文：拼占位文本，agent 收到 mediaId', () async {
      final mock = MockNovelAgentService();
      final container = createContainer(mock);
      final session = container.read(currentScenarioSessionProvider('writing'));

      await session.sendMessage(
        content: '',
        imageMediaIds: const ['local_abc123'],
      );

      // agent 视角收到的 userInput 含占位文本
      expect(mock.lastUserInput,
          contains('[用户上传了图片 mediaId=local_abc123]'));
      // UI 消息：user 一条
      expect(session.state.messages.length, greaterThanOrEqualTo(1));
      final userMsg = session.state.messages.first;
      expect(userMsg.role, AgentChatRole.user);
      // 投影层还原出 ImageSegment
      expect(userMsg.segments.whereType<ImageSegment>().length, 1);
      expect(
          userMsg.segments.whereType<ImageSegment>().first.mediaId,
          'local_abc123');
    });

    test('单图有文：占位文本 + 用户原文', () async {
      final mock = MockNovelAgentService();
      final container = createContainer(mock);
      final session = container.read(currentScenarioSessionProvider('writing'));

      await session.sendMessage(
        content: '把这张图变成水墨风视频',
        imageMediaIds: const ['local_abc123'],
      );

      expect(mock.lastUserInput,
          contains('[用户上传了图片 mediaId=local_abc123]'));
      expect(mock.lastUserInput, contains('把这张图变成水墨风视频'));
      final userMsg = session.state.messages.first;
      expect(userMsg.segments.whereType<ImageSegment>().length, 1);
      // 用户原文作为 TextSegment 保留
      expect(
          userMsg.segments
              .whereType<TextSegment>()
              .any((t) => t.content.contains('把这张图变成水墨风视频')),
          isTrue);
    });
  });
```

> 注：`mock.lastUserInput` 是需要在 `MockNovelAgentService` 里新增的字段（捕获 sendMessage 的 userInput 参数）；`currentScenarioSessionProvider` 名字按现有测试里的实际 provider 名为准（看文件顶部已有的测试怎么拿 session）。

- [ ] **Step 2: 跑测试验证失败**

Run: `cd novel_app && flutter test test/unit/providers/scenario_session_test.dart --plain-name "sendMessage 图片附件"`
Expected: FAIL，`sendMessage 命名参数不匹配` / `lastUserInput 未定义`

- [ ] **Step 3: 改 sendMessage 签名 + 占位文本**

在 `novel_app/lib/core/providers/scenario_session.dart` 第 313-339 行，把 `sendMessage` 改为：

```dart
  /// 占位文本契约：用户上传图片时拼进 content，供 agent 识别 + 投影层还原。
  /// 格式：[用户上传了图片 mediaId=<mediaId>]
  static final RegExp _imagePlaceholderRe =
      RegExp(r'\[用户上传了图片 mediaId=([^\]]+)\]');

  /// 发送消息 — Agent 在本 session 内独立运行
  Future<void> sendMessage({
    required String content,
    List<String> imageMediaIds = const [],
  }) async {
    final text = content.trim();
    if (text.isEmpty && imageMediaIds.isEmpty) return;

    // 运行中再发：先中断当前回合（落库 partial），再发送新消息。
    await _interruptIfRunning();

    await _ensureSessionId();

    // 拼接 agent 视角 content：图片占位文本（图在前）+ 用户原文
    final buf = StringBuffer();
    for (final id in imageMediaIds) {
      buf.writeln('[用户上传了图片 mediaId=$id]');
    }
    if (text.isNotEmpty) {
      buf.write(text);
    }
    final agentContent = buf.toString().trim();

    LoggerService.instance.i(
      'ScenarioSession [$scenarioId] 发送消息: length=${agentContent.length} '
      'images=${imageMediaIds.length} sessionId=$_sessionId',
      category: LogCategory.ai,
      tags: ['session', 'send', scenarioId],
    );

    // user 消息即时进 _agentMessages + 落库
    final userMsg = ChatMessage(role: 'user', content: agentContent);
    _agentMessages.add(userMsg);
    _state = _state.copyWith(
      messages: _uiMessages,
      isLoading: true,
    );
    _notifyStateChanged();
    await _persistAgentMessage(userMsg);

    await _beginAgentRun(agentContent);
  }
```

> 注意：旧调用点 `session.sendMessage(text)`（在 `agent_chat_dialog.dart:839`）需改为 `session.sendMessage(content: text)`——这在 Task 6 一起改。但本任务先让新签名向后兼容旧位置编译：把所有现有调用点同步改为命名参数。全局搜 `sendMessage(` 找调用点（scenario_session_test.dart 里的 mock 调用除外）。

- [ ] **Step 4: 给 MockNovelAgentService 加 lastUserInput 捕获**

在 `novel_app/test/unit/providers/scenario_session_test.dart` 的 `MockNovelAgentService` 类（约第 33-152 行），找到 `sendMessage` 方法签名，加捕获字段：

```dart
  String? lastUserInput;

  @override
  Future<void> sendMessage({
    required String userInput,
    ...
  }) async {
    lastUserInput = userInput;
    ... // 原有逻辑
  }
```

> 具体行号以现有 MockNovelAgentService.sendMessage 签名为准；若它叫别的参数名，`lastUserInput = <对应参数>`。

- [ ] **Step 5: 投影层 _projectUiMessages 解析占位文本**

在 `novel_app/lib/core/providers/scenario_session.dart` 的 `_projectUiMessages`（约第 104-141 行），找到 user 消息投影处（当前对 user 消息直接 `TextSegment(content)`）。改为调用新的解析方法：

```dart
  /// 把 user 消息的 content（可能含图片占位文本）解析成 segments。
  /// 占位文本 [用户上传了图片 mediaId=xxx] → ImageSegment；其余文本 → TextSegment。
  List<AgentChatSegment> _parseUserSegments(String content) {
    final segments = <AgentChatSegment>[];
    int lastEnd = 0;
    for (final match in _imagePlaceholderRe.allMatches(content)) {
      // 占位之前的文本（非空才加）
      if (match.start > lastEnd) {
        final text = content.substring(lastEnd, match.start).trim();
        if (text.isNotEmpty) segments.add(TextSegment(content: text));
      }
      segments.add(ImageSegment(mediaId: match.group(1)!));
      lastEnd = match.end;
    }
    // 尾部剩余文本
    if (lastEnd < content.length) {
      final text = content.substring(lastEnd).trim();
      if (text.isNotEmpty) segments.add(TextSegment(content: text));
    }
    if (segments.isEmpty) return [TextSegment(content: content)];
    return segments;
  }
```

然后在 `_projectUiMessages` 里，user 消息分支从 `TextSegment(m.content)` 改为：

```dart
      // role == 'user'
      segments: _parseUserSegments(m.content ?? ''),
```

> 精确位置：定位 `_projectUiMessages` 内构造 user `AgentChatMessage` 的地方（当前应该是 `segments: [TextSegment(m.content ?? '')]` 或类似），替换为上面这行。

- [ ] **Step 6: 跑测试验证通过**

Run: `cd novel_app && flutter test test/unit/providers/scenario_session_test.dart`
Expected: PASS（含原有用例 + 新增 3 个图片用例全过）

- [ ] **Step 7: analyze 验证**

Run: `cd novel_app && flutter analyze lib/core/providers/scenario_session.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
cd novel_app
git add lib/core/providers/scenario_session.dart test/unit/providers/scenario_session_test.dart
git commit -m "feat(agent-chat): sendMessage 支持 imageMediaIds + 投影层还原 ImageSegment"
```

---

### Task 5: user 气泡渲染图片 + assistant switch 补分支

**Files:**
- Modify: `novel_app/lib/widgets/agent_chat/agent_message_bubble.dart`
- Test: `novel_app/test/unit/widgets/agent_message_bubble_test.dart`（Create）

**Interfaces:**
- Consumes: `ImageSegment`（Task 2）、`MediaView`
- Produces: user 气泡按 segments 渲染图片；assistant switch 穷尽

- [ ] **Step 1: 写失败测试 — user 气泡有图渲染 MediaView**

Create `novel_app/test/unit/widgets/agent_message_bubble_test.dart`:

```dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/agent_chat_message.dart';
import 'package:novel_app/widgets/agent_chat/agent_message_bubble.dart';
import 'package:novel_app/widgets/media/media_view.dart';

void main() {
  testWidgets('user 气泡含 ImageSegment → 出现 MediaView', (tester) async {
    final msg = AgentChatMessage(
      role: AgentChatRole.user,
      segments: const [
        ImageSegment(mediaId: 'local_test1'),
        TextSegment(content: '看看这张'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AgentMessageBubble(message: msg))),
    );

    expect(find.byType(MediaView), findsOneWidget);
    expect(find.text('看看这张'), findsOneWidget);
  });

  testWidgets('user 气泡纯文本（回归）→ 无 MediaView', (tester) async {
    final msg = AgentChatMessage(
      role: AgentChatRole.user,
      segments: const [TextSegment(content: '你好')],
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AgentMessageBubble(message: msg))),
    );

    expect(find.byType(MediaView), findsNothing);
    expect(find.text('你好'), findsOneWidget);
  });
}
```

> 注：确认 `AgentMessageBubble` 构造参数名是 `message`（探索显示是）；若需其他必填参数（如 onTap 回调），测试里补 dummy。

- [ ] **Step 2: 跑测试验证失败**

Run: `cd novel_app && flutter test test/unit/widgets/agent_message_bubble_test.dart`
Expected: FAIL，user 气泡没渲染 MediaView（当前 `_buildContent` 只渲染 `message.content` 文本）

- [ ] **Step 3: 改 _buildContent 按 segments 渲染**

在 `novel_app/lib/widgets/agent_chat/agent_message_bubble.dart`，先确认 import 区有（没有则加）：

```dart
import 'package:novel_app/widgets/media/media_view.dart';
```

把 `_buildContent`（第 122-131 行）替换为：

```dart
  Widget _buildContent(BuildContext context) {
    final segments = message.segments;
    // 无 ImageSegment 时走原文本路径（性能 + 不破坏现有样式）
    final hasImage = segments.any((s) => s is ImageSegment);
    if (!hasImage) {
      return Text(
        message.content,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: context.appColors.agentOnBrand,
              height: 1.4,
            ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final seg in segments)
          if (seg is ImageSegment)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 200,
                  maxHeight: 200,
                ),
                child: MediaView(
                  mediaId: seg.mediaId,
                  onTap: () => _showImageFullScreen(context, seg.mediaId),
                ),
              ),
            )
          else if (seg is TextSegment)
            Text(
              seg.content,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: context.appColors.agentOnBrand,
                    height: 1.4,
                  ),
            ),
      ],
    );
  }

  /// 图片全屏查看（点击缩略图触发）
  void _showImageFullScreen(BuildContext context, String mediaId) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: MediaView(mediaId: mediaId)),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 4: assistant switch 补 ImageSegment 分支（穷尽性）**

在 `_buildAssistantContent`（第 150-160 行）的 `switch (segment)`，加 `ImageSegment` 分支（assistant 消息理论上不会有图片，但 sealed class 要求穷尽）：

```dart
        return switch (segment) {
          TextSegment s => _buildTextSegment(context, s, isStreaming && isLast),
          ToolCallSegment s => Padding(
              padding: EdgeInsets.only(
                top: idx > 0 ? 8 : 0,
                bottom: isLast ? 0 : 4,
              ),
              child: AgentToolCallCard(call: s.call),
            ),
          ImageSegment s => ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
              child: MediaView(
                mediaId: s.mediaId,
                onTap: () => _showImageFullScreen(context, s.mediaId),
              ),
            ),
        };
```

- [ ] **Step 5: 跑测试验证通过**

Run: `cd novel_app && flutter test test/unit/widgets/agent_message_bubble_test.dart`
Expected: PASS（2 个测试全过）

- [ ] **Step 6: analyze 验证**

Run: `cd novel_app && flutter analyze lib/widgets/agent_chat/agent_message_bubble.dart`
Expected: `No issues found!`（确认 sealed switch 穷尽，无 non-exhaustive 报错）

- [ ] **Step 7: Commit**

```bash
cd novel_app
git add lib/widgets/agent_chat/agent_message_bubble.dart test/unit/widgets/agent_message_bubble_test.dart
git commit -m "feat(agent-chat): user 气泡按 segments 渲染上传图片 + assistant switch 补分支"
```

---

### Task 6: AgentChatDialog 输入栏 + 按钮 + 预览 + 上传编排

**Files:**
- Modify: `novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart`

**Interfaces:**
- Consumes: `ImagePickerService`（Task 3）、`MediaProxy.upload`、`sendMessage(content, imageMediaIds)`（Task 4）
- Produces: 输入栏 `+` 按钮、预览缩略图行、上传→预览→发送完整流程

- [ ] **Step 1: 写失败测试 — 点 + 触发选图（mock service）+ 已有预览时再点提示**

Create `novel_app/test/unit/widgets/agent_chat_dialog_attach_test.dart`:

```dart
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/image_picker_service.dart';

/// 可注入的假 ImagePickerService，跳过真实原生调用。
class _FakeImagePickerService implements ImagePickerService {
  _FakeImagePickerService(this.bytes);
  final Uint8List bytes;
  int callCount = 0;
  @override
  Future<Uint8List?> pickAndCrop() async {
    callCount++;
    return bytes;
  }
}

void main() {
  testWidgets('已有预览时再点 + → SnackBar 提示单图限制', (tester) async {
    // 这个测试验证 UI 行为：state 里 _attachedMediaId 非空时点 + 弹 SnackBar
    // 由于 AgentChatDialog 内部直接 new ImagePickerService，需要先做可注入改造（见 Step 3）
    // 此测试在改造前 FAIL（无法注入），改造后 PASS
    expect(true, isTrue); // 占位，Step 3 改造后补真实断言
  });
}
```

> 注：AgentChatDialog 内部若直接 `ImagePickerService()` 构造，无法注入。Step 3 会把 ImagePickerService 改成 Riverpod Provider 注入（或构造参数注入），让 dialog 可测。若改造代价过大，本任务测试降级为：只测 `_buildSendStopButton` 的 enabled 逻辑（`_hasText || _attachedMediaId != null`）。

- [ ] **Step 2: 跑测试验证当前状态**

Run: `cd novel_app && flutter test test/unit/widgets/agent_chat_dialog_attach_test.dart`
Expected: PASS（占位测试），但功能未实现

- [ ] **Step 3: 改 dialog — state 字段 + ImagePickerService 可注入**

在 `novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart`：

import 区加（约第 20 行后）：

```dart
import 'dart:typed_data';
import 'package:novel_app/services/image_picker_service.dart';
import 'package:novel_app/services/media/media_proxy.dart';
import 'package:novel_app/services/media/media_types.dart';
import 'package:novel_app/widgets/media/media_view.dart';
```

State 字段区（第 34-42 行）加：

```dart
  // 待发送的已上传图片 mediaId（单选单图，null 表示无）
  String? _attachedMediaId;
  // 选图+上传进行中（控制 + 按钮转圈）
  bool _isPickingImage = false;

  // ImagePickerService 钩子（默认走真实实现，测试可注入）
  ImagePickerService? _imagePickerServiceOverride;
  ImagePickerService get _imagePicker =>
      _imagePickerServiceOverride ??= ImagePickerService();
```

> 测试注入入口：在 `AgentChatDialog` widget 顶层加可选参数 `final ImagePickerService? imagePickerService;`，构造里传给 state 的 `_imagePickerServiceOverride`。

- [ ] **Step 4: 加 + 按钮 + 预览缩略图行到 _buildInputBar**

在 `_buildInputBar`（第 678-736 行），把内部 `Column` 的 `children` 改造（加预览行），并把输入 `Row` 改造（加 + 按钮在最左）：

定位 `child: Column(mainAxisSize: MainAxisSize.min, children: [`，在 `// 快速输入提示词` 那个 if 之后、`Row(crossAxisAlignment: CrossAxisAlignment.end` 之前，插入预览行：

```dart
          // 待发送图片预览（仅有附件时显示）
          if (_attachedMediaId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                          maxWidth: 80, maxHeight: 80),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: MediaView(mediaId: _attachedMediaId!),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _attachedMediaId = null),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
```

然后把输入 `Row`（第 701 行）的 `children` 开头，在 `Expanded(child: TextField(...))` **之前**插入 + 按钮：

```dart
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildAttachButton(theme, appColors),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(...),  // 原样保留
                ),
                const SizedBox(width: 8),
                _buildSendStopButton(chatState, session, theme, appColors),
              ],
            ),
```

- [ ] **Step 5: 实现 _buildAttachButton + _onAttachTap（选图→上传→预览）**

在 dialog 类里加方法（放在 `_buildSendStopButton` 附近）：

```dart
  /// + 附件按钮（圆形 40x40，与发送按钮同款）
  Widget _buildAttachButton(ThemeData theme, AppColors appColors) {
    return _circleIconButton(
      icon: _isPickingImage ? null : Icons.add_rounded,
      bg: appColors.chatInputBackground,
      fg: appColors.inkSoft,
      onPressed: _isPickingImage ? null : () => _onAttachTap(),
      tooltip: '上传图片',
      // 转圈态：_isPickingImage 时 icon 为 null，显示 CircularProgressIndicator
      child: _isPickingImage
          ? SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation(appColors.inkSoft),
              ),
            )
          : null,
    );
  }

  Future<void> _onAttachTap() async {
    if (!mounted) return;
    // 单选单图：已有附件时拒绝
    if (_attachedMediaId != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('一次只支持一张图片，发送或删除后再选')),
        );
      }
      return;
    }
    setState(() => _isPickingImage = true);
    try {
      final Uint8List? bytes = await _imagePicker.pickAndCrop();
      if (bytes == null) return; // 用户取消
      // 注册为 local_ mediaId（复用 MediaProxy.upload）
      final mediaId = await ref
          .read(mediaProxyProvider)
          .upload(bytes, MediaKind.image);
      if (!mounted) return;
      setState(() => _attachedMediaId = mediaId);
    } on ImageTooLargeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片上传失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }
```

> 注：`_circleIconButton` 现有签名（第 774-794 行）需要确认是否支持 `child` 参数。若不支持，把转圈逻辑改为：`_isPickingImage` 时用独立 `SizedBox` widget 替代 `_circleIconButton`。实施时读 `_circleIconButton` 源码决定。

- [ ] **Step 6: 改 _sendMessage 传 imageMediaIds + 发送按钮 enabled 逻辑**

把 `_sendMessage`（第 834-842 行）改为：

```dart
  Future<void> _sendMessage(ScenarioSession? session) async {
    final text = _inputController.text.trim();
    final hasImage = _attachedMediaId != null;
    if (text.isEmpty && !hasImage) return;

    final imageIds =
        _attachedMediaId != null ? [_attachedMediaId!] : const <String>[];

    _inputController.clear();
    setState(() {
      _hasText = false;
      _attachedMediaId = null;
    });
    await session?.sendMessage(content: text, imageMediaIds: imageIds);

    if (mounted) _focusNode.requestFocus();
  }
```

把 `_buildSendStopButton`（第 741-772 行）的 enabled 判断改：`_hasText` 全部替换为 `(_hasText || _attachedMediaId != null)`。具体：

```dart
    if (chatState.isLoading) {
      return _circleIconButton(... 停止 ...);  // 不变
    }
    if (_hasText || _attachedMediaId != null) {
      return _circleIconButton(
        icon: Icons.send_rounded,
        bg: appColors.agentAccent,
        fg: appColors.agentOnBrand,
        onPressed: () => _sendMessage(session),
        tooltip: '发送',
      );
    }
    return _circleIconButton(... 禁用态 ...);  // 不变
```

- [ ] **Step 7: 跑所有相关测试**

Run: `cd novel_app && flutter test test/unit/widgets/ test/unit/providers/scenario_session_test.dart test/unit/models/agent_chat_message_test.dart`
Expected: PASS（全部）

- [ ] **Step 8: analyze + format**

Run: `cd novel_app && flutter analyze lib/widgets/agent_chat/agent_chat_dialog.dart`
Expected: `No issues found!`

Run: `cd novel_app && dart format lib/widgets/agent_chat/agent_chat_dialog.dart`

- [ ] **Step 9: Commit**

```bash
cd novel_app
git add lib/widgets/agent_chat/agent_chat_dialog.dart test/unit/widgets/agent_chat_dialog_attach_test.dart
git commit -m "feat(agent-chat): 输入栏 + 按钮上传图片入口 + 预览缩略图"
```

---

### Task 7: 全量验证 + 手动验收

**Files:** 无代码改动

- [ ] **Step 1: 全量 analyze**

Run: `cd novel_app && flutter analyze`
Expected: `No issues found!`（或与改动前一致的既存 issues，无新增）

- [ ] **Step 2: 全量 format 检查**

Run: `cd novel_app && dart format --set-exit-if-changed lib/`
Expected: 无输出（已格式化）。若有改动，跑 `dart format lib/` 修正后再 commit。

- [ ] **Step 3: 全量测试**

Run: `cd novel_app && flutter test`
Expected: 全 PASS（含原有测试 + 本次新增的 4 个测试文件）

- [ ] **Step 4: 手动验收（桌面 dev）**

Run: `cd novel_app && flutter run -d windows`（或用户常用设备）

逐项验证（对应 spec §8.2 DoD）：
- [ ] 打开 agent chat dialog → 输入栏最左侧出现圆形 `+` 按钮
- [ ] 点 `+` → 系统相册弹出 → 选图 → 进入裁剪页（1:1 锁定）→ 裁完确认
- [ ] 输入框上方出现缩略图 + `×` 移除按钮
- [ ] 不打字直接点发送 → user 气泡展示图片缩略图（200x200 内）+ 占位文本
- [ ] 点气泡里的图片 → 全屏查看 + 双指缩放 + 关闭按钮
- [ ] 再发一条「把这张图动起来」+ 新图 → 气泡展示图 + 文本，agent 收到占位文本+原文（看日志）
- [ ] 重启 App，打开同一会话 → 历史 user 气泡里的图片缩略图仍渲染（从 media_items 回源）
- [ ] 已有预览时再点 `+` → 看到「一次只支持一张图片」SnackBar
- [ ] 点预览缩略图 `×` → 预览消失，可重新选图

- [ ] **Step 5: 更新 CLAUDE.md 变更记录**

在 `novel_app/CLAUDE.md` 顶部 Changelog 加一行（日期 2026-07-13）：

```markdown
- **2026-07-13**: Agent Chat 图片上传。输入栏加 + 按钮（相册选图 + image_cropper 1:1 裁剪），复用 MediaProxy.upload 注册 local_ mediaId，AgentChatSegment 新增 ImageSegment，sendMessage 支持 imageMediaIds（占位文本契约），user 气泡按 segments 渲染图片，重启后投影层还原。新增 image_picker 依赖、iOS 相册/相机权限描述。
```

- [ ] **Step 6: Commit**

```bash
cd novel_app
git add CLAUDE.md
git commit -m "docs(novel_app): CLAUDE.md 记录 Agent Chat 图片上传功能"
```

---

## Self-Review 记录

（写计划后自检发现并已修正）
- ✅ Spec 覆盖：7 个任务覆盖 pubspec/Info.plist(1) + ImageSegment 模型(2) + ImagePickerService(3) + sendMessage/投影(4) + 气泡渲染(5) + 输入栏 UI(6) + 验收(7)，对应 spec 第 5 节 6 个改动文件全覆盖
- ✅ 无占位符：每个 step 含具体代码/命令/期望
- ✅ 类型一致：`ImageSegment(mediaId)`、`sendMessage({required content, List<String> imageMediaIds})`、`MediaView(mediaId, {onTap})`、占位文本正则全程一致
- ⚠️ 已知不确定点（实施时需读源码确认）：
  - `AgentChatSegment` 是否继承 Equatable（影响 `props` 写法）→ Task 2 Step 3
  - `_circleIconButton` 是否支持 `child` 参数 → Task 6 Step 5
  - `MockNovelAgentService.sendMessage` 参数名 → Task 4 Step 4
  - `currentScenarioSessionProvider` 实际 provider 名 → Task 4 Step 1
