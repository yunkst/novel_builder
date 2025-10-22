#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
from pydantic import BaseModel


class Settings(BaseModel):
    token_header: str = "X-API-TOKEN"
    api_token: str | None = os.getenv("NOVEL_API_TOKEN")


settings = Settings()