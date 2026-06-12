import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/github_release.dart';
import 'logger_service.dart';
import 'preferences_service.dart';

/// GitHub Releases API 服务
///
/// 从 GitHub Releases 获取最新版本信息并下载 APK
class GithubReleaseService {
  static const String _apiBase = 'https://api.github.com';
  static const String _repoOwner = 'yunkst';
  static const String _repoName = 'novel_builder';

  static const String _lastCheckKey = 'app_update_last_check';

  final Dio _dio;

  GithubReleaseService({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 15)));

  /// 获取最新 Release 信息
  ///
  /// 调用 GitHub API `/repos/{owner}/{repo}/releases/latest`
  /// 返回 null 表示无可用 release 或网络错误
  Future<GithubRelease?> fetchLatestRelease() async {
    try {
      final url = '$_apiBase/repos/$_repoOwner/$_repoName/releases/latest';
      LoggerService.instance.d(
        'GitHub API: $url',
        category: LogCategory.network,
        tags: ['update', 'github'],
      );

      final response = await _dio.get<Map<String, dynamic>>(url);

      if (response.statusCode == 200 && response.data != null) {
        final release = GithubRelease.fromJson(response.data!);

        // 跳过 draft 和 prerelease
        if (release.draft || release.prerelease) {
          LoggerService.instance.d(
            '跳过 draft/prerelease: ${release.tagName}',
            category: LogCategory.network,
            tags: ['update', 'github'],
          );
          return null;
        }

        // 确认有 APK asset
        if (release.apkAsset == null) {
          LoggerService.instance.w(
            'Release ${release.tagName} 无 APK asset',
            category: LogCategory.network,
            tags: ['update', 'github'],
          );
          return null;
        }

        return release;
      }

      return null;
    } on DioException catch (e) {
      // 404 = 没有 release，静默处理
      if (e.response?.statusCode == 404) {
        LoggerService.instance.d(
          'GitHub: 无 latest release (404)',
          category: LogCategory.network,
          tags: ['update', 'github'],
        );
        return null;
      }

      LoggerService.instance.e(
        'GitHub API 请求失败: ${e.message}',
        category: LogCategory.network,
        tags: ['update', 'github', 'error'],
      );
      return null;
    } catch (e) {
      LoggerService.instance.e(
        '获取 GitHub Release 失败: $e',
        category: LogCategory.network,
        tags: ['update', 'github', 'error'],
      );
      return null;
    }
  }

  /// 检查是否应执行更新检查（频率控制）
  ///
  /// 非强制检查时，距离上次检查不足 1 小时则跳过
  Future<bool> shouldCheck({bool forceCheck = false}) async {
    if (forceCheck) return true;

    final lastCheck = await PreferencesService.instance.getInt(_lastCheckKey);
    final now = DateTime.now().millisecondsSinceEpoch;

    if ((now - lastCheck) < 3600000) {
      return false;
    }

    return true;
  }

  /// 记录检查时间
  Future<void> recordCheckTime() async {
    await PreferencesService.instance
        .setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// 下载 APK 文件
  ///
  /// [downloadUrl] GitHub asset 的 browser_download_url（完整 URL）
  /// [fileName] 保存的文件名（如 novel_app_v1.7.7.apk）
  /// [onProgress] 进度回调 0.0-1.0
  /// [onStatus] 状态文本回调
  Future<bool> downloadApk({
    required String downloadUrl,
    required String fileName,
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    try {
      onStatus?.call('准备下载...');

      // 请求存储权限
      final storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        final manageStatus =
            await Permission.manageExternalStorage.request();
        if (!manageStatus.isGranted) {
          onStatus?.call('需要存储权限');
          return false;
        }
      }

      // 获取下载目录
      final directory = await getApplicationDocumentsDirectory();
      final updatesDir = Directory('${directory.path}/updates');
      if (!await updatesDir.exists()) {
        await updatesDir.create(recursive: true);
      }

      final filePath = '${updatesDir.path}/$fileName';

      // 如果已存在同名文件，先删除
      final existingFile = File(filePath);
      if (await existingFile.exists()) {
        await existingFile.delete();
      }

      onStatus?.call('开始下载...');

      LoggerService.instance.i(
        '从 GitHub 下载 APK: $downloadUrl',
        category: LogCategory.network,
        tags: ['update', 'download'],
      );

      await _dio.download(
        downloadUrl,
        filePath,
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            onProgress?.call(progress);
          }
        },
      );

      onStatus?.call('下载完成');
      onProgress?.call(1.0);

      LoggerService.instance.i(
        'APK 下载完成: $filePath',
        category: LogCategory.network,
        tags: ['update', 'download', 'success'],
      );

      return true;
    } on DioException catch (e) {
      LoggerService.instance.e(
        'APK 下载失败: ${e.message}',
        category: LogCategory.network,
        tags: ['update', 'download', 'error'],
      );

      if (e.response != null) {
        onStatus?.call('下载失败: 服务器错误 ${e.response?.statusCode}');
      } else {
        onStatus?.call('下载失败: ${e.message ?? "网络错误"}');
      }

      return false;
    } catch (e) {
      LoggerService.instance.e(
        'APK 下载异常: $e',
        category: LogCategory.network,
        tags: ['update', 'download', 'error'],
      );
      onStatus?.call('下载出错: $e');
      return false;
    }
  }
}
