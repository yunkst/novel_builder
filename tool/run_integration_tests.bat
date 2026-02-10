@echo off
REM run_integration_tests.bat - 集成测试脚本（Windows版本）
REM 运行使用真实数据库的集成测试

echo ==========================================
echo 🗄️  运行数据库集成测试（真实SQLite）...
echo ==========================================
echo.

REM 切换到项目目录
cd /d "%~dp0..\novel_app"

REM 运行真实数据库测试
echo 运行真实数据库测试...
flutter test test/real_db/controllers/bookshelf_manager_real_db_test.dart ^
  test/real_db/controllers/chapter_action_handler_real_db_test.dart

if %ERRORLEVEL% NEQ 0 (
  echo.
  echo ❌ 真实数据库测试失败
  exit /b 1
)

REM 运行集成测试
echo.
echo 运行端到端集成测试...
flutter test test/integration/

if %ERRORLEVEL% EQU 0 (
  echo.
  echo ✅ 集成测试完成
) else (
  echo.
  echo ❌ 集成测试失败
  exit /b 1
)
