import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'model_selector.dart';

/// 生成更多图片数量选择对话框
class GenerateMoreDialog extends StatefulWidget {
  final Function(int, String?) onConfirm; // 修改回调以支持模型选择
  final String? apiType; // 't2i' 或 'i2v'
  final String? defaultModel; // 默认模型

  const GenerateMoreDialog({
    super.key,
    required this.onConfirm,
    this.apiType = 't2i',
    this.defaultModel,
  });

  @override
  State<GenerateMoreDialog> createState() => _GenerateMoreDialogState();
}

class _GenerateMoreDialogState extends State<GenerateMoreDialog> {
  final TextEditingController _controller = TextEditingController(text: '3');
  final List<int> _quickOptions = [1, 3, 5, 10];
  String? _selectedModel;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleQuickSelect(int count) {
    setState(() {
      _controller.text = count.toString();
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  void _handleConfirm() {
    debugPrint('=== GenerateMoreDialog: 用户点击确认生成 ===');
    debugPrint('输入的文本: ${_controller.text}');

    final text = _controller.text.trim();
    final count = int.tryParse(text);

    debugPrint('解析的数量: $count');
    debugPrint('选中的模型: $_selectedModel');

    if (count == null || count <= 0) {
      debugPrint('❌ 数量验证失败');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请输入有效的图片数量'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    debugPrint('✅ 数量验证通过，调用 onConfirm 回调');

    try {
      if (!mounted) {
        debugPrint('❌ widget已销毁，取消操作');
        return;
      }

      // 只调用回调，不要在这里调用 Navigator.pop
      // onConfirm 回调会负责关闭对话框并返回数据
      debugPrint('🔄 调用 onConfirm 回调: count=$count, model=$_selectedModel');
      widget.onConfirm(count, _selectedModel);
      debugPrint('✅ onConfirm 回调调用完成');
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ onConfirm 回调异常 ❌❌❌');
      debugPrint('异常: $e');
      debugPrint('堆栈:\n$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // 标题
            Row(
              children: [
                Icon(
                  Icons.add_photo_alternate,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '生成更多图片',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '请输入您想生成的图片数量',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),

            // 快速选择选项
            Text(
              '快速选择：',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _quickOptions.map((count) {
                return _QuickOptionButton(
                  count: count,
                  isSelected: _controller.text == count.toString(),
                  onTap: () => _handleQuickSelect(count),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 数量输入框
            Text(
              '自定义数量：',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                suffix: const Text('张'),
              ),
            ),
            const SizedBox(height: 16),

            // 模型选择器
            ModelSelector(
              selectedModel: _selectedModel ?? widget.defaultModel,
              onModelChanged: (value) {
                setState(() {
                  _selectedModel = value;
                });
              },
              apiType: widget.apiType,
              hintText: '选择生成模型',
            ),
            const SizedBox(height: 24),

            // 按钮
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _handleConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('确认生成'),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

/// 快速选择选项按钮
class _QuickOptionButton extends StatelessWidget {
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickOptionButton({
    // ignore: unused_element_parameter
    super.key,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
          ),
        ),
        child: Text(
          '$count张',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}