# 人物关系引力图增强设计文档

**创建日期**: 2026-01-26
**设计师**: Claude (AI Assistant)
**状态**: 设计完成，待实施

---

## 1. 项目概述

### 1.1 当前问题
- 关系信息缺失：连线仅显示简单线条，没有关系类型
- 无交互功能：无法点击节点查看详情
- 缩放限制：缩放范围受限（0.1x - 5.0x）
- 拖动限制：存在边界约束

### 1.2 设计目标
- **单击节点**：加强该节点关系的引力权重，相关节点靠拢
- **双击节点**：显示角色基础信息（姓名、性别、简介）
- **扩大范围**：缩放范围扩大至 0.01x - 10x，完全移除拖动边界
- **视觉增强**：在连线旁显示关系类型标签

---

## 2. 架构设计

### 2.1 核心组件

```
EnhancedRelationshipGraphScreen (已有，需增强)
├── 状态管理
│   ├── int? selectedNodeId (当前选中的节点ID)
│   ├── Map<String, double> edgeWeights (边权重映射)
│   └── bool _isAnimating (动画状态)
├── EdgeWeightManager (新增)
│   ├── getWeight(sourceId, targetId)
│   ├── setWeight(sourceId, targetId, weight)
│   ├── enhanceNodeEdges(nodeId)
│   └── reset()
├── InteractiveNodeWidget (新增)
│   ├── 渲染角色节点
│   ├── 处理单击/双击手势
│   └── 显示选中状态
├── RelationshipEdgePainter (新增)
│   ├── 绘制节点间连线
│   ├── 绘制关系类型标签
│   └── 根据权重调整样式
└── CharacterDetailDialog (新增)
    └── 显示角色基础信息
```

### 2.2 数据流

```
用户交互 → InteractiveNodeWidget
                ↓
        事件处理器 (onTap / onDoubleTap)
                ↓
    ┌───────────┴───────────┐
    ↓                       ↓
单击事件                  双击事件
    ↓                       ↓
EdgeWeightManager      CharacterDetailDialog
    ↓
更新权重参数
    ↓
重新运行布局算法
    ↓
启动动画过渡 (800ms, easeInOutCubic)
    ↓
逐帧更新节点位置
```

---

## 3. 详细设计

### 3.1 边权重管理器

**职责**：管理所有边的动态权重

**数据结构**：
```dart
class EdgeWeightManager {
  final Map<String, double> _weights = {};

  double getWeight(int sourceId, int targetId) {
    final key = _getEdgeKey(sourceId, targetId);
    return _weights[key] ?? 1.0;
  }

  void setWeight(int sourceId, int targetId, double weight) {
    final key = _getEdgeKey(sourceId, targetId);
    _weights[key] = weight;
  }

  void enhanceNodeEdges(int nodeId, {double enhancedWeight = 2.5}) {
    // 提高与该节点相连的所有边的权重
  }

  void reset() {
    _weights.clear();
  }

  String _getEdgeKey(int id1, int id2) {
    final smaller = id1 < id2 ? id1 : id2;
    final larger = id1 < id2 ? id2 : id1;
    return '$smaller-$larger';
  }
}
```

**权重规则**：
- 默认权重：1.0（正常引力）
- 增强权重：2.5（选中节点相关边）
- 权重影响引力公式：`attraction = base_attraction * weight`

---

### 3.2 交互节点组件

**职责**：渲染节点并处理手势

**手势检测**：
- `onTap`：触发单击事件（加强引力）
- `onDoubleTap`：触发双击事件（显示详情）

**视觉反馈**：
- 未选中：白色边框（3px）
- 选中：金色边框（5px）+ 外发光效果

**实现结构**：
```dart
class InteractiveNodeWidget extends StatefulWidget {
  final Character character;
  final double size;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
}

// 渲染逻辑：
// - GestureDetector 包裹
// - Container 圆形节点
// - Text 显示首字母
// - BoxDecoration 边框样式
```

---

### 3.3 关系边绘制器

**职责**：绘制带标签的连线

**视觉属性**：
- 正常权重：线条粗细 1.5px，灰色半透明
- 增强权重：线条粗细 3.0px，橙色实线

**标签绘制**：
1. 计算连线中点坐标
2. 绘制圆角矩形背景（白色，带边框）
3. 在背景上绘制关系类型文字
4. 自动避让：如果标签重叠，调整垂直偏移

