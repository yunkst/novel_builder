import 'package:shared_preferences/shared_preferences.dart';

/// 统一的偏好设置服务
///
/// 提供类型安全的 SharedPreferences 读写操作，替代重复的代码。
/// 使用单例模式，确保全局唯一实例。
///
/// 使用方式：
/// ```dart
/// // 获取值
/// final value = await PreferencesService.instance.getString('key');
/// final num = await PreferencesService.instance.getInt('number');
///
/// // 设置值
/// await PreferencesService.instance.setString('key', 'value');
/// await PreferencesService.instance.setInt('number', 42);
///
/// // 检查键是否存在
/// final hasKey = await PreferencesService.instance.containsKey('key');
///
/// // 删除键
/// await PreferencesService.instance.remove('key');
///
/// // 清空所有
/// await PreferencesService.instance.clear();
/// ```
class PreferencesService {
  // ========== 单例模式 ==========
  static final PreferencesService _instance = PreferencesService._internal();

  /// 单例实例
  static PreferencesService get instance => _instance;

  factory PreferencesService() => _instance;
  PreferencesService._internal();

  // ========== 公开方法 ==========

  /// 获取字符串值
  ///
  /// 如果键不存在或值为null，返回 [defaultValue]
  Future<String> getString(String key, {String defaultValue = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) ?? defaultValue;
  }

  /// 设置字符串值
  Future<bool> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(key, value);
  }

  /// 获取整数值
  ///
  /// 如果键不存在或值为null，返回 [defaultValue]
  Future<int> getInt(String key, {int defaultValue = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? defaultValue;
  }

  /// 设置整数值
  Future<bool> setInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setInt(key, value);
  }

  /// 获取双精度浮点数值
  ///
  /// 如果键不存在或值为null，返回 [defaultValue]
  Future<double> getDouble(String key, {double defaultValue = 0.0}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(key) ?? defaultValue;
  }

  /// 设置双精度浮点数值
  Future<bool> setDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setDouble(key, value);
  }

  /// 获取布尔值
  ///
  /// 如果键不存在或值为null，返回 [defaultValue]
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  /// 设置布尔值
  Future<bool> setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(key, value);
  }

  /// 获取字符串列表值
  ///
  /// 如果键不存在或值为null，返回 [defaultValue]
  Future<List<String>> getStringList(String key,
      {List<String> defaultValue = const []}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? defaultValue;
  }

  /// 设置字符串列表值
  Future<bool> setStringList(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setStringList(key, value);
  }

  /// 检查键是否存在
  Future<bool> containsKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(key);
  }

  /// 删除指定键
  Future<bool> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(key);
  }

  /// 清空所有偏好设置
  Future<bool> clear() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.clear();
  }

  /// 获取所有键
  Future<Set<String>> getKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys();
  }

  /// 批量设置多个值
  ///
  /// 返回成功设置的键数量
  Future<int> setMultiple(Map<String, dynamic> values) async {
    final prefs = await SharedPreferences.getInstance();
    int successCount = 0;

    for (final entry in values.entries) {
      bool result = false;
      final value = entry.value;

      if (value is String) {
        result = await prefs.setString(entry.key, value);
      } else if (value is int) {
        result = await prefs.setInt(entry.key, value);
      } else if (value is double) {
        result = await prefs.setDouble(entry.key, value);
      } else if (value is bool) {
        result = await prefs.setBool(entry.key, value);
      } else if (value is List<String>) {
        result = await prefs.setStringList(entry.key, value);
      }

      if (result) successCount++;
    }

    return successCount;
  }

  /// 批量获取多个值
  ///
  /// 返回键值对映射，不存在的键不会出现在结果中
  Future<Map<String, dynamic>> getMultiple(Set<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, dynamic>{};

    for (final key in keys) {
      final value = prefs.get(key);
      if (value != null) {
        result[key] = value;
      }
    }

    return result;
  }
}
