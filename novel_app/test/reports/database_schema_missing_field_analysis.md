# 数据库字段缺失问题完整分析

## 🎯 问题总结

**现象**：测试环境中 `readAt` 字段缺失，导致无法标记章节为已读

---

## 🔍 深度分析

### 1. Schema 定义不一致

**代码中存在两套 Schema 定义**：

#### A. `_onCreate` 方法中的定义（第 97-108 行）

```dart
CREATE TABLE novel_chapters (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  novelUrl TEXT NOT NULL,
  chapterUrl TEXT NOT NULL,
  title TEXT NOT NULL,
  chapterIndex INTEGER,
  isUserInserted INTEGER DEFAULT 0,
  insertedAt INTEGER,
  isAccompanied INTEGER DEFAULT 0,
  UNIQUE(novelUrl, chapterUrl)
)
```

#### B. 迁移逻辑中的定义（版本 11）

```dart
// database_service.dart:305-315
if (oldVersion < 11) {
  ALTER TABLE novel_chapters ADD COLUMN readAt INTEGER
}
```

#### C. 模型定义中的字段

```dart
// models/chapter.dart:8
class Chapter {
  final int? readAt;  // ✅ 模型中有此字段
  bool get isRead => readAt != null;
}
```

**问题**：三个地方的定义不一致！

---

### 2. SQLite 的数据库创建流程

```dart
openDatabase(
  path,
  version: 19,
  onCreate: _onCreate,      // ← 仅在数据库不存在时调用
  onUpgrade: _onUpgrade,    // ← 仅在数据库版本提升时调用
)
```

#### 场景分析

| 场景 | onCreate | onUpgrade | 结果 |
|------|----------|-----------|------|
| **全新安装** | ✅ 调用（版本 1） | ✅ 调用（1→19） | Schema 完整 |
| **数据库已存在** | ❌ 不调用 | ❌ 不调用（版本已是 19） | ⚠️ **使用旧 Schema** |
| **残留测试数据库** | ❌ 不调用 | ❌ 不调用 | ❌ **Schema 不完整** |

---

### 3. 根本原因

**测试环境的数据库文件残留**，使用了旧版本（版本 < 11）的数据库：

```
.dart_tool/sqflite_common_ffi/databases/novel_reader.db
```

这个数据库：
- ✅ 存在（不会触发 `onCreate`）
- ❌ 版本是旧的（可能是版本 1-10）
- ❌ 没有 `readAt` 字段（版本 11 才添加）
- ❌ 不会被升级（代码中版本已硬编码为 19）

---

## 🔧 为什么修复 `_onCreate` 没有效果？

修复代码：
```dart
CREATE TABLE novel_chapters (
  ...
  readAt INTEGER,  // ← 新添加
  ...
)
```

**为什么仍然失败？**

因为测试数据库文件**已经存在**：
- `onCreate` 只在数据库**不存在**时调用
- 旧的数据库文件没有 `readAt` 字段
- 但 SQLite 认为这是"有效"的版本 19 数据库

---

## 💡 完整解决方案

### 方案 1：删除测试数据库文件 ✅

```bash
# 停止所有测试进程
cd novel_app

# 删除测试数据库
rm -f .dart_tool/sqflite_common_ffi/databases/novel_reader.db*
rm -f .dart_tool/sqflite_common_ffi/databases/novel_reader.db-shm
rm -f .dart_tool/sqflite_common_ffi/databases/novel_reader.db-wal

# 重新运行测试
flutter test test/integration/chapter_read_status_test.dart
```

**结果**：数据库被重新创建，包含最新的 Schema（包括 `readAt`）

---

### 方案 2：添加数据库版本检查逻辑 🔧

在 `_initDatabase` 中添加版本检查和自动迁移：

