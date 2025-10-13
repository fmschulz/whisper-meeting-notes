#!/bin/bash
# Record audio via ffmpeg (PulseAudio/PipeWire) and immediately upload it to the
# GPU workstation for transcription.
# Usage: record-and-upload.sh [REMOTE_HTTP_ENDPOINT] [extra meeting-notes args...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

endpoint="${REMOTE_HTTP_ENDPOINT:-}"
if [[ $# -gt 0 && $1 != -* ]]; then
  endpoint="$1"
  shift
fi

if [[ -z "$endpoint" ]]; then
  echo "Remote HTTP endpoint is required (pass as first argument or set REMOTE_HTTP_ENDPOINT)." >&2
  exit 1
fi

mkdir -p recordings
outfile="recordings/session-$(date +%Y%m%d-%H%M%S).flac"

echo "Recording to $outfile (Ctrl+C to stop)…"
"${SCRIPT_DIR}/ffmpeg-wrapper.sh" "$outfile" -c:a flac

echo "Recording finished. Uploading to $endpoint…"
"${SCRIPT_DIR}/meeting-notes.sh" --remote-http "$endpoint" "$outfile" "$@"
