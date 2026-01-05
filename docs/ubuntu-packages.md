# Ubuntu Packages Checklist (WSU)

Shortlist for matching the fw13 terminal tooling on Ubuntu 22.04.

## Apt Packages

```bash
sudo apt update
sudo apt install -y \
  git curl wget jq ripgrep fzf fd-find bat btop gh \
  unzip zip xz-utils bzip2 gzip \
  python3 python3-pip \
  build-essential cmake \
  neovim
```

## Command Name Compatibility

Ubuntu uses `fdfind` and `batcat`. Ensure the expected names exist:

```bash
mkdir -p ~/.local/bin
ln -sf "$(command -v fdfind)" ~/.local/bin/fd
ln -sf "$(command -v batcat)" ~/.local/bin/bat
```

## Rust-Based Tools (Cargo)

```bash
cargo install \
  eza zoxide starship atuin git-delta tealdeer just \
  yazi-fm yazi-cli
```

## GPU Driver Check

```bash
ubuntu-drivers devices
nvidia-smi
```
