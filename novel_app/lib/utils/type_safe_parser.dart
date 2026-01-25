import 'package:flutter/foundation.dart';

/// 类型安全的解析辅助类
///
/// 提供安全的 Map 访问和类型转换方法，避免运行时类型转换错误
class TypeSafeParser {
  /// 安全地从Map获取字符串
  ///
  /// 如果值不存在或类型不匹配，返回 null
  static String? getString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  /// 安全地从Map获取整数
  ///
  /// 支持从 int, num, String 类型解析整数
  static int? getInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// 安全地从Map获取布尔值
  ///
  /// 支持从 bool, int, String 类型解析布尔值
  static bool? getBool(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
    }
    return null;
  }

  /// 安全地从Map获取double
  ///
  /// 支持从 double, num, String 类型解析浮点数
  static double? getDouble(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// 安全地从Map获取List
  ///
  /// [converter] 可选的元素转换函数
  /// 如果类型不匹配或转换失败，返回 null
  static List<T>? getList<T>(
    Map<String, dynamic> map,
    String key, {
    T Function(dynamic)? converter,
  }) {
    final value = map[key];
    if (value == null) return null;
    if (value is! List) return null;

    try {
      return value
          .map((e) => converter?.call(e) ?? e as T)
          .toList();
    } catch (e) {
      debugPrint('⚠️ List<$T> 解析失败: $e');
      return null;
    }
  }

  /// 安全地从Map获取Map
  ///
  /// 用于嵌套Map的安全访问
  static Map<String, dynamic>? getMap(
    Map<String, dynamic> map,
    String key,
  ) {
    final value = map[key];
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  /// 安全地从Map获取DateTime
  ///
  /// 支持从 DateTime, int (毫秒), String (ISO8601) 类型解析
  static DateTime? getDateTime(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;

    if (value is DateTime) return value;

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
