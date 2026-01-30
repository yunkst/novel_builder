import 'dart:convert';
import 'package:crypto/crypto.dart';

/// 缓存工具类
///
/// 提供缓存相关的通用方法，如哈希文件名、生成缓存键等。
///
/// 使用方式：
/// ```dart
/// // 生成哈希文件名（用于缓存）
/// final hash = CacheUtils.generateHashFilename('image.jpg');
///
/// // 生成缓存键
/// final key = CacheUtils.generateCacheKey('user', '123');
///
/// // 验证缓存是否过期
/// final isExpired = CacheUtils.isCacheExpired(timestamp, Duration(hours: 1));
/// ```
class CacheUtils {
  // 私有构造函数，防止实例化
  CacheUtils._();

  /// 生成哈希文件名
  ///
  /// 使用 MD5 算法对文件名进行哈希，生成唯一的缓存文件名。
  /// 适用于将任意文件名转换为安全的缓存文件名。
  ///
  /// [filename] 原始文件名或URL
  /// 返回32位小写MD5哈希字符串
  ///
  /// 示例：
  /// ```dart
  /// CacheUtils.generateHashFilename('image.jpg');
  /// // "5d41402abc4b2a76b9719d911017c592"
  ///
  /// CacheUtils.generateHashFilename('https://example.com/path/to/image.jpg');
  /// // "7b8b9658854c3e6c1b2f3d4a5e6c7d8e"
  /// ```
  static String generateHashFilename(String filename) {
    final bytes = utf8.encode(filename);
    final hash = md5.convert(bytes);
    return hash.toString();
  }

  /// 生成缓存键
  ///
  /// 根据多个参数生成统一的缓存键。
  ///
  /// [parts] 组成缓存键的各个部分
  /// 返回用冒号分隔的缓存键
  ///
  /// 示例：
  /// ```dart
  /// CacheUtils.generateCacheKey('user', '123');
  /// // "user:123"
  ///
  /// CacheUtils.generateCacheKey('novel', '456', 'chapter', '789');
  /// // "novel:456:chapter:789"
  /// ```
  static String generateCacheKey(Iterable<String> parts) {
    return parts.join(':');
  }

  /// 生成带前缀的哈希缓存键
  ///
  /// 结合前缀和哈希值生成缓存键，适用于长URL等场景。
  ///
  /// [prefix] 键前缀（用于标识缓存类型）
  /// [content] 需要哈希的内容
  /// 返回格式为 "prefix:hash" 的缓存键
  ///
  /// 示例：
  /// ```dart
  /// CacheUtils.generateHashKey('image', 'https://example.com/image.jpg');
  /// // "image:7b8b9658854c3e6c1b2f3d4a5e6c7d8e"
  /// ```
  static String generateHashKey(String prefix, String content) {
    final hash = generateHashFilename(content);
    return '$prefix:$hash';
  }

  /// 检查缓存是否过期
  ///
  /// [cacheTimestamp] 缓存时的时间戳
  /// [maxAge] 最大有效期
  /// 返回 true 表示已过期
  ///
  /// 示例：
  /// ```dart
  /// final timestamp = DateTime.now().subtract(Duration(hours: 2));
  /// final isExpired = CacheUtils.isCacheExpired(timestamp, Duration(hours: 1));
  /// // true
  /// ```
  static bool isCacheExpired(DateTime cacheTimestamp, Duration maxAge) {
    final now = DateTime.now();
    final age = now.difference(cacheTimestamp);
    return age > maxAge;
  }

  /// 检查缓存是否过期（毫秒时间戳版本）
  ///
  /// [cacheTimestampMs] 缓存时的毫秒时间戳
  /// [maxAge] 最大有效期
  /// 返回 true 表示已过期
  ///
  /// 示例：
  /// ```dart
  /// final timestamp = DateTime.now().subtract(Duration(hours: 2));
  /// final isExpired = CacheUtils.isCacheExpiredMs(timestamp.millisecondsSinceEpoch, Duration(hours: 1));
  /// // true
  /// ```
  static bool isCacheExpiredMs(int cacheTimestampMs, Duration maxAge) {
    final cacheTimestamp = DateTime.fromMillisecondsSinceEpoch(cacheTimestampMs);
    return isCacheExpired(cacheTimestamp, maxAge);
  }

