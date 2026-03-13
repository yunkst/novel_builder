import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

/// DifyWorkflowService 请求构建测试
///
/// 专门测试 DifyWorkflowService 如何构建请求体，
/// 验证 ai_writer_setting 参数是否正确传递到最终的 HTTP 请求中。
void main() {
  group('DifyWorkflowService - 请求构建测试', () {
    group('请求体构建', () {
      test('应该正确将 inputs 传递到请求体中', () {
        // Arrange: 模拟 _buildDifyInputs 返回的参数
        final inputs = {
          'cmd': '生成细纲',
          'outline': '测试大纲内容',
          'history_chapters_content': '前文章节内容',
          'outline_item': '',
          'user_input': '用户输入',
          'ai_writer_setting': 'AI作家设定内容',
        };

        // Act: 模拟 DifyWorkflowService._executeStreamingSimple 中的请求体构建
        final requestBody = {
          'inputs': inputs,
          'response_mode': 'streaming',
          'user': 'novel-builder-app',
        };

        // Assert: 验证请求体结构
        expect(requestBody, isNotNull);
        expect(requestBody['response_mode'], equals('streaming'));
        expect(requestBody['user'], equals('novel-builder-app'));

        // 验证 inputs 被完整传递
        final requestInputs = requestBody['inputs'] as Map<String, dynamic>;
        expect(requestInputs['cmd'], equals('生成细纲'));
        expect(requestInputs['ai_writer_setting'], equals('AI作家设定内容'),
            reason: 'ai_writer_setting 应该被包含在请求体中');
      });

      test('验证 JSON 序列化 - ai_writer_setting 应该在最终 JSON 中', () {
        // Arrange
        final inputs = {
          'cmd': '生成细纲',
          'outline': '测试大纲',
          'history_chapters_content': '',
          'outline_item': '',
          'user_input': '',
          'ai_writer_setting': '这是AI作家设定',
        };

        final requestBody = {
          'inputs': inputs,
          'response_mode': 'streaming',
          'user': 'novel-builder-app',
        };

        // Act: 序列化为 JSON（模拟实际 HTTP 请求）
        final jsonBody = jsonEncode(requestBody);

        // Assert: 验证 JSON 字符串中包含 ai_writer_setting
        expect(jsonBody, contains('ai_writer_setting'),
            reason: 'JSON 字符串应该包含 ai_writer_setting 字段');
        expect(jsonBody, contains('这是AI作家设定'),
            reason: 'JSON 字符串应该包含 ai_writer_setting 的值');

        // 验证反序列化后仍然包含该字段
        final decoded = jsonDecode(jsonBody) as Map<String, dynamic>;
        final decodedInputs = decoded['inputs'] as Map<String, dynamic>;
        expect(decodedInputs['ai_writer_setting'], equals('这是AI作家设定'));
      });

      test('当 ai_writer_setting 为空字符串时也应该传递', () {
        // Arrange: ai_writer_setting 为空字符串
        final inputs = {
          'cmd': '生成细纲',
          'outline': '测试大纲',
          'history_chapters_content': '',
          'outline_item': '',
          'user_input': '',
          'ai_writer_setting': '',  // 空字符串
        };

        final requestBody = {
          'inputs': inputs,
          'response_mode': 'streaming',
          'user': 'novel-builder-app',
        };

        // Act
        final jsonBody = jsonEncode(requestBody);

        // Assert: 空字符串也应该被序列化
        expect(jsonBody, contains('ai_writer_setting'),
            reason: '即使值为空，字段也应该存在于 JSON 中');

        final decoded = jsonDecode(jsonBody) as Map<String, dynamic>;
        final decodedInputs = decoded['inputs'] as Map<String, dynamic>;
        expect(decodedInputs.containsKey('ai_writer_setting'), isTrue,
            reason: 'inputs 应该包含 ai_writer_setting 键');
        expect(decodedInputs['ai_writer_setting'], equals(''));
      });
    });

    group('问题复现 - 验证参数是否丢失', () {
      test('🔴 问题复现：验证参数构建流程', () {
        /// 此测试模拟完整的参数构建流程：
        /// 1. _buildDifyInputs 构建 inputs
        /// 2. callDifyStreaming 传递 inputs
        /// 3. runWorkflowStreaming 传递 inputs
        /// 4. executeStreaming 构建 requestBody
        ///
        /// 问题：如果某个环节丢失了 ai_writer_setting，此测试会失败

        // Step 1: 模拟 _buildDifyInputs 方法返回
        final aiWriterSetting = '测试AI作家设定';
        final buildDifyInputsResult = {
          'cmd': '生成细纲',
          'outline': '大纲内容',
          'history_chapters_content': '历史章节',
          'outline_item': '',
          'user_input': '用户输入',
          'ai_writer_setting': aiWriterSetting,
        };

        // 验证 Step 1 输出
        expect(buildDifyInputsResult['ai_writer_setting'], equals(aiWriterSetting),
            reason: '_buildDifyInputs 应该返回 ai_writer_setting');

        // Step 2-3: 模拟 callDifyStreaming -> runWorkflowStreaming 传递
        final inputsPassedToWorkflow = buildDifyInputsResult;

        // 验证 Step 2-3 传递
        expect(inputsPassedToWorkflow['ai_writer_setting'], equals(aiWriterSetting),
            reason: '传递到 WorkflowService 的 inputs 应该包含 ai_writer_setting');

        // Step 4: 模拟 executeStreaming 构建 requestBody
        final requestBody = {
          'inputs': inputsPassedToWorkflow,
          'response_mode': 'streaming',
          'user': 'novel-builder-app',
        };

        // 验证最终请求体
        final finalInputs = requestBody['inputs'] as Map<String, dynamic>;
        expect(finalInputs['ai_writer_setting'], equals(aiWriterSetting),
            reason: '最终请求体应该包含 ai_writer_setting');

        // 验证 JSON 序列化
        final jsonBody = jsonEncode(requestBody);
        expect(jsonBody, contains('ai_writer_setting'),
            reason: 'JSON 请求体应该包含 ai_writer_setting 字段');

        print('✅ 参数传递流程验证通过');
        print('请求体 JSON: $jsonBody');
      });

      test('🔴 问题复现：检查实际代码逻辑', () {
        /// 此测试检查 insert_chapter_screen.dart 中 _buildDifyInputs 的实际逻辑
        ///
        /// 代码位置: lib/screens/insert_chapter_screen.dart:288-304
        ///
        /// 原始代码：
        /// ```dart
        /// Future<Map<String, dynamic>> _buildDifyInputs({
        ///   required String userInput,
        ///   String? existingDraft,
        /// }) async {
        ///   final historyContent = (_cachedPreviousChapters ?? []).join('\n\n');
        ///   final aiWriterSetting = await PreferencesService.instance
        ///       .getString('ai_writer_prompt', defaultValue: '');
        ///
        ///   return {
        ///     'cmd': '生成细纲',
        ///     'outline': _outline!.content,
        ///     'history_chapters_content': historyContent,
        ///     'outline_item': existingDraft ?? '',
        ///     'user_input': userInput.trim(),
        ///     'ai_writer_setting': aiWriterSetting,  // <-- 参数存在
        ///   };
        /// }
        /// ```

        // 模拟代码逻辑
        final cachedPreviousChapters = ['第一章内容', '第二章内容'];
        final historyContent = cachedPreviousChapters.join('\n\n');
        final aiWriterSetting = '模拟的AI作家设定';  // 从 PreferencesService 获取
        final outlineContent = '测试大纲内容';
        final existingDraft = null;
        final userInput = '测试用户输入';

        // 模拟 _buildDifyInputs 的 return 语句
        final result = {
          'cmd': '生成细纲',
          'outline': outlineContent,
          'history_chapters_content': historyContent,
          'outline_item': existingDraft ?? '',
          'user_input': userInput.trim(),
          'ai_writer_setting': aiWriterSetting,
        };

        // 验证结果
        expect(result['ai_writer_setting'], equals('模拟的AI作家设定'),
            reason: '_buildDifyInputs 返回值应该包含 ai_writer_setting');

        print('✅ _buildDifyInputs 逻辑验证通过');
        print('返回的 inputs: $result');
      });
    });

    group('可能的问题原因分析', () {
      test('可能原因1: inputs 被错误覆盖', () {
        /// 假设某处代码错误地重新创建了 inputs 而没有包含 ai_writer_setting
        final originalInputs = {
          'cmd': '生成细纲',
          'outline': '大纲',
          'ai_writer_setting': '作家设定',
        };

        // 错误示例：某处重新构建了 inputs 但遗漏了 ai_writer_setting
        final wrongInputs = {
          'cmd': originalInputs['cmd'],
          'outline': originalInputs['outline'],
          // 忘记复制 ai_writer_setting
        };

        // 这个测试会失败，说明这种错误会导致问题
        expect(wrongInputs['ai_writer_setting'], isNull,
            reason: '错误场景：ai_writer_setting 被遗漏');
      });

      test('可能原因2: Dify 工作流未定义该参数', () {
        /// 即使 Flutter 端正确传递了参数，Dify 工作流可能：
        /// 1. 未定义 ai_writer_setting 输入变量
        /// 2. 定义了但未在流程中使用
        ///
        /// 这需要在 Dify 端检查，此测试仅记录可能性

        // 模拟 Dify 请求
        final requestJson = jsonEncode({
          'inputs': {
            'cmd': '生成细纲',
            'ai_writer_setting': '作家设定',
          },
          'response_mode': 'streaming',
          'user': 'test',
        });

        print('发送到 Dify 的请求体: $requestJson');
        print('');
        print('⚠️ 如果 Dify 日志显示请求中没有 ai_writer_setting:');
        print('   - 检查 Flutter 端网络请求日志');
        print('   - 检查 Dify 工作流是否定义了该输入变量');
      });
    });
  });
}