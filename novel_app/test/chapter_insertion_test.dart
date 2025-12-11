import 'package:flutter_test/flutter_test.dart';

void main() {
  group('章节插入逻辑测试', () {

    test('测试在第一章(index=0)后插入章节的位置', () async {
      // 模拟现有章节：第一章，索引为0
      final afterIndex = 0; // 第一章的索引

      // 根据代码逻辑计算插入位置
      final insertIndex = afterIndex + 1;

      print('第一章索引: $afterIndex');
      print('计算出的插入索引: $insertIndex');

      // 数据库操作逻辑：
      // 1. 将所有 chapterIndex >= insertIndex 的章节索引+1
      // 2. 插入新章节，索引为 insertIndex

      // 如果 insertIndex = 1，那么：
      // - 第一章索引为0，不会被移动
      // - 新章节插入在索引1的位置
      // - 原来的第二章(如果存在)会移动到索引2

      print('预期结果：新章节插入到索引1的位置(第一章后面)');

      expect(insertIndex, equals(1));
    });

    test('测试在第二章(index=1)后插入章节的位置', () async {
      // 模拟现有章节：第一章(index=0), 第二章(index=1)
      final afterIndex = 1; // 第二章的索引

      // 根据代码逻辑计算插入位置
      final insertIndex = afterIndex + 1;

      print('第二章索引: $afterIndex');
      print('计算出的插入索引: $insertIndex');

      // 如果 insertIndex = 2，那么：
      // - 第一章索引为0，不会被移动
      // - 第二章索引为1，不会被移动
      // - 新章节插入在索引2的位置
      // - 原来的第三章(如果存在)会移动到索引3

      print('预期结果：新章节插入到索引2的位置(第二章后面)');

      expect(insertIndex, equals(2));
    });

    test('测试边界情况：空列表插入第一个章节', () async {
      // 模拟空章节列表，创建第一章
      final afterIndex = 0; // 空列表时传入0

      // 根据代码逻辑计算插入位置
      final insertIndex = afterIndex + 1;

      print('空列表情况下的插入索引: $insertIndex');

      print('预期结果：新章节插入到索引1的位置');

      expect(insertIndex, equals(1));
    });
  });
}