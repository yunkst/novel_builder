import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../models/reading_progress.dart';
import '../models/tts_timer_config.dart';
import 'tts_service.dart';
import 'database_service.dart';
import 'api_service_wrapper.dart';
import '../core/di/api_service_provider.dart';

/// TTS播放器状态
enum TtsPlayerState {
  idle,       // 空闲
  loading,    // 加载中
  playing,    // 播放中
  paused,     // 已暂停
  error,      // 错误
  completed,  // 完成
}

/// TTS播放器服务 - 管理播放状态、章节切换和进度保存
class TtsPlayerService extends ChangeNotifier {
  // 依赖服务
  final TtsService _tts = TtsService();
  final DatabaseService _database = DatabaseService();
  final ApiServiceWrapper _api = ApiServiceProvider.instance;

  // 状态订阅
  StreamSubscription<bool>? _speakingSubscription;
  StreamSubscription<String>? _completeSubscription;
  StreamSubscription<String>? _errorSubscription;

  // 播放器状态
  TtsPlayerState _state = TtsPlayerState.idle;
  TtsPlayerState get state => _state;

  // 小说信息
  Novel? _novel;
  Novel? get novel => _novel;

  List<Chapter> _allChapters = [];
  List<Chapter> get allChapters => _allChapters;

  Chapter? _currentChapter;
  Chapter? get currentChapter => _currentChapter;

  int _currentChapterIndex = 0;
  int get currentChapterIndex => _currentChapterIndex;

  // 朗读内容
  List<String> _paragraphs = [];
  List<String> get paragraphs => _paragraphs;

  int _currentParagraphIndex = 0;
  int get currentParagraphIndex => _currentParagraphIndex;

  String? get currentParagraph {
    if (_currentParagraphIndex >= 0 && _currentParagraphIndex < _paragraphs.length) {
      return _paragraphs[_currentParagraphIndex];
    }
    return null;
  }

  // 播放参数
  double _speechRate = 1.0;
  double get speechRate => _speechRate;

  double _pitch = 1.0;
  double get pitch => _pitch;

  // 错误信息
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // 进度保存key
  static const String _progressKey = 'tts_reading_progress';

  // 播放队列控制
  bool _autoPlayNext = true;  // 是否自动播放下一段/下一章
  bool get autoPlayNext => _autoPlayNext;
  set autoPlayNext(bool value) {
    _autoPlayNext = value;
    notifyListeners();
  }

  // 定时结束控制
  TtsTimerConfig _timerConfig = TtsTimerConfig();
  TtsTimerConfig get timerConfig => _timerConfig;

  // 定时完成StreamController
  final StreamController<TtsTimerConfig> _timerCompleteController =
      StreamController<TtsTimerConfig>.broadcast();
  Stream<TtsTimerConfig> get onTimerComplete => _timerCompleteController.stream;

  TtsPlayerService() {
    _initTtsListeners();
    _loadSettings();
  }

  /// 初始化TTS事件监听
  void _initTtsListeners() {
    // 监听朗读开始
    _speakingSubscription = _tts.isSpeaking.listen((isSpeaking) {
      if (isSpeaking && _state != TtsPlayerState.playing) {
        _setState(TtsPlayerState.playing);
      }
    });

    // 监听朗读完成
    _completeSubscription = _tts.onSpeakComplete.listen((_) {
      _onParagraphComplete();
    });

    // 监听错误
    _errorSubscription = _tts.onError.listen((error) {
      _setError(error);
    });
  }

