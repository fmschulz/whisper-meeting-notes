# Server Runbook (Jupyter/Voila + Cloudflare)

This repo ships a reproducible notebook hosting setup under `notebooks/` using Pixi + JupyterLab + Voila, published through Cloudflare Tunnel and protected by Cloudflare Access.

## Architecture

- JupyterLab runs locally: `127.0.0.1:8891`
- Voila runs locally: `127.0.0.1:8866`
- Cloudflare Tunnel maps public hostnames to those local ports
- Cloudflare Access gates all requests (Google login + allowlist)

## Hostnames

Current shared hostnames:
- `nb.newlineages.com`
- `voila.newlineages.com`

If multiple machines need concurrent access, use machine-specific hostnames (e.g. `wsu-nb.*`, `dori-nb.*`) and create separate tunnels + Access apps.

## Using a Different Machine (Remote Host)

You can run a notebook server on another machine without touching the WSU server **as long as you use machine-specific hostnames**.

**Do you need to stop WSU?**
- **No**, if the remote machine uses its own hostnames (e.g. `dori-nb.*`, `dori-voila.*`).
- **Yes**, if you try to reuse `nb.newlineages.com` and `voila.newlineages.com`, because DNS can only point to one tunnel at a time.

**Do you need to copy secrets?**
- The remote machine needs **its own** Cloudflare tunnel credentials:
  - Either run `cloudflared tunnel login` on that machine (recommended) and create a new tunnel there,
  - Or copy the tunnel credentials JSON from the machine that created the tunnel (not recommended).
- If you’re automating Access/DNS via API, the remote machine needs the Cloudflare API token (store in `~/.secrets/cloudflare.env`).

### Remote Machine Checklist (example: dori)

1. **Clone repo + install deps**
   ```bash
   git clone <repo-url> controlcenter
   cd controlcenter
   git checkout main
   cd notebooks
   pixi install
   ```
2. **Install cloudflared (user-level)** and ensure it’s on `PATH`.
3. **Create a tunnel**
   ```bash
   cloudflared tunnel login
   cloudflared tunnel create dori-notebooks
   ```
4. **Route DNS to machine-specific hostnames**
   ```bash
   cloudflared tunnel route dns dori-notebooks dori-nb.newlineages.com
   cloudflared tunnel route dns dori-notebooks dori-voila.newlineages.com
   ```
5. **Write `~/.cloudflared/config.yml`** with the new tunnel UUID and hostnames.
6. **Create Access apps + policies** for:
   - `dori-nb.newlineages.com`
   - `dori-voila.newlineages.com`
   Allowlist: `fmschulz@gmail.com` (or Access group).
7. **Start services**
   ```bash
   ./scripts/run_lab.sh
   ./scripts/run_voila.sh
   TUNNEL_NAME=dori-notebooks ./scripts/run_tunnel.sh
   ```

## Setup (per machine)

```bash
cd notebooks
pixi install
```

## Start/Stop

JupyterLab (root defaults to `~/dev`):
```bash
./scripts/run_lab.sh
```

Voila:
```bash
./scripts/run_voila.sh
```

Voila (single notebook):
```bash
./scripts/run_voila_single.sh /path/to/notebook.ipynb
```

Tunnel:
```bash
TUNNEL_NAME=nelli-notebooks ./scripts/run_tunnel.sh
```

To override the root directory Jupyter shows:
```bash
JUPYTER_ROOT=/path/to/dir ./scripts/run_lab.sh
```

## Cloudflare Tunnel config

Local config file:
- `~/.cloudflared/config.yml`

It should point to the tunnel UUID and map `nb.newlineages.com` and `voila.newlineages.com` to the local ports.

For a remote machine, create a **new tunnel** and map **machine-specific hostnames** to avoid conflict with WSU.

## Cloudflare Access

- Login method: **Google**
- Allowlist: `fmschulz@gmail.com` (expand by adding a Group + policy)

## Troubleshooting

- **502 Bad Gateway**: cloudflared is running but local services are down. Start Jupyter/Voila.
- **403 / MIME errors on static assets**: Jupyter is rejecting the proxied host header. Ensure the lab task includes:
  - `--ServerApp.allow_remote_access=True`
  - `--ServerApp.trust_xheaders=True`
  - `--ServerApp.token=` and `--ServerApp.password=` when Access is enforced
- **Login code not received**: verify Access is set to Google login and the allowlist includes your email.

## Logs

- Jupyter: `notebooks/logs/jupyter.log`
- Voila: `notebooks/logs/voila.log`
- Tunnel: `~/.cloudflared/nelli-notebooks.log`
