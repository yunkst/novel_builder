#!/usr/bin/env python3

"""
数据库备份 API 端点测试

完全自包含：绕过项目 conftest.py（因 SQLAlchemy JSONB 与 SQLite 不兼容），
直接在测试文件中创建 FastAPI TestClient。

覆盖：
- POST /api/backup/upload      上传备份
- GET  /api/backup/list        列出备份
- GET  /api/backup/download/{backup_id:path}   下载备份
- DELETE /api/backup/delete/{backup_id:path}   删除备份
"""

import io
import os
import sqlite3
import sys
from datetime import datetime
from pathlib import Path

import pytest
from fastapi import FastAPI

# 设置必需的环境变量（在导入 app 模块之前）
os.environ.setdefault("NOVEL_API_TOKEN", "test_token_123")
os.environ.setdefault("SECRET_KEY", "test-secret-key")
os.environ.setdefault("DEBUG", "true")

# 添加项目路径
sys.path.insert(0, str(Path(__file__).parent.parent))

# —— 直接创建独立测试应用，避免导入 app.main（其 SQLAlchemy 模型与 SQLite 不兼容） ——

from app.api.routes.backup import router as backup_router
from fastapi.testclient import TestClient

_test_app = FastAPI()
_test_app.include_router(backup_router)
_test_client = TestClient(_test_app)


# ─────────────────────────────────────────────────────────────────────
# Fixtures
# ─────────────────────────────────────────────────────────────────────


@pytest.fixture
def client():
    """FastAPI 测试客户端."""
    return _test_client


@pytest.fixture
def valid_token() -> str:
    return "test_token_123"


@pytest.fixture
def isolated_backup_dir(tmp_path, monkeypatch):
    """每个测试使用独立的临时备份目录."""
    backup_dir = tmp_path / "backups"
    backup_dir.mkdir(parents=True, exist_ok=True)

    from app.api.routes import backup as backup_module

    monkeypatch.setattr(backup_module, "BACKUP_DIR", backup_dir)
    return backup_dir


@pytest.fixture
def source_dir(tmp_path):
    """源数据库文件的存放目录(独立于 backup_dir, 避免 rglob 误扫)."""
    source = tmp_path / "source"
    source.mkdir(parents=True, exist_ok=True)
    return source


def _make_db_file(path: Path) -> Path:
    """在指定路径创建一个 SQLite 文件."""
    if path.exists():
        path.unlink()
    conn = sqlite3.connect(str(path))
    conn.execute("CREATE TABLE t(id INTEGER PRIMARY KEY, name TEXT)")
    conn.execute("INSERT INTO t(name) VALUES('test')")
    conn.commit()
    conn.close()
    return path


def _upload_backup(client: TestClient, token: str, db_path: Path) -> dict:
    """辅助函数：上传一个 SQLite 备份."""
    with db_path.open("rb") as f:
        response = client.post(
            "/api/backup/upload",
            headers={"X-API-TOKEN": token},
            files={"file": (db_path.name, f, "application/octet-stream")},
        )
    return response.json()


def _to_backup_id(stored_path: str, isolated_backup_dir: Path) -> str:
    """从 stored_path 提取 backup_id（相对路径，POSIX 分隔符）.

    处理 Windows 反斜杠路径，保证跨平台一致。
    """
    backup_dir_posix = str(isolated_backup_dir).replace("\\", "/")
    stored_posix = stored_path.replace("\\", "/")
    return stored_posix.replace(backup_dir_posix + "/", "")


# ─────────────────────────────────────────────────────────────────────
# upload 端点
# ─────────────────────────────────────────────────────────────────────


class TestBackupUpload:
    """测试上传端点."""

    def test_upload_valid_db_success(
        self, client: TestClient, valid_token: str, isolated_backup_dir: Path, source_dir: Path
    ) -> None:
        """合法 .db 文件应成功上传."""
        db_path = _make_db_file(source_dir / "source.db")

        with db_path.open("rb") as f:
            response = client.post(
                "/api/backup/upload",
                headers={"X-API-TOKEN": valid_token},
                files={"file": (db_path.name, f, "application/octet-stream")},
            )

        assert response.status_code == 200
        data = response.json()
        assert data["filename"] == "source.db"
        assert data["stored_name"].endswith(".db")
        assert data["file_size"] > 0
        assert "uploaded_at" in data

        # 文件应该真实存在于 BACKUP_DIR
        assert (isolated_backup_dir / datetime.now().strftime("%Y-%m-%d")).exists()

    def test_upload_without_token_returns_401(
        self, client: TestClient, isolated_backup_dir: Path, source_dir: Path
    ) -> None:
        """缺少 token 应返回 401."""
        db_path = _make_db_file(source_dir / "source.db")
        with db_path.open("rb") as f:
            response = client.post(
                "/api/backup/upload",
                files={"file": (db_path.name, f, "application/octet-stream")},
            )
        assert response.status_code == 401

    def test_upload_non_db_extension_rejected(
        self, client: TestClient, valid_token: str, isolated_backup_dir: Path, source_dir: Path
    ) -> None:
        """非 .db 扩展名应返回 400."""
        fake_file = isolated_backup_dir / "malicious.txt"
        fake_file.write_text("not a database")
        with fake_file.open("rb") as f:
            response = client.post(
                "/api/backup/upload",
                headers={"X-API-TOKEN": valid_token},
                files={"file": (fake_file.name, f, "text/plain")},
            )
        assert response.status_code == 400
        assert ".db" in response.json()["detail"]

    def test_upload_duplicate_filename_uses_timestamp(
        self, client: TestClient, valid_token: str, isolated_backup_dir: Path, source_dir: Path
    ) -> None:
        """同名文件应自动追加时间戳避免冲突."""
        db_path = _make_db_file(source_dir / "source.db")

        result1 = _upload_backup(client, valid_token, db_path)
        result2 = _upload_backup(client, valid_token, db_path)

        assert result1["stored_name"] != result2["stored_name"]


