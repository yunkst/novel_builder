import 'package:flutter/material.dart';
import 'dart:async';
import '../models/scene_illustration.dart';
import '../widgets/illustration_request_dialog.dart';
import '../widgets/illustration_action_dialog.dart';
import '../widgets/scene_image_preview.dart';
import '../widgets/video_input_dialog.dart';
import '../widgets/generate_more_dialog.dart';
import '../services/scene_illustration_service.dart';
import '../services/database_service.dart';
import '../services/api_service_wrapper.dart';
import '../core/di/api_service_provider.dart';
import '../utils/video_generation_state_manager.dart';
import 'package:novel_api/novel_api.dart';

class IllustrationDebugScreen extends StatefulWidget {
  const IllustrationDebugScreen({super.key});

  @override
  State<IllustrationDebugScreen> createState() => _IllustrationDebugScreenState();
}

class _IllustrationDebugScreenState extends State<IllustrationDebugScreen> {
  final List<SceneIllustration> _sceneIllustrations = [];
  final SceneIllustrationService _sceneIllustrationService = SceneIllustrationService();
  final DatabaseService _databaseService = DatabaseService();

  // 分页状态
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  int _totalPages = 0; // 总页数
  int _totalItems = 0; // 总条目数
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 10; // 每页10条

  // 性能优化：防止重复请求
  DateTime _lastLoadTime = DateTime.now();
  static const Duration _minLoadInterval = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _loadIllustrations();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('生图调试'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshIllustrations,
        child: Column(
          children: [
            Expanded(
              child: _sceneIllustrations.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : _buildIllustrationList(),
            ),
            _buildPaginationControl(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'illustration_debug_fab',
        onPressed: _showIllustrationRequestDialog,
        child: const Icon(Icons.add),
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
            onPressed: _isLoading ? null : () => _refreshIllustrations(),
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            label: Text(_isLoading ? '刷新中...' : '刷新列表'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
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
      itemCount: _sceneIllustrations.length,
      itemBuilder: (context, index) {
        final illustration = _sceneIllustrations[index];
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
    if (_totalPages == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 页码信息
          Text(
            '第 ${_currentPage + 1}/$_totalPages 页',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          if (_totalItems > 0) ...[
            const SizedBox(width: 8),
            Text(
              '（共 $_totalItems 条）',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(width: 16),
          // 上一页按钮
          ElevatedButton(
            onPressed: _currentPage > 0 && !_isLoading
                ? _goToPreviousPage
                : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 36),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: const Text('上一页'),
          ),
          const SizedBox(width: 12),
          // 下一页按钮
          ElevatedButton(
            onPressed: _currentPage < _totalPages - 1 && !_isLoading
                ? _goToNextPage
                : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 36),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: const Text('下一页'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(),
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
        onDelete: () => _deleteIllustration(illustration.id),
        onImageDeleted: () {
          // 删除成功后刷新列表
          _refreshIllustrations();
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

  Future<void> _createDebugIllustration(Map<String, dynamic> requestData) async {
    try {
      final prompt = requestData['prompt'] as String;
      final imageCount = requestData['imageCount'] as int;
      final modelName = requestData['modelName'] as String?;

      // 创建空的角色列表，调试模式下不需要角色信息
      final List<RoleInfo> emptyRoles = [];

      // 调用SceneIllustrationService的API，这会自动保存到数据库
      await _sceneIllustrationService.createSceneIllustrationWithMarkup(
        novelUrl: 'debug_novel_url', // 调试用的小说URL
        chapterId: 'debug_chapter_id', // 调试用的章节ID
        paragraphText: prompt, // 使用prompt作为段落文本
        roles: emptyRoles, // 空角色列表
        imageCount: imageCount,
        modelName: modelName, // 生图模型
        insertionPosition: 'after', // 插入位置
        paragraphIndex: 0, // 段落索引
      );

      // 刷新列表以显示新创建的任务
      await _refreshIllustrations();

      _showErrorSnackBar('调试任务已创建', isSuccess: true);

    } catch (e) {
      debugPrint('创建调试生图请求失败: $e');
      _showErrorSnackBar('创建生图请求失败: $e');
    }
  }

  
  
  // 分页加载核心方法
  Future<void> _loadIllustrations({bool isRefresh = false}) async {
    // 性能优化：防止重复请求
    final now = DateTime.now();
    if (_isLoading || !isRefresh && now.difference(_lastLoadTime) < _minLoadInterval) {
      return;
    }
    _lastLoadTime = now;

    setState(() {
      _isLoading = true;
      if (isRefresh) {
        _currentPage = 0;
        _hasMore = true;
        _sceneIllustrations.clear();
      }
    });

    try {
      final result = await _databaseService.getSceneIllustrationsPaginated(
        page: _currentPage,
        limit: _pageSize,
      );

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _sceneIllustrations.clear();
          }
          _sceneIllustrations.addAll(result['items'] as List<SceneIllustration>);
          _totalItems = result['total'] as int;
          _totalPages = result['totalPages'] as int;
          _hasMore = _currentPage < _totalPages - 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('加载插图失败: $e');
      if (mounted) {
        _showErrorSnackBar('加载数据失败: $e');
      }
    }
  }

  /// 刷新插图列表（公开方法，供外部调用）
  Future<void> refreshData() async {
    await _loadIllustrations(isRefresh: true);
  }

  Future<void> _refreshIllustrations() async {
    await _loadIllustrations(isRefresh: true);
  }

  /// 手动翻页方法
  Future<void> _goToPage(int page) async {
    if (page < 0 || page >= _totalPages) return;
    if (_isLoading) return;

    setState(() {
      _currentPage = page;
    });

    await _loadIllustrations();
  }

  Future<void> _goToPreviousPage() async {
    if (_currentPage > 0) {
      await _goToPage(_currentPage - 1);
    }
  }

  Future<void> _goToNextPage() async {
    if (_currentPage < _totalPages - 1) {
      await _goToPage(_currentPage + 1);
    }
  }

  void _showErrorSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  /// 处理图片点击事件 - 显示功能选择对话框
  Future<void> _handleImageTap(String taskId, String imageUrl, int imageIndex) async {
    // 显示功能选择对话框
    if (!mounted) return;
    final action = await IllustrationActionDialog.show(context);

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
            debugPrint('GenerateMoreDialog onConfirm 回调被触发: count=$count, model=$modelName');
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
        _showErrorSnackBar('正在生成 $count 张图片...', isSuccess: true);
      }

      // 调用 API 生成图片
      debugPrint('🔄 准备调用 API: regenerateSceneIllustrationImages');
      debugPrint('ApiServiceWrapper 初始化状态检查...');
      final apiService = ApiServiceWrapper();
      debugPrint('✅ ApiServiceWrapper 实例已创建');
      debugPrint('初始化状态: ${apiService.getInitStatus()}');

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
  Future<void> _generateVideoFromSpecificImage(String taskId, String imageUrl, int imageIndex) async {
    try {
      // 检查图片是否正在生成视频
      if (VideoGenerationStateManager.isImageGenerating(imageUrl)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('该图片正在生成视频，请稍后再试'),
              backgroundColor: Colors.orange,
            ),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在为选中图片创建视频生成任务...'),
            backgroundColor: Colors.blue,
          ),
        );
      }

      // 获取 API 服务实例
      final apiService = ApiServiceProvider.instance;

      // 调用API生成视频
      final response = await apiService.generateVideoFromImage(
        imgName: fileName,
        userInput: userInput,
        modelName: '', // 使用空字符串
      );

      // 清除生成状态
      _setImageGeneratingStatus(imageUrl, false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('视频生成任务已创建，任务ID: ${response.taskId}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      // 清除生成状态
      _setImageGeneratingStatus(imageUrl, false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成视频失败: $e')),
        );
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
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认删除'),
          content: const Text('确定要删除这个插图吗？此操作无法撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final success = await _sceneIllustrationService.deleteIllustration(illustrationId);
        if (success) {
          // 删除成功后刷新列表，让被删除的项立即消失
          await _refreshIllustrations();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('插图已删除'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          debugPrint('删除插图失败: 服务返回false');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('删除插图失败'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除插图失败: $e')),
        );
      }
    }
  }
}