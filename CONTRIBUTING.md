# Contributing to Taipea

Thank you for helping! Taipea exists so that people who can't type easily can still write
quickly, in English, Spanish, or both. Every contribution should keep it **private**,
**local**, and **usable without a keyboard**. Issues and pull requests in Spanish are
welcome too.

## Ways to help

- **Report an accessibility problem.** This is the most valuable help. Use the
  "Accessibility issue" template and tell us which assistive technology you use (head mouse,
  eye tracker, switch, Voice Control, VoiceOver…). You don't need to code.
- **Report a bug** with the "Bug report" template.
- **Suggest a feature** with the "Feature request" template.
- **Improve the prompts** for the styles, especially for mixed English/Spanish, or add
  support for another language pair.
- **Translate** the README or the interface. Interface text lives in two tables: `STR` in
  `src/taipea.lua` (menu, panel, alerts) and `L` in `src/ui/app.html` (window). Add every new
  string in both English and Spanish; the tests fail if a key is missing.

## Project layout

| Path | What it is |
|---|---|
| `src/taipea.lua` | The Hammerspoon module: recording, transcription, cleanup, overlay, history, menu. |
| `src/ui/app.html` | The Taipea window (History, Settings, Models). Plain HTML + JS, no build step. |
| `src/config.example.lua` | Every user setting, with comments. |
| `install.sh`, `uninstall.sh` | Installer and uninstaller. Must stay idempotent. |
| `scripts/build-app.sh` | Builds the small `Taipea.app` launcher. |
| `tests/run.lua` | Offline tests for the text logic (runs anywhere with Lua 5.4). |
| `tests/ui_strings.js` | Checks that the window's English and Spanish strings match (Node.js). |

## Developing

1. Install Taipea normally with `bash install.sh`.
2. Edit `src/taipea.lua`, then copy it over the installed one and reload Hammerspoon:
   ```bash
   cp src/taipea.lua ~/.hammerspoon/taipea.lua
   cp src/ui/app.html ~/Library/Application\ Support/Taipea/ui/app.html
   ```
   Then choose Hammerspoon › Reload Config.
3. Watch the log: `tail -f ~/Library/Application\ Support/Taipea/logs/taipea.log`.

## Before opening a pull request

```bash
luac -p src/taipea.lua src/config.example.lua   # Lua syntax
lua tests/run.lua                                # logic tests
node tests/ui_strings.js                         # window strings in both languages
shellcheck install.sh uninstall.sh scripts/build-app.sh
```

Please also:

- keep every click target big (at least 60 px tall in the window, 110 px in the overlay),
- make every action possible with a single click, with no hold-and-drag or double-click
  needed,
- never add network calls other than model downloads the user starts,
- never log or upload anything outside the user's Mac,
- describe how you tested it (Mac model, macOS version, models used).

## Privacy in bug reports

Logs and history contain what you dictated. Remove anything private before attaching them.

## Code of conduct

Be kind and patient. Many people here use assistive technology, and writing a report can
take them a long time. Respect that effort.
