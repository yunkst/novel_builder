# 人物关系图重设计 实现计划

> **面向 AI 代理的工作者:** 必需子技能:使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标:** 重做 novel_app 的人物关系图--重写数据模型(封闭枚举 + 区间模型 + 强度 + 章节时间轴)、补齐 UI(力导向图 + 章节滑块),让用户能按阅读进度查看人物关系演变。

**架构:** `RelationType` 封闭枚举(109 个,正反双向词条)→ `CharacterRelationship` 区间模型(strength/start_chapter/end_chapter)→ `CharacterRelationRepository.getGraphSnapshot(novelUrl, chapter)` 按章节过滤 → `relationshipGraphProvider` 暴露快照 → `RelationshipGraphScreen` 用 `flutter_force_directed_graph` 渲染 + 顶部章节滑块。复用现有 `CharacterRelationRepository`/`BaseRepository`/Riverpod 模式。

**技术栈:** Flutter、Dart、Riverpod(riverpod_annotation + build_runner)、sqflite、sqflite_common_ffi(测试)、flutter_force_directed_graph ^1.0.8、mockito。

**规格引用:**
- 设计文档:`docs/superpowers/specs/2026-07-08-character-relationship-graph-design.md`
- 关系类型词表:`docs/superpowers/specs/relationship-types-catalog.md`(109 个枚举的权威来源)

**执行环境:** 建议在专用分支 `feature/character-relationship-graph` 或 worktree 执行(当前在 `master`)。所有命令在 `novel_app/` 目录下运行。

---

## 文件结构

**创建:**
- `novel_app/lib/models/relation_type.dart` — `RelationType` 枚举(109 个值,带 forward/reverse/color/symmetric)
- `novel_app/lib/models/relationship_graph_snapshot.dart` — 图快照(`{characters, relationships}`)
- `novel_app/lib/core/providers/relationship_graph_providers.dart` — `relationshipGraphProvider`、`currentChapterProvider`
- `novel_app/lib/screens/relationship_graph_screen.dart` — 关系图页面(力导向图 + 滑块)
- `novel_app/lib/widgets/relationship/timeline_chapter_slider.dart` — 章节时间轴滑块
- `novel_app/test/helpers/in_memory_db.dart` — sqflite_common_ffi in-memory 测试 helper
- `novel_app/test/unit/models/relation_type_test.dart`
- `novel_app/test/unit/models/character_relationship_test.dart`
- `novel_app/test/unit/repositories/character_relation_repository_test.dart`
- `novel_app/test/unit/providers/relationship_graph_providers_test.dart`

**修改:**
- `novel_app/lib/models/character_relationship.dart` — 重做为 v2(枚举 + 强度 + 起止章节 + novel_url)
- `novel_app/lib/models/character.dart` — 加 `firstAppearanceChapter` 字段
- `novel_app/lib/core/interfaces/repositories/i_character_relation_repository.dart` — 重做接口
- `novel_app/lib/repositories/character_relation_repository.dart` — 重做实现 + `getGraphSnapshot`
- `novel_app/lib/core/database/database_migrations.dart` — 加 `case 35`,`currentVersion` 34→35
- `novel_app/lib/core/theme/app_colors.dart` — 加 `relation*` 颜色字段(light/dark)
- `novel_app/test/test_helpers/character_relationship_test_data.dart` — 适配新 model
- `novel_app/lib/screens/character_list_screen.dart` — 加入口跳转
- `novel_app/pubspec.yaml` — 加 `sqflite_common_ffi` dev 依赖

**重新生成:** `novel_app/lib/core/providers/*.g.dart`(build_runner)

---

## 前置任务 0:测试基础设施 + 分支

- [ ] **步骤 1:开分支**

```bash
cd novel_app
git checkout -b feature/character-relationship-graph
```

- [ ] **步骤 2:加 sqflite_common_ffi dev 依赖**

在 `novel_app/pubspec.yaml` 的 `dev_dependencies:` 下加:
```yaml
  sqflite_common_ffi: ^2.3.0
```

- [ ] **步骤 3:写 in-memory db 测试 helper**

创建 `novel_app/test/helpers/in_memory_db.dart`:
```dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:novel_app/core/database/database_migrations.dart';

/// 测试用:初始化 sqflite_ffi 并返回一个跑完所有迁移的 in-memory 数据库。
///
/// DatabaseMigrations 暴露的是 `createV1Tables(db)` 与 `upgrade(db, from, to)`
/// (不是 onCreate/onUpgrade),这与 database_connection.dart 的 _onCreate/_onUpgrade
/// 实现一致:createV1Tables 建基础表,再 upgrade(db, 1, version) 跑全部迁移。
Future<Database> setupInMemoryDb() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await openDatabase(
    ':memory:',
    version: DatabaseMigrations.currentVersion,
    onCreate: (db, version) async {
      await DatabaseMigrations.createV1Tables(db);
      await DatabaseMigrations.upgrade(db, 1, version);
    },
  );
  return db;
}
```
> in-memory db 每次新建都会触发 `onCreate`,从 v1 跑到 `currentVersion`,迁移全跑一遍。`DatabaseMigrations` 的类名/方法名已核对:`createV1Tables`、`upgrade`、`currentVersion` 均为静态成员。

- [ ] **步骤 4:运行 `flutter pub get` 确认依赖解析**

运行:`flutter pub get`
预期:成功,无版本冲突。

- [ ] **步骤 5:Commit**

```bash
git add novel_app/pubspec.yaml novel_app/test/helpers/in_memory_db.dart
git commit -m "test: 引入 sqflite_common_ffi in-memory 测试基础设施"
```

---

## 任务 1:RelationType 枚举 + AppColors 颜色

**文件:**
- 创建:`novel_app/lib/models/relation_type.dart`
- 修改:`novel_app/lib/core/theme/app_colors.dart`
- 测试:`novel_app/test/unit/models/relation_type_test.dart`

- [ ] **步骤 1:写失败测试**

