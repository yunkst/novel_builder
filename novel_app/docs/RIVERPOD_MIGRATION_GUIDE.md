# Riverpod 迁移指南

> **版本**: v1.0
> **创建日期**: 2026-01-31
> **目标读者**: Novel App 开发团队

---

## 📋 目录

1. [为什么选择 Riverpod](#为什么选择-riverpod)
2. [核心概念](#核心概念)
3. [代码对比示例](#代码对比示例)
4. [迁移步骤](#迁移步骤)
5. [最佳实践](#最佳实践)
6. [常见问题](#常见问题)
7. [故障排除](#故障排除)

---

## 为什么选择 Riverpod？

### 当前问题

Novel App 目前使用的状态管理方案存在以下问题：

1. **Pending Timer 测试问题**
   - 50+ Widget 测试因 Timer 超时失败
   - 根本原因: 单例模式在测试中触发真实数据库查询
   - 影响: 测试覆盖率受限，回归风险高

2. **手动依赖注入**
   - 需要手动传递依赖到 Widget 构造函数
   - 代码冗余，维护成本高
   - 示例: `BookshelfScreen(databaseService: ..., preloadService: ...)`

3. **缺乏编译时安全性**
   - Provider 拼写错误只能在运行时发现
   - 重构困难，容易遗漏更新

### Riverpod 的优势

| 特性 | Provider (当前) | Riverpod (迁移后) |
|------|----------------|-------------------|
| **编译时安全** | ❌ 运行时错误 | ✅ 编译时检查 |
| **依赖注入** | ❌ 手动传递 | ✅ 自动注入 |
| **测试友好** | ⚠️ 需要 Mock | ✅ 易于 Mock |
| **代码生成** | ❌ 无 | ✅ 自动生成 |
| **性能优化** | ⚠️ 手动优化 | ✅ 自动优化 |
| **Pending Timer** | ❌ 存在问题 | ✅ 完全解决 |

---

## 核心概念

### 1. Provider

Provider 是 Riverpod 的基本单元，表示一个可访问的值。

#### 定义 Provider

```dart
// 使用 @riverpod 注解
@riverpod
String appName(AppNameRef ref) {
  return 'Novel App';
}

// 代码生成会创建:
// - appNameProvider: Provider 本身
// - AppNameRef: Provider 的引用类型
```

#### 读取 Provider

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 使用 ref.watch 读取 Provider
    final name = ref.watch(appNameProvider);
    return Text(name);
  }
}
```

### 2. ConsumerWidget

替代 `StatelessWidget`，支持访问 Provider。

```dart
// 旧代码 (StatelessWidget)
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final service = Provider.of<MyService>(context);
    return Text(service.getData());
  }
}

// 新代码 (ConsumerWidget)
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(myServiceProvider);
    return Text(service.getData());
  }
}
```

### 3. ConsumerStatefulWidget

替代 `StatefulWidget`，支持访问 Provider。

```dart
class MyWidget extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends ConsumerState<MyWidget> {
  @override
  Widget build(BuildContext context) {
    final service = ref.watch(myServiceProvider);
    return Text(service.getData());
  }
}
```

### 4. ref.watch vs ref.read

#### ref.watch - 建立响应式依赖

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  // ✅ 在 build 方法中使用
  final service = ref.watch(myServiceProvider);

  // 当 service 变化时，Widget 会自动重建
  return Text(service.getData());
}
```

#### ref.read - 一次性读取

```dart
onPressed: () {
  // ✅ 在回调函数中使用
  final service = ref.read(myServiceProvider);
  service.doSomething();
}

// ❌ 不要在 build 方法中使用 ref.read
@override
Widget build(BuildContext context, WidgetRef ref) {
  final service = ref.read(myServiceProvider); // 错误!
  return Text(service.getData());
}
```

### 5. Provider 类型

#### 基础 Provider

```dart
// 简单值
@riverpod
String appName(AppNameRef ref) => 'Novel App';

// 复杂对象
@riverpod
LoggerService loggerService(LoggerServiceRef ref) {
  return LoggerService.instance;
}
```

#### FutureProvider - 异步数据

```dart
@riverpod
Future<List<Novel>> novels(NovelsRef ref) async {
  final repo = ref.watch(novelRepositoryProvider);
  return repo.getNovels();
}

// 使用
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final novelsAsync = ref.watch(novelsProvider);

    return novelsAsync.when(
      data: (novels) => ListView.builder(...),
      loading: () => CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
    );
  }
}
```

#### StateProvider - 可变状态

```dart
// 定义
final counterProvider = StateProvider<int>((ref) => 0);

// 读取
final count = ref.watch(counterProvider);

// 更新
ref.read(counterProvider.notifier).state++;

// 在回调中更新
onPressed: () {
  ref.read(counterProvider.notifier).state++;
}
```

#### StateNotifierProvider - 复杂状态管理

```dart
// 定义 StateNotifier
class CounterNotifier extends StateNotifier<int> {
  CounterNotifier() : super(0);

  void increment() => state++;
  void decrement() => state--;
}

// 定义 Provider
@riverpod
CounterNotifier counter(CounterRef ref) {
  return CounterNotifier();
}

// 使用
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    final notifier = ref.read(counterProvider.notifier);

    return Column(
      children: [
        Text('Count: $count'),
        ElevatedButton(
          onPressed: notifier.increment,
          child: Text('Increment'),
        ),
      ],
    );
  }
}
```

---

## 代码对比示例

### 示例 1: LoggerService 迁移

#### 迁移前 (单例模式)

```dart
// 定义
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;

  void info(String message) {
    debugPrint(message);
  }
}

// 使用
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    LoggerService().info('Hello'); // 全局单例
    return Container();
  }
}
```

#### 迁移后 (Riverpod)

```dart
// 定义 Provider
@riverpod
LoggerService loggerService(LoggerServiceRef ref) {
  return LoggerService.instance;
}

// 使用
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = ref.watch(loggerServiceProvider);
    logger.info('Hello');
    return Container();
  }
}
```

### 示例 2: BookshelfScreen 迁移

#### 迁移前 (手动依赖注入)

```dart
class BookshelfScreen extends StatefulWidget {
  final DatabaseService? databaseService;
  final PreloadService? preloadService;
  final BookshelfRepository? bookshelfRepository;

  const BookshelfScreen({
    super.key,
    this.databaseService,
    this.preloadService,
    this.bookshelfRepository,
  });

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  late final DatabaseService _databaseService;
  late final PreloadService _preloadService;
  late final BookshelfRepository _bookshelfRepository;

  @override
  void initState() {
    super.initState();
    _databaseService = widget.databaseService ?? DatabaseService();
    _preloadService = widget.preloadService ?? PreloadService();
    _bookshelfRepository = widget.bookshelfRepository ?? BookshelfRepository();
    _loadData();
  }

  Future<void> _loadData() async {
    final novels = await _databaseService.getNovels();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildNovelList(),
    );
  }
}
```

#### 迁移后 (Riverpod)

```dart
// 定义 Provider
@riverpod
Future<List<Novel>> novels(NovelsRef ref) async {
  final db = ref.watch(databaseServiceProvider);
  return db.getNovels();
}

// Screen
class BookshelfScreen extends ConsumerWidget {
  const BookshelfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final novelsAsync = ref.watch(novelsProvider);

    return Scaffold(
      body: novelsAsync.when(
        data: (novels) => NovelListView(novels: novels),
        loading: () => CircularProgressIndicator(),
        error: (err, stack) => ErrorWidget(err),
      ),
    );
  }
}
```

### 示例 3: 测试迁移

#### 迁移前 (Pending Timer 问题)

```dart
testWidgets('BookshelfScreen should show novels', (tester) async {
  await tester.pumpWidget(
    MaterialApp(home: BookshelfScreen()),
  );
  await tester.pumpAndSettle(); // ❌ 超时! Pending Timer
  expect(find.text('测试小说'), findsOneWidget);
});
```

#### 迁移后 (解决 Pending Timer)

```dart
testWidgets('BookshelfScreen should show novels', (tester) async {
  final mockDb = MockDatabaseService();
  when(mockDb.getNovels()).thenAnswer((_) async => testNovels);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(mockDb),
      ],
      child: MaterialApp(home: BookshelfScreen()),
    ),
  );

  await tester.pump(); // ✅ 不需要 pumpAndSettle
  expect(find.text('测试小说'), findsOneWidget);
});
```

---

## 迁移步骤

### 阶段 1: Service 层迁移

#### 步骤 1: 创建 Provider

```dart
// lib/core/providers/service_providers.dart
@riverpod
LoggerService loggerService(LoggerServiceRef ref) {
  return LoggerService.instance;
}
```

#### 步骤 2: 运行代码生成

```bash
dart run build_runner build --delete-conflicting-outputs
```

#### 步骤 3: 更新使用处

```dart
// 旧代码
final logger = LoggerService.instance;

// 新代码
final logger = ref.watch(loggerServiceProvider);
```

#### 步骤 4: 编写测试

```dart
test('loggerServiceProvider should create instance', () {
  final container = ProviderContainer();
  final logger = container.read(loggerServiceProvider);

  expect(logger, isA<LoggerService>());
});
```

### 阶段 2: Screen 层迁移

#### 步骤 1: 分析依赖

识别 Screen 的所有依赖:

```dart
class BookshelfScreen extends StatefulWidget {
  final DatabaseService? databaseService;
  final PreloadService? preloadService;
  // ...
}
```

#### 步骤 2: 转换为 ConsumerWidget

```dart
// 从
class BookshelfScreen extends StatefulWidget

// 到
class BookshelfScreen extends ConsumerWidget
```

#### 步骤 3: 使用 Provider 获取依赖

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final db = ref.watch(databaseServiceProvider);
  final preload = ref.watch(preloadServiceProvider);
  // ...
}
```

#### 步骤 4: 移除构造函数参数

```dart
// 旧代码
class BookshelfScreen extends ConsumerWidget {
  final DatabaseService? databaseService;
  const BookshelfScreen({super.key, this.databaseService});
}

