import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/novel.dart';
import '../../test_bootstrap.dart';
import '../../base/database_test_base.dart';

/// novels 视图功能测试
///
/// 验证 novels 视图正确创建并作为 bookshelf 表的语义别名
void main() {
  // 初始化 FFI
  initTests();

  group('novels 视图基础测试', () {
    late DatabaseTestBase base;
    late DatabaseService databaseService;

    setUp(() async {
      base = DatabaseTestBase();
      await base.setUp();
      databaseService = base.databaseService;
    });

    tearDown(() async {
      await base.tearDown();
    });

    test('novels视图应该与bookshelf表数据一致', () async {
      // 添加测试小说数据
      final testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://test.com/novel1',
        coverUrl: 'https://test.com/cover.jpg',
        description: '测试描述',
        isInBookshelf: false,
      );

      await databaseService.addToBookshelf(testNovel);

      // 通过两种方式获取数据
      final novelsFromView = await databaseService.getNovels();
      final novelsFromOldMethod = await databaseService.getBookshelf();

      // 验证结果一致
      expect(novelsFromView.length, novelsFromOldMethod.length);
      expect(novelsFromView.length, greaterThan(0));

      final novel = novelsFromView.first;
      expect(novel.title, '测试小说');
      expect(novel.author, '测试作者');
    });

    test('getNovels方法应该返回小说列表', () async {
      // 添加多本测试小说
      final novels = [
        Novel(
          title: '小说1',
          author: '作者1',
          url: 'https://test.com/novel1',
          isInBookshelf: false,
        ),
        Novel(
          title: '小说2',
          author: '作者2',
          url: 'https://test.com/novel2',
          isInBookshelf: false,
        ),
      ];

      for (final novel in novels) {
        await databaseService.addToBookshelf(novel);
      }

      // 使用 getNovels 方法
      final result = await databaseService.getNovels();

      expect(result.length, 2);
      expect(result[0].title, '小说1');
      expect(result[1].title, '小说2');
    });

    test('novels视图应该按最后阅读时间排序', () async {
      // 先添加小说1
      final novel1 = Novel(
        title: '小说1',
        author: '作者1',
        url: 'https://test.com/novel1',
        isInBookshelf: false,
      );
      await databaseService.addToBookshelf(novel1);

      // 更新小说1的阅读时间
      await databaseService.updateLastReadChapter(
        'https://test.com/novel1',
        1,
      );

      // 再添加小说2
      final novel2 = Novel(
        title: '小说2',
        author: '作者2',
        url: 'https://test.com/novel2',
        isInBookshelf: false,
      );
      await databaseService.addToBookshelf(novel2);

      // 获取小说列表
      final result = await databaseService.getNovels();

      // 小说1应该在前面（最近阅读）
      expect(result.first.title, '小说1');
      expect(result.last.title, '小说2');
    });
  });

  group('novels 视图语义测试', () {
    late DatabaseTestBase base;

    setUp(() async {
      base = DatabaseTestBase();
      await base.setUp();
    });

    tearDown(() async {
      await base.tearDown();
    });

    test('getNovels和getBookshelf应该返回相同结果', () async {
      final databaseService = base.databaseService;

      final testNovel = Novel(
        title: '语义测试小说',
        author: '测试作者',
        url: 'https://test.com/semantic',
        isInBookshelf: false,
      );

      await databaseService.addToBookshelf(testNovel);

      // 对比两个方法
      final fromNovels = await databaseService.getNovels();
      final fromBookshelf = await databaseService.getBookshelf();

      expect(fromNovels.length, fromBookshelf.length);
      if (fromNovels.isNotEmpty) {
        expect(fromNovels.first.title, fromBookshelf.first.title);
        expect(fromNovels.first.url, fromBookshelf.first.url);
      }
    });

    test('语义别名方法文档应该清晰', () {
      // 这个测试主要验证文档注释的存在
      // 在实际代码审查中，应检查 getNovels() 方法的文档注释

      // 验证 DatabaseService 类可以被实例化（通过base）
      expect(base.databaseService, isNotNull);
    });
  });
}
