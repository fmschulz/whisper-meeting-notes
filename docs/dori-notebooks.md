# Dori Notebook Server (Cloudflare + Jupyter/Voila)

This document records the dori-specific setup performed on this branch.

## Hostnames

- `dori-nb.newlineages.com`
- `dori-voila.newlineages.com`

## Cloudflare Tunnel

- **Tunnel name**: `dori-notebooks`
- **Tunnel ID**: `fa70a91c-2b32-4e86-8bc3-44b8c6147d67`
- **Credentials**: `~/.cloudflared/fa70a91c-2b32-4e86-8bc3-44b8c6147d67.json`
- **Config**: `~/.cloudflared/config.yml`

Ingress mapping (local ports):
- JupyterLab: `127.0.0.1:8891`
- Voila: `127.0.0.1:8866`

DNS routing was created with:
```
cloudflared tunnel route dns dori-notebooks dori-nb.newlineages.com
cloudflared tunnel route dns dori-notebooks dori-voila.newlineages.com
```

## Cloudflare Access (automated)

Configured via Cloudflare API using:
- `~/.secrets/cloudflare.env`

This created/updated:
- Access apps for both hostnames
- Google IdP (if missing)
- Allowlist policy for `CLOUDFLARE_ACCESS_ALLOW_EMAIL`

## Jupyter + Voila (Pixi)

Repo template: `notebooks/` (copied from `wsu`).

Install:
```
cd ~/controlcenter/notebooks
pixi install
```

Jupyter root for this machine (default):
```
/clusterfs/jgi/scratch/science/mgs/nelli/
```
You can override per-run via `JUPYTER_ROOT=/path`.

## Background Services (tmux)

Active tmux sessions:
- `dori-lab`
- `dori-voila`
- `dori-tunnel`

Start (if not running):
```
tmux new -d -s dori-lab "cd ~/controlcenter/notebooks && JUPYTER_ROOT=/clusterfs/jgi/scratch/science/mgs/nelli/frederik/projects ./scripts/run_lab.sh"
tmux new -d -s dori-voila "cd ~/controlcenter/notebooks && ./scripts/run_voila.sh"
tmux new -d -s dori-tunnel "cd ~/controlcenter/notebooks && TUNNEL_NAME=dori-notebooks ./scripts/run_tunnel.sh"
```

Stop:
```
tmux kill-session -t dori-lab
tmux kill-session -t dori-voila
tmux kill-session -t dori-tunnel
```

Logs (if needed):
- Jupyter: `notebooks/logs/jupyter.log` (if enabled)
- Voila: `notebooks/logs/voila.log` (if enabled)
- Tunnel: `~/.cloudflared/dori-notebooks.log` (if configured)
