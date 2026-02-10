# 单元测试数据库管理机制深度分析

## 📊 当前单元测试的数据库管理方式

### 1. 三种初始化方式

#### 方式 A：直接初始化（简单测试）

```dart
// database_service_test.dart:17-20
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // 测试代码...
}
```

**特点**：
- ✅ 简单直接
- ❌ **没有清理机制**
- ❌ **共享数据库文件**（所有测试共用同一个）
- ❌ **可能产生测试污染**

---

#### 方式 B：DatabaseTestBase（结构化测试）

```dart
// database_test_base.dart:30-38
Future<void> setUp() async {
  // 初始化测试环境
  initDatabaseTests();

  // 创建数据库服务实例
  databaseService = DatabaseService();

  // 清理测试数据
  await cleanTestData();
}

Future<void> cleanTestData() async {
  final db = await databaseService.database;

  // 清理所有测试相关的表
  final tables = [
    'bookshelf',
    'chapter_cache',
    'novel_chapters',
    // ...
  ];

  for (final table in tables) {
    try {
      await db.delete(table);  // ← 只删除数据，表结构保留
    } catch (e) {
      // 表不存在或其他错误，忽略
    }
  }
}
```

**特点**：
- ✅ 有清理机制
- ✅ 结构化测试基类
- ❌ **只删除数据，不删除表**
- ❌ **表结构不更新**（Schema 可能是旧版本）

---

#### 方式 C：集成测试（手动管理）

```dart
// chapter_read_status_test.dart:13-70
setUp(() async {
  databaseService = DatabaseService();

  // 手动创建测试数据
  final db = await databaseService.database;
  for (final chapter in chapters) {
    try {
      await db.insert('novel_chapters', {...});
    } catch (e) {
      // 忽略重复插入错误
    }
  }
});
```

**特点**：
- ❌ 没有统一管理
- ❌ 依赖现有数据库结构
- ❌ **如果数据库结构是旧的，会直接失败**

---

## 🐛 为什么会出现数据库版本问题？

### 问题根源：数据库文件持久化

```
测试流程：
┌─────────────────────────────────────┐
│  1. 运行 test_a.dart                │
│     → 创建数据库文件               │
│     → 使用 onCreate (版本1)         │
│     → 数据库文件持久化在磁盘        │
└─────────────────────────────────────┘
           ↓ (测试结束，数据库文件保留)
┌─────────────────────────────────────┐
│  2. 运行 test_b.dart                │
│     → 复用已有的数据库文件         │
│     → 版本号已经是 19                │
│     → onCreate 不调用 ❌              │
│     → onUpgrade 不调用 ❌             │
│     → 使用旧 Schema ❌                │
└─────────────────────────────────────┘
```

---

### SQLite 的数据库管理逻辑

```dart
openDatabase(
  path,
  version: 19,
  onCreate: _onCreate,      // ← 仅在数据库不存在时调用
  onUpgrade: _onUpgrade,    // ← 仅在版本号提升时调用
)
```

**关键点**：
- `onCreate` **只在数据库文件不存在时调用**
- `onUpgrade` **只在版本号提升时调用**
- 如果数据库文件已存在且版本号已经是 19：
  - `onCreate` 不会调用
  - `onUpgrade` 不会调用（因为版本号没有提升）

---

## 🎯 为什么会出现版本问题？

### 场景 1：数据库文件残留（最常见）

```
第1次测试运行：
- 数据库文件不存在
- onCreate 创建表（版本 1 的结构）
- onUpgrade 升级到版本 19
- ✅ Schema 完整

第2次测试运行：
- 数据库文件已存在，版本号是 19
- onCreate 不调用 ❌
- onUpgrade 不调用 ❌
- ✅ 使用的是第1次测试创建的数据库
```

**但如果**：
- 第1次测试中途失败
- 或者使用了不完整的 `_onCreate`（之前没有 `readAt` 字段）
- 或者直接使用了旧版本数据库文件

**结果**：后续所有测试都会使用这个不完整的数据库！

---

### 场景 2：`_onCreate` 的 Schema 定义不完整

**问题代码**（第 97-108 行）：
```dart
CREATE TABLE novel_chapters (
  ...
  // ❌ 缺少 readAt 字段
)
```

**迁移代码**（第 305-315 行）：
```dart
if (oldVersion < 11) {
  ALTER TABLE novel_chapters ADD COLUMN readAt INTEGER  // ← 通过迁移添加
}
```

**矛盾**：
- `_onCreate` 创建的表没有 `readAt`
- 迁移逻辑（版本 11）会添加 `readAt`
- **但如果数据库文件已经存在且版本号 >= 11**，迁移不会执行！

---

### 场景 3：测试之间没有完全隔离

**当前的 `cleanTestData` 实现**：
```dart
for (final table in tables) {
  await db.delete(table);  // ← 只删除数据，表结构不变
}
```

