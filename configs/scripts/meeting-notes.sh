#!/bin/bash

# Capture rich meeting notes with WhisperX diarisation and markdown output.
# Usage: meeting-notes.sh <audio-file> [output-file]
# Defaults to writing notes next to the audio file under the same recording directory.

set -euo pipefail

NOTES_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/meeting-notes"
VENV_PATH="${NOTES_ROOT}/venv"
MODEL_NAME="large-v3"
timestamp="$(date +%Y%m%d-%H%M%S)"

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <audio-file> [output-markdown]" >&2
  exit 1
fi

AUDIO_PATH="${1}"

if [[ ! -f "${AUDIO_PATH}" ]]; then
  echo "Audio file not found: ${AUDIO_PATH}" >&2
  exit 1
fi

AUDIO_ABS_PATH="$(realpath "${AUDIO_PATH}")"
AUDIO_DIR="$(dirname "${AUDIO_ABS_PATH}")"
AUDIO_STEM="$(basename "${AUDIO_ABS_PATH}")"
AUDIO_STEM="${AUDIO_STEM%.*}"
DEFAULT_OUTPUT_PATH="${AUDIO_DIR}/${AUDIO_STEM}-notes-${timestamp}.md"
OUTPUT_PATH="${2:-${DEFAULT_OUTPUT_PATH}}"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required. Install it via pacman before running this script." >&2
  exit 1
fi

mkdir -p "${NOTES_ROOT}"
mkdir -p "$(dirname "${OUTPUT_PATH}")"

if [[ ! -f "${VENV_PATH}/bin/activate" ]]; then
  echo "▶ Creating Whisper notes virtual environment"
  python -m venv "${VENV_PATH}"
  "${VENV_PATH}/bin/python" -m pip install --upgrade pip
fi

echo "▶ Ensuring WhisperX dependencies are installed"
"${VENV_PATH}/bin/python" -m pip install --upgrade \
  torch --index-url https://download.pytorch.org/whl/cpu >"${NOTES_ROOT}/pip-install.log" 2>&1
"${VENV_PATH}/bin/python" -m pip install --upgrade \
  whisperx rich tabulate >>"${NOTES_ROOT}/pip-install.log" 2>&1

echo "▶ Transcribing ${AUDIO_PATH} (output -> ${OUTPUT_PATH})"

"${VENV_PATH}/bin/python" - "$AUDIO_PATH" "$OUTPUT_PATH" "$MODEL_NAME" <<'PY'
import json
import os
import sys
from datetime import timedelta

import torch
import whisperx

audio_path = sys.argv[1]
output_path = sys.argv[2]
model_name = sys.argv[3]

device = "cuda" if torch.cuda.is_available() else "cpu"
compute_type = "float16" if device == "cuda" else "int8"

print(f"Using device={device}, compute_type={compute_type}")

model = whisperx.load_model(
    model_name,
    device=device,
    compute_type=compute_type,
    asr_options={
        "best_of": 5,
        "beam_size": 5,
        "temperature": 0.0,
    },
)

audio = whisperx.load_audio(audio_path)

result = model.transcribe(audio, batch_size=16)

hf_token = os.environ.get("HF_TOKEN")
diarize_result = None
if hf_token:
    print("Running speaker diarisation with WhisperX/pyannote…")
    diarization_pipeline = whisperx.DiarizationPipeline(
        use_auth_token=hf_token,
        device=device,
    )
    diarize_result = diarization_pipeline(audio)
    result = whisperx.assign_word_speakers(diarize_result, result)
else:
    print("HF_TOKEN not set; skipping diarisation (all text attributed to Speaker 1)")

segments = result["segments"]

def format_ts(seconds: float) -> str:
    td = timedelta(seconds=float(seconds))
    total_seconds = int(td.total_seconds())
    hours, remainder = divmod(total_seconds, 3600)
    minutes, secs = divmod(remainder, 60)
    millis = int((td.total_seconds() - total_seconds) * 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}.{millis:03d}"

table_rows = []
current_speaker = "Speaker 1"

for segment in segments:
    speaker = segment.get("speaker", current_speaker)
    current_speaker = speaker
    start = format_ts(segment["start"])
    end = format_ts(segment["end"])
    text = segment["text"].strip()
    table_rows.append((start, end, speaker, text))

with open(output_path, "w", encoding="utf-8") as fh:
    fh.write("# Meeting Notes\n\n")
    fh.write(f"- **Source audio:** `{os.path.abspath(audio_path)}`\n")
    fh.write(f"- **Model:** `{model_name}` on `{device}`\n")
    fh.write(f"- **Segments:** {len(table_rows)}\n\n")
    fh.write("| Start | End | Speaker | Transcript |\n")
    fh.write("|------:|----:|---------|------------|\n")
    for row in table_rows:
        start, end, speaker, text = row
        safe_text = text.replace("|", "\\|")
        fh.write(f"| {start} | {end} | {speaker} | {safe_text} |\n")

print(f"Notes written to {output_path}")
PY

echo "▶ Done"
