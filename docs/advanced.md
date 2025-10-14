# Advanced Usage

This page keeps the extended guidance that used to live in the README. Stick to the short quick-start there for day-to-day work; check here when you need extra context or to tweak the setup.

---

## Environment Profiles

| Profile | Install command | Primary use |
|---------|-----------------|-------------|
| Capture-only | `pixi install -e capture` | Laptops that only record and upload audio |
| CPU transcription | `pixi install -e cpu` | Run WhisperX locally on CPU |
| GPU workstation | `pixi install -e gpu` | Full transcription + drop service on an NVIDIA host |

```bash
git clone https://github.com/fmschulz/whisper-meeting-notes.git
cd whisper-meeting-notes
curl -fsSL https://pixi.sh/install.sh | bash
```

Choose the profile that matches the machine, then follow the relevant sections below.

## CLI Reference

```
./scripts/meeting-notes.sh <audio> [output.md] [options]
```

Key flags:

- `--model large-v3` (default): WhisperX model.
- `--batch-size 16` (default), `--temperature 0.0`, `--beam-size 5`: decoding controls.
- `--min-speakers` / `--max-speakers`: diarisation hints (set both to the same value to fix the speaker count).
- `--no-diarisation`: skip speaker attribution even with `HF_TOKEN`.
- `--remote-http URL`: upload audio via HTTPS instead of local transcription.
- `--tailscale-host HOST`: copy audio over `tailscale ssh` and run remotely.
- Everything after `--` is forwarded through wrappers like `record-and-upload`.

Example (local CPU):

```bash
pixi install -e cpu
pixi run -e cpu meeting-notes recordings/all-hands.wav \
  --min-speakers 2 --max-speakers 4
```

## Recording Options

- **Meeting platform exports** (Zoom, Meet, Teams) feed directly into the CLI.
- **Bundled recorder**  
  ```bash
  ./scripts/record-audio.sh               # until Ctrl+C
  ./scripts/record-audio.sh --list        # list inputs
  ./scripts/record-audio.sh --source <name> --duration 1800
  ```
- **Wayland/Hyprland**: `wf-recorder -a -f session.mka`.
- **Command line FFmpeg**:  
  ```bash
  ffmpeg -f pulse -i default -c:a flac recordings/session.flac
  ```
- **Hardware recorder**: copy the WAV/FLAC into `recordings/` and run the CLI.

## GPU Workstation Setup

```bash
pixi install -e gpu
./scripts/setup-drop-service.sh
systemctl --user status meeting-notes-drop.service
```

What the helper does:

- Installs the Pixi GPU environment.
- Writes `~/.config/systemd/user/meeting-notes-drop.service`.
- Configures `tailscale serve` for `/meeting-notes`.
- Saves the HTTPS endpoint to `.remote-http-endpoint` (picked up by the capture script).

Environment knobs:

- `DROP_SERVICE_CUDA_VISIBLE_DEVICES`: choose a specific GPU index.
- `CUDNN_COMPAT_DIR`: directory containing cuDNN 8 runtime libraries (e.g., `~/.local/cudnn8/lib`).
- `HF_TOKEN`: Hugging Face token with access to `pyannote/speaker-diarization-3.1`.

The service listens on `127.0.0.1:8040` and publishes e.g. `https://hostname.tailnet.ts.net/meeting-notes`. Check status with:

```bash
systemctl --user status meeting-notes-drop.service
tailscale serve status
```

## Remote Workflows

### Tailscale SSH shortcut

```bash
./scripts/meeting-notes.sh --tailscale-host gpu-box recordings/file.wav
```

The wrapper will:

1. `tailscale ssh gpu-box "mkdir -p ..."`
2. Stream the audio to the remote repository.
3. Run `pixel run --environment gpu -- python -m meeting_notes.main` remotely.
4. Copy the Markdown back.
5. Clean up remote artifacts (unless `--tailscale-keep` or `TAILSCALE_KEEP_REMOTE_JOB=1`).

Optional flags: `--tailscale-user`, `--tailscale-repo`, `--tailscale-workdir`.

### HTTPS uploads (no Tailscale on client)

1. Ensure the drop service is running on the workstation (see setup section).
2. Expose it via `tailscale serve --https=443 --set-path=/meeting-notes http://127.0.0.1:8040`.
3. On any laptop:
   ```bash
   ./scripts/meeting-notes.sh --remote-http https://host/meeting-notes recordings/file.wav
   ```
4. Markdown lands in `remote-results/<timestamp>-<stem>.md`. Logs are available via `log_url` or under `dropbox/logs/<job>.log`.

Set `REMOTE_HTTP_ENDPOINT` if you want a default:

```bash
export REMOTE_HTTP_ENDPOINT=https://host/meeting-notes
./scripts/meeting-notes.sh --remote-http recordings/file.wav
```

## Diarisation Notes

- Hugging Face token must have accepted the pyannote T&Cs:
  - https://huggingface.co/pyannote/speaker-diarization-3.1
  - https://huggingface.co/pyannote/segmentation-3.0
- The first diarisation run downloads ~360 MB of alignment weights; later runs skip the download.
- `--min-speakers` / `--max-speakers` help on short clips (<15 s) or when voices overlap heavily. Leaving them unset lets pyannote infer the count.
- If diarisation fails, the log will show the failure reason (missing token, gated model, etc.) and transcription continues with a single speaker label.

## Miscellaneous Tips

- `pixi shell -e gpu` opens an interactive environment with all GPU deps.
- `pixi run -e capture record-and-upload -- --model medium` chooses a smaller Whisper model.
- `./scripts/meeting-notes.sh -- --help` prints the Python CLI options.
- Set `UV_TORCH_VARIANT=cu124` or similar when you need a specific CUDA wheel.
