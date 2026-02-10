# 插图组件依赖注入修复方案

## 问题概述

项目正在从单例模式迁移到 Riverpod 依赖注入，但以下组件仍在直接实例化 `ApiServiceWrapper`：

### 受影响的组件

1. **HybridMediaWidget** - 完全未使用 Provider
2. **SceneImagePreview** - 部分使用 Provider（3处中有1处正确）
3. **ImageCacheManager** - 静态类，内部使用单例

## 修复方案

### 方案 1: 改造 HybridMediaWidget（推荐）

#### 当前代码
```dart
// lib/widgets/hybrid_media_widget.dart
class HybridMediaWidget extends StatefulWidget {  // ❌
  ...

  Future<void> _checkVideoStatus() async {
    final apiService = ApiServiceWrapper();  // ❌ 单例模式
    ...
  }
}
```

#### 修复后
```dart
// lib/widgets/hybrid_media_widget.dart
class HybridMediaWidget extends ConsumerStatefulWidget {  // ✅
  ...

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 从 Provider 获取 ApiServiceWrapper
    final apiService = ref.watch(apiServiceWrapperProvider);

    return _HybridMediaWidgetContent(
      apiService: apiService,
      imageUrl: widget.imageUrl,
      // ... 其他参数
    );
  }
}

class _HybridMediaWidgetContent extends StatefulWidget {
  final ApiServiceWrapper apiService;
  // ... 其他参数

  @override
  State<_HybridMediaWidgetContent> createState() => _HybridMediaWidgetContentState();
}

class _HybridMediaWidgetContentState extends State<_HybridMediaWidgetContent> {
  Future<void> _checkVideoStatus() async {
    final apiService = widget.apiService;  // ✅ 使用注入的实例
    ...
  }
}
```

### 方案 2: 修复 SceneImagePreview

#### 当前代码
```dart
// lib/widgets/scene_image_preview.dart
class SceneImagePreview extends ConsumerStatefulWidget {
  ...

  Future<void> _loadIllustrationFromBackend() async {
    final apiService = ApiServiceWrapper();  // ❌ Line 175
    ...
  }

  Future<void> _deleteCurrentImage(String imageUrl) async {
    final apiService = ApiServiceWrapper();  // ❌ Line 969
    ...
  }

  Future<void> _generateMoreImages(...) async {
    final apiService = ref.read(apiServiceWrapperProvider);  // ✅ Line 910
    ...
  }
}
```

#### 修复后
```dart
class _SceneImagePreviewState extends ConsumerState<SceneImagePreview> {
  ...

  Future<void> _loadIllustrationFromBackend() async {
    final apiService = ref.read(apiServiceWrapperProvider);  // ✅ 修复 Line 175
    ...
  }

  Future<void> _deleteCurrentImage(String imageUrl) async {
    final apiService = ref.read(apiServiceWrapperProvider);  // ✅ 修复 Line 969
    ...
  }
}
```

### 方案 3: 改造 ImageCacheManager（长期方案）

#### 当前代码
```dart
// lib/utils/image_cache_manager.dart
class ImageCacheManager {
  static ApiServiceWrapper? _apiService;

  static void _ensureApiService() {
    _apiService ??= ApiServiceWrapper();  // ❌ 单例模式
  }

  static Future<Uint8List> getImage(String imageUrl) async {
    _ensureApiService();
    ...
  }
}
```

#### 修复后
```dart
// lib/utils/image_cache_manager.dart
class ImageCacheManager {
  // 移除静态方法，改为实例类
  final ApiServiceWrapper apiService;

  const ImageCacheManager({required this.apiService});

  Future<Uint8List> getImage(String imageUrl) async {
    // 使用注入的 apiService
    final data = await apiService.getImageProxy(imageUrl);
    ...
  }
}

// 创建 Provider
@riverpod
ImageCacheManager imageCacheManager(Ref ref) {
  final apiService = ref.watch(apiServiceWrapperProvider);
  return ImageCacheManager(apiService: apiService);
}
```

## 优先级

### P0 - 立即修复（关键问题）
1. ✅ 修复 `SceneImagePreview` 中的 2 处 `ApiServiceWrapper()` 直接实例化
2. ✅ 改造 `HybridMediaWidget` 为 ConsumerStatefulWidget

### P1 - 高优先级（后续改进）
3. 改造 `ImageCacheManager` 为依赖注入模式
4. 更新所有使用 `ImageCacheManager` 的地方

### P2 - 中优先级（重构）
5. 清理其他直接实例化 `ApiServiceWrapper` 的代码：
   - `lib/widgets/model_selector.dart:61`
   - `lib/mixins/reader/illustration_handler_mixin.dart:233`
   - `lib/services/backup_service.dart:70`

## 实施步骤

### 步骤 1: 修复 SceneImagePreview（最简单）
```bash
# 只需修改 2 行代码
# Line 175: ApiServiceWrapper() → ref.read(apiServiceWrapperProvider)
# Line 969: ApiServiceWrapper() → ref.read(apiServiceWrapperProvider)
```

### 步骤 2: 改造 HybridMediaWidget（中等复杂度）
1. 将 `StatefulWidget` 改为 `ConsumerStatefulWidget`
2. 拆分为两个类：`ConsumerStatefulWidget` + `StatefulWidget`
3. 通过构造函数传递 `ApiServiceWrapper`

### 步骤 3: 测试验证
```bash
# 运行测试验证修复
flutter test test/unit/illustration_loading_test.dart

# 手动测试插图加载功能
```

## 相关文件

### 需要修改的文件
- `lib/widgets/hybrid_media_widget.dart`
- `lib/widgets/scene_image_preview.dart`
- `lib/utils/image_cache_manager.dart`（可选）

### 参考的正确实现
- `lib/widgets/gallery_thumbnail.dart:68` ✅
- `lib/widgets/scene_illustration_dialog.dart:55` ✅

### Provider 定义
- `lib/core/providers/services/network_service_providers.dart:126` - `apiServiceWrapperProvider`

## 测试计划

### 单元测试
- ✅ 测试已创建：`test/unit/illustration_loading_test.dart`
- 修复后应该通过场景 7, 8, 16

### 集成测试
- 测试插图加载完整流程
- 验证视频生成和显示功能

## 风险评估

### 低风险
- SceneImagePreview 修复（只改 2 行代码）

### 中风险
- HybridMediaWidget 改造（需要拆分类结构）

### 高风险
- ImageCacheManager 改造（影响范围大，需要多处修改）

## 注意事项

1. **不要破坏现有功能**：确保所有插图相关功能正常工作
2. **保持向后兼容**：如果暂时无法完全移除单例，可以并存两种模式
3. **逐步迁移**：优先修复最关键的问题，其他问题可以后续迭代
4. **测试覆盖**：每次修改后运行测试确保没有引入新问题

---

**文档创建时间**: 2026-02-03
**相关测试**: `test/unit/illustration_loading_test.dart`
**相关报告**: `ILLUSTRATION_LOADING_TEST_REPORT.md`