```dart
Future<Database> _initDatabase() async {
  final databasePath = await getDatabasesPath();
  final path = join(databasePath, 'novel_reader.db');

  final db = await openDatabase(
    path,
    version: 19,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );

  // 添加：确保 Schema 是最新的
  await _ensureLatestSchema(db);

  return db;
}

Future<void> _ensureLatestSchema(Database db) async {
  // 检查当前版本
  final List<Map<String, dynamic>> result = await db.rawQuery(
    'PRAGMA user_version'
  );
  final currentVersion = result.first['user_version'] as int;

  // 如果版本不对，强制升级
  if (currentVersion < 19) {
    // 模拟从旧版本升级
    await _onUpgrade(db, currentVersion, 19);

    // 更新版本号
    await db.execute('PRAGMA user_version = 19');
  }

  // 检查关键字段是否存在
  final columns = await db.rawQuery('PRAGMA table_info(novel_chapters)');
  final columnNames = columns.map((row) => row['name'] as String).toSet();

  if (!columnNames.contains('readAt')) {
    await db.execute('ALTER TABLE novel_chapters ADD COLUMN readAt INTEGER');
  }
}
```

---

### 方案 3：在测试 setUp 中清理数据 ✅（推荐）

在每个测试的 `setUp` 方法中强制清理：

```dart
setUp(() async {
  // 清理测试数据库
  final db = await databaseService.database;

  // 删除并重新创建表
  await db.execute('DROP TABLE IF EXISTS novel_chapters');
  await db.execute('DROP TABLE IF EXISTS bookshelf');

  // 重新创建表（会使用最新的 _onCreate）
  await databaseService.database; // 触发 onCreate
});
```

---

## 📊 其他可能缺失的字段

通过分析 `_onCreate` 和迁移历史，可能还有其他字段缺失：

| 字段名 | 添加版本 | 是否在 onCreate 中 |
|--------|----------|-------------------|
| `isUserInserted` | 版本 2 | ✅ 有 |
| `insertedAt` | 版本 ? | ✅ 有 |
| `isAccompanied` | 版本 10 | ✅ 有 |
| **`readAt`** | **版本 11** | **❌ 无** ← **问题** |
| `aliases` | 版本 12 | ⚠️ 未检查 |

**建议**：全面检查 `_onCreate` 中的字段定义，确保包含所有最新字段。

---

## 🎯 经验教训

### 1. Schema 定义应该统一

**问题**：
- `_onCreate` 中定义基础字段
- 通过 `ALTER TABLE` 逐步添加字段
- 两处定义容易不同步

**最佳实践**：
```dart
// 在 _onCreate 中直接创建完整 Schema
CREATE TABLE novel_chapters (
  ... 所有字段（包括 readAt）
)
```

---

### 2. 测试环境需要特殊处理

**问题**：
- 测试数据库文件残留
- 不会触发 `onCreate`
- 不会触发 `onUpgrade`

**最佳实践**：
```dart
setUp(() async {
  // 方案 1: 删除测试数据库
  await cleanTestDatabase();

  // 方案 2: 强制迁移
  await ensureTestDatabaseSchema();
});
```

---

### 3. 版本号检查不够健壮

**问题**：
- SQLite 只检查版本号是否提升
- 不检查 Schema 是否完整

**最佳实践**：
```dart
// 不仅检查版本号，还要验证关键字段
if (!columnExists('readAt')) {
  await db.execute('ALTER TABLE novel_chapters ADD COLUMN readAt INTEGER');
}
```

---

## ✅ 推荐修复步骤

1. **立即修复**：删除测试数据库文件
   ```bash
   rm -f novel_app/.dart_tool/sqflite_common_ffi/databases/*.db*
   ```

2. **代码改进**：同步 `_onCreate` 中的 Schema
   - 确保包含所有最新字段（包括 `readAt`）

3. **测试改进**：在测试 setUp 中强制清理
   - 避免数据库残留问题

4. **长期改进**：添加 Schema 版本检查
   - 在 `_initDatabase` 中验证关键字段

---

**报告生成时间**: 2026-01-28 00:40
**核心问题**: `_onCreate` 中的 Schema 定义不完整，加上测试数据库文件残留导致迁移未执行
