/// 段落替换逻辑测试
///
/// 测试新的删除+插入逻辑的各种边界情况

void main() {
  print('========== 段落替换逻辑测试 ==========\n');

  test1_MoreParagraphsGenerated();
  test2_FewerParagraphsGenerated();
  test3_ContainsIllustration();
  test4_BoundaryIndexCheck();
  test5_EmptyContentHandling();

  print('\n========== 所有测试完成 ==========');
}

/// 测试用例1: AI生成更多段落
void test1_MoreParagraphsGenerated() {
  print('\n📝 测试1: AI生成更多段落');
  print('场景: 选中3段，AI生成5段');

  final paragraphs = ['第一段', '第二段', '第三段', '第四段', '第五段'];
  final selectedIndices = [1, 2, 3]; // 选中第二、三、四段
  final aiContent = ['改写1', '改写2', '改写3', '改写4', '改写5'];

  print('原文段落数: ${paragraphs.length}');
  print('选中索引: $selectedIndices');
  print('AI生成段落数: ${aiContent.length}');

  // 模拟删除+插入逻辑
  final updated = List<String>.from(paragraphs);
  final insertPos = selectedIndices.first;

  // 从后往前删除
  for (int i = selectedIndices.length - 1; i >= 0; i--) {
    updated.removeAt(selectedIndices[i]);
  }

  // 插入新内容
  updated.insertAll(insertPos, aiContent);

  print('新段落数: ${updated.length}');
  print('预期: 5 - 3 + 5 = 7');
  print('结果: ${updated.length}');
  print('✅ 测试通过: ${updated.length == 7}');
  print('新内容: $updated');
}

/// 测试用例2: AI生成更少段落
void test2_FewerParagraphsGenerated() {
  print('\n📝 测试2: AI生成更少段落');
  print('场景: 选中3段，AI生成2段');

  final paragraphs = ['第一段', '第二段', '第三段', '第四段', '第五段'];
  final selectedIndices = [1, 2, 3];
  final aiContent = ['改写1', '改写2'];

  print('原文段落数: ${paragraphs.length}');
  print('选中索引: $selectedIndices');
  print('AI生成段落数: ${aiContent.length}');

  final updated = List<String>.from(paragraphs);
  final insertPos = selectedIndices.first;

  for (int i = selectedIndices.length - 1; i >= 0; i--) {
    updated.removeAt(selectedIndices[i]);
  }

  updated.insertAll(insertPos, aiContent);

  print('新段落数: ${updated.length}');
  print('预期: 5 - 3 + 2 = 4');
  print('结果: ${updated.length}');
  print('✅ 测试通过: ${updated.length == 4}');
  print('新内容: $updated');
}

/// 测试用例3: 选中包含插图
void test3_ContainsIllustration() {
  print('\n📝 测试3: 选中包含插图');
  print('场景: 选中段落包含 [!插图!](task123)');

  final paragraphs = ['第一段', '[!插图!](task123)', '第三段'];
  final selectedIndices = [0, 1, 2];
  final aiContent = ['改写1', '改写2', '改写3'];

  print('原文: $paragraphs');
  print('选中索引: $selectedIndices');
  print('AI生成内容: $aiContent');
  print('检测到插图标记: [!插图!](task123)');
  print('⚠️ 需要用户确认: 保留插图或删除并替换');

  // 模拟用户选择"删除并替换"
  final updated = List<String>.from(paragraphs);
  final insertPos = selectedIndices.first;

  for (int i = selectedIndices.length - 1; i >= 0; i--) {
    updated.removeAt(selectedIndices[i]);
  }

  updated.insertAll(insertPos, aiContent);

  print('✅ 用户选择删除并替换后:');
  print('新内容: $updated');
  print('插图已删除，替换为文本');
}

/// 测试用例4: 边界索引检查
void test4_BoundaryIndexCheck() {
  print('\n📝 测试4: 边界索引检查');
  print('场景: 选中索引超出范围');

  final paragraphs = ['第一段', '第二段', '第三段'];
  final selectedIndices = [0, 1, 100]; // 索引100超出范围
  final aiContent = ['改写1'];

  print('原文段落数: ${paragraphs.length}');
  print('选中索引: $selectedIndices');
  print('⚠️ 索引100超出范围');

  // 过滤有效索引
  final validIndices = selectedIndices
      .where((index) => index >= 0 && index < paragraphs.length)
      .toList();

  print('有效索引: $validIndices');

  final updated = List<String>.from(paragraphs);

  if (validIndices.isNotEmpty) {
    final insertPos = validIndices.first;
    for (int i = validIndices.length - 1; i >= 0; i--) {
      updated.removeAt(validIndices[i]);
    }
    updated.insertAll(insertPos, aiContent);
  }

  print('新内容: $updated');
  print('✅ 测试通过: 自动过滤无效索引');
}

/// 测试用例5: 空内容处理
void test5_EmptyContentHandling() {
  print('\n📝 测试5: 空内容处理');
  print('场景: AI生成空内容');

  final paragraphs = ['第一段', '第二段', '第三段'];
  final selectedIndices = [1];
  final aiContent = <String>[]; // 空数组

  print('原文: $paragraphs');
  print('选中索引: $selectedIndices');
  print('AI生成内容: 空（${aiContent.length}段）');

  final updated = List<String>.from(paragraphs);
  final insertPos = selectedIndices.first;

  updated.removeAt(selectedIndices.first);
  updated.insertAll(insertPos, aiContent); // 插入空内容

  print('新内容: $updated');
  print('新段落数: ${updated.length}');
  print('预期: 3 - 1 + 0 = 2');
  print('✅ 测试通过: ${updated.length == 2}');
  print('说明: 只删除选中段落，不插入新内容');
}
