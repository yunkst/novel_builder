import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// TTS语音模型
class TtsVoice {
  final String id;
  final String name;
  final String locale;
  final String? language;

  TtsVoice({
    required this.id,
    required this.name,
    required this.locale,
    this.language,
  });

  factory TtsVoice.fromMap(Map<String, dynamic> map) {
    return TtsVoice(
      id: map['id'] as String,
      name: map['name'] as String,
      locale: map['locale'] as String,
      language: map['language'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'locale': locale,
      'language': language,
    };
  }
}

/// TTS服务异常
class TtsException implements Exception {
  final String message;
  final dynamic cause;

  TtsException(this.message, [this.cause]);

  @override
  String toString() => 'TtsException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// TTS核心服务 - 封装Platform Channel调用原生TTS引擎
class TtsService {
  static const MethodChannel _channel = MethodChannel('com.example.novel_app/tts');

  // 单例模式
  TtsService._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  // 状态流控制器
  final StreamController<bool> _isSpeakingController = StreamController<bool>.broadcast();
  final StreamController<String> _speakCompleteController = StreamController<String>.broadcast();
  final StreamController<String> _speakStartController = StreamController<String>.broadcast();
  final StreamController<String> _errorController = StreamController<String>.broadcast();

  // 公开流
  Stream<bool> get isSpeaking => _isSpeakingController.stream;
  Stream<String> get onSpeakComplete => _speakCompleteController.stream;
  Stream<String> get onSpeakStart => _speakStartController.stream;
  Stream<String> get onError => _errorController.stream;

  // 内部状态
  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// 处理原生层回调
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('[TtsService] 🔔 收到原生回调: ${call.method} (args: ${call.arguments})');
    switch (call.method) {
      case 'onSpeakStart':
        final utteranceId = call.arguments as String?;
        if (utteranceId != null) {
          debugPrint('[TtsService] ▶️ 朗读开始: $utteranceId');
          _speakStartController.add(utteranceId);
        }
        _isSpeakingController.add(true);
        break;
      case 'onSpeakComplete':
        final utteranceId = call.arguments as String?;
        if (utteranceId != null) {
          debugPrint('[TtsService] ⏹️ 朗读完成: $utteranceId');
          _speakCompleteController.add(utteranceId);
        }
        _isSpeakingController.add(false);
        break;
      case 'onError':
        final error = call.arguments as String?;
        debugPrint('[TtsService] ❌ TTS错误: $error');
        _errorController.add(error ?? 'Unknown error');
        _isSpeakingController.add(false);
        break;
      default:
        debugPrint('[TtsService] ⚠️ 未知回调方法: ${call.method}');
    }
  }

  /// 初始化TTS引擎
  ///
  /// 返回 true 表示初始化成功，false 表示失败
  Future<bool> initialize() async {
    try {
      debugPrint('[TtsService] 正在初始化TTS引擎...');
      final result = await _channel.invokeMethod<bool>('initialize');
      _initialized = result ?? false;

      if (_initialized) {
        debugPrint('[TtsService] ✅ TTS引擎初始化成功');
      } else {
        debugPrint('[TtsService] ❌ TTS引擎初始化失败');
      }

      return _initialized;
    } on PlatformException catch (e) {
      debugPrint('[TtsService] ❌ 初始化异常: ${e.message}');
      _initialized = false;
      return false;
    }
  }

