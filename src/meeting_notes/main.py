from __future__ import annotations

import argparse
import os
from dataclasses import fields as dataclass_fields
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterable, Tuple

import torch
import whisperx
from whisperx.asr import TranscriptionOptions

try:
    from whisperx.diarize import DiarizationPipeline
except Exception:  # pragma: no cover - optional dependency variations
    DiarizationPipeline = None

import warnings

warnings.filterwarnings(
    "ignore",
    message=r"invalid escape sequence \\s",
    category=SyntaxWarning,
    module="pyannote",
)
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

console = Console()

DEFAULT_MODEL = "large-v3"


def _select_device() -> tuple[str, str, str | None]:
    if not torch.cuda.is_available():
        return "cpu", "int8", "CUDA not available"

    try:
        major, minor = torch.cuda.get_device_capability(0)
        arch = f"sm_{major}{minor}"
    except Exception:  # pragma: no cover - defensive fallback
        major = minor = None
        arch = ""

    supported_arches: list[str] = []
    try:
        supported_arches = torch.cuda.get_arch_list()
    except Exception:  # pragma: no cover
        pass

    if arch and supported_arches and arch not in supported_arches:
        reason = (
            f"CUDA capability {arch} is not supported by the current PyTorch build "
            f"(supported architectures: {', '.join(supported_arches)})"
        )
        return "cpu", "int8", reason

    try:
        compiled_version = torch._C._cuda_getCompiledVersion()
        compiled_major = compiled_version // 1000
        compiled_minor = (compiled_version % 1000) // 10
    except Exception:  # pragma: no cover
        compiled_major = compiled_minor = None

    if major is not None and compiled_major is not None:
        if (major, minor) > (compiled_major, compiled_minor):
            reason = (
                f"GPU capability sm_{major}{minor} exceeds compiled support sm_{compiled_major}{compiled_minor}"
            )
            return "cpu", "int8", reason

    return "cuda", "float16", None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Transcribe a meeting recording with WhisperX and export Markdown notes.",
    )
    parser.add_argument(
        "audio",
        type=Path,
        help="Path to the audio/video file (any format supported by ffmpeg).",
    )
    parser.add_argument(
        "output",
        nargs="?",
        type=Path,
        help=(
            "Optional Markdown output path. Defaults to <audio-stem>-notes-<timestamp>.md in the same "
            "directory as the audio file."
        ),
    )
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help=f"Whisper/WhisperX model to use (default: {DEFAULT_MODEL}).",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=16,
        help="Batch size for WhisperX inference (default: 16).",
    )
    parser.add_argument(
        "--no-diarisation",
        action="store_true",
        help="Disable speaker diarisation even if HF_TOKEN is present.",
    )
    parser.add_argument(
        "--min-speakers",
        type=int,
        default=None,
        help="Lower bound on the number of speakers for diarisation (requires HF_TOKEN).",
    )
    parser.add_argument(
        "--max-speakers",
        type=int,
        default=None,
        help="Upper bound on the number of speakers for diarisation (requires HF_TOKEN).",
    )
    parser.add_argument(
        "--temperature",
        type=float,
        default=0.0,
        help="Decoding temperature (0.0 = deterministic, >0 introduces randomness).",
    )
    parser.add_argument(
        "--beam-size",
        type=int,
        default=5,
        help="Beam search size (default: 5).",
    )
    return parser.parse_args()


def format_timestamp(seconds: float) -> str:
    td = timedelta(seconds=float(seconds))
    total_seconds = int(td.total_seconds())
    hours, remainder = divmod(total_seconds, 3600)
    minutes, secs = divmod(remainder, 60)
    millis = int(round((td.total_seconds() - total_seconds) * 1000))
    return f"{hours:02d}:{minutes:02d}:{secs:02d}.{millis:03d}"


def escape_markdown_cell(text: str) -> str:
    return text.replace("|", "\\|")


def build_markdown(
    audio_path: Path,
    model_name: str,
    device: str,
    rows: Iterable[Tuple[str, str, str, str]],
) -> str:
    rows = list(rows)
    unique_speakers: list[str] = []
    for _start, _end, speaker, _text in rows:
        if speaker not in unique_speakers:
            unique_speakers.append(speaker)

    header = [
        "# Meeting Notes",
        "",
        f"- **Source audio:** `{audio_path.resolve()}`",
        f"- **Model:** `{model_name}` on `{device}`",
        f"- **Generated:** {datetime.now().isoformat(timespec='seconds')}",
        f"- **Participants detected:** {', '.join(unique_speakers) if unique_speakers else 'Speaker 1'}",
        "",
        "| Start | End | Speaker | Transcript |",
        "|------:|----:|---------|------------|",
    ]
    body = [
        f"| {start} | {end} | {speaker} | {escape_markdown_cell(text)} |"
        for start, end, speaker, text in rows
    ]
    return "\n".join(header + body) + "\n"


