#!/usr/bin/env python3
"""
ComfyUI 模型文件分块上传 API endpoints.

提供以下功能：
- 列出 /app/models 一级子目录（供 app 选择保存位置）
- 分块上传初始化 / 上传分块 / 查询状态 / 完成合并 / 取消上传

设计要点：
- 无状态：分块临时存文件系统 .tmp/<upload_id>/，状态查询靠扫描分块文件，不进 PostgreSQL
- 幂等：同一 (upload_id, index) 重复上传会覆盖，支持断点续传
- 防路径穿越：target_subdir 必须是 /app/models 的一级子目录
"""

import shutil
import uuid
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse

from ...config import settings
from ...deps.auth import verify_token
from ...schemas import (
    ModelChunkUploadResponse,
    ModelDirsResponse,
    ModelDirInfo,
    ModelUploadCompleteResponse,
    ModelUploadInitRequest,
    ModelUploadInitResponse,
    ModelUploadStatusResponse,
)

router = APIRouter(prefix="/api/models", tags=["models"])


def _models_root() -> Path:
    """返回 ComfyUI 模型根目录（绝对路径）。"""
    return Path(settings.comfyui_models_dir).resolve()


def _tmp_root() -> Path:
    """返回分块上传临时目录（位于模型根目录下的 .tmp）。"""
    return _models_root() / ".tmp"


def _safe_subdir(subdir: str) -> Path:
    """校验目标子目录是模型根目录下的一级子目录，返回其绝对 Path。"""
    if not subdir or "/" in subdir or "\\" in subdir or subdir.startswith("."):
        raise HTTPException(status_code=400, detail="非法的子目录名")

    root = _models_root()
    candidate = (root / subdir).resolve()
    if candidate.parent != root:
        raise HTTPException(status_code=403, detail="非法的子目录路径")

    return candidate


def _safe_filename(filename: str) -> str:
    """校验文件名不含路径分隔符，返回纯文件名。"""
    if not filename:
        raise HTTPException(status_code=400, detail="文件名不能为空")
    name = Path(filename).name  # 取最后一段，剥离任何路径
    if not name or name in (".", ".."):
        raise HTTPException(status_code=400, detail="非法的文件名")
    return name


def _upload_dir(upload_id: str) -> Path:
    """校验 upload_id 并返回其临时目录 Path。"""
    try:
        uid = str(uuid.UUID(upload_id))
    except (ValueError, AttributeError):
        raise HTTPException(status_code=400, detail="非法的 upload_id")
    if uid != upload_id:
        raise HTTPException(status_code=400, detail="非法的 upload_id")

    candidate = (_tmp_root() / uid).resolve()
    tmp_root = _tmp_root()
    if candidate != tmp_root / uid:
        raise HTTPException(status_code=403, detail="非法的上传路径")
    return candidate