# ─────────────────────────────────────────────────────────────────────
# list 端点
# ─────────────────────────────────────────────────────────────────────


class TestBackupList:
    """测试列出备份端点."""

    def test_list_empty(
        self, client: TestClient, valid_token: str, isolated_backup_dir: Path, source_dir: Path
    ) -> None:
        """无备份时应返回空列表."""
        response = client.get(
            "/api/backup/list", headers={"X-API-TOKEN": valid_token}
        )
        assert response.status_code == 200
        assert response.json() == {"backups": []}

    def test_list_returns_existing_backups(
        self, client: TestClient, valid_token: str, isolated_backup_dir: Path, source_dir: Path
    ) -> None:
        """上传后应能在列表中找到."""
        db_path = _make_db_file(source_dir / "source.db")
        _upload_backup(client, valid_token, db_path)

        response = client.get(
            "/api/backup/list", headers={"X-API-TOKEN": valid_token}
        )
        assert response.status_code == 200
        backups = response.json()["backups"]
        assert len(backups) == 1
        b = backups[0]
        assert b["filename"].endswith(".db")
        assert b["file_size"] > 0
        assert "/" in b["backup_id"]  # YYYY-MM-DD/filename.db

    def test_list_orders_by_time_desc(
        self, client: TestClient, valid_token: str, isolated_backup_dir: Path, source_dir: Path
    ) -> None:
        """列表应按时间倒序."""
        db_path = _make_db_file(source_dir / "source.db")
        _upload_backup(client, valid_token, db_path)
        _upload_backup(client, valid_token, db_path)

        response = client.get(
            "/api/backup/list", headers={"X-API-TOKEN": valid_token}
        )
        backups = response.json()["backups"]
        assert len(backups) == 2
        assert backups[0]["uploaded_at"] >= backups[1]["uploaded_at"]

    def test_list_requires_auth(
        self, client: TestClient, isolated_backup_dir: Path
    ) -> None:
        """无 token 应返回 401."""
        response = client.get("/api/backup/list")
        assert response.status_code == 401


# ─────────────────────────────────────────────────────────────────────
# download 端点
# ─────────────────────────────────────────────────────────────────────


class TestBackupDownload:
    """测试下载端点."""

    def test_download_success(
        self, client: TestClient, valid_token: str, isolated_backup_dir: Path, source_dir: Path
    ) -> None:
        """应能下载之前上传的备份."""
        db_path = _make_db_file(source_dir / "source.db")
        upload_result = _upload_backup(client, valid_token, db_path)
        backup_id = _to_backup_id(upload_result["stored_path"], isolated_backup_dir)

        response = client.get(
            f"/api/backup/download/{backup_id}",
            headers={"X-API-TOKEN": valid_token},
        )
        assert response.status_code == 200
        # 下载内容应包含 SQLite header
        assert response.content[:16] == b"SQLite format 3\x00"

    def test_download_nonexistent_returns_404(
        self, client: TestClient, valid_token: str, isolated_backup_dir: Path, source_dir: Path
    ) -> None:
        """下载不存在的备份应返回 404."""
        response = client.get(
            "/api/backup/download/2099-01-01/nonexistent.db",
            headers={"X-API-TOKEN": valid_token},
        )
        assert response.status_code == 404

    def test_download_path_traversal_blocked(
        self, client: TestClient, valid_token: str, isolated_backup_dir: Path, source_dir: Path
    ) -> None:
        """路径穿越应被拒绝(403 或 404)."""
        response = client.get(
            "/api/backup/download/..%2F..%2Fetc%2Fpasswd",
            headers={"X-API-TOKEN": valid_token},
        )
        assert response.status_code in (400, 403, 404)

    def test_download_requires_auth(
        self, client: TestClient, isolated_backup_dir: Path
    ) -> None:
        """无 token 应返回 401."""
        response = client.get("/api/backup/download/2025-01-01/test.db")
        assert response.status_code == 401


# ─────────────────────────────────────────────────────────────────────
# delete 端点
# ─────────────────────────────────────────────────────────────────────


class TestBackupDelete:
    """测试删除端点."""

    def test_delete_success(
        self, client: TestClient, valid_token: str, isolated_backup_dir: Path, source_dir: Path
    ) -> None:
        """应能删除指定备份."""
        db_path = _make_db_file(source_dir / "source.db")
        upload_result = _upload_backup(client, valid_token, db_path)
        backup_id = _to_backup_id(upload_result["stored_path"], isolated_backup_dir)

        response = client.delete(
            f"/api/backup/delete/{backup_id}",
            headers={"X-API-TOKEN": valid_token},
        )
        assert response.status_code == 200
        assert "已删除" in response.json()["message"]

        # 列表应该为空
        list_response = client.get(
            "/api/backup/list", headers={"X-API-TOKEN": valid_token}
        )
        assert list_response.json()["backups"] == []

    def test_delete_nonexistent_returns_404(
        self, client: TestClient, valid_token: str, isolated_backup_dir: Path, source_dir: Path
    ) -> None:
        """删除不存在的备份应返回 404."""
        response = client.delete(
            "/api/backup/delete/2099-01-01/nonexistent.db",
            headers={"X-API-TOKEN": valid_token},
        )
        assert response.status_code == 404

    def test_delete_cleans_up_empty_directory(
        self, client: TestClient, valid_token: str, isolated_backup_dir: Path, source_dir: Path
    ) -> None:
        """删除后若日期目录为空, 应被清理."""
        db_path = _make_db_file(source_dir / "source.db")
        upload_result = _upload_backup(client, valid_token, db_path)
        backup_id = _to_backup_id(upload_result["stored_path"], isolated_backup_dir)

        date_dir = isolated_backup_dir / backup_id.split("/")[0].replace("\\", "/")
        assert date_dir.exists()

        client.delete(
            f"/api/backup/delete/{backup_id}",
            headers={"X-API-TOKEN": valid_token},
        )

        assert not date_dir.exists()

    def test_delete_keeps_other_files_in_date_dir(
        self, client: TestClient, valid_token: str, isolated_backup_dir: Path, source_dir: Path
    ) -> None:
        """同一日期下多个备份时, 删除一个不应影响其他."""
        db_path = _make_db_file(source_dir / "source.db")
        result1 = _upload_backup(client, valid_token, db_path)

        db_path2 = _make_db_file(source_dir / "source2.db")
        result2 = _upload_backup(client, valid_token, db_path2)

        backup_id1 = _to_backup_id(result1["stored_path"], isolated_backup_dir)
        backup_id2 = _to_backup_id(result2["stored_path"], isolated_backup_dir)

        client.delete(
            f"/api/backup/delete/{backup_id1}",
            headers={"X-API-TOKEN": valid_token},
        )

        list_response = client.get(
            "/api/backup/list", headers={"X-API-TOKEN": valid_token}
        )
        backups = list_response.json()["backups"]
        assert len(backups) == 1
        assert backups[0]["backup_id"] == backup_id2

    def test_delete_path_traversal_blocked(
        self, client: TestClient, valid_token: str, isolated_backup_dir: Path, source_dir: Path
    ) -> None:
        """删除路径穿越应被拒绝."""
        response = client.delete(
            "/api/backup/delete/..%2F..%2Fetc%2Fpasswd",
            headers={"X-API-TOKEN": valid_token},
        )
        assert response.status_code in (400, 403, 404)

    def test_delete_requires_auth(
        self, client: TestClient, isolated_backup_dir: Path
    ) -> None:
        """无 token 应返回 401."""
        response = client.delete("/api/backup/delete/2025-01-01/test.db")
        assert response.status_code == 401


# ─────────────────────────────────────────────────────────────────────
# 端到端流程
# ─────────────────────────────────────────────────────────────────────


class TestBackupE2E:
    """端到端: upload -> list -> download -> delete."""

    def test_full_lifecycle(
        self, client: TestClient, valid_token: str, isolated_backup_dir: Path, source_dir: Path
    ) -> None:
        """完整生命周期应正常工作."""
        # 1. 上传
        db_path = _make_db_file(source_dir / "source.db")
        upload_result = _upload_backup(client, valid_token, db_path)
        backup_id = _to_backup_id(upload_result["stored_path"], isolated_backup_dir)

        # 2. 列出
        list_response = client.get(
            "/api/backup/list", headers={"X-API-TOKEN": valid_token}
        )
        assert len(list_response.json()["backups"]) == 1

        # 3. 下载
        download_response = client.get(
            f"/api/backup/download/{backup_id}",
            headers={"X-API-TOKEN": valid_token},
        )
        assert download_response.status_code == 200
        assert download_response.content[:16] == b"SQLite format 3\x00"

        # 4. 删除
        delete_response = client.delete(
            f"/api/backup/delete/{backup_id}",
            headers={"X-API-TOKEN": valid_token},
        )
        assert delete_response.status_code == 200

        # 5. 列表为空
        final_list = client.get(
            "/api/backup/list", headers={"X-API-TOKEN": valid_token}
        )
        assert final_list.json()["backups"] == []
