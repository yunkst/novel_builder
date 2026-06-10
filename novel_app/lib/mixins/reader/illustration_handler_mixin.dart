import 'package:flutter/material.dart';
import '../../models/novel.dart';
import '../../models/chapter.dart';
import '../../services/api_service_wrapper.dart';
import '../../core/interfaces/repositories/i_chapter_repository.dart';
import '../../core/interfaces/repositories/i_illustration_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../services/scene_illustration_service.dart';
import '../../services/logger_service.dart';
import '../../utils/error_helper.dart';
import '../../widgets/illustration_action_dialog.dart';
import '../../widgets/generate_more_dialog.dart';
import '../../widgets/video_input_dialog.dart';
import '../../utils/video_generation_state_manager.dart';
import '../../utils/toast_utils.dart';

/// 插图处理功能 Mixin
///
/// 职责：
/// - 处理插图相关的所有交互操作
/// - 支持图片生成视频
/// - 支持重新生成图片（"再来几张"）
/// - 支持删除插图
/// - 管理视频生成状态
///
/// 使用方式：
/// ```dart
/// class _MyScreenState extends State<MyScreen> with IllustrationHandlerMixin {
///   // Mixin 会自动处理插图相关的操作
/// }
/// ```
///
/// 需要子类提供的字段和方法：
/// - `Novel get novel` - 小说信息
/// - `Chapter get currentChapter` - 当前章节
/// - `IChapterRepository get chapterRepository` - 章节数据仓库
/// - `IIllustrationRepository get illustrationRepository` - 插图数据仓库
/// - `ApiServiceWrapper get apiService` - API 服务
mixin IllustrationHandlerMixin<T extends StatefulWidget> on State<T> {
  // ========== 字段 ==========

  SceneIllustrationService? _sceneIllustrationService;

  // ========== 抽象访问器（子类必须实现）==========

  /// 小说信息（子类提供）
  Novel get novel;

  /// 当前章节（子类提供）
  Chapter get currentChapter;

  /// 章节数据仓库（子类提供）
  IChapterRepository get chapterRepository;

  /// 插图数据仓库（子类提供）
  IIllustrationRepository get illustrationRepository;

  /// API 服务（子类提供）
  ApiServiceWrapper get apiService;

  // ========== 私有方法 ==========

  /// 获取SceneIllustrationService实例（延迟初始化）
  SceneIllustrationService get _sceneIllustrationServiceInstance {
    _sceneIllustrationService ??= SceneIllustrationService(
      chapterRepository: chapterRepository,
      illustrationRepository: illustrationRepository,
      apiService: apiService,
    );
    return _sceneIllustrationService!;
  }

  // ========== 公开方法 ==========

  /// 通过 taskId 直接生成视频
  Future<void> generateVideoFromIllustration(String taskId) async {
    try {
      // 根据 taskId 获取插图信息
      final illustrations =
          await illustrationRepository.getSceneIllustrationsByChapter(
        novel.url,
        currentChapter.url,
      );

      final illustration = illustrations.firstWhere(
        (ill) => ill.taskId == taskId,
        orElse: () => throw Exception('插图不存在'),
      );

      if (illustration.images.isEmpty) {
        if (mounted) {
          ToastUtils.showInfo('图片正在生成中，请稍后查看');
        }
        return;
      }

      // 获取第一张图片的文件名
      final firstImageUrl = illustration.images.first;
      final fileName = firstImageUrl.split('/').last;

      // 显示视频输入对话框
      if (!mounted) return;
      final videoInput = await VideoInputDialog.show(context);
      if (videoInput == null || !mounted) {
        return; // 用户取消或widget已销毁
      }

      final userInput = videoInput['user_input'] ?? '';
      final modelName = videoInput['model_name'];

      if (userInput.isEmpty) {
        return; // 未输入内容
      }

      // 显示加载提示
      if (mounted) {
        ToastUtils.showInfo('正在创建视频生成任务...');
      }

      // 调用API生成视频
      final response = await apiService.generateVideoFromImage(
        imgName: fileName,
        userInput: userInput,
        modelName: modelName,
      );

      if (mounted) {
        ToastUtils.showSuccess('视频生成任务已创建，任务ID: ${response.taskId}');
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      ErrorHelper.showErrorWithLog(
        context,
        '生成视频失败',
        stackTrace: stackTrace,
        category: LogCategory.ai,
        tags: ['video', 'generate', 'failed'],
      );
    }
  }

  /// 处理图片点击事件 - 显示功能选择对话框
  Future<void> handleImageTap(
      String taskId, String imageUrl, int imageIndex) async {
    // 查询数据库获取插图信息（使用用户输入的场景描述）
    String? prompts;
    try {
      final illustrations =
          await illustrationRepository.getSceneIllustrationsByChapter(
        novel.url,
        currentChapter.url,
      );
      final illustration = illustrations.firstWhere(
        (ill) => ill.taskId == taskId,
        orElse: () => throw Exception('插图不存在'),
      );
      prompts = illustration.content;
    } catch (e, stackTrace) {
      LoggerService.instance.w(
        '获取插图信息失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['illustration', 'info', 'failed'],
      );
      prompts = null;
    }

    // 显示功能选择对话框 (传入prompts)
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
      await regenerateMoreImages(taskId);
    } else if (action == 'video') {
      // 用户选择"生成视频"
      await generateVideoFromSpecificImage(taskId, imageUrl, imageIndex);
    }
  }

  /// 再来几张 - 重新生成更多图片
  Future<void> regenerateMoreImages(String taskId) async {
    LoggerService.instance.d(
      'regenerateMoreImages 开始, taskId: $taskId',
      category: LogCategory.ai,
      tags: ['illustration'],
    );

    try {
      // 显示数量选择对话框
      if (!mounted) {
        LoggerService.instance.e(
          'regenerateMoreImages: widget已销毁，取消操作',
          category: LogCategory.ai,
          tags: ['illustration'],
        );
        return;
      }

      LoggerService.instance.d(
        '显示 GenerateMoreDialog',
        category: LogCategory.ai,
        tags: ['illustration'],
      );
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => GenerateMoreDialog(
          apiType: 't2i', // 文生图模型
          onConfirm: (count, modelName) {
            LoggerService.instance.d(
              'GenerateMoreDialog onConfirm: count=$count, model=$modelName',
              category: LogCategory.ai,
              tags: ['illustration'],
            );
            Navigator.of(context).pop({
              'count': count,
              'modelName': modelName,
            });
          },
        ),
      );

      if (result == null || !mounted) {
        LoggerService.instance.i(
          '用户取消或widget已销毁',
          category: LogCategory.ai,
          tags: ['illustration'],
        );
        return;
      }

      final count = result['count'] as int;
      final modelName = result['modelName'] as String?;
      LoggerService.instance.i(
        '用户选择生成图片: count=$count, model=$modelName',
        category: LogCategory.ai,
        tags: ['illustration'],
      );

      // 显示加载提示
      if (mounted) {
        LoggerService.instance.d(
          '显示加载提示',
          category: LogCategory.ai,
          tags: ['illustration'],
        );
        ToastUtils.showInfo('正在生成 $count 张图片...');
      }

      // 调用 API 生成图片
      final apiService = this.apiService;
      LoggerService.instance.d(
        '准备调用 API: regenerateSceneIllustrationImages, ApiServiceWrapper初始化状态: ${apiService.getInitStatus()}',
        category: LogCategory.ai,
        tags: ['illustration'],
      );

      LoggerService.instance.d(
        '开始API调用: regenerateSceneIllustrationImages',
        category: LogCategory.cache,
        tags: ['illustration'],
      );
      final response = await apiService.regenerateSceneIllustrationImages(
        taskId: taskId,
        count: count,
        modelName: modelName,
      );

      LoggerService.instance.i(
        'API调用成功, 响应: $response',
        category: LogCategory.ai,
        tags: ['illustration'],
      );

      // 显示成功提示（不刷新列表，按需求）
      if (mounted) {
        LoggerService.instance.d(
          '显示成功提示',
          category: LogCategory.ai,
          tags: ['illustration'],
        );
        ToastUtils.showSuccess('图片生成任务已创建，预计需要1-3分钟');
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      ErrorHelper.showErrorWithLog(
        context,
        '生成图片失败',
        stackTrace: stackTrace,
        category: LogCategory.ai,
        tags: ['illustration', 'regenerate', 'failed'],
      );
    }

    LoggerService.instance.d(
      'regenerateMoreImages 结束',
      category: LogCategory.ai,
      tags: ['illustration'],
    );
  }

  /// 为特定图片生成视频
  Future<void> generateVideoFromSpecificImage(
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
      setImageGeneratingStatus(imageUrl, true);

      // 显示加载提示
      if (mounted) {
        ToastUtils.showInfo('正在为选中图片创建视频生成任务...');
      }

      // 调用API生成视频
      final response = await apiService.generateVideoFromImage(
        imgName: fileName,
        userInput: userInput,
        modelName: '', // 使用空字符串
      );

      // 清除生成状态
      setImageGeneratingStatus(imageUrl, false);

      if (mounted) {
        ToastUtils.showSuccess('视频生成任务已创建，任务ID: ${response.taskId}');
      }
    } catch (e) {
      // 清除生成状态
      setImageGeneratingStatus(imageUrl, false);

      if (mounted) {
        ToastUtils.showError('生成视频失败: $e');
      }
    }
  }

  /// 设置图片生成状态 - 通过状态管理器设置全局状态
  void setImageGeneratingStatus(String imageUrl, bool isGenerating) {
    // 通过视频生成状态管理器设置全局状态
    VideoGenerationStateManager.setImageGenerating(imageUrl, isGenerating);
  }

  /// 通过 taskId 删除插图
  Future<void> deleteIllustrationByTaskId(String taskId) async {
    try {
      // 根据 taskId 获取插图信息
      final illustrations =
          await illustrationRepository.getSceneIllustrationsByChapter(
        novel.url,
        currentChapter.url,
      );

      final illustration = illustrations.firstWhere(
        (ill) => ill.taskId == taskId,
        orElse: () => throw Exception('插图不存在'),
      );

      final confirmed = mounted
          ? await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('确认删除'),
                content: const Text('确定要删除这个插图吗？此操作无法撤销。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appColors.error,
                      foregroundColor: context.appColors.onSemantic,
                    ),
                    child: const Text('删除'),
                  ),
                ],
              ),
            )
          : false;

      if (confirmed == true) {
        final success = await _sceneIllustrationServiceInstance
            .deleteIllustration(illustration.id);
        if (success) {
          // 插图删除成功，内容会通过_illustrationsUpdatedCallback自动刷新
          if (mounted) {
            ToastUtils.showSuccess('插图已删除');
          }
        } else {
          LoggerService.instance.e(
            '删除插图失败: 服务返回false',
            category: LogCategory.ai,
            tags: ['illustration', 'delete', 'failed'],
          );
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
