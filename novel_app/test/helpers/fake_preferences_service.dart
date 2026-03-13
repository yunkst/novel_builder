/// PreferencesService 的 Fake 实现，用于测试
class FakePreferencesService {
  /// 存储模拟的键值对
  final Map<String, dynamic> _fakeStorage = {};

  /// 获取字符串值
  ///
  /// 如果键不存在或值为null，返回 [defaultValue]
  Future<String> getString(String key, {String defaultValue = ''}) async {
    if (!_fakeStorage.containsKey(key)) {
      return defaultValue;
    }

    final value = _fakeStorage[key];
    if (value is String) {
      return value;
    } else if (value != null) {
      return value.toString();
    }

    return defaultValue;
  }

  /// 设置字符串值
  Future<bool> setString(String key, String value) async {
    _fakeStorage[key] = value;
    return true;
  }

  /// 获取整数值
  ///
  /// 如果键不存在或值为null，返回 [defaultValue]
  Future<int> getInt(String key, {int defaultValue = 0}) async {
    if (!_fakeStorage.containsKey(key)) {
      return defaultValue;
    }

    final value = _fakeStorage[key];
    if (value is int) {
      return value;
    } else if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    } else if (value is double) {
      return value.toInt();
    }

    return defaultValue;
  }

  /// 设置整数值
  Future<bool> setInt(String key, int value) async {
    _fakeStorage[key] = value;
    return true;
  }

  /// 获取双精度浮点数值
  ///
  /// 如果键不存在或值为null，返回 [defaultValue]
  Future<double> getDouble(String key, {double defaultValue = 0.0}) async {
    if (!_fakeStorage.containsKey(key)) {
      return defaultValue;
    }

    final value = _fakeStorage[key];
    if (value is double) {
      return value;
    } else if (value is int) {
      return value.toDouble();
    } else if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }

    return defaultValue;
  }

  /// 设置双精度浮点数值
  Future<bool> setDouble(String key, double value) async {
    _fakeStorage[key] = value;
    return true;
  }

  /// 获取布尔值
  ///
  /// 如果键不存在或值为null，返回 [defaultValue]
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    if (!_fakeStorage.containsKey(key)) {
      return defaultValue;
    }

    final value = _fakeStorage[key];
    if (value is bool) {
      return value;
    } else if (value is String) {
      return value.toLowerCase() == 'true';
    } else if (value is int) {
      return value == 1;
    }

    return defaultValue;
  }

  /// 设置布尔值
  Future<bool> setBool(String key, bool value) async {
    _fakeStorage[key] = value;
    return true;
  }

  /// 获取字符串列表值
  ///
  /// 如果键不存在或值为null，返回 [defaultValue]
  Future<List<String>> getStringList(String key,
      {List<String> defaultValue = const []}) async {
    if (!_fakeStorage.containsKey(key)) {
      return defaultValue;
    }

    final value = _fakeStorage[key];
    if (value is List<String>) {
      return value;
    } else if (value is List) {
      return value.whereType<String>().toList();
    }

    return defaultValue;
  }

  /// 设置字符串列表值
  Future<bool> setStringList(String key, List<String> value) async {
    _fakeStorage[key] = List.from(value);
    return true;
  }

  /// 检查键是否存在
  Future<bool> containsKey(String key) async {
    return _fakeStorage.containsKey(key);
  }

  /// 删除指定键
  Future<bool> remove(String key) async {
    _fakeStorage.remove(key);
    return true;
  }

  /// 清空所有偏好设置
  Future<bool> clear() async {
    _fakeStorage.clear();
    return true;
  }

  /// 获取所有键
  Future<Set<String>> getKeys() async {
    return _fakeStorage.keys.toSet();
  }

  /// 批量设置多个值
  ///
  /// 返回成功设置的键数量
  Future<int> setMultiple(Map<String, dynamic> values) async {
    int successCount = 0;

    for (final entry in values.entries) {
      final value = entry.value;

      if (value is String ||
          value is int ||
          value is double ||
          value is bool ||
          value is List<String>) {
        _fakeStorage[entry.key] = value;
        successCount++;
      }
    }

    return successCount;
  }

  /// 批量获取多个值
  ///
  /// 返回键值对映射，不存在的键不会出现在结果中
  Future<Map<String, dynamic>> getMultiple(Set<String> keys) async {
    final result = <String, dynamic>{};

    for (final key in keys) {
      final value = _fakeStorage[key];
      if (value != null) {
        result[key] = value;
      }
    }

    return result;
  }
}
