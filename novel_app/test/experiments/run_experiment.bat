@echo off
REM 数据库锁定实验运行脚本 (Windows版本)
REM 用于系统性测试不同的数据库隔离方案

setlocal enabledelayedexpansion

REM 设置脚本目录
set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..\..
set EXPERIMENT_FILE=%PROJECT_ROOT%\test\experiments\database_lock_experiment.dart
set REPORT_DIR=%PROJECT_ROOT%\test\experiments\reports
set TIMESTAMP=%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set REPORT_FILE=%REPORT_DIR%\experiment_report_%TIMESTAMP%.txt

REM 创建报告目录
if not exist "%REPORT_DIR%" mkdir "%REPORT_DIR%"

echo ========================================
echo   数据库锁定方案实验
echo ========================================
echo.

REM 检查实验文件是否存在
if not exist "%EXPERIMENT_FILE%" (
    echo 错误: 实验文件不存在: %EXPERIMENT_FILE%
    exit /b 1
)

REM 进入项目目录
cd /d "%PROJECT_ROOT%"

echo 步骤1: 清理之前的测试缓存...
flutter clean >nul 2>&1
if exist .dart_tool\build rmdir /s /q .dart_tool\build

echo 步骤2: 运行实验测试...
echo.

REM 运行实验测试
flutter test test\experiments\database_lock_experiment.dart > "%REPORT_FILE%" 2>&1

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [成功] 实验测试完成!
) else (
    echo.
    echo [失败] 实验测试失败!
    echo 请查看报告文件获取详细错误信息: %REPORT_FILE%
    exit /b 1
)

echo.
echo ========================================
echo 实验完成!
echo ========================================
echo.
echo 报告文件: %REPORT_FILE%
echo.
echo 下一步:
echo 1. 查看报告文件获取详细结果
echo 2. 根据结果填写实验分析表
echo 3. 选择最优方案应用到所有测试
echo.

REM 显示报告位置
dir "%REPORT_FILE%" | findstr "experiment_report"

endlocal
