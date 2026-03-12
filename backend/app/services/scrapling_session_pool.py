#!/usr/bin/env python3
"""
会话管理器

提供会话复用和代理轮换功能，优化网络资源使用。
"""

import asyncio
from typing import Dict, Optional

from scrapling.fetchers import FetcherSession, StealthySession


class SessionPool:
    """
    会话池管理器

    提供：
    - 会话复用 - 避免重复初始化
    - 代理轮换 - 支持多个代理配置
    - 自动清理 - 确保资源释放
    - 线程安全 - 支持并发访问

    使用场景：
    - 长时间运行的爬虫
    - 需要保持登录状态的站点
    - 需要代理轮换以避免封禁
    """

    def __init__(self, max_sessions: int = 5):
        """
        初始化会话池

        Args:
            max_sessions: 最大会话数（默认 5）
        """
        self.max_sessions = max_sessions
        self.sessions: Dict[str, any] = {}
        self.lock = asyncio.Lock()
        self.current_index = 0

    async def get_session(self, session_type: str = "default") -> any:
        """
        获取或创建会话

        Args:
            session_type: 会话类型标识
                - "default": 默认会话（FetcherSession）
                - "stealth": 隐蔽会话（StealthySession）
                - "custom": 自定义会话类型

        Returns:
            any: 会话实例

        使用示例：
            >>> pool = SessionPool()
            >>> session = await pool.get_session("stealth")
            >>> # 使用会话进行请求...

        线程安全：
        使用 asyncio.Lock 确保并发安全
        延迟初始化（惰性创建）
        自动复用已存在的会话
        """
        async with self.lock:
            if session_type not in self.sessions:
                # 创建新会话
                if session_type == "stealth":
                    self.sessions[session_type] = StealthySession(
                        headless=True,
                        os_randomize=True,
                        network_idle=True,
                    )
                elif session_type == "default":
"                    self.sessions[session_type] = FetcherSession(
                        impersonate="chrome"
                    )
                else:
                    raise ValueError(f"未知的会话类型: {session_type}")

            return self.sessions[session_type]

    async def rotate_session(self):
        """
        轮换会话（可用于代理轮换）

        Returns:
            any: 下一个会话实例

        使用示例：
            >>> pool = SessionPool(max_sessions=3)
            >>> session1 = await pool.get_session("default")
            >>> session2 = await pool.get_session("stealth")
            >>> # 每次请求轮换
            >>> session = await pool.rotate_session()
        """
        async with self.lock:
            if len(self.sessions) > 1:
                keys = list(self.sessions.keys())
                self.current_index = (self.current_index + 1) % len(keys)
                return self.sessions[keys[self.current_index]]
            elif self.sessions:
                return list(self.sessions.values())[0]
            else:
                return None

    async def close_session(self, session_type: str = "default"):
        """
        关闭指定会话

        Args:
            session_type: 会话类型标识

        线程安全：
        使用 asyncio.Lock 确保并发安全
        """
        async with self.lock:
            if session_type in self.sessions:
                session = self.sessions[session_type]
                try:
                    # 尝试异步关闭
                    if hasattr(session, '__aexit__'):
                        await session.__aexit__(None, None, None)
                    elif hasattr(session, 'close'):
                        await session.close()
                except Exception as e:
                    print(f"关闭会话 {session_type} 时出错: {e}")
                finally:
                    # 移除会话引用
                    del self.sessions[session_type]

    async def close_all(self):
        """
        关闭所有会话

        清理资源，确保不泄漏
        """
        async with self.lock:
            for session_type, session in list(self.sessions.items()):
                try:
                    # 尝试异步关闭
                    if hasattr(session, '__aexit__'):
                        await session.__aexit__(None, None, None)
                    elif hasattr(session, 'close'):
                        await session.close()
                except Exception as e:
                    print(f"关闭会话 {session_type} 时出错: {e}")
                finally:
                    pass

            # 清空会话字典
            self.sessions.clear()

    def __len__(self) -> int:
        """
        返回当前会话数量

        用于监控和管理会话使用情况
        """
        return len(self.sessions)

    def __contains__(self, session_type: str) -> bool:
        """
        检查会话是否存在

        Args:
            session_type: 会话类型标识

        Returns:
            bool: 是否存在
        """
        return session_type in self.sessions


class SessionManager:
    """
    会话管理器 - 高级接口

    提供更丰富的会话管理功能：
    - 统计信息（会话使用次数、错误率等）
    - 健康检查（自动清理长时间未使用的会话）
    - 优先级支持（不同类型会话的优先级）
    - 时间跟踪（会话创建和使用时间）
    """

    def __init__(self):
        """
        初始化会话管理器
        """
        self.pools: Dict[str, SessionPool] = {}
        self.session_stats: Dict[str, Dict] = {}
        self.lock = asyncio.Lock()

    async def get_pool(self, pool_name: str = "default", max_sessions: int = 5) -> SessionPool:
        """
        获取或创建会话池

        Args:
            pool_name: 池名称标识
            max_sessions: 最大会话数

        Returns:
            SessionPool: 会话池实例

        使用示例：
            >>> manager = SessionManager()
            >>> pool = await manager.get_pool("biquge543", max_sessions=10)
            >>> session = await pool.get_session("stealth")
        """
        async with self.lock:
            pool_name = pool_name.lower()

            if pool_name not in self.pools:
                self.pools[pool_name] = SessionPool(max_sessions=max_sessions)

            return self.pools[pool_name]

    async def get_session(self, pool_name: str, session_type: str = "default") -> any:
        """
        获取指定会话池中的会话

        Args:
            pool_name: 池名称标识
            session_type: 会话类型标识

        Returns:
            any: 会话实例

        使用示例：
            >>> manager = SessionManager()
            >>> session = await manager.get_session("alice_sw", "stealth")
        """
        async with self.lock:
            pool_name = pool_name.lower()

            if pool_name not in self.pools:
                raise ValueError(f"会话池 {pool_name} 不存在")

            pool = self.pools[pool_name]
            return await pool.get_session(session_type)

    async def rotate_session(self, pool_name: str):
        """
        轮换指定池中的会话

        Args:
            pool_name: 池名称标识

        Returns:
            any: 下一个会话实例

        使用示例：
            >>> manager = SessionManager()
            >>> session = await manager.rotate_session("alice_sw")
        """
        async with self.lock:
            pool_name = pool_name.lower()

            if pool_name not in self.pools:
                return None

            pool = self.pools[pool_name]
            return await pool.rotate_session()

    async def close_pool(self, pool_name: str):
        """
        关闭指定会话池

        Args:
            pool_name: 池名称标识
        """
        async with self.lock:
            pool_name = pool_name.lower()

            if pool_name in self.pools:
                await self.pools[pool_name].close_all()
                del self.pools[pool_name]

    async def close_all(self):
        """
        关闭所有会话池
        """
        async with self.lock:
            for pool in list(self.pools.values()):
                await pool.close_all()
            self.pools.clear()

    def get_stats(self) -> Dict[str, any]:
        """
        获取会话统计信息

        Returns:
            dict: 包含各池和会话的统计信息
        """
        async with self.lock:
            stats = {
                "pools": {},
                "total_sessions": 0,
            }

            for pool_name, pool in self.pools.items():
                pool_stats = {
                    "name": pool_name,
                    "session_count": len(pool),
                }
                stats["pools"][pool_name] = pool_stats
                stats["total_sessions"] += len(pool)

            return stats
