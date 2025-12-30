import 'package:flutter/foundation.dart';
import '../services/dify_service.dart';

/// 负责章节总结功能的控制器
class SummarizeController with ChangeNotifier {
  final DifyService _difyService = DifyService();

  bool _isLoading = false;
  String _streamedContent = '';
  String? _error;
  bool _isDisposed = false;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 流式返回的、累积的总结内容
  String get streamedContent => _streamedContent;

  /// 发生的错误信息
  String? get error => _error;

  /// 开始生成章节总结
  Future<void> generateSummary({
    required Map<String, dynamic> inputs,
  }) async {
    if (_isDisposed) return;

    _isLoading = true;
    _streamedContent = '';
    _error = null;
    notifyListeners();

    try {
      await _difyService.runWorkflowStreaming(
        inputs: inputs,
        onData: (data) {
          if (_isDisposed) return;
          _streamedContent += data;
          notifyListeners();
        },
        onError: (errorMessage) {
          if (_isDisposed) return;
          _error = errorMessage;
          _isLoading = false;
          notifyListeners();
        },
        onDone: () {
          if (_isDisposed) return;
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      if (_isDisposed) return;
      _error = '生成总结时发生未知异常: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
