#!/usr/bin/env python3
"""
APP版本管理模型.

This module contains database models for managing app version updates.
"""

from datetime import datetime

from sqlalchemy import Column, DateTime, Index, Integer, String

from ..database import Base


class AppVersion(Base):
    """APP版本管理表"""

    __tablename__ = "app_versions"

    id = Column(Integer, primary_key=True, index=True)
    version = Column(String(20), nullable=False, unique=True)  # 语义化版本号 (如 1.0.1)
    version_code = Column(Integer, nullable=False)  # 版本递增码
    file_path = Column(String(500), nullable=False)  # APK文件存储路径
    file_size = Column(Integer, nullable=False)  # 文件大小(字节)
    download_url = Column(String(500), nullable=False)  # 下载URL
    changelog = Column(String(2000), nullable=True)  # 更新日志
    force_update = Column(Integer, default=0)  # 是否强制更新 (0否 1是)
    created_at = Column(DateTime, default=datetime.now)  # 发布时间

    __table_args__ = (
        Index("idx_version_code", "version_code"),
        Index("idx_version", "version"),
    )