  /// 朗读文本
  ///
  /// [text] 要朗读的文本内容
  /// 返回唯一标识符，用于跟踪朗读进度
  Future<String> speak(String text) async {
    if (!_initialized) {
      throw TtsException('TTS引擎未初始化，请先调用initialize()');
    }

    if (text.trim().isEmpty) {
      throw TtsException('朗读内容不能为空');
    }

    try {
      debugPrint('[TtsService] 开始朗读: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
      final utteranceId = await _channel.invokeMethod<String>('speak', {'text': text});
      return utteranceId ?? DateTime.now().millisecondsSinceEpoch.toString();
    } on PlatformException catch (e) {
      debugPrint('[TtsService] ❌ 朗读失败: ${e.message}');
      throw TtsException('朗读失败', e);
    }
  }

  /// 暂停朗读
  Future<void> pause() async {
    if (!_initialized) return;

    try {
      debugPrint('[TtsService] 暂停朗读');
      await _channel.invokeMethod('pause');
    } on PlatformException catch (e) {
      debugPrint('[TtsService] ❌ 暂停失败: ${e.message}');
      throw TtsException('暂停失败', e);
    }
  }

  /// 继续朗读
  Future<void> resume() async {
    if (!_initialized) return;

    try {
      debugPrint('[TtsService] 继续朗读');
      await _channel.invokeMethod('resume');
    } on PlatformException catch (e) {
      debugPrint('[TtsService] ❌ 继续失败: ${e.message}');
      throw TtsException('继续失败', e);
    }
  }

  /// 停止朗读并清除队列
  Future<void> stop() async {
    if (!_initialized) return;

    try {
      debugPrint('[TtsService] 停止朗读');
      await _channel.invokeMethod('stop');
    } on PlatformException catch (e) {
      debugPrint('[TtsService] ❌ 停止失败: ${e.message}');
      throw TtsException('停止失败', e);
    }
  }

  /// 设置语速
  ///
  /// [rate] 语速倍数，0.5(慢) ~ 2.0(快)，默认1.0
  Future<void> setSpeechRate(double rate) async {
    if (!_initialized) return;

    if (rate < 0.5 || rate > 2.0) {
      throw TtsException('语速必须在0.5~2.0之间');
    }

    try {
      debugPrint('[TtsService] 设置语速: $rate');
      await _channel.invokeMethod('setSpeechRate', {'rate': rate});
    } on PlatformException catch (e) {
      debugPrint('[TtsService] ❌ 设置语速失败: ${e.message}');
      throw TtsException('设置语速失败', e);
    }
  }

  /// 设置音调
  ///
  /// [pitch] 音调倍数，0.5(低) ~ 2.0(高)，默认1.0
  Future<void> setPitch(double pitch) async {
    if (!_initialized) return;

    if (pitch < 0.5 || pitch > 2.0) {
      throw TtsException('音调必须在0.5~2.0之间');
    }

    try {
      debugPrint('[TtsService] 设置音调: $pitch');
      await _channel.invokeMethod('setPitch', {'pitch': pitch});
    } on PlatformException catch (e) {
      debugPrint('[TtsService] ❌ 设置音调失败: ${e.message}');
      throw TtsException('设置音调失败', e);
    }
  }

  /// 设置音量
  ///
  /// [volume] 音量，0.0(静音) ~ 1.0(最大)，默认1.0
  Future<void> setVolume(double volume) async {
    if (!_initialized) return;

    if (volume < 0.0 || volume > 1.0) {
      throw TtsException('音量必须在0.0~1.0之间');
    }

    try {
      debugPrint('[TtsService] 设置音量: $volume');
      await _channel.invokeMethod('setVolume', {'volume': volume});
    } on PlatformException catch (e) {
      debugPrint('[TtsService] ❌ 设置音量失败: ${e.message}');
      throw TtsException('设置音量失败', e);
    }
  }

  /// 获取可用语音列表
  Future<List<TtsVoice>> getAvailableVoices() async {
    if (!_initialized) {
      throw TtsException('TTS引擎未初始化');
    }

    try {
      debugPrint('[TtsService] 获取可用语音列表');
      final result = await _channel.invokeListMethod<Map<Object?, Object?>>('getVoices');
      if (result == null) return [];

      return result
          .map((map) => TtsVoice.fromMap(map.cast<String, dynamic>()))
          .toList();
    } on PlatformException catch (e) {
      debugPrint('[TtsService] ❌ 获取语音列表失败: ${e.message}');
      throw TtsException('获取语音列表失败', e);
    }
  }

  /// 设置语音
  ///
  /// [voiceId] 语音ID
  Future<void> setVoice(String voiceId) async {
    if (!_initialized) return;

    try {
      debugPrint('[TtsService] 设置语音: $voiceId');
      await _channel.invokeMethod('setVoice', {'voiceId': voiceId});
    } on PlatformException catch (e) {
      debugPrint('[TtsService] ❌ 设置语音失败: ${e.message}');
      throw TtsException('设置语音失败', e);
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    debugPrint('[TtsService] 释放资源');
    await _isSpeakingController.close();
    await _speakCompleteController.close();
    await _speakStartController.close();
    await _errorController.close();
    _initialized = false;
  }
}
