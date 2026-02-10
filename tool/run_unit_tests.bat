@echo off
REM run_unit_tests.bat - 快速单元测试脚本（Windows版本）
REM 运行使用 Mock 的单元测试（快速反馈）

echo ==========================================
echo 🚀 运行快速单元测试（Mock版本）...
echo ==========================================
echo.

REM 切换到项目目录
cd /d "%~dp0..\novel_app"

REM 运行单元测试
flutter test test/unit/controllers/chapter_loader_test.dart ^
  test/unit/services/ai_accompaniment_background_test.dart ^
  test/unit/services/dify_parsing_test.dart

if %ERRORLEVEL% EQU 0 (
  echo.
  echo ✅ 快速单元测试完成
) else (
  echo.
  echo ❌ 单元测试失败
  exit /b 1
)
