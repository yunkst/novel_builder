import 'package:flutter/services.dart';

/// 输入格式化工具类
///
/// 提供常用的输入格式化器，用于限制和格式化用户输入。
///
/// 使用示例：
/// ```dart
/// TextField(
///   inputFormatters: [
///     InputFormatter.limitLength(10),
///     InputFormatter.decimalsOnly(2),
///   ],
/// )
/// ```
class InputFormatter {
  // 私有构造函数，防止实例化
  InputFormatter._();

  /// 限制输入长度
  ///
  /// [maxLength] 最大长度
  ///
  /// 返回长度限制格式化器
  static LengthLimitingTextInputFormatter limitLength(int maxLength) {
    return LengthLimitingTextInputFormatter(maxLength);
  }

  /// 仅允许数字输入
  ///
  /// 返回数字过滤格式化器
  static TextInputFormatter digitsOnly({bool allowNegative = false}) {
    return FilteringTextInputFormatter.allow(
      RegExp(allowNegative ? r'^-?\d*' : r'\d*'),
    );
  }

  /// 仅允许小数输入
  ///
  /// [decimalDigits] 小数位数，null表示不限制
  ///
  /// 返回小数过滤格式化器
  static TextInputFormatter decimalsOnly({int? decimalDigits}) {
    return DecimalTextInputFormatter(decimalDigits: decimalDigits);
  }

  /// 仅允许字母输入
  ///
  /// [allowUppercase] 是否允许大写字母
  /// [allowLowercase] 是否允许小写字母
  ///
  /// 返回字母过滤格式化器
  static TextInputFormatter lettersOnly({
    bool allowUppercase = true,
    bool allowLowercase = true,
  }) {
    String pattern;
    if (allowUppercase && allowLowercase) {
      pattern = r'[a-zA-Z]*';
    } else if (allowUppercase) {
      pattern = r'[A-Z]*';
    } else {
      pattern = r'[a-z]*';
    }
    return FilteringTextInputFormatter.allow(RegExp(pattern));
  }

  /// 仅允许字母和数字输入
  ///
  /// 返回字母数字过滤格式化器
  static TextInputFormatter alphanumeric() {
    return FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]*'));
  }

  /// 仅允许中文字符输入
  ///
  /// 返回中文过滤格式化器
  static TextInputFormatter chineseOnly() {
    return FilteringTextInputFormatter.allow(RegExp(r'[\u4e00-\u9fa5]*'));
  }

  /// 仅允许十六进制字符输入
  ///
  /// 返回十六进制过滤格式化器
  static TextInputFormatter hexOnly() {
    return FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]*'));
  }

  /// 仅允许有效URL字符输入
  ///
  /// 返回URL字符过滤格式化器
  static TextInputFormatter urlCharacters() {
    return FilteringTextInputFormatter.allow(
      RegExp(r'''[a-zA-Z0-9\-._~:/?#[\]@!$&'()*+,;=%]*'''),
    );
  }

  /// 仅允许邮箱字符输入
  ///
  /// 返回邮箱字符过滤格式化器
  static TextInputFormatter emailCharacters() {
    return FilteringTextInputFormatter.allow(
      RegExp(r'[a-zA-Z0-9._@+-]*'),
    );
  }

  /// 仅允许手机号数字输入（中国大陆）
  ///
  /// 返回手机号过滤格式化器
  static TextInputFormatter phoneDigits() {
    return FilteringTextInputFormatter.allow(RegExp(r'[0-9]*'));
  }

  /// 过滤特定字符
  ///
  /// [forbiddenChars] 要禁止的字符列表
  ///
  /// 返回字符过滤格式化器
  static TextInputFormatter forbidChars(List<String> forbiddenChars) {
    final pattern = '[${RegExp.escape(forbiddenChars.join())}]*';
    return FilteringTextInputFormatter.deny(RegExp(pattern));
  }

  /// 仅允许大写字母输入
  ///
  /// 返回大写字母过滤格式化器
  static TextInputFormatter uppercaseOnly() {
    return FilteringTextInputFormatter.allow(RegExp(r'[A-Z]*'));
  }

  /// 仅允许小写字母输入
  ///
  /// 返回小写字母过滤格式化器
  static TextInputFormatter lowercaseOnly() {
    return FilteringTextInputFormatter.allow(RegExp(r'[a-z]*'));
  }

  /// 自动转大写格式化器
  ///
  /// 返回自动转大写格式化器
  static TextInputFormatter toUppercase() {
    return _UpperCaseTextFormatter();
  }

  /// 自动转小写格式化器
  ///
  /// 返回自动转小写格式化器
  static TextInputFormatter toLowercase() {
    return _LowerCaseTextFormatter();
  }

  /// 自动添加千位分隔符格式化器
  ///
  /// 返回千位分隔符格式化器
  static TextInputFormatter thousandSeparator() {
    return _ThousandSeparatorFormatter();
  }

  /// 自动格式化手机号（中国大陆）
  ///
  /// 格式: 138 1234 5678
  ///
  /// 返回手机号格式化器
  static TextInputFormatter phoneFormatter() {
    return _PhoneFormatter();
  }

  /// 自动格式化身份证号（中国大陆）
  ///
  /// 格式: 123456 1990 01 01 1234
  ///
  /// 返回身份证号格式化器
  static TextInputFormatter idCardFormatter() {
    return _IdCardFormatter();
  }

  /// 自动格式化银行卡号
  ///
  /// 每4位添加空格
  ///
  /// 返回银行卡号格式化器
  static TextInputFormatter bankCardFormatter() {
    return _BankCardFormatter();
  }

  /// 自动格式化日期（YYYY-MM-DD）
  ///
  /// 返回日期格式化器
  static TextInputFormatter dateFormatter() {
    return _DateFormatter();
  }

  /// 自动格式化时间（HH:mm:ss）
  ///
  /// 返回时间格式化器
  static TextInputFormatter timeFormatter() {
    return _TimeFormatter();
  }

  /// 自动格式化金额（保留2位小数）
  ///
  /// 返回金额格式化器
  static TextInputFormatter currencyFormatter() {
    return _CurrencyFormatter();
  }

  /// 自动格式化百分比（0-100）
  ///
  /// 返回百分比格式化器
  static TextInputFormatter percentFormatter() {
    return _PercentFormatter();
  }

  /// 正则表达式过滤器
  ///
  /// [pattern] 允许的正则表达式
  /// [allow] 是否为允许模式（true）或拒绝模式（false）
  ///
  /// 返回正则过滤格式化器
  static TextInputFormatter regex(
    String pattern, {
    bool allow = true,
  }) {
    return FilteringTextInputFormatter(
      RegExp(pattern),
      allow: allow,
    );
  }

  /// 组合格式化器
  ///
  /// [formatters] 要组合的格式化器列表
  ///
  /// 返回组合后的格式化器
  static List<TextInputFormatter> combine(
    List<TextInputFormatter> formatters,
  ) {
    return formatters;
  }

  /// 创建自定义格式化器
  ///
  /// [formatter] 格式化函数
  ///
  /// 返回自定义格式化器
  static TextInputFormatter custom(
    TextEditingValue Function(
      TextEditingValue oldValue,
      TextEditingValue newValue,
    ) formatter,
  ) {
    return _CustomFormatter(formatter);
  }
}

