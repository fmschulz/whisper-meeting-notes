# FSWS Cluster Setup Guide

This guide sets up Tailscale SSH with tags, then a minimal Slurm cluster (no accounting) over your tailnet. Works on Arch Linux using AUR for Slurm.

## Overview
- Controller: runs `slurmctld` and manages the cluster.
- Nodes: run `slurmd` and execute jobs.
- Transport: Tailscale; use MagicDNS names or Tailscale IPs in configs.

## Tailscale
1) Install and start:
   - `sudo pacman -S tailscale`
   - `sudo systemctl enable --now tailscaled`
2) Create an auth key (Admin console → Settings → Keys). Add tags like `tag:fsws`, `tag:slurm-controller`, `tag:slurm-node`.
3) Bring up with SSH and tags:
   - `sudo tailscale up --authkey tskey-... --ssh --advertise-tags=tag:fsws --hostname fsws`
4) Verify:
   - `tailscale status` and `tailscale ip -4`

ACL examples (paste into admin console → Access controls):
```json
{
  "ssh": [
    {"action":"accept","src":["group:admins"],"dst":["tag:fsws"],"users":["autogroup:nonroot"]}
  ],
  "acls": [
    {"action":"accept","src":["tag:slurm-controller"],"dst":["tag:slurm-node:*:6817-6819"]},
    {"action":"accept","src":["tag:slurm-node"],"dst":["tag:slurm-controller:*:6817-6819"]}
  ]
}
```

## Slurm (Minimal, No Accounting)
Run on each machine (controller first):
- `sudo ./scripts/setup-slurm-tailscale.sh --role controller --cluster-name fsnet --tags tag:fsws --hostname fsws --authkey tskey-...`
- On nodes:
  - `sudo ./scripts/setup-slurm-tailscale.sh --role node --cluster-name fsnet --controller fsws --tags tag:slurm-node --hostname <node-name> --authkey tskey-...`

The script installs: `slurm` (AUR), `munge`, `tailscale`, `chrony`; configures `/etc/slurm/slurm.conf`, generates or installs a `munge.key`, and enables services.

Copy munge key from controller to nodes (one-time):
- `./scripts/scp-munge-key.sh <user> node1.tailnet.ts.net node2.tailnet.ts.net`

Verify from controller:
- `sinfo`
- `scontrol show nodes`
- `srun -N1 -w <node> hostname`

## Optional: Accounting (MariaDB)
Slurm accounting requires MariaDB/MySQL via `slurmdbd`. DuckDB is not supported.
1) Controller only: `sudo pacman -S mariadb && sudo systemctl enable --now mariadb && mysql_secure_installation`
2) Create DB/user: `CREATE DATABASE slurm_acct_db; GRANT ALL ON slurm_acct_db.* TO 'slurm'@'localhost' IDENTIFIED BY 'STRONG_PASS';`
3) `/etc/slurm/slurmdbd.conf` with MySQL creds; `sudo systemctl enable --now slurmdbd`.
4) Switch in `/etc/slurm/slurm.conf`:
   - `AccountingStorageType=accounting_storage/slurmdbd`
   - `AccountingStorageHost=<controller>`

## Notes
- Time sync: `chrony` is enabled for reliable cluster comms.
- Security: Tailscale binds SSH over tailnet, no public port exposure.
- Add more nodes: add `NodeName` lines to `/etc/slurm/slurm.conf` or leave `Nodes=ALL` with matching names.

