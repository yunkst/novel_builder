# AI伴读自动触发功能实施计划

**任务描述**: 实现AI伴读自动触发、静默更新、Toast提示和已伴读标记功能

**创建时间**: 2025-01-25

**方案选择**: 方案1 - 数据库字段扩展

---

## 📊 需求回顾

### 功能目标
1. ✅ 自动触发: 章节加载后根据设置自动触发伴读
2. ✅ 静默模式: 不显示确认对话框,直接更新数据
3. ✅ Toast提示: 根据 `infoNotificationEnabled` 显示动态提示
4. ✅ 已伴读标记: 避免回顾章节时重复触发
5. ✅ 防抖机制: 同一章节只触发一次
6. ✅ 错误处理: 静默失败,不打扰用户

### 技术选型
- **触发时机**: 方案A - 章节加载完成后立即触发
- **静默程度**: 方案A - 完全静默(不显示loading)
- **Toast内容**: 方案B - 根据更新内容动态生成
- **错误处理**: 方案A - 静默失败
- **防抖机制**: 方案A - 标志位防抖

---

## 🗂️ 实施步骤

### 阶段1: Backend数据库变更 (PostgreSQL)

#### 步骤1.1: 创建Alembic迁移文件
**文件**: `backend/alembic/versions/YYYYMMDDHHMMSS_add_ai_accompanied_to_chapter_cache.py`

**操作**:
```bash
cd backend
alembic revision -m "add ai_accompanied to chapter_cache"
```

**内容**:
```python
from alembic import op
import sqlalchemy as sa

def upgrade():
    op.add_column(
        'chapter_cache',
        sa.Column('ai_accompanied', sa.Integer(), nullable=False, server_default='0')
    )

def downgrade():
    op.drop_column('chapter_cache', 'ai_accompanied')
```

**预期结果**:
- 数据库表 `chapter_cache` 添加 `ai_accompanied` 字段
- 默认值为0(未伴读)
- 支持回滚

**验证**:
```sql
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'chapter_cache' AND column_name = 'ai_accompanied';
```

---

#### 步骤1.2: 更新后端模型定义
**文件**: `backend/app/models/scene_comfyui_mapping.py`

**操作**: 在 `SceneComfyuiMapping` 类中添加字段
```python
class SceneComfyuiMapping(Base):
    # ... 现有字段 ...

    ai_accompanied: int = Field(
        default=0,
        description="章节是否已AI伴读: 0=未伴读, 1=已伴读",
    )
```

**预期结果**:
- 模型包含 `ai_accompanied` 字段
- FastAPI OpenAPI文档自动更新
- 序列化/反序列化支持该字段

**验证**:
```bash
# 检查OpenAPI文档
curl http://localhost:3800/docs | grep ai_accompanied
```

---

### 阶段2: Frontend数据库升级 (SQLite)

#### 步骤2.1: 数据库版本升级 v3 → v4
**文件**: `novel_app/lib/services/database_service.dart`

**操作1**: 更新数据库版本常量
```dart
static const int _databaseVersion = 4;  // 从3升级到4
```

**操作2**: 在 `_onDatabaseUpgrade` 方法中添加迁移逻辑
```dart
if (oldVersion < 4) {
  await _upgradeToV4(db);
}

Future<void> _upgradeToV4(Database db) async {
  await db.execute('''
    ALTER TABLE chapter_cache ADD COLUMN ai_accompanied INTEGER DEFAULT 0
  ''');
  debugPrint('✅ 数据库升级到v4: 添加ai_accompanied字段');
}
```

**预期结果**:
- 旧版本用户升级时自动添加 `ai_accompanied` 字段
- 新用户安装时直接创建v4数据库
- 已有章节默认标记为0(未伴读)

**验证**:
```dart
// 在测试数据库中验证
final db = await database;
final tables = await db.rawQuery(
  "PRAGMA table_info(chapter_cache)"
);
print(tables.where((t) =>['name'] == 'ai_accompanied'));
```

---

#### 步骤2.2: 添加章节伴读标记管理方法
**文件**: `novel_app/lib/services/database_service.dart`

**新增方法**:

```dart
/// 标记章节为已伴读
Future<void> markChapterAsAccompanied(String novelUrl, String chapterUrl) async {
  final db = await database;
  await db.update(
    'chapter_cache',
    {'ai_accompanied': 1},
    where: 'novel_url = ? AND chapter_url = ?',
    whereArgs: [novelUrl, chapterUrl],
  );
  debugPrint('✅ 章节已标记为伴读: ${chapterUrl.split('/').last}');
}

/// 检查章节是否已伴读
Future<bool> isChapterAccompanied(String novelUrl, String chapterUrl) async {
  final db = await database;
  final results = await db.query(
    'chapter_cache',
    columns: ['ai_accompanied'],
    where: 'novel_url = ? AND chapter_url = ?',
    whereArgs: [novelUrl, chapterUrl],
  );

  if (results.isEmpty) return false;
  return results.first['ai_accompanied'] == 1;
}

/// 重置章节伴读标记（用于强制刷新）
Future<void> resetChapterAccompaniedFlag(String novelUrl, String chapterUrl) async {
  final db = await database;
  await db.update(
    'chapter_cache',
    {'ai_accompanied': 0},
    where: 'novel_url = ? AND chapter_url = ?',
    whereArgs: [novelUrl, chapterUrl],
  );
  debugPrint('🔄 章节伴读标记已重置: ${chapterUrl.split('/').last}');
}

/// 批量重置小说所有章节的伴读标记
Future<void> resetAllNovelAccompaniedFlags(String novelUrl) async {
  final db = await database;
  await db.update(
    'chapter_cache',
    {'ai_accompanied': 0},
    where: 'novel_url = ?',
    whereArgs: [novelUrl],
  );
  debugPrint('🔄 小说所有章节伴读标记已重置: $novelUrl');
}
```

**预期结果**:
- 提供完整的伴读标记管理API
- 支持单个章节和批量操作
- 日志记录便于调试

**验证**:
```dart
// 单元测试
final dbService = DatabaseService();
await dbService.markChapterAsAccompanied(novelUrl, chapterUrl);
final result = await dbService.isChapterAccompanied(novelUrl, chapterUrl);
assert(result == true);
```

---

### 阶段3: 数据模型扩展

#### 步骤3.1: Chapter模型添加isAccompanied属性
**文件**: `novel_app/lib/models/chapter.dart`

**操作1**: 添加字段
```dart
class Chapter {
  final String title;
  final String url;
  final String? content;
  final bool isCached;
  final int? chapterIndex;
  final bool isUserInserted;
  final bool isAccompanied;  // 新增字段

  const Chapter({
    required this.title,
    required this.url,
    this.content,
    this.isCached = false,
    this.chapterIndex,
    this.isUserInserted = false,
    this.isAccompanied = false,  // 新增字段
  });
}
```

**操作2**: 更新copyWith方法
```dart
Chapter copyWith({
  String? title,
  String? url,
  String? content,
  bool? isCached,
  int? chapterIndex,
  bool? isUserInserted,
  bool? isAccompanied,  // 新增参数
}) {
  return Chapter(
    title: title ?? this.title,
    url: url ?? this.url,
    content: content ?? this.content,
    isCached: isCached ?? this.isCached,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    isUserInserted: isUserInserted ?? this.isUserInserted,
    isAccompanied: isAccompanied ?? this.isAccompanied,  // 新增逻辑
  );
}
```

**操作3**: 更新fromJson/toJson (如果使用序列化)
```dart
factory Chapter.fromJson(Map<String, dynamic> json) {
  return Chapter(
    // ... 现有字段 ...
    isAccompanied: json['isAccompanied'] as bool? ?? false,  // 新增
  );
}

Map<String, dynamic> toJson() {
  return {
    // ... 现有字段 ...
    'isAccompanied': isAccompanied,  // 新增
  };
}
```

**预期结果**:
- Chapter模型包含伴读状态
- 支持不可变更新(copyWith)
- 支持JSON序列化

**验证**:
```dart
final chapter = Chapter(
  title: 'Test',
  url: 'http://test.com',
  isAccompanied: true,
);
assert章节.isAccompanied == true);
```

---

### 阶段4: ReaderScreen核心逻辑实现

#### 步骤4.1: 添加状态管理变量
**文件**: `novel_app/lib/screens/reader_screen.dart`

**位置**: `_ReaderScreenState` 类成员变量区域