def _read_meta(upload_dir: Path) -> dict:
    """读取 upload 目录下的 meta.json。"""
    meta_file = upload_dir / "meta.json"
    if not meta_file.exists():
        raise HTTPException(status_code=404, detail="上传任务不存在或已过期")
    import json

    try:
        return json.loads(meta_file.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        raise HTTPException(status_code=500, detail=f"读取上传元信息失败: {e}")


def _dir_size(path: Path) -> int:
    """递归估算目录占用大小（字节）。"""
    if not path.exists():
        return 0
    total = 0
    for p in path.rglob("*"):
        if p.is_file():
            try:
                total += p.stat().st_size
            except OSError:
                continue
    return total


@router.get("/dirs", response_model=ModelDirsResponse)
async def list_model_dirs(
    authenticated: bool = Depends(verify_token),
):
    """
    列出 ComfyUI 模型目录下的一级子目录，供 app 选择模型保存位置。

    仅返回目录，不递归。返回每个目录的占用大小估算。

    **认证**: 需要 X-API-TOKEN header
    """
    root = _models_root()
    if not root.exists():
        return ModelDirsResponse(dirs=[])

    dirs: list[ModelDirInfo] = []
    try:
        for entry in root.iterdir():
            if not entry.is_dir():
                continue
            # 跳过分块上传临时目录
            if entry.name == ".tmp":
                continue
            dirs.append(
                ModelDirInfo(name=entry.name, size_bytes=_dir_size(entry))
            )
    except OSError as e:
        raise HTTPException(status_code=500, detail=f"读取目录失败: {e}")

    # 按名称排序，方便 UI 展示
    dirs.sort(key=lambda d: d.name)
    return ModelDirsResponse(dirs=dirs)


@router.post("/upload/init", response_model=ModelUploadInitResponse)
async def init_model_upload(
    payload: ModelUploadInitRequest,
    authenticated: bool = Depends(verify_token),
):
    """
    初始化一个分块上传任务，返回 upload_id。

    - 校验 target_subdir 是 /app/models 下的一级子目录
    - 在 /app/models/.tmp/<upload_id>/ 下创建 meta.json 记录元信息
    - 幂等：客户端可对同一任务多次 init（但不建议），每次返回新 upload_id

    **认证**: 需要 X-API-TOKEN header
    """
    target_dir = _safe_subdir(payload.target_subdir)
    _safe_filename(payload.filename)

    if payload.total_size <= 0:
        raise HTTPException(status_code=400, detail="total_size 必须为正")
    if payload.chunk_size <= 0:
        raise HTTPException(status_code=400, detail="chunk_size 必须为正")
    if payload.total_chunks <= 0:
        raise HTTPException(status_code=400, detail="total_chunks 必须为正")
    if payload.total_chunks > 100000:
        raise HTTPException(status_code=400, detail="total_chunks 超过上限")

    # 确保目标子目录存在（真正落地时也会再 mkdir）
    try:
        target_dir.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        raise HTTPException(status_code=500, detail=f"无法创建目标目录: {e}")

    upload_id = str(uuid.uuid4())
    upload_dir = _tmp_root() / upload_id
    try:
        upload_dir.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        raise HTTPException(status_code=500, detail=f"无法创建临时目录: {e}")

    import json

    meta = {
        "upload_id": upload_id,
        "filename": payload.filename,
        "target_subdir": payload.target_subdir,
        "total_size": payload.total_size,
        "chunk_size": payload.chunk_size,
        "total_chunks": payload.total_chunks,
        "created_at": datetime.now().isoformat(),
    }
    (upload_dir / "meta.json").write_text(
        json.dumps(meta, ensure_ascii=False), encoding="utf-8"
    )

    return ModelUploadInitResponse(
        upload_id=upload_id,
        chunk_size=payload.chunk_size,
        total_chunks=payload.total_chunks,
    )


@router.post(
    "/upload/{upload_id}/chunk/{index}",
    response_model=ModelChunkUploadResponse,
)
async def upload_model_chunk(
    upload_id: str,
    index: int,
    request: Request,
    authenticated: bool = Depends(verify_token),
):
    """
    上传一个分块（二进制 body，application/octet-stream）。

    幂等：同一 (upload_id, index) 重复上传会覆盖已有分块。

    **认证**: 需要 X-API-TOKEN header
    """
    if index < 0:
        raise HTTPException(status_code=400, detail="index 不能为负")

    upload_dir = _upload_dir(upload_id)
    meta = _read_meta(upload_dir)
    if index >= meta["total_chunks"]:
        raise HTTPException(status_code=400, detail="index 超出 total_chunks 范围")

    chunk_path = upload_dir / f"{index}.part"
    received = 0
    try:
        # 流式写入，避免占用内存
        with chunk_path.open("wb") as buffer:
            async for chunk in request.stream():
                if chunk:
                    buffer.write(chunk)
                    received += len(chunk)
        # 校验实际写入大小（最后一块允许小于 chunk_size）
        received = chunk_path.stat().st_size
    except OSError as e:
        raise HTTPException(status_code=500, detail=f"分块写入失败: {e}")

    return ModelChunkUploadResponse(index=index, received_bytes=received)


@router.get(
    "/upload/{upload_id}/status",
    response_model=ModelUploadStatusResponse,
)
async def get_model_upload_status(
    upload_id: str,
    authenticated: bool = Depends(verify_token),
):
    """
    查询分块上传状态，返回已接收的分块序号集合。

    **认证**: 需要 X-API-TOKEN header
    """
    upload_dir = _upload_dir(upload_id)
    meta = _read_meta(upload_dir)

    received_indices: list[int] = []
    try:
        for entry in upload_dir.iterdir():
            if not entry.is_file():
                continue
            if not entry.name.endswith(".part"):
                continue
            try:
                idx = int(entry.name.removesuffix(".part"))
                if 0 <= idx < meta["total_chunks"]:
                    received_indices.append(idx)
            except ValueError:
                continue
    except OSError as e:
        raise HTTPException(status_code=500, detail=f"扫描分块失败: {e}")

    received_indices.sort()
    complete = len(received_indices) == meta["total_chunks"]
    return ModelUploadStatusResponse(
        upload_id=upload_id,
        total_chunks=meta["total_chunks"],
        received_indices=received_indices,
        complete=complete,
    )


@router.post(
    "/upload/{upload_id}/complete",
    response_model=ModelUploadCompleteResponse,
)
async def complete_model_upload(
    upload_id: str,
    authenticated: bool = Depends(verify_token),
):
    """
    校验分块齐全后合并到 /app/models/<target_subdir>/<filename>。

    - 同名文件追加时间戳避免覆盖
    - 合并成功后删除临时目录

    **认证**: 需要 X-API-TOKEN header
    """
    upload_dir = _upload_dir(upload_id)
    meta = _read_meta(upload_dir)

    total_chunks = meta["total_chunks"]

    # 校验所有分块齐全
    for idx in range(total_chunks):
        if not (upload_dir / f"{idx}.part").exists():
            raise HTTPException(
                status_code=409,
                detail=f"分块不完整，缺失: {idx}",
            )

    target_dir = _safe_subdir(meta["target_subdir"])
    stored_name = _safe_filename(meta["filename"])

    # 同名追加时间戳
    final_path = target_dir / stored_name
    if final_path.exists():
        ts = datetime.now().strftime("%H%M%S")
        stem = Path(stored_name).stem
        suffix = Path(stored_name).suffix
        final_path = target_dir / f"{stem}_{ts}{suffix}"

    try:
        with final_path.open("wb") as out:
            for idx in range(total_chunks):
                chunk_path = upload_dir / f"{idx}.part"
                with chunk_path.open("rb") as chunk_in:
                    shutil.copyfileobj(chunk_in, out)
    except OSError as e:
        raise HTTPException(status_code=500, detail=f"合并文件失败: {e}")

    try:
        size = final_path.stat().st_size
    except OSError:
        size = 0

    # 删除临时目录
    try:
        shutil.rmtree(upload_dir, ignore_errors=True)
    except OSError:
        pass

    return ModelUploadCompleteResponse(
        stored_path=str(final_path),
        filename=final_path.name,
        size=size,
    )


@router.delete("/upload/{upload_id}")
async def cancel_model_upload(
    upload_id: str,
    authenticated: bool = Depends(verify_token),
):
    """
    取消分块上传，删除整个临时目录。

    **认证**: 需要 X-API-TOKEN header
    """
    upload_dir = _upload_dir(upload_id)
    if not upload_dir.exists():
        return JSONResponse(
            status_code=200,
            content={"message": "上传任务不存在或已清理", "upload_id": upload_id},
        )

    try:
        shutil.rmtree(upload_dir, ignore_errors=True)
    except OSError as e:
        raise HTTPException(status_code=500, detail=f"清理失败: {e}")

    return {"message": "上传已取消", "upload_id": upload_id}
