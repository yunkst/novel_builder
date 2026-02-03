import 'package:flutter/material.dart';
import '../models/scene_illustration.dart';
import '../services/api_service_wrapper.dart';
import '../utils/video_generation_state_manager.dart';
import '../utils/image_cache_manager.dart';
import '../utils/toast_utils.dart';
import '../services/logger_service.dart';
import '../utils/error_helper.dart';
import 'hybrid_media_widget.dart';
import 'generate_more_dialog.dart';
import 'common/common_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/services/network_service_providers.dart';

/// 场景插图预览组件
///
/// 本组件展示场景插图生成的图片集合，支持预览、删除、视频生成等功能。
///
/// ## 核心功能
/// - **图片加载**：从后端 API 加载场景插图列表，支持新旧两种数据格式
/// - **预览 UI**：全屏预览图片，支持左右滑动切换
/// - **视频生成**：为图片生成视频，实时显示生成进度
/// - **图片删除**：单张图片删除，带连击保护和确认对话框
/// - **宽高比计算**：根据模型参数自动计算图片宽高比
///
/// ## 数据格式兼容性
/// ### 新格式（推荐）
/// ```json
/// {
///   "task_id": "xxx",
///   "images": [
///     {"url": "http://...", "model_name": "sd_xl_base"},
///     {"url": "http://...", "model_name": "sdxl_t2i"}
///   ],
///   "model_width": 1024,
///   "model_height": 2048
/// }
/// ```
///
/// ### 旧格式（兼容）
/// ```json
/// {
///   "images": ["http://...", "http://..."]
/// }
/// ```
///
/// ## 宽高比计算逻辑
/// 1. 优先使用从 API 获取的模型宽高（`_modelWidth`, `_modelHeight`）
/// 2. 其次使用 widget 参数提供的宽高（`widget.modelWidth`, `widget.modelHeight`）
/// 3. 最后使用默认比例 0.5（高是宽的2倍）
///
/// ## 视频生成状态管理
/// - 使用 `VideoGenerationStateManager` 管理全局视频生成状态
/// - 监听状态变化，实时更新 UI
/// - 支持同时为多张图片生成视频
///
/// ## 删除保护
/// - 连击保护：2次删除间隔需大于1秒
/// - 确认对话框：删除前需要用户确认
/// - 回调通知：删除成功后触发 `onImageDeleted` 回调
class SceneImagePreview extends ConsumerStatefulWidget {
  final SceneIllustration? illustration; // 可选，用于向后兼容
  final String? taskId; // 新版本：基于 taskId 查询
  final Function(String taskId, String imageUrl, int imageIndex)? onImageTap;
  final Function(String taskId)? onDelete;
  final VoidCallback? onImageDeleted; // 单张图片删除成功回调
  final int? modelWidth; // 新增：模型宽度
  final int? modelHeight; // 新增：模型高度

  const SceneImagePreview({
    super.key,
    this.illustration,
    this.taskId,
    this.onImageTap,
    this.onDelete,
    this.onImageDeleted,
    this.modelWidth,
    this.modelHeight,
  }) : assert(
          illustration != null || taskId != null,
          '必须提供 illustration 或 taskId',
        );

  @override
  ConsumerState<SceneImagePreview> createState() => _SceneImagePreviewState();
}

class _SceneImagePreviewState extends ConsumerState<SceneImagePreview> {
  // ========================================================================
  // 状态管理
  // ========================================================================

  /// 是否正在加载
  bool _isLoading = false;

  /// 是否发生错误
  bool _hasError = false;

  /// 错误消息
  String? _errorMessage;

  /// 图片URL列表
  List<String> _images = [];

  /// 索引 -> 模型名映射
  Map<int, String?> _imageModels = {};

  /// 当前页面索引
  int _currentIndex = 0;

  /// 模型宽度（从 API 获取）
  int? _modelWidth;

  /// 模型高度（从 API 获取）
  int? _modelHeight;

  // ========================================================================
  // 删除相关状态
  // ========================================================================

  /// 是否正在删除
  bool _isDeleting = false;

  /// 正在删除的图片 filename
  String? _deletingImage;

  /// 最后删除时间（用于连击保护）
  DateTime? _lastDeleteTime;

  // ========================================================================
  // 生命周期管理
  // ========================================================================

  @override
  void initState() {
    super.initState();
    // 添加状态变化监听器
    VideoGenerationStateManager.addListener(_onStateChanged);
    if (widget.taskId != null) {
      _loadIllustrationFromBackend();
    }
  }

  @override
  void dispose() {
    // 移除状态变化监听器
    VideoGenerationStateManager.removeListener(_onStateChanged);
    super.dispose();
  }

