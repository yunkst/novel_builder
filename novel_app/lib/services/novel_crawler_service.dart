import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import '../models/novel.dart';
import '../models/chapter.dart';

class NovelCrawlerService {
  final String baseUrl = 'http://www.shukuge.com';
  final http.Client client;

  NovelCrawlerService() : client = http.Client() {
    // 添加默认请求头
  }

  Map<String, String> get _headers => {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      };

  /// 搜索小说
  Future<List<Novel>> searchNovels(String keyword) async {
    if (keyword.isEmpty) {
      return [];
    }

    try {
      final searchUrl = '$baseUrl/Search';
      final uri = Uri.parse(searchUrl).replace(queryParameters: {'wd': keyword});

      final response = await client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        // 处理中文编码
        final document = parser.parse(response.body);
        final novels = <Novel>[];
        final seenTitles = <String>{};

        // 查找所有链接
        final allLinks = document.querySelectorAll('a[href]');

        for (var link in allLinks) {
          final title = link.text.trim();
          final href = link.attributes['href'] ?? '';

          // 检查是否是小说相关链接
          if (title.toLowerCase().contains(keyword.toLowerCase()) &&
              (href.contains('/book/') ||
                  href.contains('/read/') ||
                  href.contains('/modules/article'))) {
            // 获取作者信息
            String author = '未知';
            final parent = link.parent;
            if (parent != null) {
              final text = parent.text;
              final authorMatch = RegExp(r'作者[：:]\s*([^\s\n\r<>/]+)').firstMatch(text);
              if (authorMatch != null) {
                author = authorMatch.group(1)?.trim() ?? '未知';
              }
            }

            // 去重
            if (!seenTitles.contains(title) && title.length > 1) {
              seenTitles.add(title);
              novels.add(Novel(
                title: title,
                author: author,
                url: _resolveUrl(href),
              ));

              if (novels.length >= 20) break;
            }
          }
        }

        return novels;
      }

      return [];
    } catch (e) {
      print('搜索过程中出现错误: $e');
      return [];
    }
  }

  /// 获取章节列表
  Future<List<Chapter>> getChapterList(String novelUrl) async {
    try {
      final response = await client.get(Uri.parse(novelUrl), headers: _headers);

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final chapters = <Chapter>[];

        // 首先查找"在线阅读"链接
        String chapterListUrl = novelUrl;

        for (var link in document.querySelectorAll('a')) {
          if (link.text.contains('在线阅读') ||
              link.text.contains('立即阅读') ||
              link.text.contains('章节列表')) {
            chapterListUrl = _resolveUrl(link.attributes['href'] ?? '');
            break;
          }
        }

        // 如果找到章节列表页，重新请求
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
      print('获取章节列表时出现错误: $e');
      return [];
    }
  }

  /// 从文档中提取章节
  List<Chapter> _extractChapters(Document document, String baseUrl) {
    final chapters = <Chapter>[];

    // 尝试查找章节列表容器
    Element? chapterList = document.querySelector('#list') ??
        document.querySelector('.listmain') ??
        document.querySelector('dl') ??
        document.querySelector('.book_list') ??
        document.querySelector('.chapterlist') ??
        document.querySelector('#readerlist');

    // 如果没有找到标准容器，尝试其他方法
    if (chapterList == null) {
      for (var div in document.querySelectorAll('div, ul, ol')) {
        final links = div.querySelectorAll('a[href]');
        final chapterLinks = <Chapter>[];

        for (var link in links) {
          final title = link.text.trim();
          final href = link.attributes['href'] ?? '';

          // 检查是否是章节链接
          if (_isChapterTitle(title) && title.length > 1) {
            chapterLinks.add(Chapter(
              title: title,
              url: _resolveUrl(href, baseUrl),
            ));
          }
        }

        if (chapterLinks.length > 5) {
          chapters.addAll(chapterLinks);
          break;
        }
      }
    } else {
      // 从标准容器中提取章节
      final links = chapterList.querySelectorAll('a[href]');
      for (var link in links) {
        final title = link.text.trim();
        final href = link.attributes['href'] ?? '';

        if (title.isNotEmpty &&
            href.isNotEmpty &&
            (href.contains('.html') || href.contains('/book/') || href.contains('/read/'))) {
          if (title.length > 1 && !_shouldSkipTitle(title)) {
            chapters.add(Chapter(
              title: title,
              url: _resolveUrl(href, baseUrl),
              chapterIndex: chapters.length,
            ));
          }
        }
      }
    }

    return chapters;
  }

  /// 获取章节内容
  Future<String> getChapterContent(String chapterUrl) async {
    try {
      await Future.delayed(const Duration(seconds: 1)); // 避免请求过于频繁

      final response = await client.get(Uri.parse(chapterUrl), headers: _headers);

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);

        // 尝试不同的内容选择器
        Element? contentDiv = document.querySelector('#content') ??
            document.querySelector('.content') ??
            document.querySelector('.readcontent') ??
            document.querySelector('#chaptercontent') ??
            document.querySelector('.chapter-content') ??
            document.querySelector('.book_con') ??
            document.querySelector('.showtxt');

        // 如果没找到标准容器，查找文本最长的div
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
          // 提取标题
          final titleElem = document.querySelector('h1') ?? document.querySelector('title');
          final title = titleElem?.text.trim() ?? '章节内容';

          // 移除脚本和样式标签
          for (var script in contentDiv.querySelectorAll('script, style')) {
            script.remove();
          }

          // 获取文本内容
          String content = contentDiv.text.trim();

          // 清理内容
          content = _cleanContent(content);

          return '标题: $title\n\n$content';
        }

        // 如果还是没找到，尝试查找所有段落
        final paragraphs = document.querySelectorAll('p');
        if (paragraphs.length > 5) {
          final paraTexts = paragraphs
              .map((p) => p.text.trim())
              .where((text) =>
                  text.length > 20 &&
                  !_containsExcludedKeywords(text))
              .take(50)
              .join('\n');

          if (paraTexts.isNotEmpty) {
            final titleElem = document.querySelector('h1') ?? document.querySelector('title');
            final title = titleElem?.text.trim() ?? '章节内容';
            return '标题: $title\n\n$paraTexts';
          }
        }

        return '未能提取到章节内容';
      }

      return '获取章节内容失败，状态码: ${response.statusCode}';
    } catch (e) {
      return '获取章节内容时出现错误: $e';
    }
  }

  /// 清理内容
  String _cleanContent(String content) {
    // 移除多余空白
    content = content.replaceAll(RegExp(r'\n\s*\n'), '\n');
    content = content.replaceAll(RegExp(r' +'), ' ');

    // 过滤掉明显不是正文的内容
    final lines = content.split('\n');
    final filteredLines = lines.where((line) {
      line = line.trim();
      return line.length > 10 && !_containsExcludedKeywords(line);
    }).toList();

    return filteredLines.join('\n');
  }

  /// 检查是否包含排除关键词
  bool _containsExcludedKeywords(String text) {
    final keywords = ['copyright', '站点地图', '热搜小说', '广告', '推荐', '返回', '目录', '加入书签'];
    return keywords.any((keyword) => text.toLowerCase().contains(keyword.toLowerCase()));
  }

  /// 检查是否是章节标题
  bool _isChapterTitle(String title) {
    return RegExp(r'第\d+|第[一二三四五六七八九十]+|引子|序章|终章|大结局|章节|章|节').hasMatch(title) ||
        title.contains('第');
  }

  /// 检查是否应该跳过的标题
  bool _shouldSkipTitle(String title) {
    final skipKeywords = ['封面', '图片', '插图', '返回首页', '加入书架', '发表评论', 'txt下载', '在线阅读', '立即下载'];
    return skipKeywords.any((keyword) => title.toLowerCase().contains(keyword.toLowerCase()));
  }

  /// 解析URL
  String _resolveUrl(String href, [String? base]) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      return href;
    }
    final baseUri = Uri.parse(base ?? baseUrl);
    return baseUri.resolve(href).toString();
  }

  void dispose() {
    client.close();
  }
}
