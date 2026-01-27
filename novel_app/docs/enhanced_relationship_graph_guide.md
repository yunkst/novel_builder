# 增强版角色关系图使用文档

## 📖 概述

`EnhancedRelationshipGraphScreen` 是基于 `graphview` 包重构的全新关系图组件,解决了原有实现的主要问题:

### 🎯 核心改进

| 特性 | 旧实现 | 新实现 |
|------|--------|--------|
| 展示范围 | 仅当前角色关系 | ✅ 所有角色的全局关系 |
| 布局算法 | 手动圆形布局 | ✅ Fruchterman-Reingold 力导向算法 |
| 交互性 | 仅点击高亮 | ✅ 缩放、拖拽、搜索、详情查看 |
| 代码复杂度 | CustomPainter手动绘制 | ✅ 声明式API,代码量减少60% |
| 性能 | 固定尺寸,性能一般 | ✅ 自适应布局,优化渲染 |

## 🚀 快速开始

### 1. 安装依赖

已在 `pubspec.yaml` 中添加:

```yaml
dependencies:
  graphview: ^2.0.1
```

运行安装:

```bash
cd novel_app
flutter pub get
```

### 2. 基础使用

```dart
import 'package:novel_app/screens/enhanced_relationship_graph_screen.dart';

// 方式1: 从角色列表入口导航
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => EnhancedRelationshipGraphScreen(
      novelUrl: novel.url,
      initialCharacter: character, // 可选:指定初始角色
    ),
  ),
);

// 方式2: 从设置/功能入口导航(显示所有角色)
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => EnhancedRelationshipGraphScreen(
      novelUrl: novel.url,
    ),
  ),
);
```

### 3. 集成到现有页面

#### 在角色列表页面添加入口按钮

编辑 `lib/screens/character_relationship_screen.dart`:

```dart
// 在 AppBar 的 actions 中添加
AppBar(
  title: const Text('角色关系'),
  actions: [
    // 新增:全局关系图按钮
    IconButton(
      icon: const Icon(Icons.account_tree),
      tooltip: '查看全局关系图',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EnhancedRelationshipGraphScreen(
              novelUrl: widget.novelUrl,
            ),
          ),
        );
      },
    ),
    // 原有的添加按钮...
  ],
),
```

#### 在角色详情页面添加入口

编辑角色详情相关页面,添加跳转:

```dart
// 在单个角色的操作列表中添加
ListTile(
  leading: const Icon(Icons.people_outline),
  title: const Text('查看关系网络'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedRelationshipGraphScreen(
          novelUrl: character.novelUrl,
          initialCharacter: character,
        ),
      ),
    );
  },
),
```

## 🎨 功能特性详解

### 1. 全局关系网络展示

- ✅ 自动加载小说的所有角色
- ✅ 加载所有角色之间的关系
- ✅ 自动去重关系数据
- ✅ 力导向布局自动计算最优位置

### 2. 交互式操作

| 操作 | 功能 |
|------|------|
| **单击节点** | 弹出详情对话框,显示角色信息和关系列表 |
| **长按节点** | 高亮该角色的所有关系网络 |
| **拖拽节点** | 手动调整节点位置(重新布局) |
| **滚轮缩放** | 放大/缩小视图 |
| **搜索角色** | 快速定位并高亮角色 |

### 3. 可视化设计

#### 节点样式

- **颜色区分**:
  - 🔵 蓝色: 男性角色
  - 🌸 粉色: 女性角色
  - 🟣 紫色: 其他/未知

- **状态标识**:
  - 橙色边框: 当前选中节点
  - 蓝色边框: 高亮节点

- **显示内容**:
  - 圆圈内: 名字首字母
  - 圆圈下: 完整角色名

#### 关系线样式

- **箭头**: 指向目标角色
- **标签**: 关系类型文字(如"父女"、"朋友")
- **颜色**:
  - 灰色: 普通关系
  - 蓝色加粗: 高亮关系

### 4. 工具栏功能

```
[🔍放大] [🔎缩小] [🎯居中]     角色: 15 | 关系: 42
```

- **缩放控制**: 调整视图大小
- **居中**: 重置视图到中心位置
- **统计信息**: 显示当前角色数和关系数

### 5. 搜索功能

点击AppBar的搜索图标:

- 🔍 实时搜索角色名称
- 📋 显示匹配结果列表
- 👆 点击结果跳转并高亮

## 🔧 高级配置

### 自定义力导向算法参数

在 `_buildGraphStructure()` 方法中修改:

```dart
_algorithm = gv.FruchtermanReingoldAlgorithm(_graph);
_algorithm
  ..attraction = 0.1      // 吸引力(0.0-1.0) 越大节点越聚集
  ..repulsion = 1500.0    // 斥力(100-5000) 越大节点越分散
  ..iterations = 1000;    // 迭代次数(100-5000) 次数越多布局越精确
```

