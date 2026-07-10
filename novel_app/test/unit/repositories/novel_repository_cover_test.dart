import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqflite.dart';

import 'package:novel_app/repositories/novel_repository.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/core/database/database_connection.dart';
import '../../helpers/test_database_setup.dart' as test_db;

/// updateCoverMediaIdById 集成测试（真实内存 SQLite，跑完整迁移）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late NovelRepository repo;

  setUp(() async {
    db = await test_db.TestDatabaseSetup.createInMemoryDatabase();
    repo = NovelRepository(dbConnection: DatabaseConnection.forTesting(db));
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedNovel(String url) async {
    final id = await repo.addToBookshelf(Novel(
      title: '测试小说',
      author: '作者',
      url: url,
    ));
    return id;
  }

  test('写入 mediaId 后可读回', () async {
    final id = await seedNovel('custom://n1');
    final affected = await repo.updateCoverMediaIdById(id, 'media-1');
    expect(affected, 1);

    final novel = await repo.getNovelById(id);
    expect(novel?.coverMediaId, 'media-1');
  });

  test('传入 null 清空封面', () async {
    final id = await seedNovel('custom://n2');
    await repo.updateCoverMediaIdById(id, 'media-2');
    await repo.updateCoverMediaIdById(id, null);

    final novel = await repo.getNovelById(id);
    expect(novel?.coverMediaId, isNull);
  });

  test('不存在的 id 返回 0', () async {
    final affected = await repo.updateCoverMediaIdById(99999, 'media-x');
    expect(affected, 0);
  });
}
