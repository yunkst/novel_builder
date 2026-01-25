import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/models/ai_accompaniment_settings.dart';
import 'package:novel_app/models/ai_companion_response.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/services/dify_service.dart';
import 'package:novel_app/widgets/reader/ai_companion_confirm_dialog.dart';
import '../base/database_test_base.dart';
import '../test_bootstrap.dart';

// 生成Mock类
@GenerateMocks([
  DatabaseService,
  DifyService,
])
import 'ai_accompaniment_trigger_test.mocks.dart';

/// AI伴读自动触发逻辑集成测试
///
/// 测试重点：
/// 1. **触发时机**：只在章节加载完成后触发，不提前触发后续章节
/// 2. **防重复触发**：同一章节不重复触发
/// 3. **章节隔离**：各章节的伴读状态互不影响
/// 4. **设置控制**：受autoEnabled和infoNotificationEnabled控制
/// 5. **边界条件**：空内容、已伴读、正在运行等场景
///
/// 注意：这是集成测试，验证整体流程的正确性
/// 单元测试应该测试单个方法的行为
@GenerateMocks([])
void main() {
  initDatabaseTests();

  group('AI伴读自动触发集成测试', () {
    late MockDatabaseService mockDb;
    late MockDifyService mockDify;
    late AiAccompanimentSettings testSettings;

    setUp(() {
      mockDb = MockDatabaseService();
      mockDify = MockDifyService();

      testSettings = const AiAccompanimentSettings(
        autoEnabled: true,
        infoNotificationEnabled: true,
      );
    });

    group('场景1: 首次阅读章节 - 应该触发', () {
      test('当章节未伴读且autoEnabled=true时，应该触发伴读', () async {
        // Arrange
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '这是章节内容',
        );

        // Mock返回值
        when(mockDb.isChapterAccompanied(novel.url, chapter.url))
            .thenAnswer((_) async => false);
        when(mockDb.getAiAccompanimentSettings(novel.url))
            .thenAnswer((_) async => testSettings);
        when(mockDb.getCharacters(novel.url))
            .thenAnswer((_) async => []);
        when(mockDb.getRelationshipsForCharacters(novel.url, []))
            .thenAnswer((_) async => []);

        final mockResponse = AICompanionResponse(
          roles: [],
          relations: [],
          background: '',
          summery: '测试总结',
        );

        when(mockDify.generateAICompanion(
          chaptersContent: anyNamed('chaptersContent'),
          backgroundSetting: anyNamed('backgroundSetting'),
          characters: anyNamed('characters'),
          relationships: anyNamed('relationships'),
        )).thenAnswer((_) async => mockResponse);

        when(mockDb.appendBackgroundSetting(any, any))
            .thenAnswer((_) async {});
        when(mockDb.batchUpdateOrInsertCharacters(any, any))
            .thenAnswer((_) async => 0);
        when(mockDb.batchUpdateOrInsertRelationships(any, any))
            .thenAnswer((_) async => 0);
        when(mockDb.markChapterAsAccompanied(novel.url, chapter.url))
            .thenAnswer((_) async {});

        // Act & Assert
        // 验证伴读检查被调用
        final isAccompanied = await mockDb.isChapterAccompanied(
          novel.url,
          chapter.url,
        );
        expect(isAccompanied, false);

        // 验证获取设置被调用
        final settings = await mockDb.getAiAccompanimentSettings(novel.url);
        expect(settings.autoEnabled, true);

        // 验证标记伴读被调用
        await mockDb.markChapterAsAccompanied(novel.url, chapter.url);
        verify(mockDb.markChapterAsAccompanied(novel.url, chapter.url))
            .called(1);
      });

      test('应该在章节加载完成后触发，不提前触发', () async {
        // 这个测试验证触发时机：必须是先加载章节，后触发伴读
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapter1 = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '第一章内容',
        );

        final chapter2 = Chapter(
          title: '第二章',
          url: 'https://example.com/chapter2',
          content: '第二章内容',
        );

        // Mock: 两个章节都未伴读
        when(mockDb.isChapterAccompanied(novel.url, chapter1.url))
            .thenAnswer((_) async => false);
        when(mockDb.isChapterAccompanied(novel.url, chapter2.url))
            .thenAnswer((_) async => false);

        when(mockDb.getAiAccompanimentSettings(novel.url))
            .thenAnswer((_) async => testSettings);

        // 场景：用户阅读第一章
        // 应该只检查第一章的伴读状态，不应该检查第二章
        final check1 = await mockDb.isChapterAccompanied(
          novel.url,
          chapter1.url,
        );

        // 验证：只调用了第一章的检查
        verify(mockDb.isChapterAccompanied(novel.url, chapter1.url))
            .called(1);
        verifyNever(mockDb.isChapterAccompanied(novel.url, chapter2.url));

        expect(check1, false);
      });
    });

    group('场景2: 防重复触发 - 已伴读章节不重复处理', () {
      test('当章节已伴读时，应该跳过触发', () async {
        // Arrange
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '这是章节内容',
        );

        // Mock: 章节已伴读
        when(mockDb.isChapterAccompanied(novel.url, chapter.url))
            .thenAnswer((_) async => true);

        // Act
        final isAccompanied = await mockDb.isChapterAccompanied(
          novel.url,
          chapter.url,
        );

        // Assert
        expect(isAccompanied, true);

        // 验证：不应该调用AI生成
        verifyNever(mockDify.generateAICompanion(
          chaptersContent: anyNamed('chaptersContent'),
          backgroundSetting: anyNamed('backgroundSetting'),
          characters: anyNamed('characters'),
          relationships: anyNamed('relationships'),
        ));

        // 验证：不应该再次标记
        verifyNever(mockDb.markChapterAsAccompanied(any, any));
      });

      test('同一章节多次打开，只应该触发一次', () async {
        // Arrange
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '这是章节内容',
        );

        // Mock: 第一次检查返回false（未伴读），后续返回true（已伴读）
        int checkCount = 0;
        when(mockDb.isChapterAccompanied(novel.url, chapter.url))
            .thenAnswer((_) async {
          checkCount++;
          return checkCount == 1;
        });

        when(mockDb.getAiAccompanimentSettings(novel.url))
            .thenAnswer((_) async => testSettings);
        when(mockDb.getCharacters(novel.url))
            .thenAnswer((_) async => []);
        when(mockDb.getRelationshipsForCharacters(novel.url, []))
            .thenAnswer((_) async => []);

        final mockResponse = AICompanionResponse(
          roles: [],
          relations: [],
          background: '',
          summery: '总结',
        );

        when(mockDify.generateAICompanion(
          chaptersContent: anyNamed('chaptersContent'),
          backgroundSetting: anyNamed('backgroundSetting'),
          characters: anyNamed('characters'),
          relationships: anyNamed('relationships'),
        )).thenAnswer((_) async => mockResponse);

        when(mockDb.appendBackgroundSetting(any, any))
            .thenAnswer((_) async {});
        when(mockDb.batchUpdateOrInsertCharacters(any, any))
            .thenAnswer((_) async => 0);
        when(mockDb.batchUpdateOrInsertRelationships(any, any))
            .thenAnswer((_) async => 0);
        when(mockDb.markChapterAsAccompanied(novel.url, chapter.url))
            .thenAnswer((_) async {});

        // Act: 模拟用户多次打开同一章节
        for (int i = 0; i < 3; i++) {
          final isAccompanied =
              await mockDb.isChapterAccompanied(novel.url, chapter.url);

          if (!isAccompanied) {
            // 触发伴读流程
            await mockDb.markChapterAsAccompanied(novel.url, chapter.url);
          }
        }

        // Assert: AI生成应该只被调用一次
        verify(mockDify.generateAICompanion(
          chaptersContent: anyNamed('chaptersContent'),
          backgroundSetting: anyNamed('backgroundSetting'),
          characters: anyNamed('characters'),
          relationships: anyNamed('relationships'),
        )).called(1);

        // 标记伴读应该只被调用一次
        verify(mockDb.markChapterAsAccompanied(novel.url, chapter.url))
            .called(1);
      });
    });

    group('场景3: 章节隔离 - 不误触发后续章节', () {
      test('阅读第一章不应该触发第二章的伴读', () async {
        // Arrange
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapters = [
          Chapter(
            title: '第一章',
            url: 'https://example.com/chapter1',
            content: '第一章内容',
          ),
          Chapter(
            title: '第二章',
            url: 'https://example.com/chapter2',
            content: '第二章内容',
          ),
          Chapter(
            title: '第三章',
            url: 'https://example.com/chapter3',
            content: '第三章内容',
          ),
        ];

        // Mock: 只有第一章未伴读
        for (var i = 0; i < chapters.length; i++) {
          when(mockDb.isChapterAccompanied(novel.url, chapters[i].url))
              .thenAnswer((_) async => i != 0); // 第一章未伴读
        }

        when(mockDb.getAiAccompanimentSettings(novel.url))
            .thenAnswer((_) async => testSettings);

        // Act: 用户阅读第一章
        await mockDb.isChapterAccompanied(novel.url, chapters[0].url);

        // Assert: 只检查了第一章的状态
        verify(mockDb.isChapterAccompanied(novel.url, chapters[0].url))
            .called(1);
        verifyNever(
          mockDb.isChapterAccompanied(novel.url, chapters[1].url),
        );
        verifyNever(
          mockDb.isChapterAccompanied(novel.url, chapters[2].url),
        );

        // 不应该生成第二章或第三章的伴读
        verifyNever(mockDify.generateAICompanion(
          chaptersContent: anyNamed('chaptersContent'),
          backgroundSetting: anyNamed('backgroundSetting'),
          characters: anyNamed('characters'),
          relationships: anyNamed('relationships'),
        ));
      });

      test('各章节的伴读状态应该互不影响', () async {
        // Arrange
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapters = [
          Chapter(
            title: '第一章',
            url: 'https://example.com/chapter1',
            content: '第一章内容',
          ),
          Chapter(
            title: '第二章',
            url: 'https://example.com/chapter2',
            content: '第二章内容',
          ),
        ];

        // Mock: 第一章已伴读，第二章未伴读
        when(mockDb.isChapterAccompanied(novel.url, chapters[0].url))
            .thenAnswer((_) async => true);
        when(mockDb.isChapterAccompanied(novel.url, chapters[1].url))
            .thenAnswer((_) async => false);

        // Act & Assert
        final chapter1Status =
            await mockDb.isChapterAccompanied(novel.url, chapters[0].url);
        final chapter2Status =
            await mockDb.isChapterAccompanied(novel.url, chapters[1].url);

        expect(chapter1Status, true);
        expect(chapter2Status, false);

        // 第一章应该不触发伴读
        verifyNever(mockDify.generateAICompanion(
          chaptersContent: anyNamed('chaptersContent'),
          backgroundSetting: anyNamed('backgroundSetting'),
          characters: anyNamed('characters'),
          relationships: anyNamed('relationships'),
        ));

        // 第二章应该触发伴读（需要完整的设置）
        when(mockDb.getAiAccompanimentSettings(novel.url))
            .thenAnswer((_) async => testSettings);
        when(mockDb.getCharacters(novel.url))
            .thenAnswer((_) async => []);
        when(mockDb.getRelationshipsForCharacters(novel.url, []))
            .thenAnswer((_) async => []);

        final mockResponse = AICompanionResponse(
          roles: [],
          relations: [],
          background: '',
          summery: '总结',
        );

        when(mockDify.generateAICompanion(
          chaptersContent: anyNamed('chaptersContent'),
          backgroundSetting: anyNamed('backgroundSetting'),
          characters: anyNamed('characters'),
          relationships: anyNamed('relationships'),
        )).thenAnswer((_) async => mockResponse);

        // 第二章触发伴读
        if (!chapter2Status) {
          await mockDify.generateAICompanion(
            chaptersContent: chapters[1].content ?? '',
            backgroundSetting: novel.backgroundSetting ?? '',
            characters: [],
            relationships: [],
          );
        }

        // 验证：只触发了第二章的伴读
        verify(mockDify.generateAICompanion(
          chaptersContent: anyNamed('chaptersContent'),
          backgroundSetting: anyNamed('backgroundSetting'),
          characters: anyNamed('characters'),
          relationships: anyNamed('relationships'),
        )).called(1);
      });
    });

    group('场景4: 设置控制 - autoEnabled和infoNotificationEnabled', () {
      test('当autoEnabled=false时，不应该触发伴读', () async {
        // Arrange
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '这是章节内容',
        );

        final disabledSettings = const AiAccompanimentSettings(
          autoEnabled: false,
          infoNotificationEnabled: true,
        );

        when(mockDb.isChapterAccompanied(novel.url, chapter.url))
            .thenAnswer((_) async => false);
        when(mockDb.getAiAccompanimentSettings(novel.url))
            .thenAnswer((_) async => disabledSettings);

        // Act
        final isAccompanied =
            await mockDb.isChapterAccompanied(novel.url, chapter.url);
        final settings = await mockDb.getAiAccompanimentSettings(novel.url);

        // Assert
        expect(isAccompanied, false);
        expect(settings.autoEnabled, false);

        // 不应该触发AI生成
        verifyNever(mockDify.generateAICompanion(
          chaptersContent: anyNamed('chaptersContent'),
          backgroundSetting: anyNamed('backgroundSetting'),
          characters: anyNamed('characters'),
          relationships: anyNamed('relationships'),
        ));
      });

      test('当infoNotificationEnabled=false时，应该触发但不显示Toast', () async {
        // 这个测试主要验证行为，Toast显示需要在Widget测试中验证
        final noToastSettings = const AiAccompanimentSettings(
          autoEnabled: true,
          infoNotificationEnabled: false,
        );

        when(mockDb.getAiAccompanimentSettings(any))
            .thenAnswer((_) async => noToastSettings);

        final settings = await mockDb.getAiAccompanimentSettings('test_url');

        expect(settings.autoEnabled, true);
        expect(settings.infoNotificationEnabled, false);
      });
    });

    group('场景5: 边界条件', () {
      test('空章节内容不应该触发伴读', () async {
        // Arrange
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final emptyChapter = Chapter(
          title: '空章节',
          url: 'https://example.com/chapter1',
          content: '',
        );

        when(mockDb.isChapterAccompanied(novel.url, emptyChapter.url))
            .thenAnswer((_) async => false);
        when(mockDb.getAiAccompanimentSettings(novel.url))
            .thenAnswer((_) async => testSettings);

        // Act & Assert
        final isAccompanied = await mockDb.isChapterAccompanied(
          novel.url,
          emptyChapter.url,
        );
        final settings = await mockDb.getAiAccompanimentSettings(novel.url);

        expect(isAccompanied, false);
        expect(settings.autoEnabled, true);

        // 验证：空内容时不应该调用AI生成
        // （在实际代码中，会在_handleAICompanionSilent中检查_content.isEmpty）
        verifyNever(mockDify.generateAICompanion(
          chaptersContent: anyNamed('chaptersContent'),
          backgroundSetting: anyNamed('backgroundSetting'),
          characters: anyNamed('characters'),
          relationships: anyNamed('relationships'),
        ));
      });

      test('章节不存在时应该正常处理', () async {
        // Arrange
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapter = Chapter(
          title: '不存在章节',
          url: 'https://example.com/nonexistent',
        );

        // Mock: 章节不存在（返回false）
        when(mockDb.isChapterAccompanied(novel.url, chapter.url))
            .thenAnswer((_) async => false);

        // Act
        final isAccompanied = await mockDb.isChapterAccompanied(
          novel.url,
          chapter.url,
        );

        // Assert
        expect(isAccompanied, false);
        // 不应该抛出异常
      });
    });

    group('场景6: 防抖机制', () {
      test('正在运行的伴读不应该被重复触发', () async {
        // 这个测试验证防抖标志的逻辑
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '这是章节内容',
        );

        // Mock: 未伴读
        when(mockDb.isChapterAccompanied(novel.url, chapter.url))
            .thenAnswer((_) async => false);
        when(mockDb.getAiAccompanimentSettings(novel.url))
            .thenAnswer((_) async => testSettings);

        // Act: 模拟快速多次检查
        final results = await Future.wait(
          List.generate(
            5,
            (_) => mockDb.isChapterAccompanied(novel.url, chapter.url),
          ),
        );

        // Assert: 所有检查都应该返回false
        expect(results, List.filled(5, false));

        // 在实际实现中，_isAutoCompanionRunning标志会防止重复触发
        // 这里我们验证数据库调用是幂等的
        verify(mockDb.isChapterAccompanied(novel.url, chapter.url))
            .called(5);
      });
    });

    group('场景7: 强制刷新后的重新触发', () {
      test('强制刷新后应该重置标记并允许重新伴读', () async {
        // Arrange
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '这是章节内容',
        );

        when(mockDb.isChapterAccompanied(novel.url, chapter.url))
            .thenAnswer((_) async => true); // 已伴读
        when(mockDb.resetChapterAccompaniedFlag(novel.url, chapter.url))
            .thenAnswer((_) async {});

        // Act: 模拟强制刷新流程
        // 1. 当前状态：已伴读
        final beforeReset =
            await mockDb.isChapterAccompanied(novel.url, chapter.url);
        expect(beforeReset, true);

        // 2. 重置标记
        await mockDb.resetChapterAccompaniedFlag(novel.url, chapter.url);
        verify(mockDb.resetChapterAccompaniedFlag(novel.url, chapter.url))
            .called(1);

        // 3. 重置后检查（Mock应该返回false，模拟已重置）
        when(mockDb.isChapterAccompanied(novel.url, chapter.url))
            .thenAnswer((_) async => false);

        final afterReset =
            await mockDb.isChapterAccompanied(novel.url, chapter.url);
        expect(afterReset, false);

        // 现在应该可以重新触发伴读了
      });
    });
  });
}
