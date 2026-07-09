# 抽取 MarkdownEditorScreen 共享组件

## 目标

`outline_screen.dart`(423 行)与 `background_setting_screen.dart`(446 行)近乎克隆,共享 ~350 行
"TabBar(编辑/预览)+ TextField + Markdown 预览 + 2s 防抖自动保存 + PopScope 放弃确认"骨架。
本批次把骨架抽到 `lib/widgets/markdown/markdown_editor_screen.dart`,两屏瘦身为 ~50 行的 thin wrapper,
消除重复并锁定统一行为契约。

## 设计决策

### 1. 放置位置:`lib/widgets/markdown/`(新目录)
- 理由:`lib/widgets/common/` 目前只放低阶原子(`BaseDialog`/`ConfirmDialog`/`BottomSheetHeader`)。
  `MarkdownEditorScreen` 是一个完整 Screen 级组件,粒度更大,放独立子目录更符合"common=原子、子目录=领域组件"的既有约定。
- 导出:不强制加进 `common_widgets.dart` 桶(该桶目前只 export `confirm_dialog`,保持克制);调用方直接 `import` 具体文件。

### 2. API 形态:`ConsumerStatefulWidget` + 回调参数化(非泛型)
- **不引入泛型 `T`**:大纲(标题+内容)与背景设定(仅内容)的差异仅是"是否有标题字段",用泛型反而逼调用方写 mapper,心智成本更高。
- **不用 `StatelessWidget`**:组件需要持有 controllers / timer / modified 标志等大量可变状态,必须是 stateful。
- **`ConsumerStatefulWidget`**:load/save 回调闭包里会用到 `ref.read(repoProvider)`,放组件内部 build 闭包更自然;但实际我们让**调用方(thin wrapper)在闭包里 `ref.read`**,组件本身不需要 ref —— 为对称与未来扩展仍用 `ConsumerStatefulWidget`,成本为零。

### 3. 数据形状:`MarkdownEditorDoc` value object
```dart
class MarkdownEditorDoc {
  final String? title;   // null => 单字段模式(背景设定);非 null => 双字段模式(大纲)
  final String content;
  const MarkdownEditorDoc({this.title, required this.content});
}
```

### 4. 组件签名
```dart
class MarkdownEditorScreen extends ConsumerStatefulWidget {
  const MarkdownEditorScreen({
    required this.appBarTitle,        // '大纲' / '背景设定'
    required this.appBarSubtitle,     // 书名
    required this.load,               // Future<MarkdownEditorDoc> Function()
    required this.save,               // Future<void> Function(MarkdownEditorDoc, {required bool auto})
    required this.logTag,             // 'outline' / 'background' —— 日志 tags 用
    this.titleHint,                   // 非空 => 渲染标题 TextField;null => 单字段模式
    this.titleFallback,               // 标题留空时保存用的占位(大纲=书名)
    this.contentHint,                 // 内容输入框 hint
    this.emptyText,                   // 预览空态文案
    this.savedToast,                  // 手动保存成功 toast
    this.autoSavedToast = '已自动保存',
    super.key,
  });

  final String appBarTitle;
  final String appBarSubtitle;
  final Future<MarkdownEditorDoc> Function() load;
  final Future<void> Function(MarkdownEditorDoc doc, {required bool auto}) save;
  final String logTag;
  final String? titleHint;
  final String? titleFallback;
  final String? contentHint;
  final String? emptyText;
  final String? savedToast;
  final String autoSavedToast;
}
```

### 5. 回调契约(关键)
- **`load`**:返回初始 doc。**抛错由组件内部 catch** → `ErrorHelper.showErrorWithLog` + `_isLoading=false` + 内容留空。
  - 背景设定原先的 `widget.novel.backgroundSetting` fallback:**由调用方在 load 闭包内 try-catch 返回兜底值**,组件不感知 novel。✓ 干净分层。
- **`save(doc, {auto})`**:调用方执行 repo 写入。**正常返回=成功,抛错=失败**,组件统一 catch:
  - 成功 → 重置 `_original`、`_isModified=false`、`_isSaving=false`;`auto` → `autoSavedToast`;非 `auto` → `savedToast` + `Navigator.pop`。
  - 失败 → `auto` 走 `LoggerService.w`;非 `auto` 走 `ErrorHelper.showErrorWithLog`。tags = `[logTag, auto ? 'auto-save' : 'save', 'failed']`。
- 调用方 save 闭包**不应再 catch**(避免双重处理)。

### 6. 内部状态(全部组件内聚)
`_isLoading`、`_isSaving`、`_isModified`、`_currentTabIndex`、`_autoSaveTimer`、
`_original`(MarkdownEditorDoc 快照)、`_titleController`、`_contentController`。
- `isModified` 判定:组件内部比对 controllers 与 `_original`,变化触发 setState。调用方零干预。
- `titleFallback`:保存时若 title 为空,用此值替换(大纲:书名)。

