/// 格式化工具类
///
/// 提供常用的数据格式化方法，如文件大小、时长等。
/// 统一替代项目中重复的格式化逻辑。
///
/// 使用方式：
/// ```dart
/// // 格式化文件大小
/// final size = FormatUtils.formatFileSize(1024); // "1.0 KB"
/// final size2 = FormatUtils.formatFileSize(1048576); // "1.0 MB"
///
/// // 格式化时长
/// final duration = FormatUtils.formatDuration(Duration(minutes: 90)); // "1小时30分钟"
/// ```
class FormatUtils {
  // 私有构造函数，防止实例化
  FormatUtils._();

  /// 格式化文件大小
  ///
  /// 将字节数转换为人类可读的格式（B, KB, MB, GB, TB）。
  /// [bytes] 文件大小（字节数）
  /// 返回格式化后的字符串，保留1位小数
  ///
  /// 示例：
  /// ```dart
  /// FormatUtils.formatFileSize(0);        // "0 B"
  /// FormatUtils.formatFileSize(500);      // "500 B"
  /// FormatUtils.formatFileSize(1024);     // "1.0 KB"
  /// FormatUtils.formatFileSize(1048576);  // "1.0 MB"
  /// FormatUtils.formatFileSize(1073741824); // "1.0 GB"
  /// ```
  static String formatFileSize(int bytes) {
    if (bytes < 0) return '0 B';
    if (bytes < 1024) return '$bytes B';

    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = bytes.toDouble();
    int unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  /// 格式化时长
  ///
  /// 将 Duration 转换为人类可读的中文格式。
  /// [duration] 时长对象
  /// 返回格式化后的字符串
  ///
  /// 示例：
  /// ```dart
  /// FormatUtils.formatDuration(Duration(seconds: 45));    // "45秒"
  /// FormatUtils.formatDuration(Duration(minutes: 90));    // "1小时30分钟"
  /// FormatUtils.formatDuration(Duration(hours: 25));      // "1天1小时"
  /// FormatUtils.formatDuration(Duration(days: 2));        // "2天"
  /// ```
  static String formatDuration(Duration duration) {
    final parts = <String>[];

    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (days > 0) {
      parts.add('$days天');
    }
    if (hours > 0) {
      parts.add('$hours小时');
    }
    if (minutes > 0) {
      parts.add('$minutes分钟');
    }
    if (seconds > 0 && parts.isEmpty) {
      parts.add('$seconds秒');
    }

    return parts.isEmpty ? '0秒' : parts.join();
  }

  /// 格式化时间差
  ///
  /// 将 DateTime 差值转换为友好的中文描述。
  /// [difference] 时间差
  /// 返回格式化后的字符串，如"刚刚"、"5分钟前"、"昨天"
  ///
  /// 示例：
  /// ```dart
  /// FormatUtils.formatTimeDifference(Duration(seconds: 30));   // "刚刚"
  /// FormatUtils.formatTimeDifference(Duration(minutes: 5));    // "5分钟前"
  /// FormatUtils.formatTimeDifference(Duration(hours: 2));      // "2小时前"
  /// FormatUtils.formatTimeDifference(Duration(days: 1));       // "昨天"
  /// FormatUtils.formatTimeDifference(Duration(days: 5));       // "5天前"
  /// ```
  static String formatTimeDifference(Duration difference) {
    if (difference.inSeconds < 60) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      // 超过一周，返回日期格式
      final now = DateTime.now();
      final past = now.subtract(difference);
      return '${past.year}-${past.month.toString().padLeft(2, '0')}-${past.day.toString().padLeft(2, '0')}';
    }
  }

  /// 格式化日期时间
  ///
  /// 将 DateTime 格式化为标准的日期时间字符串。
  /// [dateTime] 日期时间对象
  /// [showTime] 是否显示时间部分，默认为true
  /// 返回格式化后的字符串，格式为 "YYYY-MM-DD HH:mm:ss" 或 "YYYY-MM-DD"
  ///
  /// 示例：
  /// ```dart
  /// FormatUtils.formatDateTime(DateTime(2024, 1, 15, 14, 30, 45));
  /// // "2024-01-15 14:30:45"
  ///
  /// FormatUtils.formatDateTime(DateTime(2024, 1, 15), showTime: false);
  /// // "2024-01-15"
  /// ```
  static String formatDateTime(DateTime dateTime, {bool showTime = true}) {
    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');

    if (!showTime) {
      return '$year-$month-$day';
    }

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute:$second';
  }

  /// 格式化数字（添加千位分隔符）
  ///
  /// [number] 要格式化的数字
  /// [decimalDigits] 小数位数，默认为0
  /// 返回格式化后的字符串
  ///
  /// 示例：
  /// ```dart
  /// FormatUtils.formatNumber(1000);           // "1,000"
  /// FormatUtils.formatNumber(1234567);        // "1,234,567"
  /// FormatUtils.formatNumber(1234.56, 2);     // "1,234.56"
  /// ```
  static String formatNumber(num number, {int decimalDigits = 0}) {
    final parts = number.toStringAsFixed(decimalDigits).split('.');
    final integerPart = parts[0];

    // 添加千位分隔符
    final buffer = StringBuffer();
    for (int i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(integerPart[i]);
    }

    if (parts.length > 1) {
      buffer.write('.');
      buffer.write(parts[1]);
    }

    return buffer.toString();
  }

  /// 格式化百分比
  ///
  /// [value] 0-1之间的数值
  /// [decimalDigits] 小数位数，默认为1
  /// 返回格式化后的百分比字符串
  ///
  /// 示例：
  /// ```dart
  /// FormatUtils.formatPercent(0.5);        // "50.0%"
  /// FormatUtils.formatPercent(0.75, 0);    // "75%"
  /// FormatUtils.formatPercent(1.0);        // "100.0%"
  /// ```
  static String formatPercent(double value, {int decimalDigits = 1}) {
    final percent = (value * 100).clamp(0, 100);
    return '${percent.toStringAsFixed(decimalDigits)}%';
  }
}
