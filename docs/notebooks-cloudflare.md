# Jupyter + Voila via Cloudflare Tunnel (multi-machine)

This repo provides a reusable template under `notebooks/` for hosting JupyterLab and Voila behind Cloudflare Tunnel + Cloudflare Access.

## Hostnames

- WSU: `wsu-nb.newlineages.com`, `wsu-voila.newlineages.com`
- Dori: `dori-nb.newlineages.com`, `dori-voila.newlineages.com`

## Bootstrap (per machine)

```bash
cd notebooks
pixi install
pixi run python -c "import pandas, matplotlib"
```

Run locally (no browser on host is fine):

```bash
./scripts/run_lab.sh
./scripts/run_voila.sh
```

## Cloudflared tunnel

1. Ensure `cloudflared` is in `PATH` (`/usr/local/bin/cloudflared` or `~/bin/cloudflared`).
2. Create a tunnel using the local cert at `~/.cloudflared/cert.pem`:
   ```bash
   cloudflared tunnel create <TUNNEL_NAME>
   ```
3. Route DNS:
   ```bash
   cloudflared tunnel route dns <TUNNEL_NAME> wsu-nb.newlineages.com
   cloudflared tunnel route dns <TUNNEL_NAME> wsu-voila.newlineages.com
   ```
4. Copy `notebooks/cloudflared-config.example.yml` to `~/.cloudflared/config.yml` and update the UUID + hostnames.
5. Run the tunnel:
   ```bash
   TUNNEL_NAME=<TUNNEL_NAME> ./notebooks/scripts/run_tunnel.sh
   ```

## Cloudflare Access (private apps)

Create two Access apps (one per hostname). Allowlist **fmschulz@gmail.com** for now.

To make invites easy, create an Access **Group** (e.g. `notebook-users`) and update the policy to allow that group. Add new emails to the group as needed.

## Notes

- Keep Jupyter/Voila bound to `127.0.0.1` so only the tunnel can reach them.
- Each machine should have its own tunnel + hostnames.
