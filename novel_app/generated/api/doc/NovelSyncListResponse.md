# novel_api.model.NovelSyncListResponse

## Load the model package
```dart
import 'package:novel_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**success** | **bool** | 是否成功 | 
**message** | **String** | 响应消息 | 
**novels** | [**BuiltList&lt;NovelSyncData&gt;**](NovelSyncData.md) | 小说列表 | [optional] [default to ListBuilder()]
**totalCount** | **int** | 总数 | 
**page** | **int** | 当前页码 | [optional] [default to 1]
**pageSize** | **int** | 每页数量 | [optional] [default to 20]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


