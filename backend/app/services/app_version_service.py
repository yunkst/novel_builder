#!/usr/bin/env python3
"""
APP版本管理服务.

This module contains services for managing app version updates,
including file upload, version comparison, and cleanup.
"""

import os
import shutil
from datetime import datetime
from pathlib import Path

from packaging import version
from sqlalchemy.orm import Session

from ..config import settings
from ..exceptions import NovelBuilderException
from ..models.app_version import AppVersion
from ..schemas import AppVersionResponse


class AppVersionServiceError(NovelBuilderException):
    """APP版本服务异常."""

    error_code = "APP_VERSION_ERROR"


class AppVersionService:
    """APP版本管理服务."""

    def __init__(self, upload_dir: str | None = None, max_versions: int = 2):
        """
        初始化APP版本服务.

        Args:
            upload_dir: APK文件上传目录
            max_versions: 保留的最大版本数量
        """
        self.upload_dir = Path(upload_dir or settings.apk_upload_dir)
        self.max_versions = max_versions
        self._ensure_upload_dir()

    def _ensure_upload_dir(self) -> None:
        """确保上传目录存在."""
        self.upload_dir.mkdir(parents=True, exist_ok=True)

    def _validate_version_format(self, version_str: str) -> bool:
        """
        验证版本号格式.

        Args:
            version_str: 版本号字符串

        Returns:
            是否为有效的语义化版本号
        """
        try:
            version.parse(version_str)
            return True
        except version.InvalidVersion:
            return False

    def _generate_file_path(self, version_str: str, filename: str) -> Path:
        """
        生成APK文件存储路径.

        Args:
            version_str: 版本号
            filename: 原始文件名

        Returns:
            文件存储路径
        """
        # 使用版本号作为文件名，确保唯一性
        ext = Path(filename).suffix or ".apk"
        return self.upload_dir / f"app_v{version_str}{ext}"

    async def save_apk_file(
        self,
        file_content: bytes,
        filename: str,
        version_str: str,
        version_code: int,
        changelog: str | None = None,
        force_update: bool = False,
        db: Session = None,
    ) -> AppVersion:
        """
        保存APK文件并创建版本记录.

        Args:
            file_content: APK文件内容
            filename: 原始文件名
            version_str: 版本号
            version_code: 版本递增码
            changelog: 更新日志
            force_update: 是否强制更新
            db: 数据库会话

        Returns:
            创建的版本记录

        Raises:
            AppVersionServiceError: 保存失败
        """
        # 验证版本号格式
        if not self._validate_version_format(version_str):
            raise AppVersionServiceError(
                message=f"无效的版本号格式: {version_str}",
                details="版本号应遵循语义化版本规范，如 1.0.1",
            )

        # 检查版本是否已存在，如果存在则删除旧版本（支持覆盖上传）
        if db:
            existing = db.query(AppVersion).filter(AppVersion.version == version_str).first()
            if existing:
                # 删除旧版本的APK文件
                try:
                    old_file_path = Path(existing.file_path)
                    if old_file_path.exists():
                        old_file_path.unlink()
                except OSError:
                    pass  # 文件删除失败不影响继续上传

                # 删除旧版本的数据库记录
                db.delete(existing)
                db.commit()

        # 生成文件路径
        file_path = self._generate_file_path(version_str, filename)

        # 保存文件
        try:
            # 如果文件已存在，先删除
            if file_path.exists():
                file_path.unlink()

            file_path.write_bytes(file_content)
            file_size = len(file_content)
        except OSError as e:
            raise AppVersionServiceError(
                message=f"保存APK文件失败: {e}",
                details="请检查存储目录权限",
            )

        # 创建数据库记录
        download_url = f"/api/app-version/download/{version_str}"
        app_version = AppVersion(
            version=version_str,
            version_code=version_code,
            file_path=str(file_path),
            file_size=file_size,
            download_url=download_url,
            changelog=changelog,
            force_update=1 if force_update else 0,
            created_at=datetime.now(),
        )

        if db:
            db.add(app_version)

            # 清理旧版本
            await self._cleanup_old_versions(db)

            db.commit()
            db.refresh(app_version)

        return app_version

    async def _cleanup_old_versions(self, db: Session) -> None:
        """
        清理旧版本，仅保留最新的N个版本.

        Args:
            db: 数据库会话
        """
        # 查询所有版本，按版本码降序
        versions = (
            db.query(AppVersion)
            .order_by(AppVersion.version_code.desc())
            .all()
        )

        # 如果超过保留数量，删除旧版本
        if len(versions) > self.max_versions:
            versions_to_delete = versions[self.max_versions :]
            for old_version in versions_to_delete:
                # 删除文件
                try:
                    file_path = Path(old_version.file_path)
                    if file_path.exists():
                        file_path.unlink()
                except OSError:
                    pass  # 文件删除失败不影响数据库记录删除

                # 删除数据库记录
                db.delete(old_version)

    def get_latest_version(self, db: Session) -> AppVersion | None:
        """
        获取最新版本.

        Args:
            db: 数据库会话

        Returns:
            最新版本记录，如果没有则返回None
        """
        return (
            db.query(AppVersion)
            .order_by(AppVersion.version_code.desc())
            .first()
        )

    def get_version_by_string(self, version_str: str, db: Session) -> AppVersion | None:
        """
        根据版本号获取版本记录.

        Args:
            version_str: 版本号
            db: 数据库会话

        Returns:
            版本记录，如果没有则返回None
        """
        return db.query(AppVersion).filter(AppVersion.version == version_str).first()

    def compare_versions(self, current: str, latest: str) -> int:
        """
        比较两个版本号.

        Args:
            current: 当前版本号
            latest: 最新版本号

        Returns:
            -1: current < latest (有新版本)
            0: current == latest (已是最新)
            1: current > latest (当前版本较新，不应发生)
        """
        try:
            curr = version.parse(current)
            lat = version.parse(latest)

            if curr < lat:
                return -1
            elif curr > lat:
                return 1
            else:
                return 0
        except version.InvalidVersion as e:
            raise AppVersionServiceError(
                message=f"版本号比较失败: {e}",
                details="请确保版本号格式正确",
            )

    def to_response_model(self, app_version: AppVersion) -> AppVersionResponse:
        """
        转换为响应模型.

        Args:
            app_version: 版本记录

        Returns:
            响应模型
        """
        return AppVersionResponse(
            version=app_version.version,
            version_code=app_version.version_code,
            download_url=app_version.download_url,
            file_size=app_version.file_size,
            changelog=app_version.changelog,
            force_update=bool(app_version.force_update),
            created_at=app_version.created_at.isoformat(),
        )


# 创建单例实例
app_version_service = AppVersionService()


def get_app_version_service() -> AppVersionService:
    """获取APP版本服务实例."""
    return app_version_service