```dart
class _ReaderScreenState extends State<ReaderScreen> {
  // ... 现有成员变量 ...

  // AI伴读自动触发相关
  bool _hasAutoTriggered = false;        // 防抖标志
  bool _isAutoCompanionRunning = false;  // 运行状态标志
}
```

**预期结果**:
- 状态变量初始化
- 防止重复触发

---

#### 步骤4.2: 修改_loadChapterContent方法
**文件**: `novel_app/lib/screens/reader_screen.dart`

**位置**: 第226-246行 `_loadChapterContent` 方法

**操作**: 在方法末尾添加自动触发调用
```dart
Future<void> _loadChapterContent(
    {bool resetScrollPosition = true, bool forceRefresh = false}) async {
  await _contentController.loadChapter(
    _currentChapter,
    widget.novel,
    forceRefresh: forceRefresh,
    resetScrollPosition: resetScrollPosition,
  );

  await _databaseService.markChapterAsRead(
    widget.novel.url,
    _currentChapter.url,
  );

  _handleScrollPosition(resetScrollPosition);
  await _startPreloadingChapters();

  // 👇 新增: 重置防抖标志
  _hasAutoTriggered = false;

  // 👇 新增: 自动触发AI伴读
  await _checkAndAutoTriggerAICompanion();
}
```

**预期结果**:
- 章节加载完成后自动检查并触发伴读
- 章节切换时重置防抖标志

---

#### 步骤4.3: 实现_checkAndAutoTriggerAICompanion方法
**文件**: `novel_app/lib/screens/reader_screen.dart`

**位置**: 在 `_handleAICompanion` 方法之前添加

```dart
/// 检查并自动触发AI伴读
///
/// 触发条件:
/// 1. 未触发过(_hasAutoTriggered == false)
/// 2. 未正在运行(_isAutoCompanionRunning == false)
/// 3. 章节未伴读
/// 4. 自动伴读已启用(autoEnabled == true)
/// 5. 章节内容不为空
Future<void> _checkAndAutoTriggerAICompanion() async {
  // 防抖检查
  if (_hasAutoTriggered || _isAutoCompanionRunning) {
    debugPrint('🚫 AI伴读已触发或正在运行，跳过');
    return;
  }

  // 检查是否已伴读
  final hasAccompanied = await _databaseService.isChapterAccompanied(
    widget.novel.url,
    _currentChapter.url,
  );

  if (hasAccompanied) {
    debugPrint('✅ 章节已伴读，跳过自动触发');
    return;
  }

  // 获取AI伴读设置
  final settings = await _databaseService.getAiAccompanimentSettings(
    widget.novel.url,
  );

  if (!settings.autoEnabled) {
    debugPrint('🔕 自动伴读未启用');
    return;
  }

  // 检查章节内容
  final content = await _databaseService.getCachedChapterContent(
    widget.novel.url,
    _currentChapter.url,
  );

  if (content == null || content.isEmpty) {
    debugPrint('⚠️ 章节内容为空，跳过AI伴读');
    return;
  }

  // 开始自动伴读
  _hasAutoTriggered = true;
  _isAutoCompanionRunning = true;

  debugPrint('🤖 === 自动触发AI伴读 ===');
  debugPrint('章节: ${_currentChapter.title}');

  try {
    await _handleAICompanionSilent(settings);
  } catch (e) {
    debugPrint('❌ 自动AI伴读失败: $e');
    // 静默失败，不打扰用户
  } finally {
    _isAutoCompanionRunning = false;
  }
}
```

**预期结果**:
- 完整的触发条件检查
- 防抖机制生效
- 详细的日志输出

---

#### 步骤4.4: 实现_handleAICompanionSilent静默模式方法
**文件**: `novel_app/lib/screens/reader_screen.dart`

**位置**: 在 `_handleAICompanion` 方法之后添加

