# 小说封面媒体化设计

- **日期**：2026-07-10
- **作者**：yedazhi（与 Claude Code 协同设计）
- **状态**：草案，待用户审阅
- **范围**：仅 Flutter 端（`novel_app`），后端零改动

## 1. 背景与目标

### 1.1 现状

小说封面目前由 `NovelCover` widget 程序化绘制（按书名 hashCode 选 8 套色板之一，绘制首字/竖排 + 装饰），或读取 `Novel.coverUrl`（网络 URL，由已删除的旧爬虫带入，2026-07-08 后基本为 null）。封面与 AI 媒体体系（`MediaProxy` / `MediaStore` / `MediaView` / `media_items` 表）**完全未打通**。

与此同时，角色头像已经完成媒体化（v34 迁移新增 `characters.avatarMediaId`，配套 `AvatarMedia` widget、`update_character.avatarMediaId` 工具字段）。这是一套可直接镜像复用的样板。

### 1.2 目标

让小说写作场景的 Agent 具备"修改小说封面"的能力：

- 用户在 Agent Chat 里说"给《XXX》画个封面" / "换个封面" / "恢复默认封面"
- LLM 调 `create_images`（或 `create_image_to_video`）生成媒体，拿到 `mediaId`
- LLM 调新增的 `set_novel_cover` 工具把 `mediaId` 写入小说元数据
- 书架卡片自动显示该媒体（图或视频），与角色头像体验一致

### 1.3 非目标（显式排除）

| 项 | 理由 |
|---|---|
| 提取"实体-媒体绑定"共用抽象 | 三个实体（角色头像 / 小说封面 / 未来章节插图）只共享基础设施（`MediaProxy` 等），不共享业务代码；提前抽象是伪复用。未来章节插图项目来时再各自实现，回头评估是否抽取。 |
| 章节内场景插图 | 本轮不做，也不预留扩展点。 |
| BookshelfScreen 上的"换封面"按钮 | 触发方式限定为仅 AI Agent（用户通过 Chat 说话）。 |
| 书名叠加到 AI 封面图上 | 已决定不叠加；书名在书架标题区独立显示。 |
| 程序化封面装饰叠加到 AI 封面图上 | 已决定 AI 命中时不叠加任何程序化装饰。 |
| 后端改动 | 后端 `text2img` / `image-to-video` API 已存在且不变。 |

## 2. 关键设计决策（已与用户确认）

| 维度 | 决策 | 依据 |
|------|------|------|
| 字段策略 | 保留 `bookshelf.coverUrl` 列不动，**新增 `coverMediaId` 列** | 用户确认 `coverUrl` 实际无任何写入点，但保留旧列以减小迁移风险 |
| 工具粒度 | 专用工具 `set_novel_cover` | 与角色头像（专用 `avatarMediaId` 字段）平级，语义清晰 |
| 媒体范围 | 不区分图/视频，统一由 `MediaView` 按 `media_items.kind` 自动渲染 | 用户：媒体统一 id 的设计，无需区分 |
| 触发点 | 仅 AI Agent（Agent Chat） | 用户：现有 Chat 能说话起步 |
| Prompt 来源 | LLM 自由生成 | 已有 `patch_memory` 跨会话学偏好，不预设风格 |
| AI 封面图形态 | 不含文字 | 用户：书名已能在 UI 展示，不必叠加到封面 |
| 加载失败降级 | 复用 `MediaView` 状态机 | 与头像一致 |
| "不拉伸"约束 | `BoxFit.cover`（保持原比例，多余部分裁掉） | 用户明确："保持原比例，但多余部分裁掉" |

## 3. 显式约束：媒体展示不可拉伸

> 用户原话："不管是头像还是视频，展示的时候，不可以为了兼容展示区域进行拉伸，仅展示可见区域部分。"

**语义澄清**："拉伸"指 `BoxFit.fill` 那种**变形拉伸**（破坏纵横比），用户禁止；"仅展示可见区域"指 `BoxFit.cover` 那种**保持原比例 + 裁掉超出容器的部分**。

