#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    token_header: str = "X-API-TOKEN"
    api_token: str = os.getenv("NOVEL_API_TOKEN", "your-api-token-here")
    enabled_sites: str = os.getenv("NOVEL_ENABLED_SITES", "alice_sw,shukuge")
    secret_key: str = os.getenv("SECRET_KEY", "your-secret-key-here")
    debug: bool = os.getenv("DEBUG", "false").lower() == "true"

    # Future database settings (commented out for phase 1)
    # database_url: str = os.getenv("DATABASE_URL", "postgresql://novel_user:novel_pass@localhost:5432/novel_db")


settings = Settings()