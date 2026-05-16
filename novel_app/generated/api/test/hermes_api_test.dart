import 'package:test/test.dart';
import 'package:novel_api/novel_api.dart';


/// tests for HermesApi
void main() {
  final instance = NovelApi().getHermesApi();

  group(HermesApi, () {
    // Chat Completions
    //
    // Hermes AI Chat Completions (Streaming).  Proxies chat completion requests to the Hermes API Server with streaming response support.  **Request Body:** - **messages**: List of chat messages with role and content - **model**: (Optional) Model name to use - **stream**: (Optional) Enable streaming, defaults to true - **session_id**: (Optional) Session ID for conversation continuity - Any other parameters supported by the Hermes API  **Response:** - SSE stream with chat completion chunks - X-Hermes-Session-Id header for session tracking
    //
    //Future<JsonObject> chatCompletionsHermesChatCompletionsPost({ String X_API_TOKEN }) async
    test('test chatCompletionsHermesChatCompletionsPost', () async {
      // TODO
    });

    // Hermes Health Check
    //
    // Check Hermes AI service health status.  Returns configuration status and connectivity information.
    //
    //Future<BuiltMap<String, JsonObject>> hermesHealthCheckHermesHealthGet({ String X_API_TOKEN }) async
    test('test hermesHealthCheckHermesHealthGet', () async {
      // TODO
    });

  });
}
