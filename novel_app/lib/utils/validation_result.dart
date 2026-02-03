/// 表单验证结果封装类
///
/// 用于封装表单验证的结果，包含验证状态、错误消息和错误字段信息。
///
/// 使用示例：
/// ```dart
/// // 成功结果
/// final success = ValidationResult.success();
/// if (success.isValid) {
///   print('验证通过');
/// }
///
/// // 失败结果
/// final failure = ValidationResult.failure('用户名不能为空', field: 'username');
/// if (!failure.isValid) {
///   print('验证失败: ${failure.errorMessage}');
/// }
/// ```
class ValidationResult {
  /// 验证是否通过
  final bool isValid;

  /// 错误消息（验证失败时）
  final String? errorMessage;

  /// 错误字段名称（可选）
  final String? field;

  /// 额外的错误详情（可选）
  final Map<String, dynamic>? details;

  /// 私有构造函数
  const ValidationResult._({
    required this.isValid,
    this.errorMessage,
    this.field,
    this.details,
  });

  /// 创建验证成功的结果
  ///
  /// 返回一个表示验证通过的 ValidationResult 对象
  const factory ValidationResult.success() = ValidationResult._success;

  /// 创建验证成功的结果（私有实现）
  const ValidationResult._success() : this._(isValid: true);

  /// 创建验证失败的结果
  ///
  /// [message] 错误消息
  /// [field] 错误字段名称（可选）
  /// [details] 额外的错误详情（可选）
  ///
  /// 返回一个表示验证失败的 ValidationResult 对象
  factory ValidationResult.failure(
    String message, {
    String? field,
    Map<String, dynamic>? details,
  }) {
    return ValidationResult._(
      isValid: false,
      errorMessage: message,
      field: field,
      details: details,
    );
  }

  /// 合并多个验证结果
  ///
  /// [results] 要合并的验证结果列表
  ///
  /// 如果所有结果都成功，返回成功；否则返回第一个失败的错误
  /// 返回合并后的 ValidationResult 对象
  static ValidationResult merge(List<ValidationResult> results) {
    for (final result in results) {
      if (!result.isValid) {
        return result;
      }
    }
    return const ValidationResult._success();
  }

  /// 获取完整的错误信息（包含字段名）
  ///
  /// 如果有字段名，返回 "字段名: 错误消息" 格式
  /// 否则只返回错误消息
  String get fullErrorMessage {
    if (field != null && errorMessage != null) {
      return '$field: $errorMessage';
    }
    return errorMessage ?? '';
  }

  @override
  String toString() {
    if (isValid) {
      return 'ValidationResult.success()';
    }
    return 'ValidationResult.failure($fullErrorMessage)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ValidationResult &&
        other.isValid == isValid &&
        other.errorMessage == errorMessage &&
        other.field == field;
  }

  @override
  int get hashCode => Object.hash(isValid, errorMessage, field);
}

/// 表单验证规则接口
///
/// 所有验证规则都需要实现此接口
abstract class ValidationRule {
  /// 验证给定的值
  ///
  /// [value] 要验证的值
  /// [fieldName] 字段名称（用于错误消息）
  ///
  /// 返回验证结果
  ValidationResult validate(String value, {String? fieldName});
}

/// 非空验证规则
///
/// 验证字符串不为空或仅包含空白字符
class RequiredRule implements ValidationRule {
  /// 自定义错误消息
  final String? customMessage;

  /// 是否允许纯空白字符
  final bool allowWhitespace;

  const RequiredRule({
    this.customMessage,
    this.allowWhitespace = false,
  });

  @override
  ValidationResult validate(String value, {String? fieldName}) {
    final isEmpty = allowWhitespace ? value.isEmpty : value.trim().isEmpty;

    if (isEmpty) {
      return ValidationResult.failure(
        customMessage ?? '${fieldName ?? "此字段"}不能为空',
        field: fieldName,
      );
    }

    return ValidationResult.success();
  }
}

/// 长度验证规则
///
/// 验证字符串长度在指定范围内
class LengthRule implements ValidationRule {
  /// 最小长度（null表示不限制）
  final int? minLength;

  /// 最大长度（null表示不限制）
  final int? maxLength;

