#!/usr/bin/env python3
"""
Database configuration and session management.

This module provides database connectivity, session management,
and initialization utilities for the application.
"""

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

from .config import settings

# 创建数据库引擎
engine = create_engine(
    settings.database_url,
    pool_pre_ping=True,  # 连接池预检，确保连接有效
    pool_size=5,
    max_overflow=10,
)

# 创建会话工厂 - 使用 UPPER_CASE 常量命名
SESSION_LOCAL = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 创建基类
Base = declarative_base()


def get_db():
    """获取数据库会话（用于依赖注入）"""
    db = SESSION_LOCAL()
    try:
        yield db
    finally:
        db.close()


class DatabaseSession:
    """数据库会话上下文管理器"""

    def __init__(self):
        """初始化数据库会话管理器。"""
        self.db = None

    def __enter__(self):
        self.db = SESSION_LOCAL()
        return self.db

    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type:
            self.db.rollback()
        else:
            self.db.commit()
        self.db.close()


def init_db():
    """初始化数据库（创建所有表）"""
    try:
        # 导入所有模型以确保它们被注册

        # 创建所有表
        Base.metadata.create_all(bind=engine)
        print("✓ 数据库表创建成功")
    except Exception as e:
        print(f"⚠️ 数据库初始化失败: {e}")
        raise
