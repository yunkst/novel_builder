import 'package:flutter/material.dart';
import 'dart:async';
import '../models/illustration_debug_item.dart';
import '../models/scene_illustration.dart';
import '../widgets/illustration_request_dialog.dart';
import '../widgets/scene_illustration_image_widget.dart';
import '../services/scene_illustration_service.dart';
import '../services/database_service.dart';
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
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 20;

  // 性能优化：防止重复请求
  DateTime _lastLoadTime = DateTime.now();
  static const Duration _minLoadInterval = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _loadIllustrations();
    _scrollController.addListener(_scrollListener);
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
        child: _sceneIllustrations.isEmpty && !_isLoading
            ? _buildEmptyState()
            : _buildIllustrationList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showIllustrationRequestDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            '暂无生成的图片',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '点击右下角的 + 号开始生成',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
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
      itemCount: _sceneIllustrations.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _sceneIllustrations.length) {
          // 显示加载指示器
          return _buildLoadingIndicator();
        }

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

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildIllustrationCard(SceneIllustration illustration, int index) {
    // 性能优化：使用ValueKey确保卡片正确重建
    return Card(
      key: ValueKey('illustration_${illustration.id}_${illustration.status}'),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 请求信息和状态
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '生成数量: ${illustration.imageCount}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '创建时间: ${_formatDateTime(illustration.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (illustration.taskId.isNotEmpty)
                        Text(
                          '任务ID: ${illustration.taskId}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusChip(illustration.status),
              ],
            ),

            const SizedBox(height: 12),

            // 生成要求
            if (illustration.content.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  illustration.content,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 图片展示区域 - 复用SceneIllustrationImageWidget
            if (illustration.images.isNotEmpty)
              _buildImageGrid(illustration.images)
            else if (illustration.status == 'pending' || illustration.status == 'processing')
              _buildLoadingState()
            else if (illustration.status == 'failed')
              _buildErrorState(illustration),
          ],
        ),
      ),
    );
  }

  IllustrationStatus _mapStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return IllustrationStatus.pending;
      case 'processing':
        return IllustrationStatus.processing;
      case 'completed':
        return IllustrationStatus.completed;
      case 'failed':
        return IllustrationStatus.failed;
      default:
        return IllustrationStatus.pending;
    }
  }

  Widget _buildStatusChip(String status) {
    final illustrationStatus = _mapStatus(status);
    Color backgroundColor;
    String text;
    IconData icon;

    switch (illustrationStatus) {
      case IllustrationStatus.pending:
        backgroundColor = Colors.orange;
        text = '等待中';
        icon = Icons.schedule;
        break;
      case IllustrationStatus.processing:
        backgroundColor = Colors.blue;
        text = '生成中';
        icon = Icons.autorenew;
        break;
      case IllustrationStatus.completed:
        backgroundColor = Colors.green;
        text = '已完成';
        icon = Icons.check_circle;
        break;
      case IllustrationStatus.failed:
        backgroundColor = Colors.red;
        text = '失败';
        icon = Icons.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: backgroundColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: backgroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(List<String> imageUrls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '生成的图片:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.0,
          ),
          itemCount: imageUrls.length,
          // 性能优化：禁用不必要的特性
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
          addSemanticIndexes: false,
          itemBuilder: (context, index) {
            // 直接复用SceneIllustrationImageWidget组件
            return SceneIllustrationImageWidget(
              imageUrl: imageUrls[index],
              fit: BoxFit.cover,
              height: 200,
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('正在生成图片...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(SceneIllustration illustration) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.error, color: Colors.red[400]),
          const SizedBox(height: 8),
          Text(
            '生成失败',
            style: TextStyle(color: Colors.red[600]),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _retryGeneration(illustration),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
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

      // 创建空的角色列表，调试模式下不需要角色信息
      final List<RoleInfo> emptyRoles = [];

      // 调用SceneIllustrationService的API，这会自动保存到数据库
      await _sceneIllustrationService.createSceneIllustrationWithMarkup(
        novelUrl: 'debug_novel_url', // 调试用的小说URL
        chapterId: 'debug_chapter_id', // 调试用的章节ID
        paragraphText: prompt, // 使用prompt作为段落文本
        roles: emptyRoles, // 空角色列表
        imageCount: imageCount,
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
      final illustrations = await _databaseService.getSceneIllustrationsPaginated(
        page: _currentPage,
        limit: _pageSize,
      );

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _sceneIllustrations.clear();
          }
          _sceneIllustrations.addAll(illustrations);
          _hasMore = illustrations.length == _pageSize;
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

  Future<void> _refreshIllustrations() async {
    await _loadIllustrations(isRefresh: true);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreIllustrations();
    }
  }

  Future<void> _loadMoreIllustrations() async {
    if (!_hasMore || _isLoading) return;

    setState(() {
      _currentPage++;
    });

    await _loadIllustrations();
  }

  Future<void> _retryGeneration(SceneIllustration illustration) async {
    try {
      // 更新状态为处理中
      final index = _sceneIllustrations.indexWhere((item) => item.id == illustration.id);
      if (index != -1) {
        final updatedIllustration = SceneIllustration(
          id: illustration.id,
          novelUrl: illustration.novelUrl,
          chapterId: illustration.chapterId,
          taskId: illustration.taskId,
          content: illustration.content,
          roles: illustration.roles,
          imageCount: illustration.imageCount,
          status: 'processing',
          images: illustration.images,
          prompts: illustration.prompts,
          createdAt: illustration.createdAt,
          completedAt: null,
        );

        setState(() {
          _sceneIllustrations[index] = updatedIllustration;
        });

        // 这里可以重新调用API重新生成，目前只是更新状态
        _showErrorSnackBar('重试功能待实现');
      }
    } catch (e) {
      debugPrint('重试生成失败: $e');
      _showErrorSnackBar('重试失败: $e');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}:'
           '${dateTime.second.toString().padLeft(2, '0')}';
  }

  void _showErrorSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }
}