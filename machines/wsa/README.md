# wsa Machine Backup

This directory snapshots the current `fsws-arch` configuration so the system can
be rebuilt if needed. The source is `../fsws-arch-config/` and is copied into:

- `machines/wsa/fsws-arch-config/`

Excluded from the snapshot:
- `.git/`
- `logs/`
- `.claude/`

To restore, follow the instructions in:
- `machines/wsa/fsws-arch-config/README.md`
