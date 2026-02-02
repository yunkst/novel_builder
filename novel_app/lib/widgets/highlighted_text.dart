import 'package:flutter/material.dart';
import '../utils/text_highlighter.dart';

/// 高亮文本显示组件
/// 用于显示带高亮标记的文本
class HighlightedText extends StatelessWidget {
  final String highlightedText;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool selectable;

  const HighlightedText({
    super.key,
    required this.highlightedText,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final effectiveStyle = defaultStyle.merge(style);

    // 获取高亮样式
    final defaultHighlightStyle =
        const HighlightStyle().getTextStyle(effectiveStyle);
    final effectiveHighlightStyle = highlightStyle ?? defaultHighlightStyle;

    // 解析高亮文本
    final textSpans = TextHighlighter.parseHighlightedText(
      highlightedText: highlightedText,
      baseStyle: effectiveStyle,
      highlightStyle: effectiveHighlightStyle,
    );

    if (selectable) {
      // 可选择的高亮文本
      return SelectableText.rich(
        TextSpan(
          children: textSpans,
          style: effectiveStyle,
        ),
        textAlign: textAlign ?? TextAlign.left,
        maxLines: maxLines,
      );
    } else {
      // 普通高亮文本
      return RichText(
        text: TextSpan(
          children: textSpans,
          style: effectiveStyle,
        ),
        textAlign: textAlign ?? TextAlign.left,
        maxLines: maxLines,
        overflow: overflow ?? TextOverflow.ellipsis,
      );
    }
  }
}

/// 搜索结果高亮文本组件
/// 专门用于显示搜索结果中的匹配文本
class SearchResultHighlight extends StatelessWidget {
  final String originalText;
  final List<String> keywords;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int contextLength;
  final int maxLength;
  final int maxLines;
  final TextOverflow overflow;

  const SearchResultHighlight({
    super.key,
    required this.originalText,
    required this.keywords,
    this.style,
    this.highlightStyle,
    this.contextLength = 100,
    this.maxLength = 300,
    this.maxLines = 3,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    // 检查是否使用主题适配的高亮样式
    final theme = Theme.of(context);
    final defaultHighlightStyle = TextStyle(
      backgroundColor: theme.colorScheme.primary..withValues(alpha: 0.3),
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.bold,
    );

    // 提取带高亮的上下文
    final highlightedContext = TextHighlighter.extractContextWithHighlight(
      text: originalText,
      keywords: keywords,
      contextLength: contextLength,
      maxLength: maxLength,
      style: HighlightStyle(
        backgroundColor: theme.colorScheme.primary..withValues(alpha: 0.3),
        textColor: theme.colorScheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
    );

    // 如果没有匹配，显示普通文本
    if (!highlightedContext.hasMatches) {
      return Text(
        highlightedContext.text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // 显示高亮文本
    return HighlightedText(
      highlightedText: highlightedContext.text,
      style: style,
      highlightStyle: highlightStyle ?? defaultHighlightStyle,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// 标题高亮组件
/// 用于显示章节标题等较短文本的高亮
class TitleHighlight extends StatelessWidget {
  final String title;
  final List<String> keywords;
  final TextStyle? style;
  final TextStyle? highlightStyle;

  const TitleHighlight({
    super.key,
    required this.title,
    required this.keywords,
    this.style,
    this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (keywords.isEmpty) {
      return Text(
        title,
        style: style,
      );
    }

    // 高亮整个标题
    final highlightedTitle = TextHighlighter.highlightText(
      text: title,
      keywords: keywords,
      style: HighlightStyle(
        backgroundColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        textColor: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
    );

    return HighlightedText(
      highlightedText: highlightedTitle,
      style: style,
      highlightStyle: highlightStyle,
    );
  }
}

/// 多行搜索结果显示组件
/// 用于显示较长的搜索结果，支持展开/收起
class ExpandableHighlightText extends StatefulWidget {
  final String originalText;
  final List<String> keywords;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int collapsedMaxLines;
  final int expandedMaxLines;
  final String expandText;
  final String collapseText;

  const ExpandableHighlightText({
    super.key,
    required this.originalText,
    required this.keywords,
    this.style,
    this.highlightStyle,
    this.collapsedMaxLines = 3,
    this.expandedMaxLines = 10,
    this.expandText = '展开',
    this.collapseText = '收起',
  });

  @override
  State<ExpandableHighlightText> createState() =>
      _ExpandableHighlightTextState();
}

class _ExpandableHighlightTextState extends State<ExpandableHighlightText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // 提取带高亮的上下文
    final highlightedContext = TextHighlighter.extractContextWithHighlight(
      text: widget.originalText,
      keywords: widget.keywords,
      contextLength: 200, // 更大的上下文范围
      maxLength: 1000, // 更大的最大长度
      style: HighlightStyle(
        backgroundColor: Theme.of(context).colorScheme.primary
          ..withValues(alpha: 0.3),
        textColor: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
    );

    final displayText = highlightedContext.text;

    // 检查是否需要展开/收起功能
    final needsExpansion = displayText.length > 200 && _isExpanded == false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HighlightedText(
          highlightedText: displayText,
          style: widget.style,
          highlightStyle: widget.highlightStyle,
          maxLines:
              _isExpanded ? widget.expandedMaxLines : widget.collapsedMaxLines,
          overflow: TextOverflow.ellipsis,
        ),
        if (needsExpansion)
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = true;
              });
            },
            child: Text(
              widget.expandText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else if (_isExpanded)
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = false;
              });
            },
            child: Text(
              widget.collapseText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
