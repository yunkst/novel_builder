import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:novel_app/services/api_service_wrapper.dart';
import 'package:novel_app/services/chapter_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局测试标志 - 标识是否在测试环境中
bool _isTestEnvironment = false;

/// 全局测试初始化
///
/// 在所有测试的 main() 函数开始时调用此函数
/// 统一处理测试环境的初始化，包括：
/// - Flutter测试绑定
/// - 数据库FFI初始化
///
/// 使用示例：
/// ```dart
/// void main() {
///   initTests(); // 统一初始化
///
///   group('MyTestGroup', () {
///     // 测试代码
///   });
/// }
/// ```
void initTests() {
  // 标记为测试环境
  _isTestEnvironment = true;

  // 确保Flutter测试绑定已初始化
  TestWidgetsFlutterBinding.ensureInitialized();

  // 设置SharedPreferences Mock（用于测试本地存储操作）
  SharedPreferences.setMockInitialValues({});

  // 设置ChapterManager为测试模式(禁用定时器)
  ChapterManager.setTestMode(true);

  // 初始化SQLite FFI（用于测试环境）
  sqfliteFfiInit();

  // 设置数据库工厂为FFI实现
  databaseFactory = databaseFactoryFfi;

  // 设置PathProvider Mock（用于测试文件系统操作）
  PathProviderPlatform.instance = _FakePathProviderPlatform();

  // 打印初始化成功信息（仅在调试时）
  // ignore: avoid_print
  print('✅ 测试环境初始化完成 (SQLite FFI + PathProvider Mock)');
}

/// 创建数据库测试专用的初始化函数
///
/// 对于需要使用数据库的测试，使用此函数
/// 它会额外配置数据库相关的设置
void initDatabaseTests() {
  // 先执行通用初始化
  initTests();

  // 可以在这里添加更多数据库测试特定配置
  // ignore: avoid_print
  print('✅ 数据库测试环境初始化完成');
}

/// 初始化API服务（用于测试）
///
/// 对于需要使用API服务的测试，使用此函数
/// 它会初始化ApiServiceWrapper单例
///
/// 注意：这会创建一个真实的实例，如果需要完全隔离，
/// 应该在测试中使用Mock替代
void initApiServiceTests() {
  // 先执行通用初始化
  initTests();

  // 尝试初始化ApiServiceWrapper
  try {
    ApiServiceWrapper();
    // ignore: avoid_print
    print('✅ API服务初始化完成');
  } catch (e) {
    // 忽略初始化错误，测试可能使用Mock
    // ignore: avoid_print
    print('⚠️  API服务初始化跳过: $e');
  }
}

/// 检查是否在测试环境中运行
bool get isTestEnvironment => _isTestEnvironment;

/// 创建测试专用的内存数据库
///
/// 为每个测试创建独立的内存数据库，避免锁定问题
/// 使用示例：
/// ```dart
/// late Database testDb;
/// setUp(() async {
///   testDb = createInMemoryDatabase();
/// });
/// tearDown(() async {
///   await testDb.close();
/// });
/// ```
Future<Database> createInMemoryDatabase() async {
  // 确保已初始化
  if (!isTestEnvironment) {
    initTests();
  }

  // 创建内存数据库（每个调用都是独立的）
  return await databaseFactory!.openDatabase(
    ':memory:', // 内存数据库路径
    options: OpenDatabaseOptions(
      version: 21, // 与主数据库版本保持一致
      onCreate: (Database db, int version) async {
        // 这里需要重新创建表结构
        // 为了简化，我们直接从DatabaseService复制创建逻辑
        await _createTestDatabaseSchema(db, version);
      },
      onUpgrade: _onUpgradeTestDatabase,
      singleInstance: false, // 允许多个实例（关键!）
    ),
  );
}

