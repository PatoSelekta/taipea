# Changelog

All notable changes to Taipea are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [0.2.2] - 2026-11-03

### Added
- App-wide color themes (Settings › Colors / Colores): Classic Blue, Studio, Midnight, Forest,
  Sunset, High Contrast, Paper and Custom (background, microphone/text and accent pickers, or a
  #RRGGBB code). They theme the window, the recording card and the floating button. Any text
  below 4.5:1 contrast is adjusted automatically (Custom included). Action colors stay fixed in
  every set: green = stop and paste, blue = stop and copy only (also History › Copy), red =
  cancel; warnings stay orange / red. High contrast keeps the black/white/yellow look on Classic
  Blue and adds thick borders on the other sets.
- Hide the floating button: Ctrl + Option + F (and a menu item) hides / shows it until pressed
  again; "Hide when an app is full screen" (on by default, also detects borderless full-screen
  windows); "Hide in these apps" with quick-add (TV, VLC, QuickTime Player, IINA) or a list of
  open apps. It never hides while recording or processing. New settings: `fabHideKey`,
  `hideFullscreen`, `hideApps`.
- Permission checks: Taipea checks Accessibility at startup, before every paste and when the
  window opens, shows a red banner and menu item with an **Open Accessibility settings** button,
  and says when it is back on. An empty or no-speech recording shows a Microphone permission
  hint with an **Open Microphone settings** button. All messages in English and Spanish.

### Changed
- Classic Blue accent is darker (#0A6CD6) so white text on it reaches 5.09:1; the focus ring
  stays #0A84FF.

### Fixed
- When pasting is blocked (no Accessibility), the dictation stays on the clipboard instead of
  the previous clipboard being restored over it.

## [0.2.1] - 2026-11-02

### Fixed
- Dictation could get stuck on "processing" after stopping (a one-shot timer was garbage-collected).
- Added a processing watchdog that restarts or resets to idle with an alert and keeps the audio for Recover last recording.
- An empty recording now returns to idle with a microphone alert.

## [0.2.0] - 2026-11-02

First public release (includes everything listed under 0.1.0 below, which was never published).

### Added
- Voice start / stop (off by default): say "Taipea escribe" / "Taipea write" to start and
  "listo" / "done" / "Taipea listo" to stop and paste; the phrase is removed from the text.
  Phrases are editable in Settings. A low-CPU SoX listener keeps short bursts (up to 4 s),
  only those are transcribed by Whisper on the Mac and then deleted; it accepts common
  mishearings of "Taipea", pauses while the screen is locked, and shows 👂 in the menu bar.
- Floating mic button (on by default): round, 96 px, always on top, draggable with the
  position remembered; click to start; while recording it turns green (click = stop and paste)
  with two satellite buttons (blue = stop and copy only, red = cancel), 64 px and semi-transparent
  at rest, growing to 84 px with a label on hover, placed on whichever side has room. They
  appear for any start (button, shortcut or voice). Settings › Recording controls has the
  On/Off toggle and "Show the recording card too" (off by default: the card is hidden while
  the floating button is on). The card's buttons use the same colours and icons (green paste,
  blue copy, red ×). Different looks for idle (mic), listening, recording and working (spinner).
- Custom words (Settings › Custom words): "heard → replace with" rows with large Add and
  Delete buttons; whole-word, case- and accent-insensitive; applied after Whisper and again
  after cleanup; the words are passed to Whisper as `--prompt` hints and the cleanup model
  is told never to change them. Stored in settings.json.
- Text size (Normal / Large / Extra large) and High contrast (Auto / On / Off) for the
  window, recording panel and floating button; follows macOS Increase Contrast and Reduce
  Motion.
- Recovery: the audio and progress of each dictation are kept until it is pasted; after a
  crash or reload Taipea offers "Recover last recording" (menu, alert and History banner),
  fixing the WAV header of a recording that was cut off.
- Paste last dictation again: Ctrl+Option+V, a menu item and a button at the top of History.

### Changed
- Auto-stop on silence is now a large On/Off with a 2 / 3 / 5 / 8 second choice, near the
  top of Settings. It is still off by default; the default pause is now 3 s (was 2.5 s).
- Text you are typing in Settings is kept when the window refreshes.

## [0.1.0] - 2026-11-02

Internal baseline (not published as a GitHub release).

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
- Installer options `--skip-brew` and `--no-start` (also `TAIPEA_SKIP_BREW=1`, `TAIPEA_NO_START=1`).
- English and Spanish README.

### Fixed (found while testing on a real Mac)
- A speech model that is a symlink was downloaded again; the installer now follows symlinks.
- The installer no longer starts or restarts Ollama when it is already running.
- `build-app.sh` no longer prints osacompile's "replacing existing signature" note.

[0.2.2]: https://github.com/PatoSelekta/taipea/releases/tag/v0.2.2
[0.2.1]: https://github.com/PatoSelekta/taipea/releases/tag/v0.2.1
[0.2.0]: https://github.com/PatoSelekta/taipea/releases/tag/v0.2.0
