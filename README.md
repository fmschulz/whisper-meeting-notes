# Meeting Notes Kit

Fast tooling for moderators who need high-quality transcripts and diarised notes during panel discussions or workshops. The kit wraps [WhisperX](https://github.com/m-bain/whisperX) inside Pixi-managed environments and exports Markdown tables with per-speaker attribution.

## Quick Start (Laptop → GPU)

```bash
# one-time setup
git clone https://github.com/fmschulz/whisper-meeting-notes.git
cd whisper-meeting-notes
curl -fsSL https://pixi.sh/install.sh | bash
pixi install -e capture

# record audio (Ctrl+C to stop) and upload to the workstation
pixi run -e capture record-and-upload -- --min-speakers 2 --max-speakers 4
```

- The capture task reads `.remote-http-endpoint` (created by the GPU helper) so you rarely need to set `REMOTE_HTTP_ENDPOINT` manually.
- `--min-speakers` / `--max-speakers` guide diarisation; adjust or drop them if you want pyannote to decide automatically.
- Markdown results land in `remote-results/<timestamp>-<audio>.md`.

## When you need more

- **Run on the GPU workstation**  
  ```bash
  pixi install -e gpu
  ./scripts/setup-drop-service.sh   # writes systemd unit + .remote-http-endpoint
  systemctl --user status meeting-notes-drop.service
  ```
  Set `HF_TOKEN` before starting the service to enable diarisation. The helper pins CUDA to the first supported GPU and writes the HTTPS upload URL.

- **Plain CLI (CPU or GPU)**  
  ```bash
  pixi install -e cpu  # or gpu
  ./scripts/meeting-notes.sh recordings/example.wav \
    --model large-v3 --min-speakers 2 --max-speakers 4
  ```

- **Remote HTTP uploads without capture script**  
  ```bash
  ./scripts/meeting-notes.sh --remote-http https://host/meeting-notes file.wav
  ```
  The wrapper streams the audio, polls job status, and saves Markdown locally.

- **Troubleshooting diarisation**  
  - Ensure the drop service sees `HF_TOKEN` (`systemctl --user show meeting-notes-drop.service -p Environment`).
  - The first diarisation run downloads alignment models (~360 MB). Subsequent jobs reuse the cache.
  - If very short clips still merge voices, keep `--min-speakers` / `--max-speakers` or extend the recording.

## CLI Reference

```
./scripts/meeting-notes.sh <audio> [output.md] [options]
```

Key flags:

- `--model large-v3` (default): choose WhisperX model.
- `--batch-size 16` (default): inference batch size.
- `--temperature 0.0` / `--beam-size 5`: decoding controls.
- `--min-speakers` / `--max-speakers`: hint pyannote about speaker count.
- `--no-diarisation`: disable speaker attribution even when `HF_TOKEN` is present.
- `--remote-http URL`: upload via HTTPS instead of local transcription.
- Use `--` to pass options through the capture helper (example above).

### Other handy commands

| Scenario | Command |
|----------|---------|
| Run locally on CPU | `pixi install -e cpu && pixi run -e cpu meeting-notes recordings/file.wav` |
| Install GPU stack (interactive use) | `pixi install -e gpu && pixi shell -e gpu` |
| Bootstrap drop service | `./scripts/setup-drop-service.sh` |
| Manual upload from any machine | `./scripts/meeting-notes.sh --remote-http https://host/meeting-notes file.wav` |

### Recording ideas

- Meeting platform exports (`.mp4`, `.m4a`, `.wav`) work out of the box.
- `./scripts/record-audio.sh` wraps ffmpeg for quick captures (`--list` shows devices).
- Hardware recorders or OBS captures can be copied into `recordings/` and passed to the CLI.

### Remote workflow reminders

- `./scripts/meeting-notes.sh --tailscale-host gpu-box file.wav` uses `tailscale ssh` to run inside the remote repo.
- `--remote-http` mode stores transcripts under `remote-results/` and exposes logs at `dropbox/logs/<job>.log`.
- Keep `HF_TOKEN` and (if needed) `CUDNN_COMPAT_DIR` in the drop-service unit so diarisation and ONNX alignment succeed.

You can still follow the manual rsync/ssh flow below if you prefer finer control.

### CUDA 13 hosts (cuDNN notes)

The alignment and diarisation pieces depend on ONNX Runtime wheels that still link against **cuDNN 8**. If your GPU workstation only has CUDA 13/cuDNN 9 on the system, provide a compatibility copy of the cuDNN 8 runtime libraries and the wrapper will pick them up via `CUDNN_COMPAT_DIR`:

```bash
# example: fetch cuDNN 8.9.7 for CUDA 12.2 and unpack locally
curl -fLo /tmp/libcudnn8.deb \
  https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/libcudnn8_8.9.7.29-1+cuda12.2_amd64.deb
mkdir -p ~/.local/cudnn8/lib
dpkg-deb -x /tmp/libcudnn8.deb /tmp/libcudnn8
cp /tmp/libcudnn8/usr/lib/x86_64-linux-gnu/libcudnn*.so.* ~/.local/cudnn8/lib
```

By default `meeting-notes.sh` injects `~/.local/cudnn8/lib` into `LD_LIBRARY_PATH`; customise the location via `export CUDNN_COMPAT_DIR=/path/to/compat/lib`.

### Public uploads (no client-side Tailscale)

1. **Start the drop server on the GPU host** (typically bound to localhost):
   ```bash
   # quick start (auto configures tailscale serve + funnel if possible)
   pixi run -e gpu drop-service -- --port 8040 --workers 1

   # keep it running after logout (user systemd)
   systemctl --user daemon-reload
   systemctl --user enable --now meeting-notes-drop.service

   # disable automatic tailscale configuration and flip it on later yourself
   pixi run -e gpu drop-service -- --port 8040 --workers 1 --no-tailscale
   
   # or, manage the FastAPI app manually
   export DROP_SERVER_PORT=8040              # optional; defaults to 8000
   export DROP_MAX_WORKERS=1                # number of concurrent GPU jobs
   pixi run -e gpu drop-server
   ```
   Jobs are stored under `dropbox/jobs/<timestamp>-<jobid>` with logs in `dropbox/logs/`. The systemd unit lives at `~/.config/systemd/user/meeting-notes-drop.service` and defaults to `--no-tailscale` so you can manage `tailscale serve` / `tailscale funnel` yourself.

2. **Expose it securely via Tailscale Funnel** (HTTPS only, no extra software on laptops):
   ```bash
   tailscale serve --https=443 --set-path=/meeting-notes http://127.0.0.1:${DROP_SERVER_PORT:-8000}
   tailscale funnel --https=443 on
   ```
   The host’s MagicDNS name (for example `https://jgi-ont.tailfd4067.ts.net/meeting-notes`) becomes a public upload URL with TLS handled by Tailscale. (If `meeting-notes-drop-service` was launched without `--no-tailscale` it attempts the same commands; existing serve routes may still require manual reconciliation.)

3. **Run the CLI from any laptop without Tailscale installed**:
   ```bash
   ./scripts/meeting-notes.sh --remote-http https://jgi-ont.tailfd4067.ts.net/meeting-notes recordings/all-hands.wav
   ```
   The wrapper streams the file via HTTPS, polls the job queue, and downloads the Markdown into `remote-results/<timestamp>-<stem>.md` on the caller’s machine. A `log_url` is returned alongside the job ID for debugging (`dropbox/logs/<job>.log`).

4. **Optional environment knobs**:
   - Set `REMOTE_HTTP_ENDPOINT` on the laptop for a default endpoint (`--remote-http` becomes optional).
   - The drop server honours `HF_TOKEN`, `CUDNN_COMPAT_DIR`, and `CUDA_VISIBLE_DEVICES` from its environment before launching the transcription module.

For manual rsync/SSH workflows (when you prefer not to use the helpers):

```bash
rsync -avP meeting.m4a gpu-host:~/meetings/
ssh gpu-host
cd ~/whisper-meeting-notes
pixi install --environment gpu    # once per host
pixi run -e gpu meeting-notes ./meetings/meeting.m4a ./meetings/meeting-notes.md
```

Pull the resulting Markdown back via `rsync` or share it with your note-taking tools. The script automatically detects CUDA (`torch.cuda.is_available()`) and will use mixed-precision decoding when available.

## Git Workflow for Moderators

Each moderator can fork or clone this repository and commit their Markdown outputs in a separate branch if desired. Suggested flow during an event:

```bash
# fetch the latest toolkit
git pull

# create a working branch for the session
git checkout -b notes/2025-02-04-product-sync

# run the transcription
./scripts/meeting-notes.sh recordings/product-sync.wav notes/product-sync.md

# review & commit the generated notes
git add notes/product-sync.md
git commit -m "docs: add product sync notes"
```

## Troubleshooting

- **Menu flicker or GUI issues in Zoom**: launch Zoom through XWayland (`QT_QPA_PLATFORM=xcb`) before recording.
- **ffmpeg not found**: install via `sudo pacman -S ffmpeg` (Arch) or your distro equivalent.
- **No diarisation**: ensure `HF_TOKEN` is exported and the token has `pyannote` access.
- **Slow transcription**: push the audio to a GPU host and run the script there; results are compatible across machines.

Happy moderating!
