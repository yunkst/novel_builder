import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import '../../models/novel.dart';
import '../../models/chapter.dart';
import 'base_crawler.dart';

class AliceSwCrawler implements BaseCrawler {
  @override
  final String baseUrl;
  final http.Client client;

  AliceSwCrawler({this.baseUrl = 'https://www.alicesw.com', http.Client? client})
      : client = client ?? http.Client();

  Map<String, String> get _headers => {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      };

  @override
  bool supports(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.contains('alicesw.com') || host.contains('www.alicesw.com');
  }

  @override
  Future<List<Novel>> searchNovels(String keyword) async {
    if (keyword.isEmpty) return [];
    try {
      final searchUrl = '$baseUrl/search.html';
      final uri = Uri.parse(searchUrl).replace(queryParameters: {
        'q': keyword,
        'f': '_all',
        'sort': 'relevance',
      });
      final response = await client.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final novels = <Novel>[];
        final seenTitles = <String>{};
        // 查找可能的结果项
        final allLinks = document.querySelectorAll('a[href]');
        final re = RegExp(r"/novel/\d+\.html");
        for (final link in allLinks) {
          final href = link.attributes['href'] ?? '';
          if (!re.hasMatch(href)) continue;
          final title = link.text.trim();
          if (title.isEmpty) continue;

          String author = '未知';
          final parent = link.parent;
          if (parent != null) {
            final text = parent.text;
            final m = RegExp(r'作者[：:]\s*([^\n\r<>/,，、\[\]]+)').firstMatch(text);
            if (m != null) {
              author = m.group(1)?.trim() ?? '未知';
            } else {
              final authorLink = parent.querySelector('a[href*="search"][href*="f=author"]');
              if (authorLink != null) {
                author = authorLink.text.trim().isEmpty ? '未知' : authorLink.text.trim();
              }
            }
          }

          if (seenTitles.add(title) && title.length > 1) {
            novels.add(Novel(title: title, author: author, url: _resolveUrl(href)));
            if (novels.length >= 20) break;
          }
        }
        return novels;
      }
      return [];
    } catch (e) {
      print('AliceSW 搜索错误: $e');
      return [];
    }
  }

  @override
  Future<List<Chapter>> getChapterList(String novelUrl) async {
    try {
      final response = await client.get(Uri.parse(novelUrl), headers: _headers);
      if (response.statusCode != 200) return [];
      Document document = parser.parse(response.body);

      // 优先尝试常见容器
      Element? container = document.querySelector('#list') ??
          document.querySelector('.listmain') ??
          document.querySelector('.book_list') ??
          document.querySelector('.chapterlist') ??
          document.querySelector('ul.chapterlist') ??
          document.querySelector('#readerlist') ??
          document.querySelector('div[class*="list"], div[class*="chapter"], div[class*="content"]');

      final chapters = <Chapter>[];

      Future<void> collectFromContainer(Element ctn, String base) async {
        final links = ctn.querySelectorAll('a[href]');
        for (final link in links) {
          final title = link.text.trim();
          final href = link.attributes['href'] ?? '';
          if (title.isNotEmpty && href.isNotEmpty &&
              (href.contains('.html') || href.contains('/book/') || href.contains('/read/'))) {
            if (title.length > 1 && !_shouldSkipTitle(title)) {
              chapters.add(Chapter(title: title, url: _resolveUrl(href, base), chapterIndex: chapters.length));
            }
          }
        }
      }

      if (container != null) {
        await collectFromContainer(container, novelUrl);
      }

      // 如果失败，尝试章节列表专页：/other/chapters/id/{id}.html
      if (chapters.isEmpty) {
        final idMatch = RegExp(r'/novel/(\d+)\.html').firstMatch(novelUrl);
        if (idMatch != null) {
          final id = idMatch.group(1);
          final chapterListUrl = '$baseUrl/other/chapters/id/$id.html';
          final r2 = await client.get(Uri.parse(chapterListUrl), headers: _headers);
          if (r2.statusCode == 200) {
            final doc2 = parser.parse(r2.body);
            final c2 = doc2.querySelector('ul') ?? doc2.querySelector('ol') ??
                doc2.querySelector('div[class*="list"], div[class*="chapter"], div[class*="content"]');
            if (c2 != null) {
              await collectFromContainer(c2, chapterListUrl);
            } else {
              final links = doc2.querySelectorAll('a[href]');
              for (final link in links) {
                final title = link.text.trim();
                final href = link.attributes['href'] ?? '';
                if (title.isNotEmpty && href.contains('/book/')) {
                  if (title.length > 1 && !_shouldSkipTitle(title)) {
                    chapters.add(Chapter(title: title, url: _resolveUrl(href, chapterListUrl), chapterIndex: chapters.length));
                  }
                }
              }
            }
          }
        }
      }

      // 仍为空，尝试详情页中的“在线阅读”等链接导向列表页
      if (chapters.isEmpty) {
        final readLink = document.querySelector('a[href*="read"], a:contains("在线阅读"), a:contains("立即阅读"), a:contains("开始阅读"), a:contains("章节列表"), a:contains("全文阅读")');
        if (readLink != null) {
          final readUrl = _resolveUrl(readLink.attributes['href'] ?? '', novelUrl);
          final r3 = await client.get(Uri.parse(readUrl), headers: _headers);
          if (r3.statusCode == 200) {
            final doc3 = parser.parse(r3.body);
            final c3 = doc3.querySelector('#list') ?? doc3.querySelector('.listmain') ?? doc3.querySelector('.book_list') ??
                doc3.querySelector('.chapterlist') ?? doc3.querySelector('ul.chapterlist') ?? doc3.querySelector('#readerlist') ??
                doc3.querySelector('div[class*="list"], div[class*="chapter"], div[class*="content"]');
            if (c3 != null) {
              await collectFromContainer(c3, readUrl);
            }
          }
        }
      }

      // 最后兜底：全局链接扫描
      if (chapters.isEmpty) {
        final links = document.querySelectorAll('a[href]');
        for (final link in links) {
          final title = link.text.trim();
          final href = link.attributes['href'] ?? '';
          final isCandidate = (href.contains('/book/') || href.contains('/read/') || href.contains('.html'));
          if (isCandidate && title.length > 1 && _isChapterTitle(title) && !_shouldSkipTitle(title)) {
            chapters.add(Chapter(title: title, url: _resolveUrl(href, novelUrl), chapterIndex: chapters.length));
          }
        }
      }

      return chapters;
    } catch (e) {
      print('AliceSW 获取章节列表错误: $e');
      return [];
    }
  }

  @override
  Future<String> getChapterContent(String chapterUrl, {int retryCount = 0}) async {
    const int maxRetries = 3;
    const List<int> retryDelays = [1, 2, 3];
    try {
      final delay = retryCount == 0 ? 0 : retryDelays[retryCount - 1];
      if (delay > 0) {
        await Future.delayed(Duration(seconds: delay));
      }
      final response = await client
          .get(Uri.parse(chapterUrl), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('状态码: ${response.statusCode}');
      }
      final document = parser.parse(response.body);

      // 提取标题
      final titleElem = document.querySelector('h1') ?? document.querySelector('title');
      final title = titleElem?.text.trim() ?? '章节内容';
      
      // 使用段落提取逻辑获取正文内容
      final paragraphs = document.querySelectorAll('p');
      if (paragraphs.length > 5) {
        final paraTexts = paragraphs
            .map((p) => p.text.trim())
            .where((text) => text.isNotEmpty)
            .join('\n');
        if (paraTexts.isNotEmpty) {
          return '标题: $title\n\n$paraTexts';
        }
      }
      
      throw Exception('未能提取到有效的章节内容');
    } catch (e) {
      print('AliceSW 获取章节内容失败 (尝试 ${retryCount + 1}/${maxRetries + 1}): $e');
      if (retryCount < maxRetries) {
        return await getChapterContent(chapterUrl, retryCount: retryCount + 1);
      }
      throw Exception('获取章节内容失败: $e');
    }
  }

  bool _isChapterTitle(String title) {
    return RegExp(r'第\d+|第[一二三四五六七八九十百千万]+|[序终]章|引子|正文|章节|章|节|卷|第.{1,5}章').hasMatch(title) || title.contains('第');
  }

  bool _shouldSkipTitle(String title) {
    final skipKeywords = ['封面', '图片', '插图', '返回首页', '加入书架', '发表评论', 'txt下载', '在线阅读', '首页', '分类', '排行'];
    return skipKeywords.any((k) => title.toLowerCase().contains(k.toLowerCase()));
  }

  String _resolveUrl(String href, [String? base]) {
    if (href.startsWith('http://') || href.startsWith('https://')) return href;
    final baseUri = Uri.parse(base ?? baseUrl);
    return baseUri.resolve(href).toString();
  }
}