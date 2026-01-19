#!/usr/bin/env python3
"""
Configuration settings for the Novel Builder Backend.

This module contains application configuration using Pydantic BaseSettings
for environment variable management.
"""

import os
import secrets

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """
    Application settings class.

    Manages configuration through environment variables with secure defaults.
    """

    token_header: str = "X-API-TOKEN"

    # 安全配置 - 不再使用硬编码的默认值
    api_token: str = os.getenv("NOVEL_API_TOKEN", "")
    secret_key: str = os.getenv("SECRET_KEY", secrets.token_urlsafe(32))

    # 开发环境配置
    enabled_sites: str = os.getenv("NOVEL_ENABLED_SITES", "alice_sw,shukuge")
    debug: bool = os.getenv("DEBUG", "false").lower() == "true"

    # Database settings for caching functionality
    database_url: str = os.getenv("DATABASE_URL", "sqlite:///novel_cache.db")

    # ComfyUI服务配置
    comfyui_api_url: str = os.getenv(
        "COMFYUI_API_URL", "http://host.docker.internal:8188"
    )

    # 图生视频相关配置
    video_generation_timeout: int = int(
        os.getenv("VIDEO_GENERATION_TIMEOUT", "600")
    )  # 10分钟

    # 安全配置
    cors_origins: str = os.getenv("CORS_ORIGINS", "http://localhost:3154")
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60

    # APK上传配置
    apk_upload_dir: str = os.getenv("APK_UPLOAD_DIR", "uploads/apk")
    apk_max_size: int = int(os.getenv("APK_MAX_SIZE", "100"))  # MB

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # 开发环境警告
        if self.debug:
            if not self.api_token:
                print("⚠️  警告: 开发环境下未设置API_TOKEN，所有请求将被允许")
            if os.getenv("SECRET_KEY") is None:
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
