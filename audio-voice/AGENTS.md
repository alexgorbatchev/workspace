---
created_on: 2026-10-18 13:40
last_modified: 2026-10-18 13:40
status: current
---

# Audio & Voice

Audio capture, speech-to-text processing, transcription caching, and dictation utilities.

Inherits all standing workspace boundaries, code coverage requirements (90%), and Git conventions from the [parent monorepo AGENTS.md](../AGENTS.md).

## Local commands
- Status overview: `just status`
- Run checks across audio/voice tools: `just check`
- Run tests across audio/voice tools: `just test`

## Member repositories
- `ambient-recorder-cli`: Continuous macOS microphone and system audio capture to local Opus files
- `deepgram-transcribe-cli`: Audio transcription CLI with Deepgram API, SHA-256 caching, and speaker diarization
- `omi`: Personal Omi wearable AI snapshot with atomic upstream sync
- `simple-ptt`: macOS menu bar push-to-talk dictation application in Rust powered by Deepgram