def main() -> None:
    args = parse_args()

    if args.min_speakers is not None and args.min_speakers < 1:
        console.print("[bold red]--min-speakers must be >= 1.[/bold red]")
        raise SystemExit(1)
    if args.max_speakers is not None and args.max_speakers < 1:
        console.print("[bold red]--max-speakers must be >= 1.[/bold red]")
        raise SystemExit(1)
    if (
        args.min_speakers is not None
        and args.max_speakers is not None
        and args.min_speakers > args.max_speakers
    ):
        console.print("[bold red]--min-speakers cannot be greater than --max-speakers.[/bold red]")
        raise SystemExit(1)

    if not args.audio.exists():
        console.print(f"[bold red]Audio file not found:[/bold red] {args.audio}")
        raise SystemExit(1)

    output_path = args.output
    if output_path is None:
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        output_path = args.audio.with_name(f"{args.audio.stem}-notes-{stamp}.md")
    else:
        output_path = output_path.expanduser()
        if not output_path.is_absolute():
            output_path = Path.cwd() / output_path
        output_path = output_path.resolve()

    device, compute_type, fallback_reason = _select_device()
    if fallback_reason:
        console.print(f"[yellow]{fallback_reason}. Falling back to CPU execution.[/yellow]")

    console.print(Panel.fit(
        f"Audio: [bold]{args.audio}[/bold]\n"
        f"Output: [bold]{output_path}[/bold]\n"
        f"Model: [bold]{args.model}[/bold]\n"
        f"Device: [bold]{device}[/bold] (compute={compute_type})",
        title="Meeting Notes Kit",
    ))

    console.print("[cyan]Loading model…[/cyan]")

    valid_asr_fields = {f.name for f in dataclass_fields(TranscriptionOptions)}
    requested_asr_options = {
        "best_of": max(1, args.beam_size),
        "beam_size": max(1, args.beam_size),
        "temperature": args.temperature,
        "temperature_increment_on_fallback": 0.2,
    }
    asr_options = {
        key: value for key, value in requested_asr_options.items() if key in valid_asr_fields
    }

    model = whisperx.load_model(
        args.model,
        device=device,
        compute_type=compute_type,
        asr_options=asr_options or None,
    )

    console.print("[cyan]Loading audio…[/cyan]")
    audio = whisperx.load_audio(str(args.audio))

    console.print("[cyan]Transcribing…[/cyan]")
    result = model.transcribe(audio, batch_size=args.batch_size)

    alignment_model = metadata = None
    try:
        console.print("[cyan]Aligning timestamps…[/cyan]")
        alignment_model, metadata = whisperx.load_align_model(
            language_code=result["language"], device=device
        )
    except Exception as exc:  # pragma: no cover - optional dependency quirks
        console.print(f"[yellow]Alignment model unavailable ({exc}). Continuing without refined timestamps.[/yellow]")
    else:
        try:
            aligned = whisperx.align(
                result["segments"],
                alignment_model,
                metadata,
                audio,
                device,
                return_char_alignments=False,
            )
        except Exception as exc:  # pragma: no cover
            console.print(f"[yellow]Alignment failed ({exc}). Using original segment timings.[/yellow]")
        else:
            result["segments"] = aligned.get("segments", result["segments"])
            if "word_segments" in aligned:
                result["word_segments"] = aligned["word_segments"]

    segments = result.get("segments", [])

    diarise = not args.no_diarisation
    hf_token = os.environ.get("HF_TOKEN")
    if diarise and hf_token:
        if DiarizationPipeline is None:
            console.print(
                "[yellow]whisperx.diarize.DiarizationPipeline not available; skipping diarisation (upgrade whisperx?).[/yellow]"
            )
        else:
            console.print("[cyan]Running speaker diarisation…[/cyan]")
            try:
                diarization_pipeline = DiarizationPipeline(
                    use_auth_token=hf_token,
                    device=device,
                )
                diarization_call_kwargs: dict[str, int] = {}
                if (
                    args.min_speakers is not None
                    and args.max_speakers is not None
                    and args.min_speakers == args.max_speakers
                ):
                    diarization_call_kwargs["num_speakers"] = args.min_speakers
                else:
                    if args.min_speakers is not None:
                        diarization_call_kwargs["min_speakers"] = args.min_speakers
                    if args.max_speakers is not None:
                        diarization_call_kwargs["max_speakers"] = args.max_speakers

                diarize_result = diarization_pipeline(str(args.audio), **diarization_call_kwargs)
            except Exception as exc:
                console.print(
                    f"[yellow]Diarisation failed ({exc}). Proceeding without speaker labels.[/yellow]"
                )
            else:
                result = whisperx.assign_word_speakers(diarize_result, result)
                segments = result.get("segments", [])
    elif diarise:
        console.print("[yellow]HF_TOKEN not found. Skipping diarisation (all text -> Speaker 1).[/yellow]")

    if not segments:
        console.print("[bold red]No transcript segments were produced.[/bold red]")
        raise SystemExit(2)

    table = Table(show_header=True, header_style="bold magenta")
    table.add_column("Start", justify="right")
    table.add_column("End", justify="right")
    table.add_column("Speaker")
    table.add_column("Snippet", overflow="fold")

    rows = []
    current_speaker = "Speaker 1"
    for segment in segments:
        speaker = segment.get("speaker", current_speaker)
        current_speaker = speaker
        start = format_timestamp(segment["start"])
        end = format_timestamp(segment["end"])
        text = segment.get("text", "").strip()
        rows.append((start, end, speaker, text))
        snippet = text[:120] + ("…" if len(text) > 120 else "")
        table.add_row(start, end, speaker, snippet)

    console.print(table)

    markdown = build_markdown(args.audio, args.model, device, rows)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(markdown, encoding="utf-8")
    console.print(f"[green]Notes saved to {output_path}[/green]")


if __name__ == "__main__":
    main()
