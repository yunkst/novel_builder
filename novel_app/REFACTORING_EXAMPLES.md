# 重构实战示例

本文档提供具体的重构示例，展示如何将超大文件重构为更小、更易维护的模块。

---

## 示例1: database_service.dart 拆分

### 问题分析

**当前状态**: `lib/services/database_service.dart` (3,543行)

```dart
class DatabaseService {
  // 100+ 方法混合在一起
  Future<int> addToBookshelf(Novel novel) async { ... }
  Future<int> cacheChapter(...) async { ... }
  Future<int> createCharacter(...) async { ... }
  Future<int> createRelationship(...) async { ... }
  // ... 还有90+方法
}
```

**问题**:
- 单一类承担8种职责
- 100+方法难以查找和维护
- 测试困难
- 违反单一职责原则

### 重构步骤

#### 第1步: 创建Repository目录结构

```bash
mkdir -p lib/services/database/repositories
mkdir -p lib/services/database/migrations
```

#### 第2步: 提取NovelRepository

**创建文件**: `lib/services/database/repositories/novel_repository.dart`

```dart
import 'package:sqflite/sqflite.dart';
import '../../models/novel.dart';

/// 小说数据访问仓库
///
/// 职责:
/// - 小说CRUD操作
/// - 书架管理
/// - 阅读进度跟踪
class NovelRepository {
  final Database _database;

  NovelRepository(this._database);

  /// 获取所有小说
  Future<List<Novel>> getAll() async {
    final List<Map<String, dynamic>> maps = await _database.query(
      'novels', // 使用语义视图
      orderBy: 'lastReadChapter DESC',
    );
    return List.generate(maps.length, (i) => Novel.fromMap(maps[i]));
  }

  /// 添加小说到书架
  Future<int> add(Novel novel) async {
    return await _database.insert(
      'bookshelf', // 使用物理表进行修改
      novel.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 从书架移除小说
  Future<int> remove(String novelUrl) async {
    return await _database.delete(
      'bookshelf',
      where: 'url = ?',
      whereArgs: [novelUrl],
    );
  }

  /// 检查小说是否在书架中
  Future<bool> contains(String novelUrl) async {
    final results = await _database.query(
      'bookshelf',
      where: 'url = ?',
      whereArgs: [novelUrl],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// 更新阅读进度
  Future<int> updateProgress(String novelUrl, int chapterIndex) async {
    return await _database.update(
      'bookshelf',
      {
        'lastReadChapter': chapterIndex,
        'lastReadTime': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'url = ?',
      whereArgs: [novelUrl],
    );
  }

  /// 获取背景设定
  Future<String?> getBackgroundSetting(String novelUrl) async {
    final results = await _database.query(
      'bookshelf',
      columns: ['backgroundSetting'],
      where: 'url = ?',
      whereArgs: [novelUrl],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['backgroundSetting'] as String?;
  }

  /// 更新背景设定
  Future<int> updateBackgroundSetting(
    String novelUrl,
    String backgroundSetting,
  ) async {
    return await _database.update(
      'bookshelf',
      {'backgroundSetting': backgroundSetting},
      where: 'url = ?',
      whereArgs: [novelUrl],
    );
  }

  /// 更新小说信息
  Future<int> update(Novel novel) async {
    return await _database.update(
      'bookshelf',
      novel.toMap(),
      where: 'url = ?',
      whereArgs: [novel.url],
    );
  }
}
```

#### 第3步: 提取ChapterRepository

**创建文件**: `lib/services/database/repositories/chapter_repository.dart`