```dart
/// 静默模式AI伴读（不显示确认对话框）
///
/// 特点:
/// - 不显示loading SnackBar
/// - 不显示确认对话框
/// - 直接执行数据更新
/// - 根据设置显示Toast提示
/// - 错误时静默失败
Future<void> _handleAICompanionSilent(AiAccompanimentSettings settings) async {
  try {
    // 获取章节内容
    final content = await _databaseService.getCachedChapterContent(
      widget.novel.url,
      _currentChapter.url,
    );

    if (content == null || content.isEmpty) {
      debugPrint('⚠️ 章节内容为空，跳过AI伴读');
      return;
    }

    // 获取本书的所有角色
    final allCharacters = await _databaseService.getCharacters(
      widget.novel.url,
    );

    // 筛选当前章节出现的角色
    final chapterCharacters = await _filterCharactersInChapter(
      allCharacters,
      content,
    );

    // 获取这些角色的关系
    final chapterRelationships = await _getRelationshipsForCharacters(
      widget.novel.url,
      chapterCharacters,
    );

    debugPrint('📊 === AI伴读分析开始（静默模式）===');
    debugPrint('📚 小说总角色数: ${allCharacters.length}');
    debugPrint('👥 本章出现角色数: ${chapterCharacters.length}');
    debugPrint('🔗 相关关系数: ${chapterRelationships.length}');

    // 调用DifyService
    final response = await _difyService.generateAICompanion(
      chaptersContent: content,
      backgroundSetting: widget.novel.backgroundSetting ?? '',
      characters: chapterCharacters,
      relationships: chapterRelationships,
    );

    if (response == null) {
      throw Exception('AI伴读返回数据为空');
    }

    debugPrint('✅ === AI伴读分析完成 ===');
    debugPrint('👤 角色更新: ${response.roles.length}');
    debugPrint('🤝 关系更新: ${response.relations.length}');
    debugPrint('🌄 背景设定新增: ${response.background.length} 字符');
    debugPrint('📝 本章总结: ${response.summery.length} 字符');

    // 直接执行数据更新（不显示确认对话框）
    await _performAICompanionUpdates(response, isSilent: true);

    // 标记章节为已伴读
    await _databaseService.markChapterAsAccompanied(
      widget.novel.url,
      _currentChapter.url,
    );

    debugPrint('💾 章节已标记为已伴读');

    // 显示Toast提示（根据设置）
    if (settings.infoNotificationEnabled && mounted) {
      _showDynamicToast(response);
    }

    debugPrint('🎉 === 静默AI伴读完成 ===');
  } catch (e) {
    debugPrint('❌ 静默AI伴读失败: $e');
    // 静默失败，不打扰用户
    rethrow;  // 抛出异常供上层记录日志
  }
}

/// 根据AI伴读响应显示动态Toast
void _showDynamicToast(AICompanionResponse response) {
  final messages = <String>[];
  if (response.roles.isNotEmpty) messages.add('角色');
  if (response.relations.isNotEmpty) messages.add('关系');
  if (response.background.isNotEmpty) messages.add('背景');

  final message = messages.isEmpty
      ? 'AI伴读内容已更新'
      : 'AI伴读已完成: 更新${messages.join('、')}';

  ToastUtils.showSuccess(context, message);
  debugPrint('🔔 Toast提示: $message');
}
```

**预期结果**:
- 完全静默执行
- 自动标记已伴读
- 动态Toast提示
- 详细日志记录

---

#### 步骤4.5: 修改_performAICompanionUpdates支持静默模式
**文件**: `novel_app/lib/screens/reader_screen.dart`

**位置**: 第785行 `_performAICompanionUpdates` 方法

**操作**: 添加 `isSilent` 参数并修改UI提示逻辑

