# Jupyter + Voila via Cloudflare Tunnel (multi-machine)

This repo provides a reusable template under `notebooks/` for hosting JupyterLab and Voila behind Cloudflare Tunnel + Cloudflare Access.

## Hostnames

Primary hostnames (single machine):
- `nb.newlineages.com`
- `voila.newlineages.com`

If you need multiple machines simultaneously, use machine-specific hostnames (e.g. `wsu-nb.*`, `dori-nb.*`) and create separate tunnels + Access apps for each.

If you run a server on a second machine, do **not** reuse the shared hostnames unless you intend to switch DNS over to that machine. Each machine should have its own tunnel and hostnames for concurrent use.

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

Serve a single notebook with Voila (useful for sharing one report):
```bash
./scripts/run_voila_single.sh /path/to/notebook.ipynb
```

## Cloudflared tunnel

1. Ensure `cloudflared` is in `PATH` (`/usr/local/bin/cloudflared` or `~/bin/cloudflared`).
2. Create a tunnel using the local cert at `~/.cloudflared/cert.pem`:
   ```bash
   cloudflared tunnel create <TUNNEL_NAME>
   ```
3. Route DNS (choose either the shared hostnames or machine-specific ones):
   ```bash
   cloudflared tunnel route dns <TUNNEL_NAME> <machine>-nb.newlineages.com
   cloudflared tunnel route dns <TUNNEL_NAME> <machine>-voila.newlineages.com
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
- Each machine should have its own tunnel if you need concurrent access from multiple hosts.
- When protected by Cloudflare Access, disable the Jupyter token/password and enable remote access/trusted headers so the proxy host header is accepted. The default `pixi.toml` does this.
- Jupyter’s file browser root is set to `~/dev` by default. Override with `JUPYTER_ROOT=/path` when starting Lab if you want a different root.
- See `docs/servers.md` for the full server runbook and troubleshooting.