### 7. 公共函数 `buildProseMarkdownStyle`
- 新文件 `lib/widgets/markdown/prose_markdown_style.dart`:
```dart
MarkdownStyleSheet buildProseMarkdownStyle(BuildContext context);
```
- 两屏 styleSheet 逐行一致,抽成一个函数。
- **不复用 `agent_message_bubble` 第三处**(h1 20px vs 两屏 22px、code 用 primary 色 vs 两屏 monospace)——配置不同,本次只统一两屏,不强行拉齐。

### 8. 两屏改造为 thin wrapper
保留 `OutlineScreen` / `BackgroundSettingScreen` 作为语义入口(调用方 `chapter_list_screen_riverpod.dart` 无需改动),
内部 `build` 直接返回 `MarkdownEditorScreen(...)`,load/save 闭包封装各自 repo 调用:

```dart
// outline_screen.dart(改造后 ~50 行)
class OutlineScreen extends ConsumerWidget {
  final Novel novel;
  const OutlineScreen({required this.novel, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MarkdownEditorScreen(
      appBarTitle: '大纲',
      appBarSubtitle: novel.title,
      logTag: 'outline',
      titleHint: '可选，留空则使用书名',
      titleFallback: novel.title,
      contentHint: '在此输入大纲内容（支持 Markdown 格式）...',
      emptyText: '暂无大纲，可在「编辑」页创建',
      savedToast: '大纲已保存',
      load: () async {
        final outline = await ref.read(outlineRepositoryProvider).getOutlineByNovelUrl(novel.url);
        return MarkdownEditorDoc(title: outline?.title, content: outline?.content ?? '');
      },
      save: (doc, {required bool auto}) async {
        await ref.read(outlineRepositoryProvider).saveOutline(Outline(
          novelUrl: novel.url,
          title: doc.title ?? novel.title,
          content: doc.content,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      },
    );
  }
}
```

背景设定同理,load 闭包内 try-catch 返回 `widget.novel.backgroundSetting` 兜底。

## 文件清单
| 动作 | 路径 | 说明 |
|------|------|------|
| 新建 | `lib/widgets/markdown/markdown_editor_screen.dart` | 共享 Screen + `MarkdownEditorDoc` |
| 新建 | `lib/widgets/markdown/prose_markdown_style.dart` | `buildProseMarkdownStyle(BuildContext)` |
| 改写 | `lib/screens/outline_screen.dart` | thin wrapper(~50 行) |
| 改写 | `lib/screens/background_setting_screen.dart` | thin wrapper(~50 行) |
| 新建 | `test/widgets/markdown_editor_screen_test.dart` | widget 测试 |

## 测试策略(`test/widgets/markdown_editor_screen_test.dart`)
遵循 `test/widgets/` 既有 `testWidgets` + `pumpWidget` + `pump(Duration)` 范式。

1. **`编辑后 2 秒自动保存并重置 modified`**
   - load 返回空 doc;enterText 到 content;pump(2s);断言 save 回调被调用且 `auto=true`;断言返回键不再拦截(`_isModified=false`)。
2. **`有未保存修改时返回键拦截并弹放弃确认`**
   - enterText;trigger pop(`tester.binding.popRoute` 或模拟返回);断言 `ConfirmDialog`(文案"放弃修改?")出现;点"继续编辑";断言未 pop。
3. **`load 抛错时降级为空内容且不崩溃`**
   - load 回调 throw;断言 `_isLoading` 结束(loading 圆圈消失)、无崩溃、内容为空。
4. **`标题模式渲染标题框,单字段模式不渲染`**
   - 两次 pumpWidget:一次 `titleHint` 非空,断言找到"大纲标题"label;一次 null,断言找不到。

## 回归保证(行为不变)
- [x] 防抖时机 2s 不变
- [x] 编辑→预览 Tab 切换触发 auto-save 不变
- [x] 放弃确认文案/按钮色不变(走既有 `ConfirmDialog.show`)
- [x] 手动保存成功后 `Navigator.pop` 不变
- [x] toast 文案参数化保持原值("大纲已保存"/"背景设定已保存"/"已自动保存")
- [x] 日志 tags 形态不变(`[logTag, 'save'/'auto-save', 'failed']`)
- [x] 大纲 `_isLoading` 态保留;背景设定加载失败 fallback 保留(移到 load 闭包内)
- [x] 入口 `chapter_list_screen_riverpod.dart` 零改动

## 验收
- `flutter analyze lib/` → No issues
- `flutter test` → 原有 1094 通过 + 新增 4 个 widget 测试通过,0 失败
- 两屏文件行数从 ~430 → ~50
- git diff 确认无行为漂移(防抖/保存/pop 时机一致)
