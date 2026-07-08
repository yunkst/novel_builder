# 人物关系图重设计

> 日期:2026-07-08 | 状态:待审查 | 关联词表:[relationship-types-catalog.md](./relationship-types-catalog.md)

## 1. 背景与问题

novel_app 现有"人物关系"功能的数据层(`CharacterRelationship` model、`CharacterRelationRepository`、`character_relationships` 表 migration v13、`characterRelationRepositoryProvider`)已建好,但:

- **UI / Service 层完全空缺**:全仓库 `screens/widgets/services/controllers` 无任何调用(grep 确认),用户在前端接触不到。
- **力导向图依赖已引入但未使用**:`flutter_force_directed_graph` 在 pubspec,无任何 import。
- **数据模型过于简陋**:仅"有向 + 自由文本类型",无分类、无强度、无时间维度,无法支撑可视化与 AI 抽取。

本次重做数据模型 + 补齐 UI,核心引入**章节时间轴**交互。

## 2. 核心决策(已与产品确认)

| 决策 | 选择 | 理由 |
|------|------|------|
| 定位 | 通用底座(阅读/AI/欣赏复用) | 一次建设多场景复用 |
| 关系类型 | **封闭 Dart 枚举**(17 大类 109 个) | 封闭集对 AI 抽取友好;加值需发版故 v1 穷尽铺满 |
| 正反词条 | 一个 enum 值带 forward/reverse | 一条记录两方向各取各的词(师傅↔徒弟) |
| 阵营维度 | 不做 | 避免信息混乱 |
| 章节时间轴 | 做,纯进度过滤 | 与阅读器章节进度天然契合 |
| 自动播放/未来预览 | 不做 | 克制 |
| 强度 | 正式维度(1-5) | 线宽可视化 + AI 立场权重 |
| 关系变化建模 | 区间模型 | 简单、查询快,符合 YAGNI |
| 成人向关系 | 收录,无开关,暗色系 | 阅读器要支持各类小说;iOS 审核注意截图不暴露 |

## 3. 数据模型

### 3.1 `RelationType` 枚举(新增)

```dart
enum RelationType {
  parentChild('父母', '子女', AppColors.relationBloodDirect, symmetric: false),
  mentor('师父', '徒弟', AppColors.relationMentor, symmetric: false),
  friend('朋友', '朋友', AppColors.relationFriend, symmetric: true),
  // ... 共 109 个,见 relationship-types-catalog.md
  ;

  final String forward;   // source 视角
  final String reverse;   // target 视角
  final Color color;
  final bool symmetric;
  const RelationType(this.forward, this.reverse, this.color, {required this.symmetric});

  String labelFor(bool isSource) => isSource ? forward : reverse;
}
```

完整 109 个枚举值定义见 [relationship-types-catalog.md](./relationship-types-catalog.md)。sqflite 存 `name` 字符串。颜色需在 `AppColors` 中新增 `relation*` 常量集(按词表 hex 值定义,按大类色系组织)。

### 3.2 `CharacterRelationship` v2(重做)

```
id, source_character_id, target_character_id,
relation_type      -- RelationType.name(枚举,非自由文本)
strength           -- 1-5,默认 3
start_chapter      -- 关系建立章节,必填
end_chapter        -- 关系结束章节,可空=持续至今
description        -- 可选备注(冷僻关系兜底)
novel_url          -- 冗余,加速按小说查询(免每次 join characters)
created_at, updated_at
```
唯一约束:`UNIQUE(source_character_id, target_character_id, relation_type, start_chapter)`

### 3.3 `Character` 表扩展

新增 `first_appearance_chapter INTEGER`(登场章节,可空=视为 §1 登场),时间轴据此过滤人物。

## 4. 分层架构(复用现有 Repository 模式)

```
UI: RelationshipGraphScreen(力导向图 + 时间轴控制器)  [新增]
     └─ ConsumerWidget, ref.watch(relationshipGraphProvider)
State: relationshipGraphProvider (FutureProvider.family<(novelUrl, chapter)>)
       currentChapterProvider (当前章节进度,可手动调)        [新增]
Repository: CharacterRelationRepository 扩展
     └─ getGraphSnapshot(novelUrl, chapter) → {characters, relationships}
Model: CharacterRelationship v2 + RelationType enum              [重做]
DB: character_relationships 改造 + characters 加字段 (v34 → v35)
```

不新增独立 Service 层(关系图查询简单,Provider 直接调 Repository,与项目现有模式一致)。

## 5. 章节时间轴数据流

1. **进度来源**:`currentChapter` 取自 `NovelRepository.getLastReadChapter(novelUrl)`(底层 `bookshelf.lastReadChapter`,章节 index,0-based)。关系图的 `start_chapter`/`end_chapter`/`first_appearance_chapter` **统一用章节 index**,与阅读进度对接;时间轴滑块范围 `0..章节数-1`,UI 显示时 +1(第 N 章)。关系图页面顶部提供手动滑块覆盖默认进度。
2. **快照查询**:`relationshipGraphProvider(novelUrl, chapter)` 调 `repo.getGraphSnapshot`:
   ```sql
   -- 已登场人物
   SELECT * FROM characters WHERE novel_url = ? AND (first_appearance_chapter IS NULL OR first_appearance_chapter <= ?)
   -- 当前生效关系
   SELECT * FROM character_relationships WHERE novel_url = ? AND start_chapter <= ?
     AND (end_chapter IS NULL OR end_chapter >= ?)
   ```
