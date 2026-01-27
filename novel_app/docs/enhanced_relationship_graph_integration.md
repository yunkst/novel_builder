# 增强版关系图集成示例

本文档提供了将 `EnhancedRelationshipGraphScreen` 集成到现有代码的具体示例。

## 📋 集成步骤总览

1. ✅ 已添加 `graphview` 依赖到 `pubspec.yaml`
2. ✅ 已创建 `enhanced_relationship_graph_screen.dart`
3. 🔄 需要修改现有页面添加入口

## 🔧 集成方式

### 方式1: 修改现有的关系列表页面

**文件**: `lib/screens/character_relationship_screen.dart`

在 AppBar 的 actions 中新增"全局关系图"按钮:

```dart
// 在第195-206行的actions部分修改
appBar: AppBar(
  title: Text('${widget.character.name} - 人物关系'),
  backgroundColor: Theme.of(context).colorScheme.inversePrimary,
  foregroundColor: Colors.white,
  actions: [
    // 新增:全局关系图按钮(显示所有角色的关系网络)
    IconButton(
      icon: const Icon(Icons.hub_outlined), // 使用更合适的图标
      tooltip: '查看全局关系图',
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EnhancedRelationshipGraphScreen(
              novelUrl: widget.character.novelUrl,
              initialCharacter: widget.character, // 传入当前角色作为初始焦点
            ),
          ),
        );
        // 返回后刷新列表
        _loadData();
      },
    ),
    // 原有的单个角色关系图按钮
    IconButton(
      icon: const Icon(Icons.account_tree),
      tooltip: '查看关系图',
      onPressed: _viewGraph,
    ),
    // 原有的添加按钮
    IconButton(
      icon: const Icon(Icons.add),
      tooltip: '添加关系',
      onPressed: _addRelationship,
    ),
  ],
  // ... rest of AppBar
),
```

**同时在文件顶部添加导入**:

```dart
// 在第1-7行之后添加
import 'character_relationship_graph_screen.dart';
import 'enhanced_relationship_graph_screen.dart'; // 新增导入
```

### 方式2: 在角色管理页面添加入口

**文件**: 需要找到角色管理/列表页面

```dart
// 假设在某个角色列表页面
class CharacterListScreen extends StatefulWidget {
  // ...
}

class _CharacterListScreenState extends State<CharacterListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('角色管理'),
        actions: [
          // 新增:全局关系图入口
          IconButton(
            icon: const Icon(Icons.hub),
            tooltip: '角色关系网络图',
            onPressed: () async {
              final novelUrl = widget.novel.url; // 获取小说URL

              // 先检查是否有角色数据
              final characters = await _databaseService.getCharacters(novelUrl);

              if (!mounted) return;

              if (characters.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('暂无角色数据,请先添加角色'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              // 跳转到全局关系图
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EnhancedRelationshipGraphScreen(
                    novelUrl: novelUrl,
                  ),
                ),
              );

              // 返回后刷新角色列表
              _loadCharacters();
            },
          ),
          // ... 其他按钮
        ],
      ),
      // ... rest of body
    );
  }
}
```

### 方式3: 在单个角色卡片上添加快捷入口

**文件**: 角色列表相关的页面

```dart
// 在角色卡片的操作区域添加
Widget _buildCharacterCard(Character character) {
  return Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: _getGenderColor(character.gender),
        child: Text(
          character.name.isNotEmpty ? character.name[0] : '?',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(character.name),
      subtitle: Text(character.gender ?? '未知'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 新增:在关系网络中查看此角色
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '在关系网络中查看',
            onPressed: () async {
              await Navigator.push(
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
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: '查看关系',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CharacterRelationshipScreen(
                    character: character,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}
```

### 方式4: 在阅读器页面添加快捷入口

**文件**: `lib/screens/reader_screen.dart` 或相关阅读页面

