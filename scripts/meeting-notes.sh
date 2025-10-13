#!/bin/bash

# Thin wrapper around `uv run` so moderators can launch transcription quickly.
# Usage: meeting-notes.sh <audio-file> [output-file]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UV_PYTHON_VERSION="${UV_PYTHON_VERSION:-3.12}"
TORCH_VARIANT="${UV_TORCH_VARIANT:-auto}"
TORCH_SPEC="${UV_TORCH_SPEC:-torch==2.5.1}"
TORCHAUDIO_SPEC="${UV_TORCHAUDIO_SPEC:-torchaudio==2.5.1}"

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
  cat <<'EOF'
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
EOF
}

shell_quote() {
  local s=$1
  s=${s//\'/\'\\\'\'}
  printf "'%s'" "$s"
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

  local audio_arg=""
  local output_arg=""
  if [[ ${#positionals[@]} -ge 1 ]]; then
    audio_arg="${positionals[0]}"
  fi
  if [[ ${#positionals[@]} -ge 2 ]]; then
    output_arg="${positionals[1]}"
  fi

  if [[ -z "$audio_arg" ]]; then
    echo "Audio file not supplied; pass it after any options." >&2
    exit 1
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
  if [[ -z "$TAILSCALE_HOST" ]]; then
    echo "--tailscale-host requires a hostname or MagicDNS name." >&2
    exit 1
  fi
  if [[ -n "$TAILSCALE_USER" ]]; then
    remote_target="${TAILSCALE_USER}@${TAILSCALE_HOST}"
  else
    remote_target="${TAILSCALE_HOST}"
  fi

  local remote_repo="$REMOTE_REPO"
  if [[ -z "$remote_repo" ]]; then
    remote_repo="~/whisper-meeting-notes"
  fi

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
  for var in HF_TOKEN UV_TORCH_VARIANT UV_PYTHON_VERSION UV_TORCH_SPEC UV_TORCHAUDIO_SPEC CUDA_VISIBLE_DEVICES CUDNN_COMPAT_DIR; do
    if [[ -n "${!var:-}" ]]; then
      remote_env+=("${var}=$(shell_quote "${!var}")")
    fi
  done

  local remote_command="cd $(shell_quote "$remote_repo") && "
  if (( ${#remote_env[@]} > 0 )); then
    remote_command+="${remote_env[*]} "
  fi
  remote_command+="./scripts/meeting-notes.sh $(shell_quote "$remote_audio_path") $(shell_quote "$remote_output_path")"
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

  local output_name
  output_name="$(basename "$local_output_path")"

  local curl_args=(
    --silent --show-error --fail
    --form "file=@${audio_path};filename=${audio_filename}"
    --form-string "output_name=${output_name}"
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
  start_time=$(date +%s)

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
    now=$(date +%s)
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

if [[ -n "$TAILSCALE_HOST" && -n "$REMOTE_HTTP_ENDPOINT" ]]; then
  echo "Cannot use --tailscale-host and --remote-http together." >&2
  exit 1
fi

if [[ -n "$TAILSCALE_HOST" ]]; then
  run_remote "$@"
  exit 0
fi

if [[ -n "$REMOTE_HTTP_ENDPOINT" ]]; then
  run_http_remote "$@"
  exit 0
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required. Install via \"pip install uv\" or your package manager." >&2
  exit 1
fi

echo "Ensuring dependencies are in sync (first run will download models)…"
uv sync --project "${PROJECT_ROOT}" --python "${UV_PYTHON_VERSION}" --frozen 2>/dev/null \
  || uv sync --project "${PROJECT_ROOT}" --python "${UV_PYTHON_VERSION}"

ensure_torch() {
  local desired_variant="${TORCH_VARIANT}"
  local os_name
  os_name="$(uname -s)"

  if [[ "${desired_variant}" == "auto" ]]; then
    if command -v nvidia-smi >/dev/null 2>&1; then
      desired_variant="cu124"
    else
      desired_variant="cpu"
    fi
    echo "Auto-selecting Torch variant: ${desired_variant}"
  fi

  case "${desired_variant}" in
    cpu)
      if [[ "${os_name}" == "Darwin" ]]; then
        torch_index="" # use default PyPI for macOS
      else
        torch_index="https://download.pytorch.org/whl/cpu"
      fi
      ;;
    cu124)
      torch_index="https://download.pytorch.org/whl/cu124"
      ;;
    none)
      return 0
      ;;
    *)
      echo "Unknown UV_TORCH_VARIANT='${desired_variant}'. Supported: auto, cpu, cu124, none." >&2
      exit 1
      ;;
  esac

  current_variant=$(uv run --project "${PROJECT_ROOT}" --python "${UV_PYTHON_VERSION}" python - <<'PY'
try:
    import torch
except Exception:
    print("missing")
else:
    print("cuda" if torch.version.cuda else "cpu")
PY
  )
  current_variant=$(printf '%s' "${current_variant}" | tr -d '\r\n')

  if [[ "${desired_variant}" == "cpu" && "${current_variant}" == "cpu" ]]; then
    return 0
  fi

  if [[ "${desired_variant}" == "cu124" && "${current_variant}" == "cuda" ]]; then
    return 0
  fi

  echo "Installing Torch stack (${desired_variant})…"
  if [[ -n "${torch_index:-}" ]]; then
    uv run --project "${PROJECT_ROOT}" --python "${UV_PYTHON_VERSION}" \
      pip install --no-deps --upgrade "${TORCH_SPEC}" "${TORCHAUDIO_SPEC}" --index-url "${torch_index}"
  else
    uv run --project "${PROJECT_ROOT}" --python "${UV_PYTHON_VERSION}" \
      pip install --no-deps --upgrade "${TORCH_SPEC}" "${TORCHAUDIO_SPEC}"
  fi
}

ensure_torch

if [[ -n "${HF_TOKEN:-}" ]]; then
  echo "HF_TOKEN detected – diarisation will be enabled."
else
  echo "HF_TOKEN not set – transcript will use a single default speaker (export HF_TOKEN to enable diarisation)."
fi

uv run --project "${PROJECT_ROOT}" --python "${UV_PYTHON_VERSION}" meeting-notes "$@"
