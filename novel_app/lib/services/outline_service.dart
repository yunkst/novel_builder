import 'package:flutter/foundation.dart';
import '../models/outline.dart';
import 'database_service.dart';

/// 大纲管理服务
/// 负责大纲的业务逻辑和AI生成接口
///
/// 使用方式：
/// ```dart
/// // 通过Provider获取（推荐）
/// final outlineService = ref.watch(outlineServiceProvider);
///
/// // 或手动创建实例
/// final outlineService = OutlineService(databaseService: databaseService);
/// ```
class OutlineService {
  final DatabaseService _db;

  /// 创建 OutlineService 实例
  ///
  /// 参数:
  /// - [databaseService] 数据库服务（必需）
  OutlineService({
    required DatabaseService databaseService,
  }) : _db = databaseService;

  // ========== 大纲CRUD操作 ==========

  /// 保存大纲（创建或更新）
  Future<void> saveOutline({
    required String novelUrl,
    required String title,
    required String content,
  }) async {
    final outline = Outline(
      novelUrl: novelUrl,
      title: title,
      content: content,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _db.saveOutline(outline);
    debugPrint('✅ 大纲已保存: $title');
  }

  /// 获取小说的大纲
  Future<Outline?> getOutline(String novelUrl) async {
    return await _db.getOutlineByNovelUrl(novelUrl);
  }

  /// 删除大纲
  Future<void> deleteOutline(String novelUrl) async {
    await _db.deleteOutline(novelUrl);
    debugPrint('🗑️ 大纲已删除: $novelUrl');
  }

  /// 更新大纲内容
  Future<void> updateOutline({
    required String novelUrl,
    required String title,
    required String content,
  }) async {
    await _db.updateOutlineContent(novelUrl, title, content);
    debugPrint('✏️ 大纲已更新: $title');
  }

  // ========== AI生成接口（已迁移到CreateOutlineScreen使用Dify流式API）==========
  // 注释：大纲生成方法已删除，现在使用DifyService的runWorkflowStreaming方法

  /// AI生成章节细纲（保留供OutlineIntegrationHandler使用）
  ///
  /// 优先级: P1 - 高
  /// Issue: 需要集成Dify工作流以替代模拟数据
  ///
  /// 当前实现: 返回模拟数据
  /// 目标实现:
  /// 1. 使用DifyService.runWorkflowStreaming
  /// 2. 传递细纲生成工作流ID
  /// 3. 返回真实的AI生成内容
  ///
  /// 调用位置:
  /// - OutlineIntegrationHandler.generateChapterOutline
  Future<ChapterOutlineDraft> generateChapterOutline({
    required String novelUrl,
    required String mainOutline,
    required List<String> previousChapters,
  }) async {
    debugPrint('🤖 开始生成章节细纲...');
    debugPrint('📚 参考大纲长度: ${mainOutline.length} 字符');
    debugPrint('📖 前文章节数: ${previousChapters.length}');

    // 获取当前大纲信息
    final outline = await getOutline(novelUrl);
    final outlineTitle = outline?.title ?? '未命名大纲';

    // 模拟AI生成延迟
    await Future.delayed(const Duration(seconds: 2));

    // 根据前文章节数生成不同的章节号
    final chapterNumber = previousChapters.length + 1;

    // 模拟生成的细纲内容
    final mockDraft = ChapterOutlineDraft(
      title: '第$chapterNumber章 ${_generateChapterTitle(chapterNumber)}',
      content: '''本章主要情节：

**场景设置**: 根据大纲的进度，本章应该处于故事的${_getStoryStage(chapterNumber)}阶段。

**关键事件**:
- 承接上文的情节发展
- 引入新的冲突或挑战
- 推动角色成长或关系变化

**重点描写**:
- 人物对话和心理活动
- 环境描写和氛围营造
- 动作场面的细节刻画

**结尾悬念**: 为下一章埋下伏笔，引发读者继续阅读的兴趣。

**与大纲的关联**: 本章对应大纲中"$outlineTitle"的部分内容，整体推进故事向高潮发展。
''',
      keyPoints: [
        '承接前文，保持连贯性',
        '引入新元素，推动情节',
        '展现角色成长',
        '设置悬念',
        '符合大纲规划',
      ],
    );

    debugPrint('✅ 章节细纲生成完成（模拟）');
    debugPrint('📝 细纲标题: ${mockDraft.title}');
    return mockDraft;
  }

  /// AI重新生成章节细纲（保留供OutlineIntegrationHandler使用）
  ///
  /// 优先级: P1 - 高
  /// Issue: 需要集成Dify工作流以替代模拟数据
  ///
  /// 当前实现: 返回模拟数据
  /// 目标实现:
  /// 1. 使用DifyService.runWorkflowStreaming
  /// 2. 传递细纲生成工作流ID和反馈意见
  /// 3. 返回基于反馈优化的AI生成内容
  ///
  /// 调用位置:
  /// - OutlineIntegrationHandler.regenerateChapterOutline
  /// - ChapterOutlineDialog (重新生成按钮)
  Future<ChapterOutlineDraft> regenerateChapterOutline({
    required String novelUrl,
    required String mainOutline,
    required List<String> previousChapters,
    required String feedback,
    required ChapterOutlineDraft currentDraft,
  }) async {
    debugPrint('🔄 开始重新生成章节细纲...');
    debugPrint('💬 修改意见: $feedback');

    // 模拟AI生成延迟
    await Future.delayed(const Duration(seconds: 2));

    // 模拟重新生成的细纲内容
    final mockDraft = ChapterOutlineDraft(
      title: '${currentDraft.title} (修订版)',
      content: '''本章主要情节（根据您的反馈优化）：

**场景设置**: ${feedback.contains('场景') ? '已调整场景设置，使其更合理' : '保持原有的场景设置'}

**关键事件**:
- ${feedback.contains('情节') ? '根据您的建议，优化了情节发展节奏' : '承接上文的情节发展'}
- ${feedback.contains('冲突') ? '增强了冲突的张力和戏剧性' : '引入新的冲突或挑战'}
- ${feedback.contains('角色') ? '深化了角色的内心描写' : '推动角色成长或关系变化'}

**重点描写**:
- 人物对话和心理活动（优化版）
- 环境描写和氛围营造（强化版）
- 动作场面的细节刻画（新增）

**结尾悬念**: ${feedback.contains('结尾') ? '根据建议重新设计了结尾悬念' : '为下一章埋下伏笔'}

**改进点**: 根据您的反馈"$feedback"，对细纲进行了针对性优化。
''',
      keyPoints: [
        '根据反馈优化',
        '增强戏剧冲突',
        '深化角色刻画',
        '改进节奏把控',
        '提升吸引力',
      ],
    );

    debugPrint('✅ 章节细纲重新生成完成（模拟）');
    return mockDraft;
  }

  // ========== 辅助方法 ==========

  /// 生成章节标题
  String _generateChapterTitle(int chapterNumber) {
    final titles = [
      '命运的起点',
      '未知的召唤',
      '初次试炼',
      '伙伴与敌人',
      '突破界限',
      '真相浮现',
      '抉择时刻',
      '背水一战',
      '终极对决',
      '新的开始',
    ];
    return titles[chapterNumber % titles.length];
  }

  /// 根据章节数判断故事阶段
  String _getStoryStage(int chapterNumber) {
    if (chapterNumber <= 3) return '开篇';
    if (chapterNumber <= 7) return '发展';
    if (chapterNumber <= 12) return '高潮';
    return '结局';
  }
}