/// 创建测试数据库的表结构
Future<void> _createTestDatabaseSchema(Database db, int version) async {
  // 创建小说表
  await db.execute('''
    CREATE TABLE bookshelf (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      author TEXT NOT NULL,
      url TEXT NOT NULL UNIQUE,
      coverUrl TEXT,
      description TEXT,
      backgroundSetting TEXT,
      addedAt INTEGER NOT NULL,
      lastReadChapter INTEGER DEFAULT 0,
      lastReadTime INTEGER,
      aiAccompanimentEnabled INTEGER DEFAULT 0,
      aiInfoNotificationEnabled INTEGER DEFAULT 0
    )
  ''');

  // 创建章节缓存表
  await db.execute('''
    CREATE TABLE chapter_cache (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      novelUrl TEXT NOT NULL,
      chapterUrl TEXT NOT NULL UNIQUE,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      chapterIndex INTEGER,
      cachedAt INTEGER NOT NULL,
      isUserInserted INTEGER DEFAULT 0,
      isAccompanied INTEGER DEFAULT 0
    )
  ''');

  // 创建章节元数据表 (注意：使用chapterUrl而不是url)
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
      readAt INTEGER,
      UNIQUE(novelUrl, chapterUrl)
    )
  ''');

  // 创建角色表 (完整字段)
  await db.execute('''
    CREATE TABLE characters (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      novelUrl TEXT NOT NULL,
      name TEXT NOT NULL,
      age INTEGER,
      gender TEXT,
      occupation TEXT,
      personality TEXT,
      bodyType TEXT,
      clothingStyle TEXT,
      appearanceFeatures TEXT,
      backgroundStory TEXT,
      facePrompts TEXT,
      bodyPrompts TEXT,
      cachedImageUrl TEXT,
      aliases TEXT DEFAULT '[]',
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER,
      UNIQUE(novelUrl, name)
    )
  ''');

  // 创建角色关系表
  await db.execute('''
    CREATE TABLE character_relationships (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      source_character_id INTEGER NOT NULL,
      target_character_id INTEGER NOT NULL,
      relationship_type TEXT NOT NULL,
      description TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER,
      FOREIGN KEY (source_character_id) REFERENCES characters(id) ON DELETE CASCADE,
      FOREIGN KEY (target_character_id) REFERENCES characters(id) ON DELETE CASCADE,
      UNIQUE(source_character_id, target_character_id, relationship_type)
    )
  ''');

  // 创建场景插图表
  await db.execute('''
    CREATE TABLE scene_illustrations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      novel_url TEXT NOT NULL,
      chapter_id TEXT NOT NULL,
      task_id TEXT NOT NULL UNIQUE,
      content TEXT NOT NULL,
      roles TEXT NOT NULL,
      image_count INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      images TEXT DEFAULT '',
      prompts TEXT,
      created_at TEXT NOT NULL,
      completed_at TEXT
    )
  ''');

  // 创建AI伴读设置表
  await db.execute('''
    CREATE TABLE ai_accompaniment_settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      novelUrl TEXT NOT NULL UNIQUE,
      enabled INTEGER NOT NULL DEFAULT 0
    )
  ''');

  // 创建AI伴读响应表
  await db.execute('''
    CREATE TABLE ai_companion_responses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      novelUrl TEXT NOT NULL,
      chapterUrl TEXT NOT NULL,
      response TEXT NOT NULL,
      createdAt INTEGER NOT NULL,
      UNIQUE(novelUrl, chapterUrl)
    )
  ''');

  // 创建novels视图
  await db.execute('CREATE VIEW novels AS SELECT * FROM bookshelf');

  // 创建大纲表
  await db.execute('''
    CREATE TABLE outlines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      novel_url TEXT NOT NULL UNIQUE,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');

  // 创建聊天场景表
  await db.execute('''
    CREATE TABLE chat_scenes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER
    )
  ''');

  // 创建书架分类表
  await db.execute('''
    CREATE TABLE bookshelves (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      sort_order INTEGER DEFAULT 0,
      icon TEXT DEFAULT 'book',
      color INTEGER DEFAULT 0xFF2196F3,
      is_system INTEGER DEFAULT 0
    )
  ''');

  // 创建小说-书架关联表
  await db.execute('''
    CREATE TABLE novel_bookshelves (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      novel_url TEXT NOT NULL,
      bookshelf_id INTEGER NOT NULL,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      FOREIGN KEY (novel_url) REFERENCES bookshelf(url) ON DELETE CASCADE,
      FOREIGN KEY (bookshelf_id) REFERENCES bookshelves(id) ON DELETE CASCADE,
      UNIQUE(novel_url, bookshelf_id)
    )
  ''');

  // 创建章节AI伴读状态表
  await db.execute('''
    CREATE TABLE chapter_ai_accompaniment (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      novelUrl TEXT NOT NULL,
      chapterUrl TEXT NOT NULL,
      isAccompanied INTEGER NOT NULL DEFAULT 0,
      UNIQUE(novelUrl, chapterUrl)
    )
  ''');

  // 创建索引
  await db.execute(
      'CREATE INDEX idx_chapter_cache_novel_url ON chapter_cache(novelUrl)');
  await db.execute(
      'CREATE INDEX idx_chapter_cache_chapter_url ON chapter_cache(chapterUrl)');
  await db.execute(
      'CREATE INDEX idx_novel_chapters_novel_url ON novel_chapters(novelUrl)');
  await db.execute(
      'CREATE INDEX idx_novel_chapters_chapter_url ON novel_chapters(chapterUrl)');
  await db.execute(
      'CREATE INDEX idx_novel_chapters_chapter_index ON novel_chapters(chapterIndex)');
  await db
      .execute('CREATE INDEX idx_characters_novel_url ON characters(novelUrl)');
  await db.execute(
      'CREATE INDEX idx_relationships_source ON character_relationships(source_character_id)');
  await db.execute(
      'CREATE INDEX idx_relationships_target ON character_relationships(target_character_id)');
  await db.execute('CREATE INDEX idx_chat_scenes_title ON chat_scenes(title)');
  await db.execute(
      'CREATE INDEX idx_novel_bookshelf_url ON novel_bookshelves(novel_url)');
  await db.execute(
      'CREATE INDEX idx_bookshelf_id ON novel_bookshelves(bookshelf_id)');
  await db.execute(
      'CREATE INDEX idx_ai_accompaniment_novel ON chapter_ai_accompaniment(novelUrl)');
  await db.execute(
      'CREATE INDEX idx_ai_accompaniment_chapter ON chapter_ai_accompaniment(chapterUrl)');

  debugPrint('✅ 测试数据库表创建完成');
}

/// 测试数据库升级逻辑
Future<void> _onUpgradeTestDatabase(
  Database db,
  int oldVersion,
  int newVersion,
) async {
  // 简化版本：只处理版本21
  if (oldVersion < 21) {
    // 添加AI伴读相关表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chapter_ai_accompaniment (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        novelUrl TEXT NOT NULL,
        chapterUrl TEXT NOT NULL,
        isAccompanied INTEGER NOT NULL DEFAULT 0,
        UNIQUE(novelUrl, chapterUrl)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_accompaniment_novel ON chapter_ai_accompaniment(novelUrl)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_accompaniment_chapter ON chapter_ai_accompaniment(chapterUrl)',
    );
  }

  debugPrint('✅ 测试数据库升级完成: $oldVersion -> $newVersion');
}

/// Fake PathProviderPlatform for testing
///
/// 提供 path_provider 的 Mock 实现，用于测试环境
/// 避免在单元测试中依赖真实的文件系统
class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String> getApplicationDocumentsPath() async {
    // 返回临时目录路径用于测试
    return '/tmp/test_app_documents';
  }
}
