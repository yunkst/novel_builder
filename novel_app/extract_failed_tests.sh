#!/bin/bash
flutter test --no-pub 2>&1 | tee test_full_output.txt

# 提取编译失败的文件
echo "=== 编译失败的测试文件 ==="
grep "loading.*\.dart \[E\]" test_full_output.txt | sed 's/.*loading \(.*\) \[E\].*/\1/' | sort -u

# 提取运行时失败的测试(从文件名)
echo ""
echo "=== 运行时失败的测试文件 ==="
grep -A2 "Test failed" test_full_output.txt | grep "file://" | sed 's/.*file:\/\/\/\(.*\):.*/\1/' | sort -u | sed 's|/|\|g'

# 提取有 Skip 的文件
echo ""
echo "=== 包含跳过测试的文件 ==="
grep -B5 "  Skip:" test_full_output.txt | grep "loading.*\.dart" | sed 's/.*loading \(.*\)/\1/' | sort -u
