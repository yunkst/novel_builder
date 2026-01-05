import 'package:mockito/mockito.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/character.dart';

/// Mock工厂
///
/// 统一创建和配置Mock对象
/// 提供预配置的Mock实例，减少测试代码重复
class MockFactory {
  /// 创建Mock数据库服务
  ///
  /// [bookshelf] 返回的书架列表
  /// [cachedChapters] 缓存的章节数据
  static MockDatabaseService createMockDatabase({
    List<Novel>? bookshelf,
    Map<String, String>? cachedChapters,
  }) {
    final mockDb = MockDatabaseService();

    // 配置getBookshelf行为
    when(mockDb.getBookshelf()).thenAnswer((_) async => bookshelf ?? []);

    // 配置isInBookshelf行为
    when(mockDb.isInBookshelf(any)).thenAnswer((_) async {
      final url = _getFirstArgumentPositional(args) as String;
      return bookshelf?.any((novel) => novel.url == url) ?? false;
    });

    // 配置getCachedChapter行为
    when(mockDb.getCachedChapter(any)).thenAnswer((_) async {
      final url = _getFirstArgumentPositional(args) as String;
      return cachedChapters?[url];
    });

    // 配置addToBookshelf行为
    when(mockDb.addToBookshelf(any)).thenAnswer((_) async {
      return true;
    });

    // 配置removeFromBookshelf行为
    when(mockDb.removeFromBookshelf(any)).thenAnswer((_) async {
      return true;
    });

    return mockDb;
  }

  /// 创建测试小说数据
  static Novel createTestNovel({
    String url = 'https://test.com/novel/1',
    String title = '测试小说',
    String author = '测试作者',
    String? coverUrl,
    String? description,
  }) {
    return Novel(
      url: url,
      title: title,
      author: author,
      coverUrl: coverUrl,
      description: description,
      backgroundSetting: null,
      isInBookshelf: false,
      lastReadChapterUrl: null,
      lastReadPosition: 0,
      addedTime: DateTime.now().millisecondsSinceEpoch,
      lastReadTime: null,
      updateTime: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 创建测试章节数据
  static Chapter createTestChapter({
    String url = 'https://test.com/chapter/1',
    String title = '第一章',
    int chapterIndex = 0,
    bool isUserInserted = false,
    bool isCached = false,
  }) {
    return Chapter(
      title: title,
      url: url,
      content: isCached ? '测试章节内容' : null,
      isCached: isCached,
      chapterIndex: chapterIndex,
      isUserInserted: isUserInserted,
    );
  }

  /// 创建测试角色数据
  static Character createTestCharacter({
    int id = 1,
    String name = '测试角色',
    String novelUrl = 'https://test.com/novel/1',
    int? age,
    String? gender,
  }) {
    return Character(
      id: id,
      novelUrl: novelUrl,
      name: name,
      age: age,
      gender: gender,
      occupation: null,
      personality: null,
      bodyType: null,
      clothingStyle: null,
      appearanceFeatures: null,
      backgroundStory: null,
      facePrompts: null,
      bodyPrompts: null,
      cachedImageUrl: null,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 创建测试小说列表
  static List<Novel> createTestNovelList({int count = 3}) {
    return List.generate(
      count,
      (i) => createTestNovel(
        url: 'https://test.com/novel/$i',
        title: '测试小说$i',
        author: '测试作者$i',
      ),
    );
  }

  /// 创建测试章节列表
  static List<Chapter> createTestChapterList({
    int count = 10,
    String novelUrl = 'https://test.com/novel/1',
  }) {
    return List.generate(
      count,
      (i) => createTestChapter(
        url: '$novelUrl/chapter/$i',
        title: '第${i + 1}章',
        chapterIndex: i,
      ),
    );
  }

  /// 获取方法调用的第一个位置参数
  ///
  /// 内部辅助方法，用于在Mock的thenAnswer中获取参数
  static dynamic _getFirstArgumentPositional(List<dynamic> args) {
    if (args.isEmpty) {
      throw ArgumentError('Mock方法被调用时没有提供参数');
    }
    return args.first;
  }
}

/// Mock数据库服务类
class MockDatabaseService extends Mock implements DatabaseService {}
