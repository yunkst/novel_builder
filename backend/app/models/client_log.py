#!/usr/bin/env python3
"""
Client log model for remote log reporting.

Stores logs uploaded from the Flutter mobile application.
"""

from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Index, Integer, String, Text

from ..database import Base


class ClientLog(Base):
    """客户端日志表"""

    __tablename__ = "client_logs"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    level = Column(String(10), nullable=False, index=True)  # debug/info/warning/error
    message = Column(Text, nullable=False)
    stack_trace = Column(Text, nullable=True)
    category = Column(
        String(20), nullable=False, default="general", index=True
    )  # database/network/ai/ui/cache/tts/character/backup/general
    tags = Column(Text, nullable=True)  # JSON array string
    timestamp = Column(
        DateTime, nullable=False, index=True
    )  # client-side timestamp (UTC)
    received_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )  # server-side timestamp

    __table_args__ = (
        Index("idx_level_timestamp", "level", "timestamp"),
        Index("idx_received_at", "received_at"),
        Index("idx_category_timestamp", "category", "timestamp"),
    )

    def __repr__(self):
        return f"<ClientLog(id={self.id}, level={self.level}, timestamp={self.timestamp})>"
