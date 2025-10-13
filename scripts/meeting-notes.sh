#!/bin/bash

# Thin wrapper around Pixi environments so moderators can launch transcription quickly.
# Usage: meeting-notes.sh <audio-file> [output-file]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PIXIE_BIN="${PIXIE_BIN:-$(command -v pixi 2>/dev/null || true)}"
if [[ -z "${PIXIE_BIN}" ]]; then
  echo "pixi executable not found. Install pixi and ensure it is on PATH." >&2
  exit 1
fi

DEFAULT_PIXI_ENV="${MEETING_NOTES_ENV:-cpu}"
REMOTE_PIXI_ENV="${TAILSCALE_REMOTE_PIXI_ENV:-gpu}"
REMOTE_PIXI_BIN="${TAILSCALE_REMOTE_PIXI_BIN:-pixi}"

TAILSCALE_HOST=""
TAILSCALE_USER="${TAILSCALE_REMOTE_USER:-}"
REMOTE_REPO="${TAILSCALE_REMOTE_REPO:-~/whisper-meeting-notes}"
REMOTE_WORKDIR="${TAILSCALE_REMOTE_WORKDIR:-.remote-jobs}"
KEEP_REMOTE_JOB="${TAILSCALE_KEEP_REMOTE_JOB:-}"
TAILSCALE_BIN="${TAILSCALE_BIN:-tailscale}"
REMOTE_HTTP_ENDPOINT="${REMOTE_HTTP_ENDPOINT:-}"
HTTP_TIMEOUT="${HTTP_TIMEOUT:-600}"
CUDNN_COMPAT_DIR="${CUDNN_COMPAT_DIR:-$HOME/.local/cudnn8/lib}"

if [[ -d "${CUDNN_COMPAT_DIR}" ]]; then
  if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
    export LD_LIBRARY_PATH="${CUDNN_COMPAT_DIR}:${LD_LIBRARY_PATH}"
  else
    export LD_LIBRARY_PATH="${CUDNN_COMPAT_DIR}"
  fi
fi

usage() {
  cat <<'USAGE'
Usage: meeting-notes.sh [--tailscale-host HOST | --remote-http URL] [options] <audio-file> [output-file]

Remote execution options:
  --tailscale-host HOST    Copy audio to HOST over Tailscale, run transcription there, and download the notes.
  --tailscale-user USER    SSH user for the remote host (defaults to TAILSCALE_REMOTE_USER if set).
  --tailscale-repo PATH    Path to this repository on the remote host (default: ~/whisper-meeting-notes).
  --tailscale-workdir DIR  Remote working directory (relative to repo or absolute) for per-run artefacts (default: .remote-jobs).
  --remote-http URL        Upload via HTTPS to a public drop server (for laptops without Tailscale).
  --tailscale-keep         Keep the remote artefacts instead of deleting them after download.
  --help, -h               Show this message (pass -- --help for the Python CLI usage).

All other options are passed through to the underlying Python CLI. Examples:
  meeting-notes.sh recording.wav
  meeting-notes.sh --tailscale-host gpu-box recording.wav notes.md
  meeting-notes.sh recording.wav --model large-v3 --beam-size 10
USAGE
}

shell_quote() {
  local pybin
  pybin=$(python_bin)
  "${pybin}" -c 'import shlex, sys; print(shlex.quote(sys.argv[1]))' "$1"
}

python_bin() {
  local pybin="${PYTHON_BIN:-python3}"
  if ! command -v "${pybin}" >/dev/null 2>&1; then
    pybin="python"
  fi
  if ! command -v "${pybin}" >/dev/null 2>&1; then
    echo "Python interpreter not found (set PYTHON_BIN if installed in a custom location)." >&2
    exit 1
  fi
  printf '%s' "${pybin}"
}

resolve_path() {
  local input=$1
  local pybin
  pybin=$(python_bin)
  INPUT_PATH=$input "${pybin}" - <<'PY'
import os
from pathlib import Path
input_path = Path(os.environ["INPUT_PATH"]).expanduser()
try:
    resolved = input_path.resolve(strict=False)
except FileNotFoundError:
    resolved = input_path
print(resolved)
PY
}

