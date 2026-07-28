/// GitHub Star 引导服务。
///
/// 管理 4 个 SharedPreferences key，控制启动时的 star 弹窗门槛与冷却：
/// - `star_prompt_install_time` (int ms 时间戳) 首次启动记录
/// - `star_prompt_launch_count` (int) 启动次数计数
/// - `star_prompt_dismissed` (bool) true = 永久不再弹（主按钮触发）
/// - `star_prompt_next_show_time` (int ms 时间戳) 下次允许弹窗时间（关闭按钮写）
///
/// 单例（仿 [NativeCrashReporter]），用 [PreferencesService.instance] 持久化。
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'preferences_service.dart';

class StarPromptService {
  StarPromptService._();

  static final StarPromptService instance = StarPromptService._();

  // preferences key（spec 固定字面值，不改）
  static const String _kInstallTime = 'star_prompt_install_time';
  static const String _kLaunchCount = 'star_prompt_launch_count';
  static const String _kDismissed = 'star_prompt_dismissed';
  static const String _kNextShowTime = 'star_prompt_next_show_time';

  // 门槛常量（spec 固定字面值，不改）
  static const int _launchThreshold = 7;
  static const int _installDaysThreshold = 3;
  static const int _cooldownDays = 7;
  static const int _msPerDay = 86400000;

  /// 测试用：清全部 4 个 key + 重新初始化。
  Future<void> resetForTest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kInstallTime);
    await prefs.remove(_kLaunchCount);
    await prefs.remove(_kDismissed);
    await prefs.remove(_kNextShowTime);
  }

  /// 启动时调用：首次写 install_time + count=1；非首次 count++。
  Future<void> recordLaunch() async {
    final prefs = await PreferencesService.instance.getInstance();
    final hasInstallTime = prefs.containsKey(_kInstallTime);
    if (!hasInstallTime) {
      await PreferencesService.instance.setInt(
        _kInstallTime,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
    final current = await PreferencesService.instance.getInt(_kLaunchCount);
    await PreferencesService.instance.setInt(_kLaunchCount, current + 1);
  }
}
