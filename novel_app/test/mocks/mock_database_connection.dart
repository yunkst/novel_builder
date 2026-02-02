import 'package:sqflite/sqflite.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/core/interfaces/i_database_connection.dart';

/// Mock implementation of IDatabaseConnection for testing
///
/// 这个Mock类用于单元测试，提供IDatabaseConnection的模拟实现
/// 使用mockito自动生成Mock行为
class MockDatabaseConnection extends Mock implements IDatabaseConnection {}