**问题**：
- 表结构保留（可能是旧版本）
- 不触发 `onCreate`
- 不触发 `onUpgrade`

---

## 🔧 完整的解决方案

### 方案 1：完全隔离测试数据库（推荐）✅

修改 `DatabaseTestBase`，在测试前重建数据库：

```dart
Future<void> cleanTestData() async {
  // 1. 获取数据库文件路径
  final db = await databaseService.database;
  final path = db.path;

  // 2. 关闭数据库连接
  await databaseService.close();

  // 3. 删除数据库文件（强制重新创建）
  try {
    final File dbFile = File(path);
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
  } catch (e) {
    debugPrint('删除数据库文件失败: $e');
  }

  // 4. 重新初始化（会触发 onCreate + onUpgrade）
  // 下次访问 databaseService.database 时会自动创建新数据库
}
```

---

### 方案 2：添加 Schema 版本检查（防御性）

在 `DatabaseService._initDatabase` 中添加：

```dart
Future<Database> _initDatabase() async {
  // ... 现有代码 ...

  final db = await openDatabase(...);

  // 添加：确保 Schema 是最新的
  await _ensureLatestSchema(db);

  return db;
}

Future<void> _ensureLatestSchema(Database db) async {
  // 检查所有必需的列是否存在
  final requiredColumns = {
    'novel_chapters': ['readAt', 'isUserInserted', 'isAccompanied'],
    'bookshelf': ['aiAccompanimentEnabled', 'aiInfoNotificationEnabled'],
    // ...
  };

  for (final table in requiredColumns.entries) {
    final tableName = table.key;
    final columns = table.value;

    final result = await db.rawQuery('PRAGMA table_info($tableName)');
    final existingColumns = result.map((row) => row['name'] as String).toSet();

    for (final column in columns) {
      if (!existingColumns.contains(column)) {
        await db.execute('ALTER TABLE $tableName ADD COLUMN $column INTEGER');
        debugPrint('⚠️  测试环境：自动添加缺失字段 $tableName.$column');
      }
    }
  }
}
```

---

### 方案 3：统一 `_onCreate` 中的 Schema

确保 `_onCreate` 中的表定义包含所有字段：

```dart
await db.execute('''
  CREATE TABLE novel_chapters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    novelUrl TEXT NOT NULL,
    chapterUrl TEXT NOT NULL,
    title TEXT NOT NULL,
    chapterIndex INTEGER,
    isUserInserted INTEGER DEFAULT 0,
    insertedAt INTEGER,
    isAccompanied INTEGER DEFAULT 0,
    readAt INTEGER,  // ← 直接在创建时包含
    UNIQUE(novelUrl, chapterUrl)
  )
''');
```

---

## 📊 单元测试数据库管理最佳实践

### ✅ 推荐做法

1. **完全隔离**：每个测试套件使用独立的数据库文件
   ```dart
   setUpAll(() async {
     // 使用临时数据库文件
     sqfliteFfiInit();
     databaseFactory = databaseFactoryFfi;
   });
   ```

2. **强制重建**：测试开始前删除数据库文件
   ```dart
   setUp(() async {
     await deleteTestDatabase();
     // 初始化...
   });
   ```

3. **Schema 验证**：测试前验证关键字段
   ```dart
   setUp(() async {
     await ensureTestSchema();
   });
   ```

4. **使用 Mock**：对于不依赖数据库的测试，使用 Mock 对象
   ```dart
   class MockDatabaseService extends Mock implements DatabaseService {}
   ```

---

### ❌ 避免的做法

1. **共享数据库文件**：多个测试共用同一个数据库文件
2. **只清理数据**：`delete(table)` 只删除数据，不更新结构
3. **依赖迁移**：测试环境不应该依赖生产环境的迁移逻辑
4. **硬编码版本号**：直接指定版本 19 可能导致迁移跳过

---

## 🎯 总结

### 单元测试数据库版本问题的根本原因

1. **数据库文件持久化**
   - 测试数据库文件保存在磁盘上
   - 后续测试会复用旧文件

2. **SQLite 的生命周期**
   - `onCreate` 只在数据库不存在时调用
   - `onUpgrade` 只在版本号提升时调用
   - 旧数据库文件不会自动更新

3. **测试清理不完整**
   - `cleanTestData()` 只删除数据，不删除表
   - 表结构可能是旧版本
   - 缺少新增的字段

### 推荐解决方案

**最简单有效**：在测试的 `setUp` 中删除数据库文件：

```dart
setUp(() async {
  // 删除旧的测试数据库
  await File('.dart_tool/sqflite_common_ffi/databases/novel_reader.db').delete();

  // 重新初始化
  initDatabaseTests();
});
```

**最佳实践**：使用 `DatabaseTestBase` 并增强 `cleanTestData` 方法。

---

**报告生成时间**: 2026-01-28 00:45
**核心发现**: 测试数据库文件残留 + SQLite 生命周期问题 → Schema 不同步
