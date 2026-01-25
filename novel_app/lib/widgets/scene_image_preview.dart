import 'package:flutter/material.dart';
import '../models/scene_illustration.dart';
import '../services/api_service_wrapper.dart';
import '../core/di/api_service_provider.dart';
import '../utils/video_generation_state_manager.dart';
import '../utils/image_cache_manager.dart';
import 'hybrid_media_widget.dart';
import 'generate_more_dialog.dart';

class SceneImagePreview extends StatefulWidget {
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
  State<SceneImagePreview> createState() => _SceneImagePreviewState();
}

class _SceneImagePreviewState extends State<SceneImagePreview> {
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  List<String> _images = [];  // 图片URL列表
  Map<int, String?> _imageModels = {};  // 索引 -> 模型名映射
  int _currentIndex = 0; // 当前页面索引

  // 删除相关状态
  bool _isDeleting = false;
  String? _deletingImage; // 正在删除的图片filename
  DateTime? _lastDeleteTime; // 最后删除时间，用于连击保护

  // 模型宽高信息
  int? _modelWidth;
  int? _modelHeight;

  /// 检查图片是否正在生成视频
  bool isImageGenerating(String imageUrl) {
    return VideoGenerationStateManager.isImageGenerating(imageUrl);
  }

  /// 计算宽高比
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

          debugPrint(
              '✅ 加载插图信息: ${_images.length} 张图片, 模型尺寸: ${_modelWidth}x$_modelHeight');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
          _images = [];
        });
      }
      debugPrint('从后端加载插图失败: $e');
    }
  }

  Future<void> _refreshIllustration() async {
    debugPrint('用户点击刷新按钮，taskId: ${widget.taskId}');
    await _loadIllustrationFromBackend();
  }

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
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '图片生成中...',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
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
                          foregroundColor: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    TextButton.icon(
                      onPressed: _refreshIllustration,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('刷新'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
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
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 32, color: Colors.red.shade400),
                const SizedBox(height: 8),
                Text(
                  message ?? '插图加载失败',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.onDelete != null) ...[
                      OutlinedButton.icon(
                        onPressed: () => widget.onDelete!(widget.taskId!),
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('删除'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    TextButton.icon(
                      onPressed: _refreshIllustration,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('重试'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
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

  /// 构建等待中状态（服务端优先）
  Widget _buildPendingWidget() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double containerWidth = constraints.maxWidth;
        final double containerHeight = containerWidth / _calculateAspectRatio();

        return Container(
          height: containerHeight,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image,
                  size: 48,
                  color: Colors.blue.shade300,
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
                    color: Colors.grey.shade600,
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
                          foregroundColor: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton.icon(
                      onPressed: _refreshIllustration,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('检查状态'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
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
            border: Border.all(color: Colors.grey.shade300),
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
                    foregroundColor: Colors.red,
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
                  foregroundColor: Colors.white,
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
                border: Border.all(color: Colors.grey.shade300),
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
            border: Border.all(color: Colors.grey.shade300),
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
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                modelName,
                style: const TextStyle(
                  color: Colors.white,
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
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    )
                  : Icon(
                      Icons.delete,
                      color: Colors.red,
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
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
        ),
        child: Text(
          '1 张图片',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // 多张图片时显示完整指示器
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
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
                  ? Theme.of(context).primaryColor
                  : Colors.grey,
            ),
          ),
          const SizedBox(width: 16),
          // 页面信息
          Text(
            '${currentIndex + 1} / $total',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
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
                  ? Theme.of(context).primaryColor
                  : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示生成更多图片对话框
  void _showGenerateMoreDialog() {
    if (widget.taskId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法获取任务ID')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在生成更多图片，请稍候...'),
          duration: Duration(seconds: 3),
        ),
      );

      // 使用ApiServiceWrapper确保正确的token认证
      final apiService = ApiServiceProvider.instance;

      // 调用API服务包装器的方法，自动处理token认证
      await apiService.regenerateSceneIllustrationImages(
        taskId: widget.taskId!,
        count: count,
        modelName: modelName,
      );

      // 刷新图片列表
      await _loadIllustrationFromBackend();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('图片生成完成'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('生成更多图片失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('生成图片失败: $e'),
            backgroundColor: Colors.red,
          ),
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
      debugPrint('连击保护：2秒内不允许重复删除同一张图片');
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
      debugPrint('🗑️ 已删除图片缓存: $imageUrl');

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('图片删除成功'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // 调用删除成功回调，让父组件处理后续逻辑
        widget.onImageDeleted?.call();

        // 如果所有图片都被删除了，调用刷新方法重新加载
        if (_images.isEmpty) {
          await _loadIllustrationFromBackend();
        }
      }
    } catch (e) {
      debugPrint('删除图片失败: $e');

      if (mounted) {
        // 显示错误提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除图片失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
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
