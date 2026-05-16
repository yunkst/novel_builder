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
> NovelSyncDeleteResponse deleteSyncedNovelApiNovelSyncDeleteDelete(title, X_API_TOKEN)

Delete Synced Novel

删除已同步的小说数据.

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getNovelSyncApi();
final String title = title_example; // String | 
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.deleteSyncedNovelApiNovelSyncDeleteDelete(title, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling NovelSyncApi->deleteSyncedNovelApiNovelSyncDeleteDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **title** | **String**|  | 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**NovelSyncDeleteResponse**](NovelSyncDeleteResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **downloadNovelApiNovelSyncDownloadPost**
> NovelSyncDownloadResponse downloadNovelApiNovelSyncDownloadPost(novelSyncDownloadRequest, X_API_TOKEN)

Download Novel

从服务器下载小说数据.

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

获取已同步小说列表.

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

上传小说数据到服务器.

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

