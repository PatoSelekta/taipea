# Taipea

**It types for you.** Talk, and Taipea writes your words into any app on your Mac.
Hands-free, private, and made for English, Spanish, and a mix of both.

[Leer en español](README.es.md) · Made by [selektdev](https://selektdev.com)

---

## Vision

Taipea is designed first for the **accessibility community**. It was built by a
quadriplegic developer who controls his Mac with a head mouse and a mouth click, and every
choice comes from that daily use:

- **Big, clear targets.** Buttons are 60–110 px tall, with plenty of space between them, so
  a head mouse, eye tracker or switch can hit them without precision.
- **Hands-free.** One shortcut or one click starts and stops dictation. Nothing needs a
  double-click, a held key, or a precise drag.
- **Local and private.** Your voice and text never leave your Mac. No account, no cloud.
- **Bilingual.** English, Spanish, and the mix many of us actually speak.

That same large, calm design makes Taipea comfortable for **anyone** who wants fast,
private dictation: writers, developers, people with tired hands, or anyone who would rather
talk than type.

Taipea is also the first in a series of practical apps by Patricio Escobar, who is building
his developer career at **[selektdev.com](https://selektdev.com)**. If Taipea helps you,
a star, a bug report or a hello there means a lot.

## What is Taipea?

Taipea is a free dictation tool for macOS. You press one shortcut (or click one big
button), speak, and the text appears where your cursor is: email, chat, documents, code
editors, web forms.

It was built by a quadriplegic developer who works with a head mouse. Typing is slow
and tiring for him, and most dictation tools break when he switches between English
and Spanish in the same sentence. Taipea is the tool he uses every day.

Taipea is for you if:

- you can't type, or typing hurts (motor disability, RSI, injury, fatigue),
- you use a head mouse, eye tracker, switch, or voice control,
- you speak English and Spanish, sometimes in the same sentence,
- you want dictation that never sends your voice to the internet.

## Features

- **Works in any app.** Text is pasted at your cursor. You can also choose "copy only".
- **English, Spanish, or both mixed.** "Necesito the report antes del viernes" stays
  exactly like that. Nothing is translated.
- **Grammar cleanup (optional).** A local AI model fixes punctuation, capitals and
  spelling, and removes "um" and "eh".
- **Four styles:** Light (fix only), Paragraph, Bullets, Formal (polite, professional, uses
  "usted" in Spanish).
- **History with re-style buttons.** Every dictation is saved. Turn an old one into
  bullets or a formal email with one click. The original words are always kept.
- **Long dictations.** Up to 30 minutes. Long text is cleaned in parts, and if a part
  can't be cleaned safely, Taipea keeps your original words for that part.
- **Built for head mice and switches.** Large buttons (110 px tall on the recording
  overlay) and no tiny targets. Windows move by dragging their title bar, and this also
  works with head mice that don't send normal drag events.
- **English or Spanish interface** (follows your Mac, or pick one in Settings).
- **Normal or Compact size**, overlay you can place anywhere, opens at login.
- **Optional auto-stop** after 2, 3, 5 or 8 seconds of silence (a big On/Off in Settings).
- **Voice start / stop (optional, off by default).** Say "Taipea escribe" or "Taipea write"
  to start, and "listo", "done" or "Taipea listo" to stop and paste. The phrases are
  editable. See [Voice start / stop](#voice-start--stop) for how it works and its limits.
- **Floating mic button (on by default).** A round 96 px button that stays on top: click to
  start. While you dictate it turns green—click it to stop and paste into the app you were
  using. Two smaller buttons appear beside it (blue = stop and copy only, red = cancel). Drag
  it anywhere; it remembers where you left it. You can also show the full recording card in
  Settings. It looks different when idle, recording and working.
- **Hide the floating button when you don't need it.** Tap Option + Command (or use the
  menu) to hide it until you press it again; hide it by itself while an app is full screen
  (on by default) or while chosen apps are in front (for example VLC or TV). It never hides
  while you are recording or Taipea is working, so Stop is always reachable.
- **Color themes for the whole app.** Settings › Colors has 8 sets: Classic Blue, Studio,
  Midnight, Forest, Sunset, High Contrast, Paper and Custom (pick 3 colors). They color the
  window, the recording card and the floating button. Text that would be hard to read is
  fixed automatically (at least 4.5:1 contrast), and the action colors never change: green =
  stop and paste, blue = stop and copy only, red = cancel.
- **Custom words.** Tell Taipea that "select dev" should be written "selektdev". Matching
  ignores capitals and accents and only replaces whole words. The words are also given to
  Whisper as hints and the cleanup model is told never to change them.
- **Larger text and high contrast.** Text size Normal / Large / Extra large, and a High
  contrast theme for the window, recording panel and floating button. It follows macOS
  Increase Contrast (Auto) and Reduce Motion.
- **Recovery.** Each recording is kept until its text is pasted. If Hammerspoon crashes or
  reloads in the middle, Taipea offers **Recover last recording** and transcribes it.
- **Paste last dictation again** with Ctrl + Option + V, the menu, or a button in History.
- **Permission checks.** If Accessibility is off, Taipea tells you, keeps your text on the
  clipboard (paste it with Cmd + V) and shows a big **Open Accessibility settings** button. If
  a recording comes back empty, it points you to the Microphone permission.

## Privacy: 100% local

- Your voice is recorded to a temporary file on your Mac and transcribed by
  [whisper.cpp](https://github.com/ggml-org/whisper.cpp) on your Mac.
- Grammar cleanup runs in [Ollama](https://ollama.com) on your Mac.
- No account, no cloud, no analytics, no telemetry. After the installer downloads the
  models, Taipea works with Wi-Fi off.
- Your history is a file on your Mac:
  `~/Library/Application Support/Taipea/history.json`. Delete it any time, or use
  "Clear all" in the History tab.
- The audio of the dictation in progress stays in `…/Taipea/tmp/` until it is pasted, so
  it can be recovered after a crash. Recovered or discarded audio is deleted.
- Voice start / stop (off by default) also runs only on your Mac. See below.
- The only network request besides the model downloads is the update check: once a day
  Taipea asks GitHub for the latest release version. No audio, text or settings are sent.
  Turn it off in Settings › Updates. See [Updates](#updates).

## Requirements

| | Minimum | Recommended |
|---|---|---|
| macOS | 13 Ventura | 14 Sonoma or newer |
| Chip | Intel (slow) | Apple Silicon (M1 or newer) |
| Memory | 8 GB (use the small models or no cleanup) | 16 GB or more |
| Free disk | about 3 GB (no cleanup) | about 13 GB (speech model 1.6 GB + Gemma 4 E4B 7–10 GB + tools) |

Taipea uses these free tools, and the installer sets them up for you:
[Homebrew](https://brew.sh), [Hammerspoon](https://www.hammerspoon.org),
whisper.cpp, [SoX](https://sourceforge.net/projects/sox/) and Ollama.

## Install

Open the **Terminal** app, paste this line, and press Return:

```bash
curl -fsSL https://raw.githubusercontent.com/PatoSelekta/taipea/main/install.sh | bash
```

The one-line installer installs from `main`. To install exactly v0.2.4, download the release source zip, unzip it, and run `./install.sh` from that folder.

The installer explains each step, asks before anything big, and can be run again
safely (it skips what is already done). It:

1. checks your Mac (macOS version, chip, memory, disk space),
2. installs Homebrew if you don't have it (it asks first),
3. installs Hammerspoon, whisper.cpp, SoX and Ollama with Homebrew,
4. downloads the speech model `ggml-large-v3-turbo` (1.6 GB) from Hugging Face,
5. downloads the cleanup model `gemma4:e4b` from Ollama (falls back to `qwen2.5:7b`),
6. adds one line to `~/.hammerspoon/init.lua` (it makes a backup first and keeps
   everything else),
7. creates `~/Applications/Taipea.app` and starts Taipea.

**Options.** Add them after `bash -s --`, for example
`curl -fsSL .../install.sh | bash -s -- --small`:

| Option | What it does |
|---|---|
| `--small` | Smaller speech model (0.57 GB). Good for 8 GB Macs. |
| `--whisper=small` | Smallest speech model (0.49 GB). Less accurate with mixed languages. |
| `--llm=qwen2.5:7b` | Use a different cleanup model. |
| `--no-cleanup` | Don't install Ollama. Taipea pastes the raw transcription. |
| `--yes` | Don't ask any questions; use the defaults. |
| `--skip-brew` | Don't install or start anything with Homebrew (the tools must already be there). |
| `--no-start` | Don't restart Hammerspoon, start Ollama or open System Settings. |

Prefer to look first? Download the code, read `install.sh`, then run `bash install.sh`.

### Uninstall

```bash
bash uninstall.sh            # asks before deleting your history and models
bash uninstall.sh --purge    # deletes everything Taipea created
```

The shared tools (Homebrew, Hammerspoon, Ollama…) are kept, and the script shows the
commands to remove them too.

## Updates

**How it checks.** 30 seconds after Hammerspoon starts and then once a day, Taipea asks
GitHub for the latest release (`api.github.com/repos/PatoSelekta/taipea/releases/latest`).
When there is a newer version, you see:

- a **New version available** banner at the top of the Taipea window, with three big
  buttons: **See what's new** (opens the release page on GitHub), **Remind me later**
  (7 days) and **Skip this version**,
- a menu bar item and one macOS notification per new version.

Nothing is downloaded or installed by itself, and links only open on `github.com`.
**Settings › Updates** shows your version and the last check, and has a **Check now** button.

**Privacy.** This is Taipea's only network request besides the model downloads. It sends no
audio, text, history or settings, only a `Taipea/<version>` user agent (GitHub sees your IP
address, like any website). To turn it off, choose **Off** in Settings › Updates, or add
`checkForUpdates = false,` to `config.lua`. **Check now** still works when it is off.

**How to update.** Run the same installer line again:

```bash
curl -fsSL https://raw.githubusercontent.com/PatoSelekta/taipea/main/install.sh | bash
```

It replaces the program files (`~/.hammerspoon/taipea.lua`, the window and
`~/Applications/Taipea.app`), restarts Hammerspoon, and keeps your settings
(`settings.json`, `config.lua`), your history and your downloaded models. Nothing is
downloaded again if it is already there.

## Permissions (one time)

macOS protects your microphone and keyboard. You have to allow these once. Taipea runs
inside Hammerspoon, so the permission is for **Hammerspoon**:

1. **Accessibility:** System Settings › Privacy & Security › Accessibility › turn on
   **Hammerspoon**. Needed to paste the text where your cursor is (Taipea presses Cmd+V
   for you). The shortcuts themselves work without it.
2. **Microphone:** the first time you dictate, macOS asks. Click **Allow**. To check
   later: System Settings › Privacy & Security › Microphone › **Hammerspoon**.
   Hammerspoon only appears in that list after your first dictation.

If a switch is already on but nothing gets pasted, turn it off and on again, then restart
Hammerspoon.

**Signs that a permission is missing**

- **Nothing is pasted:** Accessibility is off. Taipea shows a red banner with an **Open
  Accessibility settings** button, and your text stays on the clipboard (Cmd + V) and in History.
- **The recording is empty, or you get "No speech detected" every time:** the Microphone
  permission is off (macOS then records only silence), or the wrong microphone is chosen
  in System Settings › Sound › Input.

**Other messages you may see (normal)**

- **"Terminal wants access to control Hammerspoon":** this can appear when you run the
  installer again while Hammerspoon is open, because the installer restarts it. Click
  **OK**. If you clicked Don't Allow, quit Hammerspoon from its menu bar icon and open it
  again.
- **"Background Items Added" / login item notice:** Taipea opens at login through
  Hammerspoon, so macOS may tell you Hammerspoon was added to your login items. Nothing to
  do. You can turn it off in Taipea's Settings (Open at login) or in System Settings ›
  General › Login Items.

## Why Hammerspoon?

Taipea runs inside [Hammerspoon](https://www.hammerspoon.org), a free tool for
automating your Mac, instead of being a separate native app. We chose it on purpose:

- **It keeps Taipea free.** Hammerspoon is free and open source, and Taipea doesn't need
  a paid Apple developer account to be signed and shared.
- **Nothing is hidden.** Taipea is plain Lua and HTML you can read, check and change.
  There is no closed binary, and you can see for yourself that everything stays on your Mac.
- **Fixes arrive fast.** Most improvements are a change to one file and a reload. No app
  rebuild, no waiting for an app store.
- **It's proven.** Hammerspoon is mature and widely used, and it already does what
  dictation needs: global shortcuts, floating windows, and pasting into any app.

The honest trade-offs: you install Hammerspoon too (the installer does it for you), and
macOS permissions and prompts say **Hammerspoon**, not Taipea. A native Taipea app may
come later, once the features settle.

## How to use it

These are the default shortcuts. They work as soon as Taipea is installed, even with no
config file.

| Shortcut | What it does |
|---|---|
| **Ctrl + Option + Space** | Start dictating. Press the same shortcut again to stop: Taipea transcribes, cleans up and pastes at your cursor. |
| **Ctrl + Option + C** | Turn cleanup on or off (raw text). |
| **Ctrl + Option + H** | Open the Taipea window: History, Settings, Models. |
| **Ctrl + Option + V** | Paste the last dictation again. |
| **Option + Command** (tap: press both, let go) | Hide or show the floating button (until you tap it again). Cmd + Option + other key shortcuts are not affected. |

No keyboard? Everything also works with clicks:

- The round **floating mic button** starts dictation. While you talk it turns green: click it
  to stop and paste. Two smaller buttons appear next to it: blue **Stop & Copy only** and red
  **Cancel** (they grow and show a label when the pointer is over them).
- With the floating button off (or "Show the recording card too" on), a floating card shows
  three big buttons in the same colours: **Stop & Paste**, **Stop & Copy only**, and **Cancel**.
- Open **Taipea.app** (in `~/Applications`, add it to your Dock) to open the window.
  It has a big **🎙 Dictate** button.
- The 🎙 icon in the menu bar has the same actions.

You can see and change the shortcuts in Settings › Shortcuts (type one like
`ctrl+alt+space` and press Save). "Reset shortcuts to defaults" brings these back.

### Voice start / stop

Turn it on in Settings › Voice start / stop (or 🎙 menu). Then:

1. Say **"Taipea escribe"** or **"Taipea write"**, then pause. Recording starts.
2. Dictate as usual.
3. Pause, say **"listo"**, **"done"** or **"Taipea listo"** on its own, and pause again.
   Taipea stops, removes the phrase from the text and pastes.

How it works: a tiny recorder (SoX) waits for sound, which uses almost no CPU (about
0.1 % on an M2). When you speak, it keeps one short burst of up to 4 seconds, and Whisper
transcribes only that burst, on your Mac (about 1.5 s per burst with large-v3-turbo; put
`ggml-small.bin` in the models folder to make it lighter). Longer bursts, like normal
talking, are skipped without transcribing. Each burst is deleted right after it is checked.
The menu bar shows 👂 and the floating button gets a green ring while it listens. It pauses
while the screen is locked or the Mac sleeps.

Trade-offs:

- macOS shows the orange microphone dot the whole time it is on.
- There is a short delay: the stop phrase is noticed about 2 seconds after you say it.
- A stop phrase is only recognized when you say it alone, after a pause, so "the job is
  done" in the middle of a sentence does not stop you. In return, "done." said alone does.
- "Taipea" is a new word for Whisper, so Taipea also accepts how Whisper tends to hear it
  ("Tapia, right", "Taipei ha listo"). In a noisy room or with music, use the shortcut or
  the floating button instead, or raise `voiceThreshold` in config.lua.
- It is not a wake-word engine like "Hey Siri": it is the best reliable version that runs
  with the tools Taipea already uses, with nothing extra to install.

### Custom words

Settings › Custom words has one big row per word: **Heard** (what Whisper writes) and
**Replace with** (what you want). Add a row with the green **Add** button, delete one with
**Delete**; edits save when you leave a box. Replacements run after transcription and
again after cleanup, match whole words only, and ignore capitals and accents
("Select Dev", "select-dev" and "sélect dev" all become "selektdev").

### Recovery

If a dictation is interrupted (crash, Hammerspoon reload, power loss), Taipea shows a
message and a **♻️ Recover last recording** item in the 🎙 menu and at the top of
History. Recovering transcribes the saved audio (and cleans it if cleanup is on), copies
the text to the clipboard and adds it to History. **Discard** deletes it.

## Default settings

Taipea works out of the box with these settings. Change them in the window's **Settings**
tab, or in `config.lua` (every option, with its default, is listed in `config.example.lua`).

| Setting | Default | Options |
|---|---|---|
| Start / stop dictation | **Ctrl + Option + Space** (stop also pastes) | any shortcut |
| Cleanup on / off | **Ctrl + Option + C** | any shortcut |
| Open the Taipea window | **Ctrl + Option + H** | any shortcut |
| Paste last dictation again | **Ctrl + Option + V** | any shortcut |
| Hide / show floating button | **Option + Command** tap | fixed |
| Cleanup (grammar fix) | On | On / Off (raw text) |
| Cleanup model | `gemma4:e4b`, falls back to `qwen2.5:7b`, then `gemma4:e2b` | any Ollama model |
| Style | Light | Light / Paragraph / Bullets / Formal |
| Speech model | `ggml-large-v3-turbo` | turbo-q5, small, large-v3, medium |
| Dictation language | Auto (English/Spanish mix) | Auto / English / Español |
| Interface language | Auto (follows your Mac) | Auto / English / Español |
| After stopping | Paste at the cursor | Paste / Copy only |
| Restore clipboard after pasting | On | On / Off |
| Recording panel (overlay) | On | On / Off |
| Window size | Normal | Normal / Compact |
| Text size | Normal | Normal / Large / Extra large |
| High contrast | Auto (follows macOS Increase Contrast) | Auto / On / Off |
| Floating mic button | On | On / Off |
| Recording card with floating button | Off | On / Off (`cardWithFab` in config.lua) |
| Colors | Classic Blue | Classic Blue, Studio, Midnight, Forest, Sunset, High Contrast, Paper, Custom |
| Hide floating button when an app is full screen | On | On / Off |
| Hide floating button in these apps | none | any open app |
| Voice start / stop | Off | On / Off; start phrases "Taipea escribe", "Taipea write"; stop phrases "listo", "done", "Taipea listo" |
| Custom words | none | any "heard → replace with" pairs |
| Open at login | On | On / Off |
| Show window at login | Off | On / Off |
| Auto-stop on silence | Off (3 s pause, 1.5 % threshold when on) | On / Off; 2, 3, 5 or 8 s; 0.5–5 % |
| Longest dictation | 30 minutes | `maxSeconds` in config.lua |
| History | last 500 dictations | `historyMax` in config.lua |
| Keep cleanup model loaded | 12 hours | `ollamaKeepAlive` in config.lua |

## Styles

| Style | What you get |
|---|---|
| **Light** | Your words, with punctuation, capitals and spelling fixed. Fillers removed. |
| **Paragraph** | Same, grouped into paragraphs when the topic changes. |
| **Bullets** | A clean list, one idea per line. |
| **Formal** | Polite, professional wording for email or documents ("usted" in Spanish). |

In every style, English words stay English and Spanish words stay Spanish, and names,
numbers and dates are kept. Pick the default style in Settings, or convert any old
dictation in History. Converting always starts from your original words.

## Models

You can change models in the window's **Models** tab.

- **Speech (Whisper):** `large-v3-turbo` (default, 1.6 GB), `large-v3-turbo-q5`
  (0.57 GB), `small` (0.49 GB), and larger ones. Files live in
  `~/Library/Application Support/Taipea/models`.
- **Cleanup (Ollama):** `gemma4:e4b` (default), `qwen2.5:7b` (fallback, lighter),
  `gemma4:e2b`, and others. If the chosen model is missing, Taipea uses the first
  installed fallback. If Ollama isn't running at all, Taipea still pastes the raw text.

Advanced settings are in `~/Library/Application Support/Taipea/config.lua` (see
`config.example.lua` in the same folder).

## Troubleshooting

**Nothing happens when I press the shortcut.**
Check that Hammerspoon is running (🎙 in the menu bar), then choose Hammerspoon › Reload
Config from its menu bar icon. Shortcuts don't need any permission; if one still does
nothing, another app may use the same keys: pick a different one in Settings › Shortcuts.
(If the recording starts but the text is not pasted, that is the Accessibility permission:
see the next item.)

**The overlay appears but nothing is pasted.**
Accessibility permission is missing or stuck: turn Hammerspoon off and on again in
Privacy & Security › Accessibility. You can also choose "Copy only" in Settings and paste
with Cmd+V.

**"No speech detected" or the text is empty.**
Check System Settings › Privacy & Security › Microphone › Hammerspoon. Check that the
right microphone is selected in System Settings › Sound › Input.

**"No speech model yet."**
Open the window (Ctrl+Option+H) › Models and click Download, or run the installer again.

**"Cleanup unavailable" / text is not cleaned.**
Ollama isn't running or no cleanup model is installed. Run
`brew services start ollama` and `ollama pull gemma4:e4b`. If `ollama pull` fails, update
it with `brew upgrade ollama`.

**The first cleanup is slow.**
The model is loading into memory (it can take 10–20 seconds the first time). Taipea keeps
it loaded for 12 hours after that.

**Cleanup is slow every time, or the Mac gets slow.**
Your Mac may not have enough memory for Gemma 4 E4B. Pick `qwen2.5:7b` or `gemma4:e2b` in
Models, or turn cleanup off with Ctrl+Option+C.

**The window or overlay is off screen.**
Settings › Recording panel › Reset panel position. Windows are always kept inside the screen
when you move them.

**Voice start / stop doesn't react, or starts by itself.**
Say the phrase alone, with a short pause before and after. Check that 👂 is in the menu
bar. If it starts by itself in a noisy place, raise `voiceThreshold` (for example `"4%"`)
in config.lua, or change the start phrases. To see what it hears, set `voiceDebug = true`
in config.lua (this writes the short bursts' text to the log).

**The floating button is in the way or off screen.**
Drag it somewhere else, or Settings › Recording controls › Reset button position, or turn it
off there.

**Where are the logs?**
`~/Library/Application Support/Taipea/logs/taipea.log`, or menu bar 🎙 › Open log.
Note that the log contains your dictated text, so check it before sharing.

## Contributing and accessibility reports

Taipea is open source and contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

**Accessibility problems are treated as bugs, with high priority.** If a button is too
small, a step needs a keyboard, something doesn't work with your head mouse, eye tracker,
switch or screen reader, please
[open an accessibility issue](https://github.com/PatoSelekta/taipea/issues/new?template=accessibility.yml).
You don't need to know how to code. Tell us what you use and what got in your way.

## Credits

Taipea is a small layer on top of great free software:

- [whisper.cpp](https://github.com/ggml-org/whisper.cpp) by Georgi Gerganov and contributors,
  running OpenAI's [Whisper](https://github.com/openai/whisper) models (MIT).
- [Ollama](https://ollama.com) for running local language models (MIT).
- [Gemma](https://ai.google.dev/gemma) by Google DeepMind, the default cleanup model
  (used under the [Gemma Terms of Use](https://ai.google.dev/gemma/terms)), and
  [Qwen2.5](https://github.com/QwenLM/Qwen2.5) by Alibaba Cloud as the fallback.
- [Hammerspoon](https://www.hammerspoon.org) for the shortcuts, windows and pasting (MIT).
- [SoX](https://sourceforge.net/projects/sox/) for microphone recording.
- [Homebrew](https://brew.sh) for installing everything.

## License

[MIT](LICENSE) © 2026 Patricio Escobar / selektdev. The models you download have their
own licenses (see Credits).
