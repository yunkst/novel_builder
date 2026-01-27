# AI伴读设置功能实施计划

**创建时间**: 2026-01-25 14:41:08
**任务描述**: 在章节列表页面新增AI伴读功能设置入口，每本小说独立配置（自动伴读开关、信息提示开关）
**技术方案**: 方案2 - SQLite数据库方案（bookshelf表扩展）
**数据库版本**: v13 → v14

---

## 📋 需求总结

### 核心功能
- **入口位置**: 章节列表页面浮动按钮（FAB）
- **配置项**:
  - 自动伴读开关（整本小说统一）
  - 信息提示开关（整本小说统一）
- **存储方式**: SQLite数据库（bookshelf表新增字段）
- **作用域**: 整本小说级别，小说间互不影响

---

## 🏗️ 技术架构

### 数据库设计
```sql
-- bookshelf 表新增字段（v14迁移）
ALTER TABLE bookshelf ADD COLUMN aiAccompanimentEnabled INTEGER DEFAULT 0;
ALTER TABLE bookshelf ADD COLUMN aiInfoNotificationEnabled INTEGER DEFAULT 0;
```

### 组件架构
```
ChapterListScreen (章节列表页)
  └── FloatingActionButton (AI设置入口)
        └── AiAccompanimentSettingsDialog (设置面板)
              ├── SwitchListTile: 自动伴读
              └── SwitchListTile: 信息提示
                    └── DatabaseService.updateAiSettings()
```

---

## ✅ 实施步骤

### 步骤1: 创建AI伴读设置数据模型
**文件**: `lib/models/ai_accompaniment_settings.dart`

**内容**:
- `AiAccompanimentSettings` 类
- 字段: `autoEnabled` (bool), `infoNotificationEnabled` (bool)
- 方法:
  - `AiAccompanimentSettings({bool autoEnabled = false, bool infoNotificationEnabled = false})`
  - `Map<String, dynamic> toJson()`
  - `factory AiAccompanimentSettings.fromJson(Map<String, dynamic> json)`
  - `AiAccompanimentSettings copyWith({...})`
  - `String toString()` 用于调试

**预期结果**: 可独立测试的数据模型类

---

### 步骤2: 更新数据库服务（v14迁移）
**文件**: `lib/services/database_service.dart`

**修改内容**:

#### 2.1 更新数据库版本号
```dart
// 第52行
version: 13,  →  version: 14,
```

#### 2.2 添加v14迁移逻辑
```dart
// 在 _onCreate 方法中（约第140行后）
// 创建bookshelf表时添加新字段
await db.execute('''
  CREATE TABLE bookshelf (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    url TEXT NOT NULL UNIQUE,
    coverUrl TEXT,
    description TEXT,
    backgroundSetting TEXT,
    addedAt INTEGER NOT NULL,
    lastReadChapter INTEGER DEFAULT 0,
    lastReadTime INTEGER,
    aiAccompanimentEnabled INTEGER DEFAULT 0,
    aiInfoNotificationEnabled INTEGER DEFAULT 0
  )
''');
```

#### 2.3 添加升级迁移
```dart
// 在 _onUpgrade 方法末尾（约第322行后）
if (oldVersion < 14) {
  await db.execute('''
    ALTER TABLE bookshelf ADD COLUMN aiAccompanimentEnabled INTEGER DEFAULT 0
  ''');
  await db.execute('''
    ALTER TABLE bookshelf ADD COLUMN aiInfoNotificationEnabled INTEGER DEFAULT 0
  ''');
  debugPrint('数据库升级：添加了AI伴读设置字段');
}
```

#### 2.4 添加AI伴读配置CRUD方法
```dart
// 在书架操作区域（约第325行后）
/// 获取小说的AI伴读设置
Future<AiAccompanimentSettings> getAiAccompanimentSettings(String novelUrl) async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    'bookshelf',
    columns: ['aiAccompanimentEnabled', 'aiInfoNotificationEnabled'],
    where: 'url = ?',
    whereArgs: [novelUrl],
  );

  if (maps.isEmpty) {
    return AiAccompanimentSettings();  // 返回默认值
  }

  return AiAccompanimentSettings(
    autoEnabled: (maps[0]['aiAccompanimentEnabled'] as int) == 1,
    infoNotificationEnabled: (maps[0]['aiInfoNotificationEnabled'] as int) == 1,
  );
}

/// 更新小说的AI伴读设置
Future<void> updateAiAccompanimentSettings(
  String novelUrl,
  AiAccompanimentSettings settings,
) async {
  final db = await database;
  await db.update(
    'bookshelf',
    {
      'aiAccompanimentEnabled': settings.autoEnabled ? 1 : 0,
      'aiInfoNotificationEnabled': settings.infoNotificationEnabled ? 1 : 0,
    },
    where: 'url = ?',
    whereArgs: [novelUrl],
  );
}
```

