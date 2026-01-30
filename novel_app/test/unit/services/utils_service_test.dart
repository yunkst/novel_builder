import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/preferences_service.dart';
import 'package:novel_app/utils/format_utils.dart';
import 'package:novel_app/utils/cache_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

void main() {
  group('PreferencesService Tests', () {
    late PreferencesService prefs;

    setUp(() async {
      // 初始化 SharedPreferences mock
      SharedPreferences.setMockInitialValues({});
      prefs = PreferencesService();
    });

    test('String 读写测试', () async {
      const key = 'test_string';
      const value = 'hello world';

      await prefs.setString(key, value);
      final result = await prefs.getString(key);
      expect(result, equals(value));
    });

    test('Int 读写测试', () async {
      const key = 'test_int';
      const value = 42;

      await prefs.setInt(key, value);
      final result = await prefs.getInt(key);
      expect(result, equals(value));
    });

    test('Double 读写测试', () async {
      const key = 'test_double';
      const value = 3.14;

      await prefs.setDouble(key, value);
      final result = await prefs.getDouble(key);
      expect(result, equals(value));
    });

    test('Bool 读写测试', () async {
      const key = 'test_bool';
      const value = true;

      await prefs.setBool(key, value);
      final result = await prefs.getBool(key);
      expect(result, equals(value));
    });

    test('StringList 读写测试', () async {
      const key = 'test_list';
      const value = ['a', 'b', 'c'];

      await prefs.setStringList(key, value);
      final result = await prefs.getStringList(key);
      expect(result, equals(value));
    });

    test('默认值测试', () async {
      const key = 'non_existent_key';

      final strResult = await prefs.getString(key);
      expect(strResult, equals(''));

      final intResult = await prefs.getInt(key, defaultValue: 10);
      expect(intResult, equals(10));

      final doubleResult = await prefs.getDouble(key, defaultValue: 2.5);
      expect(doubleResult, equals(2.5));

      final boolResult = await prefs.getBool(key, defaultValue: true);
      expect(boolResult, equals(true));
    });

    test('删除键测试', () async {
      const key = 'test_delete';
      await prefs.setString(key, 'value');

      await prefs.remove(key);
      final result = await prefs.getString(key);
      expect(result, equals(''));
    });

    test('containsKey 测试', () async {
      const key = 'test_contains';

      expect(await prefs.containsKey(key), false);

      await prefs.setString(key, 'value');
      expect(await prefs.containsKey(key), true);
    });

    test('批量设置测试', () async {
      final values = <String, dynamic>{
        'key1': 'string',
        'key2': 42,
        'key3': 3.14,
        'key4': true,
      };

      final count = await prefs.setMultiple(values);
      expect(count, equals(4));

      expect(await prefs.getString('key1'), 'string');
      expect(await prefs.getInt('key2'), 42);
      expect(await prefs.getDouble('key3'), 3.14);
      expect(await prefs.getBool('key4'), true);
    });
  });

  group('FormatUtils Tests', () {
    test('formatFileSize - 字节测试', () {
      expect(FormatUtils.formatFileSize(0), '0 B');
      expect(FormatUtils.formatFileSize(500), '500 B');
      expect(FormatUtils.formatFileSize(1023), '1023 B');
    });

    test('formatFileSize - KB测试', () {
      expect(FormatUtils.formatFileSize(1024), '1.0 KB');
      expect(FormatUtils.formatFileSize(1536), '1.5 KB');
      expect(FormatUtils.formatFileSize(1024 * 1000), '1000.0 KB');
    });

    test('formatFileSize - MB测试', () {
      expect(FormatUtils.formatFileSize(1024 * 1024), '1.0 MB');
      expect(FormatUtils.formatFileSize((1024 * 1024 * 3).toInt()), '3.0 MB');
    });

    test('formatFileSize - GB测试', () {
      expect(FormatUtils.formatFileSize(1024 * 1024 * 1024), '1.0 GB');
      expect(FormatUtils.formatFileSize(1024 * 1024 * 1024 * 2), '2.0 GB');
    });

    test('formatDuration - 秒测试', () {
      expect(
        FormatUtils.formatDuration(const Duration(seconds: 45)),
        '45秒',
      );
    });

    test('formatDuration - 分钟测试', () {
      expect(
        FormatUtils.formatDuration(const Duration(minutes: 90)),
        '1小时30分钟',
      );
    });

    test('formatDuration - 小时测试', () {
      expect(
        FormatUtils.formatDuration(const Duration(hours: 25)),
        '1天1小时',
      );
    });

    test('formatDuration - 天测试', () {
      expect(
        FormatUtils.formatDuration(const Duration(days: 2)),
        '2天',
      );
    });

    test('formatTimeDifference - 刚刚测试', () {
      expect(
        FormatUtils.formatTimeDifference(const Duration(seconds: 30)),
        '刚刚',
      );
    });

    test('formatTimeDifference - 分钟前测试', () {
      expect(
        FormatUtils.formatTimeDifference(const Duration(minutes: 5)),
        '5分钟前',
      );
    });

    test('formatTimeDifference - 小时前测试', () {
      expect(
        FormatUtils.formatTimeDifference(const Duration(hours: 2)),
        '2小时前',
      );
    });

    test('formatTimeDifference - 昨天测试', () {
      expect(
        FormatUtils.formatTimeDifference(const Duration(days: 1)),
        '昨天',
      );
    });

    test('formatTimeDifference - 多天前测试', () {
      expect(
        FormatUtils.formatTimeDifference(const Duration(days: 5)),
        '5天前',
      );
    });

    test('formatDateTime - 基本测试', () {
      final dt = DateTime(2024, 1, 15, 14, 30, 45);
      expect(
        FormatUtils.formatDateTime(dt),
        '2024-01-15 14:30:45',
      );
    });

    test('formatDateTime - 不含时间测试', () {
      final dt = DateTime(2024, 1, 15, 14, 30, 45);
      expect(
        FormatUtils.formatDateTime(dt, showTime: false),
        '2024-01-15',
      );
    });

    test('formatNumber - 基本测试', () {
      expect(FormatUtils.formatNumber(1000), '1,000');
      expect(FormatUtils.formatNumber(1234567), '1,234,567');
      expect(FormatUtils.formatNumber(1234.56, decimalDigits: 2), '1,234.56');
    });

    test('formatPercent - 基本测试', () {
      expect(FormatUtils.formatPercent(0.5), '50.0%');
      expect(FormatUtils.formatPercent(0.75, decimalDigits: 0), '75%');
      expect(FormatUtils.formatPercent(1.0), '100.0%');
    });
  });

  group('CacheUtils Tests', () {
    test('generateHashFilename - 基本测试', () {
      final hash1 = CacheUtils.generateHashFilename('test.jpg');
      final hash2 = CacheUtils.generateHashFilename('test.jpg');

      // 相同输入应产生相同哈希
      expect(hash1, equals(hash2));

      // 哈希应该是32位十六进制字符串
      expect(hash1.length, equals(32));

      // 不同输入应产生不同哈希
      final hash3 = CacheUtils.generateHashFilename('other.jpg');
      expect(hash1, isNot(equals(hash3)));
    });

    test('generateCacheKey - 基本测试', () {
      expect(
        CacheUtils.generateCacheKey(['user', '123']),
        'user:123',
      );

      expect(
        CacheUtils.generateCacheKey(['novel', '456', 'chapter', '789']),
        'novel:456:chapter:789',
      );
    });

    test('generateHashKey - 基本测试', () {
      final key = CacheUtils.generateHashKey('image', 'https://example.com/image.jpg');

      // 应该是 prefix:hash 格式
      expect(key.startsWith('image:'), true);

      // 哈希部分应该是32位
      final parts = key.split(':');
      expect(parts[1].length, equals(32));
    });

    test('isCacheExpired - 未过期测试', () {
      final now = DateTime.now();
      expect(
        CacheUtils.isCacheExpired(now, const Duration(hours: 1)),
        false,
      );
    });

    test('isCacheExpired - 已过期测试', () {
      final past = DateTime.now().subtract(const Duration(hours: 2));
      expect(
        CacheUtils.isCacheExpired(past, const Duration(hours: 1)),
        true,
      );
    });

    test('getRemainingTime - 有剩余时间测试', () {
      final past = DateTime.now().subtract(const Duration(minutes: 30));
      final remaining = CacheUtils.getRemainingTime(past, const Duration(hours: 1));

      // 应该还有约30分钟剩余
      expect(
        remaining.inMinutes,
        greaterThan(25),
      );
      expect(
        remaining.inMinutes,
        lessThan(35),
      );
    });

    test('getRemainingTime - 已过期测试', () {
      final past = DateTime.now().subtract(const Duration(hours: 2));
      final remaining = CacheUtils.getRemainingTime(past, const Duration(hours: 1));

      expect(remaining, equals(Duration.zero));
    });

    test('getFileExtension - 基本测试', () {
      expect(CacheUtils.getFileExtension('image.jpg'), 'jpg');
      expect(CacheUtils.getFileExtension('photo.PNG'), 'png');
      expect(CacheUtils.getFileExtension('document.pdf'), 'pdf');
      expect(CacheUtils.getFileExtension('noextension'), '');
      expect(CacheUtils.getFileExtension('multiple.dots.txt'), 'txt');
    });

    test('getFileExtension - URL测试', () {
      expect(
        CacheUtils.getFileExtension('https://example.com/image.png?v=1'),
        'png',
      );
    });

    test('getMimeType - 图片测试', () {
      expect(CacheUtils.getMimeType('image.jpg'), 'image/jpeg');
      expect(CacheUtils.getMimeType('image.png'), 'image/png');
      expect(CacheUtils.getMimeType('image.gif'), 'image/gif');
      expect(CacheUtils.getMimeType('image.webp'), 'image/webp');
    });

    test('getMimeType - 视频测试', () {
      expect(CacheUtils.getMimeType('video.mp4'), 'video/mp4');
      expect(CacheUtils.getMimeType('video.webm'), 'video/webm');
    });

    test('getMimeType - 文档测试', () {
      expect(CacheUtils.getMimeType('doc.pdf'), 'application/pdf');
      expect(CacheUtils.getMimeType('doc.txt'), 'text/plain');
      expect(CacheUtils.getMimeType('doc.json'), 'application/json');
    });

    test('getMimeType - 未知类型测试', () {
      expect(
        CacheUtils.getMimeType('unknown.xyz'),
        'application/octet-stream',
      );
    });

    test('generateETag - 基本测试', () {
      final etag = CacheUtils.generateETag('content');

      // ETag 应该是引号包围的哈希
      expect(etag.startsWith('"'), true);
      expect(etag.endsWith('"'), true);
      expect(etag.length, equals(34)); // 32 + 2个引号
    });
  });
}
