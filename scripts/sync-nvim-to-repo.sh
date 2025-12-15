#!/bin/bash
set -euo pipefail

step() {
  printf '▶ %s\n' "$1"
}

die() {
  printf '✖ %s\n' "$1" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SOURCE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
DEST_DIR="${REPO_ROOT}/configs/nvim"

if [[ ! -d "$SOURCE_DIR" ]]; then
  die "Missing Neovim config dir: $SOURCE_DIR"
fi

mkdir -p "$DEST_DIR"

step "Syncing $SOURCE_DIR -> $DEST_DIR"
rsync -a --delete --exclude '.github/' "$SOURCE_DIR/" "$DEST_DIR/"

step "Done. Review changes with: git diff"
