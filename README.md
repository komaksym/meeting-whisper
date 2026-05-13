# meeting-whisper

Personal local meeting transcription CLI for macOS.

It records or imports English meeting audio, transcribes with WhisperKit, diarizes speakers with SpeakerKit, asks a local Ollama model for structured notes, and writes Markdown directly into an Obsidian vault.

## Requirements

- Apple Silicon Mac
- macOS 15+ for recording both system audio and microphone with ScreenCaptureKit
- Xcode 16+ or a Swift toolchain that can build Swift packages
- Ollama with a local notes model, for example:

```bash
brew install ollama
ollama pull llama3.2:3b
```

WhisperKit and SpeakerKit models download on first use.

## Setup

```bash
swift run meeting-whisper setup \
  --vault "/Users/koval/path/to/ObsidianVault" \
  --folder "Meetings"
```

This writes config to:

```text
~/.config/meeting-whisper/config.json
```

Defaults:

- Speech-to-text: `large-v3-v20240930_626MB`
- Language: English (`en`)
- Speaker diarization: SpeakerKit / Pyannote Core ML
- Notes: `llama3.2:3b`
- Retention: transcript only

## Usage

Record a meeting:

```bash
swift run meeting-whisper record --title "Weekly Coaching"
```

Press Return to stop recording. The tool then processes audio and writes an Obsidian note.

For a deterministic test run that does not rely on pressing Return:

```bash
swift run meeting-whisper record --title "Test Meeting" --duration-seconds 10
```

Import an existing file:

```bash
swift run meeting-whisper import ./meeting.m4a --title "Weekly Coaching"
```

By default, import mode does not delete the source file. Add `--delete-source-audio` if you want transcript-only retention for imported files too.

Check setup:

```bash
swift run meeting-whisper doctor
```

## Speaker Labels

Recorded meetings use separate tracks:

- microphone track -> `Me`
- system audio track -> `Other`
- extra diarized voices -> `Other 2`, `Other 3`, etc.

Imported files cannot know who is you, so labels are `Speaker 1`, `Speaker 2`, etc.

## Privacy

The intended path is local-only:

- audio capture happens on-device
- WhisperKit and SpeakerKit run on-device
- notes are generated through local Ollama
- notes are plain Markdown files in your Obsidian vault

Recording consent is your responsibility.
