# CharacterRepository 方法清单

本文档列出了从 `database_service.dart` 中提取到 `CharacterRepository` 的所有角色相关方法。

## 提取的方法总览

总共提取了 **32 个方法**，分为以下几类：
- 角色CRUD操作：15个方法
- 角色图片管理：6个方法
- 角色关系CRUD操作：11个方法

---

## 一、角色CRUD操作（15个方法）

### 1. createCharacter
**功能**：创建角色
**原方法**：`DatabaseService.createCharacter`
**签名**：`Future<int> createCharacter(Character character)`
**说明**：插入新角色到数据库，返回新记录的ID

### 2. getCharacters
**功能**：获取小说的所有角色
**原方法**：`DatabaseService.getCharacters`
**签名**：`Future<List<Character>> getCharacters(String novelUrl)`
**说明**：返回按创建时间升序排列的角色列表

### 3. getCharacter
**功能**：根据ID获取角色
**原方法**：`DatabaseService.getCharacter`
**签名**：`Future<Character?> getCharacter(int id)`
**说明**：返回指定ID的角色，不存在则返回null

### 4. updateCharacter
**功能**：更新角色
**原方法**：`DatabaseService.updateCharacter`
**签名**：`Future<int> updateCharacter(Character character)`
**说明**：更新角色信息，自动更新updatedAt字段

### 5. deleteCharacter
**功能**：删除角色
**原方法**：`DatabaseService.deleteCharacter`
**签名**：`Future<int> deleteCharacter(int id)`
**说明**：删除指定ID的角色

### 6. findCharacterByName
**功能**：根据名称查找角色
**原方法**：`DatabaseService.findCharacterByName`
**签名**：`Future<Character?> findCharacterByName(String novelUrl, String name)`
**说明**：在指定小说中查找指定名称的角色

### 7. updateOrInsertCharacter
**功能**：更新或插入角色（去重逻辑）
**原方法**：`DatabaseService.updateOrInsertCharacter`
**签名**：`Future<Character> updateOrInsertCharacter(Character newCharacter)`
**说明**：如果角色存在则更新，否则创建新角色

### 8. batchUpdateCharacters
**功能**：批量更新角色
**原方法**：`DatabaseService.batchUpdateCharacters`
**签名**：`Future<List<Character>> batchUpdateCharacters(List<Character> newCharacters)`
**说明**：对每个角色执行去重更新逻辑，失败不中断整体操作

### 9. getCharacterNames
**功能**：获取小说的所有角色名称
**原方法**：`DatabaseService.getCharacterNames`
**签名**：`Future<List<String>> getCharacterNames(String novelUrl)`
**说明**：返回按名称字母顺序排列的角色名称列表

### 10. characterExists
**功能**：检查角色是否存在
**原方法**：`DatabaseService.characterExists`
**签名**：`Future<bool> characterExists(int id)`
**说明**：返回指定ID的角色是否存在

### 11. getCharactersByIds
**功能**：根据ID列表获取多个角色
**原方法**：`DatabaseService.getCharactersByIds`
**签名**：`Future<List<Character>> getCharactersByIds(List<int> ids)`
**说明**：返回按创建时间升序排列的角色列表

### 12. deleteAllCharacters
**功能**：删除小说的所有角色
**原方法**：`DatabaseService.deleteAllCharacters`
**签名**：`Future<int> deleteAllCharacters(String novelUrl)`
**说明**：删除指定小说的所有角色

### 13. batchUpdateOrInsertCharacters
**功能**：批量更新或插入角色（用于AI伴读）
**原方法**：`DatabaseService.batchUpdateOrInsertCharacters`
**签名**：`Future<int> batchUpdateOrInsertCharacters(String novelUrl, List<AICompanionRole> aiRoles)`
**说明**：根据AI返回的角色列表批量更新或创建角色

---

## 二、角色图片管理（6个方法）

### 14. updateCharacterCachedImage
**功能**：更新角色的缓存图片URL
**原方法**：`DatabaseService.updateCharacterCachedImage`
**签名**：`Future<int> updateCharacterCachedImage(int characterId, String? imageUrl)`
**说明**：更新角色的缓存图片URL

### 15. clearCharacterCachedImage
**功能**：清除角色的缓存图片URL
**原方法**：`DatabaseService.clearCharacterCachedImage`
**签名**：`Future<int> clearCharacterCachedImage(int characterId)`
**说明**：将角色的缓存图片URL设置为null

