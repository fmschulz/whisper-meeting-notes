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
  endpoint_file="${PROJECT_ROOT}/.remote-http-endpoint"
  if [[ -f "$endpoint_file" ]]; then
    endpoint="$(tr -d '\r\n' < "$endpoint_file")"
  fi
fi

if [[ -z "$endpoint" ]]; then
  echo "Remote HTTP endpoint is required (pass as first argument, set REMOTE_HTTP_ENDPOINT, or run ./scripts/setup-drop-service.sh to generate .remote-http-endpoint)." >&2
  exit 1
fi

mkdir -p recordings
outfile="recordings/session-$(date +%Y%m%d-%H%M%S).flac"

echo "Recording to $outfile (Ctrl+C to stop)…"
INTERRUPTED=0
trap 'INTERRUPTED=1' INT

record_status=0
if ! "${SCRIPT_DIR}/ffmpeg-wrapper.sh" "$outfile" -c:a flac; then
  record_status=$?
fi
trap - INT

if [[ $INTERRUPTED -eq 1 || $record_status -eq 130 ]]; then
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
