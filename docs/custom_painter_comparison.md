# CustomPainter vs graphview 对比说明

## 🎨 CustomPainter 是什么?

**CustomPainter** 是 Flutter 的底层绘制API,让你像在画布上画画一样绘制图形。

### 类比说明

想象你在画画:

```
┌─────────────────────────────┐
│   Canvas (画布)             │
│                             │
│     🖌️ Paint (画笔)         │
│        ↓                    │
│    ┌─────────┐              │
│    │  画画   │  你控制     │
│    └─────────┘              │
│                             │
└─────────────────────────────┘
```

### 代码示例对比

#### 方案1: 使用 graphview (当前实现)

```dart
// 声明式,简单
GraphViewCustomPainter(
  graph: _graph,
  algorithm: _algorithm,
  builder: (Node node) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
      child: Text('张三'),
    );
  },
)
```

**优点:**
- ✅ 代码简单
- ✅ 自动处理交互
- ✅ 布局算法内置

**缺点:**
- ❌ 受限于库的功能
- ❌ 无法完全自定义绘制

#### 方案2: 使用 CustomPainter

```dart
// 命令式,完全控制
class MyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. 设置画笔
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // 2. 在画布上画圆
    canvas.drawCircle(Offset(100, 100), 50, paint);

    // 3. 设置文字画笔
    final textPainter = TextPainter(
      text: TextSpan(text: '张三'),
      textDirection: TextDirection.ltr,
    );

    // 4. 绘制文字
    textPainter.layout();
    textPainter.paint(canvas, Offset(70, 90));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 使用
CustomPaint(
  painter: MyPainter(),
)
```

**优点:**
- ✅ 完全控制每个像素
- ✅ 可以绘制任何东西
- ✅ 性能最优

**缺点:**
- ❌ 代码复杂
- ❌ 需要自己处理交互
- ❌ 需要自己实现布局算法

## 📊 详细对比

### 1. 实现复杂度

| 任务 | graphview | CustomPainter |
|------|-----------|---------------|
| 画一个圆 | 1行代码 | 3-5行代码 |
| 画一条线 | 自动处理 | 需要计算坐标 |
| 添加文字 | Container + Text | TextPainter + layout |
| 添加阴影 | BoxDecoration | Paint + MaskFilter |
| 点击交互 | 自动支持 | 需要自己实现 |

### 2. 性能对比

**场景: 绘制100个节点**

```
graphview:
- 创建100个Widget
- 每个Widget有完整的Element/RenderObject树
- 内存占用: ~50MB
- 帧率: 45-60 FPS

CustomPainter:
- 创建1个Canvas
- 直接绘制到画布
- 内存占用: ~10MB
- 帧率: 60 FPS (稳定)
```

### 3. 功能对比

| 功能 | graphview | CustomPainter |
|------|-----------|---------------|
| 力导向布局 | ✅ 内置 | ❌ 需要自己实现 |
| 节点渲染 | ✅ Widget | ✅ 完全控制 |
| 边的渲染 | ✅ 自动 | ✅ 完全控制 |
| 缩放/拖拽 | ✅ InteractiveViewer | ❌ 需要自己实现 |
| 点击检测 | ✅ GestureDetector | ❌ 需要自己计算 |
| 动画效果 | ⚠️ 有限 | ✅ 完全控制 |
| 性能优化 | ⚠️ 受限 | ✅ 可以优化 |

## 🎯 实际案例对比

### 案例: 绘制一个带阴影的蓝色圆形节点

#### graphview 实现

```dart
Widget buildNode(Node node) {
  return Container(
    width: 80,
    height: 80,
    decoration: BoxDecoration(
      color: Colors.blue,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 8,
          spreadRadius: 2,
        ),
      ],
    ),
  );
}
```

**优点:** 简单直观
**缺点:** 无法自定义阴影效果

#### CustomPainter 实现

```dart
void paint(Canvas canvas, Size size) {
  final center = Offset(100, 100);
  final radius = 40.0;

  // 1. 绘制阴影
  final shadowPaint = Paint()
    ..color = Colors.black.withOpacity(0.2)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

  canvas.drawCircle(center, radius, shadowPaint);

  // 2. 绘制圆形
  final circlePaint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.fill;

  canvas.drawCircle(center, radius, circlePaint);

  // 3. 绘制高光(可选)
  final highlightPaint = Paint()
    ..color = Colors.white.withOpacity(0.3)
    ..style = PaintingStyle.fill;

  canvas.drawCircle(
    center.translate(-10, -10),
    radius * 0.3,
    highlightPaint,
  );
}
```

**优点:** 可以添加高光、渐变等高级效果
**缺点:** 代码量多

## 💡 选择建议

### 使用 graphview 的场景:

✅ **推荐使用** (你当前的实现)

- 节点数量 < 100
- 需要快速开发
- 需要内置的交互(缩放、拖拽)
- 不需要特殊的视觉效果
- 团队熟悉Flutter Widget

### 使用 CustomPainter 的场景:

⚠️ **谨慎考虑**

- 节点数量 > 1000
- 需要极致性能(如游戏)
- 需要特殊的视觉效果
- 需要实时动画(每秒60帧)
- 图形复杂度很高
- 有专业的图形开发经验

## 🔧 混合方案

**最佳实践:** graphview + CustomPainter

```dart
// 使用graphview处理布局和交互
GraphViewCustomPainter(
  graph: _graph,
  algorithm: _algorithm,
  builder: (Node node) {
    // 使用CustomPaint自定义绘制
    return CustomPaint(
      painter: CustomNodePainter(
        character: character,
        size: Size(80, 80),
      ),
    );
  },
)

// 自定义节点绘制器
class CustomNodePainter extends CustomPainter {
  final Character character;
  final Size size;

  @override
  void paint(Canvas canvas, Size size) {
    // 在这里绘制特殊的节点效果
    // 例如: 渐变、纹理、复杂形状等
  }
}
```

## 📝 总结

**CustomPainter = Flutter的"Photoshop"**
- 功能强大,但需要专业技能
- 适合特殊需求,不是常规选择

**graphview = Flutter的"Canva"**
- 易用,功能全面
- 适合大多数场景,包括你的项目

### 当前项目建议:

**保持使用 graphview**,原因:

1. ✅ 你的节点数量 < 100 (人物关系图)
2. ✅ 需要交互功能(缩放、拖拽)
3. ✅ 已经实现完成
4. ✅ 性能足够好
5. ✅ 代码可维护性高

如果未来需要,可以在节点渲染时混入CustomPaint:

```dart
builder: (Node node) {
  return CustomPaint(
    painter: SpecialEffectPainter(), // 添加特殊效果
    child: Container(/* 原有节点 */),
  );
}
```

这样既有graphview的便利,又有CustomPainter的灵活性!
