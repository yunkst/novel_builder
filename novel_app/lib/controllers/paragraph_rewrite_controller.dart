import 'package:flutter/foundation.dart';
import '../models/stream_config.dart';
import '../services/unified_stream_manager.dart';

/// 负责段落改写（特写）功能的控制器
class ParagraphRewriteController with ChangeNotifier {
  final UnifiedStreamManager _streamManager = UnifiedStreamManager();

  bool _isLoading = false;
  String _streamedContent = '';
  String? _error;
  String? _activeStreamId;
  bool _isDisposed = false; // 新增：销毁标志

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 流式返回的、累积的内容
  String get streamedContent => _streamedContent;

  /// 发生的错误信息
  String? get error => _error;

  /// 开始生成改写内容
  Future<void> generateRewrite({
    required Map<String, dynamic> inputs,
  }) async {
    if (_isDisposed) return; // 防止在销毁后调用

    // 如果已有流在运行，先取消
    if (_activeStreamId != null) {
      await _streamManager.cancelStream(_activeStreamId!);
    }

    // 重置状态
    _isLoading = true;
    _streamedContent = '';
    _error = null;
    notifyListeners();

    final config = StreamConfig.closeUp(inputs: inputs);

    _activeStreamId = await _streamManager.executeStream(
      config: config,
      onChunk: (chunk) {
        if (_isDisposed) return; // 检查点
        // 特殊标记，用于一次性显示完整内容，避免UI逐字渲染长文本的性能问题
        const completeContentMarker = '<<COMPLETE_CONTENT>>';
        if (chunk.startsWith(completeContentMarker)) {
          _streamedContent = chunk.substring(completeContentMarker.length);
        } else {
          _streamedContent += chunk;
        }
        notifyListeners();
      },
      onComplete: (fullContent) {
        if (_isDisposed) return; // 检查点
        _isLoading = false;
        // 确保最终内容与 onComplete 的内容一致
        if (_streamedContent.length < fullContent.length) {
          _streamedContent = fullContent;
        }
        notifyListeners();
      },
      onError: (errorMessage) {
        if (_isDisposed) return; // 检查点
        _isLoading = false;
        _error = errorMessage;
        notifyListeners();
      },
    );
  }

  /// 取消当前的流
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
    _isDisposed = true; // 首先设置标志
    cancel(); // 在dispose时确保取消流
    super.dispose();
  }
}