创建 `novel_app/test/unit/models/relation_type_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/relation_type.dart';

void main() {
  group('RelationType', () {
    test('枚举共有 109 个值', () {
      expect(RelationType.values.length, 109);
    });

    test('forward 与 reverse 非空', () {
      for (final t in RelationType.values) {
        expect(t.forward, isNotEmpty, reason: '$t.forward 为空');
        expect(t.reverse, isNotEmpty, reason: '$t.reverse 为空');
      }
    });

    test('对称类型 forward == reverse', () {
      for (final t in RelationType.values) {
        if (t.symmetric) {
          expect(t.forward, t.reverse, reason: '$t 标记对称但正反词不同');
        }
      }
    });

    test('不对称类型 forward != reverse', () {
      expect(RelationType.masterDisciple.symmetric, isFalse);
      expect(RelationType.masterDisciple.forward, '师父');
      expect(RelationType.masterDisciple.reverse, '徒弟');
      expect(RelationType.friend.symmetric, isTrue);
      expect(RelationType.friend.forward, '朋友');
    });

    test('labelFor 按方向返回词条', () {
      expect(RelationType.masterDisciple.labelFor(isSource: true), '师父');
      expect(RelationType.masterDisciple.labelFor(isSource: false), '徒弟');
    });

    test('颜色非透明', () {
      for (final t in RelationType.values) {
        expect(t.color.alpha, greaterThan(0), reason: '$t.color 透明');
      }
    });

    test('byName 能从字符串还原(用于 DB 读入)', () {
      const name = 'masterDisciple';
      final t = RelationType.values.byName(name);
      expect(t, RelationType.masterDisciple);
    });
  });
}
```

- [ ] **步骤 2:运行测试验证失败**

运行:`flutter test test/unit/models/relation_type_test.dart`
预期:FAIL,`RelationType` 未定义 / `masterDisciple` 未定义。

- [ ] **步骤 3:在 AppColors 加 relation* 颜色字段**

读 `novel_app/lib/core/theme/app_colors.dart`,在 `AppColors` 类的字段区(语义色之后)加一组关系色。颜色值取自词表 `relationship-types-catalog.md` 的"色系总览",按大类各取一个代表色:
```dart
  // ─── 人物关系图连线色(按大类)──────────────────────────────────
  final Color relationBloodDirect;     // 血亲直系 #8B0000
  final Color relationBloodCollateral; // 血亲旁系 #B22222
  final Color relationInLaw;           // 姻亲 #C71585
  final Color relationRomance;         // 婚恋 #FF69B4
  final Color relationMentor;          // 师徒 #663399
  final Color relationPeer;            // 同窗同侪 #4169E1
  final Color relationFriend;          // 朋友 #4169E1
  final Color relationAuthority;       // 权力从属 #DAA520
  final Color relationGrace;           // 恩义 #228B22
  final Color relationRivalry;         // 敌对竞争 #696969
  final Color relationContract;        // 契约 #008B8B
  final Color relationXianxia;         // 修仙玄幻 #9B30FF
  final Color relationReligion;        // 宗教 #FFD700
  final Color relationSciFi;           // 科幻系统 #9370DB
  final Color relationGeo;             // 地缘 #5F9EA0
  final Color relationFate;            // 转世宿命 #9B30FF
  final Color relationAdult;           // 成人向 #4B0082
```
> 同时在 `AppColors` 的 light/dark 工厂构造(或 `copyWith`/`lerp`)里为每个新字段补值。先读文件确认构造方式(通常有 `light()` / `dark()` 静态方法),按现有字段模式补。

> **实施备注:** `AppColors` 当前**已有** 11 个 `graphRelation*` 字段(intimate/family/lover/friend/hostile/hostileDeep/rival/colleague/master/ally/default)。本期**保留旧字段不动**(避免牵连其他使用方),仅新增 `relation*` 字段;两者概念重叠(如 `graphRelationMaster` vs `relationMentor`)留待后续清理。

- [ ] **步骤 4:创建 RelationType 枚举**

