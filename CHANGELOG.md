# Changelog

All notable changes to Taipea are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [0.3.0] - 2026-11-10

### Added
- **New app window built for accessibility.** The header and the History / Settings / Models tabs stay fixed while the content scrolls. Every button is at least 60 px tall, has a visible keyboard focus ring and a clear text label, and all colors meet WCAG AA contrast (4.5:1 for text) in every color set, including High contrast.
- **Settings in 8 groups.** Settings opens on a grid of large tiles (Dictation, Microphone & permissions, Size, text & colors, Floating button, Voice start / stop, Shortcuts, Custom words, Startup & updates). Each tile shows a one-line summary of its current values. A search box finds any setting by name or keyword, and **‹ All settings** goes back to the tiles.
- **History cards.** Each dictation is a card with the time, the style, the cleaned text and three large buttons: **Paste**, **Copy** and **More** (raw text, copy raw, convert to another style, delete). Long texts fold with Show all / Show less.
- **Safer delete.** Deleting a dictation asks first. The **Keep it** button appears exactly where Delete was, so a double click or a tremor keeps the dictation instead of removing it.
- **Models tab.** The model in use has an **In use** badge. Downloads show a progress bar with a percentage, and a failed download shows the error with a **Try download again** button.
- **Two layouts: Accessible and Standard.** Settings › Size, text & colors › Layout. **Accessible** (the default) is the full-height 760 px window with 60 px targets. **Standard** is a regular 640 × 680 Mac window with smaller text and buttons that fits a 13-inch MacBook. Text size (Large, Extra large) scales both layouts.
- **Resize the floating button by dragging its ring.** Press on the outer ring and drag out or in (64–220 px). A tag shows the size while you drag; a press that does not move is still a normal click. Settings › Floating button › Button size has Smaller / Larger, presets (S 72, M 96, L 128, XL 160, XXL 200) and Default size. The Stop buttons scale with it and never get smaller than 60 px.
- **Idle opacity for the floating button.** 40 %, 55 %, 70 %, 85 % or 100 % while it waits. While you record or it is working, it is always fully visible.
- **Icons-only Stop buttons.** Settings › Floating button › Text labels on the Stop buttons: Show text or Icons only. The spoken names (VoiceOver), colors and sizes stay the same.
- **New Taipea icon and mark.** A new app icon for Taipea.app and the Dock, and the "Serif T" mark on the floating button (a T whose stem is a microphone). It is drawn as an outline in the outline color sets (Studio, Paper and others).
- **Remove Whisper hallucinations (sound tags, repeated loops).** On by default (Settings › Dictation). After Whisper and before cleanup, Taipea strips made-up sound or event tags such as `[Music]`, `(applause)` and `[BLANK_AUDIO]`, and discards output that is only tags or a looping repeated phrase. Real words stay: bilingual EN/ES speech, brackets or parentheses you actually said, and normal short repeats like "the the". Turn it off if a dictation is trimmed too aggressively.

### Changed
- **The Dictate tab is gone.** Start dictation with the floating button, the shortcut, the Mic key or your voice. The window now has three tabs: History, Settings and Models.
- **"Compact" is now called "Standard"**, and its window is 640 × 680 instead of 520 × 700. Saved settings keep working: `compact` and `normal` are still the stored values.
- **The recording card keeps its size in Standard layout.** It used to shrink to 75 % in Compact; now only Text size changes it.
- The Interface language (Auto / English / Español) setting lives in Settings › Size, text & colors.

### Fixed
- Text and buttons that were below WCAG AA contrast in some color sets (muted text, warning text, disabled buttons) now pass in every color set.

## [0.2.12] - 2026-11-06

### Added
- **Preferred microphone in Settings.** Settings › Microphone lists every input (and
  System default, with the current default name on a second line). Taipea records through
  that device with sox (`-t coreaudio "<name>"`) for both dictation and voice start/stop,
  without changing the Mac's default input. The CoreAudio UID is saved in `settings.json`
  (`inputDevice`; empty = system default). If the saved device is unplugged, Taipea falls
  back to the system default and shows a warning until you plug it in again.
- **Always-visible Settings › Permissions card.** Two large buttons open Accessibility and
  Microphone settings even when no warning banner is showing.

### Fixed
- **Open Accessibility / Microphone settings opens the exact pane.** The buttons now use
  `x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility`
  (and `Privacy_Microphone`), launched with `/usr/bin/open`. `hs.urlevent.openURL` rejects
  Apple's settings links because they have no `://`, so the old buttons could silently do
  nothing. On macOS 12 and earlier, or if `open` fails, the previous
  `com.apple.preference.security?Privacy_*` URL is tried. On macOS 27 the Accessibility
  permission list is titled Device Control and Data Access (Control de dispositivos y
  acceso a datos); in-app path hints use that name.
- **Long option names no longer overlap** in a narrow or Compact window. Choice buttons
  wrap (`min-height: 60px`, height auto) instead of a fixed 60 px height.

## [0.2.11] - 2026-11-06