  /// 自定义错误消息
  final String? customMessage;

  const LengthRule({
    this.minLength,
    this.maxLength,
    this.customMessage,
  }) : assert(minLength != null || maxLength != null);

  @override
  ValidationResult validate(String value, {String? fieldName}) {
    final length = value.length;

    if (minLength != null && length < minLength!) {
      return ValidationResult.failure(
        customMessage ?? '${fieldName ?? "此字段"}长度不能少于$minLength个字符',
        field: fieldName,
        details: {'actualLength': length, 'minLength': minLength},
      );
    }

    if (maxLength != null && length > maxLength!) {
      return ValidationResult.failure(
        customMessage ?? '${fieldName ?? "此字段"}长度不能超过$maxLength个字符',
        field: fieldName,
        details: {'actualLength': length, 'maxLength': maxLength},
      );
    }

    return ValidationResult.success();
  }
}

/// 正则表达式验证规则
///
/// 使用正则表达式验证字符串格式
class RegexRule implements ValidationRule {
  /// 正则表达式
  final RegExp regex;

  /// 错误消息
  final String errorMessage;

  const RegexRule(this.regex, this.errorMessage);

  @override
  ValidationResult validate(String value, {String? fieldName}) {
    if (!regex.hasMatch(value)) {
      return ValidationResult.failure(
        errorMessage,
        field: fieldName,
      );
    }

    return ValidationResult.success();
  }
}

/// URL验证规则
///
/// 验证字符串是否为有效的URL
class UrlRule extends RegexRule {
  /// 是否要求必须有协议（http/https）
  final bool requireProtocol;

  UrlRule({
    this.requireProtocol = true,
    String? customMessage,
  }) : super(
          _buildRegex(requireProtocol),
          customMessage ?? '请输入有效的URL地址',
        );

  static RegExp _buildRegex(bool requireProtocol) {
    if (requireProtocol) {
      return RegExp(
        r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&\/=]*)$',
      );
    } else {
      return RegExp(
        r'^(https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&\/=]*)$',
      );
    }
  }
}

/// 数字验证规则
///
/// 验证字符串是否为有效的数字格式
class NumberRule implements ValidationRule {
  /// 是否允许小数
  final bool allowDecimal;

  /// 是否允许负数
  final bool allowNegative;

  /// 自定义错误消息
  final String? customMessage;

  const NumberRule({
    this.allowDecimal = true,
    this.allowNegative = false,
    this.customMessage,
  });

  @override
  ValidationResult validate(String value, {String? fieldName}) {
    final regex = RegExp(
      allowDecimal
          ? (allowNegative ? r'^-?\d+(\.\d+)?$' : r'^\d+(\.\d+)?$')
          : (allowNegative ? r'^-?\d+$' : r'^\d+$'),
    );

    if (!regex.hasMatch(value)) {
      return ValidationResult.failure(
        customMessage ?? '请输入有效的${allowNegative ? "（可为负数）" : ""}数字',
        field: fieldName,
      );
    }

    return ValidationResult.success();
  }
}

/// 邮箱验证规则
///
/// 验证字符串是否为有效的邮箱地址
class EmailRule extends RegexRule {
  EmailRule({String? customMessage})
      : super(
          RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$'),
          customMessage ?? '请输入有效的邮箱地址',
        );
}

/// 范围验证规则（仅限数字）
///
/// 验证数字在指定范围内
class RangeRule implements ValidationRule {
  /// 最小值（null表示不限制）
  final num? minValue;

  /// 最大值（null表示不限制）
  final num? maxValue;

  /// 自定义错误消息
  final String? customMessage;

  const RangeRule({
    this.minValue,
    this.maxValue,
    this.customMessage,
  }) : assert(minValue != null || maxValue != null);

  @override
  ValidationResult validate(String value, {String? fieldName}) {
    final number = num.tryParse(value);

    if (number == null) {
      return ValidationResult.failure(
        '请输入有效的数字',
        field: fieldName,
      );
    }

    if (minValue != null && number < minValue!) {
      return ValidationResult.failure(
        customMessage ?? '${fieldName ?? "此字段"}不能小于$minValue',
        field: fieldName,
        details: {'actualValue': number, 'minValue': minValue},
      );
    }

    if (maxValue != null && number > maxValue!) {
      return ValidationResult.failure(
        customMessage ?? '${fieldName ?? "此字段"}不能大于$maxValue',
        field: fieldName,
        details: {'actualValue': number, 'maxValue': maxValue},
      );
    }

    return ValidationResult.success();
  }
}

