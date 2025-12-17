#!/usr/bin/env python3
"""
Configuration settings for the Novel Builder Backend.

This module contains application configuration using Pydantic BaseSettings
for environment variable management.
"""

import os

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """
    Application settings class.

    Manages configuration through environment variables with sensible defaults.
    """

    token_header: str = "X-API-TOKEN"
    api_token: str = os.getenv("NOVEL_API_TOKEN", "your-api-token-here")
    enabled_sites: str = os.getenv("NOVEL_ENABLED_SITES", "alice_sw,shukuge")
    secret_key: str = os.getenv("SECRET_KEY", "your-secret-key-here")
    debug: bool = os.getenv("DEBUG", "false").lower() == "true"

    # Database settings for caching functionality
    database_url: str = os.getenv("DATABASE_URL", "sqlite:///novel_cache.db")

    # 图生视频相关配置
    video_generation_timeout: int = int(os.getenv("VIDEO_GENERATION_TIMEOUT", "600"))  # 10分钟


settings = Settings()
