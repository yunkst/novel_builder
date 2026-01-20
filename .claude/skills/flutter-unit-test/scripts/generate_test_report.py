#!/usr/bin/env python3
"""
Flutter 单元测试报告生成器

解析 Flutter 测试输出并生成格式化的测试报告。
"""

import re
import sys
from typing import List, Dict
from dataclasses import dataclass
from datetime import datetime


@dataclass
class TestCase:
    """测试用例数据类"""
    name: str
    status: str  # "+" for passed, "-" for failed
    duration: str = ""


@dataclass
class TestGroup:
    """测试组数据类"""
    name: str
    tests: List[TestCase]


def parse_flutter_test_output(output: str) -> List[TestGroup]:
    """
    解析 Flutter 测试输出

    示例输出格式：
    00:00 +0: CharacterExtractionService - 搜索章节测试
    00:00 +1: CharacterExtractionService - 搜索章节测试 searchChaptersByName 应该找到包含正式名称的章节
    00:00 +2: CharacterExtractionService - 搜索章节测试 searchChaptersByName 应该找到包含别名的章节
    """
    groups: Dict[str, TestGroup] = {}
    current_group = None

    for line in output.split('\n'):
        # 匹配测试行: 00:00 +1: GroupName TestName
        test_match = re.match(r'\d{2}:\d{2}\s+([+-])(\d+):\s+(.+)', line)
        if test_match:
            status, _, full_name = test_match.groups()
            status = "PASSED" if status == "+" else "FAILED"

            # 判断是组名还是测试用例
            if not any(c in full_name for c in ['应该', 'should', 'when', 'when ']):
                # 这是一个组名
                if full_name not in groups:
                    groups[full_name] = TestGroup(name=full_name, tests=[])
                current_group = groups[full_name]
            else:
                # 这是一个测试用例
                if current_group:
                    test_case = TestCase(name=full_name.strip(), status=status)
                    current_group.tests.append(test_case)

    return list(groups.values())


def generate_markdown_report(groups: List[TestGroup], total_tests: int = 0,
                            passed: int = 0, failed: int = 0,
                            duration: str = "0ms") -> str:
    """生成 Markdown 格式的测试报告"""
    report = []
    report.append("# Flutter 单元测试报告")
    report.append("")
    report.append(f"**生成时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report.append("")

    # 测试概览
    report.append("## 测试概览")
    report.append("")
    report.append(f"- **总测试数**: {total_tests} 个")
    report.append(f"- **通过**: {passed} 个")
    report.append(f"- **失败**: {failed} 个")
    report.append(f"- **执行时间**: {duration}")
    if total_tests > 0:
        pass_rate = (passed / total_tests) * 100
        report.append(f"- **通过率**: {pass_rate:.1f}%")
    report.append("")

    # 测试详情
    report.append("## 测试详情")
    report.append("")

    for group in groups:
        report.append(f"### {group.name}")
        report.append("")
        report.append("| 测试用例 | 场景描述 | 状态 |")
        report.append("|---------|---------|------|")

        for test in group.tests:
            # 提取场景描述（去掉"应该"之后的部分）
            scenario = ""
            if "应该" in test.name:
                parts = test.name.split("应该", 1)
                if len(parts) > 1:
                    scenario = parts[1].strip()
            else:
                scenario = test.name

            status_icon = "✅" if test.status == "PASSED" else "❌"
            report.append(f"| {test.name} | {scenario} | {status_icon} |")

        report.append("")

    # 覆盖率分析
    report.append("## 覆盖率分析")
    report.append("")
    report.append(f"- **测试组数量**: {len(groups)}")
    report.append(f"- **测试用例总数**: {total_tests}")
    report.append("")

    # 建议
    if failed > 0:
        report.append("## 建议与改进")
        report.append("")
        report.append(f"- ⚠️ 有 {failed} 个测试失败，请检查相关代码")
        report.append("- 确保所有边界情况和异常情况都已覆盖")
        report.append("")

    return "\n".join(report)


def main():
    """主函数"""
    if len(sys.argv) < 2:
        print("Usage: python generate_test_report.py <test_output_file> [output_report_file]")
        print("Or pipe test output: flutter test | python generate_test_report.py -")
        sys.exit(1)

    input_file = sys.argv[1]

    # 读取输入
    if input_file == "-":
        output = sys.stdin.read()
    else:
        with open(input_file, 'r', encoding='utf-8') as f:
            output = f.read()

    # 解析测试输出
    groups = parse_flutter_test_output(output)

    # 统计总数
    total_tests = sum(len(g.tests) for g in groups)
    passed = sum(1 for g in groups for t in g.tests if t.status == "PASSED")
    failed = total_tests - passed

    # 生成报告
    report = generate_markdown_report(
        groups=groups,
        total_tests=total_tests,
        passed=passed,
        failed=failed
    )

    # 输出报告
    if len(sys.argv) >= 3:
        output_file = sys.argv[2]
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(report)
        print(f"测试报告已生成: {output_file}")
    else:
        print(report)


if __name__ == "__main__":
    main()
