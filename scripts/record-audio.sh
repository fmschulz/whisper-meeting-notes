#!/bin/bash

# Cross-platform audio capture helper for the Meeting Notes Kit.
# Supports Linux (PulseAudio / PipeWire) and macOS (AVFoundation).
# Usage: record-audio.sh [--output <path>] [--source <device>] [--duration <seconds>] [--list]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RECORDINGS_DIR="${PROJECT_ROOT}/recordings"
OS_NAME="$(uname -s)"

OUTPUT=""
SOURCE=""
DURATION=""
LIST_ONLY=0

show_help() {
  cat <<'USAGE'
record-audio.sh - capture raw audio suitable for Whisper transcription

Options:
  --output <path>    Output file (default: recordings/session-YYYYMMDD-HHMMSS.flac)
  --source <device>  Audio input/monitor source (platform-specific default)
  --duration <secs>  Stop automatically after the given number of seconds
  --list             List available audio sources and exit
  -h, --help         Show this help message

Examples:
  # Record using the default PipeWire/Pulse source until Ctrl+C
  ./scripts/record-audio.sh

  # Record from a specific monitor source for 1800 seconds (30 minutes)
  ./scripts/record-audio.sh --source alsa_output.pci-0000_01_00.1.hdmi-stereo.monitor --duration 1800

  # On macOS, list input devices
  ./scripts/record-audio.sh --list
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --source)
      SOURCE="$2"
      shift 2
      ;;
    --duration)
      DURATION="$2"
      shift 2
      ;;
    --list)
      LIST_ONLY=1
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      show_help
      exit 1
      ;;
  esac
done

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required. Install it via your package manager (e.g., 'sudo pacman -S ffmpeg' or 'brew install ffmpeg')." >&2
  exit 1
fi

mkdir -p "${RECORDINGS_DIR}"

if [[ -z "${OUTPUT}" ]]; then
  stamp="$(date +%Y%m%d-%H%M%S)"
  OUTPUT="${RECORDINGS_DIR}/session-${stamp}.flac"
else
  case "${OUTPUT}" in
    /*) ;; # absolute path
    *) OUTPUT="${PWD}/${OUTPUT}" ;;
  esac
fi

case "${OS_NAME}" in
  Linux)
    BACKEND="pulse"
    DEFAULT_SOURCE="default"

    list_devices_linux() {
      if command -v pactl >/dev/null 2>&1; then
        echo "PulseAudio / PipeWire sources:"
        pactl list short sources
        echo
        echo "Use the 'Name' column with --source." 
      elif command -v pw-record >/dev/null 2>&1; then
        echo "PipeWire targets (pw-record):"
        pw-record --list-targets
      else
        echo "ffmpeg detected sources:"
        ffmpeg -hide_banner -f pulse -list_devices true -i dummy 2>&1 || true
      fi
    }

    if [[ ${LIST_ONLY} -eq 1 ]]; then
      list_devices_linux
      exit 0
    fi

    SOURCE="${SOURCE:-${PULSE_SOURCE:-${PIPEWIRE_SOURCE:-${DEFAULT_SOURCE}}}}"

    cmd=(ffmpeg -hide_banner -loglevel info)
    [[ -n "${DURATION}" ]] && cmd+=(-t "${DURATION}")
    cmd+=(-f "${BACKEND}" -i "${SOURCE}" -ac 1 -c:a flac "${OUTPUT}")
    ;;

  Darwin)
    DEFAULT_SOURCE=":0"

    list_devices_mac() {
      echo "Available AVFoundation input devices:" >&2
      ffmpeg -hide_banner -f avfoundation -list_devices true -i "" 2>&1 | sed 's/^/  /'
      printf '\nUse the index in the format ":<index>" (e.g., ":0").\n' >&2
    }

    if [[ ${LIST_ONLY} -eq 1 ]]; then
      list_devices_mac
      exit 0
    fi

    SOURCE="${SOURCE:-${AVFOUNDATION_SOURCE:-${DEFAULT_SOURCE}}}"

    cmd=(ffmpeg -hide_banner -loglevel info)
    [[ -n "${DURATION}" ]] && cmd+=(-t "${DURATION}")
    cmd+=(-f avfoundation -i "${SOURCE}" -ac 1 -c:a aac -b:a 192k "${OUTPUT%.flac}.m4a")
    OUTPUT="${OUTPUT%.flac}.m4a"
    ;;

  *)
    echo "Unsupported platform (${OS_NAME}). The recording helper currently supports Linux and macOS." >&2
    exit 1
    ;;
esac

OUTPUT_DIR="$(dirname "${OUTPUT}")"
mkdir -p "${OUTPUT_DIR}"

echo "Recording to ${OUTPUT}"
echo "Press Ctrl+C to stop."
exec "${cmd[@]}"