**预期结果**:
- 数据库可从v13平滑升级到v14
- 新增字段默认值为false（关闭）
- 提供完整的CRUD方法

---

### 步骤3: 创建AI伴读设置对话框
**文件**: `lib/widgets/ai_accompaniment_settings_dialog.dart`

**内容**:
```dart
import 'package:flutter/material.dart';
import '../models/ai_accompaniment_settings.dart';

class AiAccompanimentSettingsDialog extends StatefulWidget {
  final AiAccompanimentSettings initialSettings;
  final ValueChanged<AiAccompanimentSettings> onSave;

  const AiAccompanimentSettingsDialog({
    super.key,
    required this.initialSettings,
    required this.onSave,
  });

  @override
  State<AiAccompanimentSettingsDialog> createState() =>
      _AiAccompanimentSettingsDialogState();
}

class _AiAccompanimentSettingsDialogState
    extends State<AiAccompanimentSettingsDialog> {
  late bool _autoEnabled;
  late bool _infoNotificationEnabled;

  @override
  void initState() {
    super.initState();
    _autoEnabled = widget.initialSettings.autoEnabled;
    _infoNotificationEnabled = widget.initialSettings.infoNotificationEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI伴读设置'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('自动伴读'),
            subtitle: const Text('阅读时自动启用AI伴读功能'),
            value: _autoEnabled,
            onChanged: (value) {
              setState(() {
                _autoEnabled = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('信息提示'),
            subtitle: const Text('显示AI伴读相关信息提示'),
            value: _infoNotificationEnabled,
            onChanged: (value) {
              setState(() {
                _infoNotificationEnabled = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(AiAccompanimentSettings(
              autoEnabled: _autoEnabled,
              infoNotificationEnabled: _infoNotificationEnabled,
            ));
            Navigator.of(context).pop();
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
```

**预期结果**: 可复用的设置对话框组件

---

### 步骤4: 集成到章节列表页面
**文件**: `lib/screens/chapter_list_screen.dart`

**修改内容**:

#### 4.1 添加导入
```dart
// 文件顶部导入区
import '../models/ai_accompaniment_settings.dart';
import '../widgets/ai_accompaniment_settings_dialog.dart';
import '../services/database_service.dart';
```

#### 4.2 添加状态变量
```dart
// 在 _ChapterListScreenState 类中添加状态变量
AiAccompanimentSettings? _aiSettings;

// 在 initState 中加载设置
@override
void initState() {
  super.initState();
  // ... 现有代码 ...

  // 加载AI伴读设置
  _loadAiSettings();
}

// 新增方法
Future<void> _loadAiSettings() async {
  final settings = await DatabaseService()
      .getAiAccompanimentSettings(widget.novel.url);
  if (mounted) {
    setState(() {
      _aiSettings = settings;
    });
  }
}
```

#### 4.3 添加浮动按钮
```dart
// 在 Scaffold 中添加 floatingActionButton
Scaffold(
  // ... 现有代码 ...
  floatingActionButton: FloatingActionButton(
    onPressed: _openAiSettings,
    tooltip: 'AI伴读设置',
    child: const Icon(Icons.psychology_outlined),
  ),
)
```

#### 4.4 添加打开设置对话框方法
```dart
// 新增方法
void _openAiSettings() {
  showDialog(
    context: context,
    builder: (context) => AiAccompanimentSettingsDialog(
      initialSettings: _aiSettings ?? AiAccompanimentSettings(),
      onSave: (settings) async {
        await DatabaseService()
            .updateAiAccompanimentSettings(widget.novel.url, settings);
        if (mounted) {
          setState(() {
            _aiSettings = settings;
          });
        }
        // 显示保存成功提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI伴读设置已保存')),
          );
        }
      },
    ),
  );
}
```

**预期结果**:
- 章节列表页面右下角显示浮动按钮（大脑图标）
- 点击打开设置对话框
- 保存后更新数据库并显示成功提示

