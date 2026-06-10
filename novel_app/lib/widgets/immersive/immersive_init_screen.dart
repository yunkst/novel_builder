import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/novel.dart';
import '../../models/chapter.dart';
import '../../models/character.dart';
import '../../services/dify_service.dart';
import '../../services/logger_service.dart';
import '../../utils/toast_utils.dart';
import 'immersive_setup_dialog.dart';
import '../../screens/multi_role_chat_screen.dart';

/// 沉浸体验状态枚举
enum ImmersiveStatus {
  initializing, // 初始化
  loading, // 加载中
  success, // 成功
  error, // 错误
}

/// 沉浸体验初始化页面
///
/// 功能：
/// 1. 显示加载动画（呼吸效果 + 轮播提示）
/// 2. 调用Dify生成剧本
/// 3. 使用TabBar展示剧本和角色策略
/// 4. 支持修改意见重新生成
/// 5. 错误处理和重试
class ImmersiveInitScreen extends StatefulWidget {
  final Novel novel;
  final Chapter chapter;
  final String chapterContent;
  final ImmersiveConfig config;

  const ImmersiveInitScreen({
    super.key,
    required this.novel,
    required this.chapter,
    required this.chapterContent,
    required this.config,
  });

  @override
  State<ImmersiveInitScreen> createState() => _ImmersiveInitScreenState();
}

