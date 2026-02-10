import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'validation_result.dart';

/// 表单验证器
///
/// 提供链式API的表单验证工具，支持多规则组合和自定义错误消息。
///
/// 使用示例：
/// ```dart
/// // 基础验证
/// final result = FormValidator.validate('username', 'John')
///     .required()
///     .minLength(3)
///     .maxLength(20)
///     .result();
///
/// if (result.isValid) {
///   print('验证通过');
/// } else {
///   print(result.errorMessage);
/// }
///
/// // URL验证
/// final urlResult = FormValidator.validate('url', 'https://example.com')
///     .required()
///     .url()
///     .result();
///
/// // 自定义验证
/// final customResult = FormValidator.validate('age', '25')
///     .required()
///     .number()
///     .range(min: 18, max: 100)
///     .result();
/// ```
class FormValidator {
  /// 字段名称
  final String? fieldName;

  /// 要验证的值
  final String? value;

  /// 验证规则列表
  final List<ValidationRule> _rules = [];

  /// 是否已执行验证
  bool _validated = false;

  /// 验证结果
  ValidationResult? _result;

  /// 私有构造函数
  FormValidator._({
    this.fieldName,
    this.value,
  });

  /// 创建验证器实例
  ///
  /// [fieldName] 字段名称（用于错误消息）
  /// [value] 要验证的值
  ///
  /// 返回 FormValidator 实例
  static FormValidator validate(String? fieldName, String? value) {
    return FormValidator._(
      fieldName: fieldName,
      value: value,
    );
  }

  /// 添加非空验证
  ///
  /// [message] 自定义错误消息
  /// [allowWhitespace] 是否允许纯空白字符
  ///
  /// 返回当前验证器实例（支持链式调用）
  FormValidator required({String? message, bool allowWhitespace = false}) {
    _rules.add(RequiredRule(
      customMessage: message,
      allowWhitespace: allowWhitespace,
    ));
    return this;
  }

  /// 添加最小长度验证
  ///
  /// [length] 最小长度
  /// [message] 自定义错误消息
  ///
  /// 返回当前验证器实例（支持链式调用）
  FormValidator minLength(int length, {String? message}) {
    _rules.add(LengthRule(
      minLength: length,
      customMessage: message,
    ));
    return this;
  }

  /// 添加最大长度验证
  ///
  /// [length] 最大长度
  /// [message] 自定义错误消息
  ///
  /// 返回当前验证器实例（支持链式调用）
  FormValidator maxLength(int length, {String? message}) {
    _rules.add(LengthRule(
      maxLength: length,
      customMessage: message,
    ));
    return this;
  }

  /// 添加长度范围验证
  ///
  /// [min] 最小长度
  /// [max] 最大长度
  /// [message] 自定义错误消息
  ///
  /// 返回当前验证器实例（支持链式调用）
  FormValidator lengthRange(int min, int max, {String? message}) {
    _rules.add(LengthRule(
      minLength: min,
      maxLength: max,
      customMessage: message,
    ));
    return this;
  }

  /// 添加URL验证
  ///
  /// [requireProtocol] 是否要求必须有协议（http/https）
  /// [message] 自定义错误消息
  ///
  /// 返回当前验证器实例（支持链式调用）
  FormValidator url({bool requireProtocol = true, String? message}) {
    _rules.add(UrlRule(
      requireProtocol: requireProtocol,
      customMessage: message,
    ));
    return this;
  }

  /// 添加数字验证
  ///
  /// [allowDecimal] 是否允许小数
  /// [allowNegative] 是否允许负数
  /// [message] 自定义错误消息
  ///
  /// 返回当前验证器实例（支持链式调用）
  FormValidator number({
    bool allowDecimal = true,
    bool allowNegative = false,
    String? message,
  }) {
    _rules.add(NumberRule(
      allowDecimal: allowDecimal,
      allowNegative: allowNegative,
      customMessage: message,
    ));
    return this;
  }

  /// 添加数字范围验证
  ///
  /// [min] 最小值
  /// [max] 最大值
  /// [message] 自定义错误消息
  ///
  /// 返回当前验证器实例（支持链式调用）
  FormValidator range({num? min, num? max, String? message}) {
    _rules.add(RangeRule(
      minValue: min,
      maxValue: max,
      customMessage: message,
    ));
    return this;
  }

  /// 添加邮箱验证
  ///
  /// [message] 自定义错误消息
  ///
  /// 返回当前验证器实例（支持链式调用）
  FormValidator email({String? message}) {
    _rules.add(EmailRule(customMessage: message));
    return this;
  }

  /// 添加正则表达式验证
  ///
  /// [regex] 正则表达式
  /// [message] 错误消息
  ///
  /// 返回当前验证器实例（支持链式调用）
  FormValidator regex(RegExp regex, String message) {
    _rules.add(RegexRule(regex, message));
    return this;
  }