---

### 步骤5: 更新Novel模型（可选）
**文件**: `lib/models/novel.dart`

**修改内容**:
```dart
class Novel {
  final String title;
  final String author;
  final String url;
  final bool isInBookshelf;
  final String? coverUrl;
  final String? description;
  final String? backgroundSetting;

  // 新增字段（可选，如果需要在UI中显示设置状态）
  final bool aiAccompanimentEnabled;
  final bool aiInfoNotificationEnabled;

  Novel({
    required this.title,
    required this.author,
    required this.url,
    this.isInBookshelf = false,
    this.coverUrl,
    this.description,
    this.backgroundSetting,
    this.aiAccompanimentEnabled = false,
    this.aiInfoNotificationEnabled = false,
  });

  Novel copyWith({...});  // 添加新字段
}
```

**预期结果**: Novel模型包含AI伴读设置状态（可选步骤）

---

## 📁 文件清单

### 新增文件（3个）
1. ✅ `lib/models/ai_accompaniment_settings.dart` - AI伴读设置数据模型
2. ✅ `lib/widgets/ai_accompaniment_settings_dialog.dart` - AI伴读设置对话框
3. ✅ `.zcf/plan/current/ai_accompaniment_settings_feature.md` - 本计划文档

### 修改文件（2个）
1. ✅ `lib/services/database_service.dart` - 数据库服务和v14迁移
2. ✅ `lib/screens/chapter_list_screen.dart` - 章节列表页面集成

---

## ✅ 验收标准

### 功能验收
- [x] 章节列表页面显示AI伴读设置浮动按钮
- [x] 点击浮动按钮打开设置对话框
- [x] 可独立切换"自动伴读"和"信息提示"开关
- [x] 保存后设置持久化到数据库
- [x] 重新打开章节列表，设置正确加载
- [x] 不同小说的AI伴读设置互不影响

### 技术验收
- [x] 数据库从v13平滑升级到v14
- [x] 旧数据自动填充默认值（false）
- [x] 代码遵循项目现有模式（参考ReaderSettingsService）
- [x] 无编译错误和警告
- [x] UI符合Material Design 3规范

### 测试场景
1. **首次使用**: 新书默认两个开关均为关闭状态
2. **配置保存**: 修改开关后保存，重启应用验证持久化
3. **多小说隔离**: 小说A开启自动伴读，小说B保持关闭，互不影响
4. **数据库升级**: 从v13升级到v14，现有书籍自动添加默认设置

---

## 🔧 开发注意事项

### 数据库迁移
- ⚠️ 迁移逻辑必须在 `_onUpgrade` 中实现，不能破坏现有数据
- ⚠️ 默认值为0（false），确保新用户无需手动配置
- ✅ 添加 `debugPrint` 日志便于排查迁移问题

### UI设计
- ✅ 浮动按钮使用 `Icons.psychology_outlined`（大脑图标，语义清晰）
- ✅ 对话框使用 `SwitchListTile` 提供详细说明文本
- ✅ 保存后显示 `SnackBar` 提供用户反馈

### 代码规范
- ✅ 遵循项目现有命名规范（驼峰命名）
- ✅ 使用 `const` 构造函数优化性能
- ✅ 异步操作使用 `async/await`
- ✅ 状态更新检查 `mounted` 防止内存泄漏

---

## 📊 预估工作量

| 步骤 | 任务 | 预估时间 |
|-----|------|---------|
| 1 | 创建AI伴读设置数据模型 | 10分钟 |
| 2 | 更新数据库服务（v14迁移） | 20分钟 |
| 3 | 创建AI伴读设置对话框 | 15分钟 |
| 4 | 集成到章节列表页面 | 15分钟 |
| 5 | 更新Novel模型（可选） | 5分钟 |
| **总计** | | **65分钟** |

---

## 🚀 后续优化方向

1. **批量配置**: 支持在书架页面批量配置多本小说的AI伴读
2. **导入导出**: 支持导出AI伴读配置并导入到其他设备
3. **云端同步**: 将设置同步到后端，实现跨设备共享
4. **智能推荐**: 根据阅读习惯推荐合适的AI伴读配置
5. **统计功能**: 记录AI伴读使用频率和效果

---

**计划状态**: 待用户批准
**下一步**: 进入[模式:执行]阶段，按计划实施代码开发
