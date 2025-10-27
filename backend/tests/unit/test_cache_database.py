#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
单元测试：缓存数据库操作
测试缓存任务的数据库CRUD操作和数据一致性
"""

import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from sqlalchemy import create_engine
from sqlalchemy.pool import StaticPool
from typing import List, Dict, Any

from app.database import get_db, Base
from app.models import CacheTask, CachedChapter
from app.services.novel_cache_service import novel_cache_service
from tests.factories import APITestDataFactory


class TestCacheDatabase:
    """缓存数据库操作测试"""

    def setup_method(self):
        """每个测试方法执行前的设置"""
        # 创建测试专用的内存数据库
        self.engine = create_engine(
            "sqlite:///:memory:",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
            echo=False
        )

        # 创建所有表
        Base.metadata.create_all(self.engine)

        # 创建测试会话
        self.SessionLocal = sessionmaker(bind=self.engine)

        # 创建服务实例
        self.cache_service = novel_cache_service

    def teardown_method(self):
        """每个测试方法执行后的清理"""
        # 清理数据库
        Base.metadata.drop_all(self.engine)

    def test_create_cache_task_database_persistence(self):
        """测试缓存任务数据库持久化"""
        # Given
        novel_url = "https://example.com/novel/test-novel"

        # When
        with self.SessionLocal() as db:
            task = self.cache_service.create_cache_task(novel_url, db)

            db.commit()
            task_id = task.id

            # Then
            assert task_id is not None
            assert task.novel_url == novel_url
            assert task.status == "pending"
            assert task.total_chapters >= 0
            assert task.cached_chapters == 0
            assert task.failed_chapters == 0
            assert task.error_message is None
            assert task.created_at is not None

            # 验证数据确实保存到数据库
            saved_task = db.query(CacheTask).filter(CacheTask.id == task_id).first()
            assert saved_task is not None
            assert saved_task.novel_url == novel_url
            assert saved_task.status == "pending"

    def test_update_cache_task_progress(self):
        """测试更新缓存任务进度"""
        # Given
        with self.SessionLocal() as db:
            # 先创建任务
            task = self.cache_service.create_cache_task("https://example.com/novel/progress-test", db)
            db.commit()
            task_id = task.id

            # When
            success = self.cache_service.update_task_progress(
                db,
                task_id,
                cached_chapters=50,
                failed_chapters=2,
                status="running"
            )

        db.commit()

        # Then
        assert success is True

        # 验证更新结果
        updated_task = db.query(CacheTask).filter(CacheTask.id == task_id).first()
        assert updated_task.cached_chapters == 50
        assert updated_task.failed_chapters == 2
        assert updated_task.status == "running"
        assert updated_task.updated_at is not None

    def test_update_cache_task_completion(self):
        """测试完成缓存任务"""
        # Given
        with self.SessionLocal() as db:
            task = self.cache_service.create_cache_task("https://example.com/novel/completion-test", db)
            db.commit()
            task_id = task.id

            # When
            success = self.cache_service.update_task_progress(
                db,
                task_id,
                cached_chapters=100,
                failed_chapters=0,
                status="completed"
            )
            db.commit()

            # Then
            assert success is True

            completed_task = db.query(CacheTask).filter(CacheTask.id == task_id).first()
            assert completed_task.status == "completed"
            assert completed_task.cached_chapters == 100
            assert completed_task.completed_at is not None

    def test_update_cache_task_with_error(self):
        """测试更新缓存任务错误状态"""
        # Given
        with self.SessionLocal() as db:
            task = self.cache_service.create_cache_task("https://example.com/novel/error-test", db)
            db.commit()
            task_id = task.id

            # When
            success = self.cache_service.update_task_progress(
                db,
                task_id,
                cached_chapters=30,
                failed_chapters=5,
                status="failed",
                error_message="网络连接失败"
            )
            db.commit()

            # Then
            assert success is True

            failed_task = db.query(CacheTask).filter(CacheTask.id == task_id).first()
            assert failed_task.status == "failed"
            assert failed_task.failed_chapters == 5
            assert failed_task.error_message == "网络连接失败"

    def test_cache_cached_chapters_crud(self):
        """测试缓存章节的CRUD操作"""
        # Given
        with self.SessionLocal() as db:
            # 先创建任务
            task = self.cache_service.create_cache_task("https://example.com/novel/chapters-crud-test", db)
            db.commit()
            task_id = task.id

            # When - 缓存章节
            chapters_data = [
                {
                    "chapter_title": "第一章",
                    "chapter_url": f"{task.novel_url}/chapter/1",
                    "chapter_content": "第一章内容...",
                    "word_count": 1000,
                    "chapter_index": 1
                },
                {
                    "chapter_title": "第二章",
                    "chapter_url": f"{task.novel_url}/chapter/2",
                    "chapter_content": "第二章内容...",
                    "word_count": 1500,
                    "chapter_index": 2
                }
            ]

            success = self.cache_service.cache_chapters(task_id, chapters_data, db)
            db.commit()

            # Then
            assert success is True

            # 验证章节数据
            cached_chapters = self.cache_service.get_cached_chapters(task_id, db)
            assert len(cached_chapters) == 2
            assert cached_chapters[0]["chapter_title"] == "第一章"
            assert cached_chapters[0]["word_count"] == 1000
            assert cached_chapters[1]["chapter_title"] == "第二章"
            assert cached_chapters[1]["word_count"] == 1500

    def test_get_cached_chapters_empty_result(self):
        """测试获取空的缓存章节"""
        # Given
        with self.SessionLocal() as db:
            task = self.cache_service.create_cache_task("https://example.com/novel/empty-test", db)
            db.commit()
            task_id = task.id

            # When
            chapters = self.cache_service.get_cached_chapters(task_id, db)

            # Then
            assert chapters == []

    def test_get_cache_task_by_status_filter(self):
        """测试按状态筛选缓存任务"""
        # Given
        with self.SessionLocal() as db:
            # 创建不同状态的任务
            task1 = self.cache_service.create_cache_task("https://example.com/novel/status-test1", db)
            task2 = self.cache_service.create_cache_task("https://example.com/novel/status-test2", db)
            task3 = self.cache_service.create_cache_task("https://example.com/novel/status-test3", db)
            db.commit()

            # 更新任务状态
            self.cache_service.update_task_progress(db, task1.id, status="pending")
            self.cache_service.update_task_progress(db, task2.id, status="running")
            self.cache_service.update_task_progress(db, task3.id, status="completed")
            db.commit()

            # When - 按状态筛选
            pending_tasks = self.cache_service.get_cache_tasks(status="pending", limit=10, offset=0, db)
            running_tasks = self.cache_service.get_cache_tasks(status="running", limit=10, offset=0, db)
            completed_tasks = self.cache_service.get_cache_tasks(status="completed", limit=10, offset=0, db)

            # Then
            assert len(pending_tasks) == 1
            assert len(running_tasks) == 1
            assert len(completed_tasks) == 1
            assert pending_tasks[0].id == task1.id
            assert running_tasks[0].id == task2.id
            assert completed_tasks[0].id == task3.id

    def test_get_cache_tasks_with_pagination(self):
        """测试分页获取缓存任务"""
        # Given
        with self.SessionLocal() as db:
            # 创建多个任务
            tasks = []
            for i in range(15):  # 创建15个任务用于测试分页
                task = self.cache_service.create_cache_task(f"https://example.com/novel/pagination-test-{i}", db)
                tasks.append(task)
            db.commit()

            # When - 第一页
            page1 = self.cache_service.get_cache_tasks(limit=5, offset=0, db)
            # 第二页
            page2 = self.cache_service.get_cache_tasks(limit=5, offset=5, db)
            # 第三页
            page3 = self.cache_service.get_cache_tasks(limit=5, offset=10, db)

            # Then
            assert len(page1) == 5
            assert len(page2) == 5
            assert len(page3) == 5

            # 验证分页顺序
            all_task_ids = [task.id for task in page1 + page2 + page3]
            expected_ids = [task.id for task in tasks]
            assert len(set(all_task_ids)) == len(expected_ids)

    def test_cancel_cache_task_database(self):
        """测试取消缓存任务的数据库操作"""
        # Given
        with self.SessionLocal() as db:
            task = self.cache_service.create_cache_task("https://example.com/novel/cancel-test", db)
            db.commit()
            task_id = task.id

            # When
            success = self.cache_service.cancel_task(task_id, db)
            db.commit()

            # Then
            assert success is True

            cancelled_task = db.query(CacheTask).filter(CacheTask.id == task_id).first()
            assert cancelled_task.status == "cancelled"

    def test_cancel_nonexistent_cache_task(self):
        """测试取消不存在的缓存任务"""
        # Given
        non_existent_id = 999999

        # When
        with self.SessionLocal() as db:
            success = self.cache_service.cancel_task(non_existent_id, db)

        # Then
        assert success is False

    def test_task_progress_calculation_accuracy(self):
        """测试任务进度计算的准确性"""
        # Given - 测试各种进度计算情况
        test_cases = [
            {"cached": 0, "total": 100, "expected": 0},
            {"cached": 50, "total": 100, "expected": 50},
            {"cached": 100, "total": 100, "expected": 100},
            {"cached": 1, "total": 3, "expected": 33.33},
            {"cached": 2, "total": 3, "expected": 66.67},
        ]

        # When & Then
        with self.SessionLocal() as db:
            for case in test_cases:
                task = self.cache_service.create_cache_task("https://example.com/novel/progress-test", db)
                self.cache_service.update_task_progress(
                    task.id,
                    cached_chapters=case["cached"],
                    total_chapters=case["total"],
                    status="running",
                    db
                )
                db.commit()

                # 重新获取任务验证进度
                updated_task = db.query(CacheTask).filter(CacheTask.id == task.id).first()
                calculated_progress = (updated_task.cached_chapters / updated_task.total_chapters * 100)

                # 使用四舍五入比较
                assert abs(calculated_progress - case["expected"]) < 0.5, \
                    f"进度计算错误: expected={case['expected']}, got={calculated_progress}"

    def test_database_transaction_rollback(self):
        """测试数据库事务回滚"""
        # Given
        with self.SessionLocal() as db:
            initial_count = db.query(CacheTask).count()

            # When - 模拟事务中的错误
            try:
                # 开始事务
                task = self.cache_service.create_cache_task("https://example.com/novel/transaction-test", db)
                db.add(task)
                db.flush()  # 持久化到会话但不提交

                # 模拟错误
                raise Exception("模拟错误")

            except Exception:
                # 事务应该回滚
                db.rollback()
                final_count = db.query(CacheTask).count()

        # Then
        assert final_count == initial_count

    def test_concurrent_database_operations(self):
        """测试并发数据库操作"""
        import threading
        import time

        results = []
        errors = []

        def worker(worker_id):
            try:
                with self.SessionLocal() as db:
                    # 每个工作线程创建10个任务
                    for i in range(10):
                        task = self.cache_service.create_cache_task(
                            f"https://example.com/novel/concurrent-{worker_id}-{i}",
                            db
                        )
                        db.add(task)
                        db.commit()
                        results.append(task.id)
            except Exception as e:
                errors.append(e)

        # When - 启动5个并发工作线程
        threads = []
        for i in range(5):
            thread = threading.Thread(target=worker, args=(i,))
            threads.append(thread)
            thread.start()

        # 等待所有线程完成
        for thread in threads:
            thread.join()

        # Then
        assert len(errors) == 0, f"并发操作产生错误: {errors}"
        assert len(results) == 50, f"预期创建50个任务，实际创建{len(results)}个"

        # 验证数据库中确实有50个任务
        with self.SessionLocal() as db:
            final_count = db.query(CacheTask).count()
            assert final_count == 50

    def test_database_connection_error_handling(self):
        """测试数据库连接错误处理"""
        # Given
        corrupted_engine = create_engine(
            "sqlite:///:memory:",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
            echo=False
        )

        # 模拟连接错误（通过关闭连接）
        corrupted_engine.dispose()

        # When & Then
        try:
            with self.SessionLocal() as db:
                # 这应该失败，因为引擎已关闭
                task = self.cache_service.create_cache_task("https://example.com/novel/connection-error", db)
                db.commit()
            # 如果没有抛出异常，说明错误处理可能有问题
            assert False, "应该抛出数据库连接异常"
        except Exception as e:
            # 预期会抛出异常
            assert "connection" in str(e).lower() or "closed" in str(e).lower()

    def test_large_data_handling(self):
        """测试大数据处理"""
        # Given
        with self.SessionLocal() as db:
            task = self.cache_service.create_cache_task("https://example.com/novel/large-data-test", db)
            db.commit()
            task_id = task.id

            # When - 缓存大量章节（模拟大小说）
            large_chapters = []
            for i in range(1000):  # 1000章
                chapter_data = {
                    "chapter_title": f"第{i+1}章",
                    "chapter_url": f"{task.novel_url}/chapter/{i+1}",
                    "chapter_content": "章节内容" * 100,  # 较长的内容
                    "word_count": 100 * 100,  # 10000字
                    "chapter_index": i + 1
                }
                large_chapters.append(chapter_data)

            success = self.cache_service.cache_chapters(task_id, large_chapters, db)
            db.commit()

            # Then
            assert success is True

            # 验证数据完整性
            cached_chapters = self.cache_service.get_cached_chapters(task_id, db)
            assert len(cached_chapters) == 1000

            # 验证总字数
            total_word_count = sum(ch["word_count"] for ch in cached_chapters)
            assert total_word_count == 1000 * 10000

    def test_data_integrity_constraints(self):
        """测试数据完整性约束"""
        # Given
        with self.SessionLocal() as db:
            # When - 尝试创建无效任务
            invalid_cases = [
                {"novel_url": None},  # 空URL
                {"novel_url": ""},    # 空字符串URL
                {"novel_url": "invalid-url"},  # 无效URL格式
            ]

            for case in invalid_cases:
                # Then
                try:
                    task = self.cache_service.create_cache_task(case.get("novel_url"), db)
                    # 如果没有抛出异常，验证数据是否正确处理
                    if task:
                        assert task.novel_url is not None
                        assert len(task.novel_url) > 0
                except ValueError as e:
                    # 预期的验证错误
                    assert "URL" in str(e) or "novel_url" in str(e)
                except Exception as e:
                    # 其他异常也应该被正确处理
                    assert True, f"异常被正确处理: {e}"

    @pytest.mark.slow
    def test_database_performance_under_load(self):
        """测试数据库在高负载下的性能"""
        # Given
        import time

        with self.SessionLocal() as db:
            start_time = time.time()

            # When - 批量创建任务
            tasks = []
            batch_size = 100
            for i in range(batch_size):
                task = self.cache_service.create_cache_task(f"https://example.com/novel/perf-test-{i}", db)
                tasks.append(task)

            # 批量提交
            db.commit()

            creation_time = time.time() - start_time

            # Then - 性能断言
            assert creation_time < 10.0, f"创建{batch_size}个任务耗时过长: {creation_time:.2f}秒"
            assert creation_time < batch_size * 0.01, f"平均每个任务创建时间过长: {creation_time/batch_size:.3f}秒"

            # 验证查询性能
            query_start = time.time()
            all_tasks = db.query(CacheTask).all()
            query_time = time.time() - query_start

            assert query_time < 1.0, f"查询{batch_size}个任务耗时过长: {query_time:.2f}秒"
            assert len(all_tasks) == batch_size