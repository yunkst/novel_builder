/// GitHub Release 数据模型
///
/// 对应 GitHub API `/repos/{owner}/{repo}/releases/latest` 响应
class GithubRelease {
  final String tagName;
  final String name;
  final String? body;
  final String publishedAt;
  final bool prerelease;
  final bool draft;
  final List<GithubAsset> assets;

  GithubRelease({
    required this.tagName,
    required this.name,
    this.body,
    required this.publishedAt,
    required this.prerelease,
    required this.draft,
    required this.assets,
  });

  factory GithubRelease.fromJson(Map<String, dynamic> json) {
    return GithubRelease(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      body: json['body'] as String?,
      publishedAt: json['published_at'] as String? ?? '',
      prerelease: json['prerelease'] as bool? ?? false,
      draft: json['draft'] as bool? ?? false,
      assets: (json['assets'] as List<dynamic>?)
              ?.map((e) => GithubAsset.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// 获取第一个 APK asset（通常只有一个）
  GithubAsset? get apkAsset {
    try {
      return assets.firstWhere(
        (a) => a.contentType == 'application/vnd.android.package-archive',
      );
    } catch (_) {
      // fallback: 按 .apk 后缀匹配
      try {
        return assets.firstWhere((a) => a.name.endsWith('.apk'));
      } catch (_) {
        return null;
      }
    }
  }

  /// 版本号（去除 'v' 前缀）
  /// "v1.7.7" → "1.7.7"
  String get versionNumber => tagName.replaceFirst(RegExp(r'^v'), '');
}

/// GitHub Release Asset 数据模型
class GithubAsset {
  final String name;
  final int size;
  final String browserDownloadUrl;
  final String contentType;

  GithubAsset({
    required this.name,
    required this.size,
    required this.browserDownloadUrl,
    required this.contentType,
  });

  factory GithubAsset.fromJson(Map<String, dynamic> json) {
    return GithubAsset(
      name: json['name'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      browserDownloadUrl: json['browser_download_url'] as String? ?? '',
      contentType: json['content_type'] as String? ?? '',
    );
  }
}
