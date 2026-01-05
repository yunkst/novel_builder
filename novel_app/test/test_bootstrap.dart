import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 全局测试初始化
///
/// 在所有测试的 main() 函数开始时调用此函数
/// 统一处理测试环境的初始化，包括：
/// - Flutter测试绑定
/// - 数据库FFI初始化
///
/// 使用示例：
/// ```dart
/// void main() {
///   initTests(); // 统一初始化
///
///   group('MyTestGroup', () {
///     // 测试代码
///   });
/// }
/// ```
void initTests() {
  // 确保Flutter测试绑定已初始化
  TestWidgetsFlutterBinding.ensureInitialized();

  // 初始化SQLite FFI（用于测试环境）
  sqfliteFfiInit();

  // 设置数据库工厂为FFI实现
  databaseFactory = databaseFactoryFfi;

  // 打印初始化成功信息（仅在调试时）
  // ignore: avoid_print
  print('✅ 测试环境初始化完成 (SQLite FFI)');
}

/// 创建数据库测试专用的初始化函数
///
/// 对于需要使用数据库的测试，使用此函数
/// 它会额外配置数据库相关的设置
void initDatabaseTests() {
  // 先执行通用初始化
  initTests();

  // 可以在这里添加更多数据库测试特定配置
  // ignore: avoid_print
  print('✅ 数据库测试环境初始化完成');
}
