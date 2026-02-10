/// 段落替换工具类
///
/// 提供段落替换的核心逻辑，用于特写替换原文功能
library;

import 'package:flutter/foundation.dart';

/// 段落替换工具类
///
/// 提供纯函数实现，不依赖Flutter Widget，便于测试和复用
class ParagraphReplaceHelper {
  /// 执行段落替换逻辑
  ///
  /// [paragraphs] 原始段落列表
  /// [selectedIndices] 要删除的段落索引列表
  /// [newContent] 要插入的新内容
  ///
  /// 返回替换后的新段落列表
  ///
  /// 示例：
  /// ```dart
  /// final paragraphs = ['第一段', '第二段', '第三段'];
  /// final indices = [1];
  /// final newContent = ['改写段'];
  ///
  /// final result = ParagraphReplaceHelper.executeReplace(
  ///   paragraphs: paragraphs,
  ///   selectedIndices: indices,
  ///   newContent: newContent,
  /// );
  ///
  /// // result: ['第一段', '改写段', '第三段']
  /// ```
  static List<String> executeReplace({
    required List<String> paragraphs,
    required List<int> selectedIndices,
    required List<String> newContent,
  }) {
    // 1. 边界检查：空段落列表
    if (paragraphs.isEmpty) {
      debugPrint('⚠️ ParagraphReplaceHelper: 段落列表为空');
      return paragraphs;
    }

    // 2. 边界检查：空索引列表
    if (selectedIndices.isEmpty) {
      debugPrint('⚠️ ParagraphReplaceHelper: 未选择任何段落');
      return List<String>.from(paragraphs);
    }

    // 3. 过滤有效索引（防止越界）
    final validIndices = selectedIndices.where((index) {
      return index >= 0 && index < paragraphs.length;
    }).toList();

    if (validIndices.isEmpty) {
      debugPrint('⚠️ ParagraphReplaceHelper: 所有索引都无效');
      return List<String>.from(paragraphs);
    }

    // 4. 排序并确定插入位置（第一个有效索引）
    validIndices.sort();
    final insertPosition = validIndices.first;

    // 5. 创建副本，避免修改原列表
    final updatedParagraphs = List<String>.from(paragraphs);

    // 6. 删除选中的段落（从后往前删除，避免索引变化）
    for (int i = validIndices.length - 1; i >= 0; i--) {
      final index = validIndices[i];
      if (index < updatedParagraphs.length) {
        final removedContent = updatedParagraphs.removeAt(index);
        debugPrint(
            '🗑️ 删除段落 $index: "${removedContent.substring(0, removedContent.length > 20 ? 20 : removedContent.length)}..."');
      }
    }

    // 7. 插入新内容
    updatedParagraphs.insertAll(insertPosition, newContent);
    debugPrint('✅ 在位置 $insertPosition 插入 ${newContent.length} 段内容');

    // 8. 返回结果
    return updatedParagraphs;
  }

  /// 执行段落替换并返回完整文本
  ///
  /// 便捷方法，直接返回拼接后的文本内容
  ///
  /// [content] 原始完整文本（按\n分割）
  /// [selectedIndices] 要删除的段落索引列表
  /// [newContent] 要插入的新内容
  ///
  /// 返回替换后的完整文本
  static String executeReplaceAndJoin({
    required String content,
    required List<int> selectedIndices,
    required List<String> newContent,
  }) {
    final paragraphs = content.split('\n');
    final updatedParagraphs = executeReplace(
      paragraphs: paragraphs,
      selectedIndices: selectedIndices,
      newContent: newContent,
    );
    return updatedParagraphs.join('\n');
  }

  /// 验证索引是否有效
  ///
  /// [indices] 待验证的索引列表
  /// [paragraphsLength] 段落总数
  ///
  /// 返回过滤后的有效索引列表
  static List<int> filterValidIndices(List<int> indices, int paragraphsLength) {
    return indices.where((index) {
      return index >= 0 && index < paragraphsLength;
    }).toList();
  }

  /// 计算替换后的段落数量
  ///
  /// [originalLength] 原始段落数量
  /// [deletedCount] 删除的段落数量
  /// [insertedCount] 插入的段落数量
  ///
  /// 返回新的段落总数
  static int calculateNewLength({
    required int originalLength,
    required int deletedCount,
    required int insertedCount,
  }) {
    return originalLength - deletedCount + insertedCount;
  }

  /// 验证替换操作的完整性
  ///
  /// 检查替换后是否保留了未选中的段落
  ///
  /// [originalParagraphs] 原始段落列表
  /// [updatedParagraphs] 替换后的段落列表
  /// [selectedIndices] 被删除的段落索引
  ///
  /// 返回验证结果和错误消息
  static ({bool isValid, String message}) validateReplacement({
    required List<String> originalParagraphs,
    required List<String> updatedParagraphs,
    required List<int> selectedIndices,
  }) {
    // 检查是否有内容丢失（除了选中的段落）
    final validIndices =
        filterValidIndices(selectedIndices, originalParagraphs.length);

    // 计算应该保留的段落
    final expectedRetained = <String>[];
    for (int i = 0; i < originalParagraphs.length; i++) {
      if (!validIndices.contains(i)) {
        expectedRetained.add(originalParagraphs[i]);
      }
    }

    // 验证这些段落是否都存在于结果中
    final missing = <String>[];
    for (final paragraph in expectedRetained) {
      if (!updatedParagraphs.contains(paragraph)) {
        missing.add(paragraph);
      }
    }

    if (missing.isNotEmpty) {
      return (
        isValid: false,
        message: '警告：以下段落意外丢失: ${missing.join(", ")}',
      );
    }

    return (
      isValid: true,
      message: '✅ 替换验证通过',
    );
  }
}