/// 小数输入格式化器
///
/// 限制输入为小数格式，并控制小数位数
class DecimalTextInputFormatter extends TextInputFormatter {
  /// 小数位数
  final int? decimalDigits;

  DecimalTextInputFormatter({this.decimalDigits});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // 允许空值
    if (text.isEmpty) {
      return newValue;
    }

    // 允许负号开头
    if (text == '-' || text == '+') {
      return newValue;
    }

    // 检查是否为有效的小数格式
    final regex = RegExp(r'^-?\d*\.?\d*$');
    if (!regex.hasMatch(text)) {
      return oldValue;
    }

    // 检查小数点数量
    final dotCount = '.'.allMatches(text).length;
    if (dotCount > 1) {
      return oldValue;
    }

    // 检查小数位数
    if (decimalDigits != null) {
      final parts = text.split('.');
      if (parts.length == 2 && parts[1].length > decimalDigits!) {
        return oldValue;
      }
    }

    return newValue;
  }
}

/// 大写转换格式化器
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: newValue.composing,
    );
  }
}

/// 小写转换格式化器
class _LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toLowerCase(),
      selection: newValue.selection,
      composing: newValue.composing,
    );
  }
}

/// 千位分隔符格式化器
class _ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 移除所有非数字字符
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.isEmpty) {
      return TextEditingValue.empty;
    }

    // 添加千位分隔符
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// 手机号格式化器（138 1234 5678）
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.isEmpty) {
      return TextEditingValue.empty;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 11; i++) {
      buffer.write(digits[i]);
      if (i == 2 || i == 6) {
        if (i < digits.length - 1) {
          buffer.write(' ');
        }
      }
    }

    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// 身份证号格式化器（123456 1990 01 01 1234）
class _IdCardFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.isEmpty) {
      return TextEditingValue.empty;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 18; i++) {
      buffer.write(digits[i]);
      if (i == 5 || i == 9 || i == 11 || i == 13) {
        if (i < digits.length - 1) {
          buffer.write(' ');
        }
      }
    }

    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// 银行卡号格式化器（每4位添加空格）
class _BankCardFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.isEmpty) {
      return TextEditingValue.empty;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// 日期格式化器（YYYY-MM-DD）
class _DateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.isEmpty) {
      return TextEditingValue.empty;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 8; i++) {
      buffer.write(digits[i]);
      if (i == 3 || i == 5) {
        if (i < digits.length - 1) {
          buffer.write('-');
        }
      }
    }

    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// 时间格式化器（HH:mm:ss）
