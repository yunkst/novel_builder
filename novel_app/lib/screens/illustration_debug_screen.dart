import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scene_illustration.dart';
import '../widgets/illustration_request_dialog.dart';
import '../widgets/illustration_action_dialog.dart';
import '../widgets/scene_image_preview.dart';
import '../widgets/video_input_dialog.dart';
import '../widgets/generate_more_dialog.dart';
import '../widgets/common/common_widgets.dart';
import '../core/providers/service_providers.dart';
import '../core/providers/database_providers.dart';
import '../utils/toast_utils.dart';
import '../utils/video_generation_state_manager.dart';
import '../controllers/pagination_controller.dart';
import 'package:novel_api/novel_api.dart';

/// 场景插图调试屏幕 - Riverpod 版本
class IllustrationDebugScreen extends ConsumerStatefulWidget {
  const IllustrationDebugScreen({super.key});

  @override
  ConsumerState<IllustrationDebugScreen> createState() =>
      _IllustrationDebugScreenState();
}

class _IllustrationDebugScreenState
    extends ConsumerState<IllustrationDebugScreen> {
  late final PaginationController<SceneIllustration> _pagination;
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 10; // 每页10条

  @override
  void initState() {
    super.initState();

    _pagination = PaginationController<SceneIllustration>(
      fetchPage: (page, pageSize) async {
        final databaseService = ref.read(databaseServiceProvider);
        final result = await databaseService.getSceneIllustrationsPaginated(
          page: page - 1, // PaginationController页码从1开始，API从0开始
          limit: pageSize,
        );
        _pagination.setTotalItems(result['total'] as int);
        return result['items'] as List<SceneIllustration>;
      },
      pageSize: _pageSize,
      initialPage: 1,
    );
    _pagination.refresh();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pagination.dispose();
    super.dispose();
  }

  /// 公开方法：刷新列表数据（供外部调用）
  void refreshData() {
    _pagination.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('生图调试'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: AnimatedBuilder(
        animation: _pagination,
        builder: (context, child) {
          return RefreshIndicator(
            onRefresh: () => _pagination.refresh(),
            child: Column(
              children: [
                Expanded(
                  child: _pagination.isEmpty && !_pagination.isLoading
                      ? _buildEmptyState()
                      : _buildIllustrationList(),
                ),
                _buildPaginationControl(),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80), // 向上移动，避免遮挡翻页按钮
        child: FloatingActionButton(
          heroTag: 'illustration_debug_fab',
          onPressed: _showIllustrationRequestDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无生成的图片',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '点击右下角的 + 号开始生成',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          // 添加刷新按钮
          ElevatedButton.icon(
            onPressed:
                _pagination.isLoading ? null : () => _pagination.refresh(),
            icon: _pagination.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            label: Text(_pagination.isLoading ? '刷新中...' : '刷新列表'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustrationList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _pagination.items.length,
      itemBuilder: (context, index) {
        final illustration = _pagination.items[index];
        return _buildIllustrationCard(illustration, index);
      },
      // 性能优化：添加cacheExtent和addAutomaticKeepAlives
      cacheExtent: 500,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      addSemanticIndexes: false,
    );
  }

  /// 构建底部页码控制组件
  Widget _buildPaginationControl() {
    if (_pagination.totalPages == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 页码信息
          Text(
            '第 ${_pagination.currentPage}/${_pagination.totalPages} 页',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
          if (_pagination.totalItems != null &&
              _pagination.totalItems! > 0) ...[
            const SizedBox(width: 8),
            Text(
              '（共 ${_pagination.totalItems} 条）',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
          const SizedBox(width: 16),
          // 上一页按钮
          ElevatedButton(
            onPressed: _pagination.currentPage > 1 && !_pagination.isLoading
                ? _goToPreviousPage
                : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 36),
              disabledBackgroundColor: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            child: const Text('上一页'),
          ),
          const SizedBox(width: 12),
          // 下一页按钮
          ElevatedButton(
            onPressed: _pagination.currentPage < _pagination.totalPages &&
                    !_pagination.isLoading
                ? _goToNextPage
                : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 36),
              disabledBackgroundColor: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            child: const Text('下一页'),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustrationCard(SceneIllustration illustration, int index) {
    // 直接使用 SceneImagePreview 组件，复用阅读器的实现
    return Card(
      key: ValueKey('illustration_${illustration.id}_${illustration.status}'),
      margin: const EdgeInsets.only(bottom: 16),
      child: SceneImagePreview(
        taskId: illustration.taskId,
        onImageTap: (taskId, imageUrl, imageIndex) {
          _handleImageTap(taskId, imageUrl, imageIndex);
        },
        onDelete: (taskId) => _deleteIllustration(illustration.id),
        onImageDeleted: () {
          // 删除成功后刷新列表
          _pagination.refresh();
        },
      ),
    );
  }

  Future<void> _showIllustrationRequestDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const IllustrationRequestDialog(),
    );

    if (result != null) {
      // 保留创建调试任务的功能，但现在它会直接保存到数据库
      await _createDebugIllustration(result);
    }
  }

  Future<void> _createDebugIllustration(
      Map<String, dynamic> requestData) async {
    try {
      final sceneIllustrationService =
          ref.read(sceneIllustrationServiceProvider);

      final prompt = requestData['prompt'] as String;
      final imageCount = requestData['imageCount'] as int;
      final modelName = requestData['modelName'] as String?;

      // 创建空的角色列表，调试模式下不需要角色信息
      final List<RoleInfo> emptyRoles = [];

      // 调用SceneIllustrationService的API，调试模式跳过章节内容修改
      await sceneIllustrationService.createSceneIllustrationWithMarkup(
        novelUrl: 'debug_novel_url', // 调试用的小说URL
        chapterId: 'debug_chapter_id', // 调试用的章节ID
        paragraphText: prompt, // 使用prompt作为段落文本
        roles: emptyRoles, // 空角色列表
        imageCount: imageCount,
        modelName: modelName, // 生图模型
        insertionPosition: 'after', // 插入位置
        paragraphIndex: 0, // 段落索引
        skipMarkupInsertion: true, // 🔧 调试模式：跳过章节内容修改
      );

      // 刷新列表以显示新创建的任务
      await _pagination.refresh();

      ToastUtils.showSuccess('调试任务已创建');
    } catch (e) {
      debugPrint('创建调试生图请求失败: $e');
      ToastUtils.showError('创建生图请求失败: $e');
    }
  }

  Future<void> _goToPreviousPage() async {
    if (_pagination.currentPage > 1) {
      await _pagination.loadPage(_pagination.currentPage - 1, replace: true);
    }
  }

  Future<void> _goToNextPage() async {
    if (_pagination.currentPage < _pagination.totalPages) {
      await _pagination.loadPage(_pagination.currentPage + 1, replace: true);
    }
  }

  void _showErrorSnackBar(String message, {bool isSuccess = false}) {
    if (isSuccess) {
      ToastUtils.showSuccess(message);
    } else {
      ToastUtils.showError(message);
    }
  }

  /// 处理图片点击事件 - 显示功能选择对话框
  Future<void> _handleImageTap(
      String taskId, String imageUrl, int imageIndex) async {
    // 从已有列表中查找插图信息（使用用户输入的场景描述）
    String? prompts;
    try {
      final illustration =
          _pagination.items.cast<SceneIllustration?>().firstWhere(
                (ill) => ill?.taskId == taskId,
                orElse: () => null,
              );
      prompts = illustration?.content;
    } catch (e) {
      debugPrint('获取插图信息失败: $e');
      prompts = null;
    }

    // 显示功能选择对话框（传入 prompts）
    if (!mounted) return;
    final action = await IllustrationActionDialog.show(
      context,
      prompts: prompts,
    );

    if (action == null || !mounted) {
      return; // 用户取消或widget已销毁
    }

    if (action == 'regenerate') {
      // 用户选择"再来几张"
      await _regenerateMoreImages(taskId);
    } else if (action == 'video') {
      // 用户选择"生成视频"
      await _generateVideoFromSpecificImage(taskId, imageUrl, imageIndex);
    }
  }

  /// 再来几张 - 重新生成更多图片
  Future<void> _regenerateMoreImages(String taskId) async {
    debugPrint('=== IllustrationDebugScreen._regenerateMoreImages 开始 ===');
    debugPrint('taskId: $taskId');

    try {
      // 显示数量选择对话框
      if (!mounted) {
        debugPrint('❌ widget已销毁，取消操作');
        return;
      }

      debugPrint('🔄 显示 GenerateMoreDialog...');
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => GenerateMoreDialog(
          apiType: 't2i', // 文生图模型
          onConfirm: (count, modelName) {
            debugPrint(
                'GenerateMoreDialog onConfirm 回调被触发: count=$count, model=$modelName');
            Navigator.of(context).pop({
              'count': count,
              'modelName': modelName,
            });
          },
        ),
      );

      if (result == null || !mounted) {
        debugPrint('用户取消或widget已销毁');
        return;
      }

      final count = result['count'] as int;
      final modelName = result['modelName'] as String?;
      debugPrint('✅ 用户选择: count=$count, model=$modelName');

      // 显示加载提示
      if (mounted) {
        debugPrint('📢 显示加载提示');
        ToastUtils.showSuccess('正在生成 $count 张图片...');
      }

      // 调用 API 生成图片
      debugPrint('🔄 准备调用 API: regenerateSceneIllustrationImages');
      final apiService = ref.read(apiServiceWrapperProvider);
      debugPrint('✅ ApiServiceWrapper 实例已获取');

      debugPrint('🔄 开始API调用...');
      final response = await apiService.regenerateSceneIllustrationImages(
        taskId: taskId,
        count: count,
        modelName: modelName,
      );

      debugPrint('✅ API调用成功');
      debugPrint('响应: $response');

      // 显示成功提示（不刷新列表）
      if (mounted) {
        debugPrint('📢 显示成功提示');
        _showErrorSnackBar('图片生成任务已创建，预计需要1-3分钟', isSuccess: true);
      }
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ _regenerateMoreImages 异常 ❌❌❌');
      debugPrint('异常类型: ${e.runtimeType}');
      debugPrint('异常信息: $e');
      debugPrint('堆栈跟踪:\n$stackTrace');

      if (mounted) {
        debugPrint('📢 显示错误提示');
        _showErrorSnackBar('生成图片失败: $e');
      }
    }

    debugPrint('=== _regenerateMoreImages 结束 ===');
  }

  /// 为特定图片生成视频
  Future<void> _generateVideoFromSpecificImage(
      String taskId, String imageUrl, int imageIndex) async {
    try {
      // 检查图片是否正在生成视频
      if (VideoGenerationStateManager.isImageGenerating(imageUrl)) {
        if (mounted) {
          ToastUtils.showWarning('该图片正在生成视频，请稍后再试');
        }
        return;
      }

      // 从imageUrl中提取文件名
      final fileName = imageUrl.split('/').last;

      // 显示视频输入对话框
      if (!mounted) return;
      final videoInput = await VideoInputDialog.show(context);
      if (videoInput == null || !mounted) {
        return; // 用户取消或widget已销毁
      }

      final userInput = videoInput['user_input'] ?? '';

      if (userInput.isEmpty) {
        return; // 未输入内容
      }

      // 设置生成状态
      _setImageGeneratingStatus(imageUrl, true);

      // 显示加载提示
      if (mounted) {
        ToastUtils.showInfo('正在为选中图片创建视频生成任务...');
      }

      // 调用API生成视频
      final apiService = ref.read(apiServiceWrapperProvider);
      final response = await apiService.generateVideoFromImage(
        imgName: fileName,
        userInput: userInput,
        modelName: '', // 使用空字符串
      );

      // 清除生成状态
      _setImageGeneratingStatus(imageUrl, false);

      if (mounted) {
        ToastUtils.showSuccess('视频生成任务已创建，任务ID: ${response.taskId}');
      }
    } catch (e) {
      // 清除生成状态
      _setImageGeneratingStatus(imageUrl, false);

      if (mounted) {
        ToastUtils.showError('生成视频失败: $e');
      }
    }
  }

  /// 设置图片生成状态
  void _setImageGeneratingStatus(String imageUrl, bool isGenerating) {
    VideoGenerationStateManager.setImageGenerating(imageUrl, isGenerating);
  }

  /// 删除插图
  Future<void> _deleteIllustration(int illustrationId) async {
    try {
      final confirmed = await ConfirmDialog.show(
        context,
        title: '确认删除',
        message: '确定要删除这个插图吗？此操作无法撤销。',
        confirmText: '删除',
        icon: Icons.delete,
      );

      if (confirmed == true) {
        final sceneIllustrationService =
            ref.read(sceneIllustrationServiceProvider);
        final success =
            await sceneIllustrationService.deleteIllustration(illustrationId);
        if (success) {
          // 删除成功后刷新列表，让被删除的项立即消失
          await _pagination.refresh();

          if (mounted) {
            ToastUtils.showSuccess('插图已删除');
          }
        } else {
          debugPrint('删除插图失败: 服务返回false');
          if (mounted) {
            ToastUtils.showError('删除插图失败');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('删除插图失败: $e');
      }
    }
  }
}
