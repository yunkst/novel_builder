#!/bin/bash

# Novel App E2E Test Runner
# This script sets up the environment and runs Playwright tests

set -e

echo "🚀 Starting Novel App E2E Tests..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    exit 1
fi

# Navigate to the novel_app directory
cd "$(dirname "$0")"

echo "📦 Installing Node.js dependencies..."
npm install

echo "🎭 Installing Playwright browsers..."
npm run test:e2e:install

echo "🔧 Checking Flutter dependencies..."
flutter pub get

echo "🌐 Starting Flutter web app in background..."
# Start Flutter web server
flutter run -d web-server --web-port=3000 --web-hostname=0.0.0.1 --release &
FLUTTER_PID=$!

echo "⏳ Waiting for Flutter app to start..."
sleep 10

# Check if Flutter app is running
if curl -s http://localhost:3000 > /dev/null; then
    echo "✅ Flutter app is running on http://localhost:3000"
else
    echo "❌ Flutter app failed to start. Please check the logs above."
    kill $FLUTTER_PID 2>/dev/null || true
    exit 1
fi

echo "🧪 Running Playwright E2E tests..."
if [ "$1" = "--ui" ]; then
    npm run test:e2e:ui
elif [ "$1" = "--headed" ]; then
    npm run test:e2e:headed
elif [ "$1" = "--debug" ]; then
    npm run test:e2e:debug
else
    npm run test:e2e
fi

TEST_EXIT_CODE=$?

# Cleanup
echo "🧹 Cleaning up..."
kill $FLUTTER_PID 2>/dev/null || true

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✅ All E2E tests passed!"
    echo "📊 Test report is available in: playwright-report/"
else
    echo "❌ Some E2E tests failed."
    echo "📊 Test report is available in: playwright-report/"
fi

exit $TEST_EXIT_CODE