### 16. clearAllCharacterCachedImages
**功能**：批量清除角色的缓存图片URL
**原方法**：`DatabaseService.clearAllCharacterCachedImages`
**签名**：`Future<int> clearAllCharacterCachedImages(String novelUrl)`
**说明**：清除指定小说的所有角色的缓存图片

### 17. getCharacterCachedImage
**功能**：获取角色的缓存图片URL
**原方法**：`DatabaseService.getCharacterCachedImage`
**签名**：`Future<String?> getCharacterCachedImage(int characterId)`
**说明**：返回角色的缓存图片URL，不存在则返回null

### 18. updateCharacterAvatar
**功能**：更新角色头像信息（扩展方法）
**原方法**：`DatabaseService.updateCharacterAvatar`
**签名**：`Future<int> updateCharacterAvatar(int characterId, {String? imageUrl, String? originalFilename, String? originalImageUrl})`
**说明**：支持更新角色头像及相关元数据

### 19. hasCharacterAvatar
**功能**：检查角色是否有头像缓存
**原方法**：`DatabaseService.hasCharacterAvatar`
**签名**：`Future<bool> hasCharacterAvatar(int characterId)`
**说明**：返回角色是否有有效的头像缓存

---

## 三、角色关系CRUD操作（11个方法）

### 20. createRelationship
**功能**：创建角色关系
**原方法**：`DatabaseService.createRelationship`
**签名**：`Future<int> createRelationship(CharacterRelationship relationship)`
**说明**：插入新关系到数据库，返回新记录的ID

### 21. getRelationships
**功能**：获取角色的所有关系（出度 + 入度）
**原方法**：`DatabaseService.getRelationships`
**签名**：`Future<List<CharacterRelationship>> getRelationships(int characterId)`
**说明**：返回该角色相关的所有关系（包括发起的和接收的）

### 22. getOutgoingRelationships
**功能**：获取角色的出度关系（Ta → 其他人）
**原方法**：`DatabaseService.getOutgoingRelationships`
**签名**：`Future<List<CharacterRelationship>> getOutgoingRelationships(int characterId)`
**说明**：返回该角色发起的所有关系

### 23. getIncomingRelationships
**功能**：获取角色的入度关系（其他人 → Ta）
**原方法**：`DatabaseService.getIncomingRelationships`
**签名**：`Future<List<CharacterRelationship>> getIncomingRelationships(int characterId)`
**说明**：返回指向该角色的所有关系

### 24. updateRelationship
**功能**：更新角色关系
**原方法**：`DatabaseService.updateRelationship`
**签名**：`Future<int> updateRelationship(CharacterRelationship relationship)`
**说明**：更新关系信息，关系对象必须包含id

### 25. deleteRelationship
**功能**：删除角色关系
**原方法**：`DatabaseService.deleteRelationship`
**签名**：`Future<int> deleteRelationship(int relationshipId)`
**说明**：删除指定ID的关系

### 26. relationshipExists
**功能**：检查关系是否已存在
**原方法**：`DatabaseService.relationshipExists`
**签名**：`Future<bool> relationshipExists(int sourceId, int targetId, String type)`
**说明**：检查指定的关系是否已存在

### 27. getRelationshipCount
**功能**：获取角色的关系数量
**原方法**：`DatabaseService.getRelationshipCount`
**签名**：`Future<int> getRelationshipCount(int characterId)`
**说明**：返回该角色的关系总数（出度 + 入度）

### 28. getRelatedCharacterIds
**功能**：获取与某角色相关的所有角色（去重）
**原方法**：`DatabaseService.getRelatedCharacterIds`
**签名**：`Future<List<int>> getRelatedCharacterIds(int characterId)`
**说明**：返回与该角色有关系的所有角色的ID列表

### 29. getAllRelationships
**功能**：获取小说的所有关系
**原方法**：`DatabaseService.getAllRelationships`
**签名**：`Future<List<CharacterRelationship>> getAllRelationships(String novelUrl)`
**说明**：返回指定小说的所有角色关系

### 30. getRelationshipsByCharacterIds
**功能**：根据source和target角色ID获取关系
**原方法**：`DatabaseService._getRelationshipsByCharacterIds`（私有方法改为公开）
**签名**：`Future<List<CharacterRelationship>> getRelationshipsByCharacterIds(int sourceId, int targetId)`
**说明**：返回两个角色之间的所有关系