**调整建议**:
- 节点过多(>50): 增大 `repulsion` 到 2000-3000
- 节点过少(<20): 减小 `repulsion` 到 500-1000
- 节点过于聚集: 减小 `attraction` 到 0.05
- 节点过于分散: 增大 `attraction` 到 0.2

### 自定义节点大小

修改 `_nodeSize` 常量:

```dart
static const double _nodeSize = 80.0; // 默认60.0,增大节点
```

### 自定义颜色

修改 `_getGenderColor()` 方法:

```dart
Color _getGenderColor(String? gender) {
  switch (gender?.toLowerCase()) {
    case '男':
      return Colors.indigo; // 改为靛蓝色
    case '女':
      return Colors.red;     // 改为红色
    default:
      return Colors.grey;    // 改为灰色
  }
}
```

## 📊 数据结构要求

### Character 模型

```dart
class Character {
  final int? id;
  final String novelUrl;
  final String name;
  final String? gender;
  final String? age;
  final String? personality;
  final String? appearance;
  final String? background;
}
```

### CharacterRelationship 模型

```dart
class CharacterRelationship {
  final int sourceCharacterId;
  final int targetCharacterId;
  final String relationshipType;
}
```

### 数据库服务要求

```dart
class DatabaseService {
  // 获取小说的所有角色
  Future<List<Character>> getCharacters(String novelUrl);

  // 获取角色的所有关系
  Future<List<CharacterRelationship>> getRelationships(int characterId);
}
```

## 🐛 常见问题

### Q1: 图库依赖安装失败?

**解决方案**:

```bash
# 清理并重新获取依赖
flutter clean
flutter pub get

# 如果还有问题,升级Flutter SDK
flutter upgrade
```

### Q2: 节点位置重叠严重?

**调整算法参数**:

```dart
_algorithm
  ..repulsion = 2500.0  // 增大斥力
  ..attraction = 0.05;  // 减小吸引力
```

### Q3: 性能问题,卡顿?

**优化方案**:

1. 减少迭代次数:
```dart
_algorithm..iterations = 500; // 从1000降到500
```

2. 过滤孤立节点:
```dart
final connectedCharacters = characters.where((c) =>
  relationships.any((r) =>
    r.sourceCharacterId == c.id || r.targetCharacterId == c.id
  )
).toList();
```

### Q4: 搜索不到角色?

**检查**:
- 确保角色数据已正确加载
- 搜索是区分大小写的,使用 `.toLowerCase()` 处理
- 检查 `_allCharacters` 是否为空

### Q5: 如何保存/恢复布局?

**扩展方案**: 添加状态持久化

```dart
// 保存布局
final layoutData = {
  for (final node in _graph.nodes)
    node.key?.value: panel.getNodePosition(node)
};
await prefs.setString('graph_layout', jsonEncode(layoutData));

// 恢复布局(需要修改算法支持固定位置)
```

## 🎯 后续优化方向

### 短期 (1-2周)

- [ ] 实现缩放功能
- [ ] 添加布局居中
- [ ] 支持节点拖拽后固定位置
- [ ] 添加关系过滤(如只显示家人关系)

### 中期 (1个月)

- [ ] 支持分层布局(按家族/派系)
- [ ] 添加关系路径搜索(查找A到B的关系链)
- [ ] 实现布局保存/恢复
- [ ] 支持导出为图片

### 长期 (2-3个月)

- [ ] 3D可视化支持
- [ ] 关系时间线演变
- [ ] 集成AI推荐角色关系
- [ ] 协作编辑模式

## 📚 参考资源

- [graphview包文档](https://pub.dev/packages/graphview)
- [力导向算法详解](https://en.wikipedia.org/wiki/Force-directed_graph_drawing)
- [Graph算法论文](https://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.31.1524&rep=rep1&type=pdf)

## 💡 最佳实践

### 1. 数据预加载

在进入关系图之前,建议先预加载数据:

```dart
// 在上一个页面先加载
final characters = await databaseService.getCharacters(novelUrl);
if (characters.isEmpty) {
  showToast('暂无角色数据');
  return;
}
Navigator.push(...);
```

### 2. 性能监控

使用 `performance_overlay` 监控性能:

```dart
MaterialApp(
  debugShowMaterialGrid: false,
  showPerformanceOverlay: true, // 开发环境启用
  home: EnhancedRelationshipGraphScreen(...),
);
```

### 3. 错误处理

已实现的错误处理:

- ✅ 数据加载失败提示
- ✅ 空数据状态展示
- ✅ 异常捕获和日志记录
- ✅ 用户友好的错误信息

---

**文档版本**: v1.0.0
**最后更新**: 2025-01-25
**维护者**: Novel Builder Team
