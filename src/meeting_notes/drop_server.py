from __future__ import annotations

import asyncio
import json
import os
import shutil
import subprocess
import sys
import uuid
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional

from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DROPBOX = Path(os.environ.get("MEETING_NOTES_DROPBOX", PROJECT_ROOT / "dropbox"))
JOBS_DIR = DEFAULT_DROPBOX / "jobs"
LOGS_DIR = DEFAULT_DROPBOX / "logs"
MAX_WORKERS = max(1, int(os.environ.get("DROP_MAX_WORKERS", "1")))


class JobStatus(str):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    ERROR = "error"


@dataclass
class Job:
    job_id: str
    created_at: datetime
    original_filename: str
    job_dir: Path
    audio_path: Path
    output_path: Path
    log_path: Path
    status: str = JobStatus.PENDING
    error: Optional[str] = None
    metadata: dict = field(default_factory=dict)


app = FastAPI(title="Meeting Notes Drop Server")
job_queue: "asyncio.Queue[Job]" = asyncio.Queue()
jobs: Dict[str, Job] = {}


def ensure_directories() -> None:
    for directory in (JOBS_DIR, LOGS_DIR):
        directory.mkdir(parents=True, exist_ok=True)


def _create_job_dir(job_id: str) -> Path:
    timestamp = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
    folder = JOBS_DIR / f"{timestamp}-{job_id[:8]}"
    folder.mkdir(parents=True, exist_ok=True)
    return folder


def _run_transcription(job: Job) -> None:
    env = os.environ.copy()
    env.setdefault("UV_TORCH_VARIANT", "cu124")

    command = [
        str(PROJECT_ROOT / "scripts" / "meeting-notes.sh"),
        str(job.audio_path),
        str(job.output_path),
    ]
    options = job.metadata.get("options", [])
    if options:
        command.extend(options)

    with job.log_path.open("w", encoding="utf-8") as log_file:
        process = subprocess.run(
            command,
            cwd=str(PROJECT_ROOT),
            env=env,
            stdout=log_file,
            stderr=subprocess.STDOUT,
            text=True,
        )

    if process.returncode != 0:
        raise RuntimeError(
            f"Transcription failed (exit code {process.returncode}). See {job.log_path} for details."
        )


async def worker() -> None:
    while True:
        job = await job_queue.get()
        job.status = JobStatus.PROCESSING
        try:
            await asyncio.to_thread(_run_transcription, job)
        except asyncio.CancelledError:  # pragma: no cover - service shutdown
            job.status = JobStatus.ERROR
            job.error = "Worker cancelled."
            job_queue.task_done()
            raise
        except Exception as exc:  # pragma: no cover - defensive
            job.status = JobStatus.ERROR
            job.error = str(exc)
        else:
            job.status = JobStatus.COMPLETED
        finally:
            job_queue.task_done()


@app.on_event("startup")
async def on_startup() -> None:
    ensure_directories()
    for _ in range(MAX_WORKERS):
        asyncio.create_task(worker())


@app.get("/", response_class=HTMLResponse)
async def index() -> str:
    return """
    <html>
      <head><title>Meeting Notes Drop</title></head>
      <body>
        <h1>Upload a meeting recording</h1>
        <form action="/upload" method="post" enctype="multipart/form-data">
          <input type="file" name="file" accept="audio/*,video/*" required>
          <input type="submit" value="Upload">
        </form>
      </body>
    </html>
    """


@app.post("/upload")
async def upload(
    request: Request,
    file: UploadFile = File(...),
    options: str | None = Form(None),
    output_name: str | None = Form(None),
) -> JSONResponse:
    if not file.filename:
        raise HTTPException(status_code=400, detail="Uploaded file must have a filename.")

    try:
        options_list = json.loads(options) if options else []
    except json.JSONDecodeError as exc:  # pragma: no cover - user input
        raise HTTPException(status_code=400, detail=f"Invalid options payload: {exc}") from exc

    if not isinstance(options_list, list) or not all(isinstance(opt, str) for opt in options_list):
        raise HTTPException(status_code=400, detail="Options payload must be a JSON array of strings.")

    job_id = uuid.uuid4().hex
    job_dir = _create_job_dir(job_id)
    audio_path = job_dir / file.filename
    safe_output_name = Path(output_name).name if output_name else ""
    if safe_output_name:
        output_path = job_dir / safe_output_name
    else:
        output_path = job_dir / f"{audio_path.stem}-notes.md"
    log_path = LOGS_DIR / f"{job_id}.log"

    with audio_path.open("wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    job = Job(
        job_id=job_id,
        created_at=datetime.utcnow(),
        original_filename=file.filename,
        job_dir=job_dir,
        audio_path=audio_path,
        output_path=output_path,
        log_path=log_path,
        metadata={
            "options": options_list,
            "output_name": safe_output_name or output_path.name,
        },
    )
    jobs[job_id] = job
    await job_queue.put(job)

    status_url = request.url_for("get_status", job_id=job_id)
    result_url = request.url_for("get_result", job_id=job_id)
    log_url = request.url_for("get_log", job_id=job_id)

    return JSONResponse(
        {
            "job_id": job_id,
            "created_at": job.created_at.isoformat() + "Z",
            "status": job.status,
            "status_url": str(status_url),
            "result_url": str(result_url),
            "log_url": str(log_url),
            "original_filename": file.filename,
        }
    )


@app.get("/status/{job_id}")
async def get_status(job_id: str) -> JSONResponse:
    job = jobs.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found.")
    payload = {
        "job_id": job.job_id,
        "status": job.status,
        "created_at": job.created_at.isoformat() + "Z",
        "original_filename": job.original_filename,
    }
    if job.status == JobStatus.ERROR:
        payload["error"] = job.error
    if job.status == JobStatus.COMPLETED:
        payload["result_path"] = str(job.output_path)
    return JSONResponse(payload)


@app.get("/result/{job_id}")
async def get_result(job_id: str) -> FileResponse:
    job = jobs.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found.")
    if job.status != JobStatus.COMPLETED:
        raise HTTPException(status_code=409, detail=f"Job status is {job.status}.")
    if not job.output_path.exists():
        raise HTTPException(status_code=500, detail="Transcript not found on disk.")
    filename = f"{job.output_path.name}"
    return FileResponse(
        path=job.output_path,
        media_type="text/markdown",
        filename=filename,
    )


@app.get("/log/{job_id}")
async def get_log(job_id: str) -> FileResponse:
    job = jobs.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found.")
    if not job.log_path.exists():
        raise HTTPException(status_code=404, detail="Log not available yet.")
    return FileResponse(
        path=job.log_path,
        media_type="text/plain",
        filename=f"{job.job_id}.log",
    )


def main() -> None:
    try:
        import uvicorn
    except ImportError as exc:  # pragma: no cover - defensive
        raise SystemExit("uvicorn must be installed to run the drop server.") from exc

    ensure_directories()
    host = os.environ.get("DROP_SERVER_HOST", "127.0.0.1")
    port = int(os.environ.get("DROP_SERVER_PORT", "8000"))
    uvicorn.run(
        "meeting_notes.drop_server:app",
        host=host,
        port=port,
        reload=False,
    )


if __name__ == "__main__":
    main()
