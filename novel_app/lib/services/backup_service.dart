import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:novel_api/novel_api.dart';
import 'api_service_wrapper.dart';
import 'logger_service.dart';
import 'preferences_service.dart';
import '../utils/format_utils.dart';

/// 数据库备份服务
///
/// 提供数据库备份功能，包括获取数据库文件、上传到服务器、记录备份时间等
class BackupService {
  static const String _prefsLastBackupTimeKey = 'last_backup_time';

  // 单例模式
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  // Preferences 服务实例
  static final PreferencesService _prefs = PreferencesService();

  /// 获取数据库文件
  ///
  /// 返回SQLite数据库文件对象
  /// 如果数据库不存在或无法访问，会抛出异常
  Future<File> getDatabaseFile() async {
    try {
      final dbPath = await getDatabasesPath();
      final dbFilePath = path.join(dbPath, 'novel_reader.db');
      final file = File(dbFilePath);

      if (!await file.exists()) {
        throw Exception('数据库文件不存在: $dbFilePath');
      }

      LoggerService.instance.i('获取数据库文件: ${file.path}',
          category: LogCategory.backup);
      return file;
    } catch (e, stackTrace) {
      LoggerService.instance.e('获取数据库文件失败: $e',
          category: LogCategory.backup, stackTrace: stackTrace.toString());
      rethrow;
    }
  }

  /// 上传备份到服务器
  ///
  /// [dbFile] 数据库文件
  /// [onProgress] 上传进度回调，参数为(已发送字节数, 总字节数)
  ///
  /// 返回BackupUploadResponse，包含上传结果信息
  Future<BackupUploadResponse> uploadBackup({
    required File dbFile,
    ProgressCallback? onProgress,
  }) async {
    try {
      LoggerService.instance.i('开始上传备份: ${dbFile.path}',
          category: LogCategory.backup);

      // 获取文件大小
      final fileSize = await dbFile.length();
      LoggerService.instance.i('数据库文件大小: ${FormatUtils.formatFileSize(fileSize)}',
          category: LogCategory.backup);

      // 使用ApiServiceWrapper上传
      final apiWrapper = ApiServiceWrapper();
      final result = await apiWrapper.uploadBackup(
        dbFile: dbFile,
        onProgress: onProgress,
      );

      // 记录备份时间
      await saveBackupTime(DateTime.now());

      LoggerService.instance.i('备份上传成功: ${result.storedPath}',
          category: LogCategory.backup);

      return result;
    } catch (e, stackTrace) {
      LoggerService.instance.e('备份上传失败: $e',
          category: LogCategory.backup, stackTrace: stackTrace.toString());
      rethrow;
    }
  }

  /// 获取上次备份时间
  ///
  /// 返回上次备份的DateTime，如果没有备份过则返回null
  Future<DateTime?> getLastBackupTime() async {
    try {
      final timestamp = await _prefs.getInt(_prefsLastBackupTimeKey);
      if (timestamp == 0) return null;

      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e, stackTrace) {
      LoggerService.instance.e('获取上次备份时间失败: $e',
          category: LogCategory.backup, stackTrace: stackTrace.toString());
      return null;
    }
  }

  /// 保存备份时间
  ///
  /// 记录当前时间作为最后备份时间
  Future<void> saveBackupTime(DateTime time) async {
    try {
      await _prefs.setInt(_prefsLastBackupTimeKey, time.millisecondsSinceEpoch);
      LoggerService.instance.i('记录备份时间: $time',
          category: LogCategory.backup);
    } catch (e, stackTrace) {
      LoggerService.instance.e('保存备份时间失败: $e',
          category: LogCategory.backup, stackTrace: stackTrace.toString());
    }
  }

  /// 清除备份时间记录
  ///
  /// 用于测试或重置备份状态
  Future<void> clearBackupTime() async {
    try {
      await _prefs.remove(_prefsLastBackupTimeKey);
      LoggerService.instance.i('清除备份时间记录',
          category: LogCategory.backup);
    } catch (e, stackTrace) {
      LoggerService.instance.e('清除备份时间失败: $e',
          category: LogCategory.backup, stackTrace: stackTrace.toString());
    }
  }

  /// 获取上次备份时间的友好显示文本
  ///
  /// 返回格式化的时间字符串，如"2小时前"、"昨天"、"2024-01-28"
  Future<String> getLastBackupTimeText() async {
    final lastBackup = await getLastBackupTime();
    if (lastBackup == null) return '从未备份';

    final now = DateTime.now();
    final difference = now.difference(lastBackup);
    return FormatUtils.formatTimeDifference(difference);
  }
}
