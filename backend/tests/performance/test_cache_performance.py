#!/usr/bin/env python3

"""
性能测试：缓存功能性能和压力测试
测试缓存系统在高负载下的表现
"""

import asyncio
import gc
import time

import aiohttp
import psutil
import pytest

from tests.factories import APITestDataFactory


class TestCachePerformance:
    """缓存功能性能和压力测试"""

    @pytest.fixture
    async def api_client(self):
        """创建高性能API客户端"""
        connector = aiohttp.TCPConnector(limit=0, force_close=True, enable_cleanup_closed=True)
        return aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=60, connect=5),
            connector=connector
        )

    @pytest.fixture
    def valid_headers(self):
        """有效认证头部"""
        return {"X-API-TOKEN": APITestDataFactory.create_valid_auth_token()}

    @pytest.fixture
    def base_url(self):
        """基础URL"""
        return "http://localhost:8000"

    @pytest.mark.performance
    async def test_api_response_time_benchmarks(self, api_client, valid_headers, base_url):
        """测试API响应时间基准"""
        # Given
        test_url = f"{base_url}/health"
        create_data = {"novel_url": "https://example.com/novel/benchmark-test"}

        # When - 测量各端点的响应时间
        response_times = {}
        endpoints = [
            "health",
            "api/cache/create",
            "api/cache/status/1",
            "api/cache/tasks",
            "api/cache/cancel/1"
        ]

        for endpoint in endpoints:
            times = []
            for _ in range(10):  # 每个端点测试10次
                start_time = time.time()

                if endpoint == "health":
                    async with api_client.get(test_url) as response:
                        assert response.status == 200
                        await response.text()
                elif endpoint == "api/cache/create":
                    async with api_client.post(f"{base_url}/{endpoint}", json=create_data, headers=valid_headers) as response:
                        # 201420状态都被认为是成功的性能测试
                        assert response.status in [200, 400]
                else:
                    async with api_client.get(f"{base_url}/{endpoint}", headers=valid_headers) as response:
                        assert response.status in [200, 404, 401]

                times.append(time.time() - start_time)

            response_times[endpoint] = {
                "min": min(times),
                "max": max(times),
                "avg": sum(times) / len(times),
                "p95": sorted(times)[int(0.95 * len(times))]
            }

        # Then - 性能基准断言
        # 健康状态检查应该非常快
        assert response_times["health"]["avg"] < 0.1  # 100ms
        assert response_times["health"]["p95"] < 0.2   # 200ms

        # 缓存API响应时间基准
        assert response_times["api/cache/create"]["avg"] < 0.5  # 500ms
        assert response_times["api/cache/create"]["p95"] < 1.0   # 1s

        assert response_times["api/cache/status/1"]["avg"] < 0.2  # 200ms
        assert response_times["api/cache/status/1"]["p95"] < 0.5   # 500ms

        assert response_times["api/cache/tasks"]["avg"] < 0.3  # 300ms
        assert response_times["api/cache/tasks"]["p95"] < 0.6   # 600ms

        print("\n📊 API响应时间基准 (ms):")
        for endpoint, times in response_times.items():
            print(f"  {endpoint}:")
            print(f"    平均: {times['avg']*1000:.1f}")
            print(f"    P95: {times['p95']*1000:.1f}")
            print(f"    最小: {times['min']*1000:.1f}")
            print(f"    最大: {times['max']*1000:.1f}")

    @pytest.mark.performance
    async def test_concurrent_cache_requests_performance(self, api_client, valid_headers, base_url):
        """测试并发缓存请求性能"""
        # Given
        concurrent_levels = [10, 50, 100, 200]
        results = {}

        for level in concurrent_levels:
            # When
            start_time = time.time()
            success_count = 0
            error_count = 0

            async def create_cache_task(task_index):
                try:
                    create_data = {"novel_url": f"https://example.com/novel/concurrent-{level}-{task_index}"}
                    async with api_client.post(f"{base_url}/api/cache/create", json=create_data, headers=valid_headers) as response:
                        if response.status in [200, 400, 422]:  # 成功或预期错误
                            return response.status
                        else:
                            return None
                except Exception:
                    return None

            # 并发执行请求
            tasks = [create_cache_task(i) for i in range(level)]
            responses = await asyncio.gather(*tasks, return_exceptions=True)

            end_time = time.time()

            # 计算结果
            for response in responses:
                if isinstance(response, int) and response in [200, 400, 422]:
                    success_count += 1
                else:
                    error_count += 1

            duration = end_time - start_time
            results[level] = {
                "duration": duration,
                "success_rate": success_count / level,
                "error_rate": error_count / level,
                "requests_per_second": level / duration
            }

        # Then - 性能分析
        for level, result in results.items():
            # 成功率应该保持较高水平
            assert result["success_rate"] > 0.95, f"并发级别 {level} 的成功率过低: {result['success_rate']}"

            # 响应时间应该随并发数合理增长
            if level > 10:
                prev_result = results[level // 2 * 2]  # 找到前一个并发级别
                # 响应时间增长应该小于线性
                time_ratio = result["duration"] / prev_result["duration"]
                assert time_ratio < 1.5, f"并发 {level} vs {level//2*2} 时间增长不合理: {time_ratio:.2f}x"

            # 每秒请求数应该有合理上限
            if level <= 50:
                assert result["requests_per_second"] > 50, f"并发 {level} 的吞吐量过低"
            elif level <= 100:
                assert result["requests_per_second"] > 30, f"并发 {level} 的吞吐量过低"

        print("\n📈 并发性能测试结果:")
        for level, result in results.items():
            print(f"  并发级别 {level}:")
            print(f"    耗时: {result['duration']:.2f}s")
            print(f"    成功率: {result['success_rate']:.1%}")
            print(f"    RPS: {result['requests_per_second']:.1f}")

    @pytest.mark.performance
    async def test_large_data_handling_performance(self, api_client, valid_headers, base_url):
        """测试大数据处理性能"""
        # Given - 模拟大量缓存任务和章节
        large_task_count = 100
        chapters_per_task = 1000

        # When - 创建大量任务（这个可能很慢，所以标记为performance）
        start_time = time.time()
        task_ids = []

        for i in range(large_task_count):
            create_data = {"novel_url": f"https://example.com/novel/large-data-{i}"}
            async with api_client.post(f"{base_url}/api/cache/create", json=create_data, headers=valid_headers) as response:
                if response.status == 200:
                    result = await response.json()
                    task_ids.append(result["task_id"])
                # 400错误也是预期的（因为URL可能无效）
                elif response.status == 400:
                    pass
                else:
                    pytest.fail(f"创建大数据任务 {i} 失败: {response.status}")

        # 等待一段时间让后端处理
        await asyncio.sleep(2)

        creation_time = time.time() - start_time

        # Then - 性能分析
        assert creation_time < 60, f"创建 {large_task_count} 个任务耗时过长: {creation_time:.2f}s"
        assert len(task_ids) > large_task_count * 0.8, f"任务创建成功率过低: {len(task_ids)}/{large_task_count}"

        # 测试获取大量任务列表的性能
        start_time = time.time()

        async with api_client.get(f"{base_url}/api/cache/tasks?limit={large_task_count}", headers=valid_headers) as response:
            assert response.status == 200
            result = await response.json()
            assert len(result["tasks"]) <= large_task_count

        list_time = time.time() - start_time
        assert list_time < 5, f"获取 {large_task_count} 个任务列表耗时过长: {list_time:.2f}s"

        print("\n📊 大数据性能测试结果:")
        print(f"  创建任务数: {large_task_count}")
        print(f"  创建耗时: {creation_time:.2f}s")
        print(f"  平均创建时间: {creation_time/large_task_count:.3f}s/任务")
        print(f"  任务列表耗时: {list_time:.2f}s")
        print(f"  成功创建任务: {len(task_ids)}")

    @pytest.mark.performance
    async def test_memory_usage_monitoring(self, api_client, valid_headers, base_url):
        """测试内存使用监控"""
        # Given
        initial_memory = psutil.Process().memory_info().rss / 1024 / 1024  # MB
        print(f"\n🧠 初始内存使用: {initial_memory:.1f} MB")

        # When - 执行内存密集操作
        memory_snapshots = []

        # 第一阶段：创建大量任务
        for batch in range(5):  # 5个批次，每批20个任务
            tasks = []
            for i in range(20):
                create_data = {"novel_url": f"https://example.com/novel/memory-test-{batch}-{i}"}
                tasks.append(api_client.post(f"{base_url}/api/cache/create", json=create_data, headers=valid_headers))

            await asyncio.gather(*tasks)

            # 记录内存快照
            gc.collect()
            current_memory = psutil.Process().memory_info().rss / 1024 / 1024
            memory_snapshots.append(current_memory)

            # 强制等待一小段时间
            await asyncio.sleep(0.5)

        # 第二阶段：获取任务列表
        for _ in range(10):  # 10次查询
            async with api_client.get(f"{base_url}/api/cache/tasks", headers=valid_headers) as response:
                await response.text()

        # 记录最终内存
        gc.collect()
        final_memory = psutil.Process().memory_info().rss / 1024 / 1024
        memory_snapshots.append(final_memory)

        # Then - 内存使用分析
        max_memory = max(memory_snapshots)
        memory_growth = final_memory - initial_memory

        # 内存增长应该在合理范围内
        assert memory_growth < 100, f"内存增长过多: {memory_growth:.1f} MB"

        # 最大内存使用应该有上限
        assert max_memory < 500, f"最大内存使用过多: {max_memory:.1f} MB"

        print("\n🧠 内存使用监控结果:")
        print(f"  初始内存: {initial_memory:.1f} MB")
        print(f"  最终内存: {final_memory:.1f} MB")
        print(f"  内存增长: {memory_growth:.1f} MB")
        print(f"  峰值内存: {max_memory:.1f} MB")
        print(f"  内存快照: {[f'{m:.1f}' for m in memory_snapshots]} MB")

    @pytest.mark.performance
    async def test_database_performance(self, api_client, valid_headers, base_url):
        """测试数据库性能"""
        # Given
        db_operation_times = []

        # When - 测试数据库密集操作
        for i in range(50):  # 50次数据库查询
            start_time = time.time()

            async with api_client.get(f"{base_url}/api/cache/tasks", headers=valid_headers) as response:
                if response.status == 200:
                    await response.json()

            end_time = time.time()
            db_operation_times.append(end_time - start_time)

        # Then - 性能分析
        avg_time = sum(db_operation_times) / len(db_operation_times)
        p95_time = sorted(db_operation_times)[int(0.95 * len(db_operation_times))]

        assert avg_time < 0.2, f"平均数据库查询时间过长: {avg_time:.3f}s"
        assert p95_time < 0.5, f"P95数据库查询时间过长: {p95_time:.3f}s"

        print("\n💾 数据库性能测试结果:")
        print(f"  查询次数: {len(db_operation_times)}")
        print(f"  平均时间: {avg_time:.3f}s")
        print(f"  P95时间: {p95_time:.3f}s")
        print(f"  最快: {min(db_operation_times):.3f}s")
        print(f"  最慢: {max(db_operation_times):.3f}s")

    @pytest.mark.performance
    async def test_websocket_performance(self, api_client, valid_headers, base_url):
        """测试WebSocket性能"""
        # Given
        create_data = {"novel_url": "https://example.com/novel/websocket-test"}

        async with api_client.post(f"{base_url}/api/cache/create", json=create_data, headers=valid_headers) as response:
            if response.status != 200:
                pytest.skip("无法创建WebSocket测试任务")
            result = await response.json()
            task_id = result["task_id"]

        # When - 测试WebSocket连接和消息性能
        ws_url = f"ws://localhost:8000/ws/cache/{task_id}"
        connection_time = None
        message_times = []

        try:
            start_time = time.time()
            async with api_client.ws_connect(ws_url) as ws:
                connection_time = time.time() - start_time

                # 测试连接时间
                assert connection_time < 1.0, f"WebSocket连接时间过长: {connection_time:.3f}s"

                # 测试消息接收性能
                message_count = 0
                timeout = aiohttp.ClientTimeout(total=5)

                while message_count < 10:  # 接收10个消息
                    try:
                        msg = await asyncio.wait_for(ws.receive_msg(), timeout=timeout)
                        msg_start = time.time()

                        if msg.type == aiohttp.WSMsgType.TEXT:
                            data = json.loads(msg.data)
                            message_times.append(time.time() - msg_start)
                            message_count += 1
                        elif msg.type == aiohttp.WSMsgType.ERROR or msg.type == aiohttp.WSMsgType.CLOSED:
                            break
                    except TimeoutError:
                        break

                if message_count >= 10 or ws.closed:
                    break

        except Exception as e:
            pytest.skip(f"WebSocket测试失败: {e}")

        # Then - WebSocket性能分析
        if connection_time:
            assert connection_time < 1.0, "WebSocket连接性能不达标"

        if message_times:
            avg_message_time = sum(message_times) / len(message_times)
            assert avg_message_time < 0.1, f"平均消息时间过长: {avg_message_time:.3f}s"

        print("\n🌐 WebSocket性能测试结果:")
        print(f"  连接时间: {connection_time:.3f}s" if connection_time else "N/A")
        print(f"  消息数量: {len(message_times)}")
        if message_times:
            print(f"  平均消息时间: {avg_message_time:.3f}s")
            print(f"  消息时间范围: {min(message_times):.3f}s - {max(message_times):.3f}s")

    @pytest.mark.stress
    async def test_sustained_load_stress_test(self, api_client, valid_headers, base_url):
        """测试持续负载压力测试"""
        # Given
        duration = 30  # 30秒压力测试
        rps_target = 10  # 目标每秒10个请求
        total_requests = int(duration * rps_target)

        # When
        start_time = time.time()
        success_count = 0
        error_count = 0
        response_times = []

        async def sustained_requests():
            while time.time() - start_time < duration:
                request_start = time.time()
                create_data = {"novel_url": f"https://example.com/novel/stress-test-{int(time.time())}"}

                try:
                    async with api_client.post(f"{base_url}/api/cache/create", json=create_data, headers=valid_headers) as response:
                        response_time = time.time() - request_start
                        response_times.append(response_time)

                        if response.status in [200, 400, 422]:
                            success_count += 1
                        else:
                            error_count += 1

                except Exception:
                    error_count += 1

                # 控制请求频率
                elapsed = time.time() - request_start
                sleep_time = max(0, (1.0 / rps_target) - elapsed)
                if sleep_time > 0:
                    await asyncio.sleep(sleep_time)

        # 启动多个并发工作线程模拟真实负载
        concurrent_workers = 3
        tasks = [sustained_requests() for _ in range(concurrent_workers)]
        await asyncio.gather(*tasks)

        end_time = time.time()
        actual_duration = end_time - start_time

        # Then - 压力测试分析
        total_requests_processed = success_count + error_count
        actual_rps = total_requests_processed / actual_duration

        # 验证持续性能
        assert actual_rps >= rps_target * 0.8, f"实际RPS {actual_rps:.1f} 低于目标 {rps_target} 的80%"
        assert success_count / total_requests_processed > 0.95, f"成功率过低: {success_count/total_requests_processed:.1%}"

        # 验证响应时间稳定性
        if response_times:
            avg_response_time = sum(response_times) / len(response_times)
            p95_response_time = sorted(response_times)[int(0.95 * len(response_times))]
            assert avg_response_time < 2.0, f"平均响应时间过长: {avg_response_time:.3f}s"
            assert p95_response_time < 5.0, f"P95响应时间过长: {p95_response_time:.3f}s"

        print(f"\n🔥 压力测试结果 (持续时间: {actual_duration:.1f}s):")
        print(f"  目标RPS: {rps_target}")
        print(f"  实际RPS: {actual_rps:.1f}")
        print(f"  总请求数: {total_requests_processed}")
        print(f"  成功请求: {success_count}")
        print(f"  失败请求: {error_count}")
        print(f"  成功率: {success_count/total_requests_processed:.1%}")
        if response_times:
            print(f"  平均响应时间: {avg_response_time:.3f}s")
            print(f"  P95响应时间: {p95_response_time:.3f}s")

    @pytest.mark.performance
    def test_system_resource_limits(self):
        """测试系统资源限制"""
        # Given
        cpu_count = psutil.cpu_count()
        memory_info = psutil.virtual_memory()

        print("\n💻 系统资源信息:")
        print(f"  CPU核心数: {cpu_count}")
        print(f"  总内存: {memory_info.total / 1024 / 1024:.1f} GB")
        print(f"  可用内存: {memory_info.available / 1024 / 1024:.1f} GB")
        print(f"  内存使用率: {(1 - memory_info.available/memory_info.total)*100:.1f}%")

        # 验证系统资源满足测试要求
        assert cpu_count >= 2, "系统CPU核心数不足"
        assert memory_info.total / 1024 / 1024 >= 4, "系统内存不足 (需要至少4GB)"

        # When - 检查当前进程资源使用
        process = psutil.Process()
        process_cpu = process.cpu_percent(interval=1)
        process_memory = process.memory_info()
        process_threads = process.num_threads()

        # Then - 验证进程资源使用在合理范围
        assert process_memory.rss / 1024 / 1024 < 512, "进程内存使用过高: {process_memory.rss/1024/1024:.1f} MB"
        assert process_threads <= 20, "进程线程数过多: {process_threads}"

        print(f"  进程内存使用: {process_memory.rss / 1024 / 1024:.1f} MB")
        print(f"  进程CPU使用: {process_cpu:.1f}%")
        print(f"  进程线程数: {process_threads}")

    @pytest.mark.performance
    async def test_cache_service_resource_cleanup(self, api_client, valid_headers, base_url):
        """测试缓存服务资源清理"""
        # Given - 监控初始资源
        initial_memory = psutil.Process().memory_info().rss
        initial_threads = psutil.Process().num_threads()

        # When - 执行大量操作后清理
        task_ids = []

        # 创建100个任务
        for i in range(100):
            create_data = {"novel_url": f"https://example.com/novel/cleanup-{i}"}
            async with api_client.post(f"{base_url}/api/cache/create", json=create_data, headers=valid_headers) as response:
                if response.status == 200:
                    result = await response.json()
                    task_ids.append(result["task_id"])

        # 获取任务列表多次
        for _ in range(20):
            async with api_client.get(f"{base_url}/api/cache/tasks", headers=valid_headers) as response:
                if response.status == 200:
                    await response.text()

        # 强制垃圾回收
        gc.collect()

        # 等待一段时间让资源稳定
        await asyncio.sleep(2)

        # 监控清理后的资源
        final_memory = psutil.Process().memory_info().rss
        final_threads = psutil.Process().num_threads()

        # Then - 验证资源清理效果
        memory_diff = final_memory - initial_memory
        threads_diff = final_threads - initial_threads

        print("\n🧹 资源清理测试:")
        print(f"  初始内存: {initial_memory / 1024 / 1024:.1f} MB")
        print(f"  最终内存: {final_memory / 1024 / 1024:.1f} MB")
        print(f"  内存差异: {memory_diff / 1024 / 1024:.1f} MB")
        print(f"  初始线程: {initial_threads}")
        print(f"  最终线程: {final_threads}")
        print(f"  线程差异: {threads_diff}")

        # 内存增长应该在合理范围内（考虑测试过程中产生的数据）
        assert memory_diff < 200, f"内存增长过多: {memory_diff / 1024 / 1024:.1f} MB"