**实现约束**：
- 所有走 `MediaView` 的封面/头像/视频调用，必须传 `boxFit: BoxFit.cover`
- 严禁 `BoxFit.fill`（变形）和默认 `BoxFit.contain`（留黑边）
- 现状核查（已通过）：
  - `AvatarMedia`（`widgets/character/avatar_media.dart:51`）已用 `BoxFit.cover` ✅
  - `NovelCover` 旧 `Image.network`（`widgets/novel/novel_cover.dart:57`）已用 `BoxFit.cover` ✅
  - `MediaView` 视频路径（`widgets/media/media_view.dart:447-464`）cover 模式用 `FittedBox(fit: BoxFit.cover)` ✅
- 封面新代码必须延续这一约定：`MediaView(mediaId: ..., boxFit: BoxFit.cover)`

## 4. 架构总览

```
AI Agent Chat
    ↓ 用户："帮我给《XXX》画个封面"
WritingScenario（已注入 create_images / create_image_to_video / set_novel_cover）
    ↓ LLM 调用 create_images(prompt, modelName, count, ...)
MediaExecutor.createImages（现有，不改）
    ├─ POST /api/text2img/generate → task_id（= mediaId）
    ├─ MediaProxy.register(mediaId, image, text2img, ...) → INSERT media_items
    └─ return { images: [{ mediaId, ... }] }
    ↓ LLM 调用 set_novel_cover(mediaId)
ToolExecutor.execute('set_novel_cover')（新增 case）
    ↓ NovelNavigationExecutor.setNovelCover（新增方法）
    ├─ scenarioContext.currentNovelId → resolve novel URL
    ├─ novelRepositoryProvider.updateCoverMediaIdById(id, mediaId)
    └─ return { success: true, novelTitle, mediaId }
    ↓ Agent Chat 完成，书架下次刷新生效
NovelCover(novel)
    ├─ novel.coverMediaId != null → MediaView(mediaId, boxFit: cover)（纯图，无叠加）
    └─ novel.coverMediaId == null → _ProgrammaticCoverPainter（现有逻辑，完全不动）
```

## 5. 数据层

### 5.1 DB 迁移 v35 → v36

**文件**：`lib/core/database/database_migrations.dart`

- 版本号：`currentVersion` 从 35 升到 36（v35 已被 character_relationships 重建占用）
- `_migrateToVersion` switch 追加分支：`case 36:`
- SQL：`ALTER TABLE bookshelf ADD COLUMN coverMediaId TEXT;`（用现有 `_addColumnIfNotExists` helper，幂等）
- 模式参照 v34 的 `characters.avatarMediaId` 迁移（`_addColumnIfNotExists(db, 'characters', 'avatarMediaId', 'TEXT')`，`database_migrations.dart:758`）

**保留不动**：`bookshelf.coverUrl TEXT` 列（用户决定保留）。

### 5.2 Novel 模型

**文件**：`lib/models/novel.dart`

- 新增字段：`final String? coverMediaId;`
- 构造函数加可选参数 `this.coverMediaId`
- `toMap()`：`'coverMediaId': coverMediaId`
- `fromMap()`：`coverMediaId: map['coverMediaId'] as String?`
- `copyWith()`：支持 `String? coverMediaId` 覆盖（注意 nullable 字段的 sentinel 模式，与现有 `coverUrl` 写法一致）
- **不动** `coverUrl` 字段（保留列与 Dart 字段，避免破坏旧序列化/备份兼容）

### 5.3 Repository

**接口**：`lib/core/interfaces/repositories/i_novel_repository.dart`

新增方法：
```dart
Future<void> updateCoverMediaIdById(int id, String? mediaId);
```

**实现**：`lib/repositories/novel_repository.dart`