```dart
import 'package:sqflite/sqflite.dart';
import '../../models/chapter.dart';

/// 章节数据访问仓库
///
/// 职责:
/// - 章节CRUD操作
/// - 章节缓存管理
/// - 用户插入章节管理
class ChapterRepository {
  final Database _database;

  ChapterRepository(this._database);

  /// 缓存章节内容
  Future<int> cache(String chapterUrl, String content) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return await _database.insert(
      'chapter_cache',
      {
        'url': chapterUrl,
        'content': content,
        'cachedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取缓存章节
  Future<Map<String, dynamic>?> getCached(String chapterUrl) async {
    final results = await _database.query(
      'chapter_cache',
      where: 'url = ?',
      whereArgs: [chapterUrl],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first;
  }

  /// 获取章节内容
  Future<String?> getContent(String chapterUrl) async {
    final cached = await getCached(chapterUrl);
    return cached?['content'] as String?;
  }

  /// 检查章节是否已缓存
  Future<bool> isCached(String chapterUrl) async {
    final cached = await getCached(chapterUrl);
    return cached != null;
  }

  /// 批量检查章节缓存状态
  Future<Map<String, bool>> getCacheStatus(List<String> chapterUrls) async {
    final results = await _database.query(
      'chapter_cache',
      where: 'url IN (${List.filled(chapterUrls.length, '?').join(',')})',
      whereArgs: chapterUrls,
    );

    final cachedUrls = results.map((r) => r['url'] as String).toSet();

    return Map.fromEntries(
      chapterUrls.map((url) => MapEntry(url, cachedUrls.contains(url))),
    );
  }

  /// 删除缓存
  Future<int> deleteCache(String chapterUrl) async {
    return await _database.delete(
      'chapter_cache',
      where: 'url = ?',
      whereArgs: [chapterUrl],
    );
  }

  /// 删除小说的所有缓存
  Future<int> deleteNovelCache(String novelUrl) async {
    return await _database.delete(
      'chapter_cache',
      where: 'url LIKE ?',
      whereArgs: ['$novelUrl%'],
    );
  }

  /// 获取小说的所有缓存章节数
  Future<int> getCachedCount(String novelUrl) async {
    final result = await _database.rawQuery('''
      SELECT COUNT(*) as count
      FROM chapter_cache
      WHERE url LIKE ?
    ''', ['$novelUrl%']);

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 插入用户章节
  Future<void> insertUserChapter({
    required String novelUrl,
    required String chapterTitle,
    required String chapterContent,
    required int chapterIndex,
  }) async {
    final chapterUrl = 'user://$novelUrl/$chapterIndex';

    await _database.insert(
      'novel_chapters',
      {
        'novelUrl': novelUrl,
        'title': chapterTitle,
        'url': chapterUrl,
        'chapterIndex': chapterIndex,
        'isUserInserted': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await cache(chapterUrl, chapterContent);
  }

  /// 更新自定义章节
  Future<void> updateCustomChapter({
    required String chapterUrl,
    required String title,
    required String content,
  }) async {
    await _database.update(
      'novel_chapters',
      {'title': title},
      where: 'url = ?',
      whereArgs: [chapterUrl],
    );

    await cache(chapterUrl, content);
  }

  /// 删除自定义章节
  Future<void> deleteCustomChapter(String chapterUrl) async {
    await _database.delete(
      'novel_chapters',
      where: 'url = ? AND isUserInserted = 1',
      whereArgs: [chapterUrl],
    );

    await deleteCache(chapterUrl);
  }

  /// 获取小说的所有章节
  Future<List<Chapter>> getNovelChapters(String novelUrl) async {
    final results = await _database.query(
      'novel_chapters',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
      orderBy: 'chapterIndex ASC',
    );

    return results.map((map) => Chapter.fromMap(map)).toList();
  }
}
```

#### 第4步: 简化DatabaseService

**修改文件**: `lib/services/database_service.dart`

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'repositories/novel_repository.dart';
import 'repositories/chapter_repository.dart';
import 'repositories/character_repository.dart';
import 'repositories/relationship_repository.dart';
import 'repositories/illustration_repository.dart';
import '../models/novel.dart';

