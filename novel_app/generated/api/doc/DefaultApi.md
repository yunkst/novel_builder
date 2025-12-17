# novel_api.api.DefaultApi

## Load the API package
```dart
import 'package:novel_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**chapterContentChapterContentGet**](DefaultApi.md#chaptercontentchaptercontentget) | **GET** /chapter-content | Chapter Content
[**chaptersChaptersGet**](DefaultApi.md#chapterschaptersget) | **GET** /chapters | Chapters
[**checkVideoStatusApiImageToVideoHasVideoImgNameGet**](DefaultApi.md#checkvideostatusapiimagetovideohasvideoimgnameget) | **GET** /api/image-to-video/has-video/{img_name} | Check Video Status
[**deleteRoleCardImageApiRoleCardImageDelete**](DefaultApi.md#deleterolecardimageapirolecardimagedelete) | **DELETE** /api/role-card/image | Delete Role Card Image
[**deleteSceneImageApiSceneIllustrationImageDelete**](DefaultApi.md#deletesceneimageapisceneillustrationimagedelete) | **DELETE** /api/scene-illustration/image | Delete Scene Image
[**generateRoleCardImagesApiRoleCardGeneratePost**](DefaultApi.md#generaterolecardimagesapirolecardgeneratepost) | **POST** /api/role-card/generate | Generate Role Card Images
[**generateSceneImagesApiSceneIllustrationGeneratePost**](DefaultApi.md#generatesceneimagesapisceneillustrationgeneratepost) | **POST** /api/scene-illustration/generate | Generate Scene Images
[**generateVideoFromImageApiImageToVideoGeneratePost**](DefaultApi.md#generatevideofromimageapiimagetovideogeneratepost) | **POST** /api/image-to-video/generate | Generate Video From Image
[**getAvailableModelsApiRoleCardModelsGet**](DefaultApi.md#getavailablemodelsapirolecardmodelsget) | **GET** /api/role-card/models | Get Available Models
[**getImageProxyText2imgImageFilenameGet**](DefaultApi.md#getimageproxytext2imgimagefilenameget) | **GET** /text2img/image/{filename} | Get Image Proxy
[**getRoleCardGalleryApiRoleCardGalleryRoleIdGet**](DefaultApi.md#getrolecardgalleryapirolecardgalleryroleidget) | **GET** /api/role-card/gallery/{role_id} | Get Role Card Gallery
[**getRoleCardTaskStatusApiRoleCardStatusTaskIdGet**](DefaultApi.md#getrolecardtaskstatusapirolecardstatustaskidget) | **GET** /api/role-card/status/{task_id} | Get Role Card Task Status
[**getSceneGalleryApiSceneIllustrationGalleryTaskIdGet**](DefaultApi.md#getscenegalleryapisceneillustrationgallerytaskidget) | **GET** /api/scene-illustration/gallery/{task_id} | Get Scene Gallery
[**getSourceSitesSourceSitesGet**](DefaultApi.md#getsourcesitessourcesitesget) | **GET** /source-sites | Get Source Sites
[**getVideoFileApiImageToVideoVideoImgNameGet**](DefaultApi.md#getvideofileapiimagetovideovideoimgnameget) | **GET** /api/image-to-video/video/{img_name} | Get Video File
[**getVideoTaskStatusApiImageToVideoStatusTaskIdGet**](DefaultApi.md#getvideotaskstatusapiimagetovideostatustaskidget) | **GET** /api/image-to-video/status/{task_id} | Get Video Task Status
[**healthCheckHealthGet**](DefaultApi.md#healthcheckhealthget) | **GET** /health | Health Check
[**imageToVideoHealthCheckApiImageToVideoHealthGet**](DefaultApi.md#imagetovideohealthcheckapiimagetovideohealthget) | **GET** /api/image-to-video/health | Image To Video Health Check
[**indexGet**](DefaultApi.md#indexget) | **GET** / | Index
[**regenerateSceneImagesApiSceneIllustrationRegeneratePost**](DefaultApi.md#regeneratesceneimagesapisceneillustrationregeneratepost) | **POST** /api/scene-illustration/regenerate | Regenerate Scene Images
[**regenerateSimilarImagesApiRoleCardRegeneratePost**](DefaultApi.md#regeneratesimilarimagesapirolecardregeneratepost) | **POST** /api/role-card/regenerate | Regenerate Similar Images
[**roleCardHealthCheckApiRoleCardHealthGet**](DefaultApi.md#rolecardhealthcheckapirolecardhealthget) | **GET** /api/role-card/health | Role Card Health Check
[**searchSearchGet**](DefaultApi.md#searchsearchget) | **GET** /search | Search
[**text2imgHealthCheckText2imgHealthGet**](DefaultApi.md#text2imghealthchecktext2imghealthget) | **GET** /text2img/health | Text2Img Health Check


# **chapterContentChapterContentGet**
> ChapterContent chapterContentChapterContentGet(url, forceRefresh, X_API_TOKEN)

Chapter Content

获取章节内容  - **url**: 章节URL - **force_refresh**: 是否强制刷新（默认 False）   - False: 优先从缓存获取，缓存不存在时从源站抓取   - True: 强制从源站重新获取（用于更新内容）

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final String url = url_example; // String | 章节URL
final bool forceRefresh = true; // bool | 强制刷新，从源站重新获取
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.chapterContentChapterContentGet(url, forceRefresh, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->chapterContentChapterContentGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **url** | **String**| 章节URL | 
 **forceRefresh** | **bool**| 强制刷新，从源站重新获取 | [optional] [default to false]
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**ChapterContent**](ChapterContent.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **chaptersChaptersGet**
> BuiltList<Chapter> chaptersChaptersGet(url, X_API_TOKEN)

Chapters

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final String url = url_example; // String | 小说详情页或阅读页URL
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.chaptersChaptersGet(url, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->chaptersChaptersGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **url** | **String**| 小说详情页或阅读页URL | 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**BuiltList&lt;Chapter&gt;**](Chapter.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **checkVideoStatusApiImageToVideoHasVideoImgNameGet**
> VideoStatusResponse checkVideoStatusApiImageToVideoHasVideoImgNameGet(imgName, X_API_TOKEN)

Check Video Status

检查图片是否有已生成的视频  根据图片名称快速查询是否已有对应的视频文件存在。  **路径参数:** - **img_name**: 要查询的图片文件名称  **返回值:** - **img_name**: 图片名称 - **has_video**: 是否有对应的视频文件（true/false） - **video_url**: 视频文件URL（如果有） - **created_at**: 视频创建时间（如果有）  **使用场景:** - 在显示图片时快速判断是否显示视频播放按钮 - 避免重复创建已有视频的任务

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final String imgName = imgName_example; // String | 
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.checkVideoStatusApiImageToVideoHasVideoImgNameGet(imgName, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->checkVideoStatusApiImageToVideoHasVideoImgNameGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **imgName** | **String**|  | 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**VideoStatusResponse**](VideoStatusResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteRoleCardImageApiRoleCardImageDelete**
> JsonObject deleteRoleCardImageApiRoleCardImageDelete(roleImageDeleteRequest, X_API_TOKEN)

Delete Role Card Image

从角色图集中删除图片  - **role_id**: 人物卡ID - **img_url**: 要删除的图片URL

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final RoleImageDeleteRequest roleImageDeleteRequest = ; // RoleImageDeleteRequest | 
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.deleteRoleCardImageApiRoleCardImageDelete(roleImageDeleteRequest, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->deleteRoleCardImageApiRoleCardImageDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **roleImageDeleteRequest** | [**RoleImageDeleteRequest**](RoleImageDeleteRequest.md)|  | 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**JsonObject**](JsonObject.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteSceneImageApiSceneIllustrationImageDelete**
> JsonObject deleteSceneImageApiSceneIllustrationImageDelete(sceneImageDeleteRequest, X_API_TOKEN)

Delete Scene Image

从场面绘制结果中删除图片  - **task_id**: 场面绘制任务ID - **filename**: 要删除的图片文件名

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final SceneImageDeleteRequest sceneImageDeleteRequest = ; // SceneImageDeleteRequest | 
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.deleteSceneImageApiSceneIllustrationImageDelete(sceneImageDeleteRequest, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->deleteSceneImageApiSceneIllustrationImageDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sceneImageDeleteRequest** | [**SceneImageDeleteRequest**](SceneImageDeleteRequest.md)|  | 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**JsonObject**](JsonObject.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **generateRoleCardImagesApiRoleCardGeneratePost**
> JsonObject generateRoleCardImagesApiRoleCardGeneratePost(roleCardGenerateRequest, X_API_TOKEN)

Generate Role Card Images

异步生成人物卡图片  - **role_id**: 人物卡ID - **roles**: 人物卡设定信息 - **user_input**: 用户要求  返回任务ID，可通过 /api/role-card/status/{task_id} 查询进度

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final RoleCardGenerateRequest roleCardGenerateRequest = ; // RoleCardGenerateRequest | 
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.generateRoleCardImagesApiRoleCardGeneratePost(roleCardGenerateRequest, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->generateRoleCardImagesApiRoleCardGeneratePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **roleCardGenerateRequest** | [**RoleCardGenerateRequest**](RoleCardGenerateRequest.md)|  | 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**JsonObject**](JsonObject.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **generateSceneImagesApiSceneIllustrationGeneratePost**
> JsonObject generateSceneImagesApiSceneIllustrationGeneratePost(enhancedSceneIllustrationRequest, X_API_TOKEN)

Generate Scene Images

生成场面绘制图片  - **chapters_content**: 章节内容 - **task_id**: 任务标识符 - **roles**: 角色信息 - **num**: 生成图片数量 - **model_name**: 指定使用的模型名称（可选）  返回任务ID，可通过后续接口查询和获取图片

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final EnhancedSceneIllustrationRequest enhancedSceneIllustrationRequest = ; // EnhancedSceneIllustrationRequest | 
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.generateSceneImagesApiSceneIllustrationGeneratePost(enhancedSceneIllustrationRequest, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->generateSceneImagesApiSceneIllustrationGeneratePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **enhancedSceneIllustrationRequest** | [**EnhancedSceneIllustrationRequest**](EnhancedSceneIllustrationRequest.md)|  | 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**JsonObject**](JsonObject.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **generateVideoFromImageApiImageToVideoGeneratePost**
> ImageToVideoResponse generateVideoFromImageApiImageToVideoGeneratePost(imageToVideoRequest, X_API_TOKEN)

Generate Video From Image

生成图生视频  创建一个图生视频任务，将指定的图片转换为动态视频。  **请求参数:** - **img_name**: 要处理的图片文件名称 - **user_input**: 用户对视频生成的要求描述 - **model_name**: 图生视频模型名称  **返回值:** - **task_id**: 视频生成任务的唯一标识符，用于后续状态查询 - **img_name**: 处理的图片名称 - **status**: 任务初始状态（通常为 \"pending\"） - **message**: 任务创建的状态消息  **使用示例:** ```json {     \"task_id\": 123,     \"img_name\": \"example.jpg\",     \"status\": \"pending\",     \"message\": \"图生视频任务创建成功\" } ```  **后续操作:** 使用返回的 task_id 调用 `/api/image-to-video/status/{task_id}` 查询生成进度

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final ImageToVideoRequest imageToVideoRequest = ; // ImageToVideoRequest | 
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.generateVideoFromImageApiImageToVideoGeneratePost(imageToVideoRequest, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->generateVideoFromImageApiImageToVideoGeneratePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **imageToVideoRequest** | [**ImageToVideoRequest**](ImageToVideoRequest.md)|  | 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**ImageToVideoResponse**](ImageToVideoResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAvailableModelsApiRoleCardModelsGet**
> JsonObject getAvailableModelsApiRoleCardModelsGet(X_API_TOKEN)

Get Available Models

获取可用的工作流模型列表

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.getAvailableModelsApiRoleCardModelsGet(X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->getAvailableModelsApiRoleCardModelsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**JsonObject**](JsonObject.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getImageProxyText2imgImageFilenameGet**
> Uint8List getImageProxyText2imgImageFilenameGet(filename)

Get Image Proxy

图片代理接口 - 从ComfyUI获取图片并转发给用户  返回图片二进制数据 (PNG格式)  - **filename**: 图片文件名 - **返回**: 图片二进制数据 (Content-Type: image/png)

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final String filename = filename_example; // String | 

try {
    final response = api.getImageProxyText2imgImageFilenameGet(filename);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->getImageProxyText2imgImageFilenameGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **filename** | **String**|  | 

### Return type

[**Uint8List**](Uint8List.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: image/png, application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getRoleCardGalleryApiRoleCardGalleryRoleIdGet**
> RoleGalleryResponse getRoleCardGalleryApiRoleCardGalleryRoleIdGet(roleId, X_API_TOKEN)

Get Role Card Gallery

查看角色图集  - **role_id**: 人物卡ID

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final String roleId = roleId_example; // String | 
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.getRoleCardGalleryApiRoleCardGalleryRoleIdGet(roleId, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->getRoleCardGalleryApiRoleCardGalleryRoleIdGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **roleId** | **String**|  | 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**RoleGalleryResponse**](RoleGalleryResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getRoleCardTaskStatusApiRoleCardStatusTaskIdGet**
> RoleCardTaskStatusResponse getRoleCardTaskStatusApiRoleCardStatusTaskIdGet(taskId, X_API_TOKEN)

Get Role Card Task Status

查询人物卡生成任务状态  - **task_id**: 任务ID

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final int taskId = 56; // int | 
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.getRoleCardTaskStatusApiRoleCardStatusTaskIdGet(taskId, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->getRoleCardTaskStatusApiRoleCardStatusTaskIdGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **int**|  | 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**RoleCardTaskStatusResponse**](RoleCardTaskStatusResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getSceneGalleryApiSceneIllustrationGalleryTaskIdGet**
> SceneGalleryResponse getSceneGalleryApiSceneIllustrationGalleryTaskIdGet(taskId, X_API_TOKEN)

Get Scene Gallery

查看场面绘制图片列表  - **task_id**: 场面绘制任务ID

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final String taskId = taskId_example; // String | 
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.getSceneGalleryApiSceneIllustrationGalleryTaskIdGet(taskId, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->getSceneGalleryApiSceneIllustrationGalleryTaskIdGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **String**|  | 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**SceneGalleryResponse**](SceneGalleryResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getSourceSitesSourceSitesGet**
> BuiltList<SourceSite> getSourceSitesSourceSitesGet(X_API_TOKEN)

Get Source Sites

获取所有源站列表

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.getSourceSitesSourceSitesGet(X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->getSourceSitesSourceSitesGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**BuiltList&lt;SourceSite&gt;**](SourceSite.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getVideoFileApiImageToVideoVideoImgNameGet**
> Uint8List getVideoFileApiImageToVideoVideoImgNameGet(imgName)

Get Video File

获取视频文件  返回视频二进制数据 (MP4格式)  - **img_name**: 图片名称 - **返回**: 视频二进制数据 (Content-Type: video/mp4)

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final String imgName = imgName_example; // String | 

try {
    final response = api.getVideoFileApiImageToVideoVideoImgNameGet(imgName);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->getVideoFileApiImageToVideoVideoImgNameGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **imgName** | **String**|  | 

### Return type

[**Uint8List**](Uint8List.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: video/mp4, application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getVideoTaskStatusApiImageToVideoStatusTaskIdGet**
> ImageToVideoTaskStatusResponse getVideoTaskStatusApiImageToVideoStatusTaskIdGet(taskId, X_API_TOKEN)

Get Video Task Status

查询图生视频任务状态  获取指定任务的详细状态信息，包括生成进度和结果。  **路径参数:** - **task_id**: 图生视频任务的唯一标识符  **返回值:** - **task_id**: 任务ID - **img_name**: 处理的图片名称 - **status**: 任务状态（pending/running/completed/failed） - **model_name**: 使用的模型名称 - **user_input**: 用户输入要求 - **video_prompt**: 生成的视频提示词（如果有） - **video_filename**: 生成的视频文件名（完成时） - **result_message**: 结果描述信息 - **error_message**: 错误信息（失败时） - **created_at**: 任务创建时间 - **updated_at**: 任务更新时间

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final int taskId = 56; // int | 
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.getVideoTaskStatusApiImageToVideoStatusTaskIdGet(taskId, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->getVideoTaskStatusApiImageToVideoStatusTaskIdGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **int**|  | 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**ImageToVideoTaskStatusResponse**](ImageToVideoTaskStatusResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **healthCheckHealthGet**
> BuiltMap<String, String> healthCheckHealthGet()

Health Check

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();

try {
    final response = api.healthCheckHealthGet();
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->healthCheckHealthGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**BuiltMap&lt;String, String&gt;**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **imageToVideoHealthCheckApiImageToVideoHealthGet**
> JsonObject imageToVideoHealthCheckApiImageToVideoHealthGet(X_API_TOKEN)

Image To Video Health Check

检查图生视频服务健康状态

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.imageToVideoHealthCheckApiImageToVideoHealthGet(X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->imageToVideoHealthCheckApiImageToVideoHealthGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**JsonObject**](JsonObject.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **indexGet**
> JsonObject indexGet()

Index

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();

try {
    final response = api.indexGet();
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->indexGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**JsonObject**](JsonObject.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **regenerateSceneImagesApiSceneIllustrationRegeneratePost**
> JsonObject regenerateSceneImagesApiSceneIllustrationRegeneratePost(sceneRegenerateRequest, X_API_TOKEN)

Regenerate Scene Images

基于现有任务重新生成场面图片  - **task_id**: 原始任务ID - **count**: 生成图片数量 - **model**: 指定使用的模型名称（可选，会使用原始任务的模型）

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final SceneRegenerateRequest sceneRegenerateRequest = ; // SceneRegenerateRequest | 
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.regenerateSceneImagesApiSceneIllustrationRegeneratePost(sceneRegenerateRequest, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->regenerateSceneImagesApiSceneIllustrationRegeneratePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sceneRegenerateRequest** | [**SceneRegenerateRequest**](SceneRegenerateRequest.md)|  | 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**JsonObject**](JsonObject.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **regenerateSimilarImagesApiRoleCardRegeneratePost**
> JsonObject regenerateSimilarImagesApiRoleCardRegeneratePost(roleRegenerateRequest, X_API_TOKEN)

Regenerate Similar Images

重新生成相似图片  - **img_url**: 参考图片URL - **count**: 生成图片数量 - **model**: 指定使用的模型名称（可选）

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final RoleRegenerateRequest roleRegenerateRequest = ; // RoleRegenerateRequest | 
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.regenerateSimilarImagesApiRoleCardRegeneratePost(roleRegenerateRequest, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->regenerateSimilarImagesApiRoleCardRegeneratePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **roleRegenerateRequest** | [**RoleRegenerateRequest**](RoleRegenerateRequest.md)|  | 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**JsonObject**](JsonObject.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **roleCardHealthCheckApiRoleCardHealthGet**
> JsonObject roleCardHealthCheckApiRoleCardHealthGet(X_API_TOKEN)

Role Card Health Check

检查人物卡服务健康状态

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.roleCardHealthCheckApiRoleCardHealthGet(X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->roleCardHealthCheckApiRoleCardHealthGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**JsonObject**](JsonObject.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **searchSearchGet**
> BuiltList<Novel> searchSearchGet(keyword, sites, X_API_TOKEN)

Search

搜索小说，支持指定站点

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final String keyword = keyword_example; // String | 小说名称或作者
final String sites = sites_example; // String | 指定搜索站点，逗号分隔，如 alice_sw,shukuge
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.searchSearchGet(keyword, sites, X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->searchSearchGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **keyword** | **String**| 小说名称或作者 | 
 **sites** | **String**| 指定搜索站点，逗号分隔，如 alice_sw,shukuge | [optional] 
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**BuiltList&lt;Novel&gt;**](Novel.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **text2imgHealthCheckText2imgHealthGet**
> JsonObject text2imgHealthCheckText2imgHealthGet(X_API_TOKEN)

Text2Img Health Check

检查ComfyUI服务健康状态

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getDefaultApi();
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.text2imgHealthCheckText2imgHealthGet(X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->text2imgHealthCheckText2imgHealthGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**JsonObject**](JsonObject.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

