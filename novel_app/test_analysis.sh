#!/bin/bash
echo "=== 测试执行分析 ==="
flutter test 2>&1 | tee test_output.txt | tail -20

echo ""
echo "=== 测试统计 ==="
grep "Some tests failed" test_output.txt || grep "All tests passed" test_output.txt

echo ""
echo "=== 失败的测试 ==="
grep " \[E\]" test_output.txt | head -20

echo ""
echo "=== 数据库初始化问题 ==="
grep "databaseFactory" test_output.txt | head -5

echo ""
echo "=== 视频相关错误 ==="
grep "VideoPlayer" test_output.txt | head -5

echo ""
echo "=== 超时问题 ==="
grep "timed out" test_output.txt

rm test_output.txt