```dart
/// 执行AI伴读的数据更新
///
/// [response] AI伴读响应数据
/// [isSilent] 是否静默模式(默认false)
///   - true: 不显示SnackBar提示
///   - false: 显示更新进度和结果提示
Future<void> _performAICompanionUpdates(
  AICompanionResponse response, {
  bool isSilent = false,  // 新增参数
}) async {
  try {
    // 仅在非静默模式下显示进度提示
    if (!isSilent && mounted) {
      _showSnackBar(
        message: '正在更新数据...',
        backgroundColor: Colors.blue,
        duration: const Duration(minutes: 5),
      );
    }

    // 1. 追加背景设定
    if (response.background.isNotEmpty) {
      await _databaseService.appendBackgroundSetting(
        widget.novel.url,
        response.background,
      );
      debugPrint('✅ 背景设定已追加 (${response.background.length} 字符)');
    }

    // 2. 更新角色信息
    if (response.roles.isNotEmpty) {
      int updatedCount = 0;
      for (final roleUpdate in response.roles) {
        final success = await _databaseService.updateCharacter(
          widget.novel.url,
          roleUpdate.name,
          newDescription: roleUpdate.description,
          newAvatar: roleUpdate.avatar,
          newAttributes: roleUpdate.attributes,
        );
        if (success) updatedCount++;
      }
      debugPrint('✅ 成功更新 $updatedCount/${response.roles.length} 个角色');
    }

    // 3. 更新关系信息
    if (response.relations.isNotEmpty) {
      int updatedCount = 0;
      for (final relationUpdate in response.relations) {
        final success = await _databaseService.updateRelationship(
          widget.novel.url,
          relationUpdate.character1,
          relationUpdate.character2,
          newDescription: relationUpdate.description,
          newAttributes: relationUpdate.attributes,
        );
        if (success) updatedCount++;
      }
      debugPrint('✅ 成功更新 $updatedCount/${response.relations.length} 条关系');
    }

    // 仅在非静默模式下显示成功提示
    if (!isSilent && mounted) {
      _showSnackBar(
        message: '数据更新完成！',
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      );
    }

    debugPrint('🎉 AI伴读数据更新完成');
  } catch (e) {
    debugPrint('❌ 数据更新失败: $e');
    if (mounted) {
      _showSnackBar(
        message: '数据更新失败: $e',
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      );
    }
    rethrow;
  }
}
```

**预期结果**:
- 支持静默模式和非静默模式
- 静默模式不显示任何SnackBar
- 非静默模式保持原有体验

---

#### 步骤4.6: 修改手动触发逻辑更新标记
**文件**: `novel_app/lib/screens/reader_screen.dart`

**位置**: 第699行 `_handleAICompanion` 方法

**操作**: 在用户确认后添加标记更新

```dart
Future<void> _handleAICompanion() async {
  if (_content.isEmpty) {
    _showSnackBar(
      message: '章节内容为空，无法进行AI伴读',
      backgroundColor: Colors.orange,
    );
    return;
  }

  // 显示loading提示
  _showSnackBar(
    message: 'AI正在分析章节...',
    backgroundColor: Colors.blue,
    duration: const Duration(minutes: 5),
  );

  try {
    // ... 原有逻辑 (获取角色、关系、调用API) ...

    // 显示确认对话框
    if (mounted) {
      final confirmed = await showAICompanionConfirmDialog(
        context,
        response,
      );

      if (confirmed) {
        // 用户确认，执行数据更新
        await _performAICompanionUpdates(response);

        // 👇 新增: 标记章节为已伴读
        await _databaseService.markChapterAsAccompanied(
          widget.novel.url,
          _currentChapter.url,
        );
        debugPrint('💾 手动触发后章节已标记为已伴读');
      }
    }
  } catch (e) {
    debugPrint('❌ AI伴读失败: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnackBar(
        message: 'AI伴读失败: $e',
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      );
    }
  }
}
```

**预期结果**:
- 手动触发成功后也更新标记
- 避免自动触发重复执行
- 逻辑一致性

---

#### 步骤4.7: 强制刷新时重置标记
**文件**: `novel_app/lib/screens/reader_screen.dart`

**位置**: 第226行 `_loadChapterContent` 方法开头

**操作**: 在强制刷新时重置伴读标记

```dart
Future<void> _loadChapterContent(
    {bool resetScrollPosition = true, bool forceRefresh = false}) async {
  // 👇 新增: 如果是强制刷新，重置伴读标记
  if (forceRefresh) {
    await _databaseService.resetChapterAccompaniedFlag(
      widget.novel.url,
      _currentChapter.url,
    );
    debugPrint('🔄 强制刷新: 已重置伴读标记');
  }

  await _contentController.loadChapter(
    _currentChapter,
    widget.novel,
    forceRefresh: forceRefresh,
    resetScrollPosition: resetScrollPosition,
  );

  await _databaseService.markChapterAsRead(
    widget.novel.url,
    _currentChapter.url,
  );

  _handleScrollPosition(resetScrollPosition);
  await _startPreloadingChapters();

  // 重置防抖标志
  _hasAutoTriggered = false;

  // 自动触发AI伴读
  await _checkAndAutoTriggerAICompanion();
}
```

**预期结果**:
- 强制刷新时重置标记
- 允许重新触发AI伴读
- 日志清晰

---

### 阶段5: 测试验证