### Changed
- **Floating microphone uses a Liquid Glass look.** The 96 px circular button is a tinted,
  frosted version of the current theme background (about 55% opacity on dark themes, about
  70% on light themes such as Paper) so the desktop shows through. A glass edge (inset top
  highlight, soft inner bottom shadow) and a slightly softer drop shadow complete the look.
  The microphone icon and the accent ring stay solid. Recording (green Stop & Paste) and
  busy (grey spinner) fills are also translucent glass. Size, hit target (at least 60 px),
  drag, satellites and shortcuts are unchanged. This is the new default; there is no
  Settings toggle.
- **High Contrast stays solid.** Settings High Contrast or macOS Increase Contrast keep the
  existing solid high-contrast fills and thicker borders, with no blur.
- **macOS Reduce Transparency stays solid.** When Reduce Transparency is on (System Settings
  › Accessibility › Display), the floating button uses a solid fill and no blur, including
  solid recording green and busy grey.

## [0.2.10] - 2026-11-06

### Fixed
- **Reload no longer throws away a recording that can still be recovered.** On load, Taipea
  now offers recovery before it sweeps leftover live-session folders, so a Hammerspoon
  reload or crash does not delete the audio it needs.
- **A failed Whisper run keeps the audio.** If whisper-cli exits with an error, the
  recording is moved out of the session folder before that folder is deleted, then
  recovery is offered.
- **Cancel then start no longer pastes the old take.** Leftover cleanup, finish, Whisper
  and stop-timer callbacks ignore a job that was cancelled or replaced. Finish does not
  write History or paste in that case. Recover also isolates itself from leftover
  callbacks.
- **A killed live-slice Whisper run no longer blinds Cancel and the watchdog.** It only
  clears the task handle if it still owns it, so a newer full-file transcription can
  keep going.
- **A long cleanup is not treated as a stuck job.** In-flight Ollama cleanup counts as
  busy work for the 60-second watchdog. The 180-second hard ceiling is unchanged.
- **Voice start/stop flags no longer leak into the next dictation.** They are cleared
  after a watchdog reset, a Whisper failure, or an empty recording, not only after
  Cancel, nothing-heard, or a successful take.
- **A failed model download can be retried without reloading Hammerspoon.** The Models
  tab shows a Retry button (same large control, at least 60 px tall) instead of leaving
  the failure text in place of the button.

## [0.2.9] - 2026-11-06

### Added
- **Live transcription while you speak** (on by default). Taipea starts turning your
  voice into text while you are still talking, so Stop waits mainly on the last bit
  plus cleanup. Language stays Auto (English, Spanish, or both mixed). To use the
  previous full-file path only, set `liveTranscribe = false` in `config.lua`. There
  is no new Settings toggle.

### Fixed
- **Session temp folders are deleted.** The `tmp/s<number>/` folders used during live
  transcription are removed after paste, copy, nothing-heard, Cancel, an empty
  recording, a whisper failure, or a watchdog reset. Leftover folders from an earlier
  session are swept on load and when a new dictation starts. Only those `s*` folders
  are touched.

## [0.2.8] - 2026-11-04

### Fixed
- **No more "Thank you." added at the end.** If you stayed quiet for a few seconds before
  stopping, Whisper often filled the quiet with "Thank you." / "Gracias." / "Thanks for
  watching" and Taipea pasted it after your text. Now:
  - Before Whisper, the quiet start and end of the recording are cut off with sox (keeping
    0.3 s before and 0.5 s after your voice). The threshold comes from your room's own noise
    level, and mouth clicks do not count as voice. If anything fails, the whole recording is used.
  - After Whisper, a last segment that is only such a phrase is removed when it starts after
    your voice ended or there is no voice in its time window. A "thank you" you really say
    is kept. Every removal is written to the log.
- **Long dictations no longer lose words at the 30-second mark.** Whisper now runs with
  timestamps, so a sentence that crosses its 30 s window is no longer dropped or replaced with
  a stray word.

## [0.2.7] - 2026-11-04

### Fixed
- **Floating button's shadow no longer cut off at the edge.** The recording pulse and the Copy /
  Cancel buttons' shadows were also clipped at the window edge. Button size and saved position
  are unchanged.

## [0.2.6] - 2026-11-03

### Fixed
- **No more made-up text on silence.** Whisper sometimes "heard" Japanese, Cyrillic or phrases
  like "Thanks for watching" / "Subtítulos realizados por la comunidad de Amara.org" when you
  said nothing, and Taipea pasted it. Now:
  - Before Whisper, the recording is measured with sox. A silent one (loudest moment below
    -40 dB, or steady room noise: below -28 dB and less than 6 dB between loudest and quietest)
    is not transcribed.
  - Text with no letters is dropped.
  - With Dictation language set to **English** or **Español**, text that is mostly in another
    alphabet is retried once with the other language (es / en) and dropped if that is not
    usable. In **Auto** nothing is filtered by alphabet, so the ~99 languages keep working.
  - A known silence phrase is dropped only when it is the whole output and the audio was quiet
    or short.
  - You see "Nothing heard · nothing was pasted" ("No se escuchó nada · no se pegó nada") and
    nothing is pasted. The levels and the reason are written to the log.

