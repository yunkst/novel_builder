import 'package:flutter/material.dart';
import '../models/chapter.dart';
import '../services/character_extraction_service.dart';
import '../services/logger_service.dart';

/// 创建模式枚举
enum CreateMode {
  describe, // AI描述创建
  outline, // 从大纲生成
  extract, // 提取角色
}

/// 章节匹配结果（用于UI显示）
class ChapterMatchItem {
  final Chapter chapter;
  final int matchCount;
  bool isSelected;

  ChapterMatchItem({
    required this.chapter,
    required this.matchCount,
    this.isSelected = true,
  });
}

/// 角色创建输入对话框
class CharacterInputDialog extends StatefulWidget {
  /// 是否有大纲可用于生成角色
  final bool hasOutline;
  /// 小说URL（用于提取角色功能）
  final String? novelUrl;

  const CharacterInputDialog({
    super.key,
    this.hasOutline = false,
    this.novelUrl,
  });

  @override
  State<CharacterInputDialog> createState() => _CharacterInputDialogState();

  /// 显示对话框并返回用户输入和模式
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    bool hasOutline = false,
    String? novelUrl,
  }) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CharacterInputDialog(
        hasOutline: hasOutline,
        novelUrl: novelUrl,
      ),
    );
  }
}

class _CharacterInputDialogState extends State<CharacterInputDialog> {
  final _descriptionController = TextEditingController();
  final _nameController = TextEditingController();
  final _aliasesController = TextEditingController();

  CreateMode _mode = CreateMode.describe;
  bool _useOutline = true;

  // 提取角色相关状态
  final CharacterExtractionService _extractionService =
      CharacterExtractionService();
  int _contextLength = 500;
  bool _extractFullChapter = false;
  List<ChapterMatchItem> _matchedChapters = [];
  bool _isSearching = false;
  String? _searchError;

  // 常量
  static const int _minContextLength = 100;
  static const int _maxContextLength = 1000;
  static const int _maxTotalContentLength = 100000; // 总内容长度上限10万字

