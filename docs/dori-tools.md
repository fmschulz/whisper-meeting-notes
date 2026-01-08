# Dori CLI Tools (No Sudo)

This machine has no sudo. Install modern CLI tools into user space.

## Rust toolchain (user-level)

If `cargo` is not available yet, install Rust with rustup:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
```

## Install modern tools via cargo

```bash
xargs -a packages/cargo-tools.txt -r cargo install
```

## Optional non-Rust tools (user-level)

- `fzf`: clone to `~/.fzf` and run the install script.
- `direnv`: download a release binary to `~/.local/bin`.

These are optional; the bashrc enables them only if present.