  /// 计算缓存剩余有效时间
  ///
  /// [cacheTimestamp] 缓存时的时间戳
  /// [maxAge] 最大有效期
  /// 返回剩余有效时间，如果已过期返回 Duration.zero
  ///
  /// 示例：
  /// ```dart
  /// final timestamp = DateTime.now().subtract(Duration(minutes: 30));
  /// final remaining = CacheUtils.getRemainingTime(timestamp, Duration(hours: 1));
  /// // Duration(minutes: 30)
  /// ```
  static Duration getRemainingTime(DateTime cacheTimestamp, Duration maxAge) {
    final now = DateTime.now();
    final age = now.difference(cacheTimestamp);
    final remaining = maxAge - age;

    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
  }

  /// 生成文件扩展名
  ///
  /// 从文件名或URL中提取文件扩展名。
  ///
  /// [filename] 文件名或URL
  /// 返回小写的扩展名（不含点），如果没有扩展名返回空字符串
  ///
  /// 示例：
  /// ```dart
  /// CacheUtils.getFileExtension('image.jpg');        // 'jpg'
  /// CacheUtils.getFileExtension('photo.PNG');        // 'png'
  /// CacheUtils.getFileExtension('https://example.com/image.png?v=1'); // 'png'
  /// CacheUtils.getFileExtension('noextension');      // ''
  /// ```
  static String getFileExtension(String filename) {
    // 移除URL查询参数
    final queryIndex = filename.indexOf('?');
    if (queryIndex > 0) {
      filename = filename.substring(0, queryIndex);
    }

    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == filename.length - 1) {
      return '';
    }

    return filename.substring(dotIndex + 1).toLowerCase();
  }

  /// 生成MIME类型
  ///
  /// 根据文件扩展名生成对应的MIME类型。
  ///
  /// [filename] 文件名或扩展名
  /// 返回MIME类型字符串，未知类型返回 'application/octet-stream'
  ///
  /// 示例：
  /// ```dart
  /// CacheUtils.getMimeType('image.jpg');     // 'image/jpeg'
  /// CacheUtils.getMimeType('document.pdf');  // 'application/pdf'
  /// CacheUtils.getMimeType('video.mp4');     // 'video/mp4'
  /// ```
  static String getMimeType(String filename) {
    final ext = getFileExtension(filename);

    const mimeTypes = {
      // 图片
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'bmp': 'image/bmp',
      'svg': 'image/svg+xml',
      'ico': 'image/x-icon',

      // 视频
      'mp4': 'video/mp4',
      'webm': 'video/webm',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',

      // 音频
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'ogg': 'audio/ogg',

      // 文档
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt': 'text/plain',
      'json': 'application/json',
      'xml': 'application/xml',

      // 压缩
      'zip': 'application/zip',
      'rar': 'application/x-rar-compressed',
      '7z': 'application/x-7z-compressed',
    };

    return mimeTypes[ext] ?? 'application/octet-stream';
  }

  /// 生成ETag（用于HTTP缓存验证）
  ///
  /// 根据内容生成ETag值。
  ///
  /// [content] 内容字符串
  /// 返回ETag值（格式为 "hash"）
  ///
  /// 示例：
  /// ```dart
  /// CacheUtils.generateETag('content');
  /// // "d41d8cd98f00b204e9800998ecf8427e"
  /// ```
  static String generateETag(String content) {
    return '"${generateHashFilename(content)}"';
  }

  /// 生成强ETag（基于内容长度和哈希）
  ///
  /// [content] 内容字节
  /// 返回强ETag值
  static String generateStrongETag(List<int> content) {
    final hash = md5.convert(content);
    return '"$hash"';
  }
}