```dart
@override
Future<void> updateCoverMediaIdById(int id, String? mediaId) async {
  final db = await dbConnection.database;
  await db.update(
    'bookshelf',
    {'coverMediaId': mediaId, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
    where: 'id = ?',
    whereArgs: [id],
  );
}
```

参照 `updateBackgroundSettingById`（`novel_repository.dart`）的 URL→ID 解析与错误处理风格。如 `bookshelf` 表无 `updatedAt` 列，去掉该字段（实现时以表结构为准）。

## 6. Agent 工具层

### 6.1 新工具 schema

**文件**：`lib/services/novel_agent/agent_tools.dart`

在"小说元数据"工具分组（靠近 `update_background_setting`，约 line 527）新增 `_setNovelCover` 常量：

```dart
static const Map<String, dynamic> _setNovelCover = {
  'type': 'function',
  'function': {
    'name': 'set_novel_cover',
    'description': '设置当前小说的封面。先用 create_images 或 create_image_to_video '
        '生成媒体拿到 mediaId，再把 mediaId 传到这里。封面接受图片或视频。'
        '如需清空封面回到默认占位图，mediaId 传 null。',
    'parameters': {
      'type': 'object',
      'properties': {
        'mediaId': {
          'type': ['string', 'null'],
          'description': '由 create_images / create_image_to_video 返回的 mediaId；传 null 表示清空封面',
        },
      },
      'required': ['mediaId'],
    },
  },
};
```

在 `allTools` 列表（约 line 21-54）追加 `_setNovelCover`。

**注**：去掉了最初草案里的可选 `rationale` 字段——YAGNI，LLM 在对话里自然会说理由，不必结构化存储。

### 6.2 工具分发

**文件**：`lib/services/novel_agent/tool_executor.dart`

- `_lazyExecutors` 的 `late final` 子执行器列表中确认 `_novelNav`（`NovelNavigationExecutor`）已实例化（它已存在，服务于 `list_novels` / `select_novel` / `create_novel`）
- switch（约 line 89-156）追加：
  ```dart
  case 'set_novel_cover':
    return await _novelNav.setNovelCover(args, scenarioContext: scenarioContext);
  ```

### 6.3 执行器方法

**文件**：`lib/services/novel_agent/tool_executor/novel_navigation_executor.dart`

新增方法 `setNovelCover`：

```dart
Future<String> setNovelCover(
  Map<String, dynamic> args, {
  required AgentScenarioContext scenarioContext,
  void Function(String)? onProgress,
}) async {
  final parser = ToolArgParser(args);
  final mediaId = parser.nullableString('mediaId');

  // 解析当前小说 URL（沿用现有上下文协议）
  final novelUrl = ToolExecutorHelpers.resolveCurrentNovelUrl(scenarioContext);
  if (novelUrl == null) {
    return ToolExecutorHelpers.guidanceError(
      message: '尚未选择小说，无法设置封面',
      suggestedTool: 'select_novel',
    );
  }

  // URL → ID
  final novelId = await ref.read(novelRepositoryProvider).getNovelIdByUrl(novelUrl);
  if (novelId == null) {
    return ToolExecutorHelpers.guidanceError(
      message: '当前小说不在书架中',
      suggestedTool: 'list_novels',
    );
  }

  await ref.read(novelRepositoryProvider).updateCoverMediaIdById(novelId, mediaId);

  return jsonEncode({
    'success': true,
    'novelUrl': novelUrl,
    'coverMediaId': mediaId,
    'cleared': mediaId == null,
  });
}
```

**约定**（沿用现有模式）：
- 通过 `scenarioContext.currentNovelId` 解析当前小说，不接收 `novelId` 参数（与 `update_background_setting` 一致）
- 错误返回 `guidanceError`（`tool_executor_helpers.dart:57-69`），引导 LLM 自助修复
- 不预校验 `mediaId` 是否存在于 `media_items`（写库直接 OK；UI 渲染时 `MediaView` 走 miss→失败重试状态机兜底）

**注意**：`getNovelIdByUrl` / `getNovelUrlById` 等方法名需实现时 Read `novel_navigation_executor.dart` 与 `i_novel_repository.dart` 确认实际签名。

