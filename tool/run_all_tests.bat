@echo off
REM run_all_tests.bat - 全面测试脚本（Windows版本）
REM 运行所有测试并生成覆盖率报告

echo ==========================================
echo 🧪 运行全部测试（Mock + 真实数据库 + 覆盖率）...
echo ==========================================
echo.

REM 切换到项目目录
cd /d "%~dp0..\novel_app"

REM 清理旧的覆盖率数据
echo 清理旧的覆盖率数据...
if exist coverage\lcov.info del coverage\lcov.info

echo.
echo ==========================================
echo 1️⃣  运行快速单元测试（Mock）...
echo ==========================================
call "%~dp0run_unit_tests.bat"

if %ERRORLEVEL% NEQ 0 (
  echo.
  echo ❌ 单元测试失败，终止执行
  exit /b 1
)

echo.
echo ==========================================
echo 2️⃣  运行数据库集成测试...
echo ==========================================
call "%~dp0run_integration_tests.bat"

if %ERRORLEVEL% NEQ 0 (
  echo.
  echo ❌ 集成测试失败，终止执行
  exit /b 1
)

echo.
echo ==========================================
echo 3️⃣  运行全量测试并生成覆盖率报告...
echo ==========================================
flutter test --coverage

if %ERRORLEVEL% NEQ 0 (
  echo.
  echo ❌ 全量测试失败
  exit /b 1
)

echo.
echo ==========================================
echo ✅ 全部测试完成
echo ==========================================
echo.
echo 测试结果总结：
echo   - 单元测试: ✅ 通过
echo   - 集成测试: ✅ 通过
echo   - 全量测试: ✅ 通过
echo   - 覆盖率数据: coverage\lcov.info
echo.
