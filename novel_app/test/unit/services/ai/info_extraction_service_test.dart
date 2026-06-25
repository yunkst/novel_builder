/// InfoExtractionService 端到端测试
///
/// 跑 InfoExtractionService 的核心方法，断言 LLM 调用的 (system, user) prompt
/// 包含预期内容 + model/temperature/maxTokens 正确。
///
/// 注意：结构化方法（immersiveScript/tagIntrospection/tagMatch）返回
/// Map<String, dynamic>，测试前需设置 mock 返回合法 JSON。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/ai/info_extraction_service.dart';
import 'package:novel_app/services/dsl_engine/llm_provider.dart';

import '../../../helpers/prompt_recording_mock.dart';

String _norm(String? s) {
  var text = (s ?? '').replaceAll('\r\n', '\n');
  text = text.split('\n').map((line) => line.trimRight()).join('\n');
  return text.trim();
}

void main() {
  late PromptRecordingMock mockClient;
  late InfoExtractionService service;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockClient = PromptRecordingMock();
    final config = LlmConfig(
      baseUrl: 'https://mock.test/v1',
      apiKey: 'test-key',
      defaultModel: 'test-model',
    );
    service = InfoExtractionService(
      provider: LlmProvider(config, httpClient: mockClient),
      defaultModel: 'deepseek-v4-pro',
    );
  });

  Future<PromptSnapshot> runAndSnapshot(Future<Object> future) async {
    // 注意：不能 clear()——future 在构造时已开始执行（async eager），
    // clear 会误删已记录的请求。setUp 每个测试重建 mockClient 已保证隔离。
    await future;
    expect(mockClient.recordedRequests, isNotEmpty,
        reason: 'InfoExtractionService 应至少发起一次 LLM 调用');
    return mockClient.lastSnapshot!;
  }

  test('generateCharacters: cmd="生成" 包含 system + user', () async {
    final snapshot = await runAndSnapshot(service.generateCharacters(
      backgroundSetting: '修仙世界，有五大宗门',
      userInput: '设计一个主角和一个反派',
    ));
    expect(snapshot.model, equals('deepseek-v4-pro'));
    expect(snapshot.maxTokens, equals(8192));
    expect(_norm(snapshot.systemPrompt), contains('热门网络小说家'));
    expect(_norm(snapshot.systemPrompt), contains('修仙世界'));
    expect(_norm(snapshot.userMessage), contains('设计一个主角和一个反派'));
  });

  test('generateCharactersFromOutline: cmd="大纲生成角色"', () async {
    final snapshot = await runAndSnapshot(service.generateCharactersFromOutline(
      outline: '第一卷：主角李明踏上修仙之路',
      userInput: '根据大纲生成角色',
    ));
    expect(_norm(snapshot.systemPrompt), contains('根据以下大纲内容'));
    expect(_norm(snapshot.userMessage), contains('根据大纲生成角色'));
  });

  test('updateCharacterCards: cmd="update_characters" 走 false 分支', () async {
    final snapshot = await runAndSnapshot(service.updateCharacterCards(
      chaptersContent: '李明在山洞中修炼...',
      roles: '李明：青云门弟子',
    ));
    // 走 false 分支：system 用 "从文章中提取" template
    expect(_norm(snapshot.systemPrompt), contains('根据以下文章内容'));
    expect(_norm(snapshot.systemPrompt), contains('李明在山洞中修炼'));
    expect(_norm(snapshot.systemPrompt), contains('李明：青云门弟子'));
    expect(_norm(snapshot.userMessage), contains('生成章节中提到的角色信息列表吧'));
  });

  test('extractCharacter: cmd="提取角色" 独立 LLM', () async {
    final snapshot = await runAndSnapshot(service.extractCharacter(
      chaptersContent: '李明告别了师父...',
      roles: '李明',
    ));
    expect(_norm(snapshot.systemPrompt), contains('把以下章节内容中的角色相关信息提取出来'));
    expect(_norm(snapshot.systemPrompt), contains('李明告别了师父'));
    // 提取角色 LLM 节点无 user message（null 表示无该 role 的 message）
    expect(snapshot.userMessage, anyOf(isNull, equals('')));
  });

  test('generateCharacterPrompts: cmd="角色卡提示词描写"', () async {
    final snapshot = await runAndSnapshot(service.generateCharacterPrompts(
      roles: '李明：20岁青年，剑眉星目',
    ));
    expect(_norm(snapshot.systemPrompt), contains('文生图提示词'));
    expect(_norm(snapshot.systemPrompt), contains('李明：20岁青年'));
    // 角色卡提示词 LLM 节点无 user message
    expect(snapshot.userMessage, anyOf(isNull, equals('')));
  });

  test('aiCompanion: cmd="AI伴读" 包含背景/角色/关系/章节', () async {
    final snapshot = await runAndSnapshot(service.aiCompanion(
      backgroundSetting: '修仙世界',
      roles: '李明：青云门弟子',
      relations: '李明-师父: 师徒',
      chaptersContent: '李明与师父告别',
    ));
    expect(_norm(snapshot.systemPrompt), contains('从最新章节内容中'));
    expect(_norm(snapshot.systemPrompt), contains('修仙世界'));
    expect(_norm(snapshot.systemPrompt), contains('李明：青云门弟子'));
    expect(_norm(snapshot.systemPrompt), contains('李明与师父告别'));
    expect(_norm(snapshot.userMessage), contains('开始整理吧'));
  });

  test('extractPromptTags: cmd="提取标签" 独立 LLM', () async {
    final snapshot = await runAndSnapshot(service.extractPromptTags(
      userInput: '提取文风标签',
      currentChapterContent: '李明独自在山洞中修炼',
      tagCategories: '古风/现代/科幻',
    ));
    expect(_norm(snapshot.systemPrompt), contains('按照用户要求，提取文章中的写作技巧'));
    expect(_norm(snapshot.systemPrompt), contains('古风/现代/科幻'));
    expect(_norm(snapshot.userMessage), contains('提取文风标签'));
    expect(_norm(snapshot.userMessage), contains('李明独自在山洞中修炼'));
  });

  test('immersiveScript: cmd="生成剧本" 新建剧本（无已有剧本）', () async {
    // immersiveScript 返回 Map，mock 需返回合法 JSON
    mockClient.setMockContent('{"play":"剧本内容","role_strategy":[{"name":"李明","strategy":"谨慎行动","clothes":"青衫"}]}');
    final snapshot = await runAndSnapshot(service.immersiveScript(
      chaptersContent: '李明在山洞中修炼，突然听到一声巨响',
      roles: '李明：青云门弟子，性格坚毅',
      userInput: '设计一个悬疑开场',
      userChoiceRole: '李明',
    ));
    // 新建分支：无 play → 走 else 分支
    expect(_norm(snapshot.systemPrompt), contains('构建一个多维度的互动剧本'));
    expect(_norm(snapshot.systemPrompt), contains('李明在山洞中修炼'));
    expect(_norm(snapshot.systemPrompt), contains('李明：青云门弟子'));
    expect(_norm(snapshot.userMessage), contains('我将扮演 ：李明'));
    expect(_norm(snapshot.userMessage), contains('设计一个悬疑开场'));
    // prompt 已不再包含冗余 JSON 格式指令（由 response_format 保障）
    expect(_norm(snapshot.userMessage), isNot(contains('严格遵循json格式')));
    // 验证 structured output（response_format）已传入
    expect(snapshot.responseFormat, isNotNull);
    expect(snapshot.responseFormat!['type'], equals('json_schema'));
  });

  test('immersiveScript: cmd="生成剧本" 重新生成（有已有剧本）', () async {
    // immersiveScript 返回 Map，mock 需返回合法 JSON
    mockClient.setMockContent('{"play":"修改后的剧本","role_strategy":[{"name":"李明","strategy":"谨慎行动","clothes":"青衫"}]}');
    final snapshot = await runAndSnapshot(service.immersiveScript(
      chaptersContent: '李明在山洞中修炼',
      roles: '李明：青云门弟子',
      userInput: '增加更多悬疑元素',
      userChoiceRole: '李明',
      existingPlay: '月光如水，山洞深处传来异响...',
      existingRoleStrategy: '[{"name":"李明","strategy":"谨慎行动","clothes":"青衫"}]',
    ));
    // 重新生成分支：有 play → 走 if 分支
    expect(_norm(snapshot.systemPrompt), contains('保留原有剧本框架的基础上'));
    expect(_norm(snapshot.systemPrompt), contains('月光如水，山洞深处传来异响'));
    expect(_norm(snapshot.systemPrompt), contains('李明'));
    expect(_norm(snapshot.systemPrompt), contains('strategy'));
    expect(_norm(snapshot.userMessage), contains('保留剧本的主体和角色策略'));
    expect(_norm(snapshot.userMessage), contains('增加更多悬疑元素'));
    // 验证 structured output
    expect(snapshot.responseFormat, isNotNull);
  });
}
