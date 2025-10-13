from __future__ import annotations

import io
import sys
from pathlib import Path
from types import ModuleType
from contextlib import redirect_stdout, redirect_stderr


def mock_modules() -> None:
    # torch
    torch = ModuleType("torch")
    class _Cuda:
        @staticmethod
        def is_available() -> bool:
            return False
    class _Version:
        cuda = None
    torch.cuda = _Cuda()
    torch.version = _Version()
    sys.modules["torch"] = torch

    # whisperx core and submodules
    whisperx = ModuleType("whisperx")
    sys.modules["whisperx"] = whisperx

    wx_asr = ModuleType("whisperx.asr")
    class TranscriptionOptions:  # noqa: N801 (simple placeholder)
        pass
    wx_asr.TranscriptionOptions = TranscriptionOptions
    sys.modules["whisperx.asr"] = wx_asr

    wx_diarize = ModuleType("whisperx.diarize")
    class DiarizationPipeline:  # noqa: N801 (simple placeholder)
        def __init__(self, *a, **k):
            pass
    wx_diarize.DiarizationPipeline = DiarizationPipeline
    sys.modules["whisperx.diarize"] = wx_diarize

    # rich
    rich_console = ModuleType("rich.console")
    class Console:
        def print(self, *a, **k):
            pass
    rich_console.Console = Console
    sys.modules["rich.console"] = rich_console

    rich_panel = ModuleType("rich.panel")
    class Panel:
        @staticmethod
        def fit(*a, **k):
            return None
    rich_panel.Panel = Panel
    sys.modules["rich.panel"] = rich_panel

    rich_table = ModuleType("rich.table")
    class Table:
        def __init__(self, *a, **k):
            pass
        def add_column(self, *a, **k):
            pass
        def add_row(self, *a, **k):
            pass
    rich_table.Table = Table
    sys.modules["rich.table"] = rich_table


def main() -> int:
    # Ensure repo src/ is on sys.path
    repo_root = Path(__file__).resolve().parents[2]
    sys.path.insert(0, str(repo_root / "src"))

    mock_modules()

    import meeting_notes.main as cli  # type: ignore

    # Capture help text
    buf_out, buf_err = io.StringIO(), io.StringIO()
    sys.argv = ["meeting-notes", "-h"]
    with redirect_stdout(buf_out), redirect_stderr(buf_err):
        try:
            cli.parse_args()
        except SystemExit as e:
            if e.code not in (0, None):
                print("Unexpected exit code from --help:", e.code)
                return 1

    help_text = buf_out.getvalue() + buf_err.getvalue()
    required_snippets = [
        "usage: meeting-notes",
        "audio [output]",
        "--no-diarisation",
        "--batch-size",
        "--beam-size",
    ]
    missing = [s for s in required_snippets if s not in help_text]
    if missing:
        print("Help text missing expected content:", ", ".join(missing))
        print("Captured help:\n", help_text)
        return 2

    print("CLI help validated successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

