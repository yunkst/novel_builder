import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/novel_context_service.dart';

/// NovelContext 一致性修复测试
///
/// 验证 P0 修复：
/// - buildBaseInputs 中 key 为 'roles' 而非 'characters_info'
/// - buildFullRewriteInputs 支持 aiWriterSetting 和 roles 参数
/// - buildFullRewriteInputs 默认值为空字符串
void main() {
  group('NovelContext - P0 一致性修复', () {
    late NovelContext context;

    setUp(() {
      context = const NovelContext(
        backgroundSetting: '修仙世界',
        historyChaptersContent: '前文内容',
        currentChapterContent: '当前章节',
      );
    });

    group('buildBaseInputs - key 命名', () {
      test('角色信息 key 为 roles 而非 characters_info', () {
        final inputs = context.buildBaseInputs(
          userInput: '写一段打斗',
          cmd: '',
          charactersInfo: '李明：青云门弟子',
        );

        expect(inputs.containsKey('roles'), isTrue,
            reason: '角色信息 key 应为 roles');
        expect(inputs.containsKey('characters_info'), isFalse,
            reason: 'characters_info 是死代码，已移除');
        expect(inputs['roles'], '李明：青云门弟子');
      });

      test('不传 charactersInfo 时 roles 为空字符串', () {
        final inputs = context.buildBaseInputs(
          userInput: '写一段打斗',
          cmd: '',
        );

        expect(inputs['roles'], '');
      });

      test('aiWriterSetting 正确传入', () {
        final inputs = context.buildBaseInputs(
          userInput: '写一段打斗',
          cmd: '',
          aiWriterSetting: '文风偏古风',
        );

        expect(inputs['ai_writer_setting'], '文风偏古风');
      });

      test('不传 aiWriterSetting 时为空字符串', () {
        final inputs = context.buildBaseInputs(
          userInput: '写一段打斗',
          cmd: '',
        );

        expect(inputs['ai_writer_setting'], '');
      });
    });

    group('buildFullRewriteInputs - 扩展参数', () {
      test('仅传 userInput 时 aiWriterSetting 和 roles 为空', () {
        final inputs = context.buildFullRewriteInputs('重写这段');

        expect(inputs['user_input'], '重写这段');
        expect(inputs['cmd'], '');
        expect(inputs['ai_writer_setting'], '');
        expect(inputs['roles'], '');
      });

      test('传入 aiWriterSetting 时正确注入', () {
        final inputs = context.buildFullRewriteInputs(
          '重写这段',
          aiWriterSetting: '文风偏古风',
        );

        expect(inputs['ai_writer_setting'], '文风偏古风');
      });

      test('传入 roles 时正确注入', () {
        final inputs = context.buildFullRewriteInputs(
          '重写这段',
          roles: '李明：青云门弟子\n王浩：剑宗传人',
        );

        expect(inputs['roles'], '李明：青云门弟子\n王浩：剑宗传人');
      });

      test('同时传入 aiWriterSetting 和 roles', () {
        final inputs = context.buildFullRewriteInputs(
          '重写这段',
          aiWriterSetting: '文风偏古风',
          roles: '李明：青云门弟子',
        );

        expect(inputs['ai_writer_setting'], '文风偏古风');
        expect(inputs['roles'], '李明：青云门弟子');
        expect(inputs['background_setting'], '修仙世界');
        expect(inputs['history_chapters_content'], '前文内容');
        expect(inputs['current_chapter_content'], '当前章节');
      });
    });
  });
}
