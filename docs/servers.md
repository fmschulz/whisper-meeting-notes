# Server Runbook (Jupyter/Voila + Cloudflare)

The notebook hosting setup is **WSU-specific** and now lives on the `wsu` branch. To use or adapt it on other machines, check out `wsu` and copy the `notebooks/` folder and docs into the target machine branch.

Quick guidance:
- Use machine-specific hostnames (e.g., `dori-nb.*`, `dori-voila.*`) for concurrent servers.
- Create a new Cloudflare Tunnel per machine.
- Configure Cloudflare Access with Google login + allowlist.

See the full runbook on the `wsu` branch in `docs/servers.md`.
