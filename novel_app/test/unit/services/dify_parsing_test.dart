import 'dart:convert';

void main() {
  // 模拟 Dify 返回的实际数据
  final testJson = '''
{
  "content": {
    "play": "【云海情劫·剑影迷踪】\\n\\n**世界观与情境重塑**",
    "role_strategy": "[{\\"name\\": \\"孟红绚\\", \\"strategy\\": \\"**性格底色**：理性至上\\"}]"
  }
}
''';

  print('=== 测试1: 实际Dify返回数据（嵌套结构 + 字符串格式） ===');
  try {
    final outputs = jsonDecode(testJson);
    final content = outputs['content'] as Map<String, dynamic>?;

    if (content != null) {
      final play = content['play'] as String?;
      final roleStrategyRaw = content['role_strategy'];

      print('✅ play类型: ${play.runtimeType}');
      print('✅ play内容: ${play?.substring(0, 20)}...');
      print('✅ role_strategy原始类型: ${roleStrategyRaw.runtimeType}');

      // 测试解析逻辑
      final roleStrategy = _parseRoleStrategy(roleStrategyRaw);
      print('✅ role_strategy解析后类型: ${roleStrategy.runtimeType}');
      print('✅ role_strategy数量: ${roleStrategy.length}');
      print('✅ 第一个元素: ${roleStrategy[0]}');

      final firstItem = roleStrategy[0] as Map<String, dynamic>;
      print('✅ 角色名: ${firstItem['name']}');
      final strategy = firstItem['strategy'] as String;
      print('✅ 策略: ${strategy.length > 20 ? strategy.substring(0, 20) : strategy}...');
    }
    print('✅ 测试1通过\n');
  } catch (e) {
    print('❌ 测试1失败: $e\n');
  }

  print('=== 测试2: 数组格式（扁平结构） ===');
  try {
    final arrayFormatJson = '''
{
  "play": "测试剧本",
  "role_strategy": [
    {"name": "张三", "strategy": "张三的策略"},
    {"name": "李四", "strategy": "李四的策略"}
  ]
}
''';

    final outputs2 = jsonDecode(arrayFormatJson);
    final play = outputs2['play'] as String?;
    final roleStrategyRaw = outputs2['role_strategy'];

    print('✅ play: $play');
    print('✅ role_strategy原始类型: ${roleStrategyRaw.runtimeType}');

    final roleStrategy = _parseRoleStrategy(roleStrategyRaw);
    print('✅ 解析后数量: ${roleStrategy.length}');
    print('✅ 角色列表: ${(roleStrategy as List).map((e) => e['name']).join(', ')}');
    print('✅ 测试2通过\n');
  } catch (e) {
    print('❌ 测试2失败: $e\n');
  }

  print('=== 测试3: 字符串格式（扁平结构） ===');
  try {
    final stringFormatJson = '''
{
  "play": "测试剧本2",
  "role_strategy": "[{\\"name\\": \\"王五\\", \\"strategy\\": \\"王五的策略\\"}]"
}
''';

    final outputs3 = jsonDecode(stringFormatJson);
    final roleStrategyRaw = outputs3['role_strategy'];

    print('✅ role_strategy原始类型: ${roleStrategyRaw.runtimeType}');

    final roleStrategy = _parseRoleStrategy(roleStrategyRaw);
    print('✅ 解析后数量: ${roleStrategy.length}');
    print('✅ 角色名: ${(roleStrategy[0] as Map<String, dynamic>)['name']}');
    print('✅ 测试3通过\n');
  } catch (e) {
    print('❌ 测试3失败: $e\n');
  }

  print('=== 测试4: 错误格式测试 ===');

  print('--- 测试4.1: 空字符串 ---');
  try {
    _parseRoleStrategy('');
    print('❌ 应该抛出异常但没有');
  } catch (e) {
    print('✅ 正确捕获异常: $e');
  }

  print('\n--- 测试4.2: 数字类型 ---');
  try {
    _parseRoleStrategy(123);
    print('❌ 应该抛出异常但没有');
  } catch (e) {
    print('✅ 正确捕获异常: $e');
  }

  print('\n--- 测试4.3: 无效JSON字符串 ---');
  try {
    _parseRoleStrategy('not a json');
    print('❌ 应该抛出异常但没有');
  } catch (e) {
    print('✅ 正确捕获异常: ${e.toString().substring(0, 50)}...');
  }

  print('\n=== 测试5: 完整的实际数据（简化版） ===');
  try {
    // 使用简化但完整的数据结构
    final fullData = {
      "content": {
        "play": "【云海情劫·剑影迷踪】\n\n**世界观与情境重塑**\n\n**情境基调**：\n- **云海秘境**：药清罂所在之处，金光璀璨，白云无垠，氛围**静谧而神圣**，如世外桃源，但暗藏师尊对徒儿的深沉关切与仙路艰险的警示。",
        "role_strategy": '[{"name": "孟红绚", "strategy": "**性格底色**：理性至上、谨慎多疑、利益权衡。\\n**情感羁绊**：对裴凌持**利用与观察**态度，认为其幽素坟机缘是变数，与岑芳渥有同门之谊但更重宗门利益。", "clothes": "素雅道袍，青丝以玉簪束起。"}]'
      }
    };

    final outputs5 = fullData;
    final content5 = outputs5['content'] as Map<String, dynamic>;
    final play5 = content5['play'] as String?;
    final roleStrategyRaw5 = content5['role_strategy'];

    print('✅ 剧本长度: ${play5?.length} 字符');
    print('✅ role_strategy原始类型: ${roleStrategyRaw5.runtimeType}');

    final roleStrategy5 = _parseRoleStrategy(roleStrategyRaw5);
    print('✅ 解析成功，数量: ${roleStrategy5.length}');

    final character = roleStrategy5[0] as Map<String, dynamic>;
    print('✅ 角色名: ${character['name']}');
    print('✅ 策略长度: ${(character['strategy'] as String).length} 字符');
    print('✅ 服装: ${character['clothes']}');
    print('✅ 测试5通过\n');
  } catch (e) {
    print('❌ 测试5失败: $e\n');
  }

  print('\n=== 全部测试完成 ===');
}

/// 解析 role_strategy（支持字符串和数组两种格式）
List<dynamic> _parseRoleStrategy(dynamic roleStrategyRaw) {
  if (roleStrategyRaw is List) {
    // 已经是数组，直接返回
    return roleStrategyRaw;
  }

  if (roleStrategyRaw is String) {
    // 是字符串，需要解析JSON
    try {
      final decoded = jsonDecode(roleStrategyRaw);
      if (decoded is List) {
        return decoded;
      } else {
        print('❌ role_strategy字符串解析后不是数组: $decoded');
        throw Exception('role_strategy格式错误：解析后不是数组');
      }
    } catch (e) {
      print('❌ role_strategy字符串解析失败: $e');
      print('原始字符串: $roleStrategyRaw');
      throw Exception('role_strategy字符串解析失败: $e');
    }
  }

  print('❌ role_strategy类型错误: ${roleStrategyRaw.runtimeType}');
  throw Exception('role_strategy格式错误：不支持的类型 ${roleStrategyRaw.runtimeType}');
}
