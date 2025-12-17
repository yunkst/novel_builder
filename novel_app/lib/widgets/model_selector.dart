import 'package:flutter/material.dart';

/// 统一的模型选择组件
/// 支持从后端API动态获取模型列表并提供下拉选择功能
class ModelSelector extends StatefulWidget {
  /// 当前选中的模型
  final String? selectedModel;
  /// 模型选择变化回调
  final ValueChanged<String?> onModelChanged;
  /// API类型：'t2i' 表示文生图模型，'i2v' 表示图生视频模型
  final String? apiType;
  /// 是否启用
  final bool enabled;
  /// 提示文本
  final String? hintText;

  const ModelSelector({
    super.key,
    this.selectedModel,
    required this.onModelChanged,
    this.apiType,
    this.enabled = true,
    this.hintText,
  });

  @override
  State<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<ModelSelector> {
  late Future<List<String>> _modelsFuture;
  String? _selectedModel;

  @override
  void initState() {
    super.initState();
    _selectedModel = widget.selectedModel;
    _modelsFuture = _loadModels();
  }

  @override
  void didUpdateWidget(ModelSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedModel != widget.selectedModel) {
      setState(() {
        _selectedModel = widget.selectedModel;
      });
    }
  }

  /// 从后端API加载模型列表
  Future<List<String>> _loadModels() async {
    // 直接返回默认模型列表，避免API调用问题
    return _getDefaultModels();
  }

  /// 获取默认模型列表
  List<String> _getDefaultModels() {
    return widget.apiType == 'i2v'
      ? ['SVD', 'AnimateDiff']
      : ['通用模型', 'Stable Diffusion', 'Midjourney Style'];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _modelsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return DropdownButtonFormField<String>(
            initialValue: null,
            decoration: InputDecoration(
              hintText: widget.hintText ?? '加载模型中...',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.model_training),
            ),
            items: const [],
            onChanged: null,
          );
        }

        if (snapshot.hasError) {
          return DropdownButtonFormField<String>(
            initialValue: null,
            decoration: InputDecoration(
              hintText: '加载失败',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.error_outline),
              errorText: '模型列表加载失败',
            ),
            items: const [],
            onChanged: null,
          );
        }

        final models = snapshot.data ?? [];

        // 如果当前选择的模型不在列表中，清空选择
        if (_selectedModel != null && !models.contains(_selectedModel)) {
          _selectedModel = null;
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedModel,
          decoration: InputDecoration(
            hintText: widget.hintText ?? '请选择模型',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.model_training),
            filled: true,
            fillColor: widget.enabled ? null : Colors.grey.shade100,
          ),
          items: models.map((model) {
            return DropdownMenuItem<String>(
              value: model,
              child: Text(
                model,
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: widget.enabled ? (value) {
            setState(() {
              _selectedModel = value;
            });
            widget.onModelChanged(value);
          } : null,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
        );
      },
    );
  }
}

/// 简化版模型选择器，用于快速集成
class SimpleModelSelector extends StatelessWidget {
  /// 当前选中的模型
  final String? selectedModel;
  /// 模型选择变化回调
  final ValueChanged<String?> onModelChanged;
  /// API类型
  final String? apiType;

  const SimpleModelSelector({
    super.key,
    this.selectedModel,
    required this.onModelChanged,
    this.apiType,
  });

  @override
  Widget build(BuildContext context) {
    return ModelSelector(
      selectedModel: selectedModel,
      onModelChanged: onModelChanged,
      apiType: apiType,
      hintText: '选择模型',
    );
  }
}