// 新代码
class BookshelfScreen extends ConsumerWidget {
  const BookshelfScreen({super.key});
}
```

#### 步骤 5: 更新测试

```dart
testWidgets('test', (tester) async {
  final mockDb = MockDatabaseService();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(mockDb),
      ],
      child: MaterialApp(home: BookshelfScreen()),
    ),
  );

  await tester.pump();
});
```

---

## 最佳实践

### 1. 使用 `keepAlive: true` 对于单例

```dart
@Riverpod(keepAlive: true)
LoggerService loggerService(LoggerServiceRef ref) {
  return LoggerService.instance;
}
```

### 2. 使用 `select` 优化重建

```dart
// ❌ 整个对象变化时重建
final novels = ref.watch(novelsProvider);

// ✅ 只在 count 变化时重建
final count = ref.watch(novelsProvider.select((state) => state.length));
```

### 3. 使用 `family` 参数化 Provider

```dart
@riverpod
Future<List<Chapter>> chapters(ChaptersRef ref, String novelUrl) async {
  final repo = ref.watch(chapterRepositoryProvider);
  return repo.getChapters(novelUrl);
}

// 使用
final chapters = ref.watch(chaptersProvider('https://example.com/novel/1'));
```

### 4. 在 `onDispose` 中清理资源

```dart
@riverpod
MyService myService(MyServiceRef ref) {
  final service = MyService();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
}
```

### 5. 使用 `ProviderScope` 包裹应用

```dart
void main() {
  runApp(ProviderScope(
    child: MyApp(),
  ));
}
```

---

## 常见问题

### Q1: 为什么不能在 `build` 方法中使用 `ref.read`?

**A**: `ref.read` 不建立响应式依赖，数据变化时 Widget 不会重建。

```dart
// ❌ 错误
@override
Widget build(BuildContext context, WidgetRef ref) {
  final service = ref.read(myServiceProvider); // 不响应变化
  return Text(service.data);
}