  /// 添加自定义验证规则
  ///
  /// [validator] 验证函数，返回错误消息或null（表示验证通过）
  ///
  /// 返回当前验证器实例（支持链式调用）
  FormValidator custom(String? Function(String value) validator) {
    _rules.add(CustomRule(validator, fieldName: fieldName));
    return this;
  }

  /// 添加防重复验证
  ///
  /// [existingValues] 现有的值列表
  /// [message] 自定义错误消息
  /// [caseSensitive] 是否区分大小写
  ///
  /// 返回当前验证器实例（支持链式调用）
  FormValidator unique(
    List<String> existingValues, {
    String? message,
    bool caseSensitive = true,
  }) {
    _rules.add(UniqueRule(
      existingValues,
      customMessage: message,
      caseSensitive: caseSensitive,
    ));
    return this;
  }

  /// 添加密码强度验证
  ///
  /// [minLength] 最小长度
  /// [requireUppercase] 是否要求包含大写字母
  /// [requireLowercase] 是否要求包含小写字母
  /// [requireNumber] 是否要求包含数字
  /// [requireSpecialChar] 是否要求包含特殊字符
  ///
  /// 返回当前验证器实例（支持链式调用）
  FormValidator password({
    int minLength = 8,
    bool requireUppercase = true,
    bool requireLowercase = true,
    bool requireNumber = true,
    bool requireSpecialChar = false,
  }) {
    _rules.add(PasswordStrengthRule(
      minLength: minLength,
      requireUppercase: requireUppercase,
      requireLowercase: requireLowercase,
      requireNumber: requireNumber,
      requireSpecialChar: requireSpecialChar,
    ));
    return this;
  }

  /// 添加中文字符验证
  ///
  /// [message] 自定义错误消息
  ///
  /// 返回当前验证器实例（支持链式调用）
  FormValidator chineseOnly({String? message}) {
    _rules.add(ChineseOnlyRule(customMessage: message));
    return this;
  }

  /// 添加手机号验证（中国大陆）
  ///
  /// [message] 自定义错误消息
  ///
  /// 返回当前验证器实例（支持链式调用）
  FormValidator phone({String? message}) {
    _rules.add(ChinesePhoneRule(customMessage: message));
    return this;
  }

  /// 添加身份证号验证（中国大陆）
  ///
  /// [message] 自定义错误消息
  ///
  /// 返回当前验证器实例（支持链式调用）
  FormValidator idCard({String? message}) {
    _rules.add(ChineseIdCardRule(customMessage: message));
    return this;
  }

  /// 添加日期格式验证
  ///
  /// [format] 日期格式（如 'yyyy-MM-dd'）
  /// [message] 自定义错误消息
  ///
  /// 返回当前验证器实例（支持链式调用）
  FormValidator dateFormat(String format, {String? message}) {
    _rules.add(DateFormatRule(format, customMessage: message));
    return this;
  }

  /// 执行验证并返回结果
  ///
  /// 返回 ValidationResult 对象
  ValidationResult result() {
    if (_validated) {
      return _result ?? ValidationResult.success();
    }

    _validated = true;

    // 如果值为null或为空，立即返回非空验证结果
    if (value == null || value!.isEmpty) {
      // 检查是否有required规则
      final hasRequired = _rules.any((rule) => rule is RequiredRule);
      if (hasRequired) {
        _result = RequiredRule().validate('', fieldName: fieldName);
        return _result!;
      }
    }

    // 执行所有验证规则
    final effectiveValue = value ?? '';
    for (final rule in _rules) {
      final result = rule.validate(effectiveValue, fieldName: fieldName);
      if (!result.isValid) {
        _result = result;
        return _result!;
      }
    }

    _result = ValidationResult.success();
    return _result!;
  }

  /// 重置验证器状态
  ///
  /// 允许重新使用验证器进行新的验证
  void reset() {
    _validated = false;
    _result = null;
  }

  /// 获取错误消息（验证失败时）
  ///
  /// 如果验证通过或尚未验证，返回null
  String? get errorMessage {
    if (!_validated) {
      result();
    }
    return _result?.errorMessage;
  }

  /// 获取完整的错误消息（包含字段名）
  ///
  /// 如果验证通过或尚未验证，返回null
  String? get fullErrorMessage {
    if (!_validated) {
      result();
    }
    return _result?.fullErrorMessage;
  }

  /// 检查是否验证通过
  bool get isValid {
    if (!_validated) {
      result();
    }
    return _result?.isValid ?? false;
  }
}

/// 多字段表单验证器
///
/// 用于验证多个字段的表单
class FormValidatorGroup {
  /// 验证器映射
  final Map<String, FormValidator> _validators = {};

  /// 添加字段验证器
  ///
  /// [fieldName] 字段名称
  /// [value] 字段值
  ///
  /// 返回 FormValidator 实例用于配置验证规则
  FormValidator field(String fieldName, String? value) {
    final validator = FormValidator.validate(fieldName, value);
    _validators[fieldName] = validator;
    return validator;
  }