  @override
  void initState() {
    super.initState();
    if (!widget.hasOutline) {
      _useOutline = false;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _nameController.dispose();
    _aliasesController.dispose();
    super.dispose();
  }

  bool get _canExtract => widget.novelUrl != null && widget.novelUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI创建角色'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 模式选择
              _buildModeSelector(),
              const SizedBox(height: 16),

              // 根据模式显示不同内容
              if (_mode == CreateMode.describe) _buildDescribeMode(),
              if (_mode == CreateMode.outline) _buildOutlineMode(),
              if (_mode == CreateMode.extract) _buildExtractMode(),
            ],
          ),
        ),
      ),
      actions: _buildActions(),
    );
  }

  /// 构建模式选择器
  Widget _buildModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择创建方式',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildModeButton('AI描述', CreateMode.describe),
            const SizedBox(width: 8),
            if (widget.hasOutline)
              _buildModeButton('从大纲', CreateMode.outline),
            if (widget.hasOutline) const SizedBox(width: 8),
            _buildModeButton('提取角色', CreateMode.extract),
          ],
        ),
      ],
    );
  }

  /// 构建模式按钮
  Widget _buildModeButton(String label, CreateMode mode) {
    final isSelected = _mode == mode;
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _mode = mode;
          });
        },
        style: OutlinedButton.styleFrom(
          backgroundColor:
              isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
          foregroundColor: isSelected ? Colors.blue : null,
          side: BorderSide(
            color: isSelected ? Colors.blue : Colors.grey,
          ),
        ),
        child: Text(label),
      ),
    );
  }

  /// 构建AI描述模式
  Widget _buildDescribeMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '请描述您想要创建的角色：',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: '角色描述',
            hintText: '例如：一个勇敢的骑士，忠诚而正直',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          minLines: 2,
        ),
        const SizedBox(height: 12),
        _buildTipsCard(
          '描述角色的性格、外貌、职业、背景等特点，越详细越好。',
        ),
      ],
    );
  }

  /// 构建大纲模式
  Widget _buildOutlineMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text(
            '从大纲生成角色',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: const Text(
            '利用已有大纲生成更符合故事设定的角色',
            style: TextStyle(fontSize: 12),
          ),
          value: _useOutline,
          onChanged: (value) {
            setState(() {
              _useOutline = value;
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        const Text(
          '请描述您想要创建的角色：',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: '角色描述',
            hintText: '例如：生成故事中的主要配角',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          minLines: 2,
        ),
        const SizedBox(height: 12),
        _buildTipsCard(
          '描述角色的性格、外貌、职业、背景等特点，越详细越好。',
        ),
      ],
    );
  }

  /// 构建提取角色模式
  Widget _buildExtractMode() {
    final canExtract = _canExtract;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!canExtract)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, size: 16, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '提取角色功能需要先在书架中打开该小说',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        if (canExtract) ...[
          // 角色正式名称
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '角色正式名称 *',
              hintText: '例如：李明',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // 别名
          TextField(
            controller: _aliasesController,
            decoration: const InputDecoration(
              labelText: '别名（可选）',
              hintText: '用逗号分隔，例如：小李,阿明',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // 上下文长度设置
          const Text(
            '上下文长度',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _contextLength.toDouble(),
                  min: _minContextLength.toDouble(),
                  max: _maxContextLength.toDouble(),
                  divisions: 100,
                  label: '$_contextLength字',
                  onChanged: (value) {
                    setState(() {
                      _contextLength = value.toInt();
                    });
                  },
                ),
              ),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: TextEditingController(text: '$_contextLength'),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (value) {
                    final len = int.tryParse(value);
                    if (len != null &&
                        len >= _minContextLength &&
                        len <= _maxContextLength) {
                      setState(() {
                        _contextLength = len;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 提取模式
          const Text(
            '提取模式',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          RadioListTile<bool>(
            title: const Text('提取匹配位置上下文'),
            value: false,
            groupValue: _extractFullChapter,
            onChanged: (bool? value) {
              if (value != null) {
                setState(() {
                  _extractFullChapter = value;
                });
              }
            },
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          RadioListTile<bool>(
            title: const Text('提取整章内容'),
            value: true,
            groupValue: _extractFullChapter,
            onChanged: (bool? value) {
              if (value != null) {
                setState(() {
                  _extractFullChapter = value;
                });
              }
            },
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          const SizedBox(height: 12),

          // 搜索按钮
          ElevatedButton.icon(
            onPressed: _isSearching ? null : _searchChapters,
            icon: _isSearching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.search),
            label: Text(_isSearching ? '搜索中...' : '搜索章节'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(40),
            ),
          ),
          const SizedBox(height: 12),

          // 搜索错误提示
          if (_searchError != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _searchError!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          // 搜索结果
          if (_matchedChapters.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '找到 ${_matchedChapters.length} 个匹配章节',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      final allSelected =
                          _matchedChapters.every((c) => c.isSelected);
                      for (final chapter in _matchedChapters) {
                        chapter.isSelected = !allSelected;
                      }
                    });
                  },
                  child: Text(_matchedChapters.every((c) => c.isSelected)
                      ? '取消全选'
                      : '全选'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _matchedChapters.length,
                itemBuilder: (context, index) {
                  final item = _matchedChapters[index];
                  return CheckboxListTile(
                    title: Text(item.chapter.title),
                    subtitle: Text('匹配 ${item.matchCount} 处'),
                    value: item.isSelected,
                    onChanged: (value) {
                      setState(() {
                        item.isSelected = value ?? false;
                      });
                    },
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _buildEstimatedLength(),
          ],
        ],
      ],
    );
  }

  /// 构建预计长度提示
  Widget _buildEstimatedLength() {
    final selectedChapters =
        _matchedChapters.where((c) => c.isSelected).toList();
    final estimated = _extractionService.estimateContentLength(
      chapterMatches: selectedChapters.map((item) {
        return ChapterMatch(
          chapter: item.chapter,
          matchCount: item.matchCount,
          matchPositions: [],
        );
      }).toList(),
      contextLength: _contextLength,
      useFullChapter: _extractFullChapter,
    );

    final isOverLimit = estimated > _maxTotalContentLength;
    final color = isOverLimit ? Colors.red : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOverLimit ? Icons.warning : Icons.info,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                '预计提取内容长度：${_formatNumber(estimated)} 字',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          if (isOverLimit)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '内容过长可能导致处理失败，建议减少选中章节或缩短上下文长度',
                style: TextStyle(fontSize: 11, color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  /// 格式化数字（添加千位分隔符）
  String _formatNumber(int num) {
    return num.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  /// 构建提示卡片
  Widget _buildTipsCard(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, size: 16, color: Colors.blue),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮
  List<Widget> _buildActions() {
    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      ElevatedButton(
        onPressed: _onConfirm,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        child: Text(_mode == CreateMode.extract ? '开始提取' : 'AI生成'),
      ),
    ];
  }

  /// 搜索章节
  Future<void> _searchChapters() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _searchError = '请输入角色正式名称';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
      _matchedChapters = [];
    });

    try {
      // 构建名称列表
      final names = <String>[name];
      final aliasesText = _aliasesController.text.trim();
      if (aliasesText.isNotEmpty) {
        // 支持逗号、分号、空格分隔
        final aliases = aliasesText
            .split(RegExp(r'[,，;；\s]+'))
            .where((s) => s.isNotEmpty)
            .toList();
        names.addAll(aliases);
      }

      // 搜索章节
      final matches = await _extractionService.searchChaptersByName(
        novelUrl: widget.novelUrl!,
        names: names,
      );

      if (matches.isEmpty) {
        setState(() {
          _searchError = '未找到匹配的章节，请检查角色名称或别名';
        });
      } else {
        setState(() {
          _matchedChapters = matches.map((m) {
            return ChapterMatchItem(
              chapter: m.chapter,
              matchCount: m.matchCount,
            );
          }).toList();
        });
      }
    } catch (e) {
      LoggerService.instance.e('搜索章节失败:' + e.toString());
      debugPrint('❌ 搜索章节失败: $e');
      setState(() {
        _searchError = '搜索失败: $e';
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  /// 确认按钮处理
  void _onConfirm() {
    if (_mode == CreateMode.extract) {
      _onExtractConfirm();
    } else {
      _onDescribeConfirm();
    }
  }

  /// AI描述/大纲模式确认
  void _onDescribeConfirm() {
    final input = _descriptionController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入角色描述'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop({
      'mode': 'describe',
      'userInput': input,
      'useOutline': _mode == CreateMode.outline ? _useOutline : false,
    });
  }

  /// 提取模式确认
  void _onExtractConfirm() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入角色正式名称'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedChapters =
        _matchedChapters.where((c) => c.isSelected).toList();
    if (selectedChapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请至少选择一个章节'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 构建角色名字符串
    final names = <String>[name];
    final aliasesText = _aliasesController.text.trim();
    if (aliasesText.isNotEmpty) {
      final aliases = aliasesText
          .split(RegExp(r'[,，;；\s]+'))
          .where((s) => s.isNotEmpty)
          .toList();
      names.addAll(aliases);
    }

    Navigator.of(context).pop({
      'mode': 'extract',
      'name': name,
      'aliases': names.sublist(1), // 不包含正式名称
      'contextLength': _contextLength,
      'extractFullChapter': _extractFullChapter,
      'selectedChapters': selectedChapters.map((item) {
        return ChapterMatch(
          chapter: item.chapter,
          matchCount: item.matchCount,
          matchPositions: [],
        );
      }).toList(),
    });
  }
}