/// 数据库服务（简化版）
///
/// 职责:
/// - 数据库初始化和迁移
/// - 提供Repository访问
/// - 管理数据库连接
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  // ========== Repository实例 ==========

  late NovelRepository _novelRepo;
  late ChapterRepository _chapterRepo;
  late CharacterRepository _characterRepo;
  late RelationshipRepository _relationshipRepo;
  late IllustrationRepository _illustrationRepo;

  /// 获取数据库连接
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    _initRepositories();
    return _database!;
  }

  /// 初始化Repository
  void _initRepositories() {
    _novelRepo = NovelRepository(_database!);
    _chapterRepo = ChapterRepository(_database!);
    _characterRepo = CharacterRepository(_database!);
    _relationshipRepo = RelationshipRepository(_database!);
    _illustrationRepo = IllustrationRepository(_database!);
  }

  // ========== 便捷访问器 ==========

  NovelRepository get novels => _novelRepo;
  ChapterRepository get chapters => _chapterRepo;
  CharacterRepository get characters => _characterRepo;
  RelationshipRepository get relationships => _relationshipRepo;
  IllustrationRepository get illustrations => _illustrationRepo;

  // ========== 向后兼容方法（废弃）==========

  @Deprecated('Use novels.add() instead. Will be removed in v2.0.0')
  Future<int> addToBookshelf(Novel novel) => _novelRepo.add(novel);

  @Deprecated('Use novels.remove() instead. Will be removed in v2.0.0')
  Future<int> removeFromBookshelf(String novelUrl) => _novelRepo.remove(novelUrl);

  @Deprecated('Use novels.getAll() instead. Will be removed in v2.0.0')
  Future<List<Novel>> getBookshelf() => _novelRepo.getAll();

  // ========== 数据库初始化（保持原有逻辑）==========

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'novel_reader.db');

    return await openDatabase(
      path,
      version: 21,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ... 创建表逻辑
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // ... 迁移逻辑
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
```

#### 第5步: 更新调用方

**修改前**:
```dart
// lib/screens/bookshelf_screen.dart
class _BookshelfScreenState extends State<BookshelfScreen> {
  final DatabaseService _db = DatabaseService();

  Future<void> _loadNovels() async {
    final novels = await _db.getBookshelf();
    setState(() {
      _novels = novels;
    });
  }

  Future<void> _addNovel(Novel novel) async {
    await _db.addToBookshelf(novel);
    await _loadNovels();
  }
}
```

**修改后**:
```dart
// lib/screens/bookshelf_screen.dart
class _BookshelfScreenState extends State<BookshelfScreen> {
  final DatabaseService _db = DatabaseService();

  Future<void> _loadNovels() async {
    // 使用新的Repository API
    final novels = await _db.novels.getAll();
    setState(() {
      _novels = novels;
    });
  }

  Future<void> _addNovel(Novel novel) async {
    // 使用新的Repository API
    await _db.novels.add(novel);
    await _loadNovels();
  }
}
```

### 重构效果

**重构前**:
- 文件行数: 3,543行
- 类数量: 1个
- 方法数量: 100+个
- 职责数量: 8种

**重构后**:
```
lib/services/database/
├── database_service.dart              # ~300行 (只负责初始化)
└── repositories/
    ├── novel_repository.dart          # ~200行 (1种职责)
    ├── chapter_repository.dart        # ~250行 (1种职责)
    ├── character_repository.dart      # ~200行 (1种职责)
    ├── relationship_repository.dart   # ~180行 (1种职责)
    └── illustration_repository.dart   # ~150行 (1种职责)
```

**收益**:
- ✅ 单个文件<300行
- ✅ 职责清晰
- ✅ 易于测试
- ✅ 便于扩展
- ✅ 向后兼容

---

## 示例2: reader_screen.dart 简化

### 问题分析

**当前状态**: `lib/screens/reader_screen.dart` (1,734行)

```dart
class _ReaderScreenState extends State<ReaderScreen> {
  // build()方法就有372行！
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(...),
      body: Column(
        children: [
          // 300+行的UI代码
          _buildContent(),
          _buildActionBar(),
          _buildSettingsBar(),
          _buildAIPanel(),
          // ...
        ],
      ),
    );
  }
}
```

### 重构步骤

#### 第1步: 创建ReaderAIController

**创建文件**: `lib/screens/reader/controllers/reader_ai_controller.dart`

```dart
import '../services/dify_service.dart';
import '../../models/character.dart';
import '../../models/character_relationship.dart';

/// 阅读器AI功能控制器
///
/// 职责:
/// - AI伴读功能
/// - 角色卡片更新
/// - 段落重写
/// - 章节摘要
class ReaderAIController {
  final DifyService _difyService = DifyService();

