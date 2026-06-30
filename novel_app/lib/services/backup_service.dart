import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:novel_api/novel_api.dart';
import 'api_service_wrapper.dart';
import 'logger_service.dart';
import 'preferences_service.dart';
import '../utils/format_utils.dart';
import '../core/database/database_connection.dart';

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

      LoggerService.instance
          .i('获取数据库文件: ${file.path}', category: LogCategory.backup);
      return file;
    } catch (e, stackTrace) {
      LoggerService.instance.e('获取数据库文件失败: $e',
          category: LogCategory.backup, stackTrace: stackTrace.toString());
      rethrow;
    }
  }

  /// 上传备份到服务器
  ///
  /// [apiWrapper] API服务包装器实例（必须已初始化）
  /// [dbFile] 数据库文件
  /// [onProgress] 上传进度回调，参数为(已发送字节数, 总字节数)
  ///
  /// 返回BackupUploadResponse，包含上传结果信息
  Future<BackupUploadResponse> uploadBackup({
    required ApiServiceWrapper apiWrapper,
    required File dbFile,
    ProgressCallback? onProgress,
  }) async {
    try {
      LoggerService.instance
          .i('开始上传备份: ${dbFile.path}', category: LogCategory.backup);

      // 获取文件大小
      final fileSize = await dbFile.length();
      LoggerService.instance.i(
          '数据库文件大小: ${FormatUtils.formatFileSize(fileSize)}',
          category: LogCategory.backup);

      // 使用传入的ApiServiceWrapper上传
      final result = await apiWrapper.uploadBackup(
        dbFile: dbFile,
        onProgress: onProgress,
      );

      // 记录备份时间
      await saveBackupTime(DateTime.now());

      LoggerService.instance
          .i('备份上传成功: ${result.storedPath}', category: LogCategory.backup);

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
      LoggerService.instance.i('记录备份时间: $time', category: LogCategory.backup);
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
      LoggerService.instance.i('清除备份时间记录', category: LogCategory.backup);
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

    // 内联时间差格式化
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
      return FormatUtils.formatDateTime(lastBackup, showTime: false);
    }
  }

  /// 获取服务器备份列表
  ///
  /// [apiWrapper] 已初始化的 API 服务包装器实例
  ///
  /// 返回服务器上所有备份文件信息，按时间倒序
  Future<List<Map<String, dynamic>>> getBackupList({
    required ApiServiceWrapper apiWrapper,
  }) async {
    try {
      LoggerService.instance
          .i('获取服务器备份列表', category: LogCategory.backup);
      final backups = await apiWrapper.getBackupList();
      LoggerService.instance.i(
        '获取备份列表成功: ${backups.length} 条',
        category: LogCategory.backup,
      );
      return backups;
    } catch (e, stackTrace) {
      LoggerService.instance.e('获取备份列表失败: $e',
          category: LogCategory.backup, stackTrace: stackTrace.toString());
      rethrow;
    }
  }

  /// 下载服务器备份到本地文件
  ///
  /// [apiWrapper] 已初始化的 API 服务包装器实例
  /// [backupId] 备份唯一标识
  /// [savePath] 本地保存路径
  ///
  /// 返回下载到的本地文件 File 对象
  Future<File> downloadBackup({
    required ApiServiceWrapper apiWrapper,
    required String backupId,
    required String savePath,
  }) async {
    try {
      LoggerService.instance
          .i('下载备份: $backupId -> $savePath', category: LogCategory.backup);
      await apiWrapper.downloadBackup(
        backupId: backupId,
        savePath: savePath,
      );
      final file = File(savePath);
      if (!await file.exists()) {
        throw Exception('下载完成但文件不存在: $savePath');
      }
      LoggerService.instance.i(
        '备份下载完成: ${FormatUtils.formatFileSize(await file.length())}',
        category: LogCategory.backup,
      );
      return file;
    } catch (e, stackTrace) {
      LoggerService.instance.e('下载备份失败: $e',
          category: LogCategory.backup, stackTrace: stackTrace.toString());
      rethrow;
    }
  }

  /// 删除服务器上的备份文件
  ///
  /// [apiWrapper] 已初始化的 API 服务包装器实例
  /// [backupId] 备份唯一标识
  Future<void> deleteBackupOnServer({
    required ApiServiceWrapper apiWrapper,
    required String backupId,
  }) async {
    try {
      LoggerService.instance
          .i('删除服务器备份: $backupId', category: LogCategory.backup);
      await apiWrapper.deleteBackupOnServer(backupId: backupId);
      LoggerService.instance.i(
        '备份删除成功: $backupId',
        category: LogCategory.backup,
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e('删除备份失败: $e',
          category: LogCategory.backup, stackTrace: stackTrace.toString());
      rethrow;
    }
  }

  /// 从服务器恢复备份
  ///
  /// 核心流程（10 步）：
  /// 1. 获取源数据库路径
  /// 2. 下载备份到临时文件
  /// 3. SQLite 头校验（"SQLite format 3\0"）
  /// 4. 校验失败 → 删除临时文件 → 抛异常
  /// 5. 关闭当前数据库连接
  /// 6. 备份现有 DB → novel_reader.db.bak
  /// 7. 临时文件复制到目标路径
  /// 8. 删除临时文件
  /// 9. 重新打开数据库验证
  /// 10. 打开失败 → 从 .bak 回滚 → 抛异常；成功 → 删除 .bak
  ///
  /// [apiWrapper] 已初始化的 API 服务包装器实例
  /// [backupId] 备份唯一标识
  Future<void> restoreBackup({
    required ApiServiceWrapper apiWrapper,
    required String backupId,
  }) async {
    final dbPath = await getDatabasesPath();
    final targetFilePath = path.join(dbPath, 'novel_reader.db');
    final tempFilePath = path.join(dbPath, 'novel_app_restore_temp.db');
    final bakFilePath = path.join(dbPath, 'novel_reader.db.bak');

    try {
      LoggerService.instance.i(
        '开始恢复备份: $backupId',
        category: LogCategory.backup,
      );

      // 步骤 1-2：下载到临时文件
      await downloadBackup(
        apiWrapper: apiWrapper,
        backupId: backupId,
        savePath: tempFilePath,
      );

      // 步骤 3：SQLite header 校验
      final tempFile = File(tempFilePath);
      final fileSize = await tempFile.length();
      if (fileSize < 16) {
        await tempFile.delete();
        LoggerService.instance.e(
          '恢复失败: 文件过小 ($fileSize bytes < 16)',
          category: LogCategory.backup,
          tags: ['backup', 'restore', 'file_too_small'],
        );
        throw Exception('下载的文件不是有效的 SQLite 数据库（文件过小）');
      }

      final headerBytes = await tempFile.openRead(0, 16).first;
      const sqliteHeader = 'SQLite format 3\x00';
      final header = String.fromCharCodes(headerBytes);
      if (header != sqliteHeader) {
        await tempFile.delete();
        LoggerService.instance.e(
          '恢复失败: SQLite header 校验失败 (期望 "SQLite format 3\\0", 实际 "$header")',
          category: LogCategory.backup,
          tags: ['backup', 'restore', 'header_invalid'],
        );
        throw Exception('下载的文件不是有效的 SQLite 数据库');
      }

      LoggerService.instance.i(
        'SQLite header 校验通过',
        category: LogCategory.backup,
      );

      // 步骤 5：关闭数据库连接
      final dbConnection = DatabaseConnection();
      await dbConnection.close();
      LoggerService.instance.i(
        '数据库连接已关闭',
        category: LogCategory.backup,
      );

      // 步骤 6：备份现有 DB
      final existingDb = File(targetFilePath);
      if (await existingDb.exists()) {
        // 先删除旧 .bak
        final oldBak = File(bakFilePath);
        if (await oldBak.exists()) {
          await oldBak.delete();
        }
        await existingDb.rename(bakFilePath);
        LoggerService.instance.i(
          '现有数据库已备份: $bakFilePath',
          category: LogCategory.backup,
        );
      }

      // 步骤 7-8：复制临时文件到目标路径，删除临时文件
      await tempFile.copy(targetFilePath);
      await tempFile.delete();
      LoggerService.instance.i(
        '备份文件已复制到目标路径',
        category: LogCategory.backup,
      );

      // 步骤 9-10：验证恢复
      try {
        await dbConnection.database;
        LoggerService.instance.i(
          '数据库重新打开成功，恢复完成',
          category: LogCategory.backup,
        );
        // 恢复成功，删除 .bak
        final bakFile = File(bakFilePath);
        if (await bakFile.exists()) {
          await bakFile.delete();
        }
      } catch (e) {
        LoggerService.instance.e(
          '恢复后数据库打开失败，正在回滚...',
          category: LogCategory.backup,
        );
        // 从 .bak 回滚
        final bakFile = File(bakFilePath);
        if (await bakFile.exists()) {
          // 关闭可能部分打开的连接
          await dbConnection.close();
          // 删除损坏的恢复文件
          final targetFile = File(targetFilePath);
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          // 回滚
          await bakFile.rename(targetFilePath);
          await dbConnection.database; // 重新打开
          LoggerService.instance.i(
            '已从 .bak 回滚成功',
            category: LogCategory.backup,
          );
        }
        throw Exception('数据库恢复失败，已回滚到原数据库: $e');
      }

      LoggerService.instance.i(
        '备份恢复完成: $backupId',
        category: LogCategory.backup,
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e('恢复备份失败: $e',
          category: LogCategory.backup, stackTrace: stackTrace.toString());
      // 清理临时文件
      try {
        final tempFile = File(tempFilePath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        LoggerService.instance.d(
          '清理临时文件失败（可忽略）: $tempFilePath - $e',
          category: LogCategory.backup,
          tags: ['backup', 'restore', 'cleanup_temp'],
        );
      }
      rethrow;
    }
  }
}
