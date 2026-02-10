#!/usr/bin/env bash

# 数据库锁定实验运行脚本
# 用于系统性测试不同的数据库隔离方案

set -e  # 遇到错误立即退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
EXPERIMENT_FILE="$PROJECT_ROOT/test/experiments/database_lock_experiment.dart"
REPORT_DIR="$PROJECT_ROOT/test/experiments/reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$REPORT_DIR/experiment_report_$TIMESTAMP.txt"

# 创建报告目录
mkdir -p "$REPORT_DIR"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  数据库锁定方案实验${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查实验文件是否存在
if [ ! -f "$EXPERIMENT_FILE" ]; then
    echo -e "${RED}错误: 实验文件不存在: $EXPERIMENT_FILE${NC}"
    exit 1
fi

# 进入项目目录
cd "$PROJECT_ROOT"

echo -e "${YELLOW}步骤1: 清理之前的测试缓存...${NC}"
flutter clean > /dev/null 2>&1 || true
rm -rf .dart_tool/build || true

echo -e "${YELLOW}步骤2: 运行实验测试...${NC}"
echo ""

# 创建报告头
cat > "$REPORT_FILE" << EOF
========================================
数据库锁定方案实验报告
========================================
实验时间: $(date '+%Y-%m-%d %H:%M:%S')
实验文件: $EXPERIMENT_FILE

========================================
实验设计
========================================

方案1: DatabaseService单例
- 直接使用全局单例
- 所有测试共享同一个数据库连接
- 预期: 可能会有锁冲突

方案2: DatabaseTestBase包装类
- 使用测试基类的包装服务
- 每个测试有独立的内存数据库
- 预期: 应该避免锁冲突

方案3: 纯内存数据库
- 完全独立的内存数据库
- 不依赖任何共享状态
- 预期: 应该完全隔离

方案4: 独立数据库实例
- 每次创建新的数据库实例
- 显式关闭连接
- 预期: 应该完全隔离

========================================
实验结果
========================================

EOF

# 运行实验测试,将输出追加到报告
if flutter test test/experiments/database_lock_experiment.dart 2>&1 | tee -a "$REPORT_FILE"; then
    echo ""
    echo -e "${GREEN}✅ 实验测试完成!${NC}"
else
    echo ""
    echo -e "${RED}❌ 实验测试失败!${NC}"
    echo -e "${YELLOW}请查看报告文件获取详细错误信息: $REPORT_FILE${NC}"
    exit 1
fi

# 追加总结部分到报告
cat >> "$REPORT_FILE" << EOF

========================================
实验分析
========================================

请根据上述测试结果,填写以下表格:

| 方案 | 测试1 | 测试2 | 测试3 | 有锁冲突? | 推荐指数 |
|------|-------|-------|-------|-----------|----------|
| 方案1 | [✅/❌] | [✅/❌] | [✅/❌] | [是/否] | [⭐~⭐⭐⭐⭐⭐] |
| 方案2 | [✅/❌] | [✅/❌] | [✅/❌] | [是/否] | [⭐~⭐⭐⭐⭐⭐] |
| 方案3 | [✅/❌] | [✅/❌] | [✅/❌] | [是/否] | [⭐~⭐⭐⭐⭐⭐] |
| 方案4 | [✅/❌] | [✅/❌] | [✅/❌] | [是/否] | [⭐~⭐⭐⭐⭐⭐] |

EOF

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}实验完成!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}报告文件: $REPORT_FILE${NC}"
echo ""
echo -e "${YELLOW}下一步:${NC}"
echo "1. 查看报告文件获取详细结果"
echo "2. 根据结果填写实验分析表"
echo "3. 选择最优方案应用到所有测试"
echo ""

# 显示报告位置
echo -e "${BLUE}报告位置:${NC}"
ls -lh "$REPORT_FILE"
