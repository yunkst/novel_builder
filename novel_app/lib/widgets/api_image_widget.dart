import 'package:flutter/material.dart';
import '../services/logger_service.dart';
import 'common/common_widgets.dart';

/// 使用API客户端的图片加载组件
class ApiImageWidget extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableRetry;
  final Function()? onRetry;
  final Duration? timeout;

  const ApiImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.enableRetry = true,
    this.onRetry,
    this.timeout = const Duration(seconds: 30),
  });

  @override
  State<ApiImageWidget> createState() => _ApiImageWidgetState();
}

class _ApiImageWidgetState extends State<ApiImageWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.isEmpty) {
      return _buildErrorWidget('图片URL为空');
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Image.network(
        widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          LoggerService.instance.e(
            '图片加载失败: ${widget.imageUrl}',
            stackTrace: stackTrace.toString(),
            category: LogCategory.network,
            tags: ['image', 'load', 'failed'],
          );
          return _buildErrorWidget(error.toString());
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Container(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
        child: const LoadingStateWidget(
          message: '加载中...',
          centered: true,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String? error) {
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Container(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        child: ErrorStateWidget(
          message: '图片加载失败',
          icon: Icons.broken_image_outlined,
          onRetry: widget.enableRetry ? () => _retry() : null,
          centered: true,
        ),
      ),
    );
  }

  Future<void> _retry() async {
    if (!widget.enableRetry) return;
    if (widget.onRetry != null) {
      await widget.onRetry!();
    }
    setState(() {});
  }

  Future<void> retry() async {
    await _retry();
  }
}