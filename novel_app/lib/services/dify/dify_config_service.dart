import '../preferences_service.dart';

/// 配置服务 - 仅保留 DSL Engine 之外仍需要的 AI 设定项。
class DifyConfigService {
  /// 获取 AI 作家设定（仍在工作流 inputs 中使用）
  Future<String> getAiWriterSetting() async {
    return await PreferencesService.instance
        .getString('ai_writer_prompt', defaultValue: '');
  }

  /// 写入 AI 作家设定
  Future<void> setAiWriterSetting(String value) async {
    await PreferencesService.instance.setString('ai_writer_prompt', value);
  }
}