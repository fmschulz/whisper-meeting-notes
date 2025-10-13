#!/bin/bash
# Helper that ensures libopenh264 symlinks exist inside the Pixi environment
# and invokes ffmpeg with the requested input device.
# Usage: ffmpeg-wrapper.sh <output-file> [additional ffmpeg args...]

set -euo pipefail

FORMAT="${FFMPEG_INPUT_FORMAT:-pulse}"
DEVICE="${FFMPEG_INPUT_DEVICE:-default}"

if [[ -z "${CONDA_PREFIX:-}" ]]; then
  CONDA_PREFIX=$(dirname "$(dirname "${BASH_SOURCE[0]}")")/.pixi/envs/capture
fi

if [[ -n "${CONDA_PREFIX}" && -d "${CONDA_PREFIX}/lib" ]]; then
  if [[ ! -e "${CONDA_PREFIX}/lib/libopenh264.so.5" && -e "${CONDA_PREFIX}/lib/libopenh264.so.6" ]]; then
    ln -sfn libopenh264.so.6 "${CONDA_PREFIX}/lib/libopenh264.so.5"
  fi
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <output-file> [extra ffmpeg args...]" >&2
  exit 1
fi

OUTPUT="$1"
shift

ffmpeg -f "$FORMAT" -i "$DEVICE" "$@" "$OUTPUT"
