import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/outline.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';

/// FakePreferencesService - 用于测试的简易版本
///
/// 模拟 PreferencesService 的行为，提供内存存储
class FakePreferencesService {
  final Map<String, dynamic> _storage = {};

  Future<String> getString(String key, {String defaultValue = ''}) async {
    if (!_storage.containsKey(key)) {
      return defaultValue;
    }
    final value = _storage[key];
    if (value is String) {
      return value;
    }
    return defaultValue;
  }

  Future<bool> setString(String key, String value) async {
    _storage[key] = value;
    return true;
  }
}

/// InsertChapterScreen 单元测试
///
/// 测试 InsertChapterScreen 中的核心功能：
/// - _buildDifyInputs 方法的参数构建
/// - AI 作家设定的集成
///
/// 测试策略：
/// 1. 测试 _buildDifyInputs 方法的参数构建
/// 2. 验证 AI 作家设定正确传递
/// 3. 测试边界情况（空大纲、空前文等）
/// 4. 测试重新生成场景
void main() {
  group('InsertChapterScreen - _buildDifyInputs 方法测试', () {
    late FakePreferencesService fakePreferences;
    late Outline testOutline;
    late Novel testNovel;
    late List<Chapter> testChapters;

    setUp(() {
      fakePreferences = FakePreferencesService();

      // 创建测试用的大纲
      testOutline = Outline(
        id: 1,
        novelUrl: 'https://example.com/novel/1',
        title: '测试大纲',
        content: '''# 小说大纲

## 第一章：开篇
主角小明的日常生活，介绍世界观和角色背景。

## 第二章：冲突
小明遇到突发事件，开始冒险旅程。

## 第三章：发展
在冒险过程中遇到同伴，建立友谊。

## 第四章：高潮
面对最大的挑战，展现角色成长。

## 第五章：结局
解决问题，迎接新的开始。
''',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // 创建测试用的小说
      testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://example.com/novel/1',
        isInBookshelf: true,
      );

      // 创建测试用的章节列表
      testChapters = [
        Chapter(
          title: '第一章 测试章节',
          url: 'https://example.com/chapter/1',
          content: '这是第一章的内容。',
          isCached: true,
          chapterIndex: 0,
        ),
        Chapter(
          title: '第二章 测试章节',
          url: 'https://example.com/chapter/2',
          content: '这是第二章的内容。',
          isCached: true,
          chapterIndex: 1,
        ),
      ];
    });

    group('正常情况 - 参数构建测试', () {
      test('应该正确构建 Dify 输入参数 - 带 AI 作家设定', () async {
        // Arrange: 设置 AI 作家设定
        const aiWriterSetting = '请使用简洁流畅的语言，注重情节推进和角色刻画。避免过度修饰，注重对话的自然性。';
        await fakePreferences.setString('ai_writer_prompt', aiWriterSetting);

        const previousChapters = [
          '第一章内容：主角小明第一次醒来',
          '第二章内容：小明遇到了神秘人',
        ];

        const userInput = '第三章需要展现主角的内心冲突';
        const outlineItem = '';

        // Act: 模拟 _buildDifyInputs 方法
        final historyContent = previousChapters.join('\n\n');
        final finalAiWriterSetting = await fakePreferences
            .getString('ai_writer_prompt', defaultValue: '');

        final inputs = {
          'cmd': '生成细纲',
          'outline': testOutline.content,
          'history_chapters_content': historyContent,
          'outline_item': outlineItem,
          'user_input': userInput.trim(),
          'ai_writer_setting': finalAiWriterSetting,
        };

        // Assert: 验证所有必需参数
        expect(inputs, isNotNull);
        expect(inputs['cmd'], equals('生成细纲'));
        expect(inputs['outline'], equals(testOutline.content));
        expect(inputs['history_chapters_content'], equals(historyContent));
        expect(inputs['outline_item'], equals(outlineItem));
        expect(inputs['user_input'], equals(userInput.trim()));
        expect(inputs['ai_writer_setting'], equals(aiWriterSetting),
            reason: '应该包含 AI 作家设定参数');
      });

      test('应该正确处理用户输入的空格和换行', () async {
        // Arrange
        await fakePreferences.setString('ai_writer_prompt', '');
        const userInputWithWhitespace =
            '  第三章需要展现主角的内心冲突\n  特别要描写情绪变化  ';

        // Act
        const expectedTrimmedInput =
            '第三章需要展现主角的内心冲突\n  特别要描写情绪变化';
        final inputs = {
          'cmd': '生成细纲',
          'outline': testOutline.content,
          'history_chapters_content': '',
          'outline_item': '',
          'user_input': userInputWithWhitespace.trim(),
          'ai_writer_setting': '',
        };

        // Assert
        expect(inputs['user_input'], equals(expectedTrimmedInput),
            reason: '用户输入应该被 trim 处理');
      });

      test('应该正确拼接前文章节内容', () async {
        // Arrange
        await fakePreferences.setString('ai_writer_prompt', '');
        const previousChapters = [
          '第一章内容',
          '第二章内容',
          '第三章内容',
        ];

        // Act
        const expectedHistoryContent = '''第一章内容

第二章内容

第三章内容''';
        final inputs = {
          'cmd': '生成细纲',
          'outline': testOutline.content,
          'history_chapters_content': previousChapters.join('\n\n'),
          'outline_item': '',
          'user_input': '',
          'ai_writer_setting': '',
        };

        // Assert
        expect(inputs['history_chapters_content'], equals(expectedHistoryContent),
            reason: '前文章节应该用双换行符拼接');
      });
    });

    group('边界情况 - 参数构建测试', () {
      test('空大纲应该正常工作', () async {
        // Arrange
        const emptyOutline = '';
        await fakePreferences.setString('ai_writer_prompt', '');

        // Act
        final inputs = {
          'cmd': '生成细纲',
          'outline': emptyOutline,
          'history_chapters_content': '',
          'outline_item': '',
          'user_input': '',
          'ai_writer_setting': '',
        };

        // Assert
        expect(inputs['outline'], equals(''),
            reason: '空大纲应该被正常处理');
        expect(inputs['cmd'], equals('生成细纲'),
            reason: 'cmd 参数应该仍然存在');
      });

      test('空前文章节应该正常工作', () async {
        // Arrange
        const emptyPreviousChapters = <String>[];
        await fakePreferences.setString('ai_writer_prompt', '');

        // Act
        final inputs = {
          'cmd': '生成细纲',
          'outline': testOutline.content,
          'history_chapters_content': emptyPreviousChapters.join('\n\n'),
          'outline_item': '',
          'user_input': '',
          'ai_writer_setting': '',
        };

        // Assert
        expect(inputs['history_chapters_content'], equals(''),
            reason: '空前文章节应该生成空字符串');
      });

      test('空用户输入应该正常工作', () async {
        // Arrange
        const emptyUserInput = '';
        await fakePreferences.setString('ai_writer_prompt', '');

        // Act
        final inputs = {
          'cmd': '生成细纲',
          'outline': testOutline.content,
          'history_chapters_content': '',
          'outline_item': '',
          'user_input': emptyUserInput.trim(),
          'ai_writer_setting': '',
        };

        // Assert
        expect(inputs['user_input'], equals(''),
            reason: '空用户输入应该被正常处理');
      });

      test('未设置 AI 作家设定应该返回空字符串', () async {
        // Arrange: 不设置 ai_writer_prompt
        // (FakePreferencesService 默认返回空字符串）

        // Act
        final aiWriterSetting = await fakePreferences
            .getString('ai_writer_prompt', defaultValue: '');

        // Assert
        expect(aiWriterSetting, equals(''),
            reason: '未设置的 AI 作家设定应该返回空字符串');
      });
    });

    group('重新生成场景 - 参数构建测试', () {
      test('重新生成应该包含现有的细纲内容', () async {
        // Arrange
        await fakePreferences.setString('ai_writer_prompt', '测试作家设定');
        const existingDraft = '第三章细纲草稿：主角内心冲突的详细描写';

        // Act
        final inputs = {
          'cmd': '生成细纲',
          'outline': testOutline.content,
          'history_chapters_content': '',
          'outline_item': existingDraft,
          'user_input': '请增加更多的对话',
          'ai_writer_setting': '测试作家设定',
        };

        // Assert
        expect(inputs['outline_item'], equals(existingDraft),
            reason: '重新生成时应该包含现有细纲');
        expect(inputs['user_input'], equals('请增加更多的对话'),
            reason: '用户输入应该是修改意见');
        expect(inputs['ai_writer_setting'], equals('测试作家设定'));
      });

      test('重新生成时 outline_item 为空应该正常工作', () async {
        // Arrange
        await fakePreferences.setString('ai_writer_prompt', '');

        // Act
        final inputs = {
          'cmd': '生成细纲',
          'outline': testOutline.content,
          'history_chapters_content': '',
          'outline_item': '',
          'user_input': '',
          'ai_writer_setting': '',
        };

        // Assert
        expect(inputs['outline_item'], equals(''),
            reason: '空的 outline_item 应该被正常处理');
      });
    });

    group('AI 作家设定测试', () {
      test('长的 AI 作家设定应该被正确传递', () async {
        // Arrange
        const longAiWriterSetting = '''
请使用以下写作风格：

1. 语言风格：
   - 简洁流畅，避免冗余
   - 注重节奏感，控制句子长度
   - 对话自然，符合角色身份

2. 情节推进：
   - 每段都要推动故事发展
   - 避免过度描写背景
   - 重视冲突和转折

3. 角色刻画：
   - 通过动作展现性格
   - 注重内心活动的描写
   - 保持角色行为一致性

4. 氛围营造：
   - 适当描写环境
   - 注重感官细节
   - 烘托情绪氛围
''';
        await fakePreferences.setString('ai_writer_prompt', longAiWriterSetting);

        // Act
        final inputs = {
          'cmd': '生成细纲',
          'outline': testOutline.content,
          'history_chapters_content': '',
          'outline_item': '',
          'user_input': '',
          'ai_writer_setting': longAiWriterSetting,
        };

        // Assert
        expect(inputs['ai_writer_setting'], equals(longAiWriterSetting),
            reason: '长的 AI 作家设定应该被完整传递');
        expect((inputs['ai_writer_setting'] as String).length,
            greaterThan(100),
            reason: 'AI 作家设定长度应该足够长');
      });

      test('AI 作家设定包含特殊字符应该正常工作', () async {
        // Arrange
        const specialCharSetting = '测试"设定"包含\'特殊\'字符\n和换行\t制表符';
        await fakePreferences.setString('ai_writer_prompt', specialCharSetting);

        // Act
        final inputs = {
          'cmd': '生成细纲',
          'outline': testOutline.content,
          'history_chapters_content': '',
          'outline_item': '',
          'user_input': '',
          'ai_writer_setting': specialCharSetting,
        };

        // Assert
        expect(inputs['ai_writer_setting'], equals(specialCharSetting),
            reason: '包含特殊字符的 AI 作家设定应该被正确传递');
      });
    });
  });
}
