# 搜索结果 UI 优化

## 任务上下文

**问题描述**:
1. 没有展示章节的标题（需要确认）
2. 重复展示章节信息，不需要展示【第 X 章】，匹配数应该展示在章节标题后面
3. 展示的搜索结果内容中，应该把搜索关键词相关的正文前后20字列出来。如果一个章节中存在多个匹配，那么也都需要展示出来

**目标文件**: `novel_app/lib/screens/chapter_search_screen.dart`

## 问题分析

### 当前 UI 结构

```
┌────────────────────────────────────────────────────┐
│ 第一章 少年与魔法              ← 标题（有显示）    │
│ 第 1 章    ┃  2 处匹配           ← ❌ 重复信息    │
│ ─────────────────────────────────────────────────  │
│ ...长文本内容（只显示第一个匹配的上下文）...      │
│ 缓存于 2025/01/20 14:30:00                         │
└────────────────────────────────────────────────────┘
```

### 期望 UI 结构

```
┌────────────────────────────────────────────────────┐
│ 第一章 少年与魔法 (2处匹配)    ← ✅ 标题+匹配数    │
│                                                    │
│ ...森林中发现了【魔法】阵法...     ← 匹配1         │
│ ...这个【魔法】阵法散发着...       ← 匹配2         │
│                                                    │
│ 缓存于 2025/01/20 14:30:00                         │
└────────────────────────────────────────────────────┘
```

### 技术问题

1. `TextHighlighter.extractContextWithHighlight` 只展示第一个匹配
2. `contextLength` 参数为 100 字符，需要改为 20 字（约 40 字符）

## 执行步骤

### 步骤 1: 修改 `chapter_search_screen.dart` UI 结构

**文件**: `novel_app/lib/screens/chapter_search_screen.dart`

**位置**: 第 244-379 行 (`_buildSearchResults` 方法中的 `ListView.builder`)

#### 1.1 修改标题显示

**当前代码** (第 253-269 行):
```dart
title: result.hasHighlight
    ? TitleHighlight(
        title: result.chapterTitle,
        keywords: result.searchKeywords,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      )
    : Text(
        result.chapterTitle,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
```

**修改为**:
```dart
title: Row(
  children: [
    Expanded(
      child: result.hasHighlight
          ? TitleHighlight(
              title: result.chapterTitle,
              keywords: result.searchKeywords,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            )
          : Text(
              result.chapterTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
    ),
    if (result.matchCount > 0)
      Text(
        ' (${result.matchCount}处匹配)',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
          fontWeight: FontWeight.normal,
        ),
      ),
  ],
),
```

**变更说明**:
- 使用 `Row` 包裹标题和匹配数
- 匹配数显示在标题后面的括号中
- 样式为灰色、14px、普通字重

#### 1.2 移除 "第 X 章" 和匹配数徽章

**当前代码** (第 270-311 行):
```dart
subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // 章节索引和匹配信息
    Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            result.chapterIndexText,  // ← 删除
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
        if (result.matchCount > 0) const SizedBox(width: 8),
        if (result.matchCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Container(  // ← 删除
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${result.matchCount} 处匹配',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    ),
    // ...
  ],
),
```

**修改为**:
```dart
subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // 匹配的文本片段列表（带高亮）
    ..._buildMatchHighlights(result),

    // 缓存时间
    Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '缓存于 ${result.cachedDate.toString().substring(0, 19).replaceAll('-', '/')}',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[500],
        ),
      ),
    ),
  ],
),
```

**变更说明**:
- 删除整个 `Row` 组件（章节索引和匹配数徽章）
- 使用 spread operator `...` 调用新方法 `_buildMatchHighlights`
- 保留缓存时间显示

#### 1.3 添加 `_buildMatchHighlights` 方法

**位置**: 在 `_ChapterSearchScreenState` 类中添加新方法

**添加代码**:
```dart
/// 构建所有匹配项的高亮显示
List<Widget> _buildMatchHighlights(ChapterSearchResult result) {
  if (!result.hasHighlight || result.matchPositions.isEmpty) {
    return [];
  }

  return result.matchPositions.map((position) {
    // 提取匹配位置前后的上下文
    final start = (position.start - 20).clamp(0, result.content.length);
  final end = (position.end + 20).clamp(0, result.content.length);
  final contextText = result.content.substring(start, end);

  // 添加省略号
  final displayText = (start > 0 ? '...' : '') +
                     contextText +
                     (end < result.content.length ? '...' : '');

  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: SearchResultHighlight(
      originalText: result.content,
      keywords: result.searchKeywords,
      style: const TextStyle(
        fontSize: 14,
        height: 1.4,
      ),
      maxLines: 2,
    ),
  );
}).toList();
}
```

**预期结果**: 每个匹配项独立显示一个高亮块

---

