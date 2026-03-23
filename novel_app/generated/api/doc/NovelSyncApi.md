# novel_api.api.NovelSyncApi

## Load the API package
```dart
import 'package:novel_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**deleteSyncedNovelApiNovelSyncDeleteDelete**](NovelSyncApi.md#deletesyncednovelapinovelsyncdeletedelete) | **DELETE** /api/novel/sync/delete | Delete Synced Novel
[**downloadNovelApiNovelSyncDownloadPost**](NovelSyncApi.md#downloadnovelapinovelsyncdownloadpost) | **POST** /api/novel/sync/download | Download Novel
[**listSyncedNovelsApiNovelSyncListGet**](NovelSyncApi.md#listsyncednovelsapinovelsynclistget) | **GET** /api/novel/sync/list | List Synced Novels
[**uploadNovelApiNovelSyncUploadPost**](NovelSyncApi.md#uploadnovelapinovelsyncuploadpost) | **POST** /api/novel/sync/upload | Upload Novel


# **deleteSyncedNovelApiNovelSyncDeleteDelete**
> JsonObject deleteSyncedNovelApiNovelSyncDeleteDelete(novelUrl, X_API_TOKEN)

Delete Synced Novel

删除已同步的小说数据.  从服务器删除指定小说的所有同步数据，包括章节、角色、关系和大纲。  **查询参数:** - **novel_url**: 小说URL（作为唯一标识）  **返回值:** - **success**: 是否成功 - **message**: 响应消息  **认证**: 需要X-API-TOKEN header  **注意:** 此操作不可逆，删除后数据无法恢复

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getNovelSyncApi();
final String novelUrl = novelUrl_example; // String | 
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.deleteSyncedNovelApiNovelSyncDeleteDelete(novelUrl, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling NovelSyncApi->deleteSyncedNovelApiNovelSyncDeleteDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **novelUrl** | **String**|  | 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**JsonObject**](JsonObject.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **downloadNovelApiNovelSyncDownloadPost**
> NovelSyncDownloadResponse downloadNovelApiNovelSyncDownloadPost(novelSyncDownloadRequest, X_API_TOKEN)

Download Novel

从服务器下载小说数据.  根据小说来源URL（source_url）获取服务器上存储的完整小说数据。 支持选择性下载章节、角色和大纲数据。  **请求参数:** - **device_id**: 设备标识 - **source_url**: 小说来源URL（作为唯一标识，与上传时一致） - **include_chapters**: 是否包含章节内容（默认true） - **include_characters**: 是否包含角色数据（默认true） - **include_outlines**: 是否包含大纲数据（默认true）  **返回值:** - **success**: 是否成功 - **message**: 响应消息 - **novel_data**: 完整的小说数据（如果找到） - **sync_version**: 同步版本号 - **synced_at**: 最后同步时间  **认证**: 需要X-API-TOKEN header  **注意:** 如果小说不存在，返回success=false，novel_data=null

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getNovelSyncApi();
final NovelSyncDownloadRequest novelSyncDownloadRequest = ; // NovelSyncDownloadRequest | 
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.downloadNovelApiNovelSyncDownloadPost(novelSyncDownloadRequest, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling NovelSyncApi->downloadNovelApiNovelSyncDownloadPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **novelSyncDownloadRequest** | [**NovelSyncDownloadRequest**](NovelSyncDownloadRequest.md)|  | 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**NovelSyncDownloadResponse**](NovelSyncDownloadResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listSyncedNovelsApiNovelSyncListGet**
> NovelSyncListResponse listSyncedNovelsApiNovelSyncListGet(page, pageSize, X_API_TOKEN)

List Synced Novels

获取已同步小说列表.  返回服务器上所有已同步小说的基本信息列表，支持分页。 返回的数据仅包含元数据，不包含章节内容。  **查询参数:** - **page**: 页码（从1开始，默认1） - **page_size**: 每页数量（默认20，最大100）  **返回值:** - **success**: 是否成功 - **message**: 响应消息 - **novels**: 小说元数据列表 - **total_count**: 总数 - **page**: 当前页码 - **page_size**: 每页数量  **认证**: 需要X-API-TOKEN header

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getNovelSyncApi();
final int page = 56; // int | 
final int pageSize = 56; // int | 
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.listSyncedNovelsApiNovelSyncListGet(page, pageSize, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling NovelSyncApi->listSyncedNovelsApiNovelSyncListGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **page** | **int**|  | [optional] [default to 1]
 **pageSize** | **int**|  | [optional] [default to 20]
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**NovelSyncListResponse**](NovelSyncListResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **uploadNovelApiNovelSyncUploadPost**
> NovelSyncUploadResponse uploadNovelApiNovelSyncUploadPost(novelSyncUploadRequest, X_API_TOKEN)

Upload Novel

上传小说数据到服务器.  接收APP端上传的完整小说数据，包括章节、角色、关系和大纲等信息。 服务器会根据source_url作为唯一标识存储数据，支持版本控制。  **请求参数:** - **device_id**: 设备标识（用于追踪同步来源） - **novel_data**: 完整的小说数据，包括：     - 基本信息（标题、作者、简介等）     - 章节列表（包括用户插入章节）     - 角色列表     - 角色关系列表     - 大纲列表 - **force_overwrite**: 是否强制覆盖服务器数据（默认false）  **返回值:** - **success**: 是否成功 - **message**: 响应消息 - **novel_id**: 小说ID - **sync_version**: 同步版本号（每次更新递增） - **synced_at**: 同步时间  **认证**: 需要X-API-TOKEN header

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getNovelSyncApi();
final NovelSyncUploadRequest novelSyncUploadRequest = ; // NovelSyncUploadRequest | 
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.uploadNovelApiNovelSyncUploadPost(novelSyncUploadRequest, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling NovelSyncApi->uploadNovelApiNovelSyncUploadPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **novelSyncUploadRequest** | [**NovelSyncUploadRequest**](NovelSyncUploadRequest.md)|  | 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**NovelSyncUploadResponse**](NovelSyncUploadResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

