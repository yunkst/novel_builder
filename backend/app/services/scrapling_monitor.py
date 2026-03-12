#!/usr/bin/env python3
"""
性能监控模块

提供爬虫性能监控和统计分析功能。
支持请求耗时跟踪、成功率统计、错误分布分析等。
"""

import time
from typing import Dict, List
from collections import defaultdict
import threading
from datetime import datetime


class PerformanceMonitor:
    """
    性能监控器

    跟踪：
    - 请求耗时
    - 成功率
    - 错误分布
    - 站点统计
    - 并发统计

    使用示例：
        >>> monitor = PerformanceMonitor()
        >>> monitor.record_request(1.5, "biquge543")
        >>> monitor.record_success()
        >>> stats = monitor.get_stats()
        >>> print(f"平均耗时: {stats['average_time']:.2f}s")
    """

    def __init__(self):
        """初始化监控器"""
        self.request_times: List[Dict[str, float]] = []
        self.success_counts: Dict[str, int] = defaultdict(int)
        self.error_counts: Dict[str, Dict[str, int]] = defaultdict(lambda: defaultdict(int))
        self.concurrent_stats: Dict[str, int] = {
            "max_concurrent": 0,
            "average_concurrent": 0,
        }
        self.lock = threading.Lock()
        self.start_time: float | None = None

    def start_crawl(self):
        """
        开始爬取

        记录爬取开始时间，用于计算总耗时
        """
        self.start_time = time.time()

    def end_crawl(self):
        """
        结束爬取

        计算并记录总耗时
        """
        if self.start_time is None:
            return

        total_time = time.time() - self.start_time
        self.record_total_time(total_time)
        self.start_time = None

    def record_request(self, duration: float, site_id: str = "unknown"):
        """
        记录请求

        Args:
            duration: 请求耗时（秒）
            site_id: 站点标识
        """
        with self.lock:
            request_info = {
                "duration": duration,
                "site_id": site_id,
                "timestamp": datetime.now().isoformat(),
            }
            self.request_times.append(request_info)

            # 更新站点统计
            self._update_site_stats(site_id, duration, success=True)

    def record_success(self, site_id: str = "unknown"):
        """
        记录成功请求

        Args:
            site_id: 站点标识
        """
        with self.lock:
            self.success_counts[site_id] += 1

    def record_error(self, error_type: str, site_id: str = "unknown", duration: float = 0):
        """
        记录错误

        Args:
            error_type: 错误类型（timeout/connection/http_error/parsing等）
            site_id: 站点标识
            duration: 错误发生时的请求耗时
        """
        with self.lock:
            self.error_counts[site_id][error_type] += 1

            # 更新站点统计
            self._update_site_stats(site_id, duration, success=False)

    def record_concurrent(self, concurrent_count: int):
        """
        记录并发数

        Args:
            concurrent_count: 当前并发数
        """
        with self.lock:
            self.concurrent_stats["max_concurrent"] = max(
                self.concurrent_stats["max_concurrent"],
                concurrent_count
            )
            # 计算平均值（简化计算）
            self.concurrent_stats["average_concurrent"] = (
                (self.concurrent_stats["average_concurrent"] * 0.9 + concurrent_count * 0.1)
                if self.concurrent_stats["average_concurrent"] > 0
                else concurrent_count
            )

    def record_total_time(self, duration: float):
        """
        记录总爬取时间

        Args:
            duration: 总耗时（秒）
        """
        with self.lock:
            # 可以扩展为更复杂的统计
            pass

    def _update_site_stats(self, site_id: str, duration: float, success: bool):
        """
        更新站点统计信息

        Args:
            site_id: 站点标识
            duration: 请求耗时
            success: 是否成功
        """
        # 站点级统计可以通过扩展实现
        pass

    def get_stats(self) -> Dict[str, any]:
        """
        获取统计信息

        Returns:
            dict: 包含所有统计信息
                - total_requests: 总请求数
                - total_errors: 总错误数
                - success_rate: 成功率
                - average_time: 平均耗时
                - error_distribution: 错误分布
                - site_stats: 站点统计
                - concurrent_stats: 并发统计
                - total_time: 总爬取时间
        """
        with self.lock:
            # 计算总请求数
            total_requests = len(self.request_times)

            # 计算总错误数
            total_errors = sum(
                sum(site_errors.values())
                for site_errors in self.error_counts.values()
            )

            # 计算成功率
            success_rate = (
                (total_requests - total_errors) / total_requests * 100
                if total_requests > 0
                else 0
            )

            # 计算平均耗时
            durations = [req["duration"] for req in self.request_times]
            average_time = sum(durations) / len(durations) if durations else 0

            # 整理错误分布
            error_distribution = {}
            for site_id, site_errors in self.error_counts.items():
                if site_errors:
                    error_distribution[site_id] = {
                        error_type: count
                        for error_type, count in site_errors.items()
                    }

            # 按时间分组的统计
            time_groups = self._group_by_time(durations)
            time_distribution = {
                "under_1s": len(time_groups.get(0, [])),
                "under_5s": len(time_groups.get(0, []) + time_groups.get(1, []) + time_groups.get(2, [])),
                "under_10s": len(time_groups.get(0, []) + time_groups.get(1, []) + time_groups.get(2, []) + time_groups.get(3, [])),
                "over_10s": len(time_groups.get(4, [])),
            }

            # 站点统计
            site_stats = {
                site_id: {
                    "requests": len([
                        req for req in self.request_times
                        if req["site_id"] == site_id
                    ]),
                    "successes": self.success_counts.get(site_id, 0),
                    "errors": sum(self.error_counts.get(site_id, {}).values()),
                    "success_rate": (
                        self.success_counts.get(site_id, 0)
                        / (
                            len([
                                req for req in self.request_times
                                if req["site_id"] == site_id
                            ])
                        ) * 100
                        if len([
                            req for req in self.request_times
                            if req["site_id"] == site_id
                        ]) > 0
                        else 0
                    ),
                }
                for site_id in set(
                    [req["site_id"] for req in self.request_times] +
                    list(self.success_counts.keys()) +
                    list(self.error_counts.keys())
                )
            }

            return {
                "total_requests": total_requests,
                "total_errors": total_errors,
                "success_rate": success_rate,
                "average_time": average_time,
                "error_distribution": error_distribution,
                "time_distribution": time_distribution,
                "concurrent_stats": self.concurrent_stats,
                "site_stats": site_stats,
                "total_time": sum(durations) if durations else 0,
            }

    def _group_by_time(self, durations: List[float]) -> Dict[int, List[float]]:
        """
        按时间分组

        Args:
            durations: 耗时列表

        Returns:
            dict: 分组后的耗时
        """
        groups = {0: [], 1: [], 2: [], 3: [], 4: []}

        for duration in durations:
            if duration < 1.0:
                groups[0].append(duration)
            elif duration < 5.0:
                groups[1].append(duration)
            elif duration < 10.0:
                groups[2].append(duration)
            else:
                groups[3].append(duration)

        return groups

    def reset(self):
        """
        重置所有统计信息
        """
        with self.lock:
            self.request_times.clear()
            self.success_counts.clear()
            self.error_counts.clear()
            self.concurrent_stats = {
                "max_concurrent": 0,
                "average_concurrent": 0,
            }
            self.start_time = None

    def get_summary(self) -> str:
        """
        获取统计摘要

        Returns:
            str: 可读的统计摘要
        """
        stats = self.get_stats()

        summary = f"""
=== 爬虫性能统计 ===

基本指标：
  总请求数: {stats['total_requests']}
  总错误数: {stats['total_errors']}
  成功率: {stats['success_rate']:.1f}%
  平均耗时: {stats['average_time']:.3f}秒

耗时分布：
  <1秒: {stats['time_distribution']['under_1s']} ({stats['time_distribution']['under_1s']/(stats['total_requests'])*100:.1f}%)
  <5秒: {stats['time_distribution']['under_5s']} ({stats['time_distribution']['under_5s']/(stats['total_requests'])*100:.1f}%)
  <10秒: {stats['time_distribution']['under_10s']} ({stats['time_distribution']['under_10s']/(stats['total_requests'])*100:.1f}%)
  >10秒: {stats['time_distribution']['over_10s']} ({stats['time_distribution']['over_10s']/(stats['total_requests'])*100:.1f}%)

并发统计：
  最大并发数: {stats['concurrent_stats']['max_concurrent']}
  平均并发数: {stats['concurrent_stats']['average_concurrent']:.1f}
        """

        return summary

    def export_stats(self, filepath: str):
        """
        导出统计信息到文件

        Args:
            filepath: 输出文件路径
        """
        import json

        stats = self.get_stats()

        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump({
                "timestamp": datetime.now().isoformat(),
                "stats": stats,
                "summary": self.get_summary(),
            }, f, ensure_ascii=False, indent=2)