### Changed
- Dictation language **Auto** is now labelled "Auto (any language; EN/ES mix)" / "Automático
  (cualquier idioma; mezcla ES/EN)". Option buttons grow taller (never below 60 px) when a
  label needs two lines.
- The recording hint is shorter: "Press Control + Command or Esc to finish", so it fits on one
  line; new recording-card screenshots.
- Docs: README "Other languages" section: speech recognition works in about 99 languages;
  the interface and cleanup are made for English and Spanish.


### Added
- New default start / stop shortcut: **Control + Command**. Press both keys together, or latch
  both on the Accessibility Keyboard. It acts on press (about 0.28 s after both keys are down),
  not on release, and works with Sticky Keys, the Accessibility Keyboard and Dwell clicks. If
  another key is pressed in that moment (Control + Command + Q, …) it does nothing, and holding
  the keys counts once. Each attempt that didn't count is written to the log with the reason.
- **Control + Option + Space** stays as a backup start / stop shortcut (`toggleKey2`).
- **Escape while recording = stop & paste.** Only Escape alone and only while recording;
  otherwise Escape is untouched. Setting `escStop`, On by default (Settings › Shortcuts).
- **Record your shortcuts.** Settings › Shortcuts has a big ⏺ Record shortcut button on every
  row: press the keys (with a key, or two or more modifiers alone), check them, Save. Taipea
  refuses, with the reason, single keys, Shift + key, a single modifier, macOS shortcuts
  (Command + Q, Command + Space, Control + Command + Q, …), duplicates and the Mic key. Typing
  (`ctrl+cmd`, `ctrl+alt+space`) still works under "Type it instead". Reset brings back all six.
- **Mic (Dictation) key 🎙 (F5)** can start / stop Taipea (`micKey`, **Off by default**). Turn
  off macOS Dictation's shortcut first (System Settings › Keyboard › Dictation › Shortcut: Off);
  the steps are in Settings and in docs/USAGE.md.
- Docs: new Shortcuts guide (recording, refusals, Accessibility Keyboard Panel Editor tip) and a
  "Use the Mic (Dictation) key" section, in English and Spanish, with new light-theme screenshots.

### Changed
- Hide / show the floating button is now **Option + Command acting on press** (it used to act
  when you let go) and can be changed like any other shortcut (`fabHideKey`).
- Shortcut names use full words: Control, Option, Command (Spanish: Control, Opción, Comando).
- The recording hint says "Press Control + Command or Esc, or a button, to finish".

### Upgrading
- Shortcuts you changed (in Settings or `config.lua`) are kept. If you had set start / stop to
  Control + Option + Space, it is bound once (the backup is skipped as a duplicate).

## [0.2.4] - 2026-11-03

### Added
- Update check. 30 seconds after start and then once a day, Taipea asks GitHub for the latest
  release (`updateRepo`, default `PatoSelekta/taipea`). This is the only network request besides
  the model downloads; no audio, text or settings are sent. On by default (`checkForUpdates`); turn
  it off in Settings › Updates or with `checkForUpdates = false` in `config.lua`.
- When a newer version exists: a "New version available" banner in the Taipea window with three
  large buttons (See what's new, Remind me later = 7 days, Skip this version), a menu bar item and
  one macOS notification per version. Nothing is downloaded or installed automatically, and only
  `https://github.com/<owner>/<repo>/releases/…` links are opened (anything else falls back to the
  repo's releases page).
- Settings › Updates / Actualizaciones: on/off, current version, last check and a Check now button.
  All texts follow Taipea's language setting (English / Spanish).
- README: a new Updates section (how it checks, privacy, and how to update by running the
  installer again, which keeps settings, history and models).

## [0.2.3] - 2026-11-03

### Changed
- Hide / show the floating button is now a tap of **Option + Command** (press both keys together
  and let go within about 1 second, with no other key, click, scroll or Control / Shift / Fn in
  between; left or right keys). It replaces Ctrl + Option + F. Cmd + Option + <key> shortcuts are
  not affected: the tap only watches keys and never blocks them. Settings › Shortcuts shows it as
  a fixed shortcut, and the alert and menu item say "Option + Command" / "Opción + Comando".
- The key watcher is restarted automatically if macOS turns it off. It needs Accessibility; without
  it, Settings shows a note and the menu item and Hide for now button still work.

### Removed
- The `fabHideKey` setting (Ctrl + Option + F).

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

[0.2.5]: https://github.com/PatoSelekta/taipea/releases/tag/v0.2.5
[0.2.4]: https://github.com/PatoSelekta/taipea/releases/tag/v0.2.4
[0.2.3]: https://github.com/PatoSelekta/taipea/releases/tag/v0.2.3
[0.2.2]: https://github.com/PatoSelekta/taipea/releases/tag/v0.2.2
[0.2.1]: https://github.com/PatoSelekta/taipea/releases/tag/v0.2.1
[0.2.0]: https://github.com/PatoSelekta/taipea/releases/tag/v0.2.0
