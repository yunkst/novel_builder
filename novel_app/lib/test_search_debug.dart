import 'package:flutter/material.dart';
import 'services/database_service.dart';

/// 调试搜索功能的工具页面
class SearchDebugScreen extends StatefulWidget {
  const SearchDebugScreen({super.key});

  @override
  State<SearchDebugScreen> createState() => _SearchDebugScreenState();
}

class _SearchDebugScreenState extends State<SearchDebugScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _novels = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String? _selectedNovelUrl;
  final TextEditingController _keywordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNovels();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _loadNovels() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await _databaseService.database;
      final novels = await db.rawQuery('''
        SELECT DISTINCT novelUrl, COUNT(*) as chapter_count
        FROM chapter_cache
        GROUP BY novelUrl
        ORDER BY chapter_count DESC
      ''');

      setState(() {
        _novels = novels;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('加载小说列表失败: $e');
    }
  }

  Future<void> _testSearch(String keyword) async {
    if (_selectedNovelUrl == null || keyword.trim().isEmpty) {
      return;
    }

        setState(() {
      _isLoading = true;
    });

    try {
      final db = await _databaseService.database;

      // 测试 searchInNovel 逻辑
      final novelResults = await db.query(
        'chapter_cache',
        where: '(content LIKE ? OR title LIKE ?) AND novelUrl = ?',
        whereArgs: ['%$keyword%', '%$keyword%', _selectedNovelUrl],
        orderBy: 'chapterIndex',
      );

      // 测试 searchInAllNovels 逻辑
      final allResults = await db.query(
        'chapter_cache',
        where: 'content LIKE ? OR title LIKE ?',
        whereArgs: ['%$keyword%', '%$keyword%'],
        orderBy: 'novelUrl, chapterIndex',
      );

      // 检查来自其他小说的结果
      final otherNovelResults = allResults
          .where((result) => result['novelUrl'] != _selectedNovelUrl)
          .toList();

      final results = [
        {
          'type': 'searchInNovel',
          'count': novelResults.length,
          'results': novelResults.take(5).toList(),
        },
        {
          'type': 'searchInAllNovels',
          'count': allResults.length,
          'results': allResults.take(5).toList(),
          'other_novel_count': otherNovelResults.length,
          'other_novels': otherNovelResults.take(3).toList(),
        },
      ];

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }

      debugPrint('搜索关键词: "$keyword"');
      debugPrint('选定小说: $_selectedNovelUrl');
      debugPrint('searchInNovel 结果: ${novelResults.length}');
      debugPrint('searchInAllNovels 结果: ${allResults.length}');
      debugPrint('来自其他小说的结果: ${otherNovelResults.length}');

      if (otherNovelResults.isNotEmpty) {
        debugPrint('⚠️ 发现来自其他小说的结果!');
        for (var result in otherNovelResults.take(3)) {
          debugPrint('  - 小说: ${result['novelUrl']}');
          debugPrint('    章节: ${result['title']}');
        }
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        debugPrint('搜索测试失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索功能调试'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 小说选择
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '1. 选择测试小说',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButton<String>(
                            hint: const Text('请选择小说'),
                            value: _selectedNovelUrl,
                            isExpanded: true,
                            items: _novels.map((novel) {
                              return DropdownMenuItem<String>(
                                value: novel['novelUrl'] as String,
                                child: Text(
                                  '${novel['novelUrl']} (${novel['chapter_count']} 章)',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedNovelUrl = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 搜索测试
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '2. 输入搜索关键词',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _keywordController,
                            decoration: InputDecoration(
                              hintText: '输入搜索关键词',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: () {
                                  if (_keywordController.text.isNotEmpty &&
                                      _selectedNovelUrl != null) {
                                    _testSearch(_keywordController.text);
                                  }
                                },
                              ),
                            ),
                            onSubmitted: (value) {
                              if (value.isNotEmpty && _selectedNovelUrl != null) {
                                _testSearch(value);
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: ['的', '了', '是', '在', '有', '我', '他'].map((keyword) {
                              return ActionChip(
                                label: Text(keyword),
                                onPressed: () {
                                  _keywordController.text = keyword;
                                  if (_selectedNovelUrl != null) {
                                    _testSearch(keyword);
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 搜索结果
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '3. 搜索结果对比',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: _searchResults.isEmpty
                                  ? const Center(
                                      child: Text('请选择小说并输入关键词进行测试'),
                                    )
                                  : ListView.builder(
                                      itemCount: _searchResults.length,
                                      itemBuilder: (context, index) {
                                        final result = _searchResults[index];
                                        final type = result['type'] as String;
                                        final count = result['count'] as int;
                                        final results = result['results'] as List;

                                        return Card(
                                          color: type == 'searchInAllNovels' &&
                                                  result['other_novel_count'] > 0
                                              ? Colors.red.shade50
                                              : null,
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      type,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 8,
                                                              vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      child: Text(
                                                        '$count 个结果',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (type == 'searchInAllNovels' &&
                                                    result['other_novel_count'] >
                                                        0) ...[
                                                  const SizedBox(height: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text(
                                                      '⚠️ 包含 ${result['other_novel_count']} 个来自其他小说的结果!',
                                                      style: TextStyle(
                                                        color: Colors.red.shade800,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ...((result['other_novels']
                                                          as List)
                                                      .map<Widget>((otherResult) {
                                                    return Padding(
                                                      padding: const EdgeInsets
                                                          .only(bottom: 4),
                                                      child: Text(
                                                        '🔸 ${otherResult['novelUrl']} - ${otherResult['title']}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.red.shade700,
                                                        ),
                                                      ),
                                                    );
                                                  })),
                                                ],
                                                const SizedBox(height: 8),
                                                ...results.map<Widget>((chapterResult) {
                                                  return Padding(
                                                    padding: const EdgeInsets
                                                        .only(bottom: 4),
                                                    child: Text(
                                                      '• ${chapterResult['title']} (${chapterResult['novelUrl']})',
                                                      style: const TextStyle(
                                                          fontSize: 14),
                                                    ),
                                                  );
                                                }),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}