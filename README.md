# whisperkit-skills

Claude Code skills for local transcription workflows on Apple Silicon.

<p>
  <img alt="Fine Tension" src="https://img.shields.io/badge/Fine-Tension-111111?style=flat-square&labelColor=111111&color=8CF8D2" />
  <img alt="WhisperKit" src="https://img.shields.io/badge/WhisperKit-local-111111?style=flat-square&labelColor=111111&color=FAFAFA" />
  <img alt="Platform" src="https://img.shields.io/badge/platform-Apple%20Silicon-111111?style=flat-square&labelColor=111111&color=A1A1AA" />
</p>

This repository contains two skills:

- `whisperkit`: transcribes audio/video files with WhisperKit CLI and speaker diarization.
- `setup`: checks and prepares the local macOS environment.

The skills are Korean-first and designed for meeting notes, interviews, podcasts, subtitles, and local inbox-based transcription flows.

## Requirements

- macOS 13+
- Apple Silicon
- Homebrew
- `whisperkit-cli`
- `ffmpeg` / `ffprobe`

## Layout

```txt
whisperkit/
  SKILL.md
  scripts/parse-speakers.sh

setup/
  SKILL.md
  scripts/check-env.sh
```

## Notes

WhisperKit runs on-device through Apple Silicon/Core ML. Speaker diarization output is captured from CLI stdout, so the workflow preserves raw command output before generating the final transcript.

Maintained by [Fine Tension](https://github.com/finetension).