### 步骤 2: 创建新的多匹配高亮组件（备选）

**文件**: `novel_app/lib/widgets/multiple_match_highlight.dart`

**创建新组件**:
```dart
import 'package:flutter/material.dart';
import 'highlighted_text.dart';

/// 多匹配高亮显示组件
/// 为每个匹配位置独立显示带高亮的上下文
class MultipleMatchHighlight extends StatelessWidget {
  final String content;
  final List<String> keywords;
  final int contextLength;
  final TextStyle? style;
  final TextStyle? highlightStyle;

  const MultipleMatchHighlight({
    super.key,
    required this.content,
    required this.keywords,
    this.contextLength = 20, // 默认前后20字
    this.style,
    this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    // 查找所有匹配位置
    final matches = _findAllMatches();

    if (matches.isEmpty) {
      return Text(
        content,
        style: style,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: matches.map((match) {
        // 提取上下文
        final start = (match.start - contextLength).clamp(0, content.length);
        final end = (match.end + contextLength).clamp(0, content.length);
        var contextText = content.substring(start, end);

        // 添加省略号
        if (start > 0) contextText = '...$contextText';
        if (end < content.length) contextText = '$contextText...';

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _SingleMatchHighlight(
            text: contextText,
            keyword: match.keyword,
            baseStyle: style,
            highlightStyle: highlightStyle,
          ),
        );
      }).toList(),
    );
  }

  /// 查找所有匹配位置
  List<_MatchInfo> _findAllMatches() {
    final List<_MatchInfo> matches = [];

    for (final keyword in keywords) {
      if (keyword.isEmpty) continue;

      final pattern = RegExp(keyword, caseSensitive: false);
      for (final match in pattern.allMatches(content)) {
        matches.add(_MatchInfo(
          start: match.start,
          end: match.end,
          keyword: match.group(0) ?? '',
        ));
      }
    }

    matches.sort((a, b) => a.start.compareTo(b.start));
    return matches;
  }
}

/// 单个匹配高亮组件
class _SingleMatchHighlight extends StatelessWidget {
  final String text;
  final String keyword;
  final TextStyle? baseStyle;
  final TextStyle? highlightStyle;

  const _SingleMatchHighlight({
    required this.text,
    required this.keyword,
    this.baseStyle,
    this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    final pattern = RegExp(RegExp.escape(keyword), caseSensitive: false);
    final match = pattern.firstMatch(text);

    if (match == null) {
      return Text(text, style: baseStyle);
    }

    final before = text.substring(0, match.start);
    final matched = text.substring(match.start, match.end);
    final after = text.substring(match.end);

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: before),
          TextSpan(
            text: matched,
            style: highlightStyle ??
                TextStyle(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(0.3),
                  fontWeight: FontWeight.bold,
                ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}

class _MatchInfo {
  final int start;
  final int end;
  final String keyword;

  _MatchInfo({required this.start, required this.end, required this.keyword});
}
```

**预期结果**: 创建专门处理多匹配的组件

---

### 步骤 3: 调整上下文长度参数

**文件**: `novel_app/lib/widgets/highlighted_text.dart`

**位置**: 第 104-114 行 (`SearchResultHighlight.build` 方法)

**当前代码**:
```dart
final highlightedContext = TextHighlighter.extractContextWithHighlight(
  text: originalText,
  keywords: keywords,
  contextLength: 100,  // ← 改为 40（20个中文字符）
  maxLength: 300,
  style: HighlightStyle(...),
);
```

**修改为**:
```dart
final highlightedContext = TextHighlighter.extractContextWithHighlight(
  text: originalText,
  keywords: keywords,
  contextLength: 40,  // 20个中文字符（每个中文字符约2字节）
  maxLength: 300,
  style: HighlightStyle(...),
);
```

**预期结果**: 搜索结果显示前后20字的上下文

---

### 步骤 4: 测试搜索功能

**操作**:
1. 启动 Flutter 应用
2. 进入任意小说的章节列表
3. 点击搜索按钮
4. 输入关键词搜索
5. 检查搜索结果展示

**预期结果**:
- 标题后面显示 "(X处匹配)"
- 不再显示 "第 X 章"
- 每个匹配项独立显示前后20字的高亮内容
- 多个匹配都展示出来

## 变更摘要

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `chapter_search_screen.dart` | 修改 UI 结构 | 移除"第X章"，匹配数移到标题后 |
| `highlighted_text.dart` | 修改参数 | contextLength: 100 → 40 |
| `multiple_match_highlight.dart` | 新建组件 | 多匹配高亮显示（可选） |

## 注意事项

1. 中文字符通常占用 2 字节，所以 20 个中文字 ≈ 40 字符长度
2. 如果匹配项很多，可能需要限制显示数量或添加展开/收起功能
3. 确保 `TextHighlighter` 能够正确处理多匹配场景