  /// 更新角色卡片
  Future<List<Character>> updateCharacterCards({
    required String novelUrl,
    required List<Character> existingCharacters,
    required String chapterContent,
  }) async {
    try {
      final updatedCharacters = await _difyService.updateCharacterCards(
        novelUrl: novelUrl,
        characters: existingCharacters,
        chapterContent: chapterContent,
      );
      return updatedCharacters;
    } catch (e) {
      // 错误处理
      rethrow;
    }
  }

  /// 段落重写
  Future<String> rewriteParagraph({
    required String paragraph,
    required String userInstruction,
  }) async {
    // AI重写逻辑
    return await _difyService.rewriteParagraph(
      paragraph: paragraph,
      instruction: userInstruction,
    );
  }

  /// 生成章节摘要
  Future<String> generateSummary({
    required String chapterContent,
  }) async {
    // AI摘要逻辑
    return await _difyService.generateSummary(
      content: chapterContent,
    );
  }

  /// 全章重写
  Future<String> rewriteFullChapter({
    required String chapterContent,
    required String userInstruction,
  }) async {
    // 全章重写逻辑
    return await _difyService.rewriteFullChapter(
      content: chapterContent,
      instruction: userInstruction,
    );
  }
}
```

#### 第2步: 提取子Widget

**创建文件**: `lib/screens/reader/widgets/reader_ai_panel.dart`

```dart
import 'package:flutter/material.dart';
import '../../controllers/reader_ai_controller.dart';
import 'paragraph_rewrite_dialog.dart';
import 'chapter_summary_dialog.dart';
import 'full_rewrite_dialog.dart';

/// 阅读器AI功能面板
class ReaderAIPanel extends StatelessWidget {
  final ReaderAIController aiController;
  final String paragraph;
  final String chapterContent;
  final VoidCallback onRefresh;

  const ReaderAIPanel({
    Key? key,
    required this.aiController,
    required this.paragraph,
    required this.chapterContent,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAIButton(
            icon: Icons.edit,
            label: '段落重写',
            onTap: () => _showParagraphRewrite(context),
          ),
          _buildAIButton(
            icon: Icons.summarize,
            label: '章节摘要',
            onTap: () => _showChapterSummary(context),
          ),
          _buildAIButton(
            icon: Icons.auto_fix_high,
            label: '全章重写',
            onTap: () => _showFullRewrite(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAIButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }

  void _showParagraphRewrite(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ParagraphRewriteDialog(
        paragraph: paragraph,
        aiController: aiController,
        onRewrite: onRefresh,
      ),
    );
  }

  void _showChapterSummary(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ChapterSummaryDialog(
        chapterContent: chapterContent,
        aiController: aiController,
      ),
    );
  }

  void _showFullRewrite(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FullRewriteDialog(
        chapterContent: chapterContent,
        aiController: aiController,
        onRewrite: onRefresh,
      ),
    );
  }
}
```

#### 第3步: 简化主Screen

**修改文件**: `lib/screens/reader_screen.dart`

```dart
class _ReaderScreenState extends State<ReaderScreen> {
  late ReaderContentController _contentController;
  late ReaderInteractionController _interactionController;
  late ReaderAIController _aiController; // 新增

  @override
  void initState() {
    super.initState();
    _contentController = ReaderContentController(...);
    _interactionController = ReaderInteractionController(...);
    _aiController = ReaderAIController(); // 新增
    _loadChapterContent();
  }

