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
INTERRUPTED=0
record_status=0
cleanup() {
  INTERRUPTED=1
  if kill -0 "$FFMPEG_PID" 2>/dev/null; then
    kill -INT "$FFMPEG_PID" 2>/dev/null || true
  fi
}
trap cleanup INT

"${SCRIPT_DIR}/ffmpeg-wrapper.sh" "$outfile" -c:a flac &
FFMPEG_PID=$!
wait "$FFMPEG_PID" || record_status=$?
trap - INT

if [[ $INTERRUPTED -eq 1 ]]; then
  echo "Recording stopped by user."
elif [[ $record_status -ne 0 ]]; then
  echo "ffmpeg exited with status $record_status" >&2
  exit $record_status
else
  echo "Recording finished."
fi

if [[ ! -s "$outfile" ]]; then
  echo "No audio was captured; skipping upload." >&2
  exit 1
fi

echo "Uploading to $endpoint…"
"${SCRIPT_DIR}/meeting-notes.sh" --remote-http "$endpoint" "$outfile" "$@"
