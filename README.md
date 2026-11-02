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
- **Optional auto-stop** after a few seconds of silence.

## Privacy: 100% local

- Your voice is recorded to a temporary file on your Mac and transcribed by
  [whisper.cpp](https://github.com/ggml-org/whisper.cpp) on your Mac.
- Grammar cleanup runs in [Ollama](https://ollama.com) on your Mac.
- No account, no cloud, no analytics, no telemetry. After the installer downloads the
  models, Taipea works with Wi-Fi off.
- Your history is a file on your Mac:
  `~/Library/Application Support/Taipea/history.json`. Delete it any time, or use
  "Clear all" in the History tab.

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

## Permissions (one time)

macOS protects your microphone and keyboard. You have to allow these once. Taipea runs
inside Hammerspoon, so the permission is for **Hammerspoon**:

1. **Accessibility:** System Settings › Privacy & Security › Accessibility › turn on
   **Hammerspoon**. Needed for the shortcuts and to paste the text.
2. **Microphone:** the first time you dictate, macOS asks. Click **Allow**. To check
   later: System Settings › Privacy & Security › Microphone › **Hammerspoon**.

If a switch is already on but nothing gets pasted, turn it off and on again, then restart
Hammerspoon.

## How to use it

These are the default shortcuts. They work as soon as Taipea is installed, even with no
config file.

| Shortcut | What it does |
|---|---|
| **Ctrl + Option + Space** | Start dictating. Press the same shortcut again to stop: Taipea transcribes, cleans up and pastes at your cursor. |
| **Ctrl + Option + C** | Turn cleanup on or off (raw text). |
| **Ctrl + Option + H** | Open the Taipea window: History, Settings, Models. |

No keyboard? Everything also works with clicks:

- While you talk, a floating panel shows three big buttons: **Stop & Paste**,
  **Stop & Copy only**, and **Cancel**.
- Open **Taipea.app** (in `~/Applications`, add it to your Dock) to open the window.
  It has a big **🎙 Dictate** button.
- The 🎙 icon in the menu bar has the same actions.

You can see and change the shortcuts in Settings › Shortcuts (type one like
`ctrl+alt+space` and press Save). "Reset shortcuts to defaults" brings these back.

## Default settings

Taipea works out of the box with these settings. Change them in the window's **Settings**
tab, or in `config.lua` (every option, with its default, is listed in `config.example.lua`).

| Setting | Default | Options |
|---|---|---|
| Start / stop dictation | **Ctrl + Option + Space** (stop also pastes) | any shortcut |
| Cleanup on / off | **Ctrl + Option + C** | any shortcut |
| Open the Taipea window | **Ctrl + Option + H** | any shortcut |
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
| Open at login | On | On / Off |
| Show window at login | Off | On / Off |
| Auto-stop on silence | Off (2.5 s pause, 1.5 % threshold when on) | On / Off, 1–∞ s, 0.5–5 % |
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
Check that Hammerspoon is running (🎙 in the menu bar) and has Accessibility permission.
Then choose Hammerspoon › Reload Config from its menu bar icon.

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
