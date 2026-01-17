#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Copy /etc/munge/munge.key to multiple nodes over Tailscale SSH
# Usage: ./scripts/scp-munge-key.sh <user> <host1> [host2 ...]

if [ $# -lt 2 ]; then
  echo "Usage: $0 <user> <host1> [host2 ...]" >&2
  exit 1
fi

USER_NAME="$1"; shift

if [ ! -f /etc/munge/munge.key ]; then
  echo "/etc/munge/munge.key not found on this machine" >&2
  exit 1
fi

for host in "$@"; do
  echo "==> Copying munge key to $host"
  scp /etc/munge/munge.key "${USER_NAME}@${host}:/tmp/munge.key"
  ssh "${USER_NAME}@${host}" 'sudo mkdir -p /etc/munge && sudo mv /tmp/munge.key /etc/munge/ && sudo chown munge:munge /etc/munge/munge.key && sudo chmod 0400 /etc/munge/munge.key && sudo systemctl restart munge'
done

echo "All done."