  @override
  Widget build(BuildContext context) {
    // 简化后的build方法：<100行
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ReaderContentView(
              content: _content,
              paragraphs: _paragraphs,
              scrollController: _scrollController,
              onParagraphTap: _handleParagraphTap,
              onParagraphLongPress: _handleLongPress,
            ),
          ),
          ReaderActionBar(
            currentIndex: _currentChapterIndex,
            totalChapters: widget.chapters.length,
            onPrevious: _goToPreviousChapter,
            onNext: _goToNextChapter,
            onFontSize: _showFontSizeDialog,
            onScrollSpeed: _showScrollSpeedDialog,
            onTTS: _startTtsReading,
          ),
          if (_isCloseupMode)
            ReaderAIPanel(
              aiController: _aiController,
              paragraph: _selectedParagraph,
              chapterContent: _content,
              onRefresh: _loadChapterContent,
            ),
        ],
      ),
    );
  }

  // AI相关方法简化
  Future<void> _handleAICompanion() async {
    await _aiController.updateCharacterCards(
      novelUrl: widget.novel.url,
      existingCharacters: _characters,
      chapterContent: _content,
    );
    await _loadChapterContent();
  }

  Future<void> _showParagraphRewriteDialog() async {
    // 逻辑已移到ReaderAIPanel
  }
}
```

### 重构效果

**重构前**:
- 文件行数: 1,734行
- build()方法: 372行
- 职责: UI + 业务逻辑混合

**重构后**:
```
lib/screens/reader/
├── reader_screen.dart                 # ~300行
├── controllers/
│   ├── reader_content_controller.dart # (已存在)
│   ├── reader_interaction_controller.dart # (已存在)
│   └── reader_ai_controller.dart      # ~200行 (新增)
└── widgets/
    ├── reader_content_view.dart       # ~200行 (新增)
    ├── reader_action_bar.dart         # ~150行 (新增)
    └── reader_ai_panel.dart           # ~150行 (新增)
```

**收益**:
- ✅ build()方法<100行
- ✅ AI功能可独立测试
- ✅ Widget可复用
- ✅ 职责清晰

---

## 通用重构模式总结

### 1. Repository模式
**适用场景**: 数据访问逻辑复杂
**步骤**:
1. 识别不同数据实体（Novel, Chapter, Character等）
2. 为每个实体创建Repository类
3. 将相关方法从Service迁移到Repository
4. 在Service中提供便捷访问器
5. 逐步更新调用方

### 2. Controller模式
**适用场景**: UI组件包含过多业务逻辑
**步骤**:
1. 识别UI中的业务逻辑（AI调用、数据处理等）
2. 创建Controller类
3. 将业务逻辑移到Controller
4. 在State中初始化Controller
5. 简化build()方法

### 3. Widget提取模式
**适用场景**: UI组件过于复杂
**步骤**:
1. 识别UI中可独立的区域
2. 为每个区域创建子Widget
3. 将相关UI代码移到子Widget
4. 通过参数传递数据和回调
5. 简化父Widget

### 4. Service分离模式
**适用场景**: Service承担多种职责
**步骤**:
1. 识别Service中的不同功能域
2. 为每个功能域创建专门的服务类
3. 提取通用逻辑到基础服务
4. 在专门服务中组合基础服务
5. 更新调用方

---

## 重构注意事项

### ✅ DO (应该做的)

1. **小步快跑**: 每次只重构一个文件或一个类
2. **保持测试**: 每次重构后都要运行测试
3. **向后兼容**: 使用@Deprecated标记旧方法
4. **充分测试**: 确保功能不变
5. **文档更新**: 更新相关文档和注释

### ❌ DON'T (不应该做的)

1. **不要重写**: 重构≠重写，保持现有逻辑
2. **不要一次改太多**: 避免大爆炸式重构
3. **不要忽略测试**: 没有测试不要重构
4. **不要破坏兼容**: 给调用方留出迁移时间
5. **不要过度优化**: 保持代码简洁易懂

---

## 重构工具推荐

### 1. 静态分析
```bash
# 运行Flutter分析
flutter analyze

# 格式化代码
flutter format .

# 检查代码行数
find lib -name "*.dart" -exec wc -l {} + | sort -rn | head -20
```

### 2. IDE辅助
- 使用"Extract Method"重构功能
- 使用"Extract Widget"重构功能
- 使用"Rename"批量重命名
- 使用"Find References"查找调用

### 3. Git工作流
```bash
# 创建重构分支
git checkout -b refactor/xyz-service

# 小步提交
git add lib/services/xyz/
git commit -m "refactor(xyz): Extract XRepository"

# 完成后合并
git checkout main
git merge refactor/xyz-service
```

---

*记住: 重构是一个持续的过程，不要试图一次性解决所有问题。*