创建 `novel_app/lib/models/relation_type.dart`:
```dart
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// 人物关系类型(封闭枚举)。
///
/// 每个值带 [forward](source 视角词)与 [reverse](target 视角词)。
/// 关系 (A->B, type) 表示"A 是 B 的 [forward]";A 出度显示 forward,B 入度显示 reverse。
/// 对称类型 forward == reverse。完整 109 个值见
/// docs/superpowers/specs/relationship-types-catalog.md。
enum RelationType {
  // 1. 血亲·直系
  parentChild('父母', '子女', AppColors.relationBloodDirect, symmetric: false),
  grandparentGrandchild('祖父母', '孙辈', AppColors.relationBloodDirect, symmetric: false),
  greatGrandparentDescendant('曾祖/高祖', '曾孙/玄孙', AppColors.relationBloodDirect, symmetric: false),
  // 2. 血亲·旁系与义亲
  sibling('兄弟姐妹', '兄弟姐妹', AppColors.relationBloodCollateral, symmetric: true),
  // ... half_sibling, cousin, uncle_aunt_nephew, adoptive_parent_child, sworn_family, wet_nurse_child
  // 3. 姻亲与再婚
  // ... spouse, concubine, co_wife, parent_in_law, sibling_in_law, step_parent_child, step_sibling
  // 4. 婚恋情感
  // ... lover, fiance, ex_lover, childhood_sweetheart, secret_admirer, unrequited_love, mistress, rival_in_love
  // 5. 师徒与传承
  masterDisciple('师父', '徒弟', AppColors.relationMentor, symmetric: false),
  // ... grandmaster_disciple, sect_elder_junior, fellow_disciple, same_sect_disciple, teacher_student, mentor_mentee, inheritor_predecessor
  // 6. 同窗同侪
  // ... classmate, schoolmate, senior_junior_student, fellow_exam_candidate, colleague, comrade_in_arms, teammate, companion
  // 7. 朋友知己
  friend('朋友', '朋友', AppColors.relationFriend, symmetric: true),
  // ... close_friend, sworn_sibling, cross_generation_friend
  // 8. 权力从属
  // ... monarch_subject, lord_retainer, sect_leader_member, superior_subordinate, master_servant, employer_employee, employer_mercenary, master_slave, liege_vassal
  // 9. 恩义仇怨
  // ... benefactor_beneficiary, savior_saved, creditor_debtor, enemy, sworn_enemy, blood_feud_enemy, betrayer_betrayed
  // 10. 敌对竞争
  // ... rival, competitor, frienemy, nemesis
  // 11. 契约羁绊
  // ... contract_partner, blood_pact_sibling, soul_contract_master, master_contract_beast, beast_partner, summoner_summon, familiar_master
  // 12. 修仙玄幻特殊
  // ... dao_companion, dual_cultivation_partner, avatar_main_body, inner_demon_host, symbiote, bloodline_ancestor_descendant, artifact_spirit_master, possessor_host
  // 13. 宗教信仰
  // ... deity_believer, deity_chosen, cult_leader_believer, prophet_followers
  // 14. 科幻与系统流特殊
  // ... creator_creation, linked_minds, ai_owner, system_host, puppeteer_puppet
  // 15. 地缘与其他
  // ... hometown_tie, neighbor, doctor_patient, guild_leader_member, faction_ally
  // 16. 转世宿命
  // ... reincarnation_predecessor, fated_lover, fated_enemy
  // 17. 情色·奴役·占有(成人向,暗色系)
  // ... sex_slave_master, paramour, male_favorite, cauldron_cultivator, forbidden_possession, plaything_player, captive_captor, prey_predator, master_slave_sm, trainer_trainee, shared_partner, usurper_victim
  ;

  final String forward;
  final String reverse;
  final Color color;
  final bool symmetric;

  const RelationType(this.forward, this.reverse, this.color, {required this.symmetric});

  /// 按方向返回词条:[isSource] 为 true 返回正向词,否则反向词。
  String labelFor({required bool isSource}) => isSource ? forward : reverse;
}
```
> **关键:** 上面只展开了 4 个示例值。执行时**必须**对照 `docs/superpowers/specs/relationship-types-catalog.md` 的 17 大类表格,把全部 109 个值补全(每个值的 forward/reverse/color/symmetric 严格按词表)。注释里列出了每个大类应包含的 key 名。颜色按词表"色系总览"映射到对应的 `AppColors.relation*` 字段。完成后 `RelationType.values.length` 必须等于 109。

- [ ] **步骤 5:运行测试验证通过**

运行:`flutter test test/unit/models/relation_type_test.dart`
预期:PASS(7 个测试全过)。若"枚举共有 109 个值"失败,说明值没补全。

- [ ] **步骤 6:Commit**

```bash
git add novel_app/lib/models/relation_type.dart novel_app/lib/core/theme/app_colors.dart novel_app/test/unit/models/relation_type_test.dart
git commit -m "feat: 新增 RelationType 封闭枚举(109 个关系类型)与关系色"
```

---

## 任务 2:CharacterRelationship v2 model

**文件:**
- 修改:`novel_app/lib/models/character_relationship.dart`
- 修改:`novel_app/test/test_helpers/character_relationship_test_data.dart`
- 测试:`novel_app/test/unit/models/character_relationship_test.dart`

- [ ] **步骤 1:写失败测试**

创建 `novel_app/test/unit/models/character_relationship_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/character_relationship.dart';
import 'package:novel_app/models/relation_type.dart';

void main() {
  group('CharacterRelationship v2', () {
    test('toMap 包含全部新字段', () {
      final r = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationType: RelationType.masterDisciple,
        strength: 4,
        startChapter: 8,
        endChapter: null,
        novelUrl: 'novel_a',
      );
      final m = r.toMap();
      expect(m['relation_type'], 'masterDisciple');
      expect(m['strength'], 4);
      expect(m['start_chapter'], 8);
      expect(m['end_chapter'], isNull);
      expect(m['novel_url'], 'novel_a');
    });

    test('strength 默认为 3', () {
      final r = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationType: RelationType.friend,
        startChapter: 0,
        novelUrl: 'novel_a',
      );
      expect(r.strength, 3);
    });

    test('fromMap 还原枚举', () {
      final m = {
        'id': 1,
        'source_character_id': 1,
        'target_character_id': 2,
        'relation_type': 'masterDisciple',
        'strength': 5,
        'start_chapter': 8,
        'end_chapter': 50,
        'description': '拜师',
        'novel_url': 'novel_a',
        'created_at': 0,
        'updated_at': null,
      };
      final r = CharacterRelationship.fromMap(m);
      expect(r.relationType, RelationType.masterDisciple);
      expect(r.strength, 5);
      expect(r.endChapter, 50);
    });

    test('fromMap 非法枚举名抛异常', () {
      final m = {
        'source_character_id': 1,
        'target_character_id': 2,
        'relation_type': 'not_a_real_type',
        'strength': 3,
        'start_chapter': 0,
        'novel_url': 'novel_a',
        'created_at': 0,
      };
      expect(() => CharacterRelationship.fromMap(m), throwsA(isA<StateError>()));
    });

    test('copyWith 更新 endChapter', () {
      final r = CharacterRelationship(
        sourceCharacterId: 1, targetCharacterId: 2,
        relationType: RelationType.friend, startChapter: 0, novelUrl: 'n');
      final r2 = r.copyWith(endChapter: 79);
      expect(r2.endChapter, 79);
      expect(r2.sourceCharacterId, 1);
    });
  });
}
```

- [ ] **步骤 2:运行测试验证失败**

运行:`flutter test test/unit/models/character_relationship_test.dart`
预期:FAIL(旧 model 无 `relationType`/`strength`/`startChapter` 等字段)。

- [ ] **步骤 3:重做 model**

完全重写 `novel_app/lib/models/character_relationship.dart`:
```dart
import 'relation_type.dart';

/// 角色关系 v2(区间模型)。
///
/// 关系 (source -> target, relationType) 表示"A 是 B 的 [relationType.forward]"。
/// [startChapter]/[endChapter] 为章节 index(0-based),定义关系生效区间。
class CharacterRelationship {
  final int? id;
  final int sourceCharacterId;
  final int targetCharacterId;
  final RelationType relationType;
  final int strength;          // 1-5,默认 3
  final int startChapter;      // 0-based,必填
  final int? endChapter;       // 0-based,可空=持续至今
  final String? description;
  final String novelUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CharacterRelationship({
    this.id,
    required this.sourceCharacterId,
    required this.targetCharacterId,
    required this.relationType,
    this.strength = 3,
    required this.startChapter,
    this.endChapter,
    this.description,
    required this.novelUrl,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'source_character_id': sourceCharacterId,
        'target_character_id': targetCharacterId,
        'relation_type': relationType.name,
        'strength': strength,
        'start_chapter': startChapter,
        'end_chapter': endChapter,
        'description': description,
        'novel_url': novelUrl,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt?.millisecondsSinceEpoch,
      };

  factory CharacterRelationship.fromMap(Map<String, dynamic> map) {
    return CharacterRelationship(
      id: map['id']?.toInt(),
      sourceCharacterId: map['source_character_id'] as int,
      targetCharacterId: map['target_character_id'] as int,
      relationType: RelationType.values.byName(map['relation_type'] as String),
      strength: (map['strength'] as int?) ?? 3,
      startChapter: map['start_chapter'] as int,
      endChapter: map['end_chapter'] as int?,
      description: map['description'] as String?,
      novelUrl: map['novel_url'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : null,
    );
  }

  CharacterRelationship copyWith({
    int? id,
    int? sourceCharacterId,
    int? targetCharacterId,
    RelationType? relationType,
    int? strength,
    int? startChapter,
    int? endChapter,
    String? description,
    String? novelUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      CharacterRelationship(
        id: id ?? this.id,
        sourceCharacterId: sourceCharacterId ?? this.sourceCharacterId,
        targetCharacterId: targetCharacterId ?? this.targetCharacterId,
        relationType: relationType ?? this.relationType,
        strength: strength ?? this.strength,
        startChapter: startChapter ?? this.startChapter,
        endChapter: endChapter ?? this.endChapter,
        description: description ?? this.description,
        novelUrl: novelUrl ?? this.novelUrl,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  @override
  String toString() =>
      'CharacterRelationship($sourceCharacterId->${targetCharacterId}, ${relationType.name}, §$startChapter-${endChapter ?? "∞"})';
}
```
> 注意 `copyWith` 里 `endChapter` 的 `?? this.endChapter` 会让"设回 null"无法表达--区间模型里关系通常只从 null 变为有值,可接受;若需显式清空,执行时另加 `endChapter` 的 sentinel 处理。

- [ ] **步骤 4:更新测试数据 helper**

重写 `novel_app/test/test_helpers/character_relationship_test_data.dart` 以适配新 model(把 `String type` 改为 `RelationType relationType`,加 `startChapter`/`novelUrl`/`strength` 参数,删除旧的 `reverseRelationshipTypes` 常量)。保留 `createTestCharacter`、`createCharacterMap` 等不涉及旧关系字段的辅助方法。

- [ ] **步骤 5:运行测试验证通过**

运行:`flutter test test/unit/models/character_relationship_test.dart`
预期:PASS。

- [ ] **步骤 6:确认存量测试不被破坏**

运行:`flutter test test/unit/repositories/character_repository_test.dart test/verification/relationship_feature_verification.dart`
预期:`character_repository_test.dart` PASS;`relationship_feature_verification.dart` 若引用旧 model 字段会编译失败--修复其引用(改为 `relationType`/`startChapter` 等)或在计划本任务内同步更新。

- [ ] **步骤 7:Commit**

```bash
git add novel_app/lib/models/character_relationship.dart novel_app/test/test_helpers/character_relationship_test_data.dart novel_app/test/unit/models/character_relationship_test.dart
git commit -m "refactor: CharacterRelationship 重做为区间模型(枚举+强度+起止章节)"
```

---

## 任务 3:Character 加 firstAppearanceChapter

**文件:**
- 修改:`novel_app/lib/models/character.dart`
- 测试:`novel_app/test/unit/repositories/character_repository_test.dart`(沿用)+ 可能新增 `character_model_test.dart`

- [ ] **步骤 1:写失败测试**

新增 `novel_app/test/unit/models/character_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/character.dart';

void main() {
  test('firstAppearanceChapter 进出 toMap/fromMap', () {
    final c = Character(novelUrl: 'n', name: '甲', firstAppearanceChapter: 8);
    final m = c.toMap();
    expect(m['firstAppearanceChapter'], 8);
    final c2 = Character.fromMap({
      'id': 1, 'novelUrl': 'n', 'name': '甲',
      'firstAppearanceChapter': 8, 'createdAt': 0,
    });
    expect(c2.firstAppearanceChapter, 8);
  });

  test('firstAppearanceChapter 默认 null(视为 §0 登场)', () {
    final c = Character(novelUrl: 'n', name: '甲');
    expect(c.firstAppearanceChapter, isNull);
  });
}
```

- [ ] **步骤 2:运行测试验证失败**

运行:`flutter test test/unit/models/character_test.dart`
预期:FAIL(`firstAppearanceChapter` 未定义)。

- [ ] **步骤 3:在 Character 加字段**

在 `novel_app/lib/models/character.dart`:
- 字段区加 `final int? firstAppearanceChapter; // 登场章节(0-based index),空=视为§0登场`
- 构造函数加 `this.firstAppearanceChapter,`
- `toMap` 加 `'firstAppearanceChapter': firstAppearanceChapter,`
- `fromMap` 加 `firstAppearanceChapter: map['firstAppearanceChapter'] as int?,`
- `copyWith` 加 `int? firstAppearanceChapter,` 参数与 `firstAppearanceChapter: firstAppearanceChapter ?? this.firstAppearanceChapter,`

- [ ] **步骤 4:运行测试验证通过**

运行:`flutter test test/unit/models/character_test.dart`
预期:PASS。

- [ ] **步骤 5:Commit**

```bash
git add novel_app/lib/models/character.dart novel_app/test/unit/models/character_test.dart
git commit -m "feat: Character 加 firstAppearanceChapter(登场章节)"
```

---

## 任务 4:数据库迁移 case 35

**文件:**
- 修改:`novel_app/lib/core/database/database_migrations.dart`
- 测试:`novel_app/test/unit/database/migration_v35_test.dart`

- [ ] **步骤 1:写失败测试**

创建 `novel_app/test/unit/database/migration_v35_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import '../../helpers/in_memory_db.dart';
import 'package:novel_app/core/database/database_migrations.dart';

void main() {
  late Database db;
  setUp(() async { db = await setupInMemoryDb(); });
  tearDown(() async => db.close());

  test('currentVersion 为 35', () {
    expect(DatabaseMigrations.currentVersion, 35);
  });

  test('character_relationships 表有全部新列', () async {
    final cols = await db.rawQuery('PRAGMA table_info(character_relationships)');
    final names = cols.map((c) => c['name']).toSet();
    for (final n in [
      'relation_type', 'strength', 'start_chapter', 'end_chapter',
      'description', 'novel_url'
    ]) {
      expect(names, contains(n), reason: '缺列 $n');
    }
  });

  test('characters 表有 firstAppearanceChapter 列', () async {
    final cols = await db.rawQuery('PRAGMA table_info(characters)');
    expect(cols.map((c) => c['name']), contains('firstAppearanceChapter'));
  });

  test('唯一约束生效:同对人同章同类型不重复', () async {
    await db.insert('characters', {'novelUrl': 'n', 'name': '甲', 'createdAt': 0});
    await db.insert('characters', {'novelUrl': 'n', 'name': '乙', 'createdAt': 0});
    final rel = {
      'source_character_id': 1, 'target_character_id': 2,
      'relation_type': 'friend', 'strength': 3, 'start_chapter': 0,
      'novel_url': 'n', 'created_at': 0,
    };
    await db.insert('character_relationships', rel);
    expect(() => db.insert('character_relationships', rel), throwsA(isA<Object>()));
  });
}
```
> 若 `DatabaseMigrations` 类名不符,先读 `database_migrations.dart` 头部确认。

- [ ] **步骤 2:运行测试验证失败**

运行:`flutter test test/unit/database/migration_v35_test.dart`
预期:FAIL(`currentVersion` 是 34,新列不存在)。

- [ ] **步骤 3:加 case 35**

在 `novel_app/lib/core/database/database_migrations.dart`:
1. 第 14 行 `static const int currentVersion = 34;` → `35`
2. 在 `case 34:` 的 `break;` 之后、下一个 `case`(无下一个则 `_migrateToVersion` 函数闭合 `}`)之前加:
```dart
      // ========== 版本 35：人物关系图重设计 ==========
      // character_relationships 重建为区间模型（旧表从未被 UI 使用,空表）；
      // characters 加 firstAppearanceChapter（登场章节）。
      case 35:
        await db.execute('DROP TABLE IF EXISTS character_relationships');
        await db.execute('''
        CREATE TABLE character_relationships (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          source_character_id INTEGER NOT NULL,
          target_character_id INTEGER NOT NULL,
          relation_type TEXT NOT NULL,
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
        )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_rel_source ON character_relationships(source_character_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_rel_target ON character_relationships(target_character_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_rel_novel_chapter ON character_relationships(novel_url, start_chapter, end_chapter)');
        await _addColumnIfNotExists(db, 'characters', 'firstAppearanceChapter', 'INTEGER');
        _log('迁移 v34 -> v35: 重建 character_relationships 为区间模型, characters 加 firstAppearanceChapter');
        break;
```

- [ ] **步骤 4:运行测试验证通过**

运行:`flutter test test/unit/database/migration_v35_test.dart`
预期:PASS。

- [ ] **步骤 5:Commit**

```bash
git add novel_app/lib/core/database/database_migrations.dart novel_app/test/unit/database/migration_v35_test.dart
git commit -m "feat: 数据库 v35 重建 character_relationships 为区间模型"
```

---

## 任务 5:ICharacterRelationRepository 接口重做

**文件:**
- 修改:`novel_app/lib/core/interfaces/repositories/i_character_relation_repository.dart`

- [ ] **步骤 1:重写接口**

完全重写 `i_character_relation_repository.dart`:
```dart
import '../../../models/character_relationship.dart';
import '../../../models/relationship_graph_snapshot.dart';

/// 人物关系仓库接口(v2,区间模型 + 章节快照)。
abstract class ICharacterRelationRepository {
  /// 创建关系。校验:startChapter>=0、endChapter>=startChapter、对称类型去重。
  Future<int> createRelationship(CharacterRelationship relationship);

  /// 更新关系(必须含 id)。
  Future<int> updateRelationship(CharacterRelationship relationship);

  /// 删除关系。
  Future<int> deleteRelationship(int relationshipId);

  /// 取小说在指定章节的关系图快照:已登场人物 + 当前生效关系。
  Future<RelationshipGraphSnapshot> getGraphSnapshot(String novelUrl, int chapter);

  /// 取小说的全部关系(全部章节,用于编辑/管理)。
  Future<List<CharacterRelationship>> getAllRelationships(String novelUrl);
}
```

- [ ] **步骤 2:创建快照 model**

创建 `novel_app/lib/models/relationship_graph_snapshot.dart`:
```dart
import 'character.dart';
import 'character_relationship.dart';

/// 关系图在某章节的快照。
class RelationshipGraphSnapshot {
  final List<Character> characters;
  final List<CharacterRelationship> relationships;
  final int chapter;
  const RelationshipGraphSnapshot({
    required this.characters,
    required this.relationships,
    required this.chapter,
  });
}
```

- [ ] **步骤 3:编译确认**

