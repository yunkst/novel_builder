import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/ai_companion_response.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/services/database_service.dart';
import '../../test_bootstrap.dart';

/// AI伴读数据更新逻辑单元测试
///
/// 测试重点：
/// 1. 验证不同响应组合下的真实数据库更新
/// 2. 验证空响应的处理
/// 3. 验证数据实际写入数据库
/// 4. 验证AI陪伴数据字段完整性
///
/// 迁移说明：
/// - 从Mock数据库迁移到真实数据库测试
/// - 验证数据实际存储和查询
/// - 专注于背景设定和角色更新测试（关系测试较复杂，暂不包含）
void main() {
  // 初始化数据库测试环境
  initDatabaseTests();

  group('AI伴读数据更新逻辑测试', () {
    late DatabaseService db;
    late String testNovelUrl;

    setUp(() async {
      // 创建数据库服务实例
      db = DatabaseService();
      testNovelUrl = 'https://test.com/novel/1';

      // 创建测试小说
      final novel = Novel(
        url: testNovelUrl,
        title: '测试小说',
        author: '测试作者',
        description: '测试描述',
        backgroundSetting: '测试背景',
      );
      await db.addToBookshelf(novel);
    });

    tearDown(() async {
      // 清理测试数据
      final database = await db.database;
      await database.delete('bookshelf', where: 'url = ?', whereArgs: [testNovelUrl]);
      await database.delete('characters', where: 'novelUrl = ?', whereArgs: [testNovelUrl]);
    });

    group('空响应处理', () {
      test('空响应时不写入任何数据', () async {
        // 准备空响应
        final emptyResponse = AICompanionResponse(
          background: '',
          roles: [],
          relations: [],
          summery: '',
        );

        // 执行数据更新
        await _performDataUpdate(db, testNovelUrl, emptyResponse);

        // 验证背景设定未被修改
        final bookshelf = await db.getBookshelf();
        final novel = bookshelf.firstWhere((n) => n.url == testNovelUrl);
        expect(novel.backgroundSetting, '测试背景');

        // 验证没有角色数据
        final characters = await db.getCharacters(testNovelUrl);
        expect(characters.length, 0);
      });
    });

    group('单独更新测试', () {
      test('仅背景设定更新', () async {
        final response = AICompanionResponse(
          background: '这是新增的背景设定',
          roles: [],
          relations: [],
          summery: '',
        );

        await _performDataUpdate(db, testNovelUrl, response);

        // 验证背景设定已更新（包含换行符）
        final bookshelf = await db.getBookshelf();
        final novel = bookshelf.firstWhere((n) => n.url == testNovelUrl);
        expect(novel.backgroundSetting, contains('这是新增的背景设定'));

        // 验证角色表为空
        final characters = await db.getCharacters(testNovelUrl);
        expect(characters.length, 0);
      });

      test('仅角色更新', () async {
        final response = AICompanionResponse(
          background: '',
          roles: [
            AICompanionRole(
              name: '张三',
              gender: '男',
              age: 25,
            ),
          ],
          relations: [],
          summery: '',
        );

        await _performDataUpdate(db, testNovelUrl, response);

        // 验证背景设定未被修改
        final bookshelf = await db.getBookshelf();
        final novel = bookshelf.firstWhere((n) => n.url == testNovelUrl);
        expect(novel.backgroundSetting, '测试背景');

        // 验证角色已插入
        final characters = await db.getCharacters(testNovelUrl);
        expect(characters.length, 1);
        expect(characters.first.name, '张三');
        expect(characters.first.gender, '男');
        expect(characters.first.age, 25);
      });
    });

    group('组合更新测试', () {
      test('背景设定和角色更新', () async {
        final response = AICompanionResponse(
          background: '新增背景',
          roles: [
            AICompanionRole(
              name: '张三',
              gender: '男',
              age: 25,
            ),
          ],
          relations: [],
          summery: '',
        );

        await _performDataUpdate(db, testNovelUrl, response);

        // 验证背景设定已更新（包含换行符）
        final bookshelf = await db.getBookshelf();
        final novel = bookshelf.firstWhere((n) => n.url == testNovelUrl);
        expect(novel.backgroundSetting, contains('新增背景'));

        // 验证角色已插入
        final characters = await db.getCharacters(testNovelUrl);
        expect(characters.length, 1);
        expect(characters.first.name, '张三');
      });

      test('背景设定和多角色更新', () async {
        final response = AICompanionResponse(
          background: '新增背景',
          roles: [
            AICompanionRole(
              name: '张三',
              gender: '男',
              age: 25,
            ),
            AICompanionRole(
              name: '李四',
              gender: '女',
              age: 23,
            ),
          ],
          relations: [],
          summery: '章节总结',
        );

        await _performDataUpdate(db, testNovelUrl, response);

        // 验证背景设定已更新（包含换行符）
        final bookshelf = await db.getBookshelf();
        final novel = bookshelf.firstWhere((n) => n.url == testNovelUrl);
        expect(novel.backgroundSetting, contains('新增背景'));

        // 验证两个角色都已插入
        final characters = await db.getCharacters(testNovelUrl);
        expect(characters.length, 2);

        final zhangSan = characters.firstWhere((c) => c.name == '张三');
        expect(zhangSan.gender, '男');
        expect(zhangSan.age, 25);

        final liSi = characters.firstWhere((c) => c.name == '李四');
        expect(liSi.gender, '女');
        expect(liSi.age, 23);
      });
    });

    group('数据完整性测试', () {
      test('多角色批量更新', () async {
        final response = AICompanionResponse(
          background: '',
          roles: [
            AICompanionRole(
              name: '张三',
              gender: '男',
              age: 25,
              occupation: '医生',
              personality: '温和',
            ),
            AICompanionRole(
              name: '李四',
              gender: '女',
              age: 23,
              occupation: '护士',
              personality: '活泼',
            ),
            AICompanionRole(
              name: '王五',
              gender: '男',
              age: 30,
              occupation: '警察',
              personality: '严肃',
            ),
          ],
          relations: [],
          summery: '',
        );

        await _performDataUpdate(db, testNovelUrl, response);

        // 验证所有角色都已插入
        final characters = await db.getCharacters(testNovelUrl);
        expect(characters.length, 3);

        // 验证角色字段完整性
        final zhangSan = characters.firstWhere((c) => c.name == '张三');
        expect(zhangSan.gender, '男');
        expect(zhangSan.age, 25);
        expect(zhangSan.occupation, '医生');
        expect(zhangSan.personality, '温和');

        final liSi = characters.firstWhere((c) => c.name == '李四');
        expect(liSi.gender, '女');
        expect(liSi.age, 23);
        expect(liSi.occupation, '护士');
        expect(liSi.personality, '活泼');

        final wangWu = characters.firstWhere((c) => c.name == '王五');
        expect(wangWu.gender, '男');
        expect(wangWu.age, 30);
        expect(wangWu.occupation, '警察');
        expect(wangWu.personality, '严肃');
      });

      test('角色更新包含可选字段', () async {
        final response = AICompanionResponse(
          background: '',
          roles: [
            AICompanionRole(
              name: '完整角色',
              gender: '女',
              age: 28,
              occupation: '律师',
              personality: '理智',
              bodyType: '苗条',
              clothingStyle: '正装',
              appearanceFeatures: '长发',
              backgroundStory: '出身法学世家',
            ),
          ],
          relations: [],
          summery: '',
        );

        await _performDataUpdate(db, testNovelUrl, response);

        final characters = await db.getCharacters(testNovelUrl);
        expect(characters.length, 1);

        final char = characters.first;
        expect(char.name, '完整角色');
        expect(char.gender, '女');
        expect(char.age, 28);
        expect(char.occupation, '律师');
        expect(char.personality, '理智');
        expect(char.bodyType, '苗条');
        expect(char.clothingStyle, '正装');
        expect(char.appearanceFeatures, '长发');
        expect(char.backgroundStory, '出身法学世家');
      });
    });

    group('边界条件测试', () {
      test('空字符串背景不调用更新', () async {
        final response = AICompanionResponse(
          background: '',
          roles: [],
          relations: [],
          summery: '',
        );

        await _performDataUpdate(db, testNovelUrl, response);

        // 验证背景设定未被修改
        final bookshelf = await db.getBookshelf();
        final novel = bookshelf.firstWhere((n) => n.url == testNovelUrl);
        expect(novel.backgroundSetting, '测试背景');
      });

      test('空角色列表不调用更新', () async {
        final response = AICompanionResponse(
          background: '',
          roles: [],
          relations: [],
          summery: '',
        );

        await _performDataUpdate(db, testNovelUrl, response);

        // 验证角色表为空
        final characters = await db.getCharacters(testNovelUrl);
        expect(characters.length, 0);
      });

      test('多次更新背景设定累加', () async {
        // 第一次更新
        final response1 = AICompanionResponse(
          background: '第一次追加',
          roles: [],
          relations: [],
          summery: '',
        );

        await _performDataUpdate(db, testNovelUrl, response1);

        final bookshelf1 = await db.getBookshelf();
        final novel1 = bookshelf1.firstWhere((n) => n.url == testNovelUrl);
        expect(novel1.backgroundSetting, contains('第一次追加'));

        // 第二次更新
        final response2 = AICompanionResponse(
          background: '第二次追加',
          roles: [],
          relations: [],
          summery: '',
        );

        await _performDataUpdate(db, testNovelUrl, response2);

        final bookshelf2 = await db.getBookshelf();
        final novel2 = bookshelf2.firstWhere((n) => n.url == testNovelUrl);
        expect(novel2.backgroundSetting, contains('第二次追加'));
      });

      test('角色更新支持覆盖', () async {
        // 第一次插入角色
        final response1 = AICompanionResponse(
          background: '',
          roles: [
            AICompanionRole(
              name: '张三',
              gender: '男',
              age: 25,
              occupation: '医生',
            ),
          ],
          relations: [],
          summery: '',
        );

        await _performDataUpdate(db, testNovelUrl, response1);

        final characters1 = await db.getCharacters(testNovelUrl);
        expect(characters1.first.occupation, '医生');

        // 第二次更新同一角色
        final response2 = AICompanionResponse(
          background: '',
          roles: [
            AICompanionRole(
              name: '张三',
              gender: '男',
              age: 26, // 年龄更新
              occupation: '专家', // 职业更新
            ),
          ],
          relations: [],
          summery: '',
        );

        await _performDataUpdate(db, testNovelUrl, response2);

        final characters2 = await db.getCharacters(testNovelUrl);
        expect(characters2.length, 1); // 数量不变
        expect(characters2.first.age, 26); // 年龄已更新
        expect(characters2.first.occupation, '专家'); // 职业已更新
      });
    });

    group('实际应用场景测试', () {
      test('章节AI陪伴完整流程', () async {
        // 模拟AI返回的完整章节陪伴数据
        final response = AICompanionResponse(
          background: '本章发生在一个雨夜的医院急诊室。',
          roles: [
            AICompanionRole(
              name: '张医生',
              gender: '男',
              age: 35,
              occupation: '急诊科主任',
              personality: '冷静专业',
            ),
            AICompanionRole(
              name: '小李',
              gender: '女',
              age: 24,
              occupation: '实习护士',
              personality: '认真负责',
            ),
          ],
          relations: [],
          summery: '张医生指导小李处理了一个急诊病人',
        );

        await _performDataUpdate(db, testNovelUrl, response);

        // 验证背景设定（包含换行符）
        final bookshelf = await db.getBookshelf();
        final novel = bookshelf.firstWhere((n) => n.url == testNovelUrl);
        expect(
          novel.backgroundSetting,
          contains('本章发生在一个雨夜的医院急诊室。'),
        );

        // 验证角色
        final characters = await db.getCharacters(testNovelUrl);
        expect(characters.length, 2);

        final zhang = characters.firstWhere((c) => c.name == '张医生');
        expect(zhang.occupation, '急诊科主任');
        expect(zhang.personality, '冷静专业');
        expect(zhang.age, 35);

        final li = characters.firstWhere((c) => c.name == '小李');
        expect(li.occupation, '实习护士');
        expect(li.personality, '认真负责');
        expect(li.age, 24);
      });
    });
  });
}

/// 执行AI伴读数据更新
///
/// 这个方法模拟 ReaderScreen 中 _performAICompanionUpdates 的行为
/// 用于测试数据库更新是否正确
Future<void> _performDataUpdate(
  DatabaseService db,
  String novelUrl,
  AICompanionResponse response,
) async {
  // 1. 追加背景设定
  if (response.background.isNotEmpty) {
    await db.appendBackgroundSetting(
      novelUrl,
      response.background,
    );
  }

  // 2. 批量更新或插入角色
  if (response.roles.isNotEmpty) {
    await db.batchUpdateOrInsertCharacters(
      novelUrl,
      response.roles,
    );
  }

  // 3. 批量更新或插入关系（暂时注释，关系API较复杂）
  // if (response.relations.isNotEmpty) {
  //   await db.batchUpdateOrInsertRelationships(
  //     novelUrl,
  //     response.relations,
  //   );
  // }
}
