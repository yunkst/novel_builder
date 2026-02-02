import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/repositories/novel_repository.dart';
import 'package:novel_app/models/novel.dart';
import '../../test_bootstrap.dart';

/// NovelRepository 向后兼容性测试
///
/// 验证现有代码（直接创建实例）仍然正常工作
/// 不依赖 Riverpod Provider
void main() {
  // 初始化测试环境
  initDatabaseTests();

  group('NovelRepository 向后兼容性测试', () {
    late NovelRepository repository;

    setUp(() async {
      // 模拟现有代码：直接创建实例，不使用 Provider
      repository = NovelRepository();
    });

    test('应该能够直接创建 NovelRepository 实例', () {
      // 这是现有代码的使用方式
      final directRepository = NovelRepository();

      expect(directRepository, isA<NovelRepository>());
      expect(repository, isA<NovelRepository>());
    });

    test('应该支持继承自 BaseRepository 的方法', () {
      // 验证 BaseRepository 的方法可用
      expect(repository.isWebPlatform, isA<bool>());

      // dispose 方法应该存在
      expect(() async => await repository.dispose(), returnsNormally);
    });

    test('现有代码的初始化方式应该仍然有效', () {
      // 模拟 DatabaseService 中的初始化
      final novelRepo = NovelRepository();
      final chapterRepo = NovelRepository();

      // 每个实例应该是独立的
      expect(identical(novelRepo, chapterRepo), false);
    });

    test('应该能够使用 setSharedDatabase 注入数据库', () async {
      final testDb = await createInMemoryDatabase();
      final repo = NovelRepository();

      // 这是 DatabaseService 使用的注入方式
      repo.setSharedDatabase(testDb);

      // 验证可以正常工作
      final novel = Novel(
        title: '兼容性测试',
        author: '测试作者',
        url: 'https://test.com/compatibility',
      );

      try {
        await repo.addToBookshelf(novel);
        // 如果成功添加，测试通过
        expect(true, true);
      } finally {
        await testDb.close();
      }
    });

    test('Riverpod Provider 使用方式应该同样有效', () {
      // 虽然 Provider 测试在单独的文件中
      // 但这里验证 Repository 本身的接口未改变

      final repo = NovelRepository();

      // 所有公共方法应该存在
      expect(repo.addToBookshelf, isA<Function>());
      expect(repo.removeFromBookshelf, isA<Function>());
      expect(repo.getNovels, isA<Function>());
      expect(repo.isInBookshelf, isA<Function>());
      expect(repo.updateLastReadChapter, isA<Function>());
      expect(repo.updateBackgroundSetting, isA<Function>());
      expect(repo.getBackgroundSetting, isA<Function>());
      expect(repo.getLastReadChapter, isA<Function>());
      expect(repo.getAiAccompanimentSettings, isA<Function>());
      expect(repo.updateAiAccompanimentSettings, isA<Function>());
    });
  });
}