// ✅ 正确
@override
Widget build(BuildContext context, WidgetRef ref) {
  final service = ref.watch(myServiceProvider); // 响应变化
  return Text(service.data);
}
```

### Q2: 如何在测试中 Mock Provider?

**A**: 使用 `ProviderScope` 的 `overrides` 参数。

```dart
testWidgets('test', (tester) async {
  final mockService = MockMyService();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myServiceProvider.overrideWithValue(mockService),
      ],
      child: MyApp(),
    ),
  );
});
```

### Q3: Pending Timer 问题如何解决?

**A**: 使用 Mock DatabaseService，避免触发真实数据库查询。

```dart
testWidgets('test', (tester) async {
  final mockDb = MockDatabaseService();
  when(mockDb.getNovels()).thenAnswer((_) async => []); // Mock 返回值

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(mockDb),
      ],
      child: BookshelfScreen(),
    ),
  );

  await tester.pump(); // ✅ 不需要 pumpAndSettle
});
```

### Q4: 何时使用 `ConsumerWidget` vs `ConsumerStatefulWidget`?

**A**:
- **ConsumerWidget**: 无需内部状态 (如 TextEditingController)
- **ConsumerStatefulWidget**: 需要内部状态或生命周期方法

```dart
// ConsumerWidget 示例
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text('Simple');
  }
}