### 31. batchUpdateOrInsertRelationships
**功能**：批量更新或插入关系（用于AI伴读）
**原方法**：`DatabaseService.batchUpdateOrInsertRelationships`
**签名**：`Future<int> batchUpdateOrInsertRelationships(String novelUrl, List<AICompanionRelation> aiRelations)`
**说明**：根据AI返回的关系列表批量更新或创建关系

---

## 与原方法的对应关系

| CharacterRepository方法 | DatabaseService原方法 | 说明 |
|------------------------|----------------------|------|
| createCharacter | createCharacter | 完全相同 |
| getCharacters | getCharacters | 完全相同 |
| getCharacter | getCharacter | 完全相同 |
| updateCharacter | updateCharacter | 完全相同 |
| deleteCharacter | deleteCharacter | 完全相同 |
| findCharacterByName | findCharacterByName | 完全相同 |
| updateOrInsertCharacter | updateOrInsertCharacter | 完全相同 |
| batchUpdateCharacters | batchUpdateCharacters | 完全相同 |
| getCharacterNames | getCharacterNames | 完全相同 |
| characterExists | characterExists | 完全相同 |
| getCharactersByIds | getCharactersByIds | 完全相同 |
| deleteAllCharacters | deleteAllCharacters | 完全相同 |
| updateCharacterCachedImage | updateCharacterCachedImage | 完全相同 |
| clearCharacterCachedImage | clearCharacterCachedImage | 完全相同 |
| clearAllCharacterCachedImages | clearAllCharacterCachedImages | 完全相同 |
| getCharacterCachedImage | getCharacterCachedImage | 完全相同 |
| updateCharacterAvatar | updateCharacterAvatar | 完全相同 |
| hasCharacterAvatar | hasCharacterAvatar | 完全相同 |
| createRelationship | createRelationship | 完全相同 |
| getRelationships | getRelationships | 完全相同 |
| getOutgoingRelationships | getOutgoingRelationships | 完全相同 |
| getIncomingRelationships | getIncomingRelationships | 完全相同 |
| updateRelationship | updateRelationship | 完全相同 |
| deleteRelationship | deleteRelationship | 完全相同 |
| relationshipExists | relationshipExists | 完全相同 |
| getRelationshipCount | getRelationshipCount | 完全相同 |
| getRelatedCharacterIds | getRelatedCharacterIds | 完全相同 |
| getAllRelationships | getAllRelationships | 完全相同 |
| getRelationshipsByCharacterIds | _getRelationshipsByCharacterIds | 私有方法改为公开 |
| batchUpdateOrInsertCharacters | batchUpdateOrInsertCharacters | 完全相同 |
| batchUpdateOrInsertRelationships | batchUpdateOrInsertRelationships | 完全相同 |

---

## 代码质量验证

✅ **Flutter analyze 通过**：`No issues found!`
✅ **完整的文档注释**：所有方法都有详细的中文注释
✅ **类型安全**：所有方法都有明确的类型签名
✅ **错误处理**：关键操作都有try-catch和日志记录
✅ **继承BaseRepository**：遵循项目的Repository模式

---

## 使用示例

```dart
// 创建实例
final characterRepo = CharacterRepository();

// 初始化数据库（需要注入DatabaseService的database实例）
// 注意：实际使用时需要通过依赖注入获取数据库实例

// 创建角色
final character = Character(
  novelUrl: 'https://example.com/novel/1',
  name: '张三',
  age: 25,
  gender: '男',
);
await characterRepo.createCharacter(character);

// 获取所有角色
final characters = await characterRepo.getCharacters('https://example.com/novel/1');

// 创建关系
final relationship = CharacterRelationship(
  sourceCharacterId: 1,
  targetCharacterId: 2,
  relationshipType: '师父',
);
await characterRepo.createRelationship(relationship);
```

---

## 注意事项

1. **数据库实例**：`CharacterRepository` 继承自 `BaseRepository`，需要通过依赖注入获取数据库实例
2. **Web平台支持**：部分方法对Web平台做了特殊处理（通过 `isWebPlatform` 检查）
3. **日志记录**：所有关键操作都有详细的日志记录，使用 `LoggerService`
4. **批量操作**：批量更新/插入操作会跳过失败的项，不会中断整体操作
5. **关系去重**：通过 `updateOrInsertCharacter` 和 `batchUpdateOrInsertCharacters` 实现智能去重
