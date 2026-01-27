# 全局人物关系图功能说明

## 功能概述

实现了基于graphview库的全局人物关系图,使用FruchtermanReingold力导向布局算法自动计算节点位置。

## 访问路径

1. 打开小说详情页
2. 点击右上角的"人物管理"按钮
3. 在人物管理页面的AppBar右上角,点击"全人物关系图"图标 (🌲 图标)

## 功能特性

### 1. 自动布局
- 使用FruchtermanReingold力导向算法
- 自动计算最优节点位置
- 关系紧密的角色会自动靠近

### 2. 视觉设计
- **节点颜色区分**:
  - 蓝色: 男性角色
  - 粉色: 女性角色
  - 紫色: 性别未知
- **节点内容**: 显示角色名称首字母
- **节点样式**: 圆形带阴影和白色边框
- **连线**: 表示角色之间存在关系

### 3. 交互功能
- **缩放**: 捏合手势缩放视图 (0.1x - 5.0x)
- **移动**: 拖拽移动视图位置
- **信息统计**: AppBar显示"角色: X | 关系: Y"
- **重新加载**: 点击刷新按钮重新计算布局
- **使用说明**: 点击帮助按钮查看交互说明

### 4. 数据加载
- 自动加载小说中的所有角色
- 收集所有角色之间的关系
- 边去重处理(避免重复连线)

## 技术实现

### 核心依赖
```yaml
dependencies:
  graphview: ^1.5.1  # 图可视化库
```

### 关键代码

#### 1. 图结构构建
```dart
// 创建图
_graph = Graph()..isTree = false;

// 创建节点
for (final character in characters) {
  final node = Node.Id(character.id);
  nodeMap[character.id!] = node;
}

// 创建边(去重)
for (final relationship in relationships) {
  final edgeKey = '${sourceId < targetId ? sourceId : targetId}-${...}';
  if (!edgeSet.contains(edgeKey)) {
    _graph.addEdge(sourceNode, targetNode);
  }
}
```

#### 2. 力导向算法配置
```dart
final config = FruchtermanReingoldConfiguration()
  ..iterations = 1000;
_algorithm = FruchtermanReingoldAlgorithm(config);
```

#### 3. 自定义节点渲染
```dart
GraphViewCustomPainter(
  graph: _graph,
  algorithm: _algorithm,
  builder: (Node node) {
    return Container(
      width: _nodeSize,
      height: _nodeSize,
      decoration: BoxDecoration(
        color: _getGenderColor(character.gender),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(...)],
      ),
      child: Center(
        child: Text(_getCharacterInitial(character)),
      ),
    );
  },
)
```

#### 4. 交互式视图
```dart
InteractiveViewer(
  transformationController: _transformationController,
  minScale: 0.1,
  maxScale: 5.0,
  constrained: false,
  boundaryMargin: const EdgeInsets.all(8),
  child: GraphViewCustomPainter(...),
)
```

## 文件结构

### 新增文件
```
novel_app/lib/screens/
  └── enhanced_relationship_graph_screen.dart  # 全局关系图实现

novel_app/test/unit/screens/
  └── character_management_screen_test.dart    # 入口功能测试
```

### 修改文件
```
novel_app/lib/screens/
  └── character_management_screen.dart         # 添加关系图入口按钮
```

## 测试验证

### 单元测试
- ✅ 验证非多选模式下显示关系图按钮
- ✅ 验证按钮可交互性
- ✅ 验证AppBar标题正确
- ✅ 验证按钮图标和tooltip
- ✅ 所有7个测试通过

### 编译检查
- ✅ flutter analyze 无错误
- ✅ 依赖正确加载
- ✅ API使用正确

## 已知限制

1. **单小说范围**: 关系图仅显示当前小说的角色和关系
2. **布局性能**: 角色数量过多(>50)时布局计算可能较慢
3. **关系类型**: 当前连线不显示具体关系类型(朋友、敌人等)
4. **点击交互**: 点击节点无额外操作(可扩展显示详情)

## 未来优化方向

1. **关系标签**: 在连线上显示关系类型
2. **节点详情**: 点击节点显示角色详细信息
3. **关系筛选**: 允许筛选显示特定类型的关系
4. **布局优化**: 增加更多布局算法选项
5. **导出功能**: 支持导出关系图为图片
6. **性能优化**: 大规模图的虚拟化渲染

## 使用示例

### 场景1: 查看小说人物关系
1. 打开有多个角色的小说
2. 进入人物管理
3. 点击关系图图标
4. 查看自动布局的人物关系网络

### 场景2: 分析角色关系
1. 在关系图中观察节点距离
2. 距离近的角色关系更紧密
3. 使用缩放功能查看细节
4. 拖移动查看不同区域

## 故障排除

### 问题: 关系图显示空白
**原因**: 小说中暂无角色数据
**解决**: 先添加角色后再查看关系图

### 问题: 节点位置不够理想
**原因**: 力导向算法随机初始化
**解决**: 点击刷新按钮重新计算布局

### 问题: 无法缩放/移动
**原因**: InteractiveViewer配置问题
**解决**: 检查constrained和boundaryMargin设置

## 总结

全局人物关系图功能已完整实现,使用现代化的力导向布局算法,提供流畅的交互体验。用户可以直观地查看和分析小说中所有角色之间的关系网络。