// ConsumerStatefulWidget 示例
class MyWidget extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends ConsumerState<MyWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);
  }
}
```

### Q5: 如何处理异步状态?

**A**: 使用 `AsyncValue.when` 方法。

```dart
final novelsAsync = ref.watch(novelsProvider);

return novelsAsync.when(
  data: (novels) => NovelListView(novels: novels),
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
);
```

---

## 故障排除

### 问题 1: 代码生成失败

**症状**:
```
Could not generate .g.dart file
```

**解决方案**:
```bash
# 清理并重新生成
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

### 问题 2: Provider 未找到

**症状**:
```
Undefined name 'loggerServiceProvider'
```

**解决方案**:
1. 确保已运行 `build_runner`
2. 检查 `.g.dart` 文件是否生成
3. 确保导入了生成的文件:
```dart
import 'service_providers.dart'; // 会自动导入 .g.dart
```

### 问题 3: 测试超时

**症状**:
```
Test timed out after 0:00:30.000
```

**解决方案**:
确保使用 Mock 而不是真实依赖:
```dart
final mockDb = MockDatabaseService();
when(mockDb.getNovels()).thenAnswer((_) async => []); // Mock 返回值
```

### 问题 4: Widget 不重建

**症状**: Provider 变化但 Widget 不更新

**解决方案**:
确保使用 `ref.watch` 而不是 `ref.read`:
```dart
// ❌ 不会重建
final service = ref.read(myServiceProvider);

// ✅ 会重建
final service = ref.watch(myServiceProvider);
```

---

## 迁移检查清单

### Service 层
- [ ] 创建 Provider 定义
- [ ] 运行代码生成
- [ ] 更新所有使用处
- [ ] 编写单元测试
- [ ] 验证向后兼容

### Screen 层
- [ ] 转换为 ConsumerWidget
- [ ] 移除构造函数参数
- [ ] 使用 Provider 获取依赖
- [ ] 更新测试
- [ ] 验证 Pending Timer 问题解决

### 测试
- [ ] 所有单元测试通过
- [ ] 所有 Widget 测试通过
- [ ] 测试覆盖率 > 85%
- [ ] 无 Pending Timer 错误

---

## 参考资料

- [Riverpod 官方文档](https://riverpod.dev/)
- [Flutter 测试文档](https://docs.flutter.dev/testing)
- [Provider 参考](../lib/core/providers/README.md)

---

**文档版本**: v1.0
**最后更新**: 2026-01-31
**维护者**: Novel App 开发团队
