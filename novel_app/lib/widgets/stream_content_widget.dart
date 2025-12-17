import 'package:flutter/material.dart';
import '../models/stream_config.dart';
import '../services/unified_stream_manager.dart';

/// 通用流式内容显示组件
/// 封装所有流式内容的显示和处理逻辑，支持配置化的行为模式
class StreamContentWidget extends StatefulWidget {
  /// 流式配置
  final StreamConfig config;

  /// 文本控制器
  final TextEditingController? controller;

  /// 内容变化回调
  final ValueChanged<String>? onChanged;

  /// 开始生成回调
  final VoidCallback? onGenerationStart;

  /// 完成生成回调
  final ValueChanged<String>? onGenerationComplete;

  /// 生成错误回调
  final ValueChanged<String>? onGenerationError;

  /// 自定义加载指示器
  final Widget? loadingIndicator;

  /// 自定义装饰
  final InputDecoration? decoration;

  /// 自定义文本样式
  final TextStyle? textStyle;

  /// 自定义焦点节点
  final FocusNode? focusNode;

  /// 是否自动开始生成
  final bool autoStart;

  const StreamContentWidget({
    super.key,
    required this.config,
    this.controller,
    this.onChanged,
    this.onGenerationStart,
    this.onGenerationComplete,
    this.onGenerationError,
    this.loadingIndicator,
    this.decoration,
    this.textStyle,
    this.focusNode,
    this.autoStart = false,
  });

  @override
  State<StreamContentWidget> createState() => _StreamContentWidgetState();
}

