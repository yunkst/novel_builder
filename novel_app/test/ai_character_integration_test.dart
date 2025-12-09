import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/novel.dart';

void main() {
  // 初始化FFI数据库工厂
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AI角色信息传递集成测试', () {
    late DatabaseService databaseService;
    late String testNovelUrl;

    setUpAll(() async {
      databaseService = DatabaseService();
      testNovelUrl = 'https://example.com/ai-integration-test-novel';
      await databaseService.database;
    });

    setUp(() async {
      await _cleanupTestData();
    });

    tearDown(() async {
      await _cleanupTestData();
    });

    test('测试章节生成中的角色信息传递流程', () async {
      // 1. 创建具有丰富细节的角色
      final protagonist = Character(
        name: '林风',
        age: 22,
        gender: '男',
        occupation: '武学生',
        personality: '冷静沉着，武艺高强，有强烈的正义感',
        bodyType: '健壮，肌肉线条分明',
        clothingStyle: '青色武服，腰间佩戴长剑',
        appearanceFeatures: '剑眉星目，眼神锐利，黑色长发束成马尾',
        backgroundStory: '出身武林世家，家族被神秘势力灭门，踏上复仇之路',
        novelUrl: testNovelUrl,
      );

      final femaleLead = Character(
        name: '苏雨薇',
        age: 20,
        gender: '女',
        occupation: '医者',
        personality: '温柔善良，医术高超，内心坚强',
        bodyType: '苗条匀称，气质优雅',
        clothingStyle: '白色长裙，外罩淡青色纱衣',
        appearanceFeatures: '肌肤如雪，柳叶眉，杏核眼，长发如瀑',
        backgroundStory: '医仙弟子，游历江湖救死扶伤，寻找失散的师兄',
        novelUrl: testNovelUrl,
      );

      // 2. 将角色插入数据库
      final protagonistId = await databaseService.createCharacter(protagonist);
      final femaleLeadId = await databaseService.createCharacter(femaleLead);

      expect(protagonistId, greaterThan(0));
      expect(femaleLeadId, greaterThan(0));

      // 3. 模拟章节生成中的角色选择
      final selectedCharacterIds = [protagonistId, femaleLeadId];

      // 4. 模拟获取选中角色信息
      final selectedCharacters = await databaseService.getCharactersByIds(selectedCharacterIds);
      expect(selectedCharacters.length, equals(2));

      // 5. 格式化角色信息为AI可读格式
      final rolesInfo = Character.formatForAI(selectedCharacters);

      // 6. 验证格式化的角色信息完整性
      expect(rolesInfo, contains('【出场人物】'));
      expect(rolesInfo, contains('1. 林风'));
      expect(rolesInfo, contains('2. 苏雨薇'));

      // 验证角色基本信息
      expect(rolesInfo, contains('基本信息：男，22岁，武学生'));
      expect(rolesInfo, contains('基本信息：女，20岁，医者'));

      // 验证角色性格特点
      expect(rolesInfo, contains('性格特点：冷静沉着，武艺高强，有强烈的正义感'));
      expect(rolesInfo, contains('性格特点：温柔善良，医术高超，内心坚强'));

      // 验证角色外貌特征
      expect(rolesInfo, contains('外貌特征：剑眉星目，眼神锐利，黑色长发束成马尾'));
      expect(rolesInfo, contains('外貌特征：肌肤如雪，柳叶眉，杏核眼，长发如瀑'));

      // 验证角色身材体型
      expect(rolesInfo, contains('身材体型：健壮，肌肉线条分明'));
      expect(rolesInfo, contains('身材体型：苗条匀称，气质优雅'));

      // 验证角色穿衣风格
      expect(rolesInfo, contains('穿衣风格：青色武服，腰间佩戴长剑'));
      expect(rolesInfo, contains('穿衣风格：白色长裙，外罩淡青色纱衣'));

      // 验证角色背景经历
      expect(rolesInfo, contains('背景经历：出身武林世家，家族被神秘势力灭门，踏上复仇之路'));
      expect(rolesInfo, contains('背景经历：医仙弟子，游历江湖救死扶伤，寻找失散的师兄'));

      // 7. 模拟构建Dify API请求参数（类似章节生成的实际流程）
      final inputs = {
        'user_input': '请写一段主角与女主角初次相遇的场景',
        'cmd': '',
        'current_chapter_content': '',
        'history_chapters_content': '前文讲述了林风为复仇踏上的江湖之路...',
        'background_setting': '古代武侠世界，江湖恩怨情仇',
        'ai_writer_setting': '',
        'next_chapter_overview': '',
        'roles': rolesInfo, // 关键：角色信息传递给AI
      };

      // 8. 验证请求参数中角色信息的完整性
      expect(inputs['roles'], isNotNull);
      expect(inputs['roles']!.toString(), contains('林风'));
      expect(inputs['roles']!.toString(), contains('苏雨薇'));
      expect(inputs['roles']!.toString(), contains('武学生'));
      expect(inputs['roles']!.toString(), contains('医者'));

      // 9. 验证角色信息的格式结构
      final rolesContent = inputs['roles'] as String;
      final roleSections = rolesContent.split('\n');

      // 确保包含必要的字段
      expect(roleSections.any((line) => line.contains('基本信息：')), isTrue);
      expect(roleSections.any((line) => line.contains('性格特点：')), isTrue);
      expect(roleSections.any((line) => line.contains('外貌特征：')), isTrue);
      expect(roleSections.any((line) => line.contains('身材体型：')), isTrue);
      expect(roleSections.any((line) => line.contains('穿衣风格：')), isTrue);
      expect(roleSections.any((line) => line.contains('背景经历：')), isTrue);
    });

    test('测试重写功能中的角色信息传递', () async {
      // 1. 创建一个简单的角色用于重写测试
      final character = Character(
        name: '李明',
        age: 25,
        gender: '男',
        occupation: '程序员',
        personality: '理性，逻辑思维强',
        bodyType: '标准身材',
        clothingStyle: '休闲装',
        appearanceFeatures: '戴眼镜，短发',
        backgroundStory: '软件工程师，喜欢解决技术问题',
        novelUrl: testNovelUrl,
      );

      // 2. 插入角色
      final characterId = await databaseService.createCharacter(character);
      final selectedIds = [characterId];

      // 3. 模拟重写功能中的角色信息获取
      final selectedCharacters = await databaseService.getCharactersByIds(selectedIds);
      final rolesInfo = Character.formatForAI(selectedCharacters);

      // 4. 模拟重写功能的Dify参数（类似ReaderScreen中的实际流程）
      final rewriteInputs = {
        'selected_paragraph': '这段代码有一个bug需要修复',
        'user_input': '请重写这段代码，使其更加优雅和高效',
        'current_chapter_content': '正在讨论程序员的日常工作',
        'history_chapters_content': [],
        'background_setting': '现代科技公司',
        'roles': rolesInfo, // 重写功能也需要角色信息
      };

      // 5. 验证重写请求中的角色信息
      expect(rewriteInputs['roles'], isNotNull);
      expect(rewriteInputs['roles']!.toString(), contains('李明'));
      expect(rewriteInputs['roles']!.toString(), contains('程序员'));
      expect(rewriteInputs['roles']!.toString(), contains('理性，逻辑思维强'));
    });

    test('测试无角色场景的默认处理', () async {
      // 1. 模拟用户未选择任何角色
      final selectedIds = <int>[];
      final selectedCharacters = await databaseService.getCharactersByIds(selectedIds);

      // 2. 格式化空角色列表
      final rolesInfo = Character.formatForAI(selectedCharacters);
      expect(rolesInfo, equals('无特定角色出场'));

      // 3. 模拟AI请求参数
      final inputs = {
        'user_input': '请写一段风景描写',
        'roles': rolesInfo,
      };

      // 4. 验证默认处理
      expect(inputs['roles'], equals('无特定角色出场'));
    });

    test('测试角色信息的可读性和AI友好性', () async {
      // 1. 创建复杂角色
      final complexCharacter = Character(
        name: '东方不败',
        age: 35,
        gender: '男',
        occupation: '日月神教教主',
        personality: '霸气侧漏，心机深沉，爱恨分明',
        bodyType: '身材修长，气质阴柔',
        clothingStyle: '红色华服，绣金凤凰图案',
        appearanceFeatures: '面如冠玉，目若朗星，红唇如血',
        backgroundStory: '夺得《葵花宝典》，练就绝世武功，称霸武林',
        novelUrl: testNovelUrl,
      );

      // 2. 插入并获取角色
      final characterId = await databaseService.createCharacter(complexCharacter);
      final characters = await databaseService.getCharactersByIds([characterId]);

      // 3. 格式化角色信息
      final rolesInfo = Character.formatForAI(characters);

      // 4. 验证AI友好的格式特性
      expect(rolesInfo, contains('【出场人物】')); // 明确的标题
      expect(rolesInfo, contains('1. 东方不败')); // 编号列表
      expect(rolesInfo.contains('基本信息：男，35岁，日月神教教主'), isTrue); // 结构化信息
      expect(rolesInfo.contains('性格特点：霸气侧漏，心机深沉，爱恨分明'), isTrue);
      expect(rolesInfo.contains('背景经历：夺得《葵花宝典》，练就绝世武功，称霸武林'), isTrue);

      // 5. 验证中文格式（对AI更友好）
      expect(rolesInfo, contains('基本信息：'));
      expect(rolesInfo, contains('性格特点：'));
      expect(rolesInfo, contains('外貌特征：'));
      expect(rolesInfo, contains('身材体型：'));
      expect(rolesInfo, contains('穿衣风格：'));
      expect(rolesInfo, contains('背景经历：'));

      // 6. 验证换行和结构（便于AI解析）
      final lines = rolesInfo.split('\n');
      expect(lines.length, greaterThan(5)); // 应该有足够的行数
      expect(lines.any((line) => line.trim().isNotEmpty), isTrue); // 非空行
    });
  });
}

/// 清理测试数据
Future<void> _cleanupTestData() async {
  final db = await DatabaseService().database;
  await db.delete(
    'characters',
    where: 'novelUrl LIKE ?',
    whereArgs: ['%ai-integration-test-novel%'],
  );
}