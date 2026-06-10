import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../services/logger_service.dart';

/// 浏览器收藏夹数据模型
class Bookmark {
  final String id;
  final String title;
  final String url;
  final DateTime createdAt;

  Bookmark({
    required this.id,
    required this.title,
    required this.url,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        id: json['id'] as String,
        title: json['title'] as String,
        url: json['url'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bookmark && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 浏览器收藏夹持久化服务
class BookmarkService {
  static const _key = 'browser_bookmarks';

  final SharedPreferences _prefs;

  BookmarkService(this._prefs);

  /// 加载所有收藏
  List<Bookmark> loadBookmarks() {
    try {
      final raw = _prefs.getStringList(_key);
      if (raw == null) return [];
      return raw
          .map((s) {
            try {
              return Bookmark.fromJson(
                  jsonDecode(s) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<Bookmark>()
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '加载收藏夹失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['bookmark', 'load', 'error'],
      );
      return [];
    }
  }

  /// 保存所有收藏
  Future<void> saveBookmarks(List<Bookmark> bookmarks) async {
    try {
      final raw =
          bookmarks.map((b) => jsonEncode(b.toJson())).toList();
      await _prefs.setStringList(_key, raw);
      LoggerService.instance.d(
        '保存 ${bookmarks.length} 条收藏',
        category: LogCategory.database,
        tags: ['bookmark', 'save'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '保存收藏夹失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['bookmark', 'save', 'error'],
      );
    }
  }

  /// 添加收藏
  Future<void> addBookmark(Bookmark bookmark) async {
    final bookmarks = loadBookmarks();
    // 避免重复 URL
    bookmarks.removeWhere((b) => b.url == bookmark.url);
    bookmarks.add(bookmark);
    await saveBookmarks(bookmarks);
  }

  /// 删除收藏
  Future<void> removeBookmark(String id) async {
    final bookmarks = loadBookmarks();
    bookmarks.removeWhere((b) => b.id == id);
    await saveBookmarks(bookmarks);
  }

  /// 检查 URL 是否已收藏
  bool isBookmarked(String url) {
    return loadBookmarks().any((b) => b.url == url);
  }
}
