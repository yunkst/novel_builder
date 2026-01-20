#!/usr/bin/env python3
"""
Configuration settings for the Novel Builder Backend.

This module contains application configuration using Pydantic BaseSettings
for environment variable management.
"""

import os
import secrets

from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """
    Application settings class.

    Manages configuration through environment variables with secure defaults.
    """

    model_config = {"populate_by_name": True}

    token_header: str = "X-API-TOKEN"

    # 安全配置
    api_token: str = Field(default="", alias="NOVEL_API_TOKEN")
    secret_key: str = ""

    # 开发环境配置
    enabled_sites: str = Field(default="alice_sw,shukuge", alias="NOVEL_ENABLED_SITES")
    debug: bool = False

    # Database settings for caching functionality
    database_url: str = "sqlite:///novel_cache.db"

    # ComfyUI服务配置
    comfyui_api_url: str = "http://host.docker.internal:8188"

    # 图生视频相关配置
    video_generation_timeout: int = 600  # 10分钟

    # 安全配置
    cors_origins: str = "http://localhost:3154"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60

    # APK上传配置
    apk_upload_dir: str = "uploads/apk"
    apk_max_size: int = 100  # MB

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # 生成默认的secret_key（如果未设置）
        if not self.secret_key:
            self.secret_key = secrets.token_urlsafe(32)

        # 开发环境警告
        if self.debug:
            if not self.api_token:
                print("⚠️  警告: 开发环境下未设置API_TOKEN，所有请求将被允许")
            if not os.getenv("SECRET_KEY"):
                print(f"⚠️  警告: 使用自动生成的SECRET_KEY: {self.secret_key[:8]}...")

    def is_secure(self) -> bool:
        """检查是否为安全的生产配置"""
        return (
            self.api_token != ""
            and self.api_token != "your-api-token-here"
            and self.secret_key != "your-secret-key-here"
            and not self.debug
        )


settings = Settings()
