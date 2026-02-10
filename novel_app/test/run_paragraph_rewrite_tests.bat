@echo off
REM 段落改写功能测试脚本 (Windows)
REM 用于快速验证Bug修复状态

echo ========================================
echo   段落改写功能测试套件
echo ========================================
echo.

REM 进入项目目录
cd /d "%~dp0\.." || exit /b 1

REM 检查Flutter环境
where flutter >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [错误] 未找到Flutter命令
    exit /b 1
)

echo [信息] Flutter版本:
flutter --version | findstr /C:"Flutter"
echo.

REM 运行基础功能测试
echo 运行: 基础功能测试
echo 文件: test/paragraph_rewrite_test.dart
echo ----------------------------------------
flutter test test/paragraph_rewrite_test.dart
set TEST1_RESULT=%ERRORLEVEL%
echo.

REM 运行Bug详细分析测试
echo 运行: Bug详细分析测试
echo 文件: test/paragraph_rewrite_bug_analysis_test.dart
echo ----------------------------------------
flutter test test/paragraph_rewrite_bug_analysis_test.dart
set TEST2_RESULT=%ERRORLEVEL%
echo.

REM 总结
echo ========================================
echo   测试总结
echo ========================================
echo.

if %TEST1_RESULT% equ 0 (
    echo [OK] 基础功能测试: 通过
) else (
    echo [FAIL] 基础功能测试: 失败
)

if %TEST2_RESULT% equ 0 (
    echo [OK] Bug详细分析测试: 通过
) else (
    echo [FAIL] Bug详细分析测试: 失败
)

echo.

if %TEST1_RESULT% equ 0 if %TEST2_RESULT% equ 0 (
    echo [成功] 所有测试通过！段落改写功能正常。
    exit /b 0
) else (
    echo [失败] 存在失败的测试，请查看详情。
    echo.
    echo 详细信息请查看:
    echo   - test/BUG_REPORT.md (完整报告)
    echo   - test/QUICK_REFERENCE.md (快速参考)
    exit /b 1
)