### 6.4 System Prompt

**文件**：`lib/services/novel_agent/agent_system_prompt.dart`

工作原则列表（约 line 30-44）追加一条（编号续现有）：

> 修改小说封面：先调 `create_images`（或 `create_image_to_video`）生成媒体，从返回结果里选最合适的一张，把它的 `mediaId` 传给 `set_novel_cover`。封面接受图片或视频。封面图本身不需要包含书名文字（书名会在书架标题区独立展示）。改完后无需重复告知用户，`create_images` 已经在对话里展示过候选了。如需恢复默认占位封面，调 `set_novel_cover(mediaId=null)`。

## 7. UI 层

### 7.1 NovelCover 改造

**文件**：`lib/widgets/novel/novel_cover.dart`

唯一改造点：在 `build()` 顶部加一层 `coverMediaId` 判断分支。

```dart
@override
Widget build(BuildContext context) {
  final width = widget.width;
  final height = width * 4 / 3;

  // ★ 新增：AI 封面分支
  final coverMediaId = widget.novel.coverMediaId;
  if (coverMediaId != null && coverMediaId.isNotEmpty) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(-2, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: MediaView(
            mediaId: coverMediaId,
            boxFit: BoxFit.cover, // ★ 显式 cover，遵守"不拉伸"约束
          ),
        ),
      ),
    );
  }

  // ★ 以下为现有逻辑，完全不动
  final content = _hasCoverUrl ? Image.network(...) : CustomPaint(...);
  ...
}
```

**关键约束**（已与用户确认）：
- AI 封面命中时**不叠加任何**：不画书名、不画书脊高光、不画内框装饰、不画"在读"点（"在读"点本就不在 `NovelCover` 内，由父 `_NovelCard` 处理，本次不动）
- 加载/失败/pending 由 `MediaView` 自带状态机承担，`NovelCover` 不再自管 `_useFallback`
- `NovelCover` 需从 `StatelessWidget` 或保留 `StatefulWidget`——因为 AI 分支无 state 需求，但程序化分支的 `_useFallback` 仍需 state。**保持 `StatefulWidget`** 不变，仅在 build 顶部短路返回

**导入**：新增 `import '../../services/media/...`（实际路径以 `avatar_media.dart` 的 import 为准：`import '../media/media_view.dart';`）。

### 7.2 BookshelfScreen

**文件**：`lib/screens/bookshelf_screen.dart`

**零修改**。`_NovelCard` 通过 `NovelCover(novel: ...)` 拿封面，自动跟随新逻辑。

## 8. 数据流刷新

`set_novel_cover` 写库后，书架列表必须刷新才能看到新封面。

- `bookshelfNovelsProvider`（`core/providers/bookshelf_providers.dart:69-115`）是 `FutureProvider`
- **优先沿用现有机制**：实现时先 Read 确认现有写类工具（`create_novel` / `update_background_setting` 等）如何让书架刷新——若 `NovelAgentService` / `ScenarioSession` 在工具调用后有统一的 `ref.invalidate` 钩子，`set_novel_cover` 自动跟随即可
- **兜底方案**：若无统一机制，在 `NovelNavigationExecutor.setNovelCover` 末尾显式 `ref.invalidate(bookshelfNovelsProvider)`
- plan 阶段需定位精确入口并写入实现步骤，不留模糊

## 9. 错误处理

| 情况 | 行为 |
|------|------|
| 用户未 `select_novel` / `create_novel`（无 currentNovelId） | 返回 `guidanceError`，建议 `select_novel` |
| `currentNovelId` 指向的小说不在书架 | 返回 `guidanceError`，建议 `list_novels` |
| `mediaId` 不在 `media_items` | 不预校验；写库 OK；UI 渲染时 `MediaView` 走 miss→回源→失败重试 |
| `mediaId` 为 null（清空） | 直接写 null，`NovelCover` 回退程序化分支 |
| `create_images` 失败 | `create_images` 工具自己的事，`set_novel_cover` 收不到，LLM 自然会向用户说明 |
| 封面媒体被用户清空缓存 | `MediaView` 走回源路径（`GET /api/text2img/image/{task_id}` 或视频对应接口）重新拉取 |

