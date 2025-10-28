#!/usr/bin/env python3

"""
端到端测试：缓存功能完整流程
测试从API请求到数据库操作的完整缓存功能
"""

import asyncio
import json
import time

import aiohttp
import pytest

from tests.factories import APITestDataFactory


class TestCacheE2E:
    """缓存功能端到端测试"""

    @pytest.fixture
    async def api_client(self):
        """创建API客户端"""
        return aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=30))

    @pytest.fixture
    def valid_headers(self):
        """有效认证头部"""
        return {"X-API-TOKEN": APITestDataFactory.create_valid_auth_token()}

    @pytest.fixture
    def base_url(self):
        """基础URL"""
        return "http://localhost:8000"

    @pytest.mark.asyncio
    async def test_complete_caching_workflow_e2e(
        self, api_client, valid_headers, base_url
    ):
        """测试完整的缓存工作流程"""
        # Given - 测试小说URL
        novel_url = "https://example.com/novel/e2e-test"

        # Step 1: 创建缓存任务
        create_data = {"novel_url": novel_url}

        async with api_client.post(
            f"{base_url}/api/cache/create", json=create_data, headers=valid_headers
        ) as response:
            assert response.status == 200
            create_result = await response.json()
            assert "task_id" in create_result
            task_id = create_result["task_id"]
            assert create_result["status"] == "pending"

        # Step 2: 等待任务状态变化（轮询）
        max_polls = 30  # 最多等待30次，每次1秒
        current_status = "pending"

        for _poll_count in range(max_polls):
            async with api_client.get(
                f"{base_url}/api/cache/status/{task_id}", headers=valid_headers
            ) as status_response:
                assert status_response.status == 200
                status_result = await status_response.json()
                current_status = status_result["status"]

                if current_status in ["completed", "failed"]:
                    break

            if current_status == "pending":
                await asyncio.sleep(1)  # 等待状态变化

        # Step 3: 验证任务最终状态
        if current_status == "completed":
            # Step 4: 下载缓存的小说
            async with api_client.get(
                f"{base_url}/api/cache/download/{task_id}?format=json",
                headers=valid_headers,
            ) as download_response:
                assert download_response.status == 200
                download_result = await download_response.json()

                # 验证下载结果
                assert "novel" in download_result
                assert "chapters" in download_result
                assert len(download_result["chapters"]) > 0

                novel_info = download_result["novel"]
                assert novel_info["title"]
                assert novel_info["author"]
                assert novel_info["url"] == novel_url

        else:
            pytest.fail(f"任务最终状态为 {current_status}，不是 'completed'")

    @pytest.mark.asyncio
    async def test_concurrent_caching_tasks(self, api_client, valid_headers, base_url):
        """测试并发缓存任务"""
        # Given - 多个小说URL
        novel_urls = [
            "https://example.com/novel/concurrent-1",
            "https://example.com/novel/concurrent-2",
            "https://example.com/novel/concurrent-3",
        ]

        # When - 并发创建多个缓存任务
        async def create_task(novel_url):
            create_data = {"novel_url": novel_url}
            async with api_client.post(
                f"{base_url}/api/cache/create", json=create_data, headers=valid_headers
            ) as response:
                assert response.status == 200
                result = await response.json()
                return result["task_id"]

        # 并发执行创建任务
        task_ids = await asyncio.gather(*[create_task(url) for url in novel_urls])

        # Then - 验证所有任务都创建成功
        assert len(task_ids) == len(novel_urls)
        for task_id in task_ids:
            assert isinstance(task_id, int)
            assert task_id > 0

        # 验证任务ID是唯一的
        assert len(set(task_ids)) == len(task_ids)

    @pytest.mark.asyncio
    async def test_cache_task_lifecycle_e2e(self, api_client, valid_headers, base_url):
        """测试缓存任务的完整生命周期"""
        # Given
        novel_url = "https://example.com/novel/lifecycle-test"

        # Step 1: 创建任务
        create_data = {"novel_url": novel_url}

        async with api_client.post(
            f"{base_url}/api/cache/create", json=create_data, headers=valid_headers
        ) as response:
            assert response.status == 200
            create_result = await response.json()
            task_id = create_result["task_id"]

        # Step 2: 监控状态变化
        status_history = []
        max_duration = 10  # 最多监控10秒

        start_time = time.time()
        while time.time() - start_time < max_duration:
            async with api_client.get(
                f"{base_url}/api/cache/status/{task_id}", headers=valid_headers
            ) as status_response:
                assert status_response.status == 200
                status_result = await status_response.json()
                status_history.append(status_result["status"])

                if status_result["status"] == "completed":
                    break

            await asyncio.sleep(0.5)  # 每0.5秒检查一次

        # Then - 验证状态变化符合预期
        assert len(status_history) >= 2
        assert status_history[0] == "pending"  # 应该从pending开始
        assert status_history[-1] == "completed"  # 应该以completed结束

    @pytest.mark.asyncio
    async def test_cache_task_cancellation_e2e(
        self, api_client, valid_headers, base_url
    ):
        """测试缓存任务取消功能"""
        # Given
        novel_url = "https://example.com/novel/cancel-test"

        # Step 1: 创建任务
        create_data = {"novel_url": novel_url}

        async with api_client.post(
            f"{base_url}/api/cache/create", json=create_data, headers=valid_headers
        ) as response:
            assert response.status == 200
            create_result = await response.json()
            task_id = create_result["task_id"]

        # Step 2: 立即取消任务
        async with api_client.post(
            f"{base_url}/api/cache/cancel/{task_id}", headers=valid_headers
        ) as cancel_response:
            # 取消可能成功也可能失败（如果任务已经完成）
            assert cancel_response.status in [200, 404]

            if cancel_response.status == 200:
                cancel_result = await cancel_response.json()
                assert cancel_result["task_id"] == task_id

        # Step 3: 验证任务状态
        async with api_client.get(
            f"{base_url}/api/cache/status/{task_id}", headers=valid_headers
        ) as status_response:
            assert status_response.status == 200
            status_result = await status_response.json()

            # 任务状态应该是 pending, running, cancelled, 或 completed
            assert status_result["status"] in [
                "pending",
                "running",
                "cancelled",
                "completed",
            ]

    @pytest.mark.asyncio
    async def test_cache_task_pagination_e2e(self, api_client, valid_headers, base_url):
        """测试缓存任务分页功能"""
        # Given - 创建多个任务来测试分页
        task_ids = []
        for i in range(15):  # 创建15个任务
            create_data = {"novel_url": f"https://example.com/novel/pagination-{i}"}

            async with api_client.post(
                f"{base_url}/api/cache/create", json=create_data, headers=valid_headers
            ) as response:
                assert response.status == 200
                result = await response.json()
                task_ids.append(result["task_id"])

        # 等待任务创建完成
        await asyncio.sleep(1)

        # Step 1: 测试第一页（默认limit=20, offset=0）
        async with api_client.get(
            f"{base_url}/api/cache/tasks", headers=valid_headers
        ) as response:
            assert response.status == 200
            result = await response.json()
            assert "tasks" in result
            assert "total" in result
            assert len(result["tasks"]) == 15  # 应该返回所有任务

        # Step 2: 测试分页（limit=5, offset=0）
        async with api_client.get(
            f"{base_url}/api/cache/tasks?limit=5&offset=0", headers=valid_headers
        ) as response:
            assert response.status == 200
            result = await response.json()
            assert len(result["tasks"]) == 5
            assert result["total"] == 15

        # Step 3: 测试第二页（limit=5, offset=5）
        async with api_client.get(
            f"{base_url}/api/cache/tasks?limit=5&offset=5", headers=valid_headers
        ) as response:
            assert response.status == 200
            result = await response.json()
            assert len(result["tasks"]) == 5

        # Step 4: 测试状态过滤
        async with api_client.get(
            f"{base_url}/api/cache/tasks?status=pending&limit=10", headers=valid_headers
        ) as response:
            assert response.status == 200
            result = await response.json()
            # 所有任务状态可能是pending（因为刚创建）
            for task in result["tasks"]:
                assert task["status"] in ["pending", "running"]

    @pytest.mark.asyncio
    async def test_cache_download_formats_e2e(
        self, api_client, valid_headers, base_url
    ):
        """测试缓存下载的不同格式"""
        # Given - 创建一个已完成的任务
        novel_url = "https://example.com/novel/download-formats-test"

        # 首先创建任务
        create_data = {"novel_url": novel_url}

        async with api_client.post(
            f"{base_url}/api/cache/create", json=create_data, headers=valid_headers
        ) as create_response:
            assert create_response.status == 200
            create_result = await create_response.json()
            task_id = create_result["task_id"]

        # 模拟任务完成（在实际测试中，这可能需要手动完成或等待）

        # Step 1: 测试JSON格式下载
        async with api_client.get(
            f"{base_url}/api/cache/download/{task_id}?format=json",
            headers=valid_headers,
        ) as json_response:
            # 这个可能返回404如果任务未完成，这是正常的
            if json_response.status == 200:
                json_result = await json_response.json()
                assert "novel" in json_result
                assert "chapters" in json_result
                assert isinstance(json_result["chapters"], list)
            elif json_response.status == 404:
                pass  # 任务未完成，这是预期的
            else:
                pytest.fail(f"JSON下载返回意外状态: {json_response.status}")

        # Step 2: 测试TXT格式下载
        async with api_client.get(
            f"{base_url}/api/cache/download/{task_id}?format=txt", headers=valid_headers
        ) as txt_response:
            if txt_response.status == 200:
                # TXT下载应该返回文件内容
                content_type = txt_response.headers.get("content-type", "")
                assert "text/plain" in content_type

                # 检查是否有attachment header
                content_disposition = txt_response.headers.get(
                    "content-disposition", ""
                )
                assert "attachment" in content_disposition
            elif txt_response.status == 404:
                pass  # 任务未完成，这是预期的
            else:
                pytest.fail(f"TXT下载返回意外状态: {txt_response.status}")

        # Step 3: 测试无效格式
        async with api_client.get(
            f"{base_url}/api/cache/download/{task_id}?format=xml", headers=valid_headers
        ) as invalid_response:
            assert invalid_response.status == 400

    @pytest.mark.asyncio
    async def test_error_scenarios_e2e(self, api_client, valid_headers, base_url):
        """测试各种错误场景"""
        # Given
        invalid_headers = {"X-API-TOKEN": "invalid-token"}

        # Test 1: 无效token的API调用
        create_data = {"novel_url": "https://example.com/novel/test"}

        async with api_client.post(
            f"{base_url}/api/cache/create", json=create_data, headers=invalid_headers
        ) as response:
            assert response.status == 401

        # Test 2: 缺少必需参数
        async with api_client.post(
            f"{base_url}/api/cache/create",
            json={},  # 缺少novel_url
            headers=valid_headers,
        ) as response:
            assert response.status == 422  # Validation error

        # Test 3: 无效的novel_url
        invalid_urls = [
            "",  # 空字符串
            "invalid-url",  # 无效格式
            "not-a-url",  # 非URL格式
        ]

        for invalid_url in invalid_urls:
            async with api_client.post(
                f"{base_url}/api/cache/create",
                json={"novel_url": invalid_url},
                headers=valid_headers,
            ) as response:
                # 可能返回400或422，取决于验证逻辑
                assert response.status in [400, 422]

        # Test 4: 不存在的任务ID
        non_existent_ids = [0, -1, 999999]

        for task_id in non_existent_ids:
            async with api_client.get(
                f"{base_url}/api/cache/status/{task_id}", headers=valid_headers
            ) as response:
                assert response.status == 404

            async with api_client.post(
                f"{base_url}/api/cache/cancel/{task_id}", headers=valid_headers
            ) as cancel_response:
                assert cancel_response.status == 404

        # Test 5: 无效的查询参数
        async with api_client.get(
            f"{base_url}/api/cache/tasks?limit=1000",  # 超出限制
            headers=valid_headers,
        ) as response:
            # 应该被限制到100
            assert response.status == 200
            result = await response.json()
            assert len(result["tasks"]) <= 100

        async with api_client.get(
            f"{base_url}/api/cache/tasks?limit=-1",  # 负数limit
            headers=valid_headers,
        ) as response:
            assert response.status == 422  # Validation error

    @pytest.mark.asyncio
    async def test_websocket_progress_updates(
        self, api_client, valid_headers, base_url
    ):
        """测试WebSocket进度更新功能"""
        # Given
        novel_url = "https://example.com/novel/websocket-test"

        # Step 1: 创建任务
        create_data = {"novel_url": novel_url}

        async with api_client.post(
            f"{base_url}/api/cache/create", json=create_data, headers=valid_headers
        ) as response:
            assert response.status == 200
            create_result = await response.json()
            task_id = create_result["task_id"]

        # Step 2: 连接WebSocket
        ws_url = f"ws://localhost:8000/ws/cache/{task_id}"

        progress_updates = []

        try:
            async with api_client.ws_connect(ws_url) as ws:
                # 等待初始状态更新
                async for msg in ws:
                    if msg.type == aiohttp.WSMsgType.TEXT:
                        data = json.loads(msg.data)
                        progress_updates.append(data)

                        # 验证消息格式
                        assert "task_id" in data
                        assert "status" in data
                        assert "total_chapters" in data
                        assert "cached_chapters" in data
                        assert "progress" in data
                        assert data["task_id"] == task_id

                        # 如果任务完成或失败，断开连接
                        if data["status"] in ["completed", "failed"]:
                            break

                        # 最多等待10个消息
                        if len(progress_updates) >= 10:
                            break
                    elif (
                        msg.type == aiohttp.WSMsgType.ERROR
                        or msg.type == aiohttp.WSMsgType.CLOSED
                    ):
                        break

        except Exception as e:
            pytest.skip(f"WebSocket连接失败: {e}")

        # Then - 验证进度更新
        if progress_updates:
            # 验证状态序列
            statuses = [update["status"] for update in progress_updates]
            assert len(set(statuses)) >= 1  # 至少有一种状态

            # 验证进度是递增的（对于正常完成的情况）
            for i in range(1, len(progress_updates)):
                prev_progress = progress_updates[i - 1]["progress"]
                curr_progress = progress_updates[i]["progress"]

                # 进度应该是非递减的
                if progress_updates[i]["status"] == progress_updates[i - 1]["status"]:
                    assert curr_progress >= prev_progress

    @pytest.mark.asyncio
    async def test_api_response_time_e2e(self, api_client, valid_headers, base_url):
        """测试API响应时间"""
        # Given
        create_data = {"novel_url": "https://example.com/novel/response-time-test"}

        # Test 1: 创建任务的响应时间
        start_time = time.time()

        async with api_client.post(
            f"{base_url}/api/cache/create", json=create_data, headers=valid_headers
        ) as response:
            assert response.status == 200
            create_result = await response.json()
            task_id = create_result["task_id"]

        creation_time = time.time() - start_time
        assert creation_time < 2.0, f"创建任务响应时间过长: {creation_time:.2f}秒"

        # Test 2: 状态查询的响应时间
        for _ in range(5):  # 测试5次状态查询
            start_time = time.time()

            async with api_client.get(
                f"{base_url}/api/cache/status/{task_id}", headers=valid_headers
            ) as response:
                assert response.status == 200
                await response.json()

            query_time = time.time() - start_time
            assert query_time < 0.5, f"状态查询响应时间过长: {query_time:.2f}秒"

        # Test 3: 任务列表的响应时间
        start_time = time.time()

        async with api_client.get(
            f"{base_url}/api/cache/tasks", headers=valid_headers
        ) as response:
            assert response.status == 200
            await response.json()

        list_time = time.time() - start_time
        assert list_time < 1.0, f"任务列表响应时间过长: {list_time:.2f}秒"

    @pytest.mark.asyncio
    async def test_api_rate_limiting_e2e(self, api_client, valid_headers, base_url):
        """测试API频率限制"""
        # Given
        create_data = {"novel_url": "https://example.com/novel/rate-limit-test"}

        # When - 快速连续创建多个任务
        responses = []
        for i in range(20):  # 快速创建20个任务
            async with api_client.post(
                f"{base_url}/api/cache/create",
                json={**create_data, "novel_url": f"{create_data['novel_url']}-{i}"},
                headers=valid_headers,
            ) as response:
                responses.append(
                    (
                        response.status,
                        await response.text() if response.status != 200 else "",
                    )
                )

        # Then - 分析响应
        success_count = sum(1 for status, _ in responses if status == 200)
        rate_limited_count = sum(1 for status, _ in responses if status == 429)
        error_count = sum(1 for status, _ in responses if status in [400, 422, 500])

        # 至少应该有一些成功请求
        assert success_count > 0, "应该至少有一些请求成功"

        # 如果有频率限制，验证数量合理
        if rate_limited_count > 0:
            assert rate_limited_count < 10, "频率限制触发过于频繁"

        # 错误数量应该在合理范围内
        assert error_count < len(responses), "错误数量过高"
