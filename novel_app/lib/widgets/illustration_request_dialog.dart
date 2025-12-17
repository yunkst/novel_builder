import 'package:flutter/material.dart';

class IllustrationRequestDialog extends StatefulWidget {
  const IllustrationRequestDialog({super.key});

  @override
  State<IllustrationRequestDialog> createState() => _IllustrationRequestDialogState();
}

class _IllustrationRequestDialogState extends State<IllustrationRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _promptController = TextEditingController();
  int _selectedImageCount = 1;

  final List<int> _imageCountOptions = [1, 2, 3, 4, 6, 8];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 24,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '生图请求',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 生图要求输入框
              const Text(
                '生图要求 *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _promptController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  filled: true,
                  fillColor: Colors.black,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入生图要求';
                  }
                  if (value.trim().length < 5) {
                    return '生图要求至少需要5个字符';
                  }
                  if (value.trim().length > 500) {
                    return '生图要求不能超过500个字符';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // 生图数量选择器
              const Text(
                '生图数量 *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedImageCount,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    isExpanded: true,
                    items: _imageCountOptions.map((count) {
                      return DropdownMenuItem<int>(
                        value: count,
                        child: Text(
                          '$count 张',
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedImageCount = value;
                        });
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 提示信息
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                             size: 16,
                             color: Colors.blue[600]),
                        const SizedBox(width: 4),
                        Text(
                          '提示',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• 描述越详细，生成效果越好\n'
                      '• 支持中文和英文描述\n'
                      '• 生成过程可能需要几秒钟\n'
                      '• 最多可同时生成8张图片',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 按钮区域
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 取消按钮
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text(
                      '取消',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 确认按钮
                  ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '开始生成',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
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

  void _submitForm() {
    if (_formKey.currentState?.validate() == true) {
      final result = {
        'prompt': _promptController.text.trim(),
        'imageCount': _selectedImageCount,
      };

      Navigator.of(context).pop(result);
    }
  }
}