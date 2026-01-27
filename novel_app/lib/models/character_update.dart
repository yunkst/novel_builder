import 'character.dart';

/// 角色更新包装类
///
/// 包含新旧角色信息,用于判断新增/更新状态和计算字段差异
class CharacterUpdate {
  final Character newCharacter;
  final Character? oldCharacter;

  /// 缓存的差异计算结果
  List<FieldDiff>? _cachedDiffs;

  CharacterUpdate({
    required this.newCharacter,
    this.oldCharacter,
  });

  /// 是否为新增角色
  bool get isNew => oldCharacter == null;

  /// 是否为更新角色
  bool get isUpdate => oldCharacter != null;

  /// 获取字段差异列表(带缓存)
  List<FieldDiff> getDifferences() {
    return _cachedDiffs ??= _computeDifferences();
  }

  /// 计算字段差异
  List<FieldDiff> _computeDifferences() {
    if (isNew) return [];

    final diffs = <FieldDiff>[];
    final oldChar = oldCharacter!;
    final newChar = newCharacter;

    // 对比所有可能变化的字段
    _addDiff(diffs, '年龄', _formatAge(oldChar.age), _formatAge(newChar.age));
    _addDiff(diffs, '性别', oldChar.gender, newChar.gender);
    _addDiff(diffs, '职业', oldChar.occupation, newChar.occupation);
    _addDiff(diffs, '性格', oldChar.personality, newChar.personality);
    _addDiff(diffs, '体型', oldChar.bodyType, newChar.bodyType);
    _addDiff(diffs, '着装', oldChar.clothingStyle, newChar.clothingStyle);
    _addDiff(diffs, '外貌', oldChar.appearanceFeatures, newChar.appearanceFeatures);
    _addDiff(diffs, '背景', oldChar.backgroundStory, newChar.backgroundStory);

    return diffs.where((d) => d.hasChanged).toList();
  }

  void _addDiff(List<FieldDiff> diffs, String label, String? oldVal, String? newVal) {
    if (oldVal != newVal) {
      diffs.add(FieldDiff(
        label: label,
        oldValue: oldVal,
        newValue: newVal,
      ));
    }
  }

  String? _formatAge(int? age) => age != null ? '$age岁' : null;
}

/// 字段差异类
///
/// 表示单个字段的新旧值对比
class FieldDiff {
  final String label;
  final String? oldValue;
  final String? newValue;

  const FieldDiff({
    required this.label,
    this.oldValue,
    this.newValue,
  });

  /// 是否有变化
  bool get hasChanged => oldValue != newValue;

  /// 是否为新增字段(old为null)
  bool get isNewField => oldValue == null && newValue != null;

  /// 是否为删除字段(new为null)
  bool get isDeletedField => oldValue != null && newValue == null;
}