3. **渲染**:力导向图节点=已登场人物,边=生效关系(按 `RelationType.color` 着色,按 `strength` 映射线宽 1-5px);对称关系无箭头,不对称带方向箭头;节点显示角色名,边显示 `labelFor`。
4. **交互**:滑块拖动 → 更新 `currentChapter` → provider 重查 → 图重绘;拖动用 debounce(~150ms)避免抖动。
5. **性能**:本地 SQLite,单小说关系量级小(几十人物/百关系),查询毫秒级。

## 6. 数据库迁移(v34 → v35)

当前 `currentVersion = 34`(v34 已用于 media_items 表)。本次新增 **case 35** 并将 `currentVersion` 改为 `35`。`character_relationships` 表(v13 建)实际**从未被 UI 使用,是空表**,迁移零数据风险,可直接 `DROP` 重建:

```sql
DROP TABLE IF EXISTS character_relationships;
CREATE TABLE character_relationships (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_character_id INTEGER NOT NULL,
  target_character_id INTEGER NOT NULL,
  relation_type TEXT NOT NULL,           -- RelationType.name
  strength INTEGER NOT NULL DEFAULT 3,
  start_chapter INTEGER NOT NULL,
  end_chapter INTEGER,
  description TEXT,
  novel_url TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER,
  FOREIGN KEY (source_character_id) REFERENCES characters(id) ON DELETE CASCADE,
  FOREIGN KEY (target_character_id) REFERENCES characters(id) ON DELETE CASCADE,
  UNIQUE(source_character_id, target_character_id, relation_type, start_chapter)
);
CREATE INDEX idx_rel_source ON character_relationships(source_character_id);
CREATE INDEX idx_rel_target ON character_relationships(target_character_id);
CREATE INDEX idx_rel_novel_chapter ON character_relationships(novel_url, start_chapter, end_chapter);
```
`characters` 表:`ALTER TABLE characters ADD COLUMN first_appearance_chapter INTEGER;`

> 现有 model/接口 `ICharacterRelationRepository` 的方法签名需同步重做(原方法如 `getRelationships(characterId)` 语义不变,但字段变了;新增 `getGraphSnapshot`)。

## 7. 错误处理

- **章节越界**:`start_chapter < 0` 拒绝(0-based index);`end_chapter < start_chapter` 拒绝(repository 校验,抛 `ArgumentError`)。
- **未登场人物建关系**:`start_chapter` 应 ≥ 双方 `first_appearance_chapter`;不强制,但 UI 给警告提示。
- **枚举非法值**:`relation_type` 必须是合法 `RelationType.name`;Dart enum 在代码层保证,DB 读入时 `RelationType.values.byName` 失败则抛(数据不应出现非法值)。
- **对称关系重复**:对称类型 `(A,B)` 与 `(B,A)` 视为同一条;repository `createRelationship` 前查重(对称则双向检查)。
- **删除角色级联**:`ON DELETE CASCADE` 已保证角色删除时关系自动清理。

## 8. 测试策略(补现有缺失的 repository 单测)

- **`RelationType` 枚举单测**:109 个值字段完整(forward/reverse/color/symmetric);`labelFor` 方向正确;对称性标注与 forward==reverse 一致。
- **`CharacterRelationRepository` 单测**(用 sqflite_ffi):
  - `getGraphSnapshot` 按章节正确过滤(人物登场、关系生效/失效)
  - 关系区间重叠场景(朋友 §25-79、恋人 §80+ 在 §50/§80 查询返回正确关系)
  - 唯一约束(同对人同章同类型不重复)
  - 强度/起止章节校验(越界、end<start 抛错)
  - 对称关系去重
  - 级联删除
- **Provider 测试**:`relationshipGraphProvider(novelUrl, chapter)` 按章节返回正确快照;章节变化触发重查。
- **迁移测试**:v34→v35 表结构正确;空表迁移无报错。

## 9. 范围边界(YAGNI)

本期**不做**:
- AI 自动从章节抽取关系(留作后续 Agent 工具,封闭枚举已为此铺路)
- 阵营/势力图层
- 关系演变的"事件流"建模(区间模型足够)
- 成人内容开关(暗色系已为未来分组隐藏留基础)
- 自动播放 / 未来关系预览

## 10. 与现有代码的关系

- 复用:`BaseRepository`、`databaseConnectionProvider`、`LoggerService`、`flutter_force_directed_graph` 依赖、现有 `characterRepositoryProvider`。
- 重做:`models/character_relationship.dart`、`core/interfaces/repositories/i_character_relation_repository.dart`、`repositories/character_relation_repository.dart`、`database_migrations.dart`(新增 case 35,`currentVersion` 34->35)。
- 新增:`RelationType` 枚举文件、`RelationshipGraphScreen`、时间轴控制器 widget、`relationshipGraphProvider`/`currentChapterProvider`。
- 删除:README 中对 `relationshipCountCacheProvider` 的过时引用(该 provider 实际不存在)。
