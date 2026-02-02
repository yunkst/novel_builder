import 'package:novel_api/novel_api.dart';
import 'package:built_collection/built_collection.dart';
import 'package:novel_app/services/api_service_wrapper.dart';

/// Mock辅助工具 - 为 ApiServiceWrapper 提供通用stub配置
///
/// 用途:
/// - 统一管理Mock Api Service的stub配置
/// - 避免在每个测试文件中重复配置
/// - 确保所有测试使用一致的Mock数据
class MockApiHelper {
  /// 配置 MockApiServiceWrapper 的常用stub
  ///
  /// 使用示例:
  /// ```dart
  /// setUp(() {
  ///   mockApiService = MockApiServiceWrapper();
  ///   MockApiHelper.setupCommonStubs(mockApiService);
  /// });
  /// ```
  static void setupCommonStubs(MockApiServiceWrapper mock) {
    // 为 getModels() 方法提供默认stub
    // 这个方法被 ModelSelector widget 使用
    when(mock.getModels()).thenAnswer((_) async {
      return ModelsResponse((b) => b
        ..text2img = BuiltList<WorkflowInfo>([
          WorkflowInfo((b) => b
            ..title = 'default_text2img_model'
            ..workflowId = 'default_t2i'),
        ])
        ..img2video = BuiltList<WorkflowInfo>([
          WorkflowInfo((b) => b
            ..title = 'default_img2video_model'
            ..workflowId = 'default_i2v'),
        ])).build;
    });
  }

  /// 配置空的模型列表stub
  static void setupEmptyModelsStub(MockApiServiceWrapper mock) {
    when(mock.getModels()).thenAnswer((_) async {
      return ModelsResponse((b) => b
        ..text2img = BuiltList<WorkflowInfo>()
        ..img2video = BuiltList<WorkflowInfo>()).build;
    });
  }

  /// 创建默认的 ModelsResponse
  static ModelsResponse createDefaultModelsResponse() {
    return ModelsResponse((b) => b
      ..text2img = BuiltList<WorkflowInfo>([
        WorkflowInfo((b) => b
          ..title = 'test_text2img_model'
          ..workflowId = 'test_t2i_id'),
      ])
      ..img2video = BuiltList<WorkflowInfo>([
        WorkflowInfo((b) => b
          ..title = 'test_img2video_model'
          ..workflowId = 'test_i2v_id'),
      ])).build;
  }
}