  /// 执行所有字段的验证
  ///
  /// [stopOnFirstError] 是否在第一个错误时停止验证
  ///
  /// 返回验证结果，如果所有字段都验证通过，返回成功结果
  ValidationResult validateAll({bool stopOnFirstError = true}) {
    final results = <ValidationResult>[];

    for (final entry in _validators.entries) {
      final result = entry.value.result();
      results.add(result);

      if (stopOnFirstError && !result.isValid) {
        return result;
      }
    }

    return ValidationResult.merge(results);
  }

  /// 获取所有错误消息
  ///
  /// 返回字段名到错误消息的映射
  Map<String, String> getAllErrors() {
    final errors = <String, String>{};

    for (final entry in _validators.entries) {
      if (!entry.value.isValid) {
        final errorMsg = entry.value.fullErrorMessage;
        if (errorMsg != null && errorMsg.isNotEmpty) {
          errors[entry.key] = errorMsg;
        }
      }
    }

    return errors;
  }

  /// 获取第一个错误消息
  ///
  /// 如果没有错误，返回null
  String? getFirstError() {
    for (final validator in _validators.values) {
      if (!validator.isValid) {
        return validator.fullErrorMessage;
      }
    }
    return null;
  }

  /// 检查所有字段是否都验证通过
  bool get isAllValid {
    return _validators.values.every((v) => v.isValid);
  }

  /// 重置所有验证器状态
  void resetAll() {
    for (final validator in _validators.values) {
      validator.reset();
    }
  }
}

/// TextFormField 验证混入类
///
/// 提供与 Flutter TextFormField 集成的便捷方法
mixin TextFormFieldValidationMixin {
  /// 创建验证函数用于TextFormField
  ///
  /// [validator] FormValidator实例
  ///
  /// 返回适用于TextFormField的验证函数
  String? Function(String?) createValidator(FormValidator validator) {
    return (value) {
      validator.reset();
      final result = validator.result();
      return result.errorMessage;
    };
  }

  /// 创建自动验证的TextFormField
  ///
  /// [controller] 文本控制器
  /// [validator] FormValidator实例
  /// [onChanged] 值变化回调
  /// [decoration] 输入框装饰
  /// [keyboardType] 键盘类型
  /// [textInputAction] 键盘操作
  /// [enabled] 是否启用
  /// [maxLines] 最大行数
  /// [minLines] 最小行数
  /// [maxLength] 最大长度
  /// [obscureText] 是否隐藏文本
  /// [autofocus] 是否自动聚焦
  ///
  /// 返回配置好的TextFormField
  Widget validatedTextField({
    required TextEditingController controller,
    required FormValidator validator,
    void Function(String)? onChanged,
    InputDecoration? decoration,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool enabled = true,
    int maxLines = 1,
    int? minLines,
    int? maxLength,
    bool obscureText = false,
    bool autofocus = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      decoration: decoration,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      enabled: enabled,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      obscureText: obscureText,
      autofocus: autofocus,
      inputFormatters: inputFormatters,
      validator: createValidator(validator),
      onChanged: (value) {
        validator.reset();
        onChanged?.call(value);
      },
    );
  }
}

/// 快速验证工具类
///
/// 提供常用的快速验证方法
class QuickValidator {
  /// 快速验证非空
  static String? required(String? value, {String? message}) {
    return FormValidator.validate(null, value)
        .required(message: message)
        .result()
        .errorMessage;
  }

  /// 快速验证邮箱
  static String? email(String? value, {String? message}) {
    return FormValidator.validate('邮箱', value)
        .required(message: message)
        .email()
        .result()
        .errorMessage;
  }

  /// 快速验证URL
  static String? url(String? value, {String? message}) {
    return FormValidator.validate('URL', value)
        .required(message: message)
        .url()
        .result()
        .errorMessage;
  }

  /// 快速验证数字
  static String? number(String? value, {String? message}) {
    return FormValidator.validate('数值', value)
        .required(message: message)
        .number()
        .result()
        .errorMessage;
  }

  /// 快速验证手机号
  static String? phone(String? value, {String? message}) {
    return FormValidator.validate('手机号', value)
        .required(message: message)
        .phone()
        .result()
        .errorMessage;
  }

  /// 快速验证身份证号
  static String? idCard(String? value, {String? message}) {
    return FormValidator.validate('身份证号', value)
        .required(message: message)
        .idCard()
        .result()
        .errorMessage;
  }

  /// 快速验证长度范围
  static String? lengthRange(
    String? value,
    int min,
    int max, {
    String? fieldName,
    String? message,
  }) {
    return FormValidator.validate(fieldName, value)
        .required(message: message)
        .lengthRange(min, max)
        .result()
        .errorMessage;
  }

  /// 快速验证角色名称（防重复）
  static String? characterName(
    String? value,
    List<String> existingNames, {
    String? message,
  }) {
    return FormValidator.validate('角色名称', value)
        .required(message: message)
        .minLength(2)
        .maxLength(20)
        .unique(existingNames, message: message)
        .result()
        .errorMessage;
  }
}
