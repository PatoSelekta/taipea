-- Taipea settings file: ~/Library/Application Support/Taipea/config.lua
-- Every line is optional. Remove the "--" in front of a line to change it,
-- then choose Hammerspoon > Reload Config (or restart Hammerspoon).
-- Most of these can also be changed in the Taipea window (Ctrl+Option+H) > Settings;
-- choices made there are saved in settings.json and win over this file.
return {
  -- toggleKey   = { mods = {"ctrl","alt"}, key = "space" },  -- start / stop dictation
  -- modeKey     = { mods = {"ctrl","alt"}, key = "c" },      -- cleanup on / off
  -- historyKey  = { mods = {"ctrl","alt"}, key = "h" },      -- open the Taipea window

  -- cleanup     = true,                 -- false = always paste the raw transcription
  -- ollamaModel = "gemma4:e4b",         -- cleanup model (any Ollama library tag)
  -- ollamaFallbacks = { "qwen2.5:7b", "gemma4:e2b" },  -- tried in order if the main one is missing
  -- ollamaKeepAlive = "12h",            -- how long Ollama keeps the model in memory

  -- modelName   = "ggml-large-v3-turbo.bin",  -- file in .../Taipea/models, or a full path
  -- language    = "auto",               -- "auto" (English/Spanish mix), "en" or "es"
  -- maxSeconds  = 1800,                 -- longest dictation, in seconds (30 minutes)
  -- autoStop    = false,                -- stop by itself after a pause
  -- silenceSeconds = 2.5,
  -- silenceThreshold = "1.5%",
  -- restoreClipboard = true,            -- put back what was on the clipboard after pasting
  -- historyMax  = 500,

  -- Paths are found automatically in /opt/homebrew/bin (Apple Silicon) and /usr/local/bin (Intel).
  -- Set them only if you installed the tools somewhere else:
  -- whisper = "/opt/homebrew/bin/whisper-cli",
  -- rec     = "/opt/homebrew/bin/rec",
  -- ollama  = "/opt/homebrew/bin/ollama",
}
