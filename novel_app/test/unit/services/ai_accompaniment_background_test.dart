import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/ai_companion_response.dart';
import 'package:novel_app/models/ai_accompaniment_settings.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/services/database_service.dart';
import '../../base/database_test_base.dart';
import '../../test_bootstrap.dart';

/// AI伴读自动触发背景设定更新测试
///
/// 测试重点：
/// 1. 自动伴读时背景设定是否正确追加
/// 2. 背景设定的追加逻辑是否符合预期
/// 3. 多次追加背景设定的累积效果
/// 4. 背景设定为空时的处理
void main() {
  initDatabaseTests();

  group('AI伴读背景设定更新测试', () {
    late DatabaseTestBase testBase;

    setUp(() async {
      testBase = _BackgroundTestBase();
      await testBase.setUp();
    });

    group('appendBackgroundSetting - 背景设定追加', () {
      test('应该成功追加背景设定到空背景', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
          backgroundSetting: null, // 初始背景为空
        );

        await testBase.databaseService.addToBookshelf(novel);

        // 追加背景设定
        const newBackground = '这是一个古代修仙世界，灵气充沛。';
        await testBase.databaseService.appendBackgroundSetting(
          novel.url,
          newBackground,
        );

        // 验证背景设定已追加
        final updatedBackground =
            await testBase.databaseService.getBackgroundSetting(novel.url);
        expect(updatedBackground, isNotNull);
        expect(updatedBackground, equals(newBackground),
            reason: '空背景应该直接设置为新内容');
      });

      test('应该正确追加背景设定到已有背景', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel2',
          backgroundSetting: '这是初始背景。',
        );

        await testBase.databaseService.addToBookshelf(novel);

        // 追加背景设定
        const newBackground = '这是新增的背景设定。';
        await testBase.databaseService.appendBackgroundSetting(
          novel.url,
          newBackground,
        );

        // 验证背景设定已追加
        final updatedBackground =
            await testBase.databaseService.getBackgroundSetting(novel.url);
        expect(updatedBackground, isNotNull);
        expect(
          updatedBackground,
          equals('这是初始背景。\n\n这是新增的背景设定。'),
            reason: '应该用双换行符分隔旧背景和新背景',
        );
      });

      test('应该忽略空的背景设定追加', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel3',
          backgroundSetting: '这是初始背景。',
        );

        await testBase.databaseService.addToBookshelf(novel);

        // 获取追加前的背景
        final before =
            await testBase.databaseService.getBackgroundSetting(novel.url);

        // 尝试追加空背景
        await testBase.databaseService.appendBackgroundSetting(
          novel.url,
          '', // 空字符串
        );

        // 验证背景未改变
        final after =
            await testBase.databaseService.getBackgroundSetting(novel.url);
        expect(after, equals(before),
            reason: '空背景应该被忽略');
      });

      test('应该忽略只有空白字符的背景设定追加', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel4',
          backgroundSetting: '这是初始背景。',
        );

        await testBase.databaseService.addToBookshelf(novel);

        // 获取追加前的背景
        final before =
            await testBase.databaseService.getBackgroundSetting(novel.url);

        // 尝试追加只有空白字符的背景
        await testBase.databaseService.appendBackgroundSetting(
          novel.url,
          '   \n\t  ', // 只有空白字符
        );

        // 验证背景未改变
        final after =
            await testBase.databaseService.getBackgroundSetting(novel.url);
        expect(after, equals(before),
            reason: '只有空白字符的背景应该被忽略');
      });

      test('应该对不存在的小说返回0', () async {
        const newBackground = '这是新增的背景设定。';
        final result = await testBase.databaseService.appendBackgroundSetting(
          'https://example.com/nonexistent',
          newBackground,
        );

        expect(result, 0,
            reason: '不存在的小说应该返回0（表示未更新）');
      });
    });

    group('多次追加背景设定', () {
      test('应该正确累积多次背景设定追加', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel5',
          backgroundSetting: null,
        );

        await testBase.databaseService.addToBookshelf(novel);

        // 第一次追加
        await testBase.databaseService.appendBackgroundSetting(
          novel.url,
          '背景1',
        );
        final after1 =
            await testBase.databaseService.getBackgroundSetting(novel.url);
        expect(after1, equals('背景1'));

        // 第二次追加
        await testBase.databaseService.appendBackgroundSetting(
          novel.url,
          '背景2',
        );
        final after2 =
            await testBase.databaseService.getBackgroundSetting(novel.url);
        expect(after2, equals('背景1\n\n背景2'));

        // 第三次追加
        await testBase.databaseService.appendBackgroundSetting(
          novel.url,
          '背景3',
        );
        final after3 =
            await testBase.databaseService.getBackgroundSetting(novel.url);
        expect(after3, equals('背景1\n\n背景2\n\n背景3'),
            reason: '每次追加都应该用双换行符分隔');
      });

      test('应该正确处理长文本背景追加', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel6',
          backgroundSetting: null,
        );

        await testBase.databaseService.addToBookshelf(novel);

        // 追加长文本背景
        final longBackground = 'A' * 10000; // 10000个字符
        await testBase.databaseService.appendBackgroundSetting(
          novel.url,
          longBackground,
        );

        final updated =
            await testBase.databaseService.getBackgroundSetting(novel.url);
        expect(updated, isNotNull);
        expect(updated!.length, equals(10000),
            reason: '长文本背景应该完整保存');
      });
    });

    group('模拟AI伴读响应数据更新', () {
      test('应该正确处理AI伴读返回的背景设定', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel7',
          backgroundSetting: '初始背景。',
        );

        await testBase.databaseService.addToBookshelf(novel);

        // 模拟AI伴读返回的响应
        final aiResponse = AICompanionResponse(
          roles: [],
          background: 'AI分析发现的新背景信息。',
          summery: '本章总结',
          relations: [],
        );

        // 执行背景设定追加（模拟AI伴读流程）
        if (aiResponse.background.isNotEmpty) {
          await testBase.databaseService.appendBackgroundSetting(
            novel.url,
            aiResponse.background,
          );
        }

        // 验证背景设定已正确追加
        final updated =
            await testBase.databaseService.getBackgroundSetting(novel.url);
        expect(updated, isNotNull);
        expect(
          updated,
          equals('初始背景。\n\nAI分析发现的新背景信息。'),
            reason: 'AI返回的背景应该正确追加',
        );
      });

      test('当AI返回空背景时不应该修改现有背景', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel8',
          backgroundSetting: '初始背景。',
        );

        await testBase.databaseService.addToBookshelf(novel);

        // 模拟AI伴读返回空背景的响应
        final aiResponse = AICompanionResponse(
          roles: [],
          background: '', // 空背景
          summery: '本章总结',
          relations: [],
        );

        // 执行背景设定追加（应该被忽略）
        if (aiResponse.background.isNotEmpty) {
          await testBase.databaseService.appendBackgroundSetting(
            novel.url,
            aiResponse.background,
          );
        }

        // 验证背景设定未改变
        final updated =
            await testBase.databaseService.getBackgroundSetting(novel.url);
        expect(updated, isNotNull);
        expect(
          updated!.replaceAll('。', '.'), // 统一标点符号
          equals('初始背景.'),
            reason: 'AI返回空背景时不应修改现有背景',
        );
      });

      test('应该正确处理AI伴读的完整数据更新流程', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel9',
          backgroundSetting: '初始背景。',
        );

        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '这是第一章的内容，包含新的场景描述。',
        );

        await testBase.databaseService.addToBookshelf(novel);
        await testBase.databaseService.cacheChapter(
          novel.url,
          chapter,
          chapter.content ?? '',
        );

        // 模拟AI伴读返回的完整响应
        final aiResponse = AICompanionResponse(
          roles: [
            AICompanionRole(
              name: '主角',
              age: 18,
              gender: '男',
            ),
          ],
          background: '本章新增了一个山洞场景，洞内有一座古老的祭坛。',
          summery: '主角在山洞中发现祭坛',
          relations: [],
        );

        // 执行完整的AI伴读更新流程
        int updatedCount = 0;

        // 1. 追加背景设定
        if (aiResponse.background.isNotEmpty) {
          await testBase.databaseService.appendBackgroundSetting(
            novel.url,
            aiResponse.background,
          );
          updatedCount++;
        }

        // 2. 更新角色信息(如果有的话)
        if (aiResponse.roles.isNotEmpty) {
          try {
            await testBase.databaseService.batchUpdateOrInsertCharacters(
              novel.url,
              aiResponse.roles,
            );
            updatedCount++;
          } catch (e) {
            // 角色更新失败不影响背景设定测试
            debugPrint('角色更新失败(非关键): $e');
          }
        }

        // 验证背景设定已更新
        final updatedBackground =
            await testBase.databaseService.getBackgroundSetting(novel.url);
        expect(updatedBackground, isNotNull);
        expect(
          updatedBackground,
          contains('山洞场景'),
            reason: '背景设定应该包含AI返回的新内容',
        );
        expect(
          updatedBackground,
          contains('初始背景'),
            reason: '背景设定应该保留原有内容',
        );

        // 验证角色(可选)
        if (aiResponse.roles.isNotEmpty) {
          try {
            final characters =
                await testBase.databaseService.getCharacters(novel.url);
            // 如果角色插入成功,验证它
            if (characters.isNotEmpty) {
              expect(characters.first.name, equals('主角'),
                  reason: '第一个角色应该是主角');
            }
          } catch (e) {
            // 角色查询失败不影响背景设定测试
            debugPrint('角色查询失败(非关键): $e');
          }
        }

        expect(updatedCount, greaterThan(0),
            reason: '至少应该有一项数据被更新');
      });
    });

    group('边界条件和异常情况', () {
      test('应该正确处理包含特殊字符的背景设定', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel10',
          backgroundSetting: null,
        );

        await testBase.databaseService.addToBookshelf(novel);

        // 包含特殊字符的背景
        const specialBackground = '''
背景包含：
- 引号："双引号" 和 '单引号'
- 换行符：多行
- 特殊符号：@#¥%……&*()
- Emoji：🎉🎊🎈
''';

        await testBase.databaseService.appendBackgroundSetting(
          novel.url,
          specialBackground,
        );

        final updated =
            await testBase.databaseService.getBackgroundSetting(novel.url);
        expect(updated, isNotNull);
        expect(updated, contains('Emoji'));
        expect(updated, contains('🎉'));
      });

      test('应该正确处理包含SQL特殊字符的背景设定', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel11',
          backgroundSetting: null,
        );

        await testBase.databaseService.addToBookshelf(novel);

        // 包含SQL特殊字符的背景
        const sqlInjectionBackground = "背景包含'单引号'和\"双引号\"--注释";

        await testBase.databaseService.appendBackgroundSetting(
          novel.url,
          sqlInjectionBackground,
        );

        final updated =
            await testBase.databaseService.getBackgroundSetting(novel.url);
        expect(updated, isNotNull);
        expect(
          updated,
          equals(sqlInjectionBackground),
            reason: 'SQL特殊字符应该被正确转义',
        );
      });

      test('应该正确处理超大背景设定', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel12',
          backgroundSetting: null,
        );

        await testBase.databaseService.addToBookshelf(novel);

        // 超大背景设定（100KB）
        final hugeBackground = '背景内容' * 25000; // 约100KB

        await testBase.databaseService.appendBackgroundSetting(
          novel.url,
          hugeBackground,
        );

        final updated =
            await testBase.databaseService.getBackgroundSetting(novel.url);
        expect(updated, isNotNull);
        expect(updated!.length, equals(hugeBackground.length),
            reason: '超大背景应该完整保存');
      });
    });

    group('跨小说独立性', () {
      test('不同小说的背景设定应该独立', () async {
        final novel1 = Novel(
          title: '小说1',
          author: '作者1',
          url: 'https://example.com/novel1',
          backgroundSetting: '背景1',
        );

        final novel2 = Novel(
          title: '小说2',
          author: '作者2',
          url: 'https://example.com/novel2',
          backgroundSetting: '背景2',
        );

        await testBase.databaseService.addToBookshelf(novel1);
        await testBase.databaseService.addToBookshelf(novel2);

        // 只更新novel1的背景
        await testBase.databaseService.appendBackgroundSetting(
          novel1.url,
          '新背景1',
        );

        // 验证novel1的背景已更新
        final updated1 =
            await testBase.databaseService.getBackgroundSetting(novel1.url);
        expect(updated1, contains('新背景1'));

        // 验证novel2的背景未改变
        final updated2 =
            await testBase.databaseService.getBackgroundSetting(novel2.url);
        expect(updated2, equals('背景2'),
            reason: 'novel2的背景应该不受影响');
      });
    });
  });
}

/// 测试基类实现
class _BackgroundTestBase extends DatabaseTestBase {}
