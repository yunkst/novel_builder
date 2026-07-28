import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/services/star_prompt_service.dart';
import 'package:novel_app/services/preferences_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StarPromptService.instance.resetForTest();
  });

  test('recordLaunch 首次启动写入 install_time + count=1', () async {
    final beforeMs = DateTime.now().millisecondsSinceEpoch;
    await StarPromptService.instance.recordLaunch();
    final afterMs = DateTime.now().millisecondsSinceEpoch;

    final installTime = await PreferencesService.instance.getInt(
      'star_prompt_install_time',
    );
    final count = await PreferencesService.instance.getInt(
      'star_prompt_launch_count',
    );

    expect(installTime, greaterThanOrEqualTo(beforeMs));
    expect(installTime, lessThanOrEqualTo(afterMs));
    expect(count, 1);
  });

  test('recordLaunch 非首次启动 count 累加 + install_time 不变', () async {
    // 模拟已有状态：install_time 是昨天，count=3
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'star_prompt_install_time': yesterday,
      'star_prompt_launch_count': 3,
    });

    await StarPromptService.instance.recordLaunch();

    final installTime = await PreferencesService.instance.getInt(
      'star_prompt_install_time',
    );
    final count = await PreferencesService.instance.getInt(
      'star_prompt_launch_count',
    );

    expect(installTime, yesterday);
    expect(count, 4);
  });
}
