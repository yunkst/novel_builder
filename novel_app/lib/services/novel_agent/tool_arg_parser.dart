/// Agent 工具参数安全解析器
///
/// 将 LLM 返回的 `Map<String, dynamic>` 参数按类型安全提取，
/// 消除 ToolExecutor 中所有 `as int` / `as String` 强转导致的 TypeError 崩溃。
///
/// 设计原则：
/// - 每个提取方法返回 (value, error?) 的 record
/// - error 为 null 表示成功，非 null 表示失败（JSON 格式错误信息）
/// - error 格式与 ToolExecutor 现有的错误自引导一致（含 error + message）
/// - 支持 double→int 自动转换（LLM 有时返回 3.0 而非 3）
/// - 可选参数缺失时返回 (null, null)，类型错误时返回 (null, error)
library;

import 'dart:convert';

class ToolArgParser {
  final Map<String, dynamic> args;

  ToolArgParser(this.args);

  // ══════════════════════════════════════
  // 必填参数
  // ══════════════════════════════════════

  /// 提取必填 String 参数
  ///
  /// - null 或缺失 → 错误
  /// - 非 String 类型 → 错误
  /// - 空字符串（trim 后） → 错误
  /// - 正常 → 返回 trim 后的值
  (String, String?) requireString(String key) {
    if (!args.containsKey(key) || args[key] == null) {
      return ('', _missingError(key));
    }
    final v = args[key];
    if (v is! String) {
      return ('', _typeError(key, 'string', v.runtimeType));
    }
    final trimmed = v.trim();
    if (trimmed.isEmpty) {
      return ('', _emptyError(key));
    }
    return (trimmed, null);
  }

  /// 提取必填 int 参数
  ///
  /// - null 或缺失 → 错误
  /// - int → 直接返回
  /// - double → 自动 toInt()（LLM 有时返回 3.0 而非 3）
  /// - 其他类型 → 错误
  (int, String?) requireInt(String key) {
    if (!args.containsKey(key) || args[key] == null) {
      return (0, _missingError(key));
    }
    final v = args[key];
    if (v is int) return (v, null);
    if (v is double) return (v.toInt(), null);
    // String 数字如 "3" 也尝试解析
    if (v is String) {
      final parsed = int.tryParse(v);
      if (parsed != null) return (parsed, null);
    }
    return (0, _typeError(key, 'int', v.runtimeType));
  }

  // ══════════════════════════════════════
  // 可选参数
  // ══════════════════════════════════════

  /// 提取可选 int 参数
  ///
  /// - 缺失或 null → (null, null)
  /// - int → 直接返回
  /// - double → 自动 toInt()
  /// - String 数字 → 尝试解析
  /// - 其他类型 → (null, error)
  (int?, String?) optionalInt(String key) {
    if (!args.containsKey(key) || args[key] == null) return (null, null);
    final v = args[key];
    if (v is int) return (v, null);
    if (v is double) return (v.toInt(), null);
    if (v is String) {
      final parsed = int.tryParse(v);
      if (parsed != null) return (parsed, null);
    }
    return (null, _typeError(key, 'int', v.runtimeType));
  }

  /// 提取可选 String 参数
  ///
  /// - 缺失或 null → (null, null)
  /// - 非 String → (null, error)
  /// - String → 返回 trim 后的值（空字符串也允许）
  (String?, String?) optionalString(String key) {
    if (!args.containsKey(key) || args[key] == null) return (null, null);
    final v = args[key];
    if (v is! String) return (null, _typeError(key, 'string', v.runtimeType));
    return (v.trim(), null);
  }

  /// 提取可空 String 参数（用于 description 等可选但可空的字段）
  ///
  /// - 缺失 → 返回 null
  /// - null → 返回 null
  /// - 非 String → (null, error)
  /// - String → 返回 trim 后的值（空字符串返回 null）
  (String?, String?) nullableString(String key) {
    if (!args.containsKey(key) || args[key] == null) return (null, null);
    final v = args[key];
    if (v is! String) return (null, _typeError(key, 'string', v.runtimeType));
    final trimmed = v.trim();
    return (trimmed.isEmpty ? null : trimmed, null);
  }

  // ══════════════════════════════════════
  // 错误构造
  // ══════════════════════════════════════

  static String _missingError(String key) => jsonEncode({
        'error': 'missing_required_param',
        'message': '缺少必填参数 "$key"',
        'param': key,
      });

  static String _typeError(String key, String expected, Type actual) =>
      jsonEncode({
        'error': 'param_type_error',
        'message': '参数 "$key" 类型错误：期望 $expected，实际 $actual',
        'param': key,
      });

  static String _emptyError(String key) => jsonEncode({
        'error': 'empty_param',
        'message': '参数 "$key" 不能为空',
        'param': key,
      });
}