/// 自定义验证规则
///
/// 允许使用自定义函数进行验证
class CustomRule implements ValidationRule {
  /// 验证函数
  final String? Function(String value) validator;

  /// 错误字段名称
  final String? fieldName;

  const CustomRule(this.validator, {this.fieldName});

  @override
  ValidationResult validate(String value, {String? fieldName}) {
    final effectiveFieldName = fieldName ?? this.fieldName;
    final error = validator(value);

    if (error != null) {
      return ValidationResult.failure(
        error,
        field: effectiveFieldName,
      );
    }

    return ValidationResult.success();
  }
}

/// 集合验证规则
///
/// 验证集合（如List、Set）不为空
class CollectionNotEmptyRule<T> implements ValidationRule {
  /// 自定义错误消息
  final String? customMessage;

  const CollectionNotEmptyRule({this.customMessage});

  @override
  ValidationResult validate(String value, {String? fieldName}) {
    // 此规则主要用于验证集合，此处提供兼容性实现
    return ValidationResult.success();
  }

  /// 验证集合
  ValidationResult validateCollection(Iterable<T>? collection,
      {String? fieldName}) {
    if (collection == null || collection.isEmpty) {
      return ValidationResult.failure(
        customMessage ?? '${fieldName ?? "此字段"}不能为空',
        field: fieldName,
      );
    }

    return ValidationResult.success();
  }
}

/// 防重复验证规则
///
/// 验证值在给定的集合中不存在重复
class UniqueRule implements ValidationRule {
  /// 现有的值列表
  final List<String> existingValues;

  /// 自定义错误消息
  final String? customMessage;

  /// 是否区分大小写
  final bool caseSensitive;

  const UniqueRule(
    this.existingValues, {
    this.customMessage,
    this.caseSensitive = true,
  });

  @override
  ValidationResult validate(String value, {String? fieldName}) {
    final normalizedValue = caseSensitive ? value : value.toLowerCase();

    final hasDuplicate = existingValues.any((existing) {
      final normalizedExisting =
          caseSensitive ? existing : existing.toLowerCase();
      return normalizedExisting == normalizedValue;
    });

    if (hasDuplicate) {
      return ValidationResult.failure(
        customMessage ?? '${fieldName ?? "此值"}已存在，请使用其他值',
        field: fieldName,
      );
    }

    return ValidationResult.success();
  }
}

/// 密码强度验证规则
///
/// 验证密码满足基本安全要求
class PasswordStrengthRule implements ValidationRule {
  /// 最小长度
  final int minLength;

  /// 是否要求包含大写字母
  final bool requireUppercase;

  /// 是否要求包含小写字母
  final bool requireLowercase;

  /// 是否要求包含数字
  final bool requireNumber;

  /// 是否要求包含特殊字符
  final bool requireSpecialChar;

  const PasswordStrengthRule({
    this.minLength = 8,
    this.requireUppercase = true,
    this.requireLowercase = true,
    this.requireNumber = true,
    this.requireSpecialChar = false,
  });

  @override
  ValidationResult validate(String value, {String? fieldName}) {
    final errors = <String>[];

    if (value.length < minLength) {
      errors.add('密码长度不能少于$minLength位');
    }

    if (requireUppercase && !value.contains(RegExp(r'[A-Z]'))) {
      errors.add('密码必须包含至少一个大写字母');
    }

    if (requireLowercase && !value.contains(RegExp(r'[a-z]'))) {
      errors.add('密码必须包含至少一个小写字母');
    }

    if (requireNumber && !value.contains(RegExp(r'[0-9]'))) {
      errors.add('密码必须包含至少一个数字');
    }

    if (requireSpecialChar &&
        !value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add('密码必须包含至少一个特殊字符');
    }

    if (errors.isNotEmpty) {
      return ValidationResult.failure(
        errors.join('；'),
        field: fieldName,
        details: {'errors': errors},
      );
    }

    return ValidationResult.success();
  }
}

