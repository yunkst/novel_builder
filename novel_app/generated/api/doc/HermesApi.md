# novel_api.api.HermesApi

## Load the API package
```dart
import 'package:novel_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**chatCompletionsHermesChatCompletionsPost**](HermesApi.md#chatcompletionshermeschatcompletionspost) | **POST** /hermes/chat/completions | Chat Completions
[**hermesHealthCheckHermesHealthGet**](HermesApi.md#hermeshealthcheckhermeshealthget) | **GET** /hermes/health | Hermes Health Check


# **chatCompletionsHermesChatCompletionsPost**
> JsonObject chatCompletionsHermesChatCompletionsPost(X_API_TOKEN)

Chat Completions

Hermes AI Chat Completions (Streaming).  Proxies chat completion requests to the Hermes API Server with streaming response support.  **Request Body:** - **messages**: List of chat messages with role and content - **model**: (Optional) Model name to use - **stream**: (Optional) Enable streaming, defaults to true - **session_id**: (Optional) Session ID for conversation continuity - Any other parameters supported by the Hermes API  **Response:** - SSE stream with chat completion chunks - X-Hermes-Session-Id header for session tracking

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getHermesApi();
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.chatCompletionsHermesChatCompletionsPost(X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling HermesApi->chatCompletionsHermesChatCompletionsPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**JsonObject**](JsonObject.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **hermesHealthCheckHermesHealthGet**
> BuiltMap<String, JsonObject> hermesHealthCheckHermesHealthGet(X_API_TOKEN)

Hermes Health Check

Check Hermes AI service health status.  Returns configuration status and connectivity information.

### Example
```dart
import 'package:novel_api/api.dart';

final api = NovelApi().getHermesApi();
final String X_API_TOKEN = X_API_TOKEN_example; // String | 

try {
    final response = api.hermesHealthCheckHermesHealthGet(X_API_TOKEN);
    print(response);
} catch on DioException (e) {
    print('Exception when calling HermesApi->hermesHealthCheckHermesHealthGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **X_API_TOKEN** | **String**|  | [optional] 

### Return type

[**BuiltMap&lt;String, JsonObject&gt;**](JsonObject.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