运行:`flutter analyze lib/core/interfaces/repositories/i_character_relation_repository.dart lib/models/relationship_graph_snapshot.dart`
预期:无错误。

- [ ] **步骤 4:Commit**

```bash
git add novel_app/lib/core/interfaces/repositories/i_character_relation_repository.dart novel_app/lib/models/relationship_graph_snapshot.dart
git commit -m "refactor: ICharacterRelationRepository 接口重做(章节快照)"
```

---

## 任务 6:CharacterRelationRepository 实现

**文件:**
- 修改:`novel_app/lib/repositories/character_relation_repository.dart`
- 测试:`novel_app/test/unit/repositories/character_relation_repository_test.dart`

- [ ] **步骤 1:写失败测试**

创建 `novel_app/test/unit/repositories/character_relation_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import '../../helpers/in_memory_db.dart';
import 'package:novel_app/repositories/character_relation_repository.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_relationship.dart';
import 'package:novel_app/models/relation_type.dart';

void main() {
  late Database db;
  late CharacterRelationRepository repo;

  setUp(() async {
    db = await setupInMemoryDb();
    repo = CharacterRelationRepository(dbConnection: _Conn(db));
    // 造 3 个角色:甲(§0)、乙(§8)、丙(§45)
    await db.insert('characters', {'novelUrl': 'n', 'name': '甲', 'firstAppearanceChapter': 0, 'createdAt': 0});
    await db.insert('characters', {'novelUrl': 'n', 'name': '乙', 'firstAppearanceChapter': 8, 'createdAt': 0});
    await db.insert('characters', {'novelUrl': 'n', 'name': '丙', 'firstAppearanceChapter': 45, 'createdAt': 0});
  });
  tearDown(() async => db.close());

  test('§0 快照:只有甲登场,无关系', () async {
    final snap = await repo.getGraphSnapshot('n', 0);
    expect(snap.characters.map((c) => c.name), ['甲']);
    expect(snap.relationships, isEmpty);
  });

  test('§8 快照:甲乙登场,师徒关系生效', () async {
    await repo.createRelationship(CharacterRelationship(
      sourceCharacterId: 1, targetCharacterId: 2,
      relationType: RelationType.masterDisciple, startChapter: 8, novelUrl: 'n'));
    final snap = await repo.getGraphSnapshot('n', 8);
    expect(snap.characters.map((c) => c.name), containsAll(['甲', '乙']));
    expect(snap.relationships.length, 1);
    expect(snap.relationships.first.relationType, RelationType.masterDisciple);
  });

  test('区间重叠:朋友 §25-79 / 恋人 §80+,§50 取朋友、§80 取恋人', () async {
    await repo.createRelationship(CharacterRelationship(
      sourceCharacterId: 1, targetCharacterId: 3, relationType: RelationType.friend,
      startChapter: 25, endChapter: 79, novelUrl: 'n'));
    await repo.createRelationship(CharacterRelationship(
      sourceCharacterId: 1, targetCharacterId: 3, relationType: RelationType.lover,
      startChapter: 80, novelUrl: 'n'));
    expect((await repo.getGraphSnapshot('n', 50)).relationships.single.relationType, RelationType.friend);
    expect((await repo.getGraphSnapshot('n', 80)).relationships.single.relationType, RelationType.lover);
  });

  test('校验:startChapter<0 拒绝', () async {
    expect(
      () => repo.createRelationship(CharacterRelationship(
        sourceCharacterId: 1, targetCharacterId: 2,
        relationType: RelationType.friend, startChapter: -1, novelUrl: 'n')),
      throwsA(isA<ArgumentError>()));
  });

  test('校验:endChapter<startChapter 拒绝', () async {
    expect(
      () => repo.createRelationship(CharacterRelationship(
        sourceCharacterId: 1, targetCharacterId: 2,
        relationType: RelationType.friend, startChapter: 10, endChapter: 5, novelUrl: 'n')),
      throwsA(isA<ArgumentError>()));
  });

  test('对称关系去重:(A,B,friend) 与 (B,A,friend) 视为已存在', () async {
    await repo.createRelationship(CharacterRelationship(
      sourceCharacterId: 1, targetCharacterId: 2, relationType: RelationType.friend,
      startChapter: 0, novelUrl: 'n'));
    // 反向再建应抛错(唯一约束或显式检查)
    expect(
      () => repo.createRelationship(CharacterRelationship(
        sourceCharacterId: 2, targetCharacterId: 1, relationType: RelationType.friend,
        startChapter: 0, novelUrl: 'n')),
      throwsA(isA<Object>()));
  });

  test('级联删除:删角色连带删关系', () async {
    await repo.createRelationship(CharacterRelationship(
      sourceCharacterId: 1, targetCharacterId: 2, relationType: RelationType.friend,
      startChapter: 0, novelUrl: 'n'));
    await db.delete('characters', where: 'id = ?', whereArgs: [1]);
    final snap = await repo.getGraphSnapshot('n', 99);
    expect(snap.relationships, isEmpty);
  });
}

class _Conn implements IDatabaseConnection {
  final Database db;
  _Conn(this.db);
  @override
  Future<Database> get database => Future.value(db);
  // 其余 IDatabaseConnection 成员按接口实现(若接口方法多,可生成 mock)
}
```
> 执行前先读 `core/interfaces/i_database_connection.dart` 确认 `IDatabaseConnection` 的成员,补全 `_Conn` 实现(或改用 `MockIDatabaseConnection` + `when(mock.database).thenAnswer((_) async => db)`)。推荐后者(mockito 模式与项目现有测试一致)。

- [ ] **步骤 2:运行测试验证失败**

运行:`flutter test test/unit/repositories/character_relation_repository_test.dart`
预期:FAIL(旧实现无 `getGraphSnapshot`/新校验)。

- [ ] **步骤 3:重写 repository**

