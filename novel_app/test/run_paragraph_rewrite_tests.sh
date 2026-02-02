#!/bin/bash

# 段落改写功能测试脚本
# 用于快速验证Bug修复状态

echo "========================================"
echo "  段落改写功能测试套件"
echo "========================================"
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 测试计数
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 函数：运行测试并统计结果
run_test() {
    local test_file=$1
    local test_name=$2

    echo "运行: $test_name"
    echo "文件: $test_file"
    echo "----------------------------------------"

    # 运行测试并捕获输出
    output=$(flutter test "$test_file" 2>&1)
    result=$?

    # 统计测试数量
    if [[ $output =~ ([0-9]+)\ passed\ /\ ([0-9]+)\ failed ]]; then
        local passed=${BASH_REMATCH[1]}
        local failed=${BASH_REMATCH[2]}
        local total=$((passed + failed))

        TOTAL_TESTS=$((TOTAL_TESTS + total))
        PASSED_TESTS=$((PASSED_TESTS + passed))
        FAILED_TESTS=$((FAILED_TESTS + failed))

        echo "结果: $passed 通过 / $failed 失败"
    fi

    if [ $result -eq 0 ]; then
        echo -e "${GREEN}✓ 测试通过${NC}"
    else
        echo -e "${RED}✗ 测试失败${NC}"
        echo "$output" | tail -20
    fi

    echo ""
}

# 进入项目目录
cd "$(dirname "$0")/.." || exit 1

# 检查Flutter环境
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}错误: 未找到Flutter命令${NC}"
    exit 1
fi

echo -e "${YELLOW}Flutter版本:${NC}"
flutter --version | head -1
echo ""

# 运行测试套件
run_test "test/paragraph_rewrite_test.dart" "基础功能测试"
run_test "test/paragraph_rewrite_bug_analysis_test.dart" "Bug详细分析测试"

# 总结
echo "========================================"
echo "  测试总结"
echo "========================================"
echo -e "总测试数: $TOTAL_TESTS"
echo -e "${GREEN}通过: $PASSED_TESTS${NC}"
echo -e "${RED}失败: $FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ 所有测试通过！段落改写功能正常。${NC}"
    exit 0
else
    echo -e "${RED}✗ 存在失败的测试，请查看详情。${NC}"
    echo ""
    echo "详细信息请查看:"
    echo "  - test/BUG_REPORT.md (完整报告)"
    echo "  - test/QUICK_REFERENCE.md (快速参考)"
    exit 1
fi
