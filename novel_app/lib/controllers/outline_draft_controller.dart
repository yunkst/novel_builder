import 'package:flutter/material.dart';
import '../models/stream_config.dart';
import '../services/unified_stream_manager.dart';

/// 细纲生成控制器
/// 负责生成和重新生成章节细纲，使用流式输出
class OutlineDraftController with ChangeNotifier {
  final UnifiedStreamManager _streamManager = UnifiedStreamManager();

  bool _isLoading = false;
  String _streamedContent = '';
  String? _error;
  String? _activeStreamId;
  bool _isDisposed = false;

  // TextField控制器(用于流式显示)
  TextEditingController? _textController;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 流式返回的累积内容
  String get streamedContent => _streamedContent;

  /// 发生的错误信息
  String? get error => _error;

  /// 设置TextField控制器
  void setTextController(TextEditingController controller) {
    _textController = controller;
  }

  /// 重置控制器状态
  void reset() {
    if (_isDisposed) return;
    _streamedContent = '';
    _error = null;
    notifyListeners();
  }

  /// 生成章节细纲
  ///
  /// [outline] 大纲内容
  /// [historyChaptersContent] 前文章节内容（用于上下文）
  /// [userInput] 用户输入的要求
  /// [existingDraft] 已存在的细纲（用于重新生成场景）
  Future<void> generateDraft({
    required String outline,
    required List<String> historyChaptersContent,
    required String userInput,
    String? existingDraft,
  }) async {
    if (_isDisposed) return;

    // 如果已有流在运行，先取消
    if (_activeStreamId != null) {
      await _streamManager.cancelStream(_activeStreamId!);
    }

    // 重置状态
    _isLoading = true;
    _streamedContent = '';
    _error = null;

    // 清空TextField
    _textController?.clear();

    notifyListeners();

    // 构建Dify输入参数
    final inputs = {
      'cmd': '生成细纲',
      'outline': outline,
      'history_chapters_content': historyChaptersContent.join('\n\n'),
      'outline_item': existingDraft ?? '',
      'user_input': userInput.trim(), // 确保空字符串也能正确传递
    };

    debugPrint('🤖 开始生成细纲...');
    debugPrint('📚 大纲长度: ${outline.length} 字符');
    debugPrint('📖 前文章节数: ${historyChaptersContent.length}');
    debugPrint('📝 用户输入: $userInput');
    debugPrint('🔄 已有细纲: ${existingDraft != null ? "是" : "否"}');

    // 使用配置创建流式任务
    final config = StreamConfig.outlineDraft(inputs: inputs);

    _activeStreamId = await _streamManager.executeStream(
      config: config,
      onChunk: (chunk) {
        if (_isDisposed) return;
        // 特殊标记，用于一次性显示完整内容
        const completeContentMarker = '<<COMPLETE_CONTENT>>';
        if (chunk.startsWith(completeContentMarker)) {
          _streamedContent = chunk.substring(completeContentMarker.length);
        } else {
          _streamedContent += chunk;
        }

        // 直接更新TextField(参考大纲生成的实现)
        _textController?.text = _streamedContent;

        // 移动光标到末尾,让用户看到最新内容
        if (_textController != null && _streamedContent.isNotEmpty) {
          _textController!.selection = TextSelection.fromPosition(
            TextPosition(offset: _streamedContent.length),
          );
        }

        notifyListeners();
      },
      onComplete: (fullContent) {
        if (_isDisposed) return;
        _isLoading = false;
        // 确保最终内容与 onComplete 的内容一致
        if (_streamedContent.length < fullContent.length) {
          _streamedContent = fullContent;
          // 更新TextField
          _textController?.text = _streamedContent;
        }
        debugPrint('✅ 细纲生成完成，总长度: ${_streamedContent.length} 字符');
        notifyListeners();
      },
      onError: (errorMessage) {
        if (_isDisposed) return;
        _isLoading = false;
        _error = errorMessage;
        debugPrint('❌ 细纲生成失败: $errorMessage');
        notifyListeners();
      },
    );
  }

  /// 取消当前的生成任务
  Future<void> cancel() async {
    if (_activeStreamId != null) {
      await _streamManager.cancelStream(_activeStreamId!);
      _activeStreamId = null;
    }
    if (!_isDisposed) {
      _isLoading = false;
      if (_streamedContent.isEmpty) {
        _error = '操作已取消';
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    cancel();
    super.dispose();
  }
}
