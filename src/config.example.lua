-- Taipea settings file: ~/Library/Application Support/Taipea/config.lua
--
-- Every value below is the DEFAULT that Taipea already uses, so this file is optional.
-- To change one, copy the line into config.lua, remove the "--" in front, edit it,
-- then choose Hammerspoon > Reload Config (or restart Hammerspoon).
-- Most of these can also be changed in the Taipea window (Control+Option+H) > Settings;
-- choices made there are saved in settings.json and win over this file.
return {
  -- Shortcuts (mods: "ctrl", "alt" = Option, "cmd", "shift"). The easy way to change them is
  -- Settings > Shortcuts > Record shortcut. key = "" means modifiers only: press them together
  -- (or latch them on the Accessibility Keyboard); it acts on press, not on release.
  -- toggleKey   = { mods = {"ctrl","cmd"}, key = "" },       -- Control+Command: start; press again to stop and paste
  -- toggleKey2  = { mods = {"ctrl","alt"}, key = "space" },  -- Control+Option+Space: start / stop (backup)
  -- modeKey     = { mods = {"ctrl","alt"}, key = "c" },      -- Control+Option+C: cleanup on / off (raw text)
  -- historyKey  = { mods = {"ctrl","alt"}, key = "h" },      -- Control+Option+H: open the Taipea window
  -- pasteLastKey = { mods = {"ctrl","alt"}, key = "v" },     -- Control+Option+V: paste the last dictation again
  -- fabHideKey  = { mods = {"alt","cmd"}, key = "" },        -- Option+Command: hide / show the floating button
  -- escStop     = true,                 -- Escape while recording = stop and paste (Escape alone, no modifiers)
  -- micKey      = false,                -- true = the Mic (Dictation) key F5 starts / stops Taipea. First set
  --                                     -- System Settings > Keyboard > Dictation > Shortcut to Off (see docs/USAGE.md)

  -- Cleanup (grammar fix with a local Ollama model)
  -- cleanup     = true,                 -- false = always paste the raw transcription
  -- style       = "light",              -- "light" | "paragraphs" | "bullets" | "formal"
  -- ollamaModel = "gemma4:e4b",         -- any Ollama library tag
  -- ollamaFallbacks = { "qwen2.5:7b", "gemma4:e2b" },  -- tried in order if the main one is missing
  -- ollamaKeepAlive = "12h",            -- how long Ollama keeps the model in memory
  -- ollamaURL   = "http://127.0.0.1:11434/api/generate",

  -- Speech recognition (whisper.cpp)
  -- modelName   = "ggml-large-v3-turbo.bin",  -- file in .../Taipea/models, or a full path
  -- language    = "auto",               -- dictation language: "auto" (detects ~99 languages, incl. the English/Spanish mix), "en" or "es"
  -- maxSeconds  = 1800,                 -- longest dictation: 30 minutes
  -- liveTranscribe = true,              -- true = transcribe overlapping 24 s slices while you talk
  --                                     -- (stop waits on the last slice + cleanup). false = current
  --                                     -- full-file Whisper after stop. Failures and >40 s backlog
  --                                     -- fall back to the full-file path. No Settings toggle.
  -- autoStop    = false,                -- true = stop by itself after a pause
  -- silenceSeconds = 3,                 -- length of that pause, in seconds (Settings offers 2, 3, 5, 8)
  -- silenceThreshold = "1.5%",          -- higher = more background noise counts as silence

  -- Behaviour and interface
  -- defaultAction = "paste",            -- after stopping: "paste" at the cursor, or "copy" only
  -- restoreClipboard = true,            -- put back what was on the clipboard after pasting
  -- showOverlay = true,                 -- floating panel with big Stop & Paste / Copy only / Cancel buttons
  -- uiLanguage  = "auto",               -- interface language: "auto" (follows macOS), "en" or "es"
  -- uiSize      = "normal",             -- "normal" or "compact"
  -- textSize    = "normal",             -- "normal", "large" or "xlarge" (window, panel and floating button)
  -- contrast    = "auto",               -- high contrast: "auto" (follows macOS Increase Contrast), "on" or "off"
  -- floatButton = true,                 -- round always-on-top mic button: click to start; green while recording = stop and paste
  -- cardWithFab = false,                -- with floatButton on: also show the full recording card (three big buttons)
  -- hideFullscreen = true,              -- hide the floating button while the app in front is full screen
  -- hideApps    = {},                   -- hide it while these apps are in front, e.g. { { name = "VLC", id = "org.videolan.vlc" } }
  --                                        (it never hides while recording or working)

  -- Updates. 30 seconds after start and then once a day, Taipea asks GitHub (api.github.com) for the
  -- latest release. This is its only network request besides the model downloads. It sends no data
  -- about you or your dictations (only "Taipea/<version>" as the user agent). Nothing is downloaded
  -- or installed by itself: a "New version" banner links to the release page on GitHub.
  -- Turn it off here or in Settings › Updates ("Check now" still works when it is off).
  -- checkForUpdates = true,
  -- updateRepo  = "PatoSelekta/taipea", -- GitHub owner/repo to check (links only open on github.com)

  -- Colors for the whole app (window, recording card, floating button). Easier in Settings › Colors.
  -- floatingTheme = "classic",          -- "classic" | "studio" | "midnight" | "forest" | "sunset" | "contrast" | "paper" | "custom"
  -- customBg     = "#1A1A1A",           -- Custom set: background
  -- customMic    = "#FFFFFF",           -- Custom set: microphone and text
  -- customAccent = "#E8503A",           -- Custom set: accent (buttons, ring); hard-to-read text is fixed automatically

  -- Custom words: fixed after transcription and after cleanup (whole words, any case/accents).
  -- Easier to edit in Settings › Custom words.
  -- customWords = { { heard = "select dev", replace = "selektdev" } },

  -- Voice start / stop (everything runs on this Mac; see the README)
  -- voiceControl = false,               -- true = listen for the phrases below
  -- startPhrases = { "Taipea escribe", "Taipea write" },
  -- stopPhrases  = { "listo", "done", "Taipea listo" },  -- say them alone, after a pause
  -- voiceModel   = nil,                 -- nil = ggml-small*.bin in models/ if present, else the main model
  -- voiceThreshold = "2%",              -- how loud a sound must be to be checked (raise it in noisy rooms)
  -- voiceMaxBurst = 4,                  -- seconds; longer bursts (normal talking) are skipped
  -- voiceDebug   = false,               -- true = write what the listener heard to the log
  -- inputDevice = "",                   -- CoreAudio UID of the preferred microphone; empty = Mac default (Settings › Microphone)
  -- inputDeviceName = "",               -- display name saved with it (set automatically)
  -- openAtLogin = true,                 -- start Hammerspoon (and Taipea) when you log in
  -- showAtLogin = false,                -- also open the Taipea window at login
  -- historyMax  = 500,                  -- dictations kept in History

  -- Tool paths are found automatically in /opt/homebrew/bin (Apple Silicon) and
  -- /usr/local/bin (Intel). Set them only if you installed the tools somewhere else:
  -- whisper = "/opt/homebrew/bin/whisper-cli",
  -- rec     = "/opt/homebrew/bin/rec",
  -- ollama  = "/opt/homebrew/bin/ollama",
}
