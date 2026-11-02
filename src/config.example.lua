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
  -- silenceSeconds = 2.5,               -- length of that pause, in seconds
  -- silenceThreshold = "1.5%",          -- higher = more background noise counts as silence

  -- Behaviour and interface
  -- defaultAction = "paste",            -- after stopping: "paste" at the cursor, or "copy" only
  -- restoreClipboard = true,            -- put back what was on the clipboard after pasting
  -- showOverlay = true,                 -- floating panel with big Stop & Paste / Copy only / Cancel buttons
  -- uiLanguage  = "auto",               -- interface language: "auto" (follows macOS), "en" or "es"
  -- uiSize      = "normal",             -- "normal" or "compact"
  -- openAtLogin = true,                 -- start Hammerspoon (and Taipea) when you log in
  -- showAtLogin = false,                -- also open the Taipea window at login
  -- historyMax  = 500,                  -- dictations kept in History

  -- Tool paths are found automatically in /opt/homebrew/bin (Apple Silicon) and
  -- /usr/local/bin (Intel). Set them only if you installed the tools somewhere else:
  -- whisper = "/opt/homebrew/bin/whisper-cli",
  -- rec     = "/opt/homebrew/bin/rec",
  -- ollama  = "/opt/homebrew/bin/ollama",
}