```dart
// 在阅读器的菜单或工具栏中添加
class ReaderScreen extends StatefulWidget {
  // ...
}

class _ReaderScreenState extends State<ReaderScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... existing UI
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showReaderMenu();
        },
        child: const Icon(Icons.menu),
      ),
    );
  }

  void _showReaderMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bookmark),
              title: const Text('目录'),
              onTap: () {
                Navigator.pop(context);
                // 显示目录
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('设置'),
              onTap: () {
                Navigator.pop(context);
                // 显示设置
              },
            ),
            // 新增:角色关系网络入口
            ListTile(
              leading: const Icon(Icons.hub),
              title: const Text('角色关系图'),
              subtitle: const Text('查看所有角色的关系网络'),
              onTap: () async {
                Navigator.pop(context);

                final novelUrl = widget.novel.url;

                // 跳转到关系图
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EnhancedRelationshipGraphScreen(
                      novelUrl: novelUrl,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

## 🎨 UI优化建议

### 1. 图标选择

推荐的图标选项:

```dart
Icons.hub              // 网络中心节点图标
Icons.hub_outlined     // 网络中心节点图标(轮廓)
Icons.account_tree     // 树形结构
Icons.share            // 分享/连接图标
Icons.device_hub       // 设备连接中心
Icons.bubble_chart     // 气泡图
Icons.public           // 全球/网络
```

### 2. 按钮位置建议

根据页面类型选择合适的位置:

| 页面类型 | 推荐位置 | 优先级 |
|---------|---------|--------|
| 角色关系列表 | AppBar actions (第一位) | 高 |
| 角色管理列表 | AppBar actions | 中 |
| 角色详情页 | 卡片操作区 | 中 |
| 阅读器 | 菜单/抽屉 | 低 |

### 3. 权限控制

添加角色数量检查,避免空数据:

```dart
// 统一的跳转方法
Future<void> _navigateToRelationshipGraph(BuildContext context, String novelUrl, {Character? initialCharacter}) async {
  // 显示加载提示
  if (context.mounted) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  try {
    // 预先检查角色数据
    final characters = await _databaseService.getCharacters(novelUrl);

    if (context.mounted) {
      Navigator.pop(context); // 关闭加载对话框
    }

    if (characters.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('暂无角色数据,请先添加角色'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedRelationshipGraphScreen(
            novelUrl: novelUrl,
            initialCharacter: initialCharacter,
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context); // 关闭加载对话框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加载失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// 使用示例
onPressed: () => _navigateToRelationshipGraph(
  context,
  widget.character.novelUrl,
  initialCharacter: widget.character,
),
```

## 🧪 测试清单

集成后请测试以下功能:

### 基础功能测试

- [ ] 从关系列表页能正常跳转到全局关系图
- [ ] 从角色管理页能正常跳转
- [ ] 没有角色数据时显示正确提示
- [ ] 有角色数据时能正常显示关系网络

### 交互功能测试

- [ ] 点击节点能弹出详情对话框
- [ ] 长按节点能高亮关系网络
- [ ] 搜索功能正常工作
- [ ] 返回后上一页面正确刷新

### 边界情况测试

- [ ] 只有1个角色时正确显示
- [ ] 有大量角色(>50)时性能可接受
- [ ] 角色没有任何关系时正确显示
- [ ] 数据加载失败时错误提示清晰

### UI兼容性测试

- [ ] 暗色模式下显示正常
- [ ] 不同屏幕尺寸下布局合理
- [ ] 横屏/竖屏切换无问题
- ] ] AppBar图标不拥挤

## 📝 集成检查清单

在提交代码前,请确认:

- [ ] 已添加 `import 'enhanced_relationship_graph_screen.dart';`
- [ ] 已在至少一个页面添加入口按钮
- [ ] 已测试从不同页面跳转功能
- [ ] 已处理空数据和错误情况
- [ ] 已更新用户文档(如果需要)
- [ ] 代码符合项目规范

## 🔍 常见集成问题

### Q1: 导入错误找不到类?

**确认**:
```dart
// 文件顶部添加
import 'enhanced_relationship_graph_screen.dart';
```

### Q2: 点击按钮没反应?

**检查**:
1. 是否使用了 `await`
2. 是否检查了 `context.mounted`
3. 是否正确传递了 `novelUrl` 参数

### Q3: 页面返回后数据没刷新?

**解决**:
```dart
await Navigator.push(...);
// 在push后添加刷新逻辑
_loadData();
```

## 📦 完整示例:修改后的 character_relationship_screen.dart

```dart
import 'package:flutter/material.dart';
import '../models/character.dart';
import '../models/character_relationship.dart';
import '../services/database_service.dart';
import '../widgets/relationship_edit_dialog.dart';
import 'character_relationship_graph_screen.dart';
import 'enhanced_relationship_graph_screen.dart'; // 新增

class CharacterRelationshipScreen extends StatefulWidget {
  final Character character;

  const CharacterRelationshipScreen({
    super.key,
    required this.character,
  });

  @override
  State<CharacterRelationshipScreen> createState() =>
      _CharacterRelationshipScreenState();
}

class _CharacterRelationshipScreenState
    extends State<CharacterRelationshipScreen>
    with SingleTickerProviderStateMixin {
  // ... 现有代码

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.character.name} - 人物关系'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        foregroundColor: Colors.white,
        actions: [
          // 新增:全局关系图按钮
          IconButton(
            icon: const Icon(Icons.hub_outlined),
            tooltip: '查看全局关系图',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EnhancedRelationshipGraphScreen(
                    novelUrl: widget.character.novelUrl,
                    initialCharacter: widget.character,
                  ),
                ),
              );
              _loadData(); // 返回后刷新
            },
          ),
          // 原有按钮
          IconButton(
            icon: const Icon(Icons.account_tree),
            tooltip: '查看关系图',
            onPressed: _viewGraph,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加关系',
            onPressed: _addRelationship,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          // ... 现有代码
        ),
      ),
      // ... 现有代码
    );
  }

  // ... 其他现有代码保持不变
}
```

---

**文档版本**: v1.0.0
**最后更新**: 2025-01-25
