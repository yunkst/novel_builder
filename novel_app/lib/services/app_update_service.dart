import 'dart:io';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:novel_api/novel_api.dart';

import '../models/app_version.dart';
import 'logger_service.dart';
import 'api_service_wrapper.dart';
import 'preferences_service.dart';

/// APP更新服务
///
/// 提供版本检查、下载和安装功能
class AppUpdateService {
  static const String _lastCheckKey = 'app_update_last_check';
  static const String _ignoreVersionKey = 'app_update_ignore_version';
  static const _platformChannel =
      MethodChannel('com.example.novel_app/app_install');

  final ApiServiceWrapper _apiWrapper;
  final Future<PackageInfo> Function()? _packageInfoGetter;

  AppUpdateService({
    required ApiServiceWrapper apiWrapper,
    Future<PackageInfo> Function()? packageInfoGetter,
  })  : _apiWrapper = apiWrapper,
        _packageInfoGetter = packageInfoGetter;

  /// 获取当前APP版本信息
  Future<PackageInfo> getCurrentVersion() async {
    if (_packageInfoGetter != null) {
      return await _packageInfoGetter!();
    }
    return await PackageInfo.fromPlatform();
  }

  /// 检查是否有新版本
  ///
  /// 返回null表示没有新版本，否则返回新版本信息
  Future<AppVersion?> checkForUpdate({bool forceCheck = false}) async {
    try {
      // 检查是否需要跳过此次检查（距离上次检查不足1小时且非强制检查）
      if (!forceCheck) {
        final lastCheck =
            await PreferencesService.instance.getInt(_lastCheckKey);
        final now = DateTime.now().millisecondsSinceEpoch;

        if ((now - lastCheck) < 3600000) {
          // 1小时内已检查过，跳过
          return null;
        }
      }

      // 获取当前版本
      final currentInfo = await getCurrentVersion();

      // 使用生成的API客户端获取最新版本
      final token = await _apiWrapper.getToken();

      if (token == null || token.isEmpty) {
        return null;
      }

      final response = await _apiWrapper.defaultApi
          .getLatestAppVersionApiAppVersionLatestGet(
        X_API_TOKEN: token,
      );

      if (response.data != null) {
        // 记录检查时间
        await PreferencesService.instance
            .setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

        final latestVersion = _convertToAppVersion(response.data!);

        // 比较版本号
        // 强制检查时，即使版本相同也返回版本信息（允许用户重新下载安装）
        final hasNew =
            hasNewVersion(currentInfo.version, latestVersion.version);
        LoggerService.instance.d(
          '版本比较: ${currentInfo.version} vs ${latestVersion.version}, hasNew: $hasNew, forceCheck: $forceCheck',
          category: LogCategory.general,
          tags: ['update', 'debug'],
        );

        if (forceCheck || hasNew) {
          return latestVersion;
        }
      }

      return null;
    } catch (e) {
      LoggerService.instance.e(
        '检查更新失败',
        category: LogCategory.general,
        tags: ['update', 'check', 'error'],
      );
      return null;
    }
  }

  /// 将API返回的 AppVersionResponse 转换为本地 AppVersion 模型
  AppVersion _convertToAppVersion(AppVersionResponse response) {
    return AppVersion(
      version: response.version,
      versionCode: response.versionCode,
      downloadUrl: response.downloadUrl,
      fileSize: response.fileSize,
      changelog: response.changelog,
      forceUpdate: response.forceUpdate ?? false,
      createdAt: response.createdAt,
    );
  }

  /// 比较版本号
  ///
  /// 返回true表示有新版本
  bool hasNewVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      // 补齐版本号位数
      while (currentParts.length < 3) {
        currentParts.add(0);
      }
      while (latestParts.length < 3) {
        latestParts.add(0);
      }

      // 比较主版本号
      if (latestParts[0] > currentParts[0]) return true;
      if (latestParts[0] < currentParts[0]) return false;

