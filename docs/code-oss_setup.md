# Code OSS Remote SSH Setup (with Open Remote - SSH)

This guide captures the workaround we used to connect Code OSS 1.104.1 (Arch package `code`) to remote hosts via the `jeanp413.open-remote-ssh` extension. It addresses recent upstream changes where VSCodium removed the release suffix from `product.json`, causing the extension to fetch a non-existent server build and throw 404 errors. The steps consolidate fixes discussed in [open-remote-ssh#209](https://github.com/jeanp413/open-remote-ssh/issues/209) and the [Arch forum thread](https://bbs.archlinux.org/viewtopic.php?id=299731).

## Prerequisites

- Local workstation running Code OSS 1.104.1 (`/usr/lib/code` commit `0f0d87fa9e96c856c5212fc86db137ac0d783365`).
- OpenSSH client on the workstation; password or key access to the remote host(s).
- Remote host is Linux (x86_64) with `tar`, `curl` or `wget`, and home directory writable by the user.
- `jeanp413.open-remote-ssh` extension installed in Code OSS and enabled via `~/.vscode-oss/argv.json`:

  ```json
  {
      "enable-proposed-api": [
          "jeanp413.open-remote-ssh"
      ]
  }
  ```

## 1. Stage the VSCodium Remote Server Locally

Download the current VSCodium remote server tarball that matches the "full" version used in their `product.json`.

```bash
mkdir -p "$HOME/.cache/vscode-server"
cd "$HOME/.cache/vscode-server"
curl -L --fail -o vscodium-reh-linux-x64-1.104.16282.tar.gz \
  https://github.com/VSCodium/vscodium/releases/download/1.104.16282/vscodium-reh-linux-x64-1.104.16282.tar.gz
```

> Replace `1.104.16282` if VSCodium publishes a newer patch level. Use `curl https://api.github.com/repos/VSCodium/vscodium/releases | jq '.[0].tag_name'` to discover the latest tag.

## 2. Push the Server to Each Remote Host

```bash
COMMIT=0f0d87fa9e96c856c5212fc86db137ac0d783365
TARBALL="$HOME/.cache/vscode-server/vscodium-reh-linux-x64-1.104.16282.tar.gz"
HOSTS=(host1 host2)  # SSH config aliases; adjust as needed

for HOST in "${HOSTS[@]}"; do
  echo "==> $HOST"
  ssh "$HOST" "rm -rf ~/.vscode-server-oss/bin/$COMMIT && mkdir -p ~/.vscode-server-oss/bin/$COMMIT"
  scp "$TARBALL" "$HOST:/tmp/vscodium-server.tar.gz"
  ssh "$HOST" "tar -xf /tmp/vscodium-server.tar.gz -C ~/.vscode-server-oss/bin/$COMMIT --strip-components=1 && rm /tmp/vscodium-server.tar.gz"

  # Ensure Code OSS expects the correct metadata and binary name
  scp /usr/lib/code/product.json "$HOST:~/.vscode-server-oss/bin/$COMMIT/product.json"
  ssh "$HOST" "ln -sf codium-server ~/.vscode-server-oss/bin/$COMMIT/bin/code-server-oss"

  # Optional: migrate any existing VSCodium data out of the way
  ssh "$HOST" "if [ -d ~/.vscodium-server ]; then mv ~/.vscodium-server ~/.vscode-server-oss/data; fi"
done
```

### Why copy `product.json`?

The remote server refuses connections if the commit hash embedded in its `product.json` differs from the local editor. Copying the local `/usr/lib/code/product.json` to the remote server directory aligns the commit to `0f0d87f…`, eliminating the `Client refused: version mismatch` errors seen in the remote log.

## 3. Configure Code OSS Remote SSH Settings

Edit `~/.config/Code - OSS/User/settings.json`:

```json
{
    "workbench.colorTheme": "Gruvbox Light Medium",
    "remote.SSH.configFile": "/home/<YOUR_USER>/.ssh/config",
    "remote.SSH.serverDownloadUrlTemplate": "https://github.com/VSCodium/vscodium/releases/download/1.104.16282/vscodium-reh-${os}-${arch}-1.104.16282.tar.gz",
    "remote.SSH.experimental.serverBinaryName": "code-server-oss",
    "remote.SSH.remoteServerDownload": "neverDownload"
}
```

Key points:

- `serverDownloadUrlTemplate` hardcodes the correct version string; without the five-digit release suffix the extension builds an invalid URL (`…1.104.1..tar.gz`). Update both occurrences when VSCodium releases a new tag.
- `experimental.serverBinaryName` tells the extension to invoke the `code-server-oss` symlink we created above.
- `remoteServerDownload` set to `"neverDownload"` prevents the extension from retrying the broken default URL.

Restart Code OSS after saving the settings.

## 4. Verify Connection

1. Restart Code OSS to load the updated runtime arguments and settings.
2. Open the Command Palette → `Remote-SSH: Connect to Host…` → select `host1` (or another alias from `~/.ssh/config`).
3. Enter your password or passphrase as prompted.
4. The first successful connection writes to `~/.vscode-server-oss/.<commit>.log` on the remote and spawns the server on a random loopback port (see `listeningOn` line).

If you see `Client refused: version mismatch` in the remote log, re-check that:
- `/usr/lib/code/product.json` was copied to the remote server directory and contains `"commit": "0f0d87fa9e96c856c5212fc86db137ac0d783365"`.
- The symlink `~/.vscode-server-oss/bin/<commit>/bin/code-server-oss` exists and points to `codium-server`.
- Code OSS was restarted after editing `settings.json`.

If the extension still tries to download from `…1.104.1..tar.gz`, confirm that `remote.SSH.remoteServerDownload` is set to `"neverDownload"` and no workspace overrides are in effect.

## 5. Updating for Future Releases

When either Code OSS or VSCodium moves to a new commit:

1. Update `COMMIT` to the new `code-oss` commit hash (`code-oss --version` prints it).
2. Download the matching VSCodium tarball for the new tag and update the `serverDownloadUrlTemplate` URL/file name.
3. Rerun the staging loop for each remote host.
4. Replace the remote `product.json` with the one from `/usr/lib/code/product.json` for the new release.

## References

- **GitHub**: [jeanp413/open-remote-ssh#209](https://github.com/jeanp413/open-remote-ssh/issues/209)
- **Forums**: [Arch Linux thread – “How to make Open Remote - SSH work for vscode” (Sept 2024)](https://bbs.archlinux.org/viewtopic.php?id=299731)
- **VSCodium**: [PR #2299 – new version numbering scheme](https://github.com/VSCodium/vscodium/pull/2299)

Documented September 2025.