**实现方式**：
```dart
class RelationshipEdgePainter extends CustomPainter {
  final List<Node> nodes;
  final List<Edge> edges;
  final Map<String, double> edgeWeights;
  final Map<int, Character> characterMap;
  final Map<int, String> relationshipTypes;

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制每一条边
    for (final edge in edges) {
      final source = nodes[edge.source];
      final target = nodes[edge.target];
      final weight = edgeWeights[edge.key];
      final type = relationshipTypes[edge.key];

      // 绘制线条
      _drawEdge(canvas, source, target, weight);

      // 绘制标签
      _drawLabel(canvas, source, target, type, weight);
    }
  }
}
```

---

### 3.4 角色详情对话框

**内容布局**：
```
┌─────────────────────────┐
│  [角色头像/首字母]       │
│                         │
│  姓名：张三              │
│  性别：男                │
│  简介：武林高手...       │
│                         │
│       [关闭]            │
└─────────────────────────┘
```

**交互**：
- 点击"关闭"按钮或对话框外部区域关闭
- 半透明遮罩背景
- 弹出动画（淡入 + 缩放）

**实现**：
```dart
void showCharacterDetail(BuildContext context, Character character) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          CircleAvatar(child: Text(character.name[0])),
          SizedBox(width: 12),
          Text(character.name),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('性别：${character.gender ?? "未知"}'),
          if (character.description != null) ...[
            SizedBox(height: 8),
            Text('简介：${character.description}'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('关闭'),
        ),
      ],
    ),
  );
}
```

---

### 3.5 动画过渡系统

**动画控制器配置**：
```dart
class _EnhancedRelationshipGraphScreenState extends State<StatefulWidget>
    with TickerProviderStateMixin {

  late AnimationController _layoutAnimationController;
  late Animation<double> _layoutAnimation;

  @override
  void initState() {
    super.initState();

    _layoutAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _layoutAnimation = CurvedAnimation(
      parent: _layoutAnimationController,
      curve: Curves.easeInOutCubic,
    );
  }
}
```

**布局插值**：
- 保存"当前布局"和"目标布局"两套节点位置
- 动画过程中在两套布局之间插值
- 每帧更新：`current = start + (end - start) * animationValue`

**触发流程**：
1. 用户单击节点
2. 计算新布局（调整权重后运行算法）
3. 保存当前布局为起点，新布局为终点
4. 启动动画控制器（0.0 → 1.0）
5. 在 `addListener` 中逐帧更新节点位置
6. 动画完成，停止更新

**防抖处理**：
- 动画期间设置 `_isAnimating = true`
- 忽略动画期间的所有点击事件
- 动画完成后重置标志位

---

### 3.6 缩放和拖动优化

**InteractiveViewer 配置调整**：

**修改前**：
```dart
minScale: 0.1,
maxScale: 5.0,
constrained: false,
boundaryMargin: const EdgeInsets.all(8),
```

**修改后**：
```dart
minScale: 0.01,        // 缩小到原图的1%
maxScale: 10.0,        // 放大到原图的10倍
constrained: false,    // 无边界限制
boundaryMargin: EdgeInsets.zero,  // 移除边界边距
```

**效果**：
- 可以看到更宏观的全局视图（0.01x）
- 可以查看单个节点的细节（10x）
- 完全自由拖动，不受任何边界限制

---

## 4. 用户交互流程

### 4.1 单击节点（加强引力）

```
用户单击节点A
    ↓
检查A是否已选中
    ↓
  ┌─┴─┐
  是   否
  ↓    ↓
取消选中  选中A
重置权重  提高A相关边权重
  ↓    ↓
重新运行布局算法计算目标位置
    ↓
启动动画过渡（800ms, easeInOutCubic）
    ↓
动画期间禁用交互
    ↓
逐帧更新节点位置（插值）
    ↓
动画结束，恢复交互
```

### 4.2 双击节点（查看详情）

```
用户双击节点A
    ↓
弹出 CharacterDetailDialog
    ↓
显示角色基础信息
  - 姓名
  - 性别
  - 简介
    ↓
用户点击"关闭"或外部区域
    ↓
对话框关闭
```

---

## 5. 错误处理与边界情况

### 5.1 边界情况

**空数据状态**：
- 无角色：显示空状态提示
- 无关系：只显示孤立节点，无边

**动画期间的交互**：
- 动画进行中：禁用所有节点点击
- 显示加载提示
- 队列机制：忽略动画期间的用户操作

**节点数据不完整**：
- 角色缺少 `id`：跳过该节点，记录警告
- 角色缺少 `name`：显示问号占位符
- 关系缺少 `type`：显示"未知关系"

**布局计算失败**：
- 算法不收敛：使用当前布局作为最终结果
- 节点重叠：增加斥力参数重新计算
- 异常捕获：显示错误提示，提供重试按钮

### 5.2 用户体验优化

**首次加载引导**：
- 第一次进入时显示使用说明对话框
- 或在底部显示简短提示："单击节点查看关系，双击查看详情"

