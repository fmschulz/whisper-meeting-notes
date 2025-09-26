# Meeting Notes Kit

Fast tooling for moderators who need high-quality transcripts and diarised notes during panel discussions or workshops. The kit wraps [WhisperX](https://github.com/m-bain/whisperX) with a `uv` managed Python environment and exports Markdown tables with per-speaker attribution.

## Features

- Uses the **`large-v3`** Whisper model with beam search and temperature fallback for top accuracy.
- Optional **speaker diarisation** via `pyannote.audio` when you provide a `HF_TOKEN` (multiple speakers are tagged automatically).
- Generates Markdown with a timestamped table for easy paste into docs or wikis.
- Works on laptops or remote GPU workstations; the shell helper calls `uv run` so dependencies stay inside a project-local virtual environment.

## Repository Setup

```bash
# clone the toolkit
git clone https://github.com/fmschulz/whisper-meeting-notes.git
cd whisper-meeting-notes

# install dependencies into a managed environment (Python 3.12 is required)
uv python install 3.12
uv sync --python 3.12

# the first run of the wrapper will install PyTorch with the right variant automatically
```

That creates `.venv/` (tracked via `uv.lock`) with all Python dependencies except PyTorch (handled by the shell wrapper).

## Installation Notes

### Torch build selection

The Python dependencies managed by `uv sync` no longer include PyTorch—the shell wrapper will install the appropriate wheel on first run. By default it selects the **CPU-only** build so laptops avoid the huge CUDA downloads. If you need a GPU build, export `UV_TORCH_VARIANT` before running the script.

Available variants:

- `auto` (default) → picks `cu124` when `nvidia-smi` is available, otherwise `cpu`
- `cpu` → CPU-only wheel from `https://download.pytorch.org/whl/cpu`
- `cu124` → CUDA 12.4 wheels from `https://download.pytorch.org/whl/cu124`
- `none` → skip automatic torch management (useful if you manage the wheel yourself)

Example GPU override:

```bash
export UV_TORCH_VARIANT=cu124
./scripts/meeting-notes.sh recordings/all-hands.wav
```

Force CPU-only (useful on machines without NVIDIA GPUs):

```bash
UV_TORCH_VARIANT=cpu ./scripts/meeting-notes.sh recordings/all-hands.wav
```

### HuggingFace token

Export your token before running the script if you want diarisation:

```bash
export HF_TOKEN="hf_..."
```

Pyannote’s diarisation pipeline is gated—after creating the token visit
https://huggingface.co/pyannote/speaker-diarization-3.1 and accept the terms, otherwise the script will fall back to single-speaker output.

## Capturing Audio

The toolkit expects you to provide a recorded audio file. Common ways moderators gather the raw audio:

- **Use the meeting platform’s recording feature.** Zoom, Meet, and Teams all export `.mp4`/`.m4a` files you can feed directly into the script.
- **Use the bundled recorder.** Run `./scripts/record-audio.sh` to start an `ffmpeg` capture with sane defaults. Add `--list` to see available inputs (PulseAudio/PipeWire sources on Linux, AVFoundation devices on macOS). Press `Ctrl+C` to stop recording; files land in `recordings/`.
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

Options:
- The first positional argument is the audio file.
- An optional second argument specifies the Markdown output (`.md`).
- If omitted, the script writes `<audio-stem>-notes-<timestamp>.md` alongside the source file (for example, `recordings/all-hands-notes-20240924-1730.md`).

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
    A[Capture audio
    • record-audio.sh
    • Zoom export
    • Hardware recorder] --> B[Run meeting-notes.sh
    (Laptop, CPU default)]
    B --> C[Markdown transcript
    with diarisation]
    A --> D[Optional: Upload audio
    to GPU workstation]
    D --> E[Run meeting-notes.sh
    on GPU (set UV_TORCH_VARIANT=cu124)]
    E --> C
```

## Remote GPU Workflow

1. Copy the recording to the GPU host:
   ```bash
   rsync -avP meeting.m4a gpu-host:~/meetings/
   ```
2. SSH into the GPU host, clone the repo if needed, and run the same script:
   ```bash
   ssh gpu-host
   cd ~/whisper-meeting-notes
   export UV_TORCH_VARIANT=cu124
   uv sync --python 3.12 --frozen
   ./scripts/meeting-notes.sh ~/meetings/meeting.m4a ~/meetings/meeting-notes.md
   ```
3. Pull the resulting Markdown back via `rsync` or share it with your note-taking tools.

The script automatically detects CUDA (`torch.cuda.is_available()`) and will use mixed-precision decoding when available.

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
