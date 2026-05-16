# novel_api.model.NovelSyncData

## Load the model package
```dart
import 'package:novel_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**title** | **String** | 小说标题 | 
**author** | **String** |  | [optional] 
**description** | **String** |  | [optional] 
**coverUrl** | **String** |  | [optional] 
**backgroundSetting** | **String** |  | [optional] 
**chapters** | [**BuiltList&lt;ChapterSyncData&gt;**](ChapterSyncData.md) | 章节列表 | [optional] [default to ListBuilder()]
**characters** | [**BuiltList&lt;CharacterSyncData&gt;**](CharacterSyncData.md) | 角色列表 | [optional] [default to ListBuilder()]
**characterRelations** | [**BuiltList&lt;CharacterRelationSyncData&gt;**](CharacterRelationSyncData.md) | 角色关系列表 | [optional] [default to ListBuilder()]
**outlines** | [**BuiltList&lt;OutlineSyncData&gt;**](OutlineSyncData.md) | 大纲列表 | [optional] [default to ListBuilder()]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