class _StreamContentWidgetState extends State<StreamContentWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;

  final UnifiedStreamManager _streamManager = UnifiedStreamManager();

  bool _isGenerating = false;
  String? _generationError;
  String? _currentStreamId; // 管理当前流ID以便取消
  bool _isDisposed = false; // 防止内存泄漏的状态标记

  @override
  void initState() {
    super.initState();

    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _scrollController = ScrollController();

    // 自动开始生成
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startGeneration();
      });
    }
  }

  @override
  void dispose() {
    // 最佳实践：在组件销毁时取消正在进行的流
    _isDisposed = true;

    // 取消当前流
    if (_currentStreamId != null) {
      _streamManager.cancelStream(_currentStreamId!);
    }

    // 清理控制器
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _scrollController.dispose();

    super.dispose();
  }

  /// 开始流式生成
  Future<void> _startGeneration() async {
    if (_isGenerating || _isDisposed) return;

    setState(() {
      _isGenerating = true;
      _generationError = null;
    });

    widget.onGenerationStart?.call();

    try {
      _currentStreamId = await _streamManager.executeStream(
        config: widget.config,
        onChunk: (textChunk) {
          if (_isDisposed) return; // 防止组件销毁后回调
          _handleTextChunk(textChunk);
        },
        onComplete: (fullContent) {
          if (_isDisposed) return; // 防止组件销毁后回调
          _handleGenerationComplete(fullContent);
        },
        onError: (error) {
          if (_isDisposed) return; // 防止组件销毁后回调
          _handleGenerationError(error);
        },
      );
    } catch (e, stackTrace) {
      // 最佳实践：记录详细的错误信息
      debugPrint('StreamContentWidget 启动失败: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!_isDisposed) {
        _handleGenerationError('生成启动失败: $e');
      }
    }
  }

  /// 处理文本块
  void _handleTextChunk(String textChunk) {
    // 检查是否是完整内容的特殊标记
    final bool isCompleteContent = textChunk.startsWith('<<COMPLETE_CONTENT>>');

    if (isCompleteContent) {
      // 提取实际内容（移除特殊标记）
      final completeContent = textChunk.substring('<<COMPLETE_CONTENT>>'.length);
      _handleGenerationComplete(completeContent);
    } else {
      // 流式模式：追加内容
      if (mounted) {
        setState(() {
          _controller.text += textChunk;
        });

        widget.onChanged?.call(_controller.text);

        // 自动滚动到文本末尾
        if (widget.config.autoScroll) {
          _scrollToBottom();
        }
      }
    }
  }

  /// 处理生成完成
  void _handleGenerationComplete(String fullContent) {
    _currentStreamId = null; // 清理流ID

    if (mounted && !_isDisposed) {
      setState(() {
        _controller.text = fullContent;
        _isGenerating = false;
        _generationError = null;
      });

      widget.onChanged?.call(fullContent);
      widget.onGenerationComplete?.call(fullContent);

      debugPrint('StreamContentWidget 生成完成，内容长度: ${fullContent.length}');
    }
  }

  /// 处理生成错误
  void _handleGenerationError(String error) {
    _currentStreamId = null; // 清理流ID

    if (mounted && !_isDisposed) {
      setState(() {
        _isGenerating = false;
        _generationError = error;
      });

      widget.onGenerationError?.call(error);

      // 最佳实践：记录错误到控制台
      debugPrint('StreamContentWidget 生成错误: $error');
    }
  }

  /// 滚动到文本末尾
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: widget.config.scrollDuration,
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 重新生成
  void regenerate() {
    if (!_isGenerating) {
      _controller.clear();
      _startGeneration();
    }
  }

  /// 停止生成
  Future<void> stopGeneration() async {
    if (_currentStreamId != null) {
      await _streamManager.cancelStream(_currentStreamId!);
      _currentStreamId = null;
    }

    if (mounted && !_isDisposed) {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  /// 获取当前内容
  String get content => _controller.text;

  /// 设置内容
  set content(String value) {
    _controller.text = value;
  }

  /// 是否正在生成
  bool get isGenerating => _isGenerating;

  /// 生成错误信息
  String? get generationError => _generationError;

  /// 检查是否有正在进行的流
  bool get hasActiveStream => _currentStreamId != null;

  /// 获取当前流ID
  String? get currentStreamId => _currentStreamId;

  @override
  Widget build(BuildContext context) {
    // 构建文本样式
    TextStyle effectiveTextStyle = widget.textStyle ?? const TextStyle();

    if (_isGenerating && widget.config.generatingTextColor != null) {
      effectiveTextStyle = effectiveTextStyle.copyWith(
        color: _parseColor(widget.config.generatingTextColor!),
      );
    }

    // 构建输入装饰
    InputDecoration effectiveDecoration = widget.decoration ??
        InputDecoration(
          hintText: widget.config.generatingHint ?? '请输入内容...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding: const EdgeInsets.all(12),
        );

    // 如果正在生成，修改装饰样式
    if (_isGenerating) {
      effectiveDecoration = effectiveDecoration.copyWith(
        hintText: widget.config.generatingHint ?? 'AI正在生成，请稍候...',
        hintStyle: effectiveDecoration.hintStyle?.copyWith(
          color: widget.config.generatingTextColor != null
              ? _parseColor(widget.config.generatingTextColor!).withValues(alpha: 0.7)
              : null,
        ),
        filled: true,
        fillColor: widget.config.generatingBackgroundColor != null
            ? _parseColor(widget.config.generatingBackgroundColor!)
            : Colors.grey.shade50,
        enabledBorder: effectiveDecoration.enabledBorder?.copyWith(
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 主输入区域
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          scrollController: _scrollController,
          maxLines: widget.config.maxLines,
          minLines: widget.config.minLines,
          enabled: !_isGenerating || !widget.config.disableEditWhileGenerating,
          style: effectiveTextStyle,
          decoration: effectiveDecoration,
          onChanged: widget.onChanged,
        ),

        // 错误信息显示
        if (_generationError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: Colors.red.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _generationError!,
                    style: TextStyle(color: Colors.red.shade600, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    setState(() {
                      _generationError = null;
                    });
                  },
                  color: Colors.red.shade600,
                ),
              ],
            ),
          ),
        ],

        // 加载指示器
        if (_isGenerating && widget.loadingIndicator != null) ...[
          const SizedBox(height: 8),
          widget.loadingIndicator!,
        ],
      ],
    );
  }

  /// 解析颜色字符串
  Color _parseColor(String colorString) {
    try {
      // 支持 #RRGGBB 格式
      if (colorString.startsWith('#')) {
        return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
      }
      // 支持颜色名称
      switch (colorString.toLowerCase()) {
        case 'black':
          return Colors.black;
        case 'white':
          return Colors.white;
        case 'red':
          return Colors.red;
        case 'green':
          return Colors.green;
        case 'blue':
          return Colors.blue;
        case 'grey':
        case 'gray':
          return Colors.grey;
        default:
          return Colors.black; // 默认黑色
      }
    } catch (e) {
      debugPrint('颜色解析失败: $colorString, 使用默认黑色');
      return Colors.black;
    }
  }
}