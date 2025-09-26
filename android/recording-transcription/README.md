# RecordingTranscription Android App

Minimal Android app that captures audio clips and optionally generates speech-to-text notes alongside each recording. Recordings and transcripts are stored together in the app-specific `files/recordings` directory.

## Project layout

- `app/src/main/java/com/example/recordingtranscription/` – Kotlin sources (Compose UI, recorder controller, view model).
- `app/src/main/res/` – Manifest, string resources, and Material theme configuration.
- `build.gradle.kts`, `settings.gradle.kts`, `gradle.properties` – Gradle build setup targeting Android SDK 34 with Jetpack Compose.

## Building

1. Open the `android/recording-transcription` directory in Android Studio Hedgehog (or newer).
2. Let Gradle sync; no additional plugins are required.
3. Use **Run > Run 'app'** to install on a device/emulator with speech recognition enabled.

## Using the app

1. Grant the microphone permission when prompted.
2. Toggle the transcription switch on if you want live captions (requires Google or on-device recognition service).
3. Tap **Start Recording** to begin. Audio is saved as `rec-<timestamp>.m4a` inside `files/recordings`.
4. Tap **Stop Recording** to finish. When transcription is enabled, a `<same-name>-transcript.txt` file is stored next to the audio.
5. The history section lists previous sessions with file paths and transcript previews for quick reference.

## Notes

- Speech recognition may pause automatically after a few seconds of silence; the app restarts listening while the recording is active.
- If transcription fails (for example, no speech detected), recording continues and the error appears as a toast.
- Recordings are private to the app. Use Android Studio's Device File Explorer or in-app sharing (future enhancement) to export files if needed.
