import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import '../../models/novel.dart';
import '../../models/chapter.dart';
import 'base_crawler.dart';

class ShukugeCrawler implements BaseCrawler {
  @override
  final String baseUrl;
  final http.Client client;

  ShukugeCrawler({this.baseUrl = 'http://www.shukuge.com', http.Client? client})
      : client = client ?? http.Client();

  Map<String, String> get _headers => {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      };

  @override
  bool supports(Uri uri) {
    // 仅支持书库阁域名
    final host = uri.host.toLowerCase();
    return host.contains('shukuge.com') || host.contains('www.shukuge.com');
  }

  @override
  Future<List<Novel>> searchNovels(String keyword) async {
    if (keyword.isEmpty) return [];

    try {
      final searchUrl = '$baseUrl/Search';
      final uri = Uri.parse(searchUrl).replace(queryParameters: {'wd': keyword});
      final response = await client.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final novels = <Novel>[];
        final seenTitles = <String>{};
        final allLinks = document.querySelectorAll('a[href]');
        for (var link in allLinks) {
          final title = link.text.trim();
          final href = link.attributes['href'] ?? '';
          if (title.toLowerCase().contains(keyword.toLowerCase()) &&
              (href.contains('/book/') || href.contains('/read/') || href.contains('/modules/article'))) {
            String author = '未知';
            final parent = link.parent;
            if (parent != null) {
              final text = parent.text;
              final authorMatch = RegExp(r'作者[：:]\s*([^\s\n\r<>/]+)').firstMatch(text);
              if (authorMatch != null) {
                author = authorMatch.group(1)?.trim() ?? '未知';
              }
            }
            if (!seenTitles.contains(title) && title.length > 1) {
              seenTitles.add(title);
              novels.add(Novel(title: title, author: author, url: _resolveUrl(href)));
              if (novels.length >= 20) break;
            }
          }
        }
        return novels;
      }
      return [];
    } catch (e) {
      print('搜索错误: $e');
      return [];
    }
  }

  @override
  Future<List<Chapter>> getChapterList(String novelUrl) async {
    try {
      final response = await client.get(Uri.parse(novelUrl), headers: _headers);
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        String chapterListUrl = novelUrl;
        for (var link in document.querySelectorAll('a')) {
          if (link.text.contains('在线阅读') || link.text.contains('立即阅读') || link.text.contains('章节列表')) {
            chapterListUrl = _resolveUrl(link.attributes['href'] ?? '');
            break;
          }
        }
        if (chapterListUrl != novelUrl) {
          final chapterResponse = await client.get(Uri.parse(chapterListUrl), headers: _headers);
          if (chapterResponse.statusCode == 200) {
            final chapterDoc = parser.parse(chapterResponse.body);
            return _extractChapters(chapterDoc, chapterListUrl);
          }
        }
        return _extractChapters(document, novelUrl);
      }
      return [];
    } catch (e) {
      print('获取章节列表错误: $e');
      return [];
    }
  }

  List<Chapter> _extractChapters(Document document, String baseUrl) {
    final chapters = <Chapter>[];
    Element? chapterList = document.querySelector('#list') ??
        document.querySelector('.listmain') ??
        document.querySelector('dl') ??
        document.querySelector('.book_list') ??
        document.querySelector('.chapterlist') ??
        document.querySelector('#readerlist');
    if (chapterList == null) {
      for (var div in document.querySelectorAll('div, ul, ol')) {
        final links = div.querySelectorAll('a[href]');
        final chapterLinks = <Chapter>[];
        for (var link in links) {
          final title = link.text.trim();
          final href = link.attributes['href'] ?? '';
          if (_isChapterTitle(title) && title.length > 1) {
            chapterLinks.add(Chapter(title: title, url: _resolveUrl(href, baseUrl)));
          }
        }
        if (chapterLinks.length > 5) {
          chapters.addAll(chapterLinks);
          break;
        }
      }
    } else {
      final links = chapterList.querySelectorAll('a[href]');
      for (var link in links) {
        final title = link.text.trim();
        final href = link.attributes['href'] ?? '';
        if (title.isNotEmpty && href.isNotEmpty &&
            (href.contains('.html') || href.contains('/book/') || href.contains('/read/'))) {
          if (title.length > 1 && !_shouldSkipTitle(title)) {
            chapters.add(Chapter(title: title, url: _resolveUrl(href, baseUrl), chapterIndex: chapters.length));
          }
        }
      }
    }
    return chapters;
  }

  @override
  Future<String> getChapterContent(String chapterUrl, {int retryCount = 0}) async {
    const int maxRetries = 3;
    const List<int> retryDelays = [2, 5, 10];
    try {
      int baseDelay = retryCount == 0 ? 1 : retryDelays[retryCount - 1];
      await Future.delayed(Duration(seconds: baseDelay));
      final response = await client
          .get(Uri.parse(chapterUrl), headers: _headers)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        Element? contentDiv = document.querySelector('#content') ??
            document.querySelector('.content') ??
            document.querySelector('.readcontent') ??
            document.querySelector('#chaptercontent') ??
            document.querySelector('.chapter-content') ??
            document.querySelector('.book_con') ??
            document.querySelector('.showtxt');
        if (contentDiv == null) {
          final divs = document.querySelectorAll('div');
          int maxLength = 0;
          for (var div in divs) {
            final textLength = div.text.length;
            if (textLength > maxLength && textLength > 500) {
              maxLength = textLength;
              contentDiv = div;
            }
          }
        }
        if (contentDiv != null) {
          final titleElem = document.querySelector('h1') ?? document.querySelector('title');
          final title = titleElem?.text.trim() ?? '章节内容';
          for (var script in contentDiv.querySelectorAll('script, style')) {
            script.remove();
          }
          String content = contentDiv.text.trim();
          content = _cleanContent(content);
          if (content.length < 100) {
            throw Exception('章节内容过短，可能解析失败');
          }
          return '标题: $title\n\n$content';
        }
        final paragraphs = document.querySelectorAll('p');
        if (paragraphs.length > 5) {
          final paraTexts = paragraphs
              .map((p) => p.text.trim())
              .where((text) => !_containsExcludedKeywords(text))
              .take(50)
              .join('\n');
          if (paraTexts.isNotEmpty && paraTexts.length > 100) {
            final titleElem = document.querySelector('h1') ?? document.querySelector('title');
            final title = titleElem?.text.trim() ?? '章节内容';
            return '标题: $title\n\n$paraTexts';
          }
        }
        throw Exception('未能提取到有效的章节内容');
      } else if (response.statusCode == 429) {
        throw Exception('请求过于频繁，请稍后重试');
      } else {
        throw Exception('服务器响应错误，状态码: ${response.statusCode}');
      }
    } catch (e) {
      print('获取章节内容失败 (尝试 ${retryCount + 1}/${maxRetries + 1}): $e');
      if (retryCount < maxRetries) {
        return await getChapterContent(chapterUrl, retryCount: retryCount + 1);
      }
      throw Exception('获取章节内容失败: $e');
    }
  }

  /// 清理正文内容，移除广告/噪音并规范换行与空白。
  String _cleanContent(String content) {
    // 统一换行与空白
    content = content.replaceAll('\r', '\n');
    content = content.replaceAll('\t', ' ');
    content = content.replaceAll(RegExp(r'\n\s*\n+'), '\n');
    content = content.replaceAll(RegExp(r' +'), ' ');

    final lines = content.split('\n');
    final cleaned = <String>[];

    for (var raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      // 过滤噪音关键字，但不按长度过滤
      if (_containsExcludedKeywords(line)) continue;
      cleaned.add(line);
    }

    // 合并为段落文本
    return cleaned.join('\n');
  }

  bool _isChapterTitle(String title) {
    return RegExp(r'第\d+|第[一二三四五六七八九十]+|引子|序章|终章|大结局|章节|章|节').hasMatch(title) || title.contains('第');
  }

  bool _shouldSkipTitle(String title) {
    final skipKeywords = ['封面', '图片', '插图', '返回首页', '加入书架', '发表评论', 'txt下载', '在线阅读', '立即下载'];
    return skipKeywords.any((keyword) => title.toLowerCase().contains(keyword.toLowerCase()));
  }

  bool _containsExcludedKeywords(String text) {
    final keywords = ['copyright', '站点地图', '热搜小说', '广告', '推荐', '返回', '目录', '加入书签'];
    return keywords.any((keyword) => text.toLowerCase().contains(keyword.toLowerCase()));
  }

  String _resolveUrl(String href, [String? base]) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      return href;
    }
    final baseUri = Uri.parse(base ?? baseUrl);
    return baseUri.resolve(href).toString();
  }
}