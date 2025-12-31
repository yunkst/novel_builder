import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';

/// 测试数据工厂
///
/// 提供生成测试数据的辅助方法
class MockData {
  /// 创建测试用的Novel对象
  static Novel createTestNovel({
    String title = '测试小说',
    String author = '测试作者',
    String url = 'https://example.com/novel/1',
    bool isInBookshelf = false,
    String? coverUrl,
    String? description,
    String? backgroundSetting,
  }) {
    return Novel(
      title: title,
      author: author,
      url: url,
      isInBookshelf: isInBookshelf,
      coverUrl: coverUrl,
      description: description,
      backgroundSetting: backgroundSetting,
    );
  }

  /// 创建测试用的Chapter对象
  static Chapter createTestChapter({
    String title = '第一章 测试章节',
    String url = 'https://example.com/chapter/1',
    String? content,
    bool isCached = false,
    int? chapterIndex,
    bool isUserInserted = false,
  }) {
    return Chapter(
      title: title,
      url: url,
      content: content ?? '这是测试章节内容。',
      isCached: isCached,
      chapterIndex: chapterIndex ?? 0,
      isUserInserted: isUserInserted,
    );
  }

  /// 创建测试用的章节列表
  static List<Chapter> createTestChapterList({
    int count = 5,
    bool isUserInserted = false,
  }) {
    return List.generate(
      count,
      (index) => createTestChapter(
        title: '第${index + 1}章 测试章节',
        url: 'https://example.com/chapter/${index + 1}',
        chapterIndex: index,
        isUserInserted: isUserInserted,
      ),
    );
  }

  /// 创建本地小说的Novel对象
  static Novel createCustomNovel({
    String title = '本地测试小说',
    String author = '本地作者',
  }) {
    return Novel(
      title: title,
      author: author,
      url: 'custom://${DateTime.now().millisecondsSinceEpoch}',
      isInBookshelf: false,
      description: '这是一个本地创建的测试小说',
    );
  }

  /// 创建用户插入的章节
  static Chapter createUserChapter({
    String title = '用户章节',
    String content = '这是用户创建的章节内容',
    int index = 0,
  }) {
    return createTestChapter(
      title: title,
      content: content,
      chapterIndex: index,
      isUserInserted: true,
    );
  }
}
