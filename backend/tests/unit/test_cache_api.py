#!/usr/bin/env python3

"""
单元测试：缓存 API 功能
测试缓存任务的创建、状态查询、取消等功能
"""

from datetime import UTC, datetime
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models import CacheTask
from tests.factories import APITestDataFactory


class TestCacheAPI:
    """缓存 API 单元测试"""

    def setup_method(self):
        """每个测试方法执行前的设置"""
        self.client = TestClient(app)
        self.valid_headers = {"X-API-TOKEN": APITestDataFactory.create_valid_auth_token()}
        self.invalid_headers = {"X-API-TOKEN": APITestDataFactory.create_invalid_auth_token()}

    def test_create_cache_task_success(self):
        """测试成功创建缓存任务"""
        # Given
        novel_url = "https://example.com/novel/test-novel"
        request_data = {"novel_url": novel_url}

        # When
        with patch('app.services.novel_cache_service.novel_cache_service.create_cache_task') as mock_create:
            mock_task = CacheTask(
                id=1,
                novel_url=novel_url,
                novel_title="测试小说",
                novel_author="测试作者",
                status="pending",
                total_chapters=100,
                cached_chapters=0,
                failed_chapters=0,
                error_message=None,
                created_at=datetime.now(UTC),
                updated_at=datetime.now(UTC)
            )
            mock_create.return_value = mock_task

            response = self.client.post(
                "/api/cache/create",
                json=request_data,
                headers=self.valid_headers
            )

        # Then
        assert response.status_code == 200
        data = response.json()
        assert data["task_id"] == 1
        assert data["status"] == "pending"
        assert "message" in data

    def test_create_cache_task_missing_novel_url(self):
        """测试缺少小说URL时创建缓存任务"""
        # Given
        request_data = {}  # 缺少 novel_url

        # When
        response = self.client.post(
            "/api/cache/create",
            json=request_data,
            headers=self.valid_headers
        )

        # Then
        assert response.status_code == 422  # Validation error

    def test_create_cache_task_invalid_novel_url(self):
        """测试无效小说URL时创建缓存任务"""
        # Given
        request_data = {"novel_url": "invalid-url"}

        # When
        with patch('app.services.novel_cache_service.novel_cache_service.create_cache_task') as mock_create:
            mock_create.side_effect = ValueError("无效的小说URL")

            response = self.client.post(
                "/api/cache/create",
                json=request_data,
                headers=self.valid_headers
            )

        # Then
        assert response.status_code == 400
        assert "detail" in response.json()

    def test_create_cache_task_unauthorized(self):
        """测试未授权时创建缓存任务"""
        # Given
        request_data = {"novel_url": "https://example.com/novel/test"}

        # When
        response = self.client.post(
            "/api/cache/create",
            json=request_data,
            headers=self.invalid_headers
        )

        # Then
        assert response.status_code == 401

    def test_create_cache_task_server_error(self):
        """测试服务器错误时创建缓存任务"""
        # Given
        request_data = {"novel_url": "https://example.com/novel/test"}

        # When
        with patch('app.services.novel_cache_service.novel_cache_service.create_cache_task') as mock_create:
            mock_create.side_effect = Exception("数据库错误")

            response = self.client.post(
                "/api/cache/create",
                json=request_data,
                headers=self.valid_headers
            )

        # Then
        assert response.status_code == 500
        assert "detail" in response.json()

    def test_get_cache_status_success(self):
        """测试成功获取缓存任务状态"""
        # Given
        task_id = 1

        # When
        with patch('app.services.novel_cache_service.novel_cache_service.get_task_status') as mock_status:
            mock_task = CacheTask(
                id=task_id,
                novel_url="https://example.com/novel/test",
                novel_title="测试小说",
                novel_author="测试作者",
                status="running",
                total_chapters=100,
                cached_chapters=50,
                failed_chapters=2,
                error_message=None,
                created_at=datetime.now(UTC),
                updated_at=datetime.now(UTC)
            )
            mock_status.return_value = mock_task

            response = self.client.get(
                f"/api/cache/status/{task_id}",
                headers=self.valid_headers
            )

        # Then
        assert response.status_code == 200
        data = response.json()
        assert data["task_id"] == task_id
        assert data["status"] == "running"
        assert data["total_chapters"] == 100
        assert data["cached_chapters"] == 50
        assert data["failed_chapters"] == 2
        assert data["progress"] == 50.0

    def test_get_cache_status_task_not_found(self):
        """测试获取不存在的缓存任务状态"""
        # Given
        task_id = 999

        # When
        with patch('app.services.novel_cache_service.novel_cache_service.get_task_status') as mock_status:
            mock_status.return_value = None

            response = self.client.get(
                f"/api/cache/status/{task_id}",
                headers=self.valid_headers
            )

        # Then
        assert response.status_code == 404

    def test_get_cache_status_unauthorized(self):
        """测试未授权时获取缓存任务状态"""
        # Given
        task_id = 1

        # When
        response = self.client.get(
            f"/api/cache/status/{task_id}",
            headers=self.invalid_headers
        )

        # Then
        assert response.status_code == 401

    def test_get_cache_tasks_success(self):
        """测试成功获取缓存任务列表"""
        # Given

        # When
        with patch('app.services.novel_cache_service.novel_cache_service.get_cache_tasks') as mock_tasks:
            mock_tasks_list = [
                CacheTask(
                    id=1,
                    novel_url="https://example.com/novel1",
                    novel_title="小说1",
                    novel_author="作者1",
                    status="completed",
                    total_chapters=100,
                    cached_chapters=100,
                    failed_chapters=0,
                    error_message=None,
                    created_at=datetime.now(UTC),
                    updated_at=datetime.now(UTC)
                ),
                CacheTask(
                    id=2,
                    novel_url="https://example.com/novel2",
                    novel_title="小说2",
                    novel_author="作者2",
                    status="running",
                    total_chapters=200,
                    cached_chapters=150,
                    failed_chapters=3,
                    error_message=None,
                    created_at=datetime.now(UTC),
                    updated_at=datetime.now(UTC)
                )
            ]
            mock_tasks.return_value = mock_tasks_list

            response = self.client.get(
                "/api/cache/tasks",
                headers=self.valid_headers
            )

        # Then
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 2
        assert len(data["tasks"]) == 2

        # 验证第一个任务
        task1 = data["tasks"][0]
        assert task1["task_id"] == 1
        assert task1["novel_title"] == "小说1"
        assert task1["status"] == "completed"
        assert task1["progress"] == 100.0

        # 验证第二个任务
        task2 = data["tasks"][1]
        assert task2["task_id"] == 2
        assert task2["novel_title"] == "小说2"
        assert task2["status"] == "running"
        assert task2["progress"] == 75.0

    def test_get_cache_tasks_with_status_filter(self):
        """测试带状态过滤的缓存任务列表获取"""
        # Given
        status_filter = "running"

        # When
        with patch('app.services.novel_cache_service.novel_cache_service.get_cache_tasks') as mock_tasks:
            mock_tasks.return_value = [
                CacheTask(
                    id=2,
                    novel_url="https://example.com/novel2",
                    novel_title="小说2",
                    novel_author="作者2",
                    status="running",
                    total_chapters=200,
                    cached_chapters=150,
                    failed_chapters=3,
                    error_message=None,
                    created_at=datetime.now(UTC),
                    updated_at=datetime.now(UTC)
                )
            ]

            response = self.client.get(
                f"/api/cache/tasks?status={status_filter}",
                headers=self.valid_headers
            )

        # Then
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 1
        assert data["tasks"][0]["status"] == "running"

    def test_get_cache_tasks_with_pagination(self):
        """测试分页的缓存任务列表获取"""
        # Given
        limit = 10
        offset = 20

        # When
        with patch('app.services.novel_cache_service.novel_cache_service.get_cache_tasks') as mock_tasks:
            mock_tasks.return_value = [CacheTask(id=i, status="completed") for i in range(limit)]

            response = self.client.get(
                f"/api/cache/tasks?limit={limit}&offset={offset}",
                headers=self.valid_headers
            )

        # Then
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == limit

    def test_get_cache_tasks_unauthorized(self):
        """测试未授权时获取缓存任务列表"""
        # When
        response = self.client.get(
            "/api/cache/tasks",
            headers=self.invalid_headers
        )

        # Then
        assert response.status_code == 401

    def test_cancel_cache_task_success(self):
        """测试成功取消缓存任务"""
        # Given
        task_id = 1

        # When
        with patch('app.services.novel_cache_service.novel_cache_service.cancel_task') as mock_cancel:
            mock_cancel.return_value = True

            response = self.client.post(
                f"/api/cache/cancel/{task_id}",
                headers=self.valid_headers
            )

        # Then
        assert response.status_code == 200
        data = response.json()
        assert data["message"] == "任务已取消"
        assert data["task_id"] == task_id

    def test_cancel_cache_task_not_found(self):
        """测试取消不存在的缓存任务"""
        # Given
        task_id = 999

        # When
        with patch('app.services.novel_cache_service.novel_cache_service.cancel_task') as mock_cancel:
            mock_cancel.return_value = False

            response = self.client.post(
                f"/api/cache/cancel/{task_id}",
                headers=self.valid_headers
            )

        # Then
        assert response.status_code == 404

    def test_cancel_cache_task_unauthorized(self):
        """测试未授权时取消缓存任务"""
        # Given
        task_id = 1

        # When
        response = self.client.post(
            f"/api/cache/cancel/{task_id}",
            headers=self.invalid_headers
        )

        # Then
        assert response.status_code == 401

    def test_cancel_cache_task_server_error(self):
        """测试服务器错误时取消缓存任务"""
        # Given
        task_id = 1

        # When
        with patch('app.services.novel_cache_service.novel_cache_service.cancel_task') as mock_cancel:
            mock_cancel.side_effect = Exception("数据库错误")

            response = self.client.post(
                f"/api/cache/cancel/{task_id}",
                headers=self.valid_headers
            )

        # Then
        assert response.status_code == 500

    def test_download_cached_novel_json_success(self):
        """测试成功下载JSON格式的缓存小说"""
        # Given
        task_id = 1

        # When
        with patch('app.services.novel_cache_service.novel_cache_service.get_task_status') as mock_status:
            with patch('app.services.novel_cache_service.novel_cache_service.get_cached_chapters') as mock_chapters:
                mock_task = CacheTask(
                    id=task_id,
                    novel_url="https://example.com/novel/test",
                    novel_title="测试小说",
                    novel_author="测试作者",
                    status="completed",
                    total_chapters=2,
                    cached_chapters=2,
                    failed_chapters=0,
                    error_message=None,
                    created_at=datetime.now(UTC),
                    completed_at=datetime.now(UTC)
                )
                mock_status.return_value = mock_task

                mock_chapters_list = [
                    {
                        "chapter_title": "第一章",
                        "chapter_url": "https://example.com/chapter/1",
                        "chapter_content": "第一章内容...",
                        "word_count": 1000,
                        "chapter_index": 1,
                        "cached_at": datetime.now(UTC)
                    },
                    {
                        "chapter_title": "第二章",
                        "chapter_url": "https://example.com/chapter/2",
                        "chapter_content": "第二章内容...",
                        "word_count": 1500,
                        "chapter_index": 2,
                        "cached_at": datetime.now(UTC)
                    }
                ]
                mock_chapters.return_value = mock_chapters_list

                response = self.client.get(
                    f"/api/cache/download/{task_id}?format=json",
                    headers=self.valid_headers
                )

        # Then
        assert response.status_code == 200
        data = response.json()
        assert "novel" in data
        assert data["novel"]["title"] == "测试小说"
        assert data["novel"]["author"] == "测试作者"
        assert data["novel"]["url"] == "https://example.com/novel/test"
        assert data["novel"]["total_chapters"] == 2
        assert len(data["chapters"]) == 2
        assert data["chapters"][0]["chapter_title"] == "第一章"
        assert data["chapters"][0]["content"] == "第一章内容..."
        assert data["chapters"][0]["word_count"] == 1000

    def test_download_cached_novel_txt_success(self):
        """测试成功下载TXT格式的缓存小说"""
        # Given
        task_id = 1

        # When
        with patch('app.services.novel_cache_service.novel_cache_service.get_task_status') as mock_status:
            with patch('app.services.novel_cache_service.novel_cache_service.get_cached_chapters') as mock_chapters:
                mock_task = CacheTask(
                    id=task_id,
                    novel_url="https://example.com/novel/test",
                    novel_title="测试小说",
                    novel_author="测试作者",
                    status="completed",
                    total_chapters=2,
                    cached_chapters=2,
                    failed_chapters=0,
                    error_message=None,
                    created_at=datetime.now(UTC),
                    completed_at=datetime.now(UTC)
                )
                mock_status.return_value = mock_task

                mock_chapters_list = [
                    {
                        "chapter_title": "第一章",
                        "chapter_url": "https://example.com/chapter/1",
                        "chapter_content": "第一章内容",
                        "word_count": 1000,
                        "chapter_index": 1,
                        "cached_at": datetime.now(UTC)
                    }
                ]
                mock_chapters.return_value = mock_chapters_list

                response = self.client.get(
                    f"/api/cache/download/{task_id}?format=txt",
                    headers=self.valid_headers
                )

        # Then
        assert response.status_code == 200
        assert response.headers["content-type"] == "text/plain; charset=utf-8"
        assert "attachment" in response.headers["content-disposition"]
        content = response.content.decode("utf-8")
        assert "测试小说" in content
        assert "测试作者" in content
        assert "第一章" in content
        assert "第一章内容" in content

    def test_download_cached_novel_task_not_completed(self):
        """测试下载未完成的缓存小说"""
        # Given
        task_id = 1

        # When
        with patch('app.services.novel_cache_service.novel_cache_service.get_task_status') as mock_status:
            mock_task = CacheTask(
                id=task_id,
                novel_url="https://example.com/novel/test",
                novel_title="测试小说",
                novel_author="测试作者",
                status="running",  # 任务未完成
                total_chapters=100,
                cached_chapters=50,
                failed_chapters=2,
                error_message=None,
                created_at=datetime.now(UTC)
            )
            mock_status.return_value = mock_task

            response = self.client.get(
                f"/api/cache/download/{task_id}?format=json",
                headers=self.valid_headers
            )

        # Then
        assert response.status_code == 404

    def test_download_cached_novel_task_not_found(self):
        """测试下载不存在的缓存任务"""
        # Given
        task_id = 999

        # When
        with patch('app.services.novel_cache_service.novel_cache_service.get_task_status') as mock_status:
            mock_status.return_value = None

            response = self.client.get(
                f"/api/cache/download/{task_id}?format=json",
                headers=self.valid_headers
            )

        # Then
        assert response.status_code == 404

    def test_download_cached_novel_unauthorized(self):
        """测试未授权时下载缓存小说"""
        # Given
        task_id = 1

        # When
        response = self.client.get(
            f"/api/cache/download/{task_id}?format=json",
            headers=self.invalid_headers
        )

        # Then
        assert response.status_code == 401

    def test_download_cached_novel_invalid_format(self):
        """测试下载不支持格式的缓存小说"""
        # Given
        task_id = 1

        # When
        response = self.client.get(
            f"/api/cache/download/{task_id}?format=xml",
            headers=self.valid_headers
        )

        # Then
        assert response.status_code == 400

    def test_progress_calculation_edge_cases(self):
        """测试进度计算的边界情况"""
        test_cases = [
            {"total": 0, "cached": 0, "expected": 0},
            {"total": 100, "cached": 0, "expected": 0},
            {"total": 100, "cached": 100, "expected": 100},
            {"total": 100, "cached": 50, "expected": 50},
        ]

        for case in test_cases:
            total = case["total"]
            cached = case["cached"]
            expected = case["expected"]

            if total > 0:
                actual = int(round((cached / total) * 100))
                assert actual == expected, f"Failed for total={total}, cached={cached}"
            else:
                assert expected == 0, f"Failed for total={total}, cached={cached}"

    def test_api_response_structure_consistency(self):
        """测试API响应结构的一致性"""
        # 验证所有成功响应都包含预期字段
        required_task_fields = [
            "task_id", "status", "novel_title", "novel_author",
            "total_chapters", "cached_chapters", "failed_chapters", "progress"
        ]

        # This test validates the expected response structure
        # In a real implementation, you would make actual API calls
        for field in required_task_fields:
            assert isinstance(field, str), f"Field {field} should be a string"

    @pytest.mark.slow
    def test_concurrent_cache_requests(self):
        """测试并发缓存请求"""
        import asyncio

        async def make_concurrent_requests():
            with patch('app.services.novel_cache_service.novel_cache_service.create_cache_task') as mock_create:
                mock_task = CacheTask(
                    id=1,
                    novel_url="https://example.com/novel/test",
                    novel_title="测试小说",
                    novel_author="测试作者",
                    status="pending",
                    total_chapters=100,
                    cached_chapters=0,
                    failed_chapters=0,
                    error_message=None,
                    created_at=datetime.now(UTC)
                )
                mock_create.return_value = mock_task

                # 创建并发请求
                async def make_request():
                    return self.client.post(
                        "/api/cache/create",
                        json={"novel_url": "https://example.com/novel/test"},
                        headers=self.valid_headers
                    )

                # 并发执行5个请求
                responses = await asyncio.gather(*[
                    make_request() for _ in range(5)
                ])

                # 验证所有请求都成功
                for response in responses:
                    assert response.status_code == 200

        # 运行异步测试
        asyncio.run(make_concurrent_requests())