完全重写 `novel_app/lib/repositories/character_relation_repository.dart`,实现新接口:
- `createRelationship`:先校验 `startChapter >= 0`、`endChapter == null || endChapter >= startChapter`,否则抛 `ArgumentError`;对称类型(`relationType.symmetric`)在插入前查重(双向 source/target 都查);`db.insert(..., conflictAlgorithm: ConflictAlgorithm.abort)`。
- `getGraphSnapshot(novelUrl, chapter)`:
  ```dart
  final chars = await db.query('characters',
      where: "novelUrl = ? AND (firstAppearanceChapter IS NULL OR firstAppearanceChapter <= ?)",
      whereArgs: [novelUrl, chapter], orderBy: 'createdAt ASC');
  final rels = await db.query('character_relationships',
      where: "novel_url = ? AND start_chapter <= ? AND (end_chapter IS NULL OR end_chapter >= ?)",
      whereArgs: [novelUrl, chapter, chapter], orderBy: 'created_at DESC');
  return RelationshipGraphSnapshot(
    characters: chars.map(Character.fromMap).toList(),
    relationships: rels.map(CharacterRelationship.fromMap).toList(),
    chapter: chapter,
  );
  ```
- `updateRelationship`/`deleteRelationship`/`getAllRelationships`:沿用旧实现模式,字段改为新 toMap。
- 保持 `LoggerService` 日志风格(参考旧实现的 try/catch + LoggerService.instance.e/i)。

- [ ] **步骤 4:运行测试验证通过**

运行:`flutter test test/unit/repositories/character_relation_repository_test.dart`
预期:PASS(7 个测试)。

- [ ] **步骤 5:Commit**

```bash
git add novel_app/lib/repositories/character_relation_repository.dart novel_app/test/unit/repositories/character_relation_repository_test.dart
git commit -m "feat: CharacterRelationRepository 实现区间模型 + 章节快照查询"
```

---

## 任务 7:relationship_graph_providers

**文件:**
- 创建:`novel_app/lib/core/providers/relationship_graph_providers.dart`
- 测试:`novel_app/test/unit/providers/relationship_graph_providers_test.dart`

- [ ] **步骤 1:写失败测试**

创建 `novel_app/test/unit/providers/relationship_graph_providers_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/core/providers/relationship_graph_providers.dart';
// 用 mockito 覆盖 characterRelationRepositoryProvider 与 novelRepositoryProvider,
// 验证 relationshipGraphProvider(novelUrl, chapter) 调用 getGraphSnapshot 并返回快照。
// 参考 test/unit/repositories/*_test.mocks.dart 的 @GenerateMocks 模式。

void main() {
  test('relationshipGraphProvider 调用 getGraphSnapshot', () async {
    // 1. MockINovelRepository.getLastReadChapter 返回 8
    // 2. MockICharacterRelationRepository.getGraphSnapshot('n', 8) 返回构造快照
    // 3. expect(relationshipGraphProvider('n', 8) 的 AsyncValue.data, 快照)
  });

  test('currentChapterProvider 默认取 getLastReadChapter', () async {
    // mock novelRepository.getLastReadChapter('n') => 8
    // expect(currentChapterProvider('n'), 8)
  });
}
```
> 执行时按项目 mockito 模式补全(mock 两个 repository provider)。若 Provider 用 riverpod_annotation,需先跑 build_runner 生成 `.g.dart`。

- [ ] **步骤 2:运行测试验证失败**

运行:`flutter test test/unit/providers/relationship_graph_providers_test.dart`
预期:FAIL(provider 未定义)。

- [ ] **步骤 3:创建 providers**

创建 `novel_app/lib/core/providers/relationship_graph_providers.dart`:
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/relationship_graph_snapshot.dart';
import 'database_providers.dart';

part 'relationship_graph_providers.g.dart';

/// 当前章节进度(0-based index)。默认取阅读进度,可被滑块覆盖。
@riverpod
Future<int> currentChapter(Ref ref, String novelUrl) async {
  final novelRepo = ref.watch(novelRepositoryProvider);
  return novelRepo.getLastReadChapter(novelUrl);
}

/// 关系图快照(按小说 + 章节)。
@riverpod
Future<RelationshipGraphSnapshot> relationshipGraph(
    Ref ref, String novelUrl, int chapter) async {
  final relationRepo = ref.watch(characterRelationRepositoryProvider);
  return relationRepo.getGraphSnapshot(novelUrl, chapter);
}
```

- [ ] **步骤 4:跑 build_runner 生成 .g.dart**

运行:`dart run build_runner build --delete-conflicting-outputs`
预期:成功生成 `relationship_graph_providers.g.dart`。

- [ ] **步骤 5:运行测试验证通过**

运行:`flutter test test/unit/providers/relationship_graph_providers_test.dart`
预期:PASS。

- [ ] **步骤 6:Commit**

```bash
git add novel_app/lib/core/providers/relationship_graph_providers.dart novel_app/lib/core/providers/relationship_graph_providers.g.dart novel_app/test/unit/providers/relationship_graph_providers_test.dart
git commit -m "feat: 新增关系图 Provider(章节快照 + 当前章节)"
```

---

## 任务 8:RelationshipGraphScreen + 时间轴滑块 UI

**文件:**
- 创建:`novel_app/lib/widgets/relationship/timeline_chapter_slider.dart`
- 创建:`novel_app/lib/screens/relationship_graph_screen.dart`
- 测试:`novel_app/test/widget/relationship_graph_screen_test.dart`

> **力导向图 API:** `flutter_force_directed_graph: ^1.0.8` 已在 pubspec。执行时先读包 README(pub.dev 或 `.dart_tool` 里的包源码)确认 `ForceDirectedGraph` widget 的入参(graph/node/edge builder)。下面给出框架,按实际 API 调整。

- [ ] **步骤 1:写 widget 测试(渲染 + 滑块)**

创建 `novel_app/test/widget/relationship_graph_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/screens/relationship_graph_screen.dart';

