# Ubuntu Packages Checklist (WSU)

Shortlist for matching the fw13 terminal tooling on Ubuntu 22.04.

## Apt Packages

```bash
sudo apt update
sudo apt install -y \
  git curl wget jq ripgrep fzf fd-find bat btop gh \
  duf hexyl tldr zoxide \
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

## Modern CLI Tools Not in Apt (Cargo)

```bash
cargo install \
  bottom procs dust sd ouch xh just \
  eza starship atuin git-delta tealdeer \
  yazi-fm yazi-cli
```

## YAML (yq)

Ubuntu 22.04 doesn’t ship the mikefarah `yq` by default. Choose one:

- **pipx** (lightweight):
  ```bash
  pipx install yq
  ```
- **Binary release** from upstream (preferred for full compatibility)

## GPU Driver Check

```bash
ubuntu-drivers devices
nvidia-smi
```

## NVIDIA/CUDA Maintenance (Ubuntu 22.04 LTS)

This workstation is pinned to the 580 driver series and CUDA 13.0. Keep the driver and `nvidia-utils` packages in the same series.

```bash
# Inspect recommended drivers
ubuntu-drivers devices

# Install a specific driver series (example: 580)
sudo apt install -y nvidia-driver-580 nvidia-utils-580

# Verify driver + CUDA runtime
nvidia-smi
```

For CUDA toolkit updates, follow NVIDIA's Ubuntu 22.04 repo instructions and match the toolkit to the installed driver series. After updates, reboot and validate with `nvidia-smi` plus a small CUDA workload.