/// 中文字符验证规则
///
/// 验证字符串只包含中文字符
class ChineseOnlyRule extends RegexRule {
  ChineseOnlyRule({String? customMessage})
      : super(
          RegExp(r'^[\u4e00-\u9fa5]+$'),
          customMessage ?? '只能输入中文字符',
        );
}

/// 手机号验证规则（中国大陆）
///
/// 验证字符串是否为有效的中国大陆手机号
class ChinesePhoneRule extends RegexRule {
  ChinesePhoneRule({String? customMessage})
      : super(
          RegExp(r'^1[3-9]\d{9}$'),
          customMessage ?? '请输入有效的手机号码',
        );
}

/// 身份证号验证规则（中国大陆）
///
/// 验证字符串是否为有效的中国大陆身份证号
class ChineseIdCardRule implements ValidationRule {
  /// 自定义错误消息
  final String? customMessage;

  const ChineseIdCardRule({this.customMessage});

  @override
  ValidationResult validate(String value, {String? fieldName}) {
    // 15位或18位身份证号正则
    final regex = RegExp(r'^\d{15}$|^\d{17}[\dXx]$');

    if (!regex.hasMatch(value)) {
      return ValidationResult.failure(
        customMessage ?? '请输入有效的身份证号',
        field: fieldName,
      );
    }

    // 18位身份证校验码验证
    if (value.length == 18) {
      final factors = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2];
      final checkCodes = [
        '1',
        '0',
        'X',
        '9',
        '8',
        '7',
        '6',
        '5',
        '4',
        '3',
        '2'
      ];

      var sum = 0;
      for (var i = 0; i < 17; i++) {
        sum += int.parse(value[i]) * factors[i];
      }

      final checkCode = checkCodes[sum % 11];
      if (value[17].toUpperCase() != checkCode) {
        return ValidationResult.failure(
          customMessage ?? '身份证号校验码错误',
          field: fieldName,
        );
      }
    }

    return ValidationResult.success();
  }
}

/// 日期格式验证规则
///
/// 验证字符串是否符合指定的日期格式
class DateFormatRule implements ValidationRule {
  /// 日期格式（支持 yyyy-MM-dd、yyyy/MM/dd 等）
  final String format;

  /// 自定义错误消息
  final String? customMessage;

  const DateFormatRule(
    this.format, {
    this.customMessage,
  });

  @override
  ValidationResult validate(String value, {String? fieldName}) {
    try {
      final regex = _buildRegex(format);
      if (!regex.hasMatch(value)) {
        return ValidationResult.failure(
          customMessage ?? '请输入正确的日期格式（$format）',
          field: fieldName,
        );
      }

      // 尝试解析日期
      final parts = value.split(RegExp(r'[-/\.]'));
      if (parts.length != 3) {
        return ValidationResult.failure(
          customMessage ?? '日期格式错误',
          field: fieldName,
        );
      }

      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      if (month < 1 || month > 12) {
        return ValidationResult.failure(
          '月份必须在1-12之间',
          field: fieldName,
        );
      }

      if (day < 1 || day > 31) {
        return ValidationResult.failure(
          '日期必须在1-31之间',
          field: fieldName,
        );
      }

      // 简单验证日期有效性
      final date = DateTime(year, month, day);
      if (date.year != year || date.month != month || date.day != day) {
        return ValidationResult.failure(
          '日期不存在',
          field: fieldName,
        );
      }

      return ValidationResult.success();
    } catch (e) {
      return ValidationResult.failure(
        customMessage ?? '日期格式错误',
        field: fieldName,
      );
    }
  }

  RegExp _buildRegex(String format) {
    // 支持常见的日期分隔符
    final separatorPattern = r'[-/\.]';
    final year = r'(\d{4})';
    final month = r'(0[1-9]|1[0-2])';
    final day = r'(0[1-9]|[12]\d|3[01])';

    if (format.contains('yyyy') &&
        format.contains('MM') &&
        format.contains('dd')) {
      return RegExp('^$year$separatorPattern$month$separatorPattern$day\$');
    }

    throw ArgumentError('不支持的日期格式: $format');
  }
}
