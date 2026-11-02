# Changelog

All notable changes to Taipea are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-11-02

First public release.

### Added
- Hands-free dictation into any app: Ctrl+Option+Space to start and stop, text is pasted
  at the cursor (or copied only).
- Local speech recognition with whisper.cpp (`ggml-large-v3-turbo` by default; smaller
  `large-v3-turbo-q5` and `small` options). Automatic English/Spanish detection, including
  mixed sentences.
- Optional local grammar cleanup with Ollama: `gemma4:e4b` by default, automatic fallback to
  `qwen2.5:7b` / `gemma4:e2b`, and raw text when Ollama is not available.
- Four styles: Light, Paragraph, Bullets, Formal. Mixed-language text is never translated.
- Long dictations up to 30 minutes, cleaned in ~250-word parts; any part that fails the
  safety checks keeps the original words.
- Recording overlay with three large buttons (Stop & Paste, Stop & Copy only, Cancel).
- Taipea window (Ctrl+Option+H or Taipea.app): History with search, copy, paste, delete and
  one-click re-style; Settings; Models with in-app downloads.
- Accessibility: large click targets, Normal/Compact size, head-mouse-friendly window
  dragging that stays on screen, optional auto-stop on silence, open at login.
- Bilingual interface (English / Español) for the window, recording panel, menu and alerts,
  with an Interface language setting: Auto (follows macOS), English or Español. Default: Auto.
- Default shortcuts defined and shown in Settings › Shortcuts, editable there, with
  "Reset shortcuts to defaults": Ctrl+Option+Space (start; press again to stop and paste),
  Ctrl+Option+C (cleanup on/off), Ctrl+Option+H (open the window).
- Recording panel on/off setting (`showOverlay`, default on).
- Documented defaults: table in both READMEs, and every default listed in
  `config.example.lua`.
- Vision section in both READMEs.
- `install.sh` (idempotent; Homebrew, Hammerspoon, whisper.cpp, SoX, Ollama, models,
  Taipea.app) and `uninstall.sh`.
- English and Spanish README.

[0.1.0]: https://github.com/PatoSelekta/taipea/releases/tag/v0.1.0