      // 比较次版本号
      if (latestParts[1] > currentParts[1]) return true;
      if (latestParts[1] < currentParts[1]) return false;

      // 比较修订号
      if (latestParts[2] > currentParts[2]) return true;

      return false;
    } catch (e) {
      LoggerService.instance.e(
        '版本号比较失败',
        category: LogCategory.general,
        tags: ['update', 'version', 'compare'],
      );
      return false;
    }
  }

  /// 请求安装权限
  Future<bool> requestInstallPermission() async {
    if (!Platform.isAndroid) {
      return true; // iOS不需要安装权限
    }

    final status = await Permission.requestInstallPackages.request();
    return status.isGranted;
  }

  /// 下载更新
  ///
  /// [onProgress] 进度回调，参数为0.0-1.0
  /// [onStatus] 状态回调
  Future<bool> downloadUpdate({
    required AppVersion version,
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    try {
      LoggerService.instance.i(
        '开始下载流程',
        category: LogCategory.general,
        tags: ['update', 'download', 'start'],
      );
      onStatus?.call('准备下载...');

      // 请求存储权限
      LoggerService.instance.d(
        '检查存储权限',
        category: LogCategory.general,
        tags: ['update', 'permission'],
      );
      final storageStatus = await Permission.storage.request();
      LoggerService.instance.d(
        'storage权限: $storageStatus',
        category: LogCategory.general,
        tags: ['update', 'permission', 'storage'],
      );
      if (!storageStatus.isGranted) {
        final manageStatus = await Permission.manageExternalStorage.request();
        LoggerService.instance.d(
          'manageExternalStorage权限: $manageStatus',
          category: LogCategory.general,
          tags: ['update', 'permission', 'manage'],
        );
        if (!manageStatus.isGranted) {
          LoggerService.instance.w(
            '存储权限被拒绝',
            category: LogCategory.general,
            tags: ['update', 'permission', 'denied'],
          );
          onStatus?.call('需要存储权限');
          return false;
        }
      }

      // 获取下载目录
      LoggerService.instance.d(
        '获取下载目录',
        category: LogCategory.general,
        tags: ['update', 'path'],
      );
      final directory = await getApplicationDocumentsDirectory();
      LoggerService.instance.d(
        '下载目录: ${directory.path}',
        category: LogCategory.general,
        tags: ['update', 'path'],
      );

      // 确保 updates 目录存在
      final updatesDir = Directory('${directory.path}/updates');
      if (!await updatesDir.exists()) {
        await updatesDir.create(recursive: true);
        LoggerService.instance.d(
          '创建 updates 目录',
          category: LogCategory.general,
          tags: ['update', 'directory'],
        );
      }

      final fileName = 'novel_app_v${version.version}.apk';
      final filePath = '${updatesDir.path}/$fileName';
      LoggerService.instance.d(
        '文件路径: $filePath',
        category: LogCategory.general,
        tags: ['update', 'path'],
      );

      // 构建完整的下载URL
      LoggerService.instance.d(
        '获取API配置',
        category: LogCategory.general,
        tags: ['update', 'api'],
      );
      final baseUrl = await _apiWrapper.getHost();
      LoggerService.instance.d(
        'baseUrl: $baseUrl',
        category: LogCategory.general,
        tags: ['update', 'api'],
      );
      LoggerService.instance.d(
        'version.downloadUrl: ${version.downloadUrl}',
        category: LogCategory.general,
        tags: ['update', 'api'],
      );

      if (baseUrl == null || baseUrl.isEmpty) {
        LoggerService.instance.e(
          'baseUrl 配置不完整',
          category: LogCategory.general,
          tags: ['update', 'api', 'error'],
        );
        onStatus?.call('API配置不完整');
        return false;
      }

      final downloadUrl = '$baseUrl${version.downloadUrl}';
      LoggerService.instance.d(
        '完整下载URL: $downloadUrl',
        category: LogCategory.general,
        tags: ['update', 'url'],
      );

      onStatus?.call('开始下载...');

      // 使用 ApiServiceWrapper 的 Dio 实例下载文件
      LoggerService.instance.i(
        '开始执行下载',
        category: LogCategory.general,
        tags: ['update', 'download', 'execute'],
      );

      await _apiWrapper.dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            LoggerService.instance.d(
              '下载进度: ${(progress * 100).toStringAsFixed(0)}%',
              category: LogCategory.general,
              tags: ['update', 'download', 'progress'],
            );
            onProgress?.call(progress);
          }
        },
      );

      LoggerService.instance.i(
        '下载完成',
        category: LogCategory.general,
        tags: ['update', 'download', 'success'],
      );
      onStatus?.call('下载完成');
      onProgress?.call(1.0);

      return true;
    } on DioException catch (e) {
      LoggerService.instance.e(
        '下载失败',
        category: LogCategory.general,
        tags: ['update', 'download', 'error'],
      );
      LoggerService.instance.e(
        '响应状态: ${e.response?.statusCode}',
        category: LogCategory.general,
        tags: ['update', 'download', 'status'],
      );
      onStatus?.call('下载失败: ${e.message}');
      return false;
    } catch (e) {
      LoggerService.instance.e(
        '下载异常',
        category: LogCategory.general,
        tags: ['update', 'download', 'exception'],
      );
      onStatus?.call('下载出错: $e');
      return false;
    }
  }

  /// 安装APK
  Future<bool> installUpdate(String version) async {
    try {
      LoggerService.instance.i(
        '开始安装APK',
        category: LogCategory.general,
        tags: ['update', 'install', 'start'],
      );
      // 检查安装权限
      final hasPermission = await requestInstallPermission();
      if (!hasPermission) {
        LoggerService.instance.w(
          '没有安装权限',
          category: LogCategory.general,
          tags: ['update', 'install', 'permission'],
        );
        return false;
      }

      final fileName = 'novel_app_v$version.apk';

      // 获取应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/updates/$fileName';
      LoggerService.instance.d(
        'APK文件路径: $filePath',
        category: LogCategory.general,
        tags: ['update', 'install', 'path'],
      );

      // 检查文件是否存在
      final file = File(filePath);
      if (!await file.exists()) {
        LoggerService.instance.e(
          'APK文件不存在: $filePath',
          category: LogCategory.general,
          tags: ['update', 'install', 'notfound'],
        );
        return false;
      }

      // 使用 MethodChannel 调用原生安装方法
      LoggerService.instance.i(
        '调用原生安装方法',
        category: LogCategory.general,
        tags: ['update', 'install', 'native'],
      );
      final result = await _platformChannel.invokeMethod('installApk', {
        'filePath': filePath,
      });

      return result == true;
    } on PlatformException catch (e) {
      LoggerService.instance.e(
        '安装失败',
        category: LogCategory.general,
        tags: ['update', 'install', 'error'],
      );
      LoggerService.instance.e(
        '错误码: ${e.code}',
        category: LogCategory.general,
        tags: ['update', 'install', 'code'],
      );
      return false;
    } catch (e) {
      LoggerService.instance.e(
        '安装APK失败',
        category: LogCategory.general,
        tags: ['update', 'install', 'exception'],
      );
      return false;
    }
  }

  /// 忽略此版本更新
  Future<void> ignoreVersion(String version) async {
    await PreferencesService.instance.setString(_ignoreVersionKey, version);
  }

  /// 检查版本是否被忽略
  Future<bool> isVersionIgnored(String version) async {
    final ignored =
        await PreferencesService.instance.getString(_ignoreVersionKey);
    return ignored == version;
  }

  /// 清除忽略的版本
  Future<void> clearIgnoredVersion() async {
    await PreferencesService.instance.remove(_ignoreVersionKey);
  }
}
