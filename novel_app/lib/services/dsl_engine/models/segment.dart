/// 强类型 Segment 体系，忠实复现 Dify graphon/variables/variables.py 的 Segment 设计。
///
/// 每个 Segment 包装一个强类型值，支持 toObject() 序列化和 text 属性。
library;

// -- Segment 基类 --

/// Segment 基类。所有变量值都包装为 Segment。
sealed class Segment {
  const Segment();

  /// 转为可用于 JSON 序列化的原生 Dart 对象。
  dynamic toObject();

  /// 纯文本表示。非文本类型返回 null（由调用方决定降级策略）。
  String? get text;
}

// -- 具体类型 --

class StringSegment extends Segment {
  final String value;
  const StringSegment({required this.value});

  @override
  dynamic toObject() => value;

  @override
  String get text => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StringSegment && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'StringSegment($value)';
}

class IntegerSegment extends Segment {
  final int value;
  const IntegerSegment({required this.value});

  @override
  dynamic toObject() => value;

  @override
  String? get text => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntegerSegment && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class FloatSegment extends Segment {
  final double value;
  const FloatSegment({required this.value});

  @override
  dynamic toObject() => value;

  @override
  String? get text => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FloatSegment && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class BooleanSegment extends Segment {
  final bool value;
  const BooleanSegment({required this.value});

  @override
  dynamic toObject() => value;

  @override
  String? get text => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BooleanSegment && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class ObjectSegment extends Segment {
  final Map<String, dynamic> value;
  const ObjectSegment({required this.value});

  @override
  dynamic toObject() => value;

  @override
  String? get text => null; // Object 没有 text 表示

  /// 获取嵌套属性。支持 [field1, field2, ...] 深层穿透。
  Segment? getField(List<String> path) {
    dynamic current = value;
    for (final key in path) {
      if (current is! Map<String, dynamic>) return null;
      if (!current.containsKey(key)) return null;
      current = current[key];
    }
    return segmentFromValue(current);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectSegment && runtimeType == other.runtimeType && _mapEquals(value, other.value);

  @override
  int get hashCode => value.hashCode;

  static bool _mapEquals(Map a, Map b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

class ArrayStringSegment extends Segment {
  final List<String> value;
  const ArrayStringSegment({required this.value});

  @override
  dynamic toObject() => value;

  @override
  String? get text => null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArrayStringSegment &&
          runtimeType == other.runtimeType &&
          _listEquals(value, other.value);

  @override
  int get hashCode => Object.hashAll(value);

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class ArrayObjectSegment extends Segment {
  final List<Map<String, dynamic>> value;
  const ArrayObjectSegment({required this.value});

  @override
  dynamic toObject() => value;

  @override
  String? get text => null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ArrayObjectSegment && runtimeType == other.runtimeType;

  @override
  int get hashCode => Object.hashAll(value);
}

class FileSegment extends Segment {
  final String url;
  final String mimeType;
  const FileSegment({required this.url, this.mimeType = 'image/png'});

  @override
  dynamic toObject() => {'url': url, 'mime_type': mimeType};

  @override
  String? get text => null;
}

class NoneSegment extends Segment {
  const NoneSegment();

  @override
  dynamic toObject() => null;

  @override
  String? get text => null;
}

// -- 辅助工具 --

/// SegmentGroup：convertTemplate 的返回值，包含有序的 Segment 列表。
class SegmentGroup {
  final List<Segment> segments;

  const SegmentGroup({required this.segments});

  /// 拼接所有 segment 的文本（NoneSegment/FileSegment 贡献空串）。
  String get text {
    final buffer = StringBuffer();
    for (final seg in segments) {
      buffer.write(seg.text ?? '');
    }
    return buffer.toString();
  }
}

/// 从任意 Dart 值自动推断并创建 Segment。
Segment segmentFromValue(dynamic value) {
  if (value == null) return const NoneSegment();
  if (value is String) return StringSegment(value: value);
  if (value is int) return IntegerSegment(value: value);
  if (value is double) return FloatSegment(value: value);
  if (value is bool) return BooleanSegment(value: value);
  if (value is Map<String, dynamic>) return ObjectSegment(value: value);
  if (value is List<String>) return ArrayStringSegment(value: value);
  if (value is List<Map<String, dynamic>>) {
    return ArrayObjectSegment(value: value);
  }
  if (value is List) {
    // 泛型 List → 尝试推断元素类型
    if (value.isEmpty) return const ArrayStringSegment(value: []);
    if (value.first is Map) {
      return ArrayObjectSegment(
          value: value.cast<Map<String, dynamic>>());
    }
    return ArrayStringSegment(value: value.cast<String>());
  }
  // 兜底：转字符串
  return StringSegment(value: value.toString());
}
