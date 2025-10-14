# Meeting Notes Kit

Fast tooling for moderators who need high-quality transcripts and diarised notes during panel discussions or workshops. The kit wraps [WhisperX](https://github.com/m-bain/whisperX) inside Pixi-managed environments and exports Markdown tables with per-speaker attribution.

## Features

- Uses the **`large-v3`** Whisper model with beam search and temperature fallback for top accuracy.
- Optional **speaker diarisation** via `pyannote.audio` when you provide a `HF_TOKEN` (multiple speakers are tagged automatically).
- Generates Markdown with a timestamped table for easy paste into docs or wikis.
- Works on laptops or remote GPU workstations; Pixi environments keep dependencies isolated per profile (capture, CPU, GPU).

## Environment Setup (Pixi)

```bash
# clone the toolkit
git clone https://github.com/fmschulz/whisper-meeting-notes.git
cd whisper-meeting-notes

# install pixi once (https://pixi.sh)
curl -fsSL https://pixi.sh/install.sh | bash
```

Choose the profile that matches the machine:

| Profile | Install command | Primary use |
|---------|-----------------|-------------|
| Capture-only | `pixi install -e capture` | Laptops that only record and upload audio |
| CPU transcription | `pixi install -e cpu` | Run WhisperX locally on CPU |
| GPU workstation | `pixi install -e gpu` | Full transcription + drop server on an NVIDIA host |

### Capture-only workflow

Run the capture task and the helper will pull the default HTTPS endpoint from `.remote-http-endpoint` (written by the GPU setup script) automatically:

```bash
pixi run -e capture record-and-upload
```

Override the endpoint or pass additional transcription flags if needed:

```bash
pixi run -e capture record-and-upload -- https://jgi-ont.tailfd4067.ts.net/meeting-notes --model medium
```

The task uses `ffmpeg` (PulseAudio monitor by default) and immediately calls `meeting-notes.sh --remote-http …` once the capture stops. Transcripts land in `remote-results/<timestamp>-session.md` on the laptop.

### CPU transcription

```bash
pixi install --environment cpu

# one-off run using Pixi
your@laptop$ pixi run -e cpu meeting-notes recordings/all-hands.wav

# or via the helper
your@laptop$ ./scripts/meeting-notes.sh recordings/all-hands.wav
```

Set `HF_TOKEN` beforehand to enable diarisation, and accept the pyannote terms (https://huggingface.co/pyannote/speaker-diarization-3.1).

### GPU workstation

```bash
pixi install --environment gpu

# optional: activate the environment for interactive work
pixi shell -e gpu
```

The GPU environment uses the official `pytorch` + `nvidia` channels (CUDA 12.4). WhisperX still expects cuDNN runtime libraries, so keep a compatibility copy (for example under `~/.local/cudnn8/lib`) and export `CUDNN_COMPAT_DIR` before starting the drop service. One way to obtain them on Ubuntu:

```bash
curl -fLo /tmp/libcudnn8.deb   https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/libcudnn8_8.9.7.29-1+cuda12.2_amd64.deb
mkdir -p ~/.local/cudnn8/lib
dpkg-deb -x /tmp/libcudnn8.deb /tmp/libcudnn8
cp /tmp/libcudnn8/usr/lib/x86_64-linux-gnu/libcudnn*.so.* ~/.local/cudnn8/lib
```

The helpers look at `MEETING_NOTES_ENV` (default `cpu`) to pick the local Pixi environment and at `TAILSCALE_REMOTE_PIXI_ENV` (default `gpu`) when running on a remote workstation.

> If the installed PyTorch build does not recognise your GPU architecture (for example, newer NVIDIA cards), the toolkit prints a warning and falls back to CPU execution automatically so jobs never fail.

### Drop service bootstrap (workstation)

Run the helper once on the workstation to install dependencies, create the systemd unit, and wire Tailscale Serve:

```bash
./scripts/setup-drop-service.sh
```

Optionally set `DROP_SERVICE_CUDA_VISIBLE_DEVICES` before running the helper to pin the service to a different GPU index.

The helper writes the detected HTTPS entrypoint into `.remote-http-endpoint`, which the CLI wrappers read automatically (no need to `export REMOTE_HTTP_ENDPOINT` on your laptop unless you override it).

The service listens on `127.0.0.1:8040`, publishes `https://jgi-ont.tailfd4067.ts.net/meeting-notes`, and pins WhisperX to the first supported GPU (auto-detected, falling back to `CUDA_VISIBLE_DEVICES=0`). Check status with `systemctl --user status meeting-notes-drop.service`.

## Capturing Audio

The toolkit expects you to provide a recorded audio file. Common ways moderators gather the raw audio:

- **Use the meeting platform’s recording feature.** Zoom, Meet, and Teams all export `.mp4`/`.m4a` files you can feed directly into the script.
- **Use the bundled recorder.** Run `./scripts/record-audio.sh` to start an `ffmpeg` capture with sane defaults. Add `--list` to see available inputs (PulseAudio/PipeWire sources on Linux, AVFoundation devices on macOS). Press `Ctrl+C` to stop recording; files land in `recordings/`.
 - **Use the bundled recorder (Linux/macOS).** Run `./scripts/record-audio.sh` to start an `ffmpeg` capture with sane defaults. Add `--list` to see available inputs (PulseAudio/PipeWire sources on Linux, AVFoundation devices on macOS). Press `Ctrl+C` to stop recording; files land in `recordings/`.
 - **Windows recording.** Use the OS recorder, OBS, or Zoom/Teams export to produce `.wav`/`.m4a` and pass it to the script.
- **Record locally on Wayland/Hyprland.** For quick captures, run `wf-recorder -a -f session.mka` (needs `wf-recorder` + `pamixer`). Press `Ctrl+C` when the meeting ends.
- **Record from the command line with FFmpeg.** Example for PipeWire default sink and mic:
  ```bash
  ffmpeg -f pulse -i default -c:a flac recordings/session.flac
  ```
  Replace `default` with a monitor source (e.g. `alsa_output.pci-0000_0c_00.4.analog-stereo.monitor`) to capture remote participants.
- **Hardware recorder.** If the room is mic’d, drop a USB recorder on the mix output and copy the WAV onto your laptop afterward.

Once you have an audio/video file, place it anywhere in your workspace and run the transcription step below.

## Usage

Record your meeting (any audio format supported by `ffmpeg`), then run:

```bash
./scripts/meeting-notes.sh path/to/recording.m4a
```

Windows (PowerShell):

```powershell
./scripts/meeting-notes.ps1 path\to\recording.m4a
```

Global convenience (optional):
- macOS/Linux: `ln -s "$(pwd)/scripts/meeting-notes.sh" "$HOME/bin/meeting-notes"` (ensure `$HOME/bin` is on `PATH`).
- Windows: add the repo `scripts\` directory to `PATH`, or create a PowerShell function alias.

Options:
- The first positional argument is the audio file.
- An optional second argument specifies the Markdown output (`.md`).
- If omitted, the script writes `<audio-stem>-notes-<timestamp>.md` alongside the source file (for example, `recordings/all-hands-notes-20240924-1730.md`).
- Pass `--min-speakers` / `--max-speakers` when you want to nudge diarisation toward a known speaker count (set both to the same value to force a fixed number).

When `HF_TOKEN` is exported the wrapper announces it and WhisperX runs pyannote diarisation; without the token every segment is tagged as a single default speaker.

Example output snippet:

```markdown
| Start | End | Speaker | Transcript |
|------:|----:|---------|------------|
| 00:00:01.230 | 00:00:07.840 | Speaker 1 | Welcome everyone, let's review the agenda. |
| 00:00:08.100 | 00:00:15.420 | Speaker 2 | I'd like to start with the feature rollout timeline... |
```

### Why use a GPU workstation?

Running `large-v3` on a dedicated GPU can cut transcription time drastically (minutes instead of tens of minutes on long recordings) and frees your laptop during live events. If the GPU host already has the kit cloned, you simply upload the captured audio, run the same script, and pull back the Markdown notes. The GPU path is optional but recommended for multi-hour sessions or back-to-back meetings where turnaround speed matters.

```mermaid
flowchart TD
    A["`Capture audio
- record-audio.sh
- Zoom export
- Hardware recorder`"] --> B["`Run meeting-notes.sh
(Laptop, CPU default)`"]
    B --> C["`Markdown transcript
with diarisation`"]
    A --> D["`Optional: Upload audio
to GPU workstation`"]
    D --> E["`Run meeting-notes.sh
on GPU (set UV_TORCH_VARIANT=cu124)`"]
    E --> C
```

## Remote GPU Workflow

If you already have a Tailscale-accessible workstation with this toolkit checked out, you can ship audio straight to it with a single flag on any laptop (Linux/macOS/Windows):

```bash
./scripts/meeting-notes.sh --tailscale-host gpu-box recordings/all-hands.wav
```

PowerShell (Windows):

```powershell
./scripts/meeting-notes.ps1 --tailscale-host gpu-box recordings\all-hands.wav
```

The wrapper will:

- stream the audio to the remote host over `tailscale ssh`
- run `meeting-notes.sh` in the remote repository (propagating `HF_TOKEN`, `UV_TORCH_*`, etc.)
- fetch the generated Markdown back to your machine
- clean up temporary files on the remote side (set `--tailscale-keep` or `TAILSCALE_KEEP_REMOTE_JOB=1` to inspect them)
- forward any additional CLI options (for example `--model`, `--beam-size`, or `-- --no-diarisation`).

Configuration knobs:

- `--tailscale-user` / `TAILSCALE_REMOTE_USER`: override the SSH user if it differs from your local login.
- `--tailscale-repo` / `TAILSCALE_REMOTE_REPO`: path to the toolkit on the remote host (default: `~/whisper-meeting-notes`).
- `--tailscale-workdir` / `TAILSCALE_REMOTE_WORKDIR`: directory to store per-run artefacts (default: `.remote-jobs` inside the repo).
- `--remote-http` / `REMOTE_HTTP_ENDPOINT`: HTTPS endpoint for laptops that are not on the tailnet (see Public Uploads below).
- `CUDNN_COMPAT_DIR` (optional): directory containing `libcudnn*_so.8` compatibility libraries; falls back to `~/.local/cudnn8/lib` and is added to `LD_LIBRARY_PATH` automatically.
- `TAILSCALE_BIN`: point at a non-standard Tailscale binary location.

The remote workflow requires `tailscale ssh` to be enabled on the workstation. Ensure the host has cloned this repo and can run `./scripts/meeting-notes.sh` locally before relying on the shortcut.

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
