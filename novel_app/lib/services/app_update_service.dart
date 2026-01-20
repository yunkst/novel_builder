import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_api/novel_api.dart';

import '../models/app_version.dart';
import 'api_service_wrapper.dart';

/// APP更新服务
///
/// 提供版本检查、下载和安装功能
class AppUpdateService {
  static const String _lastCheckKey = 'app_update_last_check';
  static const String _ignoreVersionKey = 'app_update_ignore_version';
  static const _platformChannel = MethodChannel('com.example.novel_app/app_install');

  final ApiServiceWrapper _apiWrapper;

  AppUpdateService({required ApiServiceWrapper apiWrapper})
      : _apiWrapper = apiWrapper;

  /// 获取当前APP版本信息
  Future<PackageInfo> getCurrentVersion() async {
    return await PackageInfo.fromPlatform();
  }

  /// 检查是否有新版本
  ///
  /// 返回null表示没有新版本，否则返回新版本信息
  Future<AppVersion?> checkForUpdate({bool forceCheck = false}) async {
    try {
      // 检查是否需要跳过此次检查（距离上次检查不足1小时且非强制检查）
      if (!forceCheck) {
        final prefs = await SharedPreferences.getInstance();
        final lastCheck = prefs.getInt(_lastCheckKey);
        final now = DateTime.now().millisecondsSinceEpoch;

        if (lastCheck != null && (now - lastCheck) < 3600000) {
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

      if (response.statusCode == 200 && response.data != null) {
        // 记录检查时间
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
            _lastCheckKey, DateTime.now().millisecondsSinceEpoch);

        final latestVersion = _convertToAppVersion(response.data!);

        // 比较版本号
        if (_hasNewVersion(currentInfo.version, latestVersion.version)) {
          return latestVersion;
        }
      }

      return null;
    } catch (e) {
      debugPrint('检查更新失败: $e');
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
  bool _hasNewVersion(String current, String latest) {
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
      debugPrint('版本号比较失败: $e');
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
    Dio? dio;
    try {
      debugPrint('🔄 [APP更新] 开始下载流程');
      onStatus?.call('准备下载...');

      // 请求存储权限
      debugPrint('🔍 [APP更新] 检查存储权限');
      final storageStatus = await Permission.storage.request();
      debugPrint('🔍 [APP更新] storage权限: $storageStatus');
      if (!storageStatus.isGranted) {
        final manageStatus = await Permission.manageExternalStorage.request();
        debugPrint('🔍 [APP更新] manageExternalStorage权限: $manageStatus');
        if (!manageStatus.isGranted) {
          debugPrint('❌ [APP更新] 存储权限被拒绝');
          onStatus?.call('需要存储权限');
          return false;
        }
      }

      // 获取下载目录
      debugPrint('🔍 [APP更新] 获取下载目录');
      final directory = await getApplicationDocumentsDirectory();
      debugPrint('🔍 [APP更新] 下载目录: ${directory.path}');

      // 确保 updates 目录存在
      final updatesDir = Directory('${directory.path}/updates');
      if (!await updatesDir.exists()) {
        await updatesDir.create(recursive: true);
        debugPrint('🔍 [APP更新] 创建 updates 目录');
      }

      final fileName = 'novel_app_v${version.version}.apk';
      final filePath = '${updatesDir.path}/$fileName';
      debugPrint('🔍 [APP更新] 文件路径: $filePath');

      // 构建完整的下载URL
      debugPrint('🔍 [APP更新] 获取API配置');
      final baseUrl = await _apiWrapper.getHost();
      debugPrint('🔍 [APP更新] baseUrl: $baseUrl');
      debugPrint('🔍 [APP更新] version.downloadUrl: ${version.downloadUrl}');

      if (baseUrl == null || baseUrl.isEmpty) {
        debugPrint('❌ [APP更新] baseUrl 配置不完整');
        onStatus?.call('API配置不完整');
        return false;
      }

      final downloadUrl = '$baseUrl${version.downloadUrl}';
      debugPrint('🔍 [APP更新] 完整下载URL: $downloadUrl');

      onStatus?.call('开始下载...');

      // 使用 Dio 下载文件
      debugPrint('🚀 [APP更新] 开始执行下载');
      dio = Dio();

      await dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            debugPrint('📥 [APP更新] 下载进度: ${(progress * 100).toStringAsFixed(0)}%');
            onProgress?.call(progress);
          }
        },
      );

      debugPrint('✅ [APP更新] 下载完成');
      onStatus?.call('下载完成');
      onProgress?.call(1.0);

      return true;
    } on DioException catch (e) {
      debugPrint('❌ [APP更新] 下载失败: ${e.message}');
      debugPrint('❌ [APP更新] 响应状态: ${e.response?.statusCode}');
      onStatus?.call('下载失败: ${e.message}');
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ [APP更新] 下载异常: $e');
      debugPrint('❌ [APP更新] 堆栈: $stackTrace');
      onStatus?.call('下载出错: $e');
      return false;
    } finally {
      dio?.close();
    }
  }

  /// 安装APK
  Future<bool> installUpdate(String version) async {
    try {
      debugPrint('🔧 [APP更新] 开始安装APK');
      // 检查安装权限
      final hasPermission = await requestInstallPermission();
      if (!hasPermission) {
        debugPrint('❌ [APP更新] 没有安装权限');
        return false;
      }

      final fileName = 'novel_app_v$version.apk';

      // 获取应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/updates/$fileName';
      debugPrint('🔍 [APP更新] APK文件路径: $filePath');

      // 检查文件是否存在
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ [APP更新] APK文件不存在: $filePath');
        return false;
      }

      // 使用 MethodChannel 调用原生安装方法
      debugPrint('🚀 [APP更新] 调用原生安装方法');
      final result = await _platformChannel.invokeMethod('installApk', {
        'filePath': filePath,
      });

      return result == true;
    } on PlatformException catch (e) {
      debugPrint('❌ [APP更新] 安装失败: ${e.message}');
      debugPrint('❌ [APP更新] 错误码: ${e.code}');
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ [APP更新] 安装APK失败: $e');
      debugPrint('❌ [APP更新] 堆栈: $stackTrace');
      return false;
    }
  }

  /// 忽略此版本更新
  Future<void> ignoreVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ignoreVersionKey, version);
  }

  /// 检查版本是否被忽略
  Future<bool> isVersionIgnored(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final ignored = prefs.getString(_ignoreVersionKey);
    return ignored == version;
  }

  /// 清除忽略的版本
  Future<void> clearIgnoredVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ignoreVersionKey);
  }
}
