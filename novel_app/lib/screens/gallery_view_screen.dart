import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/role_gallery.dart';
import '../core/providers/service_providers.dart';
import '../utils/toast_utils.dart';
import '../widgets/api_image_widget.dart';
import '../widgets/gallery_action_panel.dart';
import '../services/image_crop_service.dart';

/// 图集浏览页面 - Riverpod 版本
class GalleryViewScreen extends ConsumerStatefulWidget {
  final String roleId;
  final String? roleName;

  const GalleryViewScreen({
    super.key,
    required this.roleId,
    this.roleName,
  });

  @override
  ConsumerState<GalleryViewScreen> createState() => _GalleryViewScreenState();
}

class _GalleryViewScreenState extends ConsumerState<GalleryViewScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;
  bool _showAppBar = true;
  int _currentIndex = 0;
  RoleGallery? _gallery;
  List<RoleImage> _sortedImages = [];
  bool _hasGalleryLoadError = false;

  @override
  void initState() {
    super.initState();

    _pageController = PageController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // 初始化缓存服务
    _initializeCacheService();
  }

  Future<void> _initializeCacheService() async {
    try {
      final cacheService = ref.read(roleGalleryCacheServiceProvider);
      final avatarSyncService = ref.read(characterAvatarSyncServiceProvider);

      await cacheService.init();
      await avatarSyncService.init();
      _loadGallery();
      _fadeController.forward();
    } catch (e) {
      debugPrint('❌ 缓存服务初始化失败: $e');
      // 即使缓存服务初始化失败，也要加载图集
      _loadGallery();
      _fadeController.forward();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadGallery() async {
    try {
      final apiService = ref.read(apiServiceWrapperProvider);
      final galleryData = await apiService.getRoleGallery(widget.roleId);

      setState(() {
        _gallery = RoleGallery.fromJson(galleryData);
        _sortedImages = _gallery!.sortedImages;
        _isLoading = false;
        _hasGalleryLoadError = false; // 重置错误状态
      });

      // 预加载前几张图片
      _preloadImages();

      debugPrint('✓ 图集加载成功: ${_sortedImages.length} 张图片');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasGalleryLoadError = true;
      });
      debugPrint('❌ 图集加载失败: $e');

      if (mounted) {
        _showErrorSnackBar('加载图集失败: $e', onRetry: _loadGallery);
      }
    }
  }

  Future<void> _preloadImages() async {
    if (_sortedImages.isEmpty) return;

    final cacheService = ref.read(roleGalleryCacheServiceProvider);
    final preloadFilenames = _sortedImages
        .take(3) // 预加载前3张
        .map((img) => img.filename)
        .toList();

    await cacheService.preloadImages(preloadFilenames);
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _toggleAppBar() {
    setState(() {
      _showAppBar = !_showAppBar;
    });
  }

  void _onImageTap() {
    _toggleAppBar();
  }

  Future<void> _refreshGallery() async {
    setState(() {
      _isLoading = true;
      _hasGalleryLoadError = false; // 重置错误状态
    });

    // 清除相关缓存
    final cacheService = ref.read(roleGalleryCacheServiceProvider);
    cacheService.clearMemoryCache();

    await _loadGallery();
  }

  Future<void> _onDeleteImage(RoleImage image) async {
    try {
      final cacheService = ref.read(roleGalleryCacheServiceProvider);
      final apiService = ref.read(apiServiceWrapperProvider);

      // 删除本地缓存
      await cacheService.deleteCachedImage(image.filename);

      // 调用后端删除接口
      final success = await apiService.deleteRoleImage(
        roleId: widget.roleId,
        imageUrl: image.filename,
      );

      if (success) {
        // 更新本地数据
        setState(() {
          _gallery = _gallery!.removeImage(image.filename);
          _sortedImages = _gallery!.sortedImages;

          // 调整页面索引
          if (_currentIndex >= _sortedImages.length &&
              _sortedImages.isNotEmpty) {
            _currentIndex = _sortedImages.length - 1;
            _pageController.animateToPage(
              _currentIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });

        if (mounted) {
          ToastUtils.showSuccess('图片删除成功');
        }
      }
    } catch (e) {
      debugPrint('❌ 删除图片失败: $e');
      if (mounted) {
        ToastUtils.showError('删除失败: $e');
      }
    }
  }

  Future<void> _onGenerateMoreImages(int count, String? modelName) async {
    try {
      final apiService = ref.read(apiServiceWrapperProvider);

      // 获取当前显示的图片作为参考图片
      final currentImage =
          _sortedImages.isNotEmpty ? _sortedImages[_currentIndex] : null;
      final referenceImageUrl = currentImage?.filename;

      debugPrint('🔄 生成更多图片，当前图片索引: $_currentIndex, 参考图片: $referenceImageUrl, 模型: $modelName');

      await apiService.generateMoreImages(
        roleId: widget.roleId,
        count: count,
        referenceImageUrl: referenceImageUrl,
        modelName: modelName,
      );

      if (mounted) {
        final isRegenerate =
            referenceImageUrl != null && referenceImageUrl.isNotEmpty;
        final message = isRegenerate
            ? '已提交 $count 张相似图片的生成请求，请等待1-3分钟'
            : '已提交 $count 张新图片的生成请求，请等待1-3分钟';

        showInfoWithAction(message, '查看详情', () {
          // 重新显示生成中对话框
          _showGeneratingDialog();
        });
      }

      // 显示生成中提示
      _showGeneratingDialog();
    } catch (e) {
      debugPrint('❌ 生成图片失败: $e');
      if (mounted) {
        ToastUtils.showError('生成失败: $e', context: context);
      }
    }
  }

  Future<void> _onSetAsAvatar(RoleImage image) async {
    try {
      final cacheService = ref.read(roleGalleryCacheServiceProvider);
      final avatarService = ref.read(characterAvatarServiceProvider);

      debugPrint('🎨 开始设置图片为头像: ${image.filename}');

      // 获取图片字节数据
      final imageBytes = await cacheService.getImageBytes(image.filename);
      if (imageBytes == null) {
        debugPrint('❌ 无法获取图片数据: ${image.filename}');
        if (mounted) {
          ToastUtils.showError('无法获取图片数据');
        }
        return;
      }

      // 安全解析角色ID
      int characterId;
      try {
        characterId = int.parse(widget.roleId);
      } catch (e) {
        debugPrint('❌ 角色ID解析失败: ${widget.roleId}, 错误: $e');
        if (mounted) {
          ToastUtils.showError('角色ID无效');
        }
        return;
      }

      // 创建临时目录和文件
      Directory? tempDir;
      File? tempFile;
      File? croppedFile;

      try {
        tempDir = await Directory.systemTemp.createTemp();
        final tempImagePath =
            '${tempDir.path}/temp_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        tempFile = File(tempImagePath);

        // 写入图片数据
        await tempFile.writeAsBytes(imageBytes);
        debugPrint('📁 临时图片保存: ${tempFile.path}');

        // 验证文件是否成功创建
        if (!await tempFile.exists()) {
          throw Exception('临时文件创建失败');
        }

        // 执行图片裁剪
        croppedFile = await ImageCropService.cropImageForAvatar(tempFile);
      } catch (e) {
        debugPrint('❌ 图片准备阶段失败: $e');
        if (mounted) {
          ToastUtils.showError('图片准备失败: $e');
        }
        // 清理资源
        await _cleanupTempFiles(tempDir, tempFile, null);
        return;
      }

      // 清理临时文件
      await _cleanupTempFiles(tempDir, tempFile, null);

      if (croppedFile == null) {
        debugPrint('ℹ️ 用户取消了图片裁剪');
        if (mounted) {
          ToastUtils.showInfo('已取消头像设置');
        }
        return;
      }

      try {
        // 直接读取裁剪后的图片文件
        final imageBytes = await croppedFile.readAsBytes();

        // 直接使用CharacterAvatarService设置头像
        final avatarPath = await avatarService.setAvatarFromGallery(
          characterId,
          imageBytes,
          'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        if (avatarPath != null) {
          debugPrint('✅ 图片裁剪并设置头像成功: ${image.filename} -> $avatarPath');

          if (mounted) {
            ToastUtils.showSuccess('头像设置成功');
          }
        } else {
          debugPrint('❌ 裁剪后的图片设置头像失败');
          if (mounted) {
            ToastUtils.showError('头像设置失败');
          }
        }
      } finally {
        // 清理裁剪后的临时文件
        try {
          if (await croppedFile.exists()) {
            await croppedFile.delete();
          }
        } catch (e) {
          debugPrint('⚠️ 清理裁剪文件失败: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ 设置头像失败: $e');
      if (mounted) {
        _showErrorSnackBar('设置头像失败: $e');
      }
    }
  }

  /// 清理临时文件的辅助方法
  Future<void> _cleanupTempFiles(
      Directory? tempDir, File? tempFile, File? additionalFile) async {
    try {
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
      if (additionalFile != null && await additionalFile.exists()) {
        await additionalFile.delete();
      }
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('⚠️ 清理临时文件失败: $e');
    }
  }

  /// 显示错误提示
  void _showErrorSnackBar(String message, {VoidCallback? onRetry}) {
    if (onRetry != null) {
      // 使用SnackBar显示带重试按钮的错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '重试',
            textColor: Theme.of(context).colorScheme.surface,
            onPressed: onRetry,
          ),
        ),
      );
    } else {
      ToastUtils.showError(message, context: context);
    }
  }

  /// 显示带操作的信息提示（用于查看生成详情）
  void showInfoWithAction(
      String message, String actionLabel, VoidCallback onAction) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: actionLabel,
          textColor: Theme.of(context).colorScheme.surface,
          onPressed: onAction,
        ),
      ),
    );
  }

  void _showGeneratingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 12),
            const Text('图片生成中'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '正在为您生成新的角色图片...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '预计等待时间：1-3分钟',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI图片生成需要一些时间，请耐心等待。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '建议',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '您可以先返回人物管理页面，\n等待几分钟后再来查看新生成的图片。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我了解了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          // 主要内容区域
          if (!_isLoading && _sortedImages.isNotEmpty)
            _buildImageViewer()
          else
            _buildLoadingView(),

          // 顶部操作栏
          if (!_isLoading && (_sortedImages.isNotEmpty || _hasGalleryLoadError))
            _buildTopBar(),

          // 底部操作面板
          if (!_isLoading && (_sortedImages.isNotEmpty || _hasGalleryLoadError))
            _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildImageViewer() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: GestureDetector(
            onTap: _onImageTap,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _sortedImages.length,
              itemBuilder: (context, index) {
                final image = _sortedImages[index];
                return _buildImagePage(image, index);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagePage(RoleImage image, int index) {
    final cacheService = ref.read(roleGalleryCacheServiceProvider);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      child: ApiImageWidget(
        imageUrl: image.filename,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        onRetry: () => _refreshGallery(),
        cacheService: cacheService, // 传递已初始化的缓存服务
      ),
    );
  }

  Widget _buildLoadingView() {
    if (_hasGalleryLoadError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Color(0xB3FFFFFF),
            ),
            const SizedBox(height: 16),
            const Text(
              '图集加载失败',
              style: TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请检查网络连接后重试',
              style: TextStyle(
                color: Color(0xB3FFFFFF),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshGallery,
              icon: const Icon(Icons.refresh),
              label: const Text('重试加载'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Theme.of(context).colorScheme.surface,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFFFFFFFF),
            strokeWidth: 2,
          ),
          const SizedBox(height: 16),
          Text(
            '加载图集中...',
            style: TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: _showAppBar ? 0 : -100,
      left: 0,
      right: 0,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              IconButton(
                onPressed: () =>
                    Navigator.of(context).pop(true), // 总是返回true以触发数据刷新
                icon:
                    const Icon(Icons.arrow_back_ios, color: Color(0xFFFFFFFF)),
              ),
              Expanded(
                child: Text(
                  widget.roleName ?? '角色图集',
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: _refreshGallery,
                icon: const Icon(Icons.refresh, color: Color(0xFFFFFFFF)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    // 如果图集加载出错，显示简化的操作面板
    if (_hasGalleryLoadError) {
      return _buildErrorActionPanel();
    }

    if (_sortedImages.isEmpty) return const SizedBox.shrink();

    final currentImage = _sortedImages[_currentIndex];
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GalleryActionPanel(
        currentImage: currentImage,
        currentIndex: _currentIndex,
        totalCount: _sortedImages.length,
        onDelete: () => _onDeleteImage(currentImage),
        onGenerateMore: (count, modelName) => _onGenerateMoreImages(count, modelName),
        onSetAsAvatar: () => _onSetAsAvatar(currentImage),
      ),
    );
  }

  /// 图集加载出错时的简化操作面板
  Widget _buildErrorActionPanel() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // 错误状态指示器
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '图集加载失败',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 删除按钮 - 在出错时仍然可用
                  _actionButton(
                    icon: Icons.delete_outline,
                    label: '删除图集',
                    onPressed: _handleErrorDelete,
                    color: Colors.red,
                  ),
                  // 重试按钮
                  _actionButton(
                    icon: Icons.refresh,
                    label: '重新加载',
                    onPressed: _refreshGallery,
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 处理图集加载出错时的删除操作
  Future<void> _handleErrorDelete() async {
    try {
      final cacheService = ref.read(roleGalleryCacheServiceProvider);

      // 由于图集加载失败，我们无法获取具体的图片信息
      // 这里只清除本地缓存，并尝试重新加载
      cacheService.clearMemoryCache();

      if (mounted) {
        ToastUtils.showInfo('缓存已清除，正在重新加载图集...');
      }

      // 重新加载图集
      await _loadGallery();
    } catch (e) {
      debugPrint('❌ 重新加载图集失败: $e');
      if (mounted) {
        ToastUtils.showError('重新加载失败，请稍后再试: $e');
      }
    }
  }

  /// 删除确认对话框已移除
  /// 现在点击删除按钮后直接调用删除接口，无需额外确认

  /// 操作按钮组件（简化版）
  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed != null ? 1.0 : 0.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
                border: Border.all(
                  color: color.withValues(alpha: 0.8),
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
