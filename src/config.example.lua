-- Taipea settings file: ~/Library/Application Support/Taipea/config.lua
--
-- Every value below is the DEFAULT that Taipea already uses, so this file is optional.
-- To change one, copy the line into config.lua, remove the "--" in front, edit it,
-- then choose Hammerspoon > Reload Config (or restart Hammerspoon).
-- Most of these can also be changed in the Taipea window (Ctrl+Option+H) > Settings;
-- choices made there are saved in settings.json and win over this file.
return {
  -- Shortcuts (mods: "ctrl", "alt" = Option, "cmd", "shift")
  -- toggleKey   = { mods = {"ctrl","alt"}, key = "space" },  -- Ctrl+Option+Space: start; press again to stop and paste
  -- modeKey     = { mods = {"ctrl","alt"}, key = "c" },      -- Ctrl+Option+C: cleanup on / off (raw text)
  -- historyKey  = { mods = {"ctrl","alt"}, key = "h" },      -- Ctrl+Option+H: open the Taipea window
  -- pasteLastKey = { mods = {"ctrl","alt"}, key = "v" },     -- Ctrl+Option+V: paste the last dictation again

  -- Cleanup (grammar fix with a local Ollama model)
  -- cleanup     = true,                 -- false = always paste the raw transcription
  -- style       = "light",              -- "light" | "paragraphs" | "bullets" | "formal"
  -- ollamaModel = "gemma4:e4b",         -- any Ollama library tag
  -- ollamaFallbacks = { "qwen2.5:7b", "gemma4:e2b" },  -- tried in order if the main one is missing
  -- ollamaKeepAlive = "12h",            -- how long Ollama keeps the model in memory
  -- ollamaURL   = "http://127.0.0.1:11434/api/generate",

  -- Speech recognition (whisper.cpp)
  -- modelName   = "ggml-large-v3-turbo.bin",  -- file in .../Taipea/models, or a full path
  -- language    = "auto",               -- dictation language: "auto" (English/Spanish mix), "en" or "es"
  -- maxSeconds  = 1800,                 -- longest dictation: 30 minutes
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
  -- floatButton = true,                 -- round always-on-top 🎙 button: click to start, again to stop and paste

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
  -- openAtLogin = true,                 -- start Hammerspoon (and Taipea) when you log in
  -- showAtLogin = false,                -- also open the Taipea window at login
  -- historyMax  = 500,                  -- dictations kept in History

  -- Tool paths are found automatically in /opt/homebrew/bin (Apple Silicon) and
  -- /usr/local/bin (Intel). Set them only if you installed the tools somewhere else:
  -- whisper = "/opt/homebrew/bin/whisper-cli",
  -- rec     = "/opt/homebrew/bin/rec",
  -- ollama  = "/opt/homebrew/bin/ollama",
}