## 10. 测试策略

### 10.1 单元测试

**Repository**：
- `NovelRepository.updateCoverMediaIdById`：
  - 写入非 null mediaId → 查回正确
  - 写入 null（清空）→ 查回 null
  - 不存在的 id → 无异常（update 影响 0 行）

**执行器**：
- `NovelNavigationExecutor.setNovelCover`：
  - 有 `currentNovelId` + 有效 mediaId → 写库成功，返回 `{success:true}`
  - 无 `currentNovelId` → 返回 `guidanceError`，建议 `select_novel`
  - `mediaId == null` → 清空成功，返回 `{cleared:true}`

**Widget**：
- `NovelCover`：
  - `coverMediaId == null` → 走程序化绘制（`CustomPaint` 存在）
  - `coverMediaId != null` → 渲染 `MediaView`（可用 mock `mediaProxyProvider`）

### 10.2 数据库迁移测试

- v34 → v35 升级：`coverMediaId` 列存在，旧数据 `coverMediaId` 为 null
- 全新安装（onCreate）：`bookshelf` 表含 `coverMediaId` 列

### 10.3 手动验证

1. 启动 Agent Chat，对一本已有小说说"帮我画个封面"
2. 观察 LLM 调用链：`create_images` → 返回 mediaId → `set_novel_cover`
3. 返回书架，该小说卡片显示生成的图
4. 再说"换张古风的" → 旧封面被新 mediaId 覆盖
5. 用 `create_image_to_video` 生成视频后说"用这个视频做封面" → 卡片显示循环静音视频
6. 说"恢复默认封面" → LLM 调 `set_novel_cover(mediaId=null)` → 回到程序化绘制
7. 验证封面图/视频保持原比例，未被拉伸变形（`BoxFit.cover`）

## 11. 影响面清单

| 文件 | 改动类型 |
|------|---------|
| `lib/core/database/database_migrations.dart` | 新增 v36 迁移加 `coverMediaId` 列 |
| `lib/models/novel.dart` | 新增 `coverMediaId` 字段 + toMap/fromMap/copyWith |
| `lib/core/interfaces/repositories/i_novel_repository.dart` | 新增 `updateCoverMediaIdById` 接口 |
| `lib/repositories/novel_repository.dart` | 新增 `updateCoverMediaIdById` + `getNovelById` 补 `coverMediaId` 映射 |
| `lib/repositories/bookshelf_repository.dart` | `getNovelsByBookshelf` 两处 Novel 构造补 `coverMediaId` 映射 |
| `lib/services/novel_agent/agent_tools.dart` | 新增 `_setNovelCover` schema + 加入 allTools |
| `lib/services/novel_agent/tool_executor.dart` | switch 新增 case |
| `lib/services/novel_agent/tool_executor/novel_navigation_executor.dart` | 新增 `setNovelCover` 方法 |
| `lib/services/novel_agent/agent_system_prompt.dart` | 工作原则追加一条 |
| `lib/widgets/novel/novel_cover.dart` | build 顶部新增 coverMediaId 分支 + import MediaView |
| `lib/screens/bookshelf_screen.dart` | **不改**（可能需核查 provider invalidate） |

**零改动**：`MediaProxy` / `MediaStore` / `MediaView` / `media_items` / `ApiServiceWrapper` / 后端 / `AvatarMedia`。

## 12. 实现顺序建议

1. 数据层（迁移 + 模型 + repository）→ 单测
2. NovelCover 改造 → widget 测
3. Agent 工具（schema + 分发 + 执行器 + system prompt）
4. 端到端手动验证

每步独立可测，符合项目"功能优先、渐进测试"原则。