  /// 状态变化回调
  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // ========================================================================
  // 图片加载
  // ========================================================================

  /// 从后端加载场景插图图集
  Future<void> _loadIllustrationFromBackend() async {
    if (widget.taskId == null || !mounted) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
    }

    try {
      final apiService = ApiServiceWrapper();
      final galleryData =
          await apiService.getSceneIllustrationGallery(widget.taskId!);

      if (mounted) {
        // 安全解析图片列表
        final rawImages = galleryData['images'];
        List<String> images = [];
        Map<int, String?> imageModels = {};

        if (rawImages is List) {
          for (var i = 0; i < rawImages.length; i++) {
            final item = rawImages[i];
            if (item is Map) {
              // 新格式：{'url': 'xxx', 'model_name': 'xxx'}
              final url = item['url']?.toString() ?? '';
              if (url.isNotEmpty) {
                images.add(url);
                imageModels[i] = item['model_name']?.toString();
              }
            } else if (item is String) {
              // 兼容旧格式：纯字符串
              final url = item.toString();
              if (url.isNotEmpty) {
                images.add(url);
                imageModels[i] = null;
              }
            }
          }
        }

        setState(() {
          _images = images;
          _imageModels = imageModels;
          _modelWidth = galleryData['model_width'];
          _modelHeight = galleryData['model_height'];
          _isLoading = false;

          LoggerService.instance.i(
            '加载插图信息: ${_images.length} 张图片, 模型尺寸: ${_modelWidth}x$_modelHeight',
            category: LogCategory.ui,
            tags: ['illustration', 'load', 'success'],
          );
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
          _images = [];
        });
      }
      LoggerService.instance.e(
        '从后端加载插图失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ui,
        tags: ['illustration', 'load', 'error'],
      );
    }
  }

  /// 刷新插图
  Future<void> _refreshIllustration() async {
    LoggerService.instance.d(
      '用户点击刷新按钮，taskId: ${widget.taskId}',
      category: LogCategory.ui,
      tags: ['illustration', 'refresh'],
    );
    await _loadIllustrationFromBackend();
  }

  // ========================================================================
  // 宽高比计算
  // ========================================================================

  /// 检查图片是否正在生成视频
  bool isImageGenerating(String imageUrl) {
    return VideoGenerationStateManager.isImageGenerating(imageUrl);
  }

  /// 计算宽高比
  ///
  /// 优先级：
  /// 1. 从 API 获取的模型宽高（`_modelWidth`, `_modelHeight`）
  /// 2. widget 参数提供的宽高（`widget.modelWidth`, `widget.modelHeight`）
  /// 3. 默认比例 0.5（高是宽的2倍）
  double _calculateAspectRatio() {
    // 优先使用从 API 获取的模型宽高
    if (_modelWidth != null &&
        _modelHeight != null &&
        _modelWidth! > 0 &&
        _modelHeight! > 0) {
      return _modelWidth! / _modelHeight!;
    }

    // 其次使用 widget 参数提供的宽高（向后兼容）
    if (widget.modelWidth != null &&
        widget.modelHeight != null &&
        widget.modelWidth! > 0 &&
        widget.modelHeight! > 0) {
      return widget.modelWidth! / widget.modelHeight!;
    }

    // fallback: 使用默认1:2比例 (高是宽的2倍)
    return 0.5;
  }

  // ========================================================================
  // UI 构建
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    // 优先使用 taskId 的服务端优先模式
    if (widget.taskId != null) {
      if (_isLoading) {
        return _buildLoadingWidget();
      }

      if (_hasError) {
        return _buildErrorWidget();
      }

      if (_images.isEmpty) {
        return _buildPendingWidget(); // 插图生成中
      }

      return _buildImageGalleryFromBackend(_images);
    }

    // 向后兼容模式（如果有 illustration 参数）
    if (widget.illustration != null) {
      return _buildLegacyIllustration(widget.illustration!);
    }

    // 既没有 taskId 也没有 illustration 的错误情况
    return _buildErrorWidget(message: '缺少插图标识信息');
  }

  /// 构建加载状态
  Widget _buildLoadingWidget() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double containerWidth = constraints.maxWidth;
        final double containerHeight = containerWidth / _calculateAspectRatio();

        return Container(
          height: containerHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LoadingStateWidget(
                message: '图片生成中...',
                centered: false,
              ),
              const SizedBox(height: 12),
              const Text(
                '预计需要1-3分钟',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.onDelete != null) ...[
                    OutlinedButton.icon(
                      onPressed: () => widget.onDelete!(widget.taskId!),
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('删除'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  TextButton.icon(
                    onPressed: _refreshIllustration,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('刷新'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建错误状态
  Widget _buildErrorWidget({String? message}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double containerWidth = constraints.maxWidth;
        final double containerHeight =
            (containerWidth / _calculateAspectRatio())
                .clamp(120.0, 200.0); // 错误状态限制最小最大高度

        return Container(
          height: containerHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color:
                    Theme.of(context).colorScheme.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ErrorStateWidget(
                message: message ?? '插图加载失败',
                icon: Icons.error_outline,
                onRetry: _refreshIllustration,
                retryText: '重试',
                centered: false,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .error
                        .withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (widget.onDelete != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => widget.onDelete!(widget.taskId!),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('删除'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 构建等待中状态（服务端优先）
  Widget _buildPendingWidget() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double containerWidth = constraints.maxWidth;
        final double containerHeight = containerWidth / _calculateAspectRatio();

        return Container(
          height: containerHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.12)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image,
                  size: 48,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.6),
                ),
                const SizedBox(height: 12),
                const Text(
                  '插图生成中...',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI正在创作图片，请耐心等待',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.onDelete != null) ...[
                      OutlinedButton.icon(
                        onPressed: () => widget.onDelete!(widget.taskId!),
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('删除'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton.icon(
                      onPressed: _refreshIllustration,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('检查状态'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建基于后端数据的图片画廊
  Widget _buildImageGalleryFromBackend(List<String> images) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 图片计数标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Text(
            '${images.length} 张图片',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // 图片容器（自适应高度）
        Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: GestureDetector(
            onTap: () {
              if (widget.onImageTap != null &&
                  widget.taskId != null &&
                  _images.isNotEmpty) {
                // 传递当前显示图片的信息
                final currentImageUrl = _images[_currentIndex];
                widget.onImageTap!(
                    widget.taskId!, currentImageUrl, _currentIndex);
              } else if (widget.onImageTap == null) {
                _showGenerateMoreDialog();
              }
            },
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8)),
              child: _buildImagePageView(images),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 操作按钮
        Row(
          children: [
            if (widget.onDelete != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => widget.onDelete!(widget.taskId!),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('删除'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _refreshIllustration,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('刷新'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建图片滑动视图（自适应高度）
  Widget _buildImagePageView(List<String> images) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double containerWidth = constraints.maxWidth;
        final double containerHeight = containerWidth / _calculateAspectRatio();

        if (images.isEmpty) {
          return SizedBox(
            height: containerHeight,
            child: const Center(
              child: Text('没有图片'),
            ),
          );
        }

        return Column(
          children: [
            // 页面指示器
            _buildPageIndicator(_currentIndex, images.length),
            // 图片滑动视图 - 动态高度为宽度的2倍
            Container(
              height: containerHeight,
              decoration: BoxDecoration(
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.12)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: PageView.builder(
                itemCount: images.length,
                // 启用平台特定的隐式滚动优化
                allowImplicitScrolling: true,
                onPageChanged: (index) {
                  if (mounted) {
                    setState(() {
                      _currentIndex = index;
                    });
                  }
                },
                itemBuilder: (context, index) {
                  // 使用 RepaintBoundary 隔离重绘，提升性能
                  return RepaintBoundary(
                    child: _buildPageImage(images[index], containerHeight),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建单个页面图片
  Widget _buildPageImage(String imageUrl, double containerHeight) {
    // 从imageUrl中提取文件名
    final fileName = imageUrl.split('/').last;
    // 获取当前图片的模型名称
    final modelName = _imageModels[_currentIndex];

    return Stack(
      children: [
        // 使用混合媒体组件，自动切换显示图片或视频
        Container(
          height: containerHeight, // 使用动态高度
          decoration: BoxDecoration(
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: HybridMediaWidget(
              key: ValueKey(fileName), // 添加唯一 key，确保 Flutter 可以正确识别和复用
              imageUrl: imageUrl,
              imgName: fileName,
              height: containerHeight,
              fit: BoxFit.cover,
            ),
          ),
        ),

        // 左上角模型标签
        if (modelName != null && modelName.isNotEmpty)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                modelName,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.surface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

        // 右上角删除按钮
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _isDeleting && _deletingImage == imageUrl
                ? null
                : () => _deleteCurrentImage(imageUrl),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isDeleting && _deletingImage == imageUrl
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.error),
                      ),
                    )
                  : Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建页面指示器
  Widget _buildPageIndicator(int currentIndex, int total) {
    if (total <= 1) {
      // 单张图片时只显示计数，不显示箭头
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
        ),
        child: Text(
          '1 张图片',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // 多张图片时显示完整指示器
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 左箭头
          GestureDetector(
            onTap: currentIndex > 0
                ? () {
                    if (mounted) {
                      setState(() {
                        _currentIndex = currentIndex - 1;
                      });
                    }
                  }
                : null,
            child: Icon(
              Icons.keyboard_arrow_left,
              color: currentIndex > 0
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 16),
          // 页面信息
          Text(
            '${currentIndex + 1} / $total',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          // 右箭头
          GestureDetector(
            onTap: currentIndex < total - 1
                ? () {
                    if (mounted) {
                      setState(() {
                        _currentIndex = currentIndex + 1;
                      });
                    }
                  }
                : null,
            child: Icon(
              Icons.keyboard_arrow_right,
              color: currentIndex < total - 1
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // 操作处理
  // ========================================================================

  /// 显示生成更多图片对话框
  void _showGenerateMoreDialog() {
    if (widget.taskId == null) {
      ToastUtils.showInfo('无法获取任务ID');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => GenerateMoreDialog(
        apiType: 't2i', // 场景图片重新生成使用文生图模型
        onConfirm: (count, modelName) => _generateMoreImages(count, modelName),
      ),
    );
  }

  // ========================================================================
  // 向后兼容
  // ========================================================================

  /// 向后兼容的插图显示
  Widget _buildLegacyIllustration(SceneIllustration illustration) {
    if (illustration.images.isEmpty) {
      return _buildLoadingWidget();
    }
    return _buildImageGalleryFromBackend(illustration.images);
  }

  /// 生成更多图片
  Future<void> _generateMoreImages(int count, String? modelName) async {
    if (widget.taskId == null) return;

    try {
      // 显示加载提示
      ToastUtils.showInfo('正在生成更多图片，请稍候...');

      // 使用ApiServiceWrapper确保正确的token认证
      final apiService = ref.read(apiServiceWrapperProvider);

      // 调用API服务包装器的方法，自动处理token认证
      await apiService.regenerateSceneIllustrationImages(
        taskId: widget.taskId!,
        count: count,
        modelName: modelName,
      );

      // 刷新图片列表
      await _loadIllustrationFromBackend();

      if (mounted) {
        ToastUtils.showSuccess('图片生成完成');
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '生成更多图片失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['illustration', 'regenerate', 'error'],
      );

      if (mounted) {
        ErrorHelper.showErrorWithLog(
          context,
          '生成图片失败',
          stackTrace: stackTrace,
          category: LogCategory.ai,
          tags: ['image', 'regenerate', 'failed'],
        );
      }
    }
  }

  /// 删除单张图片
  Future<void> _deleteCurrentImage(String imageUrl) async {
    if (_isDeleting || widget.taskId == null) return;

    // 连击保护：2秒内不允许重复删除同一张图片
    final now = DateTime.now();
    if (_lastDeleteTime != null &&
        now.difference(_lastDeleteTime!).inSeconds < 2 &&
        _deletingImage == imageUrl) {
      LoggerService.instance.d(
        '连击保护：2秒内不允许重复删除同一张图片',
        category: LogCategory.ui,
        tags: ['illustration', 'delete', 'protection'],
      );
      return;
    }

    setState(() {
      _isDeleting = true;
      _deletingImage = imageUrl;
      _lastDeleteTime = now;
    });

    try {
      final apiService = ApiServiceWrapper();

      // 调用删除API
      await apiService.deleteSceneIllustrationImage(
        taskId: widget.taskId!,
        filename: imageUrl,
      );

      // 删除成功后，清除图片缓存
      ImageCacheManager.removeCache(imageUrl);
      LoggerService.instance.d(
        '已删除图片缓存: $imageUrl',
        category: LogCategory.ui,
        tags: ['illustration', 'delete', 'cache'],
      );

      // 删除成功，更新图片列表
      if (mounted) {
        setState(() {
          _images.remove(imageUrl);

          // 如果当前索引超出范围，调整索引
          if (_currentIndex >= _images.length && _images.isNotEmpty) {
            _currentIndex = _images.length - 1;
          }
        });

        // 显示成功提示
        ToastUtils.showSuccess('图片删除成功');

        // 调用删除成功回调，让父组件处理后续逻辑
        widget.onImageDeleted?.call();

        // 如果所有图片都被删除了，调用刷新方法重新加载
        if (_images.isEmpty) {
          await _loadIllustrationFromBackend();
        }
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '删除图片失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ui,
        tags: ['illustration', 'delete', 'error'],
      );

      if (mounted) {
        ErrorHelper.showErrorWithLog(
          context,
          '删除图片失败',
          stackTrace: stackTrace,
          category: LogCategory.ai,
          tags: ['image', 'delete', 'failed'],
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _deletingImage = null;
        });
      }
    }
  }
}