**操作反馈**：
- 单击节点：立即高亮边框，显示"正在调整布局..."提示
- 布局调整完成：隐藏提示，节点移动到位
- 操作失败：Toast提示"操作失败，请重试"

**视觉一致性**：
- 动画期间保持连线标签可读
- 缩放时标签字体大小同步调整
- 拖动时流畅跟手

---

## 6. 测试策略

### 6.1 功能测试

**节点交互测试**：
- 单击节点验证权重调整
- 双击节点验证详情弹窗
- 单击空白区域验证重置功能
- 快速连续单击验证防抖

**动画测试**：
- 验证动画流畅性（800ms过渡）
- 验证动画期间交互禁用
- 验证动画结束后状态正确

**缩放拖动测试**：
- 验证最小缩放（0.01x）可达
- 验证最大缩放（10x）可达
- 验证无边界拖动正常

**边界测试**：
- 空数据场景
- 单个节点场景
- 大量节点（50+）场景
- 关系数据缺失场景

### 6.2 性能测试

**渲染性能**：
- 测量60fps下的最大节点数
- 测量动画期间的帧率
- 测量缩放时的响应延迟

**内存测试**：
- 测量大量节点的内存占用
- 验证动画资源正确释放
- 验证没有内存泄漏

**算法性能**：
- 测量布局计算耗时
- 测量权重调整后的重新计算耗时

---

## 7. 实施计划

### Phase 1: 核心功能（必须）
1. ✅ 扩大缩放和拖动范围
2. ✅ 实现节点单击检测
3. ✅ 实现权重管理器
4. ✅ 实现布局动画过渡
5. ✅ 实现双击详情弹窗

### Phase 2: 增强功能（重要）
1. ⭐ 在连线旁显示关系类型标签
2. ⭐ 选中节点的视觉反馈
3. ⭐ 动画期间的加载提示

### Phase 3: 优化功能（可选）
1. 🔧 缩放控制按钮
2. 🔧 首次加载引导
3. 🔧 性能优化

---

## 8. 技术栈与依赖

**现有依赖**：
- `flutter` (SDK)
- `graphview` (力导向图库)
- `sqflite` (本地数据库)

**无需新增依赖**：所有功能可基于现有技术栈实现

---

## 9. 文件结构

```
novel_app/lib/
├── screens/
│   └── enhanced_relationship_graph_screen.dart (修改)
├── widgets/
│   ├── interactive_node_widget.dart (新增)
│   ├── relationship_edge_painter.dart (新增)
│   └── character_detail_dialog.dart (新增)
├── models/
│   └── character_relationship.dart (已有，无需修改)
└── utils/
    └── edge_weight_manager.dart (新增)
```

---

## 10. 成功标准

**功能完整性**：
- ✅ 单击节点能够加强引力权重
- ✅ 双击节点能够显示详情
- ✅ 缩放范围达到 0.01x - 10x
- ✅ 拖动无边界限制
- ✅ 连线显示关系类型标签

**用户体验**：
- ✅ 动画流畅（60fps）
- ✅ 交互响应迅速（< 100ms）
- ✅ 视觉反馈清晰
- ✅ 错误处理友好

**性能要求**：
- ✅ 支持 50+ 节点流畅运行
- ✅ 动画期间保持 30fps 以上
- ✅ 无内存泄漏

---

## 11. 风险与挑战

**技术风险**：
- 动画过渡可能影响性能（解决方案：限制帧率）
- 大量节点时布局计算慢（暂不优化）
- 标签重叠问题（解决方案：自动避让算法）

**用户接受度**：
- 单击/双击操作可能需要学习（解决方案：首次引导）
- 动画过渡可能感觉慢（解决方案：提供跳过选项）

---

## 附录：交互原型说明

**场景1：首次使用**
1. 用户打开关系图
2. 显示引导对话框："单击节点可加强关系引力，双击查看详情"
3. 用户点击"知道了"，开始浏览

**场景2：探索关系**
1. 用户看到复杂的角色关系网
2. 单击"张三"节点
3. 张三的边框变为金色高亮
4. 相关节点向张三靠拢（动画800ms）
5. 用户清晰看到张三的主要关系

**场景3：查看详情**
1. 用户双击"张三"节点
2. 弹出对话框显示：
   - 姓名：张三
   - 性别：男
   - 简介：武林高手...
3. 用户点击"关闭"，对话框消失

**场景4：缩放查看**
1. 用户双指捏合缩小到 0.05x
2. 看到全局关系网概览
3. 用户双指捏合放大到 5x
4. 看到某个区域的细节
5. 用户拖动视图到其他位置

---

**文档版本**: v1.0
**最后更新**: 2026-01-26