run_remote() {
  if [[ $# -eq 0 ]]; then
    echo "Audio file is required when using --tailscale-host." >&2
    usage
    exit 1
  fi

  if ! command -v "${TAILSCALE_BIN}" >/dev/null 2>&1; then
    echo "tailscale CLI not found (set TAILSCALE_BIN if it lives elsewhere)." >&2
    exit 1
  fi

  local args=("$@")
  local positionals=()
  local passthrough=()
  local options_with_arg="--model --batch-size --temperature --beam-size"
  local expect_value=""
  local options_ended=0

  while [[ ${#args[@]} -gt 0 ]]; do
    local current="${args[0]}"
    args=("${args[@]:1}")

    if [[ -n "$expect_value" ]]; then
      passthrough+=("$current")
      expect_value=""
      continue
    fi

    if [[ $options_ended -eq 0 && "$current" == "--" ]]; then
      passthrough+=("$current")
      options_ended=1
      continue
    fi

    if [[ $options_ended -eq 0 && "$current" == --*=* ]]; then
      passthrough+=("$current")
      continue
    fi

    if [[ $options_ended -eq 0 && "$current" == --* ]]; then
      passthrough+=("$current")
      for opt in $options_with_arg; do
        if [[ "$current" == "$opt" ]]; then
          if [[ ${#args[@]} -eq 0 ]]; then
            echo "Missing value for option $current" >&2
            exit 1
          fi
          expect_value=1
          break
        fi
      done
      continue
    fi

    if [[ $options_ended -eq 0 && "$current" == -* ]]; then
      passthrough+=("$current")
      continue
    fi

    positionals+=("$current")
  done

  if [[ ${#positionals[@]} -lt 1 ]]; then
    echo "Audio file not supplied; pass it after any options." >&2
    exit 1
  fi

  local audio_arg="${positionals[0]}"
  local output_arg=""
  if [[ ${#positionals[@]} -ge 2 ]]; then
    output_arg="${positionals[1]}"
  fi

  local audio_path
  audio_path="$(resolve_path "$audio_arg")"
  if [[ ! -f "$audio_path" ]]; then
    echo "Audio file not found: $audio_arg" >&2
    exit 1
  fi

  local audio_dir audio_filename audio_stem
  audio_dir="$(dirname "$audio_path")"
  audio_filename="$(basename "$audio_path")"
  audio_stem="${audio_filename%.*}"

  local local_output_path
  if [[ -n "$output_arg" ]]; then
    local_output_path="$(resolve_path "$output_arg")"
  else
    local timestamp
    timestamp="$(date +"%Y%m%d-%H%M%S")"
    local_output_path="${audio_dir}/${audio_stem}-notes-${timestamp}.md"
  fi
  mkdir -p "$(dirname "$local_output_path")"

  local remote_target
  if [[ -n "$TAILSCALE_USER" ]]; then
    remote_target="${TAILSCALE_USER}@${TAILSCALE_HOST}"
  else
    remote_target="${TAILSCALE_HOST}"
  fi

  local remote_repo="$REMOTE_REPO"
  local remote_base
  if [[ "$REMOTE_WORKDIR" == /* || "$REMOTE_WORKDIR" == "~"* ]]; then
    remote_base="$REMOTE_WORKDIR"
  else
    remote_base="${remote_repo%/}/${REMOTE_WORKDIR}"
  fi

  local job_id
  job_id="$(date +"%Y%m%d-%H%M%S")-$RANDOM"
  local remote_job_dir="${remote_base%/}/${job_id}"
  local remote_audio_path="${remote_job_dir}/${audio_filename}"
  local remote_output_name
  remote_output_name="$(basename "$local_output_path")"
  local remote_output_path="${remote_job_dir}/${remote_output_name}"

  echo "Preparing remote workspace on ${remote_target}…"
  local remote_mkdir_cmd="mkdir -p $(shell_quote "$remote_job_dir")"
  "${TAILSCALE_BIN}" ssh "${remote_target}" bash -lc "$remote_mkdir_cmd"

  echo "Uploading ${audio_filename} to ${remote_target}…"
  local upload_cmd="cat > $(shell_quote "$remote_audio_path")"
  "${TAILSCALE_BIN}" ssh "${remote_target}" bash -lc "$upload_cmd" < "$audio_path"

  local remote_env=()
  for var in HF_TOKEN CUDA_VISIBLE_DEVICES CUDNN_COMPAT_DIR MEETING_NOTES_ENV; do
    if [[ -n "${!var:-}" ]]; then
      remote_env+=("${var}=$(shell_quote "${!var}")")
    fi
  done

  local remote_command="cd $(shell_quote "$remote_repo") && "
  if (( ${#remote_env[@]} > 0 )); then
    remote_command+="${remote_env[*]} "
  fi
  remote_command+="${REMOTE_PIXI_BIN} run --environment ${REMOTE_PIXI_ENV} -- python -m meeting_notes.main $(shell_quote "$remote_audio_path") $(shell_quote "$remote_output_path")"
  for extra in "${passthrough[@]}"; do
    remote_command+=" $(shell_quote "$extra")"
  done

  echo "Starting transcription on ${remote_target}…"
  "${TAILSCALE_BIN}" ssh "${remote_target}" bash -lc "$remote_command"

  echo "Downloading notes (remote → ${local_output_path})…"
  local download_cmd="cat $(shell_quote "$remote_output_path")"
  "${TAILSCALE_BIN}" ssh "${remote_target}" bash -lc "$download_cmd" > "$local_output_path"

  if [[ -z "$KEEP_REMOTE_JOB" ]]; then
    local cleanup_cmd="rm -rf $(shell_quote "$remote_job_dir")"
    "${TAILSCALE_BIN}" ssh "${remote_target}" bash -lc "$cleanup_cmd"
  else
    echo "Remote artefacts kept at ${remote_target}:${remote_job_dir}"
  fi

  echo "Notes saved to ${local_output_path}"
}

run_http_remote() {
  if [[ $# -eq 0 ]]; then
    echo "Audio file is required when using --remote-http." >&2
    usage
    exit 1
  fi

  if [[ -z "$REMOTE_HTTP_ENDPOINT" ]]; then
    echo "Remote HTTP endpoint not configured." >&2
    exit 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required for HTTPS uploads." >&2
    exit 1
  fi

  local args=("$@")
  local positionals=()
  local passthrough=()
  local options_with_arg="--model --batch-size --temperature --beam-size"
  local expect_value=""
  local options_ended=0

  while [[ ${#args[@]} -gt 0 ]]; do
    local current="${args[0]}"
    args=("${args[@]:1}")

    if [[ -n "$expect_value" ]]; then
      passthrough+=("$current")
      expect_value=""
      continue
    fi

    if [[ $options_ended -eq 0 && "$current" == "--" ]]; then
      passthrough+=("$current")
      options_ended=1
      continue
    fi

    if [[ $options_ended -eq 0 && "$current" == --*=* ]]; then
      passthrough+=("$current")
      continue
    fi

    if [[ $options_ended -eq 0 && "$current" == --* ]]; then
      passthrough+=("$current")
      for opt in $options_with_arg; do
        if [[ "$current" == "$opt" ]]; then
          if [[ ${#args[@]} -eq 0 ]]; then
            echo "Missing value for option $current" >&2
            exit 1
          fi
          expect_value=1
          break
        fi
      done
      continue
    fi

    if [[ $options_ended -eq 0 && "$current" == -* ]]; then
      passthrough+=("$current")
      continue
    fi

    positionals+=("$current")
  done

  if [[ ${#positionals[@]} -lt 1 ]]; then
    echo "Audio file not supplied; pass it after any options." >&2
    exit 1
  fi

  local audio_arg="${positionals[0]}"
  local audio_path
  audio_path="$(resolve_path "$audio_arg")"
  if [[ ! -f "$audio_path" ]]; then
    echo "Audio file not found: $audio_arg" >&2
    exit 1
  fi

  local audio_filename
  audio_filename="$(basename "$audio_path")"
  local audio_stem="${audio_filename%.*}"

  local local_output_path
  if [[ ${#positionals[@]} -ge 2 ]]; then
    local_output_path="$(resolve_path "${positionals[1]}")"
  else
    local timestamp
    timestamp="$(date +"%Y%m%d-%H%M%S")"
    local_output_path="$(pwd)/remote-results/${timestamp}-${audio_stem}.md"
  fi
  mkdir -p "$(dirname "$local_output_path")"

  local upload_url="${REMOTE_HTTP_ENDPOINT%/}/upload"
  echo "Uploading ${audio_filename} to ${upload_url}…"

  local options_json="[]"
  if (( ${#passthrough[@]} > 0 )); then
    local pybin
    pybin=$(python_bin)
    options_json=$("${pybin}" -c 'import json, sys; print(json.dumps(sys.argv[1:]))' "${passthrough[@]}")
  fi

  local curl_args=(
    --silent --show-error --fail
    --form "file=@${audio_path};filename=${audio_filename}"
    --form-string "output_name=$(basename "$local_output_path")"
  )
  if [[ "${options_json}" != "[]" ]]; then
    curl_args+=(--form-string "options=${options_json}")
  fi

  local response
  if ! response=$(curl "${curl_args[@]}" "$upload_url"); then
    echo "Upload failed." >&2
    exit 1
  fi

  local pybin
  pybin=$(python_bin)

  local job_id status_url result_url
  job_id=$(printf '%s' "$response" | "${pybin}" -c 'import json, sys; print(json.load(sys.stdin)["job_id"])') || {
    echo "Unable to parse job_id from server response." >&2
    echo "$response"
    exit 1
  }

  status_url=$(printf '%s' "$response" | "${pybin}" -c 'import json, sys; print(json.load(sys.stdin)["status_url"])')
  result_url=$(printf '%s' "$response" | "${pybin}" -c 'import json, sys; print(json.load(sys.stdin)["result_url"])')

  echo "Job ${job_id} queued. Polling status…"
  local start_time
  start_time="$(date +%s)"

  while true; do
    local status_json
    if ! status_json=$(curl --silent --show-error --fail "$status_url"); then
      echo "Failed to fetch job status." >&2
      exit 1
    fi
    local job_status
    job_status=$(printf '%s' "$status_json" | "${pybin}" -c 'import json, sys; print(json.load(sys.stdin)["status"])')
    case "$job_status" in
      completed)
        echo "Transcription complete. Downloading notes…"
        if ! curl --silent --show-error --fail "$result_url" -o "$local_output_path"; then
          echo "Failed to download notes from $result_url" >&2
          exit 1
        fi
        echo "Notes saved to ${local_output_path}"
        return 0
        ;;
      error)
        local job_error
        job_error=$(printf '%s' "$status_json" | "${pybin}" -c 'import json, sys; data = json.load(sys.stdin); print(data.get("error", "unknown error"))')
        echo "Remote transcription failed: $job_error" >&2
        exit 1
        ;;
      processing)
        echo "  … job is processing."
        ;;
      pending)
        echo "  … job pending in queue."
        ;;
      *)
        echo "Unexpected job status: $job_status" >&2
        ;;
    esac

    local now
    now="$(date +%s)"
    if (( now - start_time > HTTP_TIMEOUT )); then
      echo "Timed out waiting for remote transcription after ${HTTP_TIMEOUT}s." >&2
      exit 1
    fi
    sleep 5
  done
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tailscale-host)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--tailscale-host expects a value." >&2
        exit 1
      fi
      TAILSCALE_HOST="$1"
      shift
      ;;
    --tailscale-user)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--tailscale-user expects a value." >&2
        exit 1
      fi
      TAILSCALE_USER="$1"
      shift
      ;;
    --tailscale-repo)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--tailscale-repo expects a value." >&2
        exit 1
      fi
      REMOTE_REPO="$1"
      shift
      ;;
    --tailscale-workdir)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--tailscale-workdir expects a value." >&2
        exit 1
      fi
      REMOTE_WORKDIR="$1"
      shift
      ;;
    --tailscale-keep)
      KEEP_REMOTE_JOB=1
      shift
      ;;
    --remote-http)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--remote-http expects a value." >&2
        exit 1
      fi
      REMOTE_HTTP_ENDPOINT="$1"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        POSITIONAL+=("$1")
        shift
      done
      break
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done
set -- "${POSITIONAL[@]}"

if [[ -n "$TAILSCALE_HOST" ]]; then
  run_remote "$@"
  exit 0
fi

if [[ -n "$REMOTE_HTTP_ENDPOINT" ]]; then
  run_http_remote "$@"
  exit 0
fi

if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

"${PIXIE_BIN}" run --environment "${DEFAULT_PIXI_ENV}" -- python -m meeting_notes.main "$@"