#### 步骤5.1: 单元测试
**文件**: `novel_app/test/unit/services/database_service_ai_accompanied_test.dart`

**测试用例**:
```dart
group('章节伴读标记测试', () {
  test('标记章节为已伴读', () async {
    await dbService.markChapterAsAccompanied(novelUrl, chapterUrl);
    final result = await dbService.isChapterAccompanied(novelUrl, chapterUrl);
    expect(result, true);
  });

  test('检查章节未伴读', () async {
    final result = await dbService.isChapterAccompanied(novelUrl, 'unknown_chapter');
    expect(result, false);
  });

  test('重置章节伴读标记', () async {
    await dbService.markChapterAsAccompanied(novelUrl, chapterUrl);
    await dbService.resetChapterAccompaniedFlag(novelUrl, chapterUrl);
    final result = await dbService.isChapterAccompanied(novelUrl, chapterUrl);
    expect(result, false);
  });

  test('批量重置小说所有章节', () async {
    // 准备数据
    await dbService.markChapterAsAccompanied(novelUrl, 'chapter1');
    await dbService.markChapterAsAccompanied(novelUrl, 'chapter2');

    // 批量重置
    await dbService.resetAllNovelAccompaniedFlags(novelUrl);

    // 验证
    final result1 = await dbService.isChapterAccompanied(novelUrl, 'chapter1');
    final result2 = await dbService.isChapterAccompanied(novelUrl, 'chapter2');
    expect(result1, false);
    expect(result2, false);
  });
});
```

**预期结果**:
- 所有单元测试通过
- 覆盖率 > 90%

---

#### 步骤5.2: 集成测试场景

**场景1: 首次阅读章节**
```
前置条件:
- 自动伴读: 启用
- 信息提示: 启用
- 章节未伴读

操作步骤:
1. 打开章节
2. 等待章节加载完成
3. 观察2-5秒

预期结果:
✅ 章节正常显示
✅ 无loading SnackBar
✅ 无确认对话框
✅ 后台静默执行AI伴读
✅ 完成后显示Toast: "AI伴读已完成: 更新角色、关系"
✅ 数据库标记: ai_accompanied = 1
```

**场景2: 回顾已伴读章节**
```
前置条件:
- 自动伴读: 启用
- 章节已伴读(ai_accompanied = 1)

操作步骤:
1. 重新打开已伴读的章节

预期结果:
✅ 章节正常显示
✅ 不触发AI伴读
✅ 日志: "章节已伴读，跳过自动触发"
```

**场景3: 自动伴读未启用**
```
前置条件:
- 自动伴读: 未启用
- 章节未伴读

操作步骤:
1. 打开章节

预期结果:
✅ 章节正常显示
✅ 不触发AI伴读
✅ 日志: "自动伴读未启用"
```

**场景4: 信息提示关闭**
```
前置条件:
- 自动伴读: 启用
- 信息提示: 关闭
- 章节未伴读

操作步骤:
1. 打开章节
2. 等待伴读完成

预期结果:
✅ 章节正常显示
✅ AI伴读静默执行
✅ 不显示Toast
✅ 数据正常更新
```

**场景5: 强制刷新章节**
```
前置条件:
- 章节已伴读(ai_accompanied = 1)

操作步骤:
1. 长按章节内容
2. 选择"刷新"或"强制刷新"

预期结果:
✅ 章节内容重新加载
✅ 伴读标记重置为0
✅ 如果自动伴读启用，重新触发AI伴读
```

**场景6: 手动触发伴读**
```
前置条件:
- 章节未伴读

操作步骤:
1. 打开章节菜单
2. 点击"AI伴读"
3. 等待分析完成
4. 查看确认对话框
5. 点击"确认更新"

预期结果:
✅ 显示loading SnackBar
✅ 显示确认对话框
✅ 确认后数据更新
✅ 伴读标记设置为1
✅ 成功提示SnackBar
```

**场景7: 快速切换章节(防抖测试)**
```
前置条件:
- 自动伴读: 启用
- 连续3个章节未伴读

操作步骤:
1. 快速连续打开章节1 → 章节2 → 章节3
2. 停留在章节3

预期结果:
✅ 每个章节只触发一次AI伴读
✅ 不重复触发同一章节
✅ 日志显示防抖生效
```