class _TimeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.isEmpty) {
      return TextEditingValue.empty;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 6; i++) {
      buffer.write(digits[i]);
      if (i == 1 || i == 3) {
        if (i < digits.length - 1) {
          buffer.write(':');
        }
      }
    }

    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// 金额格式化器（保留2位小数，自动添加千位分隔符）
class _CurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');

    if (text.isEmpty) {
      return TextEditingValue.empty;
    }

    // 处理小数部分
    final parts = text.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';

    // 限制小数位数为2位
    if (decimalPart.length > 2) {
      decimalPart = decimalPart.substring(0, 2);
    }

    // 添加千位分隔符
    final buffer = StringBuffer();
    for (int i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(integerPart[i]);
    }

    final formatted = buffer.toString();

    // 组合整数和小数部分
    final result = decimalPart.isEmpty ? formatted : '$formatted.$decimalPart';

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

/// 百分比格式化器（0-100，自动添加%）
class _PercentFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');

    if (text.isEmpty) {
      return TextEditingValue.empty;
    }

    // 处理小数部分
    final parts = text.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';

    // 限制小数位数为2位
    if (decimalPart.length > 2) {
      decimalPart = decimalPart.substring(0, 2);
    }

    // 限制整数部分为0-100
    if (integerPart.isNotEmpty) {
      final intValue = int.tryParse(integerPart) ?? 0;
      if (intValue > 100) {
        integerPart = '100';
      }
    }

    // 组合整数和小数部分
    final result =
        decimalPart.isEmpty ? integerPart : '$integerPart.$decimalPart';

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

/// 自定义格式化器
class _CustomFormatter extends TextInputFormatter {
  final TextEditingValue Function(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) formatter;

  _CustomFormatter(this.formatter);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return formatter(oldValue, newValue);
  }
}

/// 输入掩码格式化器
///
/// 按照指定的掩码格式化输入
///
/// 掩码规则：
/// - `#`: 数字
/// - `A`: 字母
/// - `*`: 字母或数字
/// - 其他字符: 固定字符
///
/// 示例：
/// ```dart
/// InputFormatter.mask('###-####')  // 123-4567
/// InputFormatter.mask('(###) ###-####')  // (123) 456-7890
/// ```
class MaskFormatter extends TextInputFormatter {
  /// 掩码格式
  final String mask;

  /// 是否自动跳过固定字符
  final bool skipFixedChars;

  MaskFormatter(this.mask, {this.skipFixedChars = true});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    if (text.isEmpty) {
      return newValue;
    }

    final buffer = StringBuffer();
    int textIndex = 0;

    for (int i = 0; i < mask.length && textIndex < text.length; i++) {
      final maskChar = mask[i];

      if (maskChar == '#') {
        // 数字
        if (RegExp(r'\d').hasMatch(text[textIndex])) {
          buffer.write(text[textIndex]);
          textIndex++;
        } else {
          break;
        }
      } else if (maskChar == 'A') {
        // 字母
        if (RegExp(r'[a-zA-Z]').hasMatch(text[textIndex])) {
          buffer.write(text[textIndex]);
          textIndex++;
        } else {
          break;
        }
      } else if (maskChar == '*') {
        // 字母或数字
        if (RegExp(r'[a-zA-Z0-9]').hasMatch(text[textIndex])) {
          buffer.write(text[textIndex]);
          textIndex++;
        } else {
          break;
        }
      } else {
        // 固定字符
        buffer.write(maskChar);
        if (skipFixedChars && text[textIndex] == maskChar) {
          textIndex++;
        }
      }
    }

    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// 输入过滤格式化器
///
/// 提供更灵活的输入过滤选项
class InputFilterFormatter extends TextInputFormatter {
  /// 允许的字符集合
  final String? allowedChars;

  /// 禁止的字符集合
  final String? forbiddenChars;

  /// 是否使用正则表达式匹配
  final bool useRegex;

  /// 最大长度
  final int? maxLength;

  InputFilterFormatter({
    this.allowedChars,
    this.forbiddenChars,
    this.useRegex = false,
    this.maxLength,
  }) : assert(allowedChars != null || forbiddenChars != null);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;

    // 应用长度限制
    if (maxLength != null && text.length > maxLength!) {
      text = text.substring(0, maxLength!);
    }

    // 应用字符过滤
    if (allowedChars != null) {
      final pattern = useRegex ? allowedChars! : RegExp.escape(allowedChars!);
      text = text.replaceAll(RegExp('[^$pattern]'), '');
    }

    if (forbiddenChars != null) {
      final pattern =
          useRegex ? forbiddenChars! : RegExp.escape(forbiddenChars!);
      text = text.replaceAll(RegExp('[$pattern]'), '');
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
