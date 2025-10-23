@echo off
REM Novel App E2E Test Runner for Windows

echo 🚀 Starting Novel App E2E Tests...

REM Check if Node.js is installed
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Node.js is not installed. Please install Node.js first.
    exit /b 1
)

REM Check if Flutter is installed
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Flutter is not installed. Please install Flutter first.
    exit /b 1
)

echo 📦 Installing Node.js dependencies...
call npm install

echo 🎭 Installing Playwright browsers...
call npm run test:e2e:install

echo 🔧 Checking Flutter dependencies...
call flutter pub get

echo 🌐 Starting Flutter web app in background...
REM Start Flutter web server
start /B flutter run -d web-server --web-port=3000 --web-hostname=0.0.0.1 --release

echo ⏳ Waiting for Flutter app to start...
timeout /t 10 /nobreak

REM Check if Flutter app is running
curl -s http://localhost:3000 >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ Flutter app is running on http://localhost:3000
) else (
    echo ❌ Flutter app failed to start. Please check the logs above.
    exit /b 1
)

echo 🧪 Running Playwright E2E tests...
if "%1"=="--ui" (
    call npm run test:e2e:ui
) else if "%1"=="--headed" (
    call npm run test:e2e:headed
) else if "%1"=="--debug" (
    call npm run test:e2e:debug
) else (
    call npm run test:e2e
)

set TEST_EXIT_CODE=%errorlevel%

REM Cleanup
echo 🧹 Cleaning up...
taskkill /f /im flutter.exe >nul 2>&1
taskkill /f /im dart.exe >nul 2>&1

if %TEST_EXIT_CODE% equ 0 (
    echo ✅ All E2E tests passed!
    echo 📊 Test report is available in: playwright-report\
) else (
    echo ❌ Some E2E tests failed.
    echo 📊 Test report is available in: playwright-report\
)

exit /b %TEST_EXIT_CODE%