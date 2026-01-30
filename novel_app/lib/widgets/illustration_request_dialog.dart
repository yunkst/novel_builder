import 'package:flutter/material.dart';
import 'model_selector.dart';

class IllustrationRequestDialog extends StatefulWidget {
  const IllustrationRequestDialog({super.key});

  @override
  State<IllustrationRequestDialog> createState() =>
      _IllustrationRequestDialogState();
}

class _IllustrationRequestDialogState extends State<IllustrationRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _promptController = TextEditingController();
  int _selectedImageCount = 1;
  String? _selectedModel;

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
                style: TextStyle(color: Theme.of(context).colorScheme.surface),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.onSurface,
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
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedImageCount,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

              const SizedBox(height: 16),

              // 模型选择器
              const Text(
                '生图模型 *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ModelSelector(
                selectedModel: _selectedModel,
                onModelChanged: (value) {
                  setState(() {
                    _selectedModel = value;
                  });
                },
                apiType: 't2i',
                hintText: '请选择生图模型',
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
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
                      foregroundColor: Theme.of(context).colorScheme.surface,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
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
        'modelName': _selectedModel,
      };

      Navigator.of(context).pop(result);
    }
  }
}
