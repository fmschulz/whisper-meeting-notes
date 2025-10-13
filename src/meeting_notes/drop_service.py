from __future__ import annotations

import argparse
import os
import subprocess
import sys
from contextlib import suppress
from shutil import which

from . import drop_server


def run_command(cmd: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, check=check, text=True, capture_output=False)


def enable_tailscale_https(port: int, serve_host: str, https_port: int) -> None:
    run_command(
        [
            "tailscale",
            "serve",
            f"--https={https_port}",
            "/",
            f"http://{serve_host}:{port}",
        ]
    )
    run_command(["tailscale", "funnel", f"--https={https_port}", "on"])


def disable_tailscale_https(https_port: int) -> None:
    with suppress(Exception):
        run_command(["tailscale", "funnel", f"--https={https_port}", "off"], check=False)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="meeting-notes-drop-service",
        description="Launch the drop server and (optionally) configure Tailscale Funnel.",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("DROP_SERVER_PORT", 8000)),
        help="Local port for the drop server (default: 8000 or DROP_SERVER_PORT).",
    )
    parser.add_argument(
        "--host",
        default=os.environ.get("DROP_SERVER_HOST", "127.0.0.1"),
        help="Interface to bind the drop server (default: 127.0.0.1).",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=int(os.environ.get("DROP_MAX_WORKERS", 1)),
        help="Maximum concurrent transcription jobs (default: 1 or DROP_MAX_WORKERS).",
    )
    parser.add_argument(
        "--https-port",
        type=int,
        default=443,
        help="Public HTTPS port when configuring Tailscale Funnel (default: 443).",
    )
    parser.add_argument(
        "--serve-host",
        default="127.0.0.1",
        help="Host used for the tailscale serve target URL (default: 127.0.0.1).",
    )
    parser.add_argument(
        "--no-tailscale",
        action="store_true",
        help="Skip configuring tailscale serve/funnel; only run the local drop server.",
    )
    parser.add_argument(
        "--leave-tailscale",
        action="store_true",
        help="Do not attempt to disable tailscale funnel on shutdown.",
    )

    args = parser.parse_args(argv)

    os.environ["DROP_SERVER_PORT"] = str(args.port)
    os.environ["DROP_SERVER_HOST"] = args.host
    os.environ["DROP_MAX_WORKERS"] = str(max(1, args.workers))

    started_tailscale = False
    if not args.no_tailscale:
        if not which("tailscale"):
            parser.error("tailscale CLI not found. Install tailscale or pass --no-tailscale.")
        enable_tailscale_https(args.port, args.serve_host, args.https_port)
        started_tailscale = True

    try:
        drop_server.main()
    finally:
        if started_tailscale and not args.leave_tailscale:
            disable_tailscale_https(args.https_port)
    return 0


if __name__ == "__main__":
    sys.exit(main())
