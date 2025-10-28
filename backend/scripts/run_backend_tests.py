#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
后端测试运行脚本
提供完整的测试套件执行、报告生成和性能分析
"""

import os
import sys
import subprocess
import argparse
import time
import json
import asyncio
from pathlib import Path
from typing import Dict, List, Any


class BackendTestRunner:
    """后端测试运行器"""

    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.backend_dir = self.project_root / "backend"
        self.reports_dir = self.project_root / "test-reports"
        self.reports_dir.mkdir(exist_ok=True)

        # 测试分类
        self.test_categories = {
            "unit": {
                "name": "单元测试",
                "command": ["python", "-m", "pytest", "tests/unit"],
                "timeout": 300,  # 5分钟
                "files": [
                    "test_cache_api.py",
                    "test_cache_database.py",
                ],
            },
            "integration": {
                "name": "集成测试",
                "command": ["python", "-m", "pytest", "tests/integration"],
                "timeout": 600,  # 10分钟
                "files": [
                    "test_api_endpoints.py",
                    "test_real_crawlers.py",
                    "test_crawler_cache_integration.py",
                    "test_cache_e2e.py",
                ],
            },
            "performance": {
                "name": "性能测试",
                "command": ["python", "-m", "pytest", "tests/performance"],
                "timeout": 1200,  # 20分钟
                "files": [
                    "test_cache_performance.py",
                ],
                "markers": ["performance"],
            },
            "e2e": {
                "name": "端到端测试",
                "command": ["python", "-m", "pytest", "tests/e2e"],
                "timeout": 600,  # 10分钟
                "files": [
                    "test_cache_e2e.py",
                ],
            },
            "all": {
                "name": "所有测试",
                "command": ["python", "-m", "pytest", "tests/"],
                "timeout": 1800,  # 30分钟
                "files": "all tests",
            },
        }

    def run_test_category(self, category: str) -> Dict[str, Any]:
        """运行指定类别的测试"""
        if category not in self.test_categories:
            print(f"❌ 未知的测试类别: {category}")
            return {"success": False, "error": f"Unknown test category: {category}"}

        config = self.test_categories[category]
        print(f"\n🚀 运行 {config['name']}...")
        print(f"📁 超时限制: {config['timeout']}秒")

        start_time = time.time()
        result = self._execute_command(config['command'], config['timeout'])
        end_time = time.time()

        duration = end_time - start_time

        # 解析测试结果
        test_results = self._parse_test_output(result['stdout'], result['stderr'])

        return {
            "category": category,
            "config": config,
            "success": result['returncode'] == 0,
            "duration": duration,
            "results": test_results,
            "output": result['stdout'],
            "errors": result['stderr'],
        }

    def _execute_command(self, command: List[str], timeout: int) -> Dict[str, Any]:
        """执行命令并返回结果"""
        try:
            print(f"🔄 执行命令: {' '.join(command)}")

            # 在后端目录中执行
            process = subprocess.Popen(
                command,
                cwd=self.backend_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                shell=False,
            )

            # 设置超时
            try:
                stdout, stderr = process.communicate(timeout=timeout)
                returncode = process.returncode
            except subprocess.TimeoutExpired:
                process.kill()
                print(f"⏱️ 命令超时，正在终止...")
                stdout, stderr = process.communicate(timeout=5)
                returncode = -1
            except:
                stdout, stderr = process.communicate(timeout=5)
                returncode = -2

        except Exception as e:
            print(f"💥 命令执行异常: {e}")
            return {
                "returncode": -1,
                "stdout": "",
                "stderr": str(e),
                "exception": True,
            }

        return {
            "returncode": returncode,
            "stdout": stdout,
            "stderr": stderr,
            "exception": False,
        }

    def _parse_test_output(self, stdout: str, stderr: str) -> Dict[str, Any]:
        """解析pytest输出并提取测试结果"""
        try:
            # 提取测试统计
            lines = (stdout + stderr).split('\n')

            test_results = {
                "total": 0,
                "passed": 0,
                "failed": 0,
                "skipped": 0,
                "errors": 0,
                "duration": 0.0,
                "failed_tests": [],
                "passed_tests": [],
                "skipped_tests": [],
            }

            for line in lines:
                line = line.strip()
                if not line:
                    continue

                # 解析pytest的总结行
                if "tests discovered" in line:
                    # pytest 5.x 的格式
                    match = line.split("tests discovered")[0]
                    if match:
                        test_results["total"] = int(match.split()[0])

                elif "passed in " in line or ("passed in" in line and "failed in" in line):
                    # pytest 5.x+ 的详细格式
                    parts = line.split(",")
                    for part in parts:
                        part = part.strip()
                        if "passed in" in part:
                            count = part.split("=")[1] if "=" in part else 1
                            test_results["passed"] += int(count)
                        elif "failed in" in part:
                            count = part.split("=")[1] if "=" in part else 1
                            test_results["failed"] += int(count)
                        elif "skipped" in part:
                            count = part.split("=")[1] if "=" in part else 1
                            test_results["skipped"] += int(count)
                        elif "errors" in part:
                            count = part.split("=")[1] if "=" in part else 1
                            test_results["errors"] += int(count)
                        elif "duration" in part:
                            duration_str = part.split("=")[1].strip()
                            if duration_str.endswith("s"):
                                test_results["duration"] = float(duration_str[:-1])
                            else:
                                # 处理 HH:MM:SS 格式
                                time_parts = duration_str.split(":")
                                if len(time_parts) == 3:
                                    hours = int(time_parts[0])
                                    minutes = int(time_parts[1])
                                    seconds = int(time_parts[2])
                                    test_results["duration"] = hours * 3600 + minutes * 60 + seconds
                                elif len(time_parts) == 2:
                                    minutes = int(time_parts[0])
                                    seconds = int(time_parts[1])
                                    test_results["duration"] = minutes * 60 + seconds

                # 提取失败的测试信息
                if "FAILED " in line or "ERROR " in line:
                    test_name = self._extract_test_name(line)
                    if test_name:
                        test_results["failed_tests"].append(test_name)

            return test_results

        except Exception as e:
            print(f"⚠️ 解析测试输出时出错: {e}")
            return {
                "total": 0,
                "passed": 0,
                "failed": 0,
                "skipped": 0,
                "errors": 0,
                "duration": 0.0,
                "failed_tests": [],
                "passed_tests": [],
                "skipped_tests": [],
                "parsing_error": str(e),
            }

    def _extract_test_name(self, line: str) -> str:
        """从pytest输出中提取测试名称"""
        try:
            # 查找测试名称模式
            patterns = [
                r"test_(.*?)\.py::",
                r"::test_(.*?)\s+",
                r"FAILED (test_.*?)\s+",
                r"ERROR (test_.*?)\s+",
            ]

            for pattern in patterns:
                match = re.search(pattern, line)
                if match:
                    return match.group(1)
            return ""
        except:
            return ""

    def generate_html_report(self, results: List[Dict[str, Any]]) -> str:
        """生成HTML测试报告"""
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")

        html = f"""
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>后端缓存功能测试报告 - {timestamp}</title>
    <style>
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0, 0, 0.1);
        }}
        .header {{
            text-align: center;
            margin-bottom: 30px;
            padding-bottom: 20px;
            border-bottom: 2px solid #e0e0e0;
        }}
        .header h1 {{
            color: #2196F3;
            font-size: 28px;
            margin: 0;
        }}
        .header p {{
            color: #666;
            font-size: 16px;
            margin: 10px 0;
        }}
        .summary {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }}
        .summary-item {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            font-weight: bold;
        }}
        .summary-item .number {{
            font-size: 36px;
            font-weight: bold;
        }}
        .summary-item .label {{
            font-size: 16px;
            margin-top: 5px;
        }}
        .test-categories {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }}
        .category-card {{
            border: 1px solid #ddd;
            border-radius: 8px;
            overflow: hidden;
        }}
        .category-header {{
            background: #f8f9fa;
            padding: 15px;
            font-weight: bold;
            border-bottom: 1px solid #e9ecef;
        }}
        .category-content {{
            padding: 20px;
        }}
        .status {{
            display: flex;
            justify-content: space-between;
            margin-bottom: 10px;
            font-size: 14px;
        }}
        .status-badge {{
            padding: 4px 12px;
            border-radius: 20px;
            font-weight: bold;
        }}
        .status-success {{
            background: #4CAF50;
            color: white;
        }}
        .status-failed {{
            background: #F44336;
            color: white;
        }}
        .details {{
            margin-top: 15px;
        }}
        .detail-item {{
            padding: 10px 15px;
            margin: 5px 0;
            border-radius: 4px;
            background: #f8f9fa;
            border-left: 3px solid #2196F3;
        }}
        .detail-item.success {{
            border-left-color: #4CAF50;
        }}
        .detail-item.failed {{
            border-left-color: #F44336;
        }}
        .charts {{
            margin-top: 30px;
        }}
        .chart {{
            background: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 2px 10px rgba(0, 0, 0.1);
        }}
        .progress-bar {{
            height: 20px;
            background-color: #e0e0e0;
            border-radius: 10px;
            overflow: hidden;
        }}
        .progress-fill {{
            height: 100%;
            background: linear-gradient(90deg, #4CAF50 0%, #45a049 100%);
            transition: width 0.3s ease-in-out;
        }}
        .performance-metrics {{
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-top: 20px;
        }}
        .metric {{
            text-align: center;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 8px;
        }}
        .metric .value {{
            font-size: 24px;
            font-weight: bold;
            color: #2196F3;
        }}
        .metric .label {{
            color: #666;
            margin-top: 5px;
        }}
        @media print {{
            body {{
                padding: 10px;
            }}
            .container {{
                padding: 15px;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔧 Novel Builder 后端缓存功能测试报告</h1>
            <p>生成时间: {timestamp}</p>
        </div>

        <div class="summary">
            <div class="summary-item">
                <div class="number">⚡️</div>
                <div class="label">
                    <div>总测试数</div>
                    <div>{len(results)}</div>
                </div>
            </div>
            <div class="summary-item">
                <div class="number">✅</div>
                <div class="label">
                    <div>通过测试</div>
                    <div>{sum(r.get('success', 0) for r in results)}</div>
                </div>
            </div>
            <div class="summary-item">
                <div class="number">❌</div>
                <div class="label">
                    <div>失败测试</div>
                    <div>{sum(r.get('failed', 0) for r in results)}</div>
                </div>
            </div>
            <div class="summary-item">
                <div class="number">⏱️</div>
                <div class="label">
                    <div>跳过测试</div>
                    <div>{sum(r.get('skipped', 0) for r in results)}</div>
                </div>
            </div>
            <div class="summary-item">
                <div class="number">⚠️</div>
                <div class="label">
                    <div>错误测试</div>
                    <div>{sum(r.get('errors', 0) for r in results)}</div>
                </div>
            </div>
        </div>

        <div class="test-categories">
            <h2>📋 测试分类结果</h2>
        """

        # 每个测试类别的结果
        for result in results:
            category = result.get('category', 'unknown')
            config = self.test_categories.get(category, {})

            status_class = 'status-success' if result.get('success') else 'status-failed'
            status_text = '通过' if result.get('success') else '失败'

            total = result['results']['total']
            passed = result['results']['passed']
            failed = result['results']['failed']
            pass_rate = (passed / total * 100) if total > 0 else 0

            html += f"""
            <div class="category-card">
                <div class="category-header">
                    <h3>{config['name']}</h3>
                    <div class="status">
                        <span class="status-badge {status_class}">{status_text}</span>
                        <span>({passed}/{total} - {pass_rate:.1f}%)</span>
                    </div>
                </div>
                <div class="category-content">
                    <div class="status">
                        <div>⏱️ 状态: <span class="status-badge status-success">✓</span> {status_text}</span></div>
                        <div>⏱️ 耗时: {result['duration']:.1f}秒</div>
                        <div>📝 总数: <strong>{total}</strong></div>
                        <div>📊 成功率: <strong>{pass_rate:.1f}%</strong></div>
                    </div>
                    <div class="details">
                        <h4>测试结果详情</h4>
                        {self._generate_test_details_html(result['results'])}
                    </div>
                </div>
            </div>
        </div>

        <div class="charts">
            <h2>📊 性能指标</h2>
            <div class="performance-metrics">
                <div class="metric">
                    <div class="label">平均测试时间</div>
                    <div class="value">{sum(r['duration'] for r in results) / len(results):.2f}s</div>
                </div>
                <div class="metric">
                    <div class="label">最长测试时间</div>
                    <div class="value">{max(r['duration'] for r in results):.2f}s</div>
                </div>
            </div>
            <div class="performance-metrics">
                <div class="metric">
                    <div class="label">总测试覆盖</div>
                    <div class="value">{sum(r['results']['total'] for r in results)}</div>
                </div>
            </div>
            <div class="performance-metrics">
                <div class="metric">
                    <div class="label">测试通过率</div>
                    <div class="value">{sum(r['results']['passed']) / sum(r['results']['total']) * 100:.1f}%</div>
                </div>
            </div>
        </div>

        <div class="charts">
            <h2>📈 测试进度可视化</h2>
            <div class="chart">
                <div class="progress-bar">
                    <div class="progress-fill" style="width: {sum(r.get('success', 0) for r in results) / len(results) * 100}%"></div>
                </div>
                <p style="text-align: center; margin-top: 10px; color: #666;">
                    总体测试进度: {sum(r.get('success', 0) for r in results)}/{sum(r['results']['total'])}%
                </p>
            </div>
        </div>

        <div class="charts">
            <h2>📝 建议和后续行动</h2>
            <div style="background: #fff3cd; padding: 20px; border-radius: 8px; border-left: 4px solid #4CAF50;">
                <h4 style="color: #856404; margin: 0 0 10px 0;">💡 建议</h4>
                <ul style="margin-left: 20px; color: #666;">
        """

        html += f"""
        </div>
    </div>
</body>
</html>
        """

        # 保存HTML报告
        report_filename = f"backend_test_report_{int(time.time())}.html"
        report_path = self.reports_dir / report_filename

        with open(report_path, 'w', encoding='utf-8') as f:
            f.write(html)

        print(f"📄 HTML报告已保存: {report_path}")
        return report_path

    def _generate_test_details_html(self, test_results: Dict[str, Any]) -> str:
        """生成测试详情HTML"""
        html_parts = []

        failed_tests = test_results.get('failed_tests', [])

        if failed_tests:
            html_parts.append('<h4 style="color: #F44336; margin-top: 0;">❌ 失败的测试</h4>')

            for test_name in failed_tests:
                html_parts.append(f"""
                <div class="detail-item failed">
                    <h5>{test_name}</h5>
                    <p>❌ 测试失败，请检查错误日志并修复问题。</p>
                </div>
                """)
        else:
            html_parts.append('<p style="color: #4CAF50;">✅ 所有测试都通过了！</p>')

        return ''.join(html_parts)

    def generate_json_report(self, results: List[Dict[str, Any]]) -> str:
        """生成JSON测试报告"""
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")

        report = {
            "timestamp": timestamp,
            "summary": {
                "total_tests": sum(r.get('results', {}).get('total', 0) for r in results),
                "passed_tests": sum(r.get('results', {}).get('passed', 0) for r in results),
                "failed_tests": sum(r.get('results', {}).get('failed', 0) for r in results),
                "skipped_tests": sum(r.get('results', {}).get('skipped', 0) for r in results),
                "total_duration": sum(r.get('duration', 0.0) for r in results),
                "average_duration": sum(r.get('duration', 0.0) for r in results) / len(results),
                "max_duration": max(r.get('duration', 0.0) for r in results),
                "min_duration": min(r.get('duration', 0.0) for r in results),
            },
            "pass_rate": sum(r.get('results', {}).get('passed', 0) for r in results) / sum(r.get('results', {}).get('total', 0) for r in results) * 100 if sum(r.get('results', {}).get('total', 0) for r in results) > 0 else 0,
            "categories": {
                category: {
                    "config": self.test_categories[category],
                    "results": r['results'],
                    "success": r['success'],
                    "duration": r['duration'],
                    "total": r['results']['total'],
                    "passed": r['results']['passed'],
                    "failed": r['results']['failed'],
                    "errors": r['results']['errors'],
                    "skipped": r['results']['skipped'],
                    "pass_rate": (r['results']['passed'] / r['results']['total']) * 100 if r['results']['total'] > 0 else 0,
                }
                for category, r in zip(self.test_categories.keys(), results)
            },
        "performance_metrics": {
                "total_tests_run": sum(r.get('results', {}).get('total', 0) for r in results),
                "average_response_time": sum(r.get('results', {}).get('duration', 0.0) for r in results) / len(results),
                "max_response_time": max(r.get('results', {}).get('duration', 0.0) for r in results),
                "min_response_time": min(r.get('results', {}).get('duration', 0.0) for r in results),
                "total_coverage": sum(r.get('results', {}).get('total', 0) for r in results),
        }

        # 保存JSON报告
        report_filename = f"backend_test_report_{int(time.time())}.json"
        report_path = self.reports_dir / report_filename

        with open(report_path, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)

        print(f"📄 JSON报告已保存: {report_path}")
        return report_path

    def print_summary(self, results: List[Dict[str, Any]]):
        """打印测试摘要"""
        print(f"\n{'=' * 60}")
        print("📊 后端缓存功能测试摘要")
        print(f"{'=' * 60}")

        total_tests = sum(r.get('results', {}).get('total', 0) for r in results)
        passed_tests = sum(r.get('results', {}).get('passed', 0) for r in results)
        failed_tests = sum(r.get('results', {}).get('failed', 0) for r in results)
        skipped_tests = sum(r.get('results', {}).get('skipped', 0) for r in results)
        total_duration = sum(r.get('duration', 0.0) for r in results)

        if total_tests == 0:
            print("⚠️ 没有运行任何测试")
            return

        success_rate = (passed_tests / total_tests * 100) if total_tests > 0 else 0

        print(f"📈 测试执行统计:")
        print(f"   • 总测试数: {total_tests}")
        print(f"   • ✅ 通过: {passed_tests}")
        print(f"   • ❌ 失败: {failed_tests}")
        print(f"   • ⏱️ 跳过: {skipped_tests}")
        print(f"   • ⏱️ 耗时: {total_duration:.1f}s")
        print(f"   • 📊 平均耗时: {total_duration/len(results):.2f}s")
        print(f"   • 📈 通过率: {success_rate:.1f}%")

        print(f"\n📊 各类别详细结果:")
        for result in results:
            category = result['category']
            config = self.test_categories[category]
            success = result['success']
            duration = result['duration']
            total = result['results']['total']
            passed = result['results']['passed']
            failed = result['results']['failed']

            status = "✅ 成功" if success else "❌ 失败"
            print(f"   {status} {config['name']}:")
            print(f"      ⏱️ 耗时: {duration:.1f}s")
            print(f"      📊 通过率: {(passed/total*100):.1f}% ({passed}/{total})")

            if not success and result['results']['failed_tests']:
                print(f"      ❌ 失败数量: {len(result['results']['failed_tests'])}")
                if len(result['results']['failed_tests']) <= 5:
                    for failed_test in result['results']['failed_tests'][:5]:
                        print(f"        • {failed_test}")
                else:
                    print(f"        • 失败数量: {len(result['results']['failed_tests'])} (显示前5个)")
                    print(f"        • ... 还有 {len(result['results']['failed_tests']) - 5} 个失败测试")

        # 性能指标分析
        if duration > 0:
            avg_per_test = duration / total
            if avg_per_test > 10.0:
                print(f"⚠️  ⚠️ 平均测试时间较长: {avg_per_test:.1f}s")
            elif avg_per_test > 5.0:
                print(f"⚠️  ⚠️ 平均测试时间较长: {avg_per_test:.1f}s")
            elif avg_per_test > 3.0:
                print(f"⚠️  ⚠️ 平均测试时间较长: {avg_per_test:.1f}s")
            elif avg_per_test > 1.0:
                print(f"⚠️  ⚠️ 平均测试时间较长: {avg_per_test:.1f}s")

        if success_rate < 80:
            print(f"⚠️  ⚠️ 通过率较低: {success_rate:.1f}%")
        elif success_rate < 90:
            print(f"⚠️  ⚠️ 建议优化测试用例")
        elif success_rate < 100:
            print(f"ℹ️️  通过率良好，仍有改进空间")

        print(f"\n{'=' * 60}")

        return {
            "total_tests": total_tests,
            "passed_tests": passed_tests,
            "failed_tests": failed_tests,
            "success_rate": success_rate,
            "total_duration": total_duration,
        }

    def check_environment(self) -> bool:
        """检查测试环境"""
        print("🔍 检查测试环境...")

        # 检查Python环境
        try:
            import sys
            python_version = sys.version
            print(f"   ✅ Python版本: {python_version}")
        except Exception as e:
            print(f"   ❌ Python版本检查失败: {e}")
            return False

        # 检查必要的包
        required_packages = ['pytest', 'aiohttp', 'asyncio']
        missing_packages = []

        for package in required_packages:
            try:
                __import__(package)
                print(f"   ✅ {package} 可用")
            except ImportError:
                missing_packages.append(package)

        if missing_packages:
            print(f"   ❌ 缺少必要的包: {', '.join(missing_packages)}")
            print(f"   💡 请安装: pip install {' '.join(missing_packages)}")
            return False

        # 检查后端服务状态
        try:
            import asyncio
            import aiohttp
        except ImportError:
            print(f"   ⚠️ aiohttp包不可用，跳过网络相关测试")
            missing_packages.extend(['aiohttp'])

            backend_url = "http://localhost:8000"
            timeout = aiohttp.ClientTimeout(total=5)

            async def check_backend():
                try:
                    async with aiohttp.ClientSession() as session:
                        async with session.get(f"{backend_url}/health", timeout=timeout) as response:
                            if response.status == 200:
                                return True
                            return False
                except Exception as e:
                    print(f"   ⚠️ 后端服务检查失败: {e}")
                    return False

            return asyncio.run(check_backend())

        except Exception as e:
            print(f"   ⚠️ 网络检查异常: {e}")
            print(f"   💡 确保后端服务在测试前启动")
            return True

        return True

def main():
    """主函数"""
    parser = argparse.ArgumentParser(description="运行后端缓存功能测试")
    parser.add_argument(
        "--category",
        choices=list(TestRunner(project_root=".").test_categories.keys()),
        help="选择测试类别 (unit, integration, performance, e2e, all)",
        default="all"
    )
    parser.add_argument(
        "--output-format",
        choices=["html", "json", "both"],
        help="输出格式 (html, json, both)",
        default="both"
    )
    parser.add_argument(
        "--timeout",
        type=int,
        help="测试超时时间（秒）",
        default=None
    )
    parser.add_argument(
        "--no-env-check",
        action="store_true",
        help="跳过环境检查",
        default=False
    )

    args = parser.parse_args()

    # 获取项目根目录
    project_root = Path(__file__).parent.parent

    # 创建测试运行器
    runner = BackendTestRunner(project_root)

    # 环境检查
    if not args.no_env_check:
        if not runner.check_environment():
            print("\n💡 请解决环境问题后重新运行测试")
            sys.exit(1)

    print("🚀 开始执行后端测试...")

    # 执行测试
    if args.category == "all":
        # 运行所有测试类别
        results = []
        for category in runner.test_categories.keys():
            result = runner.run_test_category(category)
            results.append(result)
    else:
        # 运行指定类别
        result = runner.run_test_category(args.category)
        results.append(result)

    # 生成报告
    success_rate = sum(r.get('success_rate', 0) for r in results) / len(results) if len(results) > 0 else 0
    all_passed = all(r['success'] for r in results)

    print(f"\n🎉 测试执行完成!")

    if success_rate >= 80:
        print("🎉 后端缓存功能测试通过！")
        print(f"📈 总体通过率: {success_rate:.1f}%")
    elif success_rate >= 60:
        print("⚠️ 后端缓存功能测试基本通过")
        print(f"📈 总体通过率: {success_rate:.1f}%")
    else:
        print("❌ 后端缓存功能测试未通过")
        print(f"💡 请检查失败测试并修复问题")

    # 生成报告
    output_format = args.output_format
    timestamp = int(time.time())

    if output_format in ["html", "both"]:
        html_path = runner.generate_html_report(results)
        print(f"📄 HTML报告: {html_path}")

    if output_format in ["json", "both"]:
        json_path = runner.generate_json_report(results)
        print(f"📄 JSON报告: {json_path}")

    # 退出码
    sys.exit(0 if all_passed else 1)


if __name__ == "__main__":
    main()