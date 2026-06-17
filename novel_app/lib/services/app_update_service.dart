import 'dart:io';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_version.dart';
import '../utils/device_arch.dart';
import 'github_release_service.dart';
import 'logger_service.dart';
import 'preferences_service.dart';

/// APP更新服务
///
/// 通过 GitHub Releases 获取版本信息和下载 APK
class AppUpdateService {
  static const String _ignoreVersionKey = 'app_update_ignore_version';
  static const _platformChannel =
      MethodChannel('com.example.novel_app/app_install');

  final GithubReleaseService _githubService;
  final Future<PackageInfo> Function()? _packageInfoGetter;

  AppUpdateService({
    GithubReleaseService? githubService,
    Future<PackageInfo> Function()? packageInfoGetter,
  })  : _githubService = githubService ?? GithubReleaseService(),
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
  /// 返回 null 表示没有新版本（或 API 错误/无可用 release）
  Future<AppVersion?> checkForUpdate({bool forceCheck = false}) async {
    try {
      // 频率控制
      if (!await _githubService.shouldCheck(forceCheck: forceCheck)) {
        LoggerService.instance.d(
          '1 小时内已检查过，跳过',
          category: LogCategory.general,
          tags: ['update'],
        );
        return null;
      }

      // 记录检查时间
      await _githubService.recordCheckTime();

      // 获取当前版本
      final currentInfo = await getCurrentVersion();

      // 从 GitHub 获取最新 release
      final release = await _githubService.fetchLatestRelease();
      if (release == null) {
        return null;
      }

      // 检测设备 CPU 架构，按架构选择最合适的 APK
      final arch = await DeviceArchDetector.getCurrent();
      final archSegment = arch.apkNameSegment;

      LoggerService.instance.d(
        '设备架构: ${arch.name} (segment=$archSegment)',
        category: LogCategory.general,
        tags: ['update', 'arch'],
      );

      final asset = release.apkAssetFor(archSegment);
      if (asset == null) {
        LoggerService.instance.w(
          'Release ${release.tagName} 无可用 APK asset (arch=$archSegment)',
          category: LogCategory.general,
          tags: ['update', 'arch', 'noapk'],
        );
        return null;
      }

      // 构造 AppVersion（downloadUrl 使用 GitHub 直链）
      final appVersion = AppVersion(
        version: release.versionNumber,
        downloadUrl: asset.browserDownloadUrl,
        fileSize: asset.size,
        changelog: _extractChangelog(release.body),
        createdAt: release.publishedAt,
      );

      // 比较版本号
      final hasNew =
          hasNewVersion(currentInfo.version, appVersion.version);

      LoggerService.instance.d(
        '版本比较: ${currentInfo.version} vs ${appVersion.version}, hasNew: $hasNew, forceCheck: $forceCheck',
        category: LogCategory.general,
        tags: ['update', 'debug'],
      );

      if (forceCheck || hasNew) {
        return appVersion;
      }

      return null;
    } catch (e) {
      LoggerService.instance.e(
        '检查更新失败: $e',
        category: LogCategory.general,
        tags: ['update', 'check', 'error'],
      );
      return null;
    }
  }

  /// 比较版本号
  ///
  /// 返回 true 表示有新版本
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
        '版本号比较失败: $e',
        category: LogCategory.general,
        tags: ['update', 'version', 'compare'],
      );
      return false;
    }
  }

  /// 请求安装权限
  Future<bool> requestInstallPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    final status = await Permission.requestInstallPackages.request();
    return status.isGranted;
  }

  /// 下载更新
  ///
  /// [onProgress] 进度回调 0.0-1.0
  /// [onStatus] 状态文本回调
  Future<bool> downloadUpdate({
    required AppVersion version,
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    final fileName = 'novel_app_v${version.version}.apk';
    return await _githubService.downloadApk(
      downloadUrl: version.downloadUrl,
      fileName: fileName,
      onProgress: onProgress,
      onStatus: onStatus,
    );
  }

  /// 安装 APK
  Future<bool> installUpdate(String version) async {
    try {
      LoggerService.instance.i(
        '开始安装APK',
        category: LogCategory.general,
        tags: ['update', 'install', 'start'],
      );
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
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/updates/$fileName';

      final file = File(filePath);
      if (!await file.exists()) {
        LoggerService.instance.e(
          'APK文件不存在: $filePath',
          category: LogCategory.general,
          tags: ['update', 'install', 'notfound'],
        );
        return false;
      }

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
        '安装失败: ${e.code}',
        category: LogCategory.general,
        tags: ['update', 'install', 'error'],
      );
      return false;
    } catch (e) {
      LoggerService.instance.e(
        '安装APK失败: $e',
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

  /// 从 GitHub Release body 中提取 changelog
  ///
  /// release body 格式约定：包含 `<!--CHANGELOG_START-->` 和 `<!--CHANGELOG_END-->`
  /// 标记包围的段落。如果标记不存在，回退到标题 `## 📝 更新日志` 之后的内容。
  /// 如果都匹配不到，返回完整 body 原始值。
  static String _extractChangelog(String? body) {
    if (body == null || body.isEmpty) return '';

    // 优先匹配 HTML 注释标记
    final startMarker = '<!--CHANGELOG_START-->';
    final endMarker = '<!--CHANGELOG_END-->';
    final startIdx = body.indexOf(startMarker);
    final endIdx = body.indexOf(endMarker);

    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      final content = body
          .substring(startIdx + startMarker.length, endIdx)
          .trim();
      if (content.isNotEmpty) return content;
    }

    // 回退：匹配 ## 📝 更新日志 标题之后的内容
    final headerMarker = '## 📝 更新日志';
    final headerIdx = body.indexOf(headerMarker);
    if (headerIdx != -1) {
      final afterHeader = body.substring(headerIdx + headerMarker.length).trim();
      if (afterHeader.isNotEmpty) return afterHeader;
    }

    // 最终回退：直接返回 body 原始值
    return body;
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
