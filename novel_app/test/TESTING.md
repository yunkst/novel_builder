# Novel App 测试指南

## 📚 测试策略

### 数据库测试原则

**核心原则**: 100%使用真实SQLite数据库进行测试

**为什么？**
- ✅ 真实验证数据操作结果(而非Mock调用)
- ✅ 防止类似readAt字段bug的回归问题
- ✅ 测试更直观,维护成本更低
- ✅ 测试可信度更高

**技术实现**:
- 使用 `sqflite_common_ffi` 在测试环境运行SQLite
- 数据库配置为 `:memory:` 内存数据库
- 通过 `DatabaseTestBase` 基类统一管理

### 禁止事项

❌ **禁止使用MockDatabaseService**
```dart
// 错误示例
final mockDb = MockDatabaseService();
when(mockDb.getChapter(url)).thenAnswer((_) async => 'content');
// ❌ 这只验证"调用",不验证"结果"
```

### 外部依赖Mock规范

✅ **允许Mock的外部依赖**:
- **网络服务**: `ApiServiceWrapper`, `BackendApiService`
- **AI服务**: `DifyService`
- **平台API**: `SharedPreferences`, `Platform`
- **时间相关**: `DateTime`, `Timer` (需要测试时间逻辑时)

```dart
// 正确示例: 真实数据库 + Mock外部服务
test('should load chapter from database or API', () async {
  // Mock外部HTTP依赖
  when(mockApi.fetchChapter(url)).thenAnswer((_) async => 'content');

  // 使用真实数据库
  final result = await service.getChapter(url);

  expect(result, 'content');

  // 验证数据库实际缓存
  final cached = await databaseService.getCachedChapter(url);
  expect(cached, 'content');
});
```

## 🧪 测试基类

### DatabaseTestBase (推荐)

**路径**: `test/base/database_test_base.dart`

**提供功能**:
- 自动初始化SQLite FFI
- 数据库实例管理
- 测试数据清理
- 辅助验证方法

**常用方法**:
```dart
// 创建测试数据
final novel = await base.createAndAddNovel();
final chapters = await base.createAndCacheChapters(
  novelUrl: novel.url,
  count: 10,
);

// 验证结果
await base.expectChapterExists(
  novelUrl: novel.url,
  chapterUrl: 'chapter-1',
  title: '第一章',
);

await base.expectTableCount('bookshelf', 1);
await base.expectTableEmpty('chapter_cache');
```

### TestDataFactory (数据工厂)

**路径**: `test/utils/test_data_factory.dart`

**提供功能**:
- 创建测试Novel对象
- 创建测试Chapter列表
- 创建测试Character对象
- 自动处理时间戳(避免冲突)

## 📝 测试模板

### Controller测试模板

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/controllers/my_controller.dart';
import '../../base/database_test_base.dart';

void main() {
  group('MyController', () {
    late MyController controller;
    late DatabaseTestBase base;

    setUp(() async {
      base = DatabaseTestBase();
      await base.setUp();

      controller = MyController(
        databaseService: base.databaseService,
      );
    });

    tearDown(() async {
      await base.tearDown();
    });

    test('should do something', () async {
      // 1. 准备测试数据
      final novel = await base.createAndAddNovel();

      // 2. 执行操作
      await controller.doSomething(novel.url);

      // 3. 验证结果(真实数据库)
      await base.expectChapterExists(
        novelUrl: novel.url,
        chapterUrl: contains('/chapter/'),
        title: '预期标题',
      );
    });
  });
}
```

### Service测试模板(混合Mock)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/services/my_service.dart';
import '../../base/database_test_base.dart';

@GenerateMocks([ApiServiceWrapper]) // 只Mock外部依赖
import 'xxx_test.mocks.dart';

void main() {
  group('MyService', () {
    late MyService service;
    late DatabaseTestBase base;
    late MockApiServiceWrapper mockApi;

    setUp(() async {
      base = DatabaseTestBase();
      await base.setUp();

      // Mock外部HTTP依赖
      mockApi = MockApiServiceWrapper();

      service = MyService(
        databaseService: base.databaseService,
        api: mockApi,
      );
    });

    tearDown(() async {
      await base.tearDown();
    });

    test('should fetch from API and cache to database', () async {
      // Mock网络请求
      when(mockApi.fetchChapter(url))
          .thenAnswer((_) async => 'API内容');

      // 执行操作
      final result = await service.getChapter(url);

      // 验证返回值
      expect(result, 'API内容');

      // 验证真实数据库缓存
      final cached = await base.databaseService.getCachedChapter(url);
      expect(cached, 'API内容');
    });
  });
}
```

## 🔄 迁移指南

### 从ServiceTestBase迁移到DatabaseTestBase

**步骤1: 修改基类**
```dart
// 迁移前
import '../../test_bootstrap.dart';
import '../../base/service_test_base.dart';

class MyTest extends ServiceTestBase {
  // ...
}

// 迁移后
import '../../base/database_test_base.dart';

void main() {
  late DatabaseTestBase base;

  setUp(() async {
    base = DatabaseTestBase();
    await base.setUp();
  });
}
```

**步骤2: 替换mock为真实数据库**
```dart
// 迁移前
late MockDatabaseService mockDb;
mockDb = MockDatabaseService();
when(mockDb.insertChapter(...)).thenAnswer((_) async {});
handler.insertChapter(...);
verify(mockDb.insertChapter(...)).called(1);

// 迁移后
late DatabaseTestBase base;
await base.setUp();
final novel = await base.createAndAddNovel();
handler.insertChapter(...);
await base.expectChapterExists(
  novelUrl: novel.url,
  chapterUrl: contains('/chapter/'),
  title: '预期标题',
);
```

**步骤3: 验证实际数据而非调用**
```dart
// ❌ 迁移前: 只验证方法调用
verify(mockDb.insertChapter(...)).called(1);

// ✅ 迁移后: 验证实际数据
final chapters = await base.databaseService.getChapters(novel.url);
expect(chapters, contains(predicate((Chapter c) =>
  c.title == '预期标题' && c.isUserInserted
)));
```

## 📖 参考资料

- **DatabaseTestBase**: `test/base/database_test_base.dart`
- **TestDataFactory**: `test/utils/test_data_factory.dart`
- **测试Bootstrap**: `test/test_bootstrap.dart`
- **迁移计划**: `.zcf/plan/current/完全放弃Mock数据库测试-迁移计划.md`

## ⚠️ 常见问题

### Q: 为什么不能Mock数据库？
A: Mock数据库只验证"某方法被调用",无法验证实际插入的数据是否正确。真实的readAt字段bug就是被Mock测试遗漏的典型案例。

### Q: 真实数据库测试会很慢吗？
A: 使用 `:memory:` 内存数据库,性能接近Mock。测试运行时间通常只增加10-20%,但可靠性和覆盖面大幅提升。

### Q: 何时使用Mock？
A: 只Mock不可控的外部依赖(HTTP API、AI服务、平台API)。对于稳定、快速的依赖(如SQLite),直接使用真实实现。

### Q: Widget测试如何使用真实数据库？
A: Widget测试同样可以继承DatabaseTestBase,在pumpWidget前初始化数据库即可。参考`character_relationship_screen_test.dart`的迁移。

---

**最后更新**: 2025-01-30
**维护者**: Novel Builder Team