void main() {
  testWidgets('页面渲染:显示章节滑块与图区域', (tester) async {
    // 用 ProviderScope override 注入 mock repositories,返回固定快照
    // await tester.pumpWidget(ProviderScope(overrides: [...], child: MaterialApp(home: RelationshipGraphScreen(novelUrl: 'n'))));
    // expect(find.byType(Slider), findsOneWidget);
    // expect(当前章节文本, '第 1 章');
  });

  testWidgets('拖动滑块更新当前章节显示', (tester) async {
    // 拖动 Slider 到 50%,验证章节文本变为 '第 N 章'
  });
}
```
> 执行时补全 override 与断言。

- [ ] **步骤 2:运行测试验证失败**

运行:`flutter test test/widget/relationship_graph_screen_test.dart`
预期:FAIL(screen 未定义)。

- [ ] **步骤 3:创建滑块 widget**

创建 `novel_app/lib/widgets/relationship/timeline_chapter_slider.dart`:一个 `StatelessWidget`,接收 `int maxChapter`、`int chapter`、`ValueChanged<int> onChanged`,渲染 `Slider(min:0, max:maxChapter-1, value:chapter, onChanged)` + 上方"第 ${chapter+1} 章"文本 + 下方进度条样式。debounce(~150ms)在父层处理。

- [ ] **步骤 4:创建关系图页面**

创建 `novel_app/lib/screens/relationship_graph_screen.dart`:
```dart
class RelationshipGraphScreen extends ConsumerStatefulWidget {
  final String novelUrl;
  const RelationshipGraphScreen({super.key, required this.novelUrl});
  @override
  ConsumerState<RelationshipGraphScreen> createState() => _RelationshipGraphScreenState();
}

class _RelationshipGraphScreenState extends ConsumerState<RelationshipGraphScreen> {
  int? _chapterOverride;  // 滑块手动覆盖值

  @override
  Widget build(BuildContext context) {
    final chapterAsync = ref.watch(currentChapterProvider(widget.novelUrl));
    return Scaffold(
      appBar: AppBar(title: const Text('人物关系图')),
      body: chapterAsync.when(
        loading: () => const CircularProgressIndicator(),
        error: (e, _) => Text('加载失败: $e'),
        data: (defaultChapter) {
          final chapter = _chapterOverride ?? defaultChapter;
          final snapAsync = ref.watch(relationshipGraphProvider(widget.novelUrl, chapter));
          return Column(children: [
            TimelineChapterSlider(
              maxChapter: /* 章节总数,优先 chapterRepository.getChapterCount(novelUrl) 或 getChapters().length;若该 API 不存在,用 snap 中 max(start_chapter)+1 兜底 */,
              chapter: chapter,
              onChanged: (v) => setState(() => _chapterOverride = v),  // 加 debounce
            ),
            Expanded(child: snapAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('加载失败: $e'),
              data: (snap) => _buildGraph(snap),
            )),
          ]);
        },
      ),
    );
  }

  Widget _buildGraph(snapshot) {
    // 用 flutter_force_directed_graph 的 ForceDirectedGraph:
    //  节点 = snapshot.characters,显示 name
    //  边 = snapshot.relationships,颜色 = relationType.color,线宽 = strength
    //  不对称关系带箭头,对称无箭头
    //  边标签 = relationType.labelFor(isSource: ...) -- 由节点角色决定方向
    // 按 ForceDirectedGraph 实际 API 构造,参考包 README
    return ForceDirectedGraph(/* ... */);
  }
}
```

- [ ] **步骤 5:运行测试验证通过**

运行:`flutter test test/widget/relationship_graph_screen_test.dart`
预期:PASS。

- [ ] **步骤 6:Commit**

```bash
git add novel_app/lib/widgets/relationship/timeline_chapter_slider.dart novel_app/lib/screens/relationship_graph_screen.dart novel_app/test/widget/relationship_graph_screen_test.dart
git commit -m "feat: 人物关系图页面(力导向图 + 章节时间轴滑块)"
```

---

## 任务 9:入口接入 + 全量验证

**文件:**
- 修改:`novel_app/lib/screens/character_list_screen.dart`

- [ ] **步骤 1:加入口**

在 `character_list_screen.dart` 的 AppBar actions(或列表头部)加一个"关系图"按钮:
```dart
IconButton(
  icon: const Icon(Icons.account_tree),
  onPressed: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => RelationshipGraphScreen(novelUrl: novelUrl),
  )),
),
```
> 先读 `character_list_screen.dart` 确认 `novelUrl` 在该页面的取法(可能是 widget 参数或 provider),按实际接入。

- [ ] **步骤 2:生成 Provider 代码(若任务7未跑或本次有改动)**

运行:`dart run build_runner build --delete-conflicting-outputs`

- [ ] **步骤 3:静态分析全量**

运行:`flutter analyze`
预期:无错误(warning 可接受但应尽量清零)。

- [ ] **步骤 4:全量测试**

运行:`flutter test`
预期:全部 PASS。若有存量测试因 model 重做失败,在本计划任务范围内修复(主要在任务 2 已处理;剩余的按报错修)。

- [ ] **步骤 5:手测(可选,若环境允许)**

运行 app,进入某小说的角色列表,点"关系图"按钮,拖动章节滑块,确认人物/关系随章节变化。

- [ ] **步骤 6:Commit**

```bash
git add novel_app/lib/screens/character_list_screen.dart
git commit -m "feat: 角色列表页接入人物关系图入口"
```

---

## 完成标准

- [ ] `RelationType` 有 109 个值,单测全过
- [ ] `CharacterRelationship` v2 区间模型,单测全过
- [ ] `Character.firstAppearanceChapter` 字段就位
- [ ] 数据库迁移到 v35,迁移测试全过
- [ ] `CharacterRelationRepository.getGraphSnapshot` 按章节过滤正确,7 个场景测试全过
- [ ] `relationshipGraphProvider`/`currentChapterProvider` 工作正常
- [ ] `RelationshipGraphScreen` 渲染力导向图 + 章节滑块,widget 测试全过
- [ ] 角色列表页有"关系图"入口
- [ ] `flutter analyze` 无错误
- [ ] `flutter test` 全过
