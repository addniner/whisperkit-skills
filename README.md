# whisperkit-skills

Claude Code skills for local transcription workflows on Apple Silicon.

<p>
  <img alt="Fine Tension" src="https://img.shields.io/badge/Fine-Tension-111111?style=flat-square&labelColor=111111&color=8CF8D2" />
  <img alt="WhisperKit" src="https://img.shields.io/badge/WhisperKit-local-111111?style=flat-square&labelColor=111111&color=FAFAFA" />
  <img alt="Platform" src="https://img.shields.io/badge/platform-Apple%20Silicon-111111?style=flat-square&labelColor=111111&color=A1A1AA" />
</p>

This repository contains three skills:

- `whisperkit`: normalizes audio/video inputs, then transcribes them with WhisperKit CLI and speaker diarization.
- `meeting-summary`: turns an existing transcript into structured meeting notes, decisions, and action items.
- `setup`: checks and prepares the local macOS environment.

The skills are Korean-first. Transcription and meeting summarization are separate, composable steps: use `whisperkit` alone for transcripts or subtitles, `meeting-summary` alone for existing transcripts, or run both for a complete meeting-notes workflow.

## Requirements

- macOS 14+
- Apple Silicon
- `whisperkit-cli`
- `ffmpeg` / `ffprobe`

Homebrew is the recommended installer for the command-line dependencies, but it is not a runtime requirement when those commands are already available:

```bash
brew install whisperkit-cli
brew install ffmpeg
```

All environment decisions go through the read-only `setup/scripts/check-env.sh` preflight. Skills consume its JSON result instead of repeating platform and dependency checks independently.

## Layout

```txt
whisperkit/
  SKILL.md
  scripts/prepare-media.sh
  scripts/parse-speakers.sh

meeting-summary/
  SKILL.md

setup/
  SKILL.md
  scripts/check-env.sh
```

## Notes

WhisperKit runs on-device through Apple Silicon/Core ML. FFmpeg converts the selected audio stream (the first by default) to mono 16 kHz PCM WAV while preserving the original media. Speaker diarization output is captured from CLI stdout, so the workflow preserves raw command output before generating the final transcript.

On first use, the workflow asks whether to keep recording folders flat in the current directory or group them under a `recordings/` root. Existing layouts are detected and reused automatically. The grouped layout is recommended:

```txt
recordings/
  inbox/
  rec_YYYY-MM-DD_NNN/
    audio.<original-extension>
    transcript.txt
    summary.md                 # only after meeting-summary runs
    data/
      audio.wav                # normalized STT input
      raw.txt
      audio.json
      audio.srt
```

Choosing the flat layout produces the same `inbox/` and `rec_*` entries directly in the current directory.

Maintained by [Fine Tension](https://github.com/finetension).