class _ImmersiveInitScreenState extends State<ImmersiveInitScreen>
    with TickerProviderStateMixin {
  final DifyService _difyService = DifyService();

  // 页面状态
  ImmersiveStatus _status = ImmersiveStatus.initializing;
  String? _errorMessage;

  // 生成结果
  String? _play;
  List<Map<String, dynamic>>?
      _roleStrategy; // 类型修改: List<String> -> List<Map<String, dynamic>>

  // 动画控制器
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // 提示文字轮播
  final List<String> _tips = [
    '🎭 正在准备沉浸体验...',
    '⏳ 剧本生成中...',
    '📝 角色策略制定中...',
    '✨ 精彩内容即将呈现...',
  ];
  int _currentTipIndex = 0;
  Timer? _tipTimer;

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器（呼吸效果）
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.repeat(reverse: true);

    // 启动提示文字轮播
    _startTipRotation();

    // 开始生成剧本
    _generateScript();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tipTimer?.cancel();
    super.dispose();
  }

  /// 启动提示文字轮播
  void _startTipRotation() {
    _tipTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
        });
      }
    });
  }

  /// 生成剧本
  Future<void> _generateScript() async {
    if (!mounted) return;

    setState(() {
      _status = ImmersiveStatus.loading;
    });

    try {
      final outputs = await _difyService.generateImmersiveScript(
        chapterContent: widget.chapterContent,
        characters: widget.config.characters, // 传递完整角色对象
        userInput: widget.config.userRequirement,
        userChoiceRole: widget.config.userRole,
      );

      if (outputs == null || outputs.isEmpty) {
        throw Exception('AI生成失败：未收到有效响应');
      }

      final play = outputs['play'] as String?;
      final roleStrategy = outputs['role_strategy'] as List<dynamic>?;

      if (play == null || roleStrategy == null) {
        throw Exception('返回数据格式错误：缺少play或role_strategy字段');
      }

      // 转换role_strategy为List<Map<String, dynamic>>
      final roleStrategyList = roleStrategy
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();

      // 停止动画和提示轮播
      _tipTimer?.cancel();
      _animationController.stop();

      if (!mounted) return;

      setState(() {
        _play = play;
        _roleStrategy = roleStrategyList;
        _status = ImmersiveStatus.success;
      });

      LoggerService.instance.i(
        '剧本生成成功: 剧本长度=${play.length}字符, 角色策略数量=${roleStrategyList.length}',
        category: LogCategory.ai,
        tags: ['immersive', 'script', 'generate', 'success'],
      );
    } catch (e, stackTrace) {
      // 停止动画和提示轮播
      _tipTimer?.cancel();
      _animationController.stop();

      if (!mounted) return;

      // 记录错误日志
      LoggerService.instance.e(
        '剧本生成失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['immersive', 'script', 'generate', 'failed'],
      );

      setState(() {
        _status = ImmersiveStatus.error;
        _errorMessage = e.toString();
      });

      if (mounted) {
        _showErrorDialog(e.toString());
      }
    }
  }

  /// 重新生成（带修改意见）
  Future<void> _regenerateWithFeedback(String feedback) async {
    if (!mounted) return;

    setState(() {
      _status = ImmersiveStatus.loading;
      _currentTipIndex = 0;
    });

    // 重新启动动画和提示轮播
    _animationController.repeat(reverse: true);
    _startTipRotation();

    try {
      final outputs = await _difyService.generateImmersiveScript(
        chapterContent: widget.chapterContent,
        characters: widget.config.characters,
        userInput: feedback, // 使用用户的修改意见
        userChoiceRole: widget.config.userRole,
        existingPlay: _play, // 传入当前剧本
        existingRoleStrategy:
            _roleStrategy, // 传入当前角色策略 (List<Map<String, dynamic>>)
      );

      if (outputs == null || outputs.isEmpty) {
        throw Exception('AI生成失败：未收到有效响应');
      }

      final play = outputs['play'] as String?;
      final roleStrategy = outputs['role_strategy'] as List<dynamic>?;

      if (play == null || roleStrategy == null) {
        throw Exception('返回数据格式错误');
      }

      final roleStrategyList = roleStrategy
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();

      _tipTimer?.cancel();
      _animationController.stop();

      if (!mounted) return;

      setState(() {
        _play = play;
        _roleStrategy = roleStrategyList;
        _status = ImmersiveStatus.success;
      });

      if (mounted) {
        ToastUtils.showSuccess('重新生成成功');
      }
    } catch (e, stackTrace) {
      _tipTimer?.cancel();
      _animationController.stop();

      if (!mounted) return;

      // 记录错误日志
      LoggerService.instance.e(
        '剧本重新生成失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['immersive', 'script', 'regenerate', 'failed'],
      );

      setState(() {
        _status = ImmersiveStatus.error;
        _errorMessage = e.toString();
      });

      if (mounted) {
        _showErrorDialog(e.toString());
      }
    }
  }

  /// 显示错误对话框
  void _showErrorDialog(String error) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            const Text('生成失败'),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            child: const Text('重试'),
            onPressed: () {
              Navigator.pop(context);
              _generateScript();
            },
          ),
          TextButton(
            child: const Text('返回'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(this.context);
            },
          ),
        ],
      ),
    );
  }

  /// 显示修改意见对话框
  void _showModifyDialog() {
    final controller = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('修改意见'),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '请描述您的修改意见',
            hintText: '例如：希望剧本更紧张一些，增加角色之间的对话...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 5,
          minLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final feedback = controller.text.trim();
              if (feedback.isEmpty) {
                ToastUtils.showWarning('请输入修改意见');
                return;
              }

              Navigator.pop(context);
              _regenerateWithFeedback(feedback);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text('重新生成'),
          ),
        ],
      ),
    );
  }

  /// 确认剧本（启动多人对话）
  void _confirmScript() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MultiRoleChatScreen(
          characters: widget.config.characters,
          play: _play!,
          roleStrategy: _roleStrategy!,
          userRole: widget.config.userRole, // 传递用户选择的角色名
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('沉浸体验初始化'),
        automaticallyImplyLeading: _status != ImmersiveStatus.loading,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case ImmersiveStatus.initializing:
      case ImmersiveStatus.loading:
        return _buildLoadingView();
      case ImmersiveStatus.success:
        return _buildSuccessView();
      case ImmersiveStatus.error:
        return _buildErrorView();
    }
  }

  /// 加载视图（选项C：简单文字提示 + 呼吸动画）
  Widget _buildLoadingView() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 动画图标
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: child,
                ),
              );
            },
            child: Icon(
              Icons.theater_comedy,
              size: 80,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),

          // 文字提示（轮播）
          Text(
            _tips[_currentTipIndex],
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '剧本生成中...',
            style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 32),

          // 进度指示器
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  /// 成功视图（选项B：TabBar切换）
  Widget _buildSuccessView() {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // TabBar
          TabBar(
            tabs: const [
              Tab(text: '📜 剧本'),
              Tab(text: '🎭 角色策略'),
            ],
            labelColor: theme.colorScheme.primary,
            indicatorColor: theme.colorScheme.primary,
          ),

          // TabBarView
          Expanded(
            child: TabBarView(
              children: [
                _buildScriptView(),
                _buildRoleStrategyView(),
              ],
            ),
          ),

          // 底部操作栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新生成'),
                    onPressed: _showModifyDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('确认'),
                    onPressed: _confirmScript,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 剧本视图
  Widget _buildScriptView() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: SelectableText(
              _play ?? '',
              style: const TextStyle(
                height: 1.6,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 角色策略视图
  Widget _buildRoleStrategyView() {
    final theme = Theme.of(context);

    if (_roleStrategy == null || _roleStrategy!.isEmpty) {
      return const Center(
        child: Text('暂无角色策略'),
      );
    }

    // 性能优化: 构建角色名到角色的映射,避免在列表构建中重复查找 (O(1) vs O(n))
    final characterMap = {for (var c in widget.config.characters) c.name: c};

    // 准备降级角色对象(用于找不到角色时)
    final fallbackCharacter = widget.config.characters.isNotEmpty
        ? widget.config.characters.first
        : Character(novelUrl: '', name: '未知角色');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _roleStrategy!.length,
      itemBuilder: (context, index) {
        final strategyItem = _roleStrategy![index];
        final characterName = strategyItem['name'] as String? ?? '未知角色';
        final strategy = strategyItem['strategy'] as String? ?? '';

        // 使用Map快速查找角色对象
        final character = characterMap[characterName] ?? fallbackCharacter;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 角色名 + 头像
                Row(
                  children: [
                    if (character.cachedImageUrl != null)
                      CircleAvatar(
                        radius: 20,
                        backgroundImage:
                            FileImage(File(character.cachedImageUrl!)),
                      )
                    else
                      CircleAvatar(
                        radius: 20,
                        child: Text(
                          characterName.isNotEmpty ? characterName[0] : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        characterName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 策略内容 (空安全: 显示友好提示)
                Text(
                  strategy.isNotEmpty ? strategy : '暂无策略描述',
                  style: TextStyle(
                    height: 1.5,
                    fontSize: 14,
                    color: strategy.isNotEmpty
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 错误视图
  Widget _buildErrorView() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: theme.colorScheme.error.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 24),
          Text(
            '生成失败',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? '未知错误',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
                onPressed: () {
                  setState(() {
                    _status = ImmersiveStatus.loading;
                    _currentTipIndex = 0;
                  });
                  _animationController.repeat(reverse: true);
                  _startTipRotation();
                  _generateScript();
                },
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  foregroundColor: theme.colorScheme.surface,
                ),
                child: const Text('返回'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