  /// 加载保存的设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _speechRate = prefs.getDouble('tts_speech_rate') ?? 1.0;
      _pitch = prefs.getDouble('tts_pitch') ?? 1.0;
      debugPrint('[TtsPlayerService] 加载设置: 语速=$_speechRate, 音调=$_pitch');
    } catch (e) {
      debugPrint('[TtsPlayerService] 加载设置失败: $e');
    }
  }

  /// 初始化播放器（从指定章节开始）
  Future<bool> initializeWithNovel({
    required Novel novel,
    required List<Chapter> chapters,
    required Chapter startChapter,
    String? startContent,
  }) async {
    try {
      _setState(TtsPlayerState.loading);
      _errorMessage = null;

      // 初始化TTS引擎
      if (!_tts.isInitialized) {
        final initialized = await _tts.initialize();
        if (!initialized) {
          _setError('TTS引擎初始化失败');
          return false;
        }
      }

      // 设置小说信息
      _novel = novel;
      _allChapters = chapters;
      _currentChapter = startChapter;
      _currentChapterIndex = chapters.indexWhere((c) => c.url == startChapter.url);

      if (_currentChapterIndex == -1) {
        _setError('未找到起始章节');
        return false;
      }

      // 加载章节内容
      final content = startContent ?? await _loadChapterContent(startChapter);
      if (content == null || content.isEmpty) {
        _setError('章节内容为空');
        return false;
      }

      // 分割段落
      _paragraphs = _parseParagraphs(content);
      _currentParagraphIndex = 0;

      // 应用保存的语速和音调
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);

      _setState(TtsPlayerState.idle);
      debugPrint('[TtsPlayerService] 初始化完成: ${startChapter.title}');
      return true;
    } catch (e) {
      _setError('初始化失败: $e');
      return false;
    }
  }

  /// 跳转到指定章节
  Future<bool> jumpToChapter(Chapter targetChapter) async {
    try {
      // 停止当前播放
      await stop();

      // 找到目标章节索引
      final targetIndex = _allChapters.indexWhere((c) => c.url == targetChapter.url);
      if (targetIndex == -1) {
        _setError('未找到目标章节');
        return false;
      }

      // 加载目标章节
      final content = await _loadChapterContent(targetChapter);
      if (content == null || content.isEmpty) {
        _setError('目标章节内容为空');
        return false;
      }

      // 更新状态
      _currentChapter = targetChapter;
      _currentChapterIndex = targetIndex;
      _paragraphs = _parseParagraphs(content);
      _currentParagraphIndex = 0;

      debugPrint('[TtsPlayerService] 跳转到章节: ${targetChapter.title}');
      notifyListeners();
      return true;
    } catch (e) {
      _setError('跳转章节失败: $e');
      return false;
    }
  }

  /// 开始播放
  Future<void> play() async {
    if (_state == TtsPlayerState.playing) return;

    try {
      _setState(TtsPlayerState.playing);

      if (currentParagraph != null) {
        await _tts.speak(currentParagraph!);
        await _saveProgress();
      }
    } catch (e) {
      _setError('播放失败: $e');
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    if (_state != TtsPlayerState.playing) return;

    try {
      await _tts.pause();
      _setState(TtsPlayerState.paused);
      await _saveProgress();
    } catch (e) {
      debugPrint('[TtsPlayerService] 暂停失败: $e');
    }
  }

  /// 继续播放
  Future<void> resume() async {
    if (_state != TtsPlayerState.paused) return;

    try {
      await _tts.resume();
      _setState(TtsPlayerState.playing);
    } catch (e) {
      _setError('继续播放失败: $e');
    }
  }

  /// 停止播放
  Future<void> stop() async {
    try {
      await _tts.stop();
      _setState(TtsPlayerState.idle);
    } catch (e) {
      debugPrint('[TtsPlayerService] 停止失败: $e');
    }
  }

  /// 跳转到指定段落
  Future<void> jumpToParagraph(int index) async {
    if (index < 0 || index >= _paragraphs.length) return;

    try {
      // 停止当前播放
      await stop();

      _currentParagraphIndex = index;
      notifyListeners();
      debugPrint('[TtsPlayerService] 跳转到段落: $index');
    } catch (e) {
      _setError('跳转段落失败: $e');
    }
  }

  /// 上一段
  Future<void> previousParagraph() async {
    if (_currentParagraphIndex > 0) {
      await jumpToParagraph(_currentParagraphIndex - 1);
      await play();
    }
  }

  /// 下一段
  Future<void> nextParagraph() async {
    if (_currentParagraphIndex < _paragraphs.length - 1) {
      await jumpToParagraph(_currentParagraphIndex + 1);
      await play();
    }
  }

  /// 设置语速
  Future<void> setSpeechRate(double rate) async {
    if (rate < 0.5 || rate > 2.0) return;

    _speechRate = rate;
    await _tts.setSpeechRate(rate);

    // 保存设置
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tts_speech_rate', rate);

    notifyListeners();
  }

  /// 设置音调
  Future<void> setPitch(double pitch) async {
    if (pitch < 0.5 || pitch > 2.0) return;

    _pitch = pitch;
    await _tts.setPitch(pitch);

    // 保存设置
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tts_pitch', pitch);

    notifyListeners();
  }

  /// 段落完成处理
  Future<void> _onParagraphComplete() async {
    debugPrint('[TtsPlayerService] 📢 段落完成回调触发: $_currentParagraphIndex/${_paragraphs.length}');

    // 移动到下一段
    _currentParagraphIndex++;
    debugPrint('[TtsPlayerService] ⏭️ 切换到段落: $_currentParagraphIndex');
    notifyListeners();

    // 检查是否还有段落
    if (_currentParagraphIndex < _paragraphs.length) {
      // 继续播放下一段
      if (_autoPlayNext) {
        final nextParagraph = _paragraphs[_currentParagraphIndex];
        debugPrint('[TtsPlayerService] 🎤 准备朗读下一段: ${nextParagraph.substring(0, nextParagraph.length > 30 ? 30 : nextParagraph.length)}...');

        // 短暂延迟后继续播放
        await Future.delayed(const Duration(milliseconds: 100));

        // 在播放前确保状态为playing
        if (_state != TtsPlayerState.playing) {
          _setState(TtsPlayerState.playing);
        }

        await _tts.speak(nextParagraph);
        await _saveProgress();
        debugPrint('[TtsPlayerService] ✅ 已启动下一段朗读');
      } else {
        debugPrint('[TtsPlayerService] ⏸️ 自动播放已关闭，暂停');
        _setState(TtsPlayerState.paused);
      }
    } else {
      // 章节完成，尝试加载下一章
      debugPrint('[TtsPlayerService] 📖 章节所有段落已完成');
      await _onChapterComplete();
    }
  }

  /// 章节完成处理
  Future<void> _onChapterComplete() async {
    debugPrint('[TtsPlayerService] 章节完成: ${_currentChapter?.title}');

    // 优先检查定时完成
    if (_timerConfig.enabled) {
      final completed = _timerConfig.getCompletedChapters(_currentChapterIndex);
      debugPrint('[TtsPlayerService] ⏰ 定时检查: 已完成$completed章/${_timerConfig.chapterCount}章');

      if (completed >= _timerConfig.chapterCount) {
        await _onTimerComplete();
        return;
      }
    }

    // 检查是否还有下一章
    if (_currentChapterIndex < _allChapters.length - 1) {
      if (_autoPlayNext) {
        await _loadNextChapter();
      } else {
        _setState(TtsPlayerState.completed);
      }
    } else {
      // 全部完成
      _setState(TtsPlayerState.completed);
      await _clearProgress();
    }
  }

  /// 加载下一章
  Future<void> _loadNextChapter() async {
    try {
      _setState(TtsPlayerState.loading);

      final nextIndex = _currentChapterIndex + 1;
      final nextChapter = _allChapters[nextIndex];

      debugPrint('[TtsPlayerService] 加载下一章: ${nextChapter.title}');

      // 加载内容
      final content = await _loadChapterContent(nextChapter);
      if (content == null || content.isEmpty) {
        _setError('下一章内容加载失败');
        return;
      }

      // 更新状态
      _currentChapter = nextChapter;
      _currentChapterIndex = nextIndex;
      _paragraphs = _parseParagraphs(content);
      _currentParagraphIndex = 0;

      notifyListeners();

      // 继续播放
      await Future.delayed(const Duration(milliseconds: 500));
      await _tts.speak(_paragraphs[0]);
      _setState(TtsPlayerState.playing);
      await _saveProgress();
    } catch (e) {
      _setError('加载下一章失败: $e');
    }
  }

  /// 加载章节内容
  Future<String?> _loadChapterContent(Chapter chapter) async {
    try {
      // 先尝试从数据库获取
      final cached = await _database.getChapterContent(chapter.url);
      if (cached.isNotEmpty) {
        debugPrint('[TtsPlayerService] 使用缓存: ${chapter.title}');
        return cached;
      }

      // 从API获取
      debugPrint('[TtsPlayerService] 从API加载: ${chapter.title}');
      final content = await _api.getChapterContent(chapter.url);

      // 缓存到数据库
      await _database.updateChapterContent(chapter.url, content);

      return content;
    } catch (e) {
      debugPrint('[TtsPlayerService] 加载章节内容失败: $e');
      return null;
    }
  }

  /// 解析段落
  List<String> _parseParagraphs(String content) {
    return content
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .where((p) => !_isMarkupParagraph(p))
        .toList();
  }

  /// 检查是否为标记段落
  bool _isMarkupParagraph(String paragraph) {
    return paragraph.startsWith('[插图:') ||
           paragraph.startsWith('[视频:') ||
           paragraph.startsWith('[图片:');
  }

  /// 设置状态
  void _setState(TtsPlayerState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
      debugPrint('[TtsPlayerService] 状态变更: $newState');
    }
  }

  /// 设置错误
  void _setError(String error) {
    _errorMessage = error;
    _setState(TtsPlayerState.error);
    debugPrint('[TtsPlayerService] 错误: $error');
  }

  /// 保存进度
  Future<void> _saveProgress() async {
    if (_novel == null || _currentChapter == null) return;

    try {
      final progress = ReadingProgress(
        novelUrl: _novel!.url,
        novelTitle: _novel!.title,
        chapterUrl: _currentChapter!.url,
        chapterTitle: _currentChapter!.title,
        paragraphIndex: _currentParagraphIndex,
        speechRate: _speechRate,
        pitch: _pitch,
        timestamp: DateTime.now(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_progressKey, progress.toJsonString());

      debugPrint('[TtsPlayerService] 保存进度: $progress');
    } catch (e) {
      debugPrint('[TtsPlayerService] 保存进度失败: $e');
    }
  }

  /// 清除进度
  Future<void> _clearProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_progressKey);
      debugPrint('[TtsPlayerService] 清除进度');
    } catch (e) {
      debugPrint('[TtsPlayerService] 清除进度失败: $e');
    }
  }

  /// 加载保存的进度
  static Future<ReadingProgress?> loadSavedProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_progressKey);
      if (jsonString == null) return null;

      final progress = ReadingProgress.fromJsonString(jsonString);
      if (progress == null) return null;

      // 检查是否过期
      if (progress.isExpired()) {
        debugPrint('[TtsPlayerService] 进度已过期，已清除');
        await prefs.remove(_progressKey);
        return null;
      }

      debugPrint('[TtsPlayerService] 加载进度: $progress');
      return progress;
    } catch (e) {
      debugPrint('[TtsPlayerService] 加载进度失败: $e');
      return null;
    }
  }

  /// 检查是否有下一章
  bool get hasNextChapter => _currentChapterIndex < _allChapters.length - 1;

  /// 检查是否有上一章
  bool get hasPreviousChapter => _currentChapterIndex > 0;

  /// 获取总进度（百分比）
  double get totalProgress {
    if (_allChapters.isEmpty) return 0.0;

    final completedChapters = _currentChapterIndex;
    final chapterProgress = _paragraphs.isEmpty
        ? 0.0
        : _currentParagraphIndex / _paragraphs.length;

    return (completedChapters + chapterProgress) / _allChapters.length;
  }

  /// 设置定时
  ///
  /// [chapterCount] 读多少章后停止（1-99）
  Future<void> setTimer(int chapterCount) async {
    if (chapterCount < 1 || chapterCount > 99) {
      debugPrint('[TtsPlayerService] ⚠️ 无效的章节数: $chapterCount');
      return;
    }

    _timerConfig = TtsTimerConfig(
      enabled: true,
      chapterCount: chapterCount,
      startChapterIndex: _currentChapterIndex,
    );

    notifyListeners();
    debugPrint('[TtsPlayerService] ⏰ 已设置定时: 从第${_currentChapterIndex + 1}章开始，读$chapterCount章后停止');
  }

  /// 取消定时
  Future<void> cancelTimer() async {
    if (!_timerConfig.enabled) {
      debugPrint('[TtsPlayerService] 定时未启用，无需取消');
      return;
    }

    _timerConfig.reset();
    notifyListeners();
    debugPrint('[TtsPlayerService] ⏰ 已取消定时');
  }

  /// 定时完成处理
  Future<void> _onTimerComplete() async {
    final completed = _timerConfig.getCompletedChapters(_currentChapterIndex);
    debugPrint('[TtsPlayerService] ⏰ 定时完成: 已完成$completed章');

    // 暂停播放
    await pause();

    // 触发定时完成事件（通过Stream通知UI）
    if (!_timerCompleteController.isClosed) {
      _timerCompleteController.add(_timerConfig);
    }
  }

  @override
  void dispose() {
    _speakingSubscription?.cancel();
    _completeSubscription?.cancel();
    _errorSubscription?.cancel();
    _timerCompleteController.close();
    _tts.dispose();
    super.dispose();
  }
}
