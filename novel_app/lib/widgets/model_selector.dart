import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:built_collection/built_collection.dart';
import 'package:novel_api/novel_api.dart';
import '../services/api_service_wrapper.dart';
import '../core/providers/services/network_service_providers.dart';

/// 统一的模型选择组件
/// 支持从后端API动态获取模型列表并提供下拉选择功能
class ModelSelector extends ConsumerStatefulWidget {
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
  ConsumerState<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends ConsumerState<ModelSelector> {
  late Future<List<WorkflowInfo>> _modelsFuture;
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
  Future<List<WorkflowInfo>> _loadModels() async {
    try {
      // ✅ 使用Provider获取已初始化的ApiServiceWrapper实例
      final apiService = ref.read(apiServiceWrapperProvider);

      // 确保实例已初始化
      if (!apiService.isInitialized) {
        throw Exception('ApiServiceWrapper 尚未完成初始化，请稍后再试');
      }

      final models = await apiService.getModels();

      // 根据 apiType 返回对应的模型列表
      switch (widget.apiType) {
        case 'i2v':
          final img2videoModels = models.img2video ?? BuiltList<WorkflowInfo>();
          return img2videoModels.toList();
        case 't2i':
          final text2imgModels = models.text2img ?? BuiltList<WorkflowInfo>();
          return text2imgModels.toList();
        default:
          // 如果没有指定类型，返回所有模型
          final allModels = <WorkflowInfo>[];
          if (models.text2img != null) {
            allModels.addAll(models.text2img!.toList());
          }
          if (models.img2video != null) {
            allModels.addAll(models.img2video!.toList());
          }
          return allModels;
      }
    } catch (e) {
      debugPrint('加载模型列表失败: $e');
      // 返回空列表，避免崩溃
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WorkflowInfo>>(
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
        if (_selectedModel != null &&
            !models.any((m) => m.title == _selectedModel)) {
          _selectedModel = null;
        }

        // 如果模型列表为空，显示提示
        if (models.isEmpty) {
          return DropdownButtonFormField<String>(
            initialValue: null,
            decoration: InputDecoration(
              hintText: '无可用模型',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.warning_amber),
              helperText: '请检查后端连接',
              helperStyle: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .tertiary
                      .withValues(alpha: 0.7),
                  fontSize: 12),
            ),
            items: const [],
            onChanged: null,
          );
        }

        // 如果没有选中模型，自动选中默认模型
        if (_selectedModel == null && models.isNotEmpty) {
          final defaultModel = models.firstWhere(
            (m) => m.isDefault ?? false,
            orElse: () => models.first,
          );
          _selectedModel = defaultModel.title;
          // 通知父组件
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onModelChanged(_selectedModel);
          });
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedModel,
          decoration: InputDecoration(
            hintText: widget.hintText ?? '请选择模型',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.model_training),
            filled: true,
            fillColor: widget.enabled
                ? null
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.1),
          ),
          items: models.map((model) {
            return DropdownMenuItem<String>(
              value: model.title,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        model.title,
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (model.isDefault ?? false) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.3),
                                width: 1),
                          ),
                          child: Text(
                            '默认',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (model.width != null && model.height != null)
                    Text(
                      '${model.width!} × ${model.height!}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: widget.enabled
              ? (value) {
                  setState(() {
                    _selectedModel = value;
                  });
                  widget.onModelChanged(value);
                }
              : null,
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
