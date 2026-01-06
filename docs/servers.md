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