**场景8: AI伴读失败**
```
前置条件:
- 自动伴读: 启用
- Dify服务异常(模拟)

操作步骤:
1. 打开章节

预期结果:
✅ 章节正常显示
✅ 无错误提示(静默失败)
✅ 日志记录错误
✅ 伴读标记仍为0(可重试)
```

---

#### 步骤5.3: 性能测试

**测试指标**:
```dart
// 测试伴读标记查询性能
final stopwatch = Stopwatch()..start();
final result = await dbService.isChapterAccompanied(novelUrl, chapterUrl);
stopwatch.stop();

print('查询耗时: ${stopwatch.elapsedMilliseconds}ms');

// 预期: < 10ms
```

**预期结果**:
- 标记查询 < 10ms
- 标记更新 < 50ms
- 不影响章节加载速度

---

#### 步骤5.4: 兼容性测试

**测试场景**:
```
1. 旧版本用户升级:
   - 数据库从v3升级到v4
   - 现有章节ai_accompanied = 0
   - 不影响现有功能

2. 新用户安装:
   - 直接创建v4数据库
   - 字段默认值为0

3. 跨设备同步(如果支持):
   - 伴读标记本地存储
   - 不同设备独立标记
```

**预期结果**:
- 升级平滑无错误
- 新用户功能正常
- 兼容旧数据

---

## 📝 实施注意事项

### 开发规范
1. **日志规范**: 所有新增方法添加详细日志
2. **错误处理**: 静默模式只记录日志，不显示UI
3. **代码复用**: 静默模式和手动模式共用 `_performAICompanionUpdates`
4. **状态管理**: 防抖标志在章节切换时重置

### 测试策略
1. **单元测试**: 数据库方法必须有单元测试
2. **集成测试**: 至少覆盖8个核心场景
3. **性能测试**: 确保不影响阅读体验

### 向后兼容
1. **数据库迁移**: 自动升级v3→v4
2. **默认值**: 新字段默认为0(未伴读)
3. **降级支持**: Alembic downgrade可用

### 用户体验
1. **静默优先**: 不打扰用户阅读
2. **可控性**: 用户可关闭自动伴读和信息提示
3. **透明性**: Toast提示让用户知道后台工作
4. **性能**: 不阻塞章节加载

---

## 📂 涉及文件清单

### Backend (3个文件)
```
backend/
├── alembic/versions/
│   └── [timestamp]_add_ai_accompanied_to_chapter_cache.py  # 新建
└── app/models/
    └── scene_comfyui_mapping.py                            # 修改
```

### Frontend (3个文件)
```
novel_app/
├── lib/
│   ├── models/
│   │   └── chapter.dart                                    # 修改
│   ├── screens/
│   │   └── reader_screen.dart                              # 修改
│   └── services/
│       └── database_service.dart                           # 修改
└── test/
    └── unit/
        └── services/
            └── database_service_ai_accompanied_test.dart   # 新建
```

---

## ✅ 验收标准

### 功能验收
- [ ] 自动伴读触发功能正常
- [ ] 已伴读章节不重复触发
- [ ] 静默模式无弹窗干扰
- [ ] Toast提示根据设置显示
- [ ] 手动触发也更新标记
- [ ] 强制刷新重置标记
- [ ] 防抖机制生效

### 性能验收
- [ ] 章节加载速度不受影响
- [ ] 标记查询 < 10ms
- [ ] AI伴读不阻塞UI

### 兼容性验收
- [ ] 旧版本用户升级无问题
- [ ] 新用户功能正常
- [ ] 数据库迁移成功

### 测试验收
- [ ] 单元测试全部通过
- [ ] 集成测试场景全部通过
- [ ] 无明显bug或崩溃

---

## 🚀 执行计划

### 估计工作量
- Backend迁移: 30分钟
- Frontend数据库升级: 1小时
- ReaderScreen实现: 2小时
- 测试验证: 1.5小时
- **总计**: 约5小时

### 执行顺序
1. ✅ Backend数据库迁移和模型更新
2. ✅ Frontend数据库升级
3. ✅ 数据模型扩展
4. ✅ ReaderScreen核心逻辑实现
5. ✅ 测试验证

---

**计划状态**: 待用户批准

**准备就绪**: 所有技术细节已规划完成，等待您的确认后进入执行阶段！

**请确认**: 是否批准此计划并开始实施？
