import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/rewrite_service.dart';
import 'package:novel_app/models/character.dart';

void main() {
  group('RewriteService', () {
    late RewriteService rewriteService;

    setUp(() {
      rewriteService = RewriteService();
    });

    group('buildRewriteInputs', () {
      test('构建完整的改写输入参数', () {
        final selectedText = '这是选中的文本';
        final userInput = '请改写这段内容';
        final fullContext = '这是上下文内容';
        final characters = [
          Character(
            novelUrl: 'test',
            name: '张三',
            gender: '男',
            age: 25,
          ),
          Character(
            novelUrl: 'test',
            name: '李四',
            gender: '女',
            age: 23,
          ),
        ];

        final result = rewriteService.buildRewriteInputs(
          selectedText: selectedText,
          userInput: userInput,
          fullContext: fullContext,
          characters: characters,
        );

        expect(result['current_chapter_content'], fullContext);
        expect(result['selected_text'], selectedText);
        expect(result['user_input'], userInput);
        expect(result['cmd'], '特写');
        expect(result['roles'], isNotEmpty);
      });

      test('处理空角色列表', () {
        final selectedText = '这是选中的文本';
        final userInput = '请改写这段内容';
        final fullContext = '这是上下文内容';
        final characters = <Character>[];

        final result = rewriteService.buildRewriteInputs(
          selectedText: selectedText,
          userInput: userInput,
          fullContext: fullContext,
          characters: characters,
        );

        expect(result['current_chapter_content'], fullContext);
        expect(result['selected_text'], selectedText);
        expect(result['user_input'], userInput);
        expect(result['cmd'], '特写');
        expect(result['roles'], isNotEmpty);
      });

      test('处理特殊字符输入', () {
        final selectedText = '包含\n换行符\t和制表符的内容';
        final userInput = '特殊字符：@#\$%';
        final fullContext = '上下文\n\n内容';
        final characters = <Character>[];

        final result = rewriteService.buildRewriteInputs(
          selectedText: selectedText,
          userInput: userInput,
          fullContext: fullContext,
          characters: characters,
        );

        expect(result['selected_text'], selectedText);
        expect(result['user_input'], userInput);
        expect(result['current_chapter_content'], fullContext);
      });

      test('处理空字符串输入', () {
        final selectedText = '';
        final userInput = '';
        final fullContext = '';
        final characters = <Character>[];

        final result = rewriteService.buildRewriteInputs(
          selectedText: selectedText,
          userInput: userInput,
          fullContext: fullContext,
          characters: characters,
        );

        expect(result['selected_text'], isEmpty);
        expect(result['user_input'], isEmpty);
        expect(result['current_chapter_content'], isEmpty);
      });
    });

    group('buildRewriteInputsWithHistory', () {
      test('构建包含历史章节的完整输入参数', () {
        final selectedText = '这是选中的文本';
        final userInput = '请改写这段内容';
        final currentChapterContent = '当前章节内容';
        final historyChaptersContent = '第一章内容\n\n第二章内容';
        final backgroundSetting = '这是一个仙侠世界';
        final aiWriterSetting = '文笔优美，描写细腻';
        final rolesInfo = '张三：主角，性格勇敢\n李四：配角，性格温和';

        final result = rewriteService.buildRewriteInputsWithHistory(
          selectedText: selectedText,
          userInput: userInput,
          currentChapterContent: currentChapterContent,
          historyChaptersContent: historyChaptersContent,
          backgroundSetting: backgroundSetting,
          aiWriterSetting: aiWriterSetting,
          rolesInfo: rolesInfo,
        );

        expect(result['user_input'], userInput);
        expect(result['cmd'], '特写');
        expect(result['ai_writer_setting'], aiWriterSetting);
        expect(result['history_chapters_content'], historyChaptersContent);
        expect(result['current_chapter_content'], currentChapterContent);
        expect(result['choice_content'], selectedText);
        expect(result['background_setting'], backgroundSetting);
        expect(result['roles'], rolesInfo);
      });

      test('处理空的历史章节内容', () {
        final selectedText = '这是选中的文本';
        final userInput = '请改写这段内容';
        final currentChapterContent = '当前章节内容';
        final historyChaptersContent = '';
        final backgroundSetting = '背景设定';
        final aiWriterSetting = '作家设定';
        final rolesInfo = '角色信息';

        final result = rewriteService.buildRewriteInputsWithHistory(
          selectedText: selectedText,
          userInput: userInput,
          currentChapterContent: currentChapterContent,
          historyChaptersContent: historyChaptersContent,
          backgroundSetting: backgroundSetting,
          aiWriterSetting: aiWriterSetting,
          rolesInfo: rolesInfo,
        );

        expect(result['history_chapters_content'], isEmpty);
        expect(result['current_chapter_content'], currentChapterContent);
      });

      test('处理长文本内容', () {
        final longContent = List.generate(1000, (i) => '段落 $i').join('\n');
        final selectedText = '选中的文本';
        final userInput = '改写要求';
        final currentChapterContent = longContent;
        final historyChaptersContent = longContent;
        final backgroundSetting = '背景设定';
        final aiWriterSetting = '作家设定';
        final rolesInfo = '角色信息';

        final result = rewriteService.buildRewriteInputsWithHistory(
          selectedText: selectedText,
          userInput: userInput,
          currentChapterContent: currentChapterContent,
          historyChaptersContent: historyChaptersContent,
          backgroundSetting: backgroundSetting,
          aiWriterSetting: aiWriterSetting,
          rolesInfo: rolesInfo,
        );

        expect(result['current_chapter_content'].length, longContent.length);
        expect(result['history_chapters_content'].length, longContent.length);
      });

      test('处理包含特殊字符的角色信息', () {
        final selectedText = '选中的文本';
        final userInput = '改写要求';
        final currentChapterContent = '当前章节';
        final historyChaptersContent = '历史章节';
        final backgroundSetting = '背景设定\n包含换行符';
        final aiWriterSetting = '作家设定\t包含制表符';
        final rolesInfo = '角色：张三\n特征：勇敢、坚毅\n背景：身怀绝技';

        final result = rewriteService.buildRewriteInputsWithHistory(
          selectedText: selectedText,
          userInput: userInput,
          currentChapterContent: currentChapterContent,
          historyChaptersContent: historyChaptersContent,
          backgroundSetting: backgroundSetting,
          aiWriterSetting: aiWriterSetting,
          rolesInfo: rolesInfo,
        );

        expect(result['background_setting'], backgroundSetting);
        expect(result['ai_writer_setting'], aiWriterSetting);
        expect(result['roles'], rolesInfo);
      });

      test('验证必需字段存在', () {
        final result = rewriteService.buildRewriteInputsWithHistory(
          selectedText: 'text',
          userInput: 'input',
          currentChapterContent: 'current',
          historyChaptersContent: 'history',
          backgroundSetting: 'background',
          aiWriterSetting: 'ai',
          rolesInfo: 'roles',
        );

        // 验证所有必需字段都存在
        expect(result.containsKey('user_input'), true);
        expect(result.containsKey('cmd'), true);
        expect(result.containsKey('ai_writer_setting'), true);
        expect(result.containsKey('history_chapters_content'), true);
        expect(result.containsKey('current_chapter_content'), true);
        expect(result.containsKey('choice_content'), true);
        expect(result.containsKey('background_setting'), true);
        expect(result.containsKey('roles'), true);
      });
    });

    group('RewriteService 边界情况', () {
      test('处理null值', () {
        // Dart中不允许直接传递null到非可空参数
        // 这里测试空字符串的行为
        final result = rewriteService.buildRewriteInputsWithHistory(
          selectedText: '',
          userInput: '',
          currentChapterContent: '',
          historyChaptersContent: '',
          backgroundSetting: '',
          aiWriterSetting: '',
          rolesInfo: '',
        );

        expect(result['user_input'], '');
        expect(result['choice_content'], '');
        expect(result['current_chapter_content'], '');
        expect(result['history_chapters_content'], '');
        expect(result['background_setting'], '');
        expect(result['ai_writer_setting'], '');
        expect(result['roles'], '');
      });

      test('处理Unicode字符', () {
        final unicodeText = '中文内容 🎉 Emoji表情 😊 特殊符号';
        final characters = [
          Character(
            novelUrl: 'test',
            name: '孙悟空',
            gender: '男',
            age: 500,
          ),
        ];

        final result = rewriteService.buildRewriteInputs(
          selectedText: unicodeText,
          userInput: '改写要求',
          fullContext: '上下文',
          characters: characters,
        );

        expect(result['selected_text'], unicodeText);
        expect(result['roles'], contains('孙悟空'));
      });
    });

    group('RewriteService 参数验证', () {
      test('buildRewriteInputs返回Map类型', () {
        final result = rewriteService.buildRewriteInputs(
          selectedText: 'text',
          userInput: 'input',
          fullContext: 'context',
          characters: [],
        );

        expect(result, isA<Map<String, dynamic>>());
      });

      test('buildRewriteInputsWithHistory返回Map类型', () {
        final result = rewriteService.buildRewriteInputsWithHistory(
          selectedText: 'text',
          userInput: 'input',
          currentChapterContent: 'current',
          historyChaptersContent: 'history',
          backgroundSetting: 'background',
          aiWriterSetting: 'ai',
          rolesInfo: 'roles',
        );

        expect(result, isA<Map<String, dynamic>>());
      });

      test('验证cmd字段始终为"特写"', () {
        final result1 = rewriteService.buildRewriteInputs(
          selectedText: 'text',
          userInput: 'input',
          fullContext: 'context',
          characters: [],
        );

        final result2 = rewriteService.buildRewriteInputsWithHistory(
          selectedText: 'text',
          userInput: 'input',
          currentChapterContent: 'current',
          historyChaptersContent: 'history',
          backgroundSetting: 'background',
          aiWriterSetting: 'ai',
          rolesInfo: 'roles',
        );

        expect(result1['cmd'], '特写');
        expect(result2['cmd'], '特写');
      });
    });

    group('RewriteService 实际场景', () {
      test('单个角色改写场景', () {
        final characters = [
          Character(
            novelUrl: 'test',
            name: '李明',
            gender: '男',
            age: 30,
            occupation: '医生',
            personality: '冷静、专业',
          ),
        ];

        final result = rewriteService.buildRewriteInputs(
          selectedText: '李明走进了病房',
          userInput: '增加心理描写',
          fullContext: '医院急诊科',
          characters: characters,
        );

        expect(result['selected_text'], '李明走进了病房');
        expect(result['user_input'], '增加心理描写');
        expect(result['current_chapter_content'], '医院急诊科');
        expect(result['roles'], contains('李明'));
        expect(result['roles'], contains('医生'));
      });

      test('多角色改写场景', () {
        final characters = [
          Character(
            novelUrl: 'test',
            name: '李明',
            gender: '男',
            age: 30,
          ),
          Character(
            novelUrl: 'test',
            name: '王芳',
            gender: '女',
            age: 28,
          ),
          Character(
            novelUrl: 'test',
            name: '张伟',
            gender: '男',
            age: 35,
          ),
        ];

        final result = rewriteService.buildRewriteInputs(
          selectedText: '三人在会议室讨论',
          userInput: '增加对话和动作描写',
          fullContext: '公司会议',
          characters: characters,
        );

        expect(result['roles'], contains('李明'));
        expect(result['roles'], contains('王芳'));
        expect(result['roles'], contains('张伟'));
      });

      test('带历史章节的改写场景', () {
        final result = rewriteService.buildRewriteInputsWithHistory(
          selectedText: '主角战斗场景',
          userInput: '增加招式描写',
          currentChapterContent: '第十章内容',
          historyChaptersContent: '第一章\n第二章\n第三章\n第四章\n第五章',
          backgroundSetting: '修仙世界',
          aiWriterSetting: '文笔华丽，善于描写战斗场面',
          rolesInfo: '主角：叶凡，金丹期修士',
        );

        expect(result['choice_content'], '主角战斗场景');
        expect(result['user_input'], '增加招式描写');
        expect(result['history_chapters_content'], contains('第一章'));
        expect(result['background_setting'], '修仙世界');
        expect(result['ai_writer_setting'], contains('战斗'));
        expect(result['roles'], contains('叶凡'));
      });
    });
  });
}
