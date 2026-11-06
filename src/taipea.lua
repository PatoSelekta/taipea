-- Taipea ("it types for you"): hands-free, 100% local dictation for macOS.
-- Hammerspoon module. https://selektdev.com · MIT License · v0.2.12
-- Data (models, settings, history, logs) lives in ~/Library/Application Support/Taipea
require("hs.ipc")
local HOME = os.getenv("HOME")
local DATA = HOME.."/Library/Application Support/Taipea"
for _,d in ipairs({ DATA, DATA.."/models", DATA.."/logs", DATA.."/tmp", DATA.."/ui" }) do
  if not hs.fs.attributes(d) then hs.fs.mkdir(d) end
end

-- find a command-line tool in the Homebrew prefixes (Apple Silicon first, then Intel)
local function findBin(name, extra)
  local dirs = { "/opt/homebrew/bin", "/usr/local/bin" }
  for _,x in ipairs(extra or {}) do table.insert(dirs, x) end
  for _,d in ipairs(dirs) do
    local p = d:sub(-#name) == name and d or (d.."/"..name)
    if hs.fs.attributes(p, "mode") == "file" then return p end
  end
  return nil
end

-- built-in defaults; override any of them in ~/Library/Application Support/Taipea/config.lua
local DEFAULTS = {
  toggleKey   = { mods = {"ctrl","cmd"}, key = "" },       -- start / stop dictation: press Control + Command (acts on press)
  toggleKey2  = { mods = {"ctrl","alt"}, key = "space" },  -- start / stop, backup shortcut
  fabHideKey  = { mods = {"alt","cmd"}, key = "" },        -- hide / show the floating button: press Option + Command
  escStop     = true,                        -- Escape while recording = stop & paste
  micKey      = false,                       -- Mic (Dictation) key 🎙 F5 = start / stop (turn off macOS Dictation's shortcut first)
  modeKey     = { mods = {"ctrl","alt"}, key = "c" },      -- cleanup on / off (raw)
  historyKey  = { mods = {"ctrl","alt"}, key = "h" },      -- open the Taipea window
  cleanup     = true,
  ollamaModel = "gemma4:e4b",                -- cleanup model (Ollama library tag)
  ollamaFallbacks = { "qwen2.5:7b", "gemma4:e2b" }, -- used if the main model is not installed
  ollamaURL   = "http://127.0.0.1:11434/api/generate",
  ollamaKeepAlive = "12h",                   -- keep the model loaded (avoids a slow first cleanup)
  whisper     = nil,                         -- nil = auto-detect whisper-cli in Homebrew
  rec         = nil,                         -- nil = auto-detect rec (from sox)
  ollama      = nil,                         -- nil = auto-detect the ollama command
  modelName   = "ggml-large-v3-turbo.bin",   -- file in DATA/models, or an absolute path
  maxSeconds  = 1800,                        -- 30-minute cap per dictation
  liveTranscribe = true,                     -- transcribe overlapping slices while recording; false = current full-file path only
  restoreClipboard = true,
  autoStop    = false,
  silenceSeconds = 3,                        -- 2, 3, 5 or 8 in Settings
  silenceThreshold = "1.5%",
  historyMax  = 500,
  openAtLogin = true, showAtLogin = false,
  showOverlay = true,                        -- floating panel with big buttons while recording
  style = "light",                           -- light | paragraphs | bullets | formal
  language = "auto",                         -- dictation language: auto (detects ~99 languages, incl. the EN/ES mix) | en | es
  uiLanguage = "auto",                       -- interface language: auto (macOS language) | en | es
  defaultAction = "paste",                   -- after stopping: paste | copy
  uiSize = "normal",                         -- normal | compact
  pasteLastKey = { mods = {"ctrl","alt"}, key = "v" },  -- paste the last dictation again
  textSize = "normal",                       -- normal | large | xlarge (window, recording panel, floating button)
  contrast = "auto",                         -- high contrast: auto (follows macOS Increase Contrast) | on | off
  floatButton = true,                        -- round always-on-top mic button: click to start; while recording it turns green (click = stop and paste)
                                             -- and shows two small buttons: blue = stop and copy only, red = cancel
  cardWithFab = false,                       -- also show the recording card while the floating button is on
  floatingTheme = "classic",                 -- app colours: classic | studio | midnight | forest | sunset | contrast | paper | custom
  customBg = "#1A1A1A", customMic = "#FFFFFF", customAccent = "#E8503A",  -- the 3 colours of the Custom set (#RRGGBB)
  hideFullscreen = true,                     -- hide the floating button while the app in front is full screen
  hideApps = {},                             -- hide it while one of these apps is in front: { {name="VLC", id="org.videolan.vlc"}, ... }
  checkForUpdates = true,                    -- once a day, ask GitHub for the latest release (nothing is downloaded)
  updateRepo = "PatoSelekta/taipea",         -- where releases are published
  customWords = {},                          -- { {heard="select dev", replace="selektdev"}, ... } (edit in Settings)
  voiceControl = false,                      -- voice start/stop (listens for the phrases below; all on this Mac)
  startPhrases = { "Taipea escribe", "Taipea write" },
  stopPhrases = { "listo", "done", "Taipea listo" },
  voiceModel = nil,                          -- nil = ggml-small*.bin if present, else the main speech model
  voiceThreshold = "2%",                     -- how loud a sound must be to be checked for a phrase
  voiceMaxBurst = 4,                         -- seconds; longer bursts (normal talking) are skipped
  voiceDebug = false,                        -- true = write what the listener heard to the log
  inputDevice = "",                          -- CoreAudio UID of the preferred microphone; empty = system default
  inputDeviceName = "",                      -- display name saved with it
}

local cfg = {}
local cfgError = false
for k,v in pairs(DEFAULTS) do cfg[k]=v end
do
  local cf = DATA.."/config.lua"
  if hs.fs.attributes(cf) then
    local ok, user = pcall(dofile, cf)
    if ok and type(user)=="table" then for k,v in pairs(user) do cfg[k]=v end
    else cfgError = true end
  end
end
local setf = DATA.."/settings.json"
local saved = {}
do local f=io.open(setf,"r"); if f then local ok,j=pcall(hs.json.decode,f:read("a")); f:close(); if ok and type(j)=="table" then saved=j end end end
for k,v in pairs(saved) do cfg[k]=v end
cfg.whisper = cfg.whisper or findBin("whisper-cli")
cfg.rec     = cfg.rec or findBin("rec")
cfg.ollama  = cfg.ollama or findBin("ollama", { "/Applications/Ollama.app/Contents/Resources/ollama" })
local function saveSettings() local f=io.open(setf,"w"); if f then f:write(hs.json.encode(saved,true)); f:close() end end
local function modelPath() if cfg.modelName:sub(1,1)=="/" then return cfg.modelName end; return DATA.."/models/"..cfg.modelName end

-- ---------- interface strings (English / Español) ----------
local STR = {
 en = {
  cfg_error="Taipea: config.lua has an error, using defaults",
  menu_open="Open Taipea…", menu_start="Start dictation", menu_stop="Stop & Paste", menu_cleanup="Cleanup (grammar fix)",
  menu_autostop="Auto-stop after %ss silence", menu_recent="Recent (click to copy)", menu_log="Open log",
  ov_listening="Listening…", ov_stop="Stop &amp;<br>Paste", ov_copy="Stop &amp;<br>Copy only", ov_cancel="Cancel",
  ov_autostop="Auto-stops after %ss of silence", ov_press="Press %s or a button to finish",
  ov_transcribing="Transcribing…", ov_still="Transcribing… (still working)",
  ov_cleaning="Cleaning up…", ov_cleaning_part="Cleaning up… part %d of %d", ov_fixing="Fixing grammar with %s",
  copied="Copied", copied_clip="Copied to clipboard", copied_raw="Copied raw", no_speech="No speech detected",
  nothing_heard="Nothing heard · nothing was pasted", ov_check_lang="checking the language",
  nothing_convert="Nothing to convert", converted="Converted to %s · copied to clipboard", parts_raw=" (%d part(s) kept raw)",
  styles_need_model="Styles need a cleanup model – install Ollama and a model (see README)",
  conv_failed="Conversion failed – is Ollama running? (see log)",
  cleanup_unavail="Cleanup unavailable (Ollama not running or no model) – pasting raw text",
  cleanup_failed="Cleanup failed (is Ollama running?) – pasted raw text",
  cleanup_too_much="Cleanup removed too much – pasted raw text",
  parts_kept="%d of %d parts kept raw (cleanup removed too much)",
  trans_failed="Transcription failed – see log", still_processing="Still processing…",
  need_sox="Taipea needs sox (rec). Run: brew install sox", need_whisper="Taipea needs whisper.cpp. Run: brew install whisper-cpp",
  need_model="No speech model yet. Open Taipea (%s) › Models to download one",
  mode_clean="Dictation: CLEANED", mode_raw="Dictation: RAW", autostop_on="Auto-stop on silence: ON", autostop_off="Auto-stop on silence: OFF",
  starting="Starting…", failed="Failed (%s)", downloaded="Downloaded %s", install_ollama="Install Ollama first: brew install ollama",
  hidden="Taipea hidden – press %s or open Taipea.app to reopen", history_cleared="History cleared", overlay_reset="Overlay position reset",
  bad_shortcut="Invalid shortcut: %s", shortcut_set="Shortcut set: %s", shortcuts_reset="Shortcuts reset to the defaults", using="Using %s",
  login_on="Opens at login: ON", login_off="Opens at login: OFF – dictation unavailable until Hammerspoon is opened",
  lang_set="Language: English", note_local="local file", note_custom="custom path (config.lua)", note_installed="installed",
  style_light="Light", style_paragraphs="Paragraph", style_bullets="Bullets", style_formal="Formal",
  k_ctrl="Control", k_alt="Option", k_cmd="Command", k_shift="Shift", k_space="Space",
 },
 es = {
  cfg_error="Taipea: config.lua tiene un error, se usan los valores por defecto",
  menu_open="Abrir Taipea…", menu_start="Empezar a dictar", menu_stop="Parar y pegar", menu_cleanup="Corrección (gramática)",
  menu_autostop="Parar solo tras %s s de silencio", menu_recent="Recientes (clic para copiar)", menu_log="Abrir registro",
  ov_listening="Escuchando…", ov_stop="Parar y<br>pegar", ov_copy="Parar y<br>solo copiar", ov_cancel="Cancelar",
  ov_autostop="Se detiene tras %s s de silencio", ov_press="Presiona %s o un botón para terminar",
  ov_transcribing="Transcribiendo…", ov_still="Transcribiendo… (sigue trabajando)",
  ov_cleaning="Corrigiendo…", ov_cleaning_part="Corrigiendo… parte %d de %d", ov_fixing="Corrigiendo con %s",
  copied="Copiado", copied_clip="Copiado al portapapeles", copied_raw="Texto original copiado", no_speech="No se detectó voz",
  nothing_heard="No se escuchó nada · no se pegó nada", ov_check_lang="revisando el idioma",
  nothing_convert="No hay nada que convertir", converted="Convertido a %s · copiado al portapapeles", parts_raw=" (%d parte(s) sin corregir)",
  styles_need_model="Los estilos necesitan un modelo de corrección: instala Ollama y un modelo (mira el README)",
  conv_failed="La conversión falló: ¿está corriendo Ollama? (mira el registro)",
  cleanup_unavail="Corrección no disponible (Ollama apagado o sin modelo): se pega el texto original",
  cleanup_failed="La corrección falló (¿está corriendo Ollama?): se pegó el texto original",
  cleanup_too_much="La corrección quitó demasiado: se pegó el texto original",
  parts_kept="%d de %d partes quedaron sin corregir (la corrección quitó demasiado)",
  trans_failed="La transcripción falló: mira el registro", still_processing="Todavía procesando…",
  need_sox="Taipea necesita sox (rec). Ejecuta: brew install sox", need_whisper="Taipea necesita whisper.cpp. Ejecuta: brew install whisper-cpp",
  need_model="Aún no hay modelo de voz. Abre Taipea (%s) › Modelos para descargar uno",
  mode_clean="Dictado: CORREGIDO", mode_raw="Dictado: ORIGINAL", autostop_on="Parada por silencio: SÍ", autostop_off="Parada por silencio: NO",
  starting="Empezando…", failed="Falló (%s)", downloaded="Descargado %s", install_ollama="Primero instala Ollama: brew install ollama",
  hidden="Taipea oculto: presiona %s o abre Taipea.app para volver", history_cleared="Historial borrado", overlay_reset="Posición del panel restablecida",
  bad_shortcut="Atajo no válido: %s", shortcut_set="Atajo guardado: %s", shortcuts_reset="Atajos restablecidos a los de fábrica", using="Usando %s",
  login_on="Abrir al iniciar sesión: SÍ", login_off="Abrir al iniciar sesión: NO (el dictado no funciona hasta abrir Hammerspoon)",
  lang_set="Idioma: Español", note_local="archivo local", note_custom="ruta propia (config.lua)", note_installed="instalado",
  style_light="Ligero", style_paragraphs="Párrafos", style_bullets="Viñetas", style_formal="Formal",
  k_ctrl="Control", k_alt="Opción", k_cmd="Comando", k_shift="Mayúsculas", k_space="Espacio",
 },
}
-- ---------- v0.2 interface strings (English / Español) ----------
local NEWSTR = {
 en = {
  menu_voice="Voice start/stop (say “%s”)", menu_fab="Floating button", menu_paste_last="Paste last dictation again",
  menu_recover="Recover last recording (%s)", menu_discard="Discard interrupted recording",
  nothing_paste="Nothing to paste yet", recover_offer="A recording was interrupted. Choose 🎙 › Recover last recording",
  recovering="Recovering…", recovered="Recovered dictation copied to the clipboard (also in History)", recover_none="Nothing to recover",
  recover_discarded="Interrupted recording discarded",
  ov_say_stop="Say “%s” or press a button to finish",
  voice_on="Voice start/stop: ON. Say “%s” to start", voice_off="Voice start/stop: OFF", voice_paused="Voice start/stop is paused while the screen is locked",
  voice_need_phrase="Type at least one phrase", phrases_saved="Phrases saved",
  fab_idle="Start dictation", fab_rec="Stop & Paste", sat_copy="Stop & Copy only", sat_cancel="Cancel", fab_busy="Working…", fab_listening="Listening for “%s”", fab_reset="Floating button position reset",
  wd_reset="Processing got stuck, so it was reset. Your audio is kept: 🎙 › Recover last recording", wd_empty="The recording was empty, nothing to transcribe. Check the microphone.", wd_nowhisper="Speech engine (whisper-cli) not found. Your audio is kept for recovery.",
  fab_on="Floating button: ON", card_on="Recording card: shown with the floating button", card_off="Recording card: hidden while the floating button is on", fab_off="Floating button: OFF",
  words_saved="Custom words saved", words_bad="Fill in both boxes: what Whisper hears and what to write",
  look_set="Display updated",
  fab_hidden="Floating button hidden (press %s to show it again)", fab_tap_key="Option + Command",
  k_none="No shortcut", k_need2="Use at least two modifier keys (for example Control + Command)", k_single="Add Control, Option or Command (a single key would type too)",
  k_system="macOS already uses this shortcut", k_dup="Already used by: %s", k_mic="The Mic key has its own switch below", k_unknown="Taipea doesn't know this key",
  k_lbl_toggleKey="Start / stop", k_lbl_toggleKey2="Start / stop (backup)", k_lbl_modeKey="Cleanup on / off", k_lbl_historyKey="Open the Taipea window",
  k_lbl_pasteLastKey="Paste last again", k_lbl_fabHideKey="Hide / show floating button",
  esc_on="Escape while recording: stop & paste", esc_off="Escape no longer stops recording", mic_on="Mic key 🎙 (F5): start / stop", mic_off="Mic key 🎙 (F5): off",
  ov_press_esc="Press %s or Esc to finish", fab_shown="Floating button shown", fab_is_off="The floating button is off in Settings",
  menu_fab_hide="Hide floating button for now", hide_added="Added: %s", hide_removed="Removed: %s", color_bad="That color is not valid. Use a code like #E8503A",
  perm_ax_paste="⚠️ Accessibility permission is off, so Taipea can't paste.\nThe text is on the clipboard: paste it with Cmd+V. Open Taipea for the settings button.",
  perm_ax_start="⚠️ Taipea needs Accessibility permission (for Hammerspoon) to paste.\nOpen Taipea › Open Accessibility settings.",
  perm_ax_back="✅ Accessibility is on: pasting works again.",
  perm_mic_hint="\n\n🎤 If this keeps happening, Hammerspoon may not have Microphone permission.\nOpen Taipea › Open Microphone settings.",
  menu_open_ax="⚠️ Open Accessibility settings", menu_open_mic="🎤 Open Microphone settings",
  mic_set="Microphone: %s", mic_default="Microphone: system default",
  mic_missing="That microphone is not connected. Using the system default.",
  upd_menu="⬆️ New version available: v%s", upd_new="New version available: v%s", upd_none="You have the latest version (v%s)", upd_err="Couldn't check for updates. Try again later.",
  upd_later="OK, I'll remind you in 7 days", upd_skipped="Skipped v%s", upd_note_t="Taipea v%s is available", upd_note_b="Open Taipea to see what's new.", upd_on="Update check: ON", upd_off="Update check: OFF",
 },
 es = {
  menu_voice="Empezar/parar con la voz (di «%s»)", menu_fab="Botón flotante", menu_paste_last="Pegar otra vez el último dictado",
  menu_recover="Recuperar la última grabación (%s)", menu_discard="Descartar la grabación interrumpida",
  nothing_paste="Todavía no hay nada para pegar", recover_offer="Se interrumpió una grabación. Elige 🎙 › Recuperar la última grabación",
  recovering="Recuperando…", recovered="Dictado recuperado y copiado al portapapeles (también está en el Historial)", recover_none="No hay nada que recuperar",
  recover_discarded="Grabación interrumpida descartada",
  ov_say_stop="Di «%s» o presiona un botón para terminar",
  voice_on="Empezar/parar con la voz: SÍ. Di «%s» para empezar", voice_off="Empezar/parar con la voz: NO", voice_paused="La voz está en pausa mientras la pantalla está bloqueada",
  voice_need_phrase="Escribe al menos una frase", phrases_saved="Frases guardadas",
  fab_idle="Empezar a dictar", fab_rec="Parar y pegar", sat_copy="Parar y solo copiar", sat_cancel="Cancelar", fab_busy="Trabajando…", fab_listening="Escuchando «%s»", fab_reset="Posición del botón flotante restablecida",
  wd_reset="El procesamiento se trabó y se reinició. Tu audio está guardado: 🎙 › Recuperar la última grabación", wd_empty="La grabación quedó vacía, no hay nada que transcribir. Revisa el micrófono.", wd_nowhisper="No se encontró el motor de voz (whisper-cli). Tu audio está guardado para recuperarlo.",
  fab_on="Botón flotante: SÍ", card_on="Tarjeta de grabación: se muestra con el botón flotante", card_off="Tarjeta de grabación: oculta mientras el botón flotante está activo", fab_off="Botón flotante: NO",
  words_saved="Palabras propias guardadas", words_bad="Llena las dos casillas: lo que oye Whisper y lo que se debe escribir",
  look_set="Pantalla actualizada",
  fab_hidden="Botón flotante oculto (presiona %s para mostrarlo otra vez)", fab_tap_key="Opción + Comando",
  k_none="Sin atajo", k_need2="Usa al menos dos teclas modificadoras (por ejemplo Control + Comando)", k_single="Agrega Control, Opción o Comando (una sola tecla también escribiría)",
  k_system="macOS ya usa este atajo", k_dup="Ya lo usa: %s", k_mic="La tecla Micrófono tiene su propio interruptor abajo", k_unknown="Taipea no conoce esta tecla",
  k_lbl_toggleKey="Empezar / detener", k_lbl_toggleKey2="Empezar / detener (respaldo)", k_lbl_modeKey="Corrección sí / no", k_lbl_historyKey="Abrir la ventana de Taipea",
  k_lbl_pasteLastKey="Pegar el último otra vez", k_lbl_fabHideKey="Ocultar / mostrar el botón flotante",
  esc_on="Escape al grabar: detener y pegar", esc_off="Escape ya no detiene la grabación", mic_on="Tecla Micrófono 🎙 (F5): empezar / detener", mic_off="Tecla Micrófono 🎙 (F5): apagada",
  ov_press_esc="Presiona %s o Esc para terminar", fab_shown="Botón flotante visible", fab_is_off="El botón flotante está apagado en Ajustes",
  menu_fab_hide="Ocultar el botón flotante por ahora", hide_added="Añadida: %s", hide_removed="Quitada: %s", color_bad="Ese color no es válido. Usa un código como #E8503A",
  perm_ax_paste="⚠️ El permiso de Accesibilidad está apagado: Taipea no puede pegar.\nEl texto está en el portapapeles: pégalo con Cmd+V. Abre Taipea para el botón de ajustes.",
  perm_ax_start="⚠️ Taipea necesita el permiso de Accesibilidad (para Hammerspoon) para pegar.\nAbre Taipea › Abrir ajustes de Accesibilidad.",
  perm_ax_back="✅ Accesibilidad activada: ya se puede pegar.",
  perm_mic_hint="\n\n🎤 Si se repite, puede que Hammerspoon no tenga permiso de Micrófono.\nAbre Taipea › Abrir ajustes de Micrófono.",
  menu_open_ax="⚠️ Abrir ajustes de Accesibilidad", menu_open_mic="🎤 Abrir ajustes de Micrófono",
  mic_set="Micrófono: %s", mic_default="Micrófono: el del sistema",
  mic_missing="Ese micrófono no está conectado. Se usa el del sistema.",
  upd_menu="⬆️ Nueva versión disponible: v%s", upd_new="Nueva versión disponible: v%s", upd_none="Tienes la última versión (v%s)", upd_err="No se pudo buscar actualizaciones. Inténtalo más tarde.",
  upd_later="Listo, te lo recuerdo en 7 días", upd_skipped="Se omitió la v%s", upd_note_t="Taipea v%s está disponible", upd_note_b="Abre Taipea para ver las novedades.", upd_on="Buscar actualizaciones: SÍ", upd_off="Buscar actualizaciones: NO",
 },
}
for l, t in pairs(NEWSTR) do for k, v in pairs(t) do STR[l][k] = v end end
-- macOS language (first preferred language), "es" or "en"
local function systemLang()
  local ok, langs = pcall(function() return hs.host.locale.preferredLanguages() end)
  local l = ok and type(langs)=="table" and langs[1] or nil
  if type(l) ~= "string" then local ok2, c = pcall(function() return hs.host.locale.current() end); l = ok2 and c or "en" end
  return (type(l)=="string" and l:lower():sub(1,2)=="es") and "es" or "en"
end
local sysLang = systemLang()
local function uiLang() if cfg.uiLanguage=="es" or cfg.uiLanguage=="en" then return cfg.uiLanguage end; return sysLang end
-- translated string; extra arguments fill %s / %d
local function T(k, ...)
  local s = STR[uiLang()][k] or STR.en[k] or k
  if select("#", ...) > 0 then return string.format(s, ...) end
  return s
end
if cfgError then hs.alert.show(T("cfg_error")) end

local M = {}
-- one-shot timers are kept referenced until they fire (an unreferenced hs.timer can be
-- garbage-collected and never run, which once left a dictation stuck in "processing")
M._timers = {}
-- Live overlapping slices. One table (no extra main-chunk locals: the file is at Lua's 200 limit).
M.LIVE = { SLICE = 24, OVERLAP = 4, FALLBACK_SECS = 40, gen = 0, on = false }
local function after(sec, fn)
  local t; t = hs.timer.doAfter(sec, function(...) M._timers[t] = nil; return fn(...) end)
  M._timers[t] = true
  return t
end
M.STR, M.T, M.uiLang, M.systemLang = STR, T, uiLang, systemLang
M.cfg, M.DEFAULTS = cfg, DEFAULTS
local DATA_DIR, KP, MSG = DATA, "taipea.", "taipea"
local keyText
-- ---------- text helpers: custom words, voice commands, recovery ----------
-- fold: lower-case and drop accents (á→a, ñ→n) so matching ignores capitals and accents
local FOLD = {}
do
  local groups = { a="àáâäãåÀÁÂÄÃÅ", e="èéêëÈÉÊË", i="ìíîïÌÍÎÏ", o="òóôöõÒÓÔÖÕ", u="ùúûüÙÚÛÜ", n="ñÑ", c="çÇ", y="ýÿÝ" }
  for base, list in pairs(groups) do for ch in list:gmatch("[\195][\128-\191]") do FOLD[ch] = base end end
end
local function fold(s) return ((s or ""):gsub("[\195][\128-\191]", function(ch) return FOLD[ch] or ch end):lower()) end
-- byte length of a word character at position k (ASCII letter/digit or a Latin letter like é, ñ), else 0
local function wlen(s, k)
  local b = s:byte(k); if not b then return 0 end
  if (b>=48 and b<=57) or (b>=65 and b<=90) or (b>=97 and b<=122) then return 1 end
  if b==195 then local c = s:byte(k+1); if c and c>=128 and c<=191 and c~=151 and c~=183 then return 2 end end
  return 0
end
-- split text into word and non-word tokens: { {t="Hola", w=true, pos=1}, {t=", ", w=false, pos=5}, ... }
local function tokens(s)
  local out, i, n = {}, 1, #s
  while i <= n do
    local isw, j = wlen(s, i) > 0, i
    while j <= n do
      local l = wlen(s, j)
      if isw then
        if l == 0 and s:byte(j) == 39 and j > i and wlen(s, j+1) > 0 then l = 1 end   -- don't, l'agua
        if l == 0 then break end
      else
        if l > 0 then break end
        l = 1
      end
      j = j + l
    end
    out[#out+1] = { t = s:sub(i, j-1), w = isw, pos = i }
    i = j
  end
  return out
end
local function wordsOf(s) local w = {}; for _,tk in ipairs(tokens(s or "")) do if tk.w then w[#w+1] = fold(tk.t) end end; return w end
-- custom word rules {heard=, replace=} -> sorted matchers (longest first)
local function prepRules(rules)
  local R = {}
  for _,r in ipairs(rules or {}) do
    if type(r)=="table" and type(r.heard)=="string" and type(r.replace)=="string" and r.replace:match("%S") then
      local hw = wordsOf(r.heard)
      if #hw > 0 then R[#R+1] = { w = hw, rep = (r.replace:gsub("^%s+",""):gsub("%s+$","")) } end
    end
  end
  table.sort(R, function(a,b) return #a.w > #b.w end)
  return R
end
-- replace whole words/phrases, ignoring case and accents; words of a phrase may be split by spaces or hyphens
-- returns new text and the number of replacements
local function applyWords(text, rules)
  if type(text) ~= "string" or text == "" then return text, 0 end
  local R = prepRules(rules); if #R == 0 then return text, 0 end
  local tk = tokens(text)
  local out, i, count = {}, 1, 0
  while i <= #tk do
    local last, rep
    if tk[i].w then
      for _,r in ipairs(R) do
        local j, ok = i, true
        for k = 1, #r.w do
          if not (tk[j] and tk[j].w and fold(tk[j].t) == r.w[k]) then ok = false; break end
          if k < #r.w then
            local sep = tk[j+1]
            if not (sep and not sep.w and sep.t:match("^[%s%-]+$")) then ok = false; break end
            j = j + 2
          end
        end
        if ok then last, rep = j, r.rep; break end
      end
    end
    if last then out[#out+1] = rep; count = count + 1; i = last + 1
    else out[#out+1] = tk[i].t; i = i + 1 end
  end
  return table.concat(out), count
end
-- the "replace with" words, once each: used as hints for Whisper and the cleanup model
local function hintWords(rules)
  local seen, list = {}, {}
  for _,r in ipairs(prepRules(rules)) do if not seen[r.rep] then seen[r.rep] = true; list[#list+1] = r.rep end end
  table.sort(list)
  return list
end
-- true when Whisper only gave back the hint words (it does that on silence when it gets a prompt)
local function isPromptEcho(text, rules)
  local w = wordsOf(text); if #w == 0 then return false end
  local H = {}; for _,h in ipairs(hintWords(rules)) do for _,x in ipairs(wordsOf(h)) do H[x] = true end end
  if next(H) == nil then return false end
  for _,x in ipairs(w) do if not H[x] then return false end end
  return true
end
-- how Whisper tends to hear "Taipea"; used only to recognise voice commands
local WAKE_ALIASES = {
  { heard="taipei", replace="taipea" }, { heard="tai pei", replace="taipea" }, { heard="tai pea", replace="taipea" },
  { heard="taipe a", replace="taipea" }, { heard="typea", replace="taipea" }, { heard="type a", replace="taipea" },
  { heard="taypea", replace="taipea" }, { heard="taipeia", replace="taipea" }, { heard="tipea", replace="taipea" },
  { heard="taipá", replace="taipea" }, { heard="tai pa", replace="taipea" },
}
local function cmdRules(rules) local r = {}; for _,x in ipairs(rules or {}) do r[#r+1] = x end; for _,x in ipairs(WAKE_ALIASES) do r[#r+1] = x end; return r end
local function phraseWords(s, rules) return wordsOf((applyWords(s or "", cmdRules(rules)))) end
local function normPhrase(s, rules) return table.concat(phraseWords(s, rules), " ") end
-- edit distance (for "Taipea" heard as "Tapia", "Taipei ha", "Tapi-")
local function lev(a, b)
  local la, lb = #a, #b; if la == 0 then return lb end; if lb == 0 then return la end
  local prev = {}; for j = 0, lb do prev[j] = j end
  for i = 1, la do
    local cur = { [0] = i }
    for j = 1, lb do cur[j] = math.min(prev[j] + 1, cur[j-1] + 1, prev[j-1] + ((a:byte(i) == b:byte(j)) and 0 or 1)) end
    prev = cur
  end
  return prev[lb]
end
-- how Whisper writes the command words after "Taipea" (e.g. "Taipea write" -> "Tapia, right")
local CMD_ALIASES = { write = { "write", "right", "rite", "wright", "writes" }, escribe = { "escribe", "escribes", "escriba", "escribi" },
  listo = { "listo", "lista", "listos" } }
-- do the burst's words w match a phrase's words pw? tol = how far "Taipea" may be misheard
local function matchWords(w, pw, tol)
  if #w == 0 or #pw == 0 then return false end
  if table.concat(w, " ") == table.concat(pw, " ") then return true end
  if pw[1] ~= "taipea" or #pw < 2 or #w > #pw + 2 then return false end
  local s, cmd = table.concat(w), table.concat(pw, "", 2)
  for _,a in ipairs(CMD_ALIASES[cmd] or { cmd }) do
    if #s > #a and s:sub(-#a) == a then
      local pre = s:sub(1, #s - #a)
      if #pre >= 3 and lev(pre, "taipea") <= (#pre >= 4 and tol or 2) then return true end
    end
  end
  return false
end
local function slice(t, a, b) local o = {}; for i = a, b do o[#o+1] = t[i] end; return o end
-- a short burst of speech -> "start", textAfterThePhrase | "stop" | nil
-- stop phrases must be the whole burst ("listo."), start phrases must begin it ("Taipea escribe, hola")
local function classifyBurst(text, startP, stopP, rules)
  local w = phraseWords(text, rules)
  if #w == 0 then return nil end
  for _,p in ipairs(stopP or {}) do if matchWords(w, phraseWords(p, rules), 2) then return "stop" end end
  local tk = tokens((applyWords(text or "", cmdRules(rules))))
  for _,p in ipairs(startP or {}) do
    local pw = phraseWords(p, rules)
    for k = math.min(#w, #pw + 2), 1, -1 do
      if matchWords(slice(w, 1, k), pw, 3) then
        local seen, rest = 0, ""
        for _,t in ipairs(tk) do
          if t.w then seen = seen + 1 end
          if seen == k and t.w then rest = (applyWords(text, cmdRules(rules))):sub(t.pos + #t.t); break end
        end
        return "start", (rest:gsub("^[%s%p]+", ""):gsub("%s+$", ""))
      end
    end
  end
  return nil
end
-- remove a spoken stop phrase from the end of a dictation ("... the report. Listo." -> "... the report.")
local function stripStop(text, stopP, rules)
  if type(text) ~= "string" then return text end
  local W = {}; for _,t in ipairs(tokens(text)) do if t.w then W[#W+1] = { f = phraseWords(t.t, rules)[1] or fold(t.t), pos = t.pos } end end
  local list = {}; for _,p in ipairs(stopP or {}) do local pw = phraseWords(p, rules); if #pw > 0 then list[#list+1] = pw end end
  local fw = {}; for i, x in ipairs(W) do fw[i] = x.f end
  for d = 0, 2 do                       -- allow up to 2 stray words after the phrase ("Done. Thank you.")
    local e = #W - d
    for k = math.min(e, 5), 1, -1 do
      local tail = slice(fw, e - k + 1, e)
      for _,pw in ipairs(list) do
        if matchWords(tail, pw, 2) then
          local cut = text:sub(1, W[e - k + 1].pos - 1)
          repeat local before = cut; cut = cut:gsub("[%s,;:%-]+$", ""):gsub("\226\128[\147\148]$", "") until cut == before
          return cut
        end
      end
    end
  end
  return text
end
-- remove a start phrase the recording may have caught at the very beginning
local function stripStart(text, startP, rules)
  if type(text) ~= "string" then return text end
  local kind, rest = classifyBurst(text, startP, {}, rules)
  if kind == "start" then return rest end
  return text
end
-- length in seconds of a 16 kHz mono 16-bit WAV (from its size)
local function wavSeconds(p)
  local f = io.open(p or "", "rb"); if not f then return 0 end
  local size = f:seek("end"); f:close()
  return math.max(0, (size - 44) / 32000)
end
-- after a crash the recorder may not have written the final sizes: fix the RIFF and data sizes in place
local function fixWavHeader(p)
  local f = io.open(p or "", "r+b"); if not f then return false end
  local size = f:seek("end"); f:seek("set", 0)
  local h = f:read(math.min(size, 4096)) or ""
  if #h < 44 or h:sub(1,4) ~= "RIFF" or h:sub(9,12) ~= "WAVE" then f:close(); return false end
  local pos = 13
  while pos + 7 <= #h do
    local id, len = h:sub(pos, pos+3), string.unpack("<I4", h, pos+4)
    if id == "data" then
      local dlen = size - (pos + 7); dlen = dlen - dlen % 2
      f:seek("set", 4); f:write(string.pack("<I4", size - 8))
      f:seek("set", pos + 3); f:write(string.pack("<I4", dlen))
      f:close(); return true, dlen
    end
    pos = pos + 8 + len + (len % 2)
  end
  f:close(); return false
end
local function shq(s) return "'"..tostring(s):gsub("'", "'\\''").."'" end
-- "Taipea escribe, Taipea write" -> { "Taipea escribe", "Taipea write" }
local function splitPhrases(s)
  local t = {}
  for piece in (s or ""):gmatch("[^,;\n]+") do
    local p = piece:gsub("^%s+", ""):gsub("%s+$", "")
    if p ~= "" then t[#t + 1] = p end
  end
  return t
end
M.fold, M.tokens, M.applyWords, M.hintWords, M.isPromptEcho, M.normPhrase, M.classifyBurst = fold, tokens, applyWords, hintWords, isPromptEcho, normPhrase, classifyBurst
M.stripStop, M.stripStart, M.wavSeconds, M.fixWavHeader, M.splitPhrases = stripStop, stripStart, wavSeconds, fixWavHeader, splitPhrases
-- icons shared by the recording card and the floating buttons (one visual language:
-- green = stop & paste, blue = stop & copy only, red = cancel)
local function svg(body, w) return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="'..(w or 2.4)..'" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'..body..'</svg>' end
local ICON = {
  mic = svg('<rect x="9" y="2.5" width="6" height="11.5" rx="3" fill="currentColor"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0"/><path d="M12 17.5V21.5"/><path d="M8.5 21.5h7"/>'),
  paste = svg('<rect x="5" y="4" width="14" height="17.5" rx="2.2"/><path d="M9 4V2.8h6V4"/><path d="M8.6 13.2l2.4 2.4 4.6-4.9"/>'),
  copy = svg('<rect x="8.5" y="8.5" width="12" height="13" rx="2"/><path d="M15.5 8.5V5a2 2 0 0 0-2-2H5.5a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h3"/>'),
  x = svg('<path d="M6 6l12 12M18 6L6 18"/>', 3.2),
}
M.ICON = ICON
local recTask, state, cancelled, mode = nil, "idle", false, "paste"
local targetApp, recStart, tick = nil, 0, nil
local wav = DATA.."/tmp/rec.wav"
local logf = DATA.."/logs/taipea.log"
local histf = DATA.."/history.json"
local menu = hs.menubar.new()
local overlay, appWin
local settings = hs.settings
local downloads = {}   -- name -> progress string

local function log(s) local f=io.open(logf,"a"); if f then f:write(os.date("%F %T ")..s.."\n"); f:close() end end
-- play sounds in a separate afplay process: hs.sound:play() runs on the main thread and blocks
-- for ~8s when the output device (e.g. external display speakers) is slow/asleep
M._sndTasks = {}
local function sound(n)
  local f = "/System/Library/Sounds/"..n..".aiff"
  if not hs.fs.attributes(f) then return end
  local t; t = hs.task.new("/usr/bin/afplay", function() M._sndTasks[t] = nil end, {f})
  M._sndTasks[t] = true
  t:start()
end

-- ---------- history ----------
local history = {}
do local f=io.open(histf,"r"); if f then local ok,j=pcall(hs.json.decode,f:read("a")); f:close(); if ok and type(j)=="table" then history=j end end end
local function saveHistory() local f=io.open(histf,"w"); if f then f:write(hs.json.encode(history, true)); f:close() end end
local function addHistory(raw, cleaned)
  table.insert(history, 1, { time=os.date("%Y-%m-%d %H:%M:%S"), raw=raw, cleaned=cleaned, style=cleaned and cfg.style or nil })
  while #history > (cfg.historyMax or 500) do table.remove(history) end
  saveHistory()
end
local function finalText(e) return (e.cleaned and e.cleaned ~= "") and e.cleaned or e.raw end

-- ---------- permissions (Accessibility = paste, Microphone = recording; both granted to Hammerspoon) ----------
-- Recent macOS uses the PrivacySecurity extension pane. hs.urlevent.openURL rejects these
-- (they have no "://"), so we launch them with /usr/bin/open. Legacy URLs are the fallback.
local AX_URL  = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
local MIC_URL = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Microphone"
M.AX_URL, M.MIC_URL = AX_URL, MIC_URL
M.PERM_OLD = {
  [AX_URL] = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
  [MIC_URL] = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone",
}
M.axCheck = function() return hs.accessibilityState(false) end   -- tests may replace this
M.permAx = M.axCheck() and true or false
M.micWarn = false
function M.permSync()
  if not M.permAx then
    if not M._axTimer then M._axTimer = hs.timer.doEvery(3, function() M.axOK() end) end
  elseif M._axTimer then M._axTimer:stop(); M._axTimer = nil end
  if M.refreshUI then M.refreshUI() end
end
-- re-reads the permission; reports when it changes and keeps a 3 s recheck running while it is off
function M.axOK()
  local ok = M.axCheck() and true or false
  if ok ~= M.permAx then
    M.permAx = ok; log("permission: Accessibility "..(ok and "ON" or "OFF"))
    if ok then hs.alert.show(T("perm_ax_back"), 4) end
    M.permSync()
  end
  return ok
end
-- an empty recording or no speech: show the message plus a hint about the Microphone permission
function M.micProblem(msg)
  M.micWarn = true; log("permission: empty/no-speech recording, microphone hint shown")
  hs.alert.show(msg..T("perm_mic_hint"), 8)
  if M.refreshUI then M.refreshUI() end
end
function M.osMajor()
  local v = hs.host.operatingSystemVersion
  if type(v) == "function" then v = v() end
  return tonumber(type(v) == "table" and v.major) or 13
end
-- macOS 27 renamed the Accessibility *permission* list (the sidebar item "Accessibility" is VoiceOver)
function M.axPaneNames()
  if M.osMajor() >= 27 then
    return "Device Control and Data Access", "Control de dispositivos y acceso a datos"
  end
  return "Accessibility", "Accesibilidad"
end
function M.openPerm(url)
  local old = M.PERM_OLD[url]
  if M.osMajor() < 13 and old then url = old end
  local function launch(u, fallback)
    log("permission: opening "..u)
    local t = hs.task.new("/usr/bin/open", function(code)
      if tonumber(code) == 0 then return end
      log("permission: open failed ("..tostring(code)..") for "..u)
      if fallback and fallback ~= u then log("permission: trying legacy URL"); launch(fallback, nil) end
    end, { u })
    if not (t and t:start()) then
      log("permission: could not start open for "..u)
      if fallback and fallback ~= u then launch(fallback, nil) end
    end
  end
  launch(url, old)
end
-- preferred microphone (CoreAudio UID in settings; sox needs the current device name). Never changes the Mac default.
function M.listMics()
  local list, ok, devs = {}, pcall(function() return hs.audiodevice.allInputDevices() end)
  if not ok or type(devs) ~= "table" then return list end
  for _, d in ipairs(devs) do
    local uid, name = d:uid(), d:name()
    if type(uid) == "string" and uid ~= "" and type(name) == "string" and name ~= "" then
      list[#list + 1] = { uid = uid, name = name }
    end
  end
  table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
  return list
end
function M.micDefaultName()
  local ok, d = pcall(function() return hs.audiodevice.defaultInputDevice() end)
  if not ok or not d then return "" end
  return d:name() or ""
end
function M.recDevice()
  local uid = cfg.inputDevice
  if type(uid) ~= "string" or uid == "" then return nil end
  local ok, d = pcall(function() return hs.audiodevice.findDeviceByUID(uid) end)
  local name = (ok and d) and d:name() or nil
  if type(name) == "string" and name ~= "" then M._micMissingLogged = nil; return name end
  if not M._micMissingLogged then
    M._micMissingLogged = true
    log("saved input "..uid.." not found, using system default")
  end
  return nil
end
function M.micActive() return M.recDevice() or M.micDefaultName() end
function M.recCmdArgs(args)
  local name = M.recDevice()
  if not name then return cfg.rec, args end
  local out = { "-q", "-t", "coreaudio", name }
  for i, a in ipairs(args or {}) do
    if not (i == 1 and a == "-q") then out[#out + 1] = a end
  end
  return (cfg.rec or ""):gsub("rec$", "sox"), out
end

-- ---------- paste ----------
-- returns false when pasting is blocked (no Accessibility): the text is then left on the clipboard
local function doPaste(text, app)
  if not M.axOK() then
    -- never restore the old clipboard here, or the dictation would be lost
    hs.pasteboard.setContents(text)
    if app then app:activate() end
    log("PASTE BLOCKED: Accessibility off, text left on clipboard ("..#text.." chars)")
    hs.alert.show(T("perm_ax_paste"), 10)
    return false
  end
  local old = hs.pasteboard.readAllData()
  hs.pasteboard.setContents(text)
  if app then app:activate() end
  after(0.25, function()
    hs.eventtap.keyStroke({"cmd"}, "v", 0)
    if cfg.restoreClipboard and old then after(0.6, function() hs.pasteboard.writeAllData(old) end) end
  end)
  return true
end
M.doPaste = doPaste

-- ---------- model catalogs ----------
local WHISPER = {
  { file="ggml-large-v3-turbo.bin", name="Whisper large-v3-turbo", size="1.6 GB", note="Recommended: fast, excellent EN/ES auto-detect", note_es="Recomendado: rápido, detecta muy bien EN/ES" },
  { file="ggml-large-v3-turbo-q5_0.bin", name="Whisper large-v3-turbo (q5)", size="0.57 GB", note="Smaller turbo, slightly less accurate (8 GB Macs)", note_es="Turbo más pequeño, un poco menos preciso (Mac de 8 GB)" },
  { file="ggml-small.bin", name="Whisper small", size="0.49 GB", note="Smallest useful model; weaker on mixed EN/ES", note_es="El más pequeño útil; peor con EN/ES mezclado" },
  { file="ggml-large-v3.bin", name="Whisper large-v3", size="3.1 GB", note="Most accurate, ~2-3x slower", note_es="El más preciso, 2 a 3 veces más lento" },
  { file="ggml-medium.bin", name="Whisper medium", size="1.5 GB", note="Faster, weaker on mixed language", note_es="Más rápido, peor con idiomas mezclados" },
}
local LLMS = {
  { name="gemma4:e4b", size="9.6 GB", note="Recommended: best Formal/Paragraph, keeps EN/ES mix (~1s)", note_es="Recomendado: el mejor en Formal/Párrafos, respeta la mezcla EN/ES (~1 s)" },
  { name="qwen2.5:7b", size="4.7 GB", note="Fallback: fast (~0.6s), sometimes picks a wrong word", note_es="Alternativa: rápido (~0,6 s), a veces elige una palabra equivocada" },
  { name="gemma4:e2b", size="7.2 GB", note="Smaller Gemma 4, for 8 GB Macs", note_es="Gemma 4 más pequeño, para Mac de 8 GB" },
  { name="qwen2.5:14b", size="9.0 GB", note="Keeps EN/ES mix, needs 16 GB+ RAM", note_es="Respeta la mezcla EN/ES, necesita 16 GB+ de RAM" },
  { name="gemma3:12b", size="8.1 GB", note="Keeps EN/ES mix, ~1.5s (slower)", note_es="Respeta la mezcla EN/ES, ~1,5 s (más lento)" },
  { name="llama3.1:8b", size="4.9 GB", note="Fast, English-leaning", note_es="Rápido, tiende al inglés" },
}
local function fileExists(p) local f=io.open(p,"r"); if f then f:close(); return true end; return false end
-- installed Ollama models (cached 30 s; empty if Ollama is missing or not running)
local instCache, instT = nil, 0
local function ollamaInstalled(force)
  if not cfg.ollama then return {} end
  local now = hs.timer.secondsSinceEpoch()
  if instCache and not force and now-instT < 30 then return instCache end
  local out = hs.execute("'"..cfg.ollama.."' list 2>/dev/null") or ""
  local set = {}
  for line in out:gmatch("[^\n]+") do local n = line:match("^(%S+)"); if n and n~="NAME" then set[n]=true; set[(n:gsub(":latest$",""))]=true end end
  instCache, instT = set, now
  return set
end
M.ollamaInstalled = ollamaInstalled
-- the cleanup model to use: the chosen one if installed, else the first installed fallback, else nil (raw text)
function M.activeModel()
  local inst = ollamaInstalled()
  if inst[cfg.ollamaModel] then return cfg.ollamaModel end
  for _,m in ipairs(cfg.ollamaFallbacks or {}) do if inst[m] then return m end end
  return nil
end

-- ---------- screen clamping ----------
-- screen that holds point pt (or the frame's center), else the one it overlaps most, else main
local function screenFor(f, pt)
  local c = pt or {x=f.x+f.w/2, y=f.y+f.h/2}
  local best, bestA = nil, 0
  for _,sc in ipairs(hs.screen.allScreens()) do local r=sc:frame()
    if c.x>=r.x and c.x<r.x+r.w and c.y>=r.y and c.y<r.y+r.h then return sc end
    local ow = math.min(f.x+f.w, r.x+r.w) - math.max(f.x, r.x)
    local oh = math.min(f.y+f.h, r.y+r.h) - math.max(f.y, r.y)
    if ow>0 and oh>0 and ow*oh>bestA then best, bestA = sc, ow*oh end
  end
  return best or hs.screen.mainScreen()
end
-- keep frame fully inside the visible area of its screen (shrinks w/h if larger than the screen)
local function clampFrame(f, scr)
  local r = (scr or screenFor(f)):frame()
  local w, h = math.min(f.w, r.w), math.min(f.h, r.h)
  local x = math.max(r.x, math.min(f.x, r.x+r.w-w))
  local y = math.max(r.y, math.min(f.y, r.y+r.h-h))
  return { x=x, y=y, w=w, h=h }
end
M.clampFrame = clampFrame

-- ---------- overlay ----------
local OW, OH = 460, 250
local function overlayFrame()
  local p = settings.get("taipea.overlayPos")
  local sf = hs.screen.mainScreen():frame()
  local k = (cfg.uiSize=="compact" and 0.75 or 1) * ((M.look and M.look.scale) or 1)
  local w, h = OW*k, OH*k
  if p then return clampFrame({ x=p.x, y=p.y, w=w, h=h }) end
  return { x=sf.x+(sf.w-w)/2, y=sf.y+60, w=w, h=h }
end
local function overlayHTML() return [[
<html lang="]]..uiLang()..[[" class="cl"><head><meta charset="utf-8"><style>
*{box-sizing:border-box}html,body{width:100%;height:100%;margin:0;background:transparent!important}
html{--ovbg:rgba(25,25,30,.95);--ovtx:#fff;--ovmut:#aaa;--ovt:#ccc;--bd:transparent}
body{font:600 22px -apple-system;color:var(--ovtx);overflow:hidden;-webkit-user-select:none}
#panel{width:100%;height:100%;background:var(--ovbg);border-radius:18px;overflow:hidden;cursor:move;border:2px solid var(--bd)}
#panel button{cursor:pointer}
#top{display:flex;align-items:center;gap:14px;padding:18px 22px 6px;cursor:move}
#dot{width:30px;height:30px;border-radius:50%;background:#ff3b30;animation:p 1s infinite}
.busy #dot{background:#ffcc00;animation:s 1s linear infinite;border-radius:6px}
@keyframes p{0%,100%{transform:scale(.7);opacity:.6}50%{transform:scale(1.1);opacity:1}}
@keyframes s{to{transform:rotate(360deg)}}
#t{margin-left:auto;font-variant-numeric:tabular-nums;color:var(--ovt)}
#sub{padding:0 22px;font:400 16px -apple-system;color:var(--ovmut);height:22px}
#b{display:flex;gap:10px;padding:16px;width:100%}
button{flex:1;min-width:0;height:110px;border:0;border-radius:14px;font:700 21px -apple-system;color:#fff;cursor:pointer}
#stop{background:#1e8e3e;flex:1.4}#copy{background:#0a6cd6}#cancel{background:#d42c22}
button{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;line-height:1.15}.ic{display:flex}.ic svg{width:32px;height:32px}
button:hover{filter:brightness(1.2)} .busy button{opacity:.35;pointer-events:none}
.busy #cancel{opacity:1;pointer-events:auto}
html.hc.cl #panel{background:#000;border:4px solid #fff}html.hc button{border:4px solid #fff}html.hc:not(.cl) #panel{border:4px solid var(--ovtx)}
html.hc #stop{background:#006b1f}html.hc #copy{background:#003f8a}html.hc #cancel{background:#a00000}html.hc.cl #sub,html.hc.cl #t{color:#fff}
html.rm *{animation:none!important;transition:none!important}
@media (prefers-reduced-motion: reduce){*{animation:none!important}}
</style></head><body><div id=panel>
<div id=top><div id=dot></div><div id=st>]]..T("ov_listening")..[[</div><div id=t>0:00</div></div>
<div id=sub></div>
<div id=b><button id=stop onclick="s('stop')"><span class=ic>]]..ICON.paste..[[</span><span>]]..T("ov_stop")..[[</span></button><button id=copy onclick="s('copy')"><span class=ic>]]..ICON.copy..[[</span><span>]]..T("ov_copy")..[[</span></button><button id=cancel onclick="s('cancel')"><span class=ic>]]..ICON.x..[[</span><span>]]..T("ov_cancel")..[[</span></button></div></div>
<script>document.documentElement.style.zoom=window.__tpZoom||1;function s(a){webkit.messageHandlers.taipea.postMessage(a)}
document.getElementById('panel').addEventListener('mousedown',e=>{if(e.button===0&&!e.target.closest('button')){e.preventDefault();s({cmd:'dragOverlay'})}});
function upd(st,t,sub,busy){document.getElementById('st').textContent=st;document.getElementById('t').textContent=t;
document.getElementById('sub').textContent=sub;document.body.classList.toggle('busy',!!busy)}
function setLook(hc,rm){document.documentElement.classList.toggle('hc',!!hc);document.documentElement.classList.toggle('rm',!!rm)}
function setPal(p){var r=document.documentElement;['ovbg','ovtx','ovmut','ovt'].forEach(function(k){r.style.setProperty('--'+k,p[k])});r.style.setProperty('--bd',p.cl?'transparent':p.bd2);r.classList.toggle('cl',!!p.cl)}</script></body></html>]] end

-- ---------- hotkeys ----------
local hk = {}
-- A shortcut is { mods = {...}, key = "space" } or modifier-only { mods = {"ctrl","cmd"}, key = "" }.
-- Modifier-only ones act on press (see "Modifier-only shortcuts" below). Modifiers are listed in
-- Apple's order: Control, Option, Shift, Command. One local table keeps the main chunk under Lua's
-- 200-local limit.
local KD = { ORDER = { "ctrl", "alt", "shift", "cmd" }, SYM = { ctrl = "⌃", alt = "⌥", shift = "⇧", cmd = "⌘" } }
function KD.sort(list) local set = {}; for _, m in ipairs(list or {}) do set[m] = true end; local o = {}; for _, m in ipairs(KD.ORDER) do if set[m] then o[#o+1] = m end end; return o end
-- "ctrl+cmd" / "ctrl+alt+space" (the editable form)
local function keyStr(k) k = k or {}; local m = {}; for _, x in ipairs(KD.sort(k.mods)) do m[#m+1] = x end; if k.key and k.key ~= "" then m[#m+1] = tostring(k.key) end; return table.concat(m, "+") end
function KD.name(key)
  key = tostring(key or "")
  if key == "space" then return T("k_space") elseif key == "mic" then return "🎙" end
  if key == "escape" then return "Esc" end
  if key:match("^f%d+$") or #key == 1 then return key:upper() end
  return key:sub(1,1):upper()..key:sub(2)
end
-- "Control + Command" / "Control + Option + Space" (shown to people)
local function keyLabel(k)
  if type(k) ~= "table" then return "" end
  local m = {}
  for _, x in ipairs(KD.sort(k.mods)) do m[#m+1] = T("k_"..x) end
  if k.key and k.key ~= "" then m[#m+1] = KD.name(k.key) end
  return table.concat(m, " + ")
end
-- "⌃ ⌘" / "⌃ ⌥ Space" (big symbols in Settings)
function M.keySym(k)
  if type(k) ~= "table" then return "" end
  local m = {}
  for _, x in ipairs(KD.sort(k.mods)) do m[#m+1] = KD.SYM[x] end
  if k.key and k.key ~= "" then m[#m+1] = KD.name(k.key) end
  return table.concat(m, " ")
end
M.keyStr, M.keyLabel, M.sortMods = keyStr, keyLabel, KD.sort
-- typed form: "ctrl+alt+space", or modifiers only ("ctrl+cmd")
local function parseKey(s)
  local parts = {}; for p in (s or ""):lower():gsub("%s",""):gmatch("[^+]+") do table.insert(parts,p) end
  if #parts == 0 then return nil end
  local map={ctrl="ctrl",control="ctrl",alt="alt",option="alt",opt="alt",cmd="cmd",command="cmd",shift="shift"}
  local key = ""
  if not map[parts[#parts]] then key = table.remove(parts) end
  local mods = {}
  for _,p in ipairs(parts) do if not map[p] then return nil end; table.insert(mods,map[p]) end
  if key ~= "" and not hs.keycodes.map[key] then return nil end
  return { mods=KD.sort(mods), key=key }
end
M.parseKey = parseKey
-- every shortcut that can be changed (Settings › Shortcuts, config.lua or settings.json)
M.KEY_ACTIONS = { "toggleKey", "toggleKey2", "modeKey", "historyKey", "pasteLastKey", "fabHideKey" }
KD.BOUND = { toggleKey = "toggle", toggleKey2 = "toggle2", modeKey = "mode", historyKey = "history", pasteLastKey = "pasteLast", fabHideKey = "fabHide" }
-- macOS shortcuts Taipea refuses to take over
KD.RES = { ["cmd+q"]=1, ["cmd+w"]=1, ["cmd+c"]=1, ["cmd+v"]=1, ["cmd+x"]=1, ["cmd+z"]=1, ["cmd+a"]=1, ["cmd+tab"]=1, ["cmd+space"]=1,
  ["ctrl+cmd+q"]=1, ["alt+cmd+escape"]=1, ["ctrl+cmd+space"]=1, ["ctrl+cmd+f"]=1, ["shift+cmd+3"]=1, ["shift+cmd+4"]=1, ["shift+cmd+5"]=1 }
-- nil = OK to use for `target`, otherwise the reason it can't be used
function M.keyProblem(target, k)
  if type(k) ~= "table" then return T("k_none") end
  local mods, key = KD.sort(k.mods), tostring(k.key or "")
  if key == "mic" then return T("k_mic") end
  if key:sub(1,1) == "?" then return T("k_unknown") end
  if key == "" then
    if #mods < 2 then return T("k_need2") end
  else
    local fkey = key:match("^f%d+$") ~= nil
    if not fkey and (#mods == 0 or (#mods == 1 and mods[1] == "shift")) then return T("k_single") end
  end
  local s = keyStr({ mods = mods, key = key })
  if KD.RES[s] then return T("k_system") end
  for _, a in ipairs(M.KEY_ACTIONS) do if a ~= target and type(cfg[a]) == "table" and keyStr(cfg[a]) == s then return T("k_dup", T("k_lbl_"..a)) end end
  return nil
end
-- one value per shortcut for the window, e.g. M.keysMap(keyLabel) or M.keysMap(keyLabel, DEFAULTS)
function M.keysMap(fn, src) local o = {}; for _, a in ipairs(M.KEY_ACTIONS) do o[a] = fn((src or cfg)[a]) end; return o end
local bindAll
-- ---------- app window push ----------
local pushState
local function onMsg(m)
  local a = m.body
  if a=="stop" then M.stop(cfg.defaultAction=="copy" and "copy" or "paste") elseif a=="copy" then M.stop("copy") elseif a=="cancel" then M.cancel()
  elseif type(a)=="table" and a.cmd=="dragStart" then M.startAppDrag()
  elseif type(a)=="table" and a.cmd=="dragOverlay" then M.startOverlayDrag()
  elseif type(a)=="table" and a.cmd=="fabDown" then M.startFabDrag()
  elseif type(a)=="table" and a.cmd=="fabReady" then M.fabUpdate()
  elseif type(a)=="table" and a.cmd=="satDown" then M.satPress(a.which)
  elseif type(a)=="table" then M.handle(a) end
end
-- window drag: poll mouse until left button released (works with head mice that send no drag events)
local function startDrag(w, key, onEnd)
  if not w then return end
  if M._dragEnd then M._dragEnd() end
  local p0, f0 = hs.mouse.absolutePosition(), w:frame()
  local n, timer, upTap = 0, nil, nil
  local function finishDrag()
    if timer then timer:stop(); timer = nil end
    if upTap then upTap:stop(); upTap = nil end
    M._appDragTimer, M._dragEnd = nil, nil
    local nf = clampFrame(w:frame()); w:frame(nf); settings.set(key, {x=nf.x, y=nf.y})
    if onEnd then local p = hs.mouse.absolutePosition(); onEnd(math.sqrt((p.x-p0.x)^2 + (p.y-p0.y)^2), f0) end
  end
  M._dragEnd = finishDrag
  -- end on the real mouse-up event too: checkMouseButtons() reads hardware state and can miss
  -- releases sent by assistive/head-mouse software, which left the window following the pointer
  upTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseUp}, function() after(0, finishDrag); return false end)
  upTap:start()
  timer = hs.timer.doEvery(0.016, function()
    local p = hs.mouse.absolutePosition()
    -- clamp to the screen under the pointer so the header/panel never leaves the visible area
    w:frame(clampFrame({x=f0.x+p.x-p0.x, y=f0.y+p.y-p0.y, w=f0.w, h=f0.h}, screenFor(f0, p)))
    n = n + 1
    if (n > 3 and not hs.eventtap.checkMouseButtons()[1]) or n > 1875 then finishDrag() end
  end)
  M._appDragTimer = timer
end
function M.startAppDrag() startDrag(M.appWinRef and M.appWinRef(), "taipea.appPos") end
function M.startOverlayDrag() startDrag(overlay, "taipea.overlayPos") end
function M.overlayRef() return overlay end
local uc = hs.webview.usercontent.new("taipea"):setCallback(onMsg)

local function showOverlay()
  -- floating button on: its satellites replace the card (unless "Show the recording card too" is on)
  if cfg.floatButton then if not M.cardWanted() then return end elseif cfg.showOverlay == false then return end
  if not overlay then
    overlay = hs.webview.new(overlayFrame(), {}, uc)
      :windowStyle({"borderless","nonactivating"}):level(hs.drawing.windowLevels.floating)
      :allowTextEntry(false):transparent(true):shadow(true)
      :behavior(hs.drawing.windowBehaviors.canJoinAllSpaces + hs.drawing.windowBehaviors.stationary)
      :html(overlayHTML())
  end
  overlay:frame(overlayFrame()):show()
  local z = (cfg.uiSize=="compact" and 0.75 or 1) * ((M.look and M.look.scale) or 1)
  overlay:evaluateJavaScript("window.__tpZoom="..z..";document.documentElement.style.zoom=window.__tpZoom;setLook("..tostring(M.look and M.look.hc or false)..","..tostring(M.look and M.look.rm or false)..")")
  if M.overlayPal then M.overlayPal() end
end
local function hideOverlay() if overlay then overlay:hide() end end
M._showOverlay, M._hideOverlay = showOverlay, hideOverlay
local function setOverlay(st, sub, busy)
  if not overlay then return end
  local e = math.floor(hs.timer.secondsSinceEpoch()-recStart)
  overlay:evaluateJavaScript(string.format("upd(%q,%q,%q,%s)", st, string.format("%d:%02d",e//60,e%60), sub or "", busy and "true" or "false"))
end

-- ---------- menu ----------
local refresh
local transcribe
keyText = function(k) return keyLabel(k) end
-- ---------- look: text size, high contrast, reduce motion, reduce transparency ----------
local function macPref(key)
  local out = hs.execute("/usr/bin/defaults read com.apple.universalaccess "..key.." 2>/dev/null") or ""
  return out:match("^%s*1") ~= nil
end
local look = { scale = 1, hc = false, rm = false, rt = false, macHC = false, macRM = false, macRT = false }
local function updateLook()
  look.macHC, look.macRM, look.macRT = macPref("increaseContrast"), macPref("reduceMotion"), macPref("reduceTransparency")
  look.hc = cfg.contrast == "on" or (cfg.contrast ~= "off" and look.macHC)
  look.rm, look.rt = look.macRM, look.macRT
  look.scale = ({ normal = 1, large = 1.2, xlarge = 1.4 })[cfg.textSize] or 1
end
updateLook()
M.look, M.updateLook = look, updateLook

-- ---------- recovery: each recording's audio and progress are kept until it is pasted ----------
local sessf = DATA_DIR.."/tmp/session.json"
local recoverWav = DATA_DIR.."/tmp/recover.wav"
local function saveSession(t) local f = io.open(sessf, "w"); if f then f:write(hs.json.encode(t)); f:close() end end
local function readSession()
  local f = io.open(sessf, "r"); if not f then return nil end
  local ok, j = pcall(hs.json.decode, f:read("a")); f:close()
  return ok and type(j) == "table" and j or nil
end
local function clearSession() os.remove(sessf) end
M.saveSession, M.readSession, M.clearSession = saveSession, readSession, clearSession
local function fmtSecs(s) s = math.floor((s or 0) + 0.5); return string.format("%d:%02d", s // 60, s % 60) end
-- at load: an unfinished session means the last dictation never reached the paste step
function M.checkRecovery()
  local s = readSession(); M.recoverable = nil
  if not s then return nil end
  if s.phase == "recording" and s.wav then
    -- stop a recorder the previous load left running, so the file is complete
    hs.execute("/usr/bin/pkill -f "..shq("16000 -b 16 "..s.wav))
  end
  if s.wav and s.wav ~= recoverWav and fileExists(s.wav) then
    os.remove(recoverWav); if os.rename(s.wav, recoverWav) then s.wav = recoverWav end
  end
  local secs = s.wav and fileExists(s.wav) and wavSeconds(s.wav) or 0
  if (type(s.raw) == "string" and s.raw:match("%S")) or secs >= 1 then
    s.secs = secs; saveSession(s); M.recoverable = s
  else clearSession() end
  return M.recoverable
end
function M.discardRecovery() M.recoverable = nil; clearSession(); os.remove(recoverWav); hs.alert.show(T("recover_discarded")); refresh() end

-- Move the current recording out of the live session folder so liveEndSession/liveSweep
-- cannot delete it before checkRecovery can offer it back.
function M.keepAudioForRecovery(file)
  local keep = file or M._sessWav or wav
  if keep and keep ~= recoverWav and fileExists(keep) then
    os.remove(recoverWav)
    if os.rename(keep, recoverWav) then keep = recoverWav end
  end
  if keep and fileExists(keep) then
    saveSession({ phase = "recording", wav = keep, started = os.date("%F %T") })
  end
  return keep
end

-- True when this callback belongs to a job that was cancelled or replaced.
-- start, cancel, recover and watchdogReset bump M.LIVE.gen.
function M.jobStale(gen)
  return gen == nil or not M.LIVE or M.LIVE.gen ~= gen
end

-- For in-flight pipeline callbacks: drop a replaced job without touching the new one;
-- if this job was cancelled, return to idle. Returns true when the caller should stop.
function M.abortIfDone(gen)
  if M.jobStale(gen) then return true end
  if cancelled then
    state = "idle"
    if tick then tick:stop() end
    hideOverlay()
    clearSession()
    M._recovering = false
    if refresh then refresh() end
    return true
  end
  return false
end

function M.clearVoiceFlags()
  M._voiceStopped, M._voicePrefix, M._voiceSession = false, nil, false
end

-- Starting… / percent stay busy; Failed / Falló can be tried again without a reload.
function M.dlBusy(status)
  if status == nil or status == false then return false end
  local s = tostring(status)
  return not s:match("^Failed") and not s:match("^Falló")
end

-- ---------- paste last dictation again ----------
function M.pasteLast(app)
  local e = history[1]
  if not e then hs.alert.show(T("nothing_paste")); return end
  app = app or hs.application.frontmostApplication()
  if not app or app:bundleID() == "org.hammerspoon.Hammerspoon" then app = M.lastApp end
  if doPaste(finalText(e), app) ~= false then log("PASTED AGAIN ("..#finalText(e).." chars)") end
end

-- remember the last app you used (not Hammerspoon), so text from the floating button goes back there
M._appWatch = hs.application.watcher.new(function(_, ev, app)
  if ev == hs.application.watcher.activated and app and app:bundleID() ~= "org.hammerspoon.Hammerspoon" then M.lastApp = app end
end)
M._appWatch:start()

-- ---------- voice start / stop ----------
-- A tiny recorder waits for sound (sox "silence" effect, almost no CPU), keeps one short burst
-- (up to voiceMaxBurst seconds), and Whisper transcribes only that burst on this Mac. Bursts that
-- are longer (normal talking) are skipped without transcribing. Audio files are deleted right away.
local VL = { task = nil, wtask = nil, n = 0, pending = nil, sleeping = false, quick = 0 }
M.VL = VL
-- a listener left over from before a reload would keep the microphone open: stop it
hs.execute("/usr/bin/pkill -f "..shq("16000 -b 16 "..DATA_DIR.."/tmp/voice"))
local function vlModel()
  if cfg.voiceModel then return cfg.voiceModel:sub(1,1) == "/" and cfg.voiceModel or (DATA_DIR.."/models/"..cfg.voiceModel) end
  local dirs = { DATA_DIR.."/models" }
  local md = modelPath():match("^(.*)/[^/]+$"); if md and md ~= dirs[1] then dirs[#dirs+1] = md end
  for _,d in ipairs(dirs) do
    for _,f in ipairs({ "ggml-small-q5_1.bin", "ggml-small-q8_0.bin", "ggml-small.bin" }) do if fileExists(d.."/"..f) then return d.."/"..f end end
  end
  return modelPath()
end
M.vlModel = vlModel
function M.voiceActive() return (cfg.voiceControl and not VL.sleeping) and true or false end
local function vlWanted() return M.voiceActive() and state ~= "busy" and cfg.rec ~= nil and cfg.whisper ~= nil and not M._simInput end
local vlBurst
local function vlSync()
  if vlWanted() then if not VL.task and not VL.waiting then vlBurst() end
  elseif VL.task then local t = VL.task; VL.task = nil; t:terminate() end
end
M.vlSync = vlSync
function M.restartVoiceListener()
  if VL.task then local t = VL.task; VL.task = nil; t:terminate() end
  vlSync()
end
vlBurst = function()
  VL.n = VL.n % 3 + 1
  local f = DATA_DIR.."/tmp/voice"..VL.n..".wav"; os.remove(f)
  local thr, cap = cfg.voiceThreshold or "2%", cfg.voiceMaxBurst or 4
  local t0 = hs.timer.secondsSinceEpoch()
  local args = { "-q", "-c", "1", "-r", "16000", "-b", "16", f, "silence", "1", "0.15", thr, "1", "0.7", thr, "trim", "0", tostring(cap) }
  local recCmd; recCmd, args = M.recCmdArgs(args)
  local t; t = hs.task.new(recCmd, function()
    if VL.task ~= t then os.remove(f); return end   -- stopped on purpose
    VL.task = nil
    local secs = wavSeconds(f)
    if secs >= 0.3 and secs < cap - 0.05 then M.voiceCheck(f) else os.remove(f) end
    -- if the recorder keeps failing (no microphone permission, device gone), back off instead of spinning
    if hs.timer.secondsSinceEpoch() - t0 < 0.5 then VL.quick = VL.quick + 1 else VL.quick = 0 end
    if VL.quick >= 5 then
      VL.waiting = true; log("voice: recorder keeps stopping, retrying in 30 s")
      after(30, function() VL.waiting = false; VL.quick = 0; vlSync() end)
    else after(0.05, vlSync) end
  end, args)
  VL.task = t
  if not t:start() then VL.task = nil end
end
function M.voiceCheck(f)
  if VL.wtask then if VL.pending then os.remove(VL.pending) end; VL.pending = f; return end
  local t0 = hs.timer.secondsSinceEpoch()
  -- no --prompt here: with a prompt Whisper "hears" the prompt in plain noise
  VL.wtask = hs.task.new(cfg.whisper, function(code, out)
    VL.wtask = nil; if not M._keepVoiceFiles then os.remove(f) end
    out = (out or ""):gsub("%[BLANK_AUDIO%]", ""):gsub("%b[]", ""):gsub("%b()", ""):gsub("\n", " ")
    if cfg.voiceDebug then log(string.format("voice heard (%.1fs): %s", hs.timer.secondsSinceEpoch() - t0, out)) end
    if code == 0 then M.voiceHeard(out) end
    local p = VL.pending; VL.pending = nil
    if p then M.voiceCheck(p) end
  end, { "-m", vlModel(), "-l", cfg.language or "auto", "-nt", "-np", "-bs", "1", "-bo", "1", "-nf", "-f", f })
  if not VL.wtask:start() then VL.wtask = nil end
end
function M.voiceHeard(text)
  local kind, rest = classifyBurst(text, cfg.startPhrases, cfg.stopPhrases, cfg.customWords)
  if kind == "start" and state == "idle" then
    log("voice: start phrase heard"); M._voicePrefix = (rest ~= "" and rest or nil); M._voiceSession = true; M.start()
  elseif kind == "stop" and state == "rec" then
    log("voice: stop phrase heard"); M._voiceStopped = true; M.stop(cfg.defaultAction == "copy" and "copy" or "paste")
  end
  return kind
end
-- pause while the screen is locked or the Mac sleeps
local function screenLocked() local ok, p = pcall(hs.caffeinate.sessionProperties); return (ok and type(p) == "table" and p.CGSSessionScreenIsLocked) and true or false end
M._sleepWatch = hs.caffeinate.watcher.new(function(ev)
  local W = hs.caffeinate.watcher
  if ev == W.systemWillSleep or ev == W.screensDidSleep or ev == W.screensDidLock then VL.sleeping = true
  elseif ev == W.screensDidUnlock then VL.sleeping = false
  elseif ev == W.systemDidWake or ev == W.screensDidWake then VL.sleeping = screenLocked() end
  vlSync(); if refresh then refresh() end
end)
M._sleepWatch:start()
-- text of a finished recording: custom words, voice phrases removed
local function polishRaw(out)
  out = applyWords(out or "", cfg.customWords)
  if isPromptEcho(out, cfg.customWords) then out = "" end
  if M._voiceStopped then out = stripStop(out, cfg.stopPhrases, cfg.customWords) end
  if M._voiceSession or M._voicePrefix then out = stripStart(out, cfg.startPhrases, cfg.customWords) end
  if M._voicePrefix then out = M._voicePrefix.." "..out end
  M.clearVoiceFlags()
  return out
end
M.polishRaw = polishRaw
-- Whisper --prompt with the custom words, so it spells them right
local function whisperHint() local h = hintWords(cfg.customWords); if #h == 0 then return nil end; return table.concat(h, ", ").."." end
-- line for the cleanup model
local function wordsRule()
  local h = hintWords(cfg.customWords); if #h == 0 then return "" end
  return "Write these words exactly as given and never change, translate or respell them: "..table.concat(h, ", ")..". "
end
M.whisperHint, M.wordsRule = whisperHint, wordsRule

-- ---------- floating button ----------
-- Idle: mic on the brand colour. Recording: green "stop & paste" (pulses gently) with two satellites,
-- blue "stop & copy only" and red "cancel", on whichever side has room. Working: spinner.
local fab, sats, satLabel, satTimer = nil, {}, nil, nil
-- FABG.PAD: transparent room around the circles so their drop shadow (0 3px 12px) and the recording
-- pulse fade out inside the window instead of being cut at its edge. Saved positions and the
-- satellite layout still use the old frame (circle + 4 px), so FABG.EXTRA converts between the two.
-- (one table, not five locals: the main chunk is near Lua's 200-local limit)
local FABG = { PAD = 18 }; FABG.EXTRA = FABG.PAD - 4
local function fabSize() return math.floor(96 * (look.scale or 1) + 0.5) + 2 * FABG.PAD end
function FABG.shrink(f, d) return { x = f.x + d, y = f.y + d, w = f.w - 2 * d, h = f.h - 2 * d } end
function FABG.grow(f, d) return { x = f.x - d, y = f.y - d, w = f.w + 2 * d, h = f.h + 2 * d } end
local function satSizes() local s = look.scale or 1; return math.max(60, math.floor(64 * s + 0.5)), math.max(80, math.floor(84 * s + 0.5)) end
function FABG.satWin0() local _, big = satSizes(); return big + 8 end
local function satWin() return FABG.satWin0() + 2 * FABG.EXTRA end
local function fabFrame()
  local s = fabSize(); local p = settings.get(KP.."fabPos"); local sf = hs.screen.mainScreen():frame()
  if type(p) == "table" and p.x then return clampFrame({ x = p.x - FABG.EXTRA, y = p.y - FABG.EXTRA, w = s, h = s }) end
  return { x = sf.x + sf.w - s - 30 + FABG.EXTRA, y = sf.y + math.floor(sf.h * 0.55) - FABG.EXTRA, w = s, h = s }
end
-- where the two satellites go: around the button on the first side that fits on the screen
-- (left, right, above, below, then the diagonals for corners)
local function satLayout(mf, sw, sr)
  local cx, cy = mf.x + mf.w / 2, mf.y + mf.h / 2
  local d, o = mf.w / 2 + sw / 2 + 2, sw / 2 + 6
  local R, spread = math.sqrt(d * d + o * o), math.atan(o, d)
  local dirs = { { 180, spread }, { 0, spread }, { 270, spread }, { 90, spread },
    { 225, 0.63 }, { 135, 0.63 }, { 315, 0.63 }, { 45, 0.63 } }
  local function frames(deg, sp)
    local t = math.rad(deg); local fr = {}
    for i, a in ipairs({ t - sp, t + sp }) do
      fr[i] = { x = math.floor(cx + R * math.cos(a) - sw / 2 + 0.5), y = math.floor(cy + R * math.sin(a) - sw / 2 + 0.5), w = sw, h = sw }
    end
    if deg == 180 or deg == 0 then if fr[1].y > fr[2].y then fr[1], fr[2] = fr[2], fr[1] end
    elseif fr[1].x > fr[2].x then fr[1], fr[2] = fr[2], fr[1] end
    return fr
  end
  local function sideOf(deg) local c, s = math.cos(math.rad(deg)), math.sin(math.rad(deg))
    if c < -0.1 then return "left" elseif c > 0.1 then return "right" elseif s < 0 then return "up" else return "down" end end
  local function fits(f) return f.x >= sr.x and f.y >= sr.y and f.x + f.w <= sr.x + sr.w and f.y + f.h <= sr.y + sr.h end
  for _, dd in ipairs(dirs) do local fr = frames(dd[1], dd[2]); if fits(fr[1]) and fits(fr[2]) then return sideOf(dd[1]), fr end end
  local deg = (cx - sr.x > sr.x + sr.w - cx) and 180 or 0
  local fr = frames(deg, spread)
  for _, f in ipairs(fr) do
    f.x = math.max(sr.x, math.min(f.x, sr.x + sr.w - f.w)); f.y = math.max(sr.y, math.min(f.y, sr.y + sr.h - f.h))
  end
  return sideOf(deg), fr
end
M.satLayout = satLayout
-- ---------- colour sets (Settings › Colors) ----------
-- Each set has 3 colours: bg = background, mic = microphone and text, acc = accent (buttons, rings).
-- They theme the whole app: the window, the recording card and the floating button. The action
-- colours never change: green = stop and paste, blue = stop and copy only, red = cancel, and
-- warnings stay orange / red.
local FAB_THEMES = {
  { id = "classic",  bg = "#0A6CD6", mic = "#FFFFFF", acc = "#FFFFFF" },
  { id = "studio",   bg = "#1A1A1A", mic = "#F2EFEA", acc = "#E8503A", outline = true },
  { id = "midnight", bg = "#14213D", mic = "#FFFFFF", acc = "#22D3EE" },
  { id = "forest",   bg = "#1F3D2B", mic = "#F3EBD3", acc = "#A3E635" },
  { id = "sunset",   bg = "#3B1F4A", mic = "#FFFFFF", acc = "#FB923C" },
  { id = "contrast", bg = "#000000", mic = "#FFE600", acc = "#FFE600" },
  { id = "paper",    bg = "#F5F2EA", mic = "#111111", acc = "#E8503A" },
  { id = "custom" },
}
local function isHex(c) return type(c) == "string" and c:match("^#%x%x%x%x%x%x$") ~= nil end
-- "#e8503a", "E8503A", "#0f0" -> "#E8503A" / "#00FF00"; anything else -> nil
local function normHex(v)
  if type(v) ~= "string" then return nil end
  local c = v:gsub("^%s+", ""):gsub("%s+$", ""):upper()
  if c ~= "" and c:sub(1, 1) ~= "#" then c = "#"..c end
  if c:match("^#%x%x%x$") then c = "#"..c:sub(2,2):rep(2)..c:sub(3,3):rep(2)..c:sub(4,4):rep(2) end
  return isHex(c) and c or nil
end
-- the set in use; an unknown name or a Custom set with an invalid colour falls back to Classic Blue
local function fabTheme()
  local id = cfg.floatingTheme
  for _, t in ipairs(FAB_THEMES) do
    if t.id == id then
      if id ~= "custom" then return t end
      if isHex(cfg.customBg) and isHex(cfg.customMic) and isHex(cfg.customAccent) then
        return { id = "custom", bg = cfg.customBg, mic = cfg.customMic, acc = cfg.customAccent }
      end
    end
  end
  return FAB_THEMES[1]
end
M.FAB_THEMES, M.fabTheme, M.isHex, M.normHex, M.FABG = FAB_THEMES, fabTheme, isHex, normHex, FABG
-- A full palette from the 3 colours. Classic Blue keeps the original Taipea colours. Other sets
-- derive the surfaces from the background, the text from the mic colour and the buttons / active
-- tab / selected choices from the accent, then fix any text below 4.5:1 contrast (WCAG AA) by
-- moving it toward black or white (and, if that is not enough, the background too).
local function hexRGB(h) return tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16) end
local function toHex(r,g,b) local function c(x) return math.max(0, math.min(255, math.floor(x + 0.5))) end; return string.format("#%02X%02X%02X", c(r), c(g), c(b)) end
local function mixC(a, b, t) local r1,g1,b1 = hexRGB(a); local r2,g2,b2 = hexRGB(b); return toHex(r1+(r2-r1)*t, g1+(g2-g1)*t, b1+(b2-b1)*t) end
local function lumC(h) local r,g,b = hexRGB(h)
  local function ch(v) v = v / 255; return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
  return 0.2126*ch(r) + 0.7152*ch(g) + 0.0722*ch(b) end
-- tinted glass fill for the floating mic (macOS-style); solid when High Contrast or Reduce Transparency is on
function FABG.rgba(hex, a)
  local r, g, b = hexRGB(hex)
  return string.format("rgba(%d,%d,%d,%.2f)", r, g, b, a)
end
function FABG.glassBg(hex, solid)
  if solid or type(hex) ~= "string" or not hex:match("^#%x%x%x%x%x%x$") then return hex end
  return FABG.rgba(hex, lumC(hex) > 0.35 and 0.70 or 0.55)
end
local function contrastC(a, b) local x, y = lumC(a), lumC(b); if x < y then x, y = y, x end; return (x + 0.05) / (y + 0.05) end
local function worstC(c, bgs) local w = 99; for _, b in ipairs(bgs) do w = math.min(w, contrastC(c, b)) end; return w end
-- the colour closest to c that reaches `min` contrast against every background in bgs
local function ensureC(c, bgs, min)
  if worstC(c, bgs) >= min then return c end
  local best, bestT, bestW, bestW2 = nil, 99, 0, nil
  for _, target in ipairs({ "#FFFFFF", "#000000" }) do
    for i = 1, 40 do local t = i / 40; local cc = mixC(c, target, t)
      if worstC(cc, bgs) >= min then if t < bestT then best, bestT = cc, t end; break end end
    local w = worstC(target, bgs); if w > bestW then bestW, bestW2 = w, target end
  end
  return best or bestW2
end
-- readable text for a filled button; if no text colour reaches 4.5:1, the fill itself is adjusted
local function onFill(fill, prefs)
  for _, c in ipairs(prefs) do if contrastC(c, fill) >= 4.5 then return fill, c end end
  local tx = contrastC("#FFFFFF", fill) >= contrastC("#000000", fill) and "#FFFFFF" or "#000000"
  return ensureC(fill, { tx }, 4.5), tx
end
local CLASSIC_PAL = { panel="#1C1C20", bar="#2A2A30", tabs="#111111", tab="#333333", tabtx="#FFFFFF", btn="#3A3A40", btntx="#FFFFFF",
  acc="#0A6CD6", acctx="#FFFFFF", input="#2A2A30", inbd="#555555", card="#2C2C32", inner="#24242A", tx="#EEEEEE", mut="#999999", mut2="#AAAAAA",
  bd="#3A3A40", bd2="#444444", ring="#FFFFFF", focus="#0A84FF", warn="#FFCC00", sb="#55555A", ovbg="rgba(25,25,30,.95)", ovtx="#FFFFFF", ovmut="#AAAAAA", ovt="#CCCCCC" }
local function surfaces(p) return { p.panel, p.bar, p.tabs, p.card, p.inner, p.tab, p.btn, p.input } end
local function buildPalette1(bg, fg, ac)
  local light = lumC(bg) > 0.35
  local p = { cl = false, light = light, panel = bg }
  if light then
    p.tabs = mixC(bg, "#000000", 0.06); p.bar = mixC(bg, fg, 0.06); p.card = mixC(bg, "#FFFFFF", 0.6); p.inner = mixC(bg, fg, 0.04)
    p.tab = mixC(bg, fg, 0.10); p.btn = mixC(bg, fg, 0.10); p.input = mixC(bg, "#FFFFFF", 0.85); p.inbd = mixC(bg, fg, 0.35)
    p.bd = mixC(bg, fg, 0.15); p.bd2 = mixC(bg, fg, 0.18); p.sb = mixC(bg, fg, 0.30)
  else
    p.tabs = mixC(bg, "#000000", 0.35); p.bar = mixC(bg, fg, 0.07); p.card = mixC(bg, fg, 0.07); p.inner = mixC(bg, fg, 0.035)
    p.tab = mixC(bg, fg, 0.12); p.btn = mixC(bg, fg, 0.15); p.input = mixC(bg, fg, 0.06); p.inbd = mixC(bg, fg, 0.30)
    p.bd = mixC(bg, fg, 0.15); p.bd2 = mixC(bg, fg, 0.20); p.sb = mixC(bg, fg, 0.30)
  end
  p.tx = ensureC(fg, surfaces(p), 4.5); p.tabtx, p.btntx, p.ovtx = p.tx, p.tx, p.tx
  p.mut = ensureC(mixC(p.tx, p.card, 0.3), { p.panel, p.bar, p.card, p.inner }, 4.5); p.mut2, p.ovmut, p.ovt = p.mut, p.mut, p.mut
  p.acc, p.acctx = onFill(ac, { p.tx, "#FFFFFF", "#000000" })
  p.ring = p.tx
  p.focus = contrastC(p.acc, p.panel) >= 3 and p.acc or p.tx
  p.warn = ensureC(light and "#9A6700" or "#FFCC00", { p.card, p.inner, p.panel }, 4.5)
  local r, g, b = hexRGB(bg); p.ovbg = string.format("rgba(%d,%d,%d,.96)", r, g, b)
  return p
end
-- if no text colour reaches 4.5:1 on every surface (mid-grey backgrounds), the background is
-- stepped toward black (dark sets) or white (light sets) until it does
local function buildPalette(th)
  if th.id == "classic" then local p = {}; for k, v in pairs(CLASSIC_PAL) do p[k] = v end; p.cl, p.light = true, false; return p end
  local bg, p = th.bg, nil
  for i = 0, 8 do
    p = buildPalette1(bg, th.mic, th.acc)
    if worstC(p.tx, surfaces(p)) >= 4.5 then break end
    bg = mixC(th.bg, p.light and "#FFFFFF" or "#000000", (i + 1) * 0.1)
  end
  return p
end
-- lowest contrast numbers of a palette (text on every surface, accent text, muted, warning, focus ring)
local function palReport(p)
  local function r2(x) return math.floor(x * 100 + 0.5) / 100 end
  return { text = r2(worstC(p.tx, surfaces(p))), accent = r2(contrastC(p.acctx, p.acc)), muted = r2(worstC(p.mut, { p.panel, p.card, p.inner })),
    warn = r2(worstC(p.warn, { p.card, p.inner, p.panel })), focus = r2(contrastC(p.focus, p.panel)) }
end
local palCache = {}
function M.palette()
  local th = fabTheme(); local key = th.id..(th.bg or "")..(th.mic or "")..(th.acc or "")
  if not palCache[key] then palCache[key] = buildPalette(th) end
  return palCache[key]
end
M.buildPalette, M.palReport, M.contrastC = buildPalette, palReport, contrastC
function M.overlayPal()
  if overlay then overlay:evaluateJavaScript("setPal("..hs.json.encode(M.palette())..")") end
end
local fabHTML = [[
<html class="cl"><head><meta charset="utf-8"><style>
html,body{margin:0;width:100%;height:100%;background:transparent!important;overflow:hidden;-webkit-user-select:none;cursor:default}#b,#c{cursor:pointer}
html{--bg:#0A6CD6;--mic:#fff;--acc:rgba(255,255,255,.9);--arc:#fff}
#b{position:absolute;inset:]]..FABG.PAD..[[px;border-radius:50%;border:4px solid var(--acc);background:var(--bg);color:var(--mic);display:flex;align-items:center;justify-content:center;-webkit-backdrop-filter:blur(28px) saturate(160%);backdrop-filter:blur(28px) saturate(160%);box-shadow:0 3px 12px rgba(0,0,0,.28),inset 0 1.5px 0 rgba(255,255,255,.34),inset 0 -2px 6px rgba(0,0,0,.16)}
#i{width:50%;height:50%;display:flex}#i svg{width:100%;height:100%}
#b:not(.rec) #i svg path:first-of-type{stroke:var(--arc)}
html.ol #b:not(.rec) #i svg rect{fill:none}html.ol #b:not(.rec) #i svg{stroke-linecap:butt}
html:not(.cl) #b{border-width:5px}
#b.rec{background:rgba(30,142,62,.62);color:#fff;animation:pulse 2.4s ease-in-out infinite}
#b.busy{background:rgba(58,63,71,.60);color:#fff}#b.busy #i{display:none}
#spin{display:none;width:50%;height:50%;box-sizing:border-box;border-radius:50%;border:7px solid rgba(255,255,255,.28);border-top-color:#fff;animation:spin 1s linear infinite}
#b.busy #spin{display:block}
#b.armed{border-color:#30d158;border-width:6px}#ear{display:none;position:absolute;right:-2px;bottom:-2px;font-size:calc(100vw*.22);background:#30d158;border-radius:50%;padding:2px 4px}
#b.armed #ear{display:block}
@keyframes pulse{0%,100%{box-shadow:0 0 0 0 rgba(48,209,88,.55),0 3px 12px rgba(0,0,0,.28),inset 0 1.5px 0 rgba(255,255,255,.28),inset 0 -2px 6px rgba(0,0,0,.14)}50%{box-shadow:0 0 0 7px rgba(48,209,88,0),0 3px 12px rgba(0,0,0,.28),inset 0 1.5px 0 rgba(255,255,255,.28),inset 0 -2px 6px rgba(0,0,0,.14)}}
@keyframes spin{to{transform:rotate(360deg)}}
html.hc #b,html.rt #b{-webkit-backdrop-filter:none;backdrop-filter:none}
html.rt #b.rec{background:#1e8e3e}html.rt #b.busy{background:#3a3f47}
html.hc.cl #b{background:#000;border:5px solid #fff;box-shadow:none}html.hc #b{border-width:6px;box-shadow:none}html.hc #b.rec{background:#006b1f}html.hc #b.busy{background:#000}
html.hc #spin{border-color:#555;border-top-color:#ffd60a}html.hc #b.armed{border-color:#30d158}
html.rm #b,html.rm #spin{animation:none!important}html.rm #spin{border-style:dotted;border-color:#fff}
@media (prefers-reduced-motion: reduce){#b,#spin{animation:none!important}#spin{border-style:dotted;border-color:#fff}}
</style></head><body><div id=b role=button aria-label=""><span id=i></span><div id=spin></div><span id=ear>👂</span></div>
<script>var IC={mic:']]..ICON.mic..[[',rec:']]..ICON.paste..[['};
function s(a){webkit.messageHandlers.__MSG__.postMessage(a)}
document.getElementById('b').addEventListener('mousedown',function(e){if(e.button===0){e.preventDefault();s({cmd:'fabDown'})}});
var cur='';function setSt(st,armed,label,hc,rm,rt){var b=document.getElementById('b');b.className=st+(armed?' armed':'');
 var ic=st=='rec'?'rec':'mic';if(ic!=cur){document.getElementById('i').innerHTML=IC[ic];cur=ic}
 b.setAttribute('aria-label',label);
 document.documentElement.classList.toggle('hc',!!hc);document.documentElement.classList.toggle('rm',!!rm);document.documentElement.classList.toggle('rt',!!rt)}
function th(bg,mic,acc,cl,ol){var r=document.documentElement.style;r.setProperty('--bg',bg);r.setProperty('--mic',mic);r.setProperty('--acc',cl?'rgba(255,255,255,.9)':acc);r.setProperty('--arc',cl?mic:acc);
 document.documentElement.classList.toggle('cl',!!cl);document.documentElement.classList.toggle('ol',!!ol)}
s({cmd:'fabReady'});</script></body></html>]]
local satHTML = [[
<html><head><meta charset="utf-8"><style>
html,body{margin:0;width:100%;height:100%;background:transparent!important;overflow:hidden;-webkit-user-select:none;cursor:default}#b,#c{cursor:pointer}
#c{position:absolute;left:50%;top:50%;width:__R__px;height:__R__px;transform:translate(-50%,-50%);box-sizing:border-box;border-radius:50%;border:3px solid rgba(255,255,255,.9);
 color:#fff;display:flex;align-items:center;justify-content:center;opacity:.55;box-shadow:0 2px 8px rgba(0,0,0,.45);transition:width .18s ease,height .18s ease,opacity .18s ease}
#c.copy{background:#0a6cd6}#c.cancel{background:#d42c22}
#c.hov{width:__H__px;height:__H__px;opacity:1}
#c svg{width:46%;height:46%}
html.hc #c{opacity:.85;border:4px solid #fff;box-shadow:none}html.hc #c.hov{opacity:1}html.hc #c.copy{background:#003f8a}html.hc #c.cancel{background:#a00000}
html.rm #c{transition:none!important}
@media (prefers-reduced-motion: reduce){#c{transition:none!important}}
</style></head><body><div id=c class="__KIND__" role=button aria-label="__LABEL__">__ICON__</div>
<script>function s(a){webkit.messageHandlers.__MSG__.postMessage(a)}
document.getElementById('c').addEventListener('mousedown',function(e){if(e.button===0){e.preventDefault();s({cmd:'satDown',which:'__KIND__'})}});
function hov(on){document.getElementById('c').classList.toggle('hov',!!on)}
function setLook(hc,rm){document.documentElement.classList.toggle('hc',!!hc);document.documentElement.classList.toggle('rm',!!rm)}
setLook(__HC__,__RM__);</script></body></html>]]
local SAT_KINDS = { "copy", "cancel" }
local function satText(k) return k == "copy" and T("sat_copy") or (k == "cancel" and T("sat_cancel") or T("fab_rec")) end
-- the hover label: a canvas, so it never takes clicks or focus
local function showLabel(kind, f, side)
  local txt = satText(kind)
  local fs = math.floor(20 * (look.scale or 1) + 0.5)
  local w, h = math.floor(utf8.len(txt) * fs * 0.58 + 36), fs + 24
  local x, y
  if kind == "main" then side = ({ left = "right", right = "left", up = "down", down = "up" })[side] or "up" end
  if side == "left" then x, y = f.x - w - 4, f.y + (f.h - h) / 2
  elseif side == "right" then x, y = f.x + f.w + 4, f.y + (f.h - h) / 2
  elseif side == "up" then x, y = f.x + (f.w - w) / 2, f.y - h - 4
  else x, y = f.x + (f.w - w) / 2, f.y + f.h + 4 end
  local fr = clampFrame({ x = x, y = y, w = w, h = h })
  if satLabel then satLabel:delete() end
  satLabel = hs.canvas.new(fr):level(hs.canvas.windowLevels.floating + 1)
  satLabel:behavior(hs.drawing.windowBehaviors.canJoinAllSpaces + hs.drawing.windowBehaviors.stationary)
  satLabel[1] = { type = "rectangle", action = look.hc and "strokeAndFill" or "fill", roundedRectRadii = { xRadius = 10, yRadius = 10 },
    fillColor = look.hc and { white = 0, alpha = 1 } or { red = .08, green = .08, blue = .1, alpha = .92 },
    strokeColor = { white = 1, alpha = 1 }, strokeWidth = 3 }
  satLabel[2] = { type = "text", text = txt, frame = { x = 0, y = (h - fs * 1.25) / 2, w = w, h = fs * 1.4 },
    textSize = fs, textColor = { white = 1, alpha = 1 }, textAlignment = "center", textFont = ".AppleSystemUIFontBold" }
  satLabel:show()
end
local function hideLabel() if satLabel then satLabel:delete(); satLabel = nil end end
local function inside(p, f) return p.x >= f.x and p.x < f.x + f.w and p.y >= f.y and p.y < f.y + f.h end
local function placeSats()
  if not fab then return end
  local wf = fab:frame(); local mf = FABG.shrink(wf, FABG.EXTRA); local sw = FABG.satWin0()
  local side, fr = satLayout(mf, sw, screenFor(mf):frame())
  M._satSide, M._satMF = side, { x = mf.x, y = mf.y }
  for i, k in ipairs(SAT_KINDS) do if sats[k] then sats[k]:frame(FABG.grow(fr[i], FABG.EXTRA)) end end
end
-- mouse-over check every 0.08 s while the satellites are up (webviews that are not focused don't get hover events)
local function satTick()
  if not fab or not next(sats) then return end
  local mf = fab:frame()
  if not M._satMF or M._satMF.x ~= mf.x or M._satMF.y ~= mf.y then placeSats() end
  local p = hs.mouse.absolutePosition(); local hit, hf
  for _, k in ipairs(SAT_KINDS) do local w = sats[k]
    if w then local f = FABG.shrink(w:frame(), FABG.EXTRA); local on = inside(p, f)
      if on ~= (M._satHov[k] or false) then M._satHov[k] = on; w:evaluateJavaScript("hov("..tostring(on)..")") end
      if on then hit, hf = k, f end end
  end
  if not hit and inside(p, FABG.shrink(mf, FABG.EXTRA)) then hit, hf = "main", FABG.shrink(mf, FABG.EXTRA) end
  if hit ~= M._satLbl then M._satLbl = hit; if hit then showLabel(hit, hf, M._satSide) else hideLabel() end end
end
M.satTick = satTick
local function hideSats()
  if satTimer then satTimer:stop(); satTimer = nil end
  for k, w in pairs(sats) do w:delete(); sats[k] = nil end
  hideLabel(); M._satHov, M._satLbl, M._satMF = {}, nil, nil
end
local function showSats()
  if not fab then return end
  if next(sats) then return end
  local rest, big = satSizes()
  M._satHov = {}
  for _, k in ipairs(SAT_KINDS) do
    local html = satHTML:gsub("__MSG__", MSG):gsub("__R__", tostring(rest)):gsub("__H__", tostring(big)):gsub("__KIND__", k)
      :gsub("__LABEL__", (satText(k):gsub("%%", "%%%%"))):gsub("__ICON__", (k == "copy" and ICON.copy or ICON.x))
      :gsub("__HC__", tostring(look.hc and true or false)):gsub("__RM__", tostring(look.rm and true or false))
    sats[k] = hs.webview.new({ x = 0, y = 0, w = satWin(), h = satWin() }, {}, uc)
      :windowStyle({ "borderless", "nonactivating" }):level(hs.drawing.windowLevels.floating)
      :allowTextEntry(false):transparent(true):shadow(false)
      :behavior(hs.drawing.windowBehaviors.canJoinAllSpaces + hs.drawing.windowBehaviors.stationary)
      :html(html)
  end
  placeSats()
  for _, k in ipairs(SAT_KINDS) do sats[k]:show() end
  satTimer = hs.timer.doEvery(0.08, satTick)
end
M.showSats, M.hideSats = showSats, hideSats
function M.satRefs() return sats end
-- ---------- hiding the floating button ----------
-- Three ways: the shortcut (until pressed again or Hammerspoon reloads), "Hide when an app is full
-- screen" and "Hide in these apps". Hiding only happens while idle: while recording or working the
-- button and its satellites always show, so Stop stays reachable. Shortcuts keep working while hidden.
M.fabSessionHidden = false
-- is this app (or {name=, id=}) in the "Hide in these apps" list? matches bundle id or name, any case
local function appMatches(app, list)
  if not app then return false end
  local function get(f) if type(f) ~= "function" then return f end; local ok, v = pcall(f, app); return ok and v or nil end
  local nm = get(app.name) or ""
  local id = (type(app.bundleID) == "function" and get(app.bundleID)) or (type(app.id) == "string" and app.id) or ""
  nm, id = nm:lower(), id:lower()
  for _, e in ipairs(list or cfg.hideApps or {}) do
    local en, ei = ((type(e)=="table" and e.name) or (type(e)=="string" and e) or ""):lower(), ((type(e)=="table" and e.id) or ""):lower()
    if (ei ~= "" and ei == id) or (en ~= "" and (en == nm or en == id)) then return true end
  end
  return false
end
-- native full screen, or a window that covers the whole screen (borderless video players, games)
local function isFullscreenWin(w)
  if not w then return false end
  local ok, fs = pcall(function() return w:isFullScreen() end)
  if ok and fs then return true end
  -- borderless full-screen windows are often not "standard", so only rule out things that are not
  -- windows at all (the Finder desktop is an AXScrollArea)
  local ok2, role = pcall(function() return w:role() end)
  if not ok2 or role ~= "AXWindow" then return false end
  local f, scr = w:frame(), w:screen(); if not scr then return false end
  local sf = scr:fullFrame()
  return f.x <= sf.x + 1 and f.y <= sf.y + 1 and f.x + f.w >= sf.x + sf.w - 1 and f.y + f.h >= sf.y + sf.h - 1
end
-- the decision, as a plain function: "" = show, else why it is hidden ("shortcut" | "app" | "fullscreen")
local function hideDecision(o)
  if o.state ~= "idle" then return "" end
  if o.session then return "shortcut" end
  if o.inList then return "app" end
  if o.hideFullscreen and o.fullscreen then return "fullscreen" end
  return ""
end
M.isFullscreenWin, M.appMatches, M.hideDecision = isFullscreenWin, appMatches, hideDecision
function M.fabHideReason()
  if state ~= "idle" then return "" end
  if M.fabSessionHidden then return "shortcut" end
  local app = hs.application.frontmostApplication()
  -- Taipea's own window (Hammerspoon) in front: keep what was decided for the app before it
  if not app or app:bundleID() == "org.hammerspoon.Hammerspoon" then return M._lastAutoReason or "" end
  local full = false
  if cfg.hideFullscreen then local ok, w = pcall(function() return app:focusedWindow() end); full = ok and isFullscreenWin(w) end
  local r = hideDecision({ state = state, session = false, inList = appMatches(app), hideFullscreen = cfg.hideFullscreen, fullscreen = full })
  M._lastAutoReason = r
  return r
end
function M.applyFabVis()
  if not fab then return end
  local r = M.fabHideReason()
  local vis = fab:isVisible()
  if r ~= "" then if vis then hideSats(); fab:hide() end
  elseif not vis then fab:show() end
  if r ~= (M._fabHidR or "") then M._fabHidR = r; log("floating button "..(r == "" and "shown" or ("hidden: "..r))) end
end
function M.toggleFabHidden()
  if not cfg.floatButton then hs.alert.show(T("fab_is_off")); return end
  M.fabSessionHidden = not M.fabSessionHidden
  M.applyFabVis()
  hs.alert.show(M.fabSessionHidden and T("fab_hidden", keyLabel(cfg.fabHideKey)) or T("fab_shown"), 2)
  if pushState then pushState() end
end

-- ---------- Modifier-only shortcuts that act ON PRESS ----------
-- Defaults: Control + Command = start / stop and paste, Option + Command = hide / show the floating
-- button. A modifier-only shortcut fires as soon as all its modifiers are down with no other
-- modifier (Fn is ignored), once CHORD_DEBOUNCE seconds pass with no other key pressed. Letting go
-- before then, with no other key, fires right away (a quick tap). A key pressed in that window
-- means a shortcut (Ctrl+Cmd+Q, Ctrl+Cmd+Space, Cmd+Option+Esc…), so it doesn't fire. After firing
-- it won't fire again until one of its keys is let go (and never twice within CHORD_COOLDOWN), so
-- one press = one toggle. Clicks are ignored, so it works with the Accessibility Keyboard (click to
-- latch Control, then Command) and Dwell clicks, where the keys may stay latched. The tap only
-- watches and never consumes events. It needs Accessibility; a watchdog restarts it if macOS
-- disables it. Each attempt that didn't fire is written to the log with the reason.
M.CHORD_DEBOUNCE = 0.28
M.CHORD_COOLDOWN = 0.8
KD.MODN = { alt = "Option", shift = "Shift", ctrl = "Control", cmd = "Command" }
function M.newChord(name, mods, onFire)
  local need = {}; for _, m in ipairs(mods) do need[m] = true end
  local C = { name = name, mods = mods, phase = "idle", t0 = 0, gen = 0, lastFire = -1e9 }
  local function forbidden(fl) for _, k in ipairs(KD.ORDER) do if fl[k] and not need[k] then return k end end end
  local function all(fl) for _, m in ipairs(mods) do if not fl[m] then return false end end; return true end
  local function fire(how, now) C.phase, C.lastFire = "fired", now; log(name.." ("..how.."): fire"); if onFire then onFire() end; return true end
  -- one step of the decision; kind = "flags" (fl = {cmd=,alt=,ctrl=,shift=,fn=}), "key", "mouse" or
  -- "tick" (the debounce time is up). Returns true = fire now. now is for tests.
  function C.feed(kind, fl, now)
    now = now or hs.timer.secondsSinceEpoch()
    if kind == "mouse" then return false end
    if kind == "key" then
      if C.phase == "pending" then C.phase = "blocked"; log(name..": not counted – a key was pressed with it (a shortcut)") end
      return false
    end
    if kind == "tick" then
      if C.phase == "pending" and (now - C.t0) >= M.CHORD_DEBOUNCE - 0.005 then return fire("press", now) end
      return false
    end
    fl = fl or {}
    local both, bad = all(fl), forbidden(fl)
    if C.phase == "idle" then
      if both and not bad and (now - C.lastFire) < M.CHORD_COOLDOWN then C.phase = "blocked"; log(name..": not counted – too soon after the last one"); return false end
      if both and not bad then C.phase, C.t0 = "pending", now; C.gen = C.gen + 1; return false end
      if both and bad then C.phase = "blocked"; log(name..": not counted – "..KD.MODN[bad].." was held too") end
      return false
    end
    if C.phase == "pending" then
      if bad then C.phase = "blocked"; log(name..": not counted – "..KD.MODN[bad].." was held too"); return false end
      if not both then local r = fire("quick tap", now); C.phase = "idle"; return r end
      return false
    end
    -- fired / blocked: ready again once one of its keys is let go
    if not both then C.phase = "idle" end
    return false
  end
  function C.reset(ph) C.phase = ph or "idle" end
  return C
end
M.CHORDS = {}   -- filled by bindAll() from the modifier-only shortcuts
function M.chordTapStart()
  if M._chordTap then M._chordTap:stop() end
  local ty = hs.eventtap.event.types
  M._chordTap = hs.eventtap.new({ ty.flagsChanged, ty.keyDown }, function(ev)
    local ok, err = pcall(function()
      if M._capturing then return end
      local isKey = ev:getType() == ty.keyDown
      local fl = (not isKey) and ev:getFlags() or nil
      for _, C in ipairs(M.CHORDS) do
        if isKey then C.feed("key") else
          local before = C.gen
          C.feed("flags", fl)
          if C.phase == "pending" and C.gen ~= before then
            local g = C.gen
            after(M.CHORD_DEBOUNCE, function() if C.gen == g then C.feed("tick") end end)
          end
        end
      end
    end)
    if not ok then log("shortcuts: error "..tostring(err)) end
    return false   -- never consume: other apps still get every key
  end)
  M._chordTap:start()
  M.chordTapOK = M._chordTap:isEnabled() and true or false
  M.fabTapOK = M.chordTapOK
  if not M.chordTapOK then log("shortcuts: could not start the key watcher (Accessibility off?); use Control + Option + Space or the menu") end
end
M.chordTapStart()

-- ---------- Escape while recording = Stop & Paste ----------
-- Only while recording and only plain Escape (no modifier, so Cmd+Option+Esc etc. are untouched);
-- that Escape is swallowed. When not recording, Escape passes through. Setting escStop (default on).
-- Escape is not Cancel: the Cancel button is the only way to throw a recording away.
function M.escWanted(kc, fl)
  fl = fl or {}
  return kc == 53 and state == "rec" and cfg.escStop ~= false and not M._capturing and not (fl.cmd or fl.alt or fl.ctrl or fl.shift) and true or false
end
function M._setState(s) state = s end   -- tests only
function M._setCancelled(v) cancelled = v end   -- tests only
function M.escTapStart()
  if M._escTap then M._escTap:stop() end
  local ty = hs.eventtap.event.types
  M._escTap = hs.eventtap.new({ ty.keyDown, ty.keyUp }, function(ev)
    if ev:getKeyCode() ~= 53 then return false end
    local ok, eat = pcall(function()
      if ev:getType() == ty.keyUp then if M._escEat then M._escEat = false; return true end; return false end
      if M._escEat and ev:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) ~= 0 then return true end
      if not M.escWanted(53, ev:getFlags()) then return false end
      M._escEat = true; log("Escape: stop and paste"); after(0, function() M.stop("paste") end)
      return true
    end)
    return ok and eat or false
  end)
  M._escTap:start()
  M.escTapOK = M._escTap:isEnabled() and true or false
end
M.escTapStart()

-- ---------- Mic (Dictation) key: F5 🎙 on recent Apple keyboards ----------
-- Off by default (setting micKey). The key reaches Taipea only when macOS isn't using it: System
-- Settings › Keyboard › Dictation, turn Dictation off or set Shortcut to Off. It arrives as keycode
-- 176; Taipea starts / stops on key down and swallows the key so macOS doesn't react too.
M.MIC_KEYCODES = { [176] = true }
function M.micTapStart()
  if M._micTap then M._micTap:stop() end
  local ty = hs.eventtap.event.types
  M._micTap = hs.eventtap.new({ ty.keyDown, ty.keyUp }, function(ev)
    local ok, eat = pcall(function()
      if M._capturing or cfg.micKey ~= true or not M.MIC_KEYCODES[ev:getKeyCode()] then return false end
      if ev:getType() == ty.keyDown and ev:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) == 0 then
        log("Mic key: start/stop (state="..tostring(state)..")"); after(0, function() M.toggle() end)
      end
      return true
    end)
    return ok and eat or false
  end)
  M._micTap:start()
  M.micTapOK = M._micTap:isEnabled() and true or false
end
M.micTapStart()

-- ---------- Recording a shortcut (Settings › Shortcuts › Record shortcut) ----------
-- Click Record shortcut, then press the keys. It ends on a key press (modifiers + key, e.g.
-- Control + Option + Space), when all held modifiers are let go (modifier-only, e.g. Control +
-- Command), or after CAP_STABLE seconds of the same 2+ modifiers held with no key (Accessibility
-- Keyboard: latched modifiers). Plain Escape cancels. While listening, Taipea's shortcuts are
-- paused and key presses are swallowed, so nothing else reacts.
M.CAP_STABLE = 0.8
M.CAP_TIMEOUT = 20
function M.modsOf(fl) local o = {}; for _, m in ipairs(KD.ORDER) do if fl and fl[m] then o[#o+1] = m end end; return o end
function M.capBegin(target, now) M.CAP = { target = target, cur = {}, max = {}, seen = false, t0 = now or hs.timer.secondsSinceEpoch(), tStable = 0 }; return M.CAP end
-- one step; kind "flags" (a = flags), "key" (a = {kc=, fl=}) or "tick". Returns nil (keep
-- listening), { spec = {mods=, key=} } or { cancel = true }. Only the first result counts.
function M.capFeed(kind, a, now)
  local P = M.CAP; if not P or P.done then return nil end
  now = now or hs.timer.secondsSinceEpoch()
  local r
  if kind == "flags" then
    local cur = M.modsOf(a)
    if #cur > 0 then
      if #cur >= #P.max then P.max = cur end
      P.cur, P.tStable, P.seen = cur, now, true
    else
      P.cur = {}
      if P.seen and #P.max > 0 then r = { spec = { mods = P.max, key = "" } } end
    end
  elseif kind == "key" then
    local kc, mods = a.kc, M.modsOf(a.fl)
    if kc == 53 and #mods == 0 then r = { cancel = true }
    elseif M.MIC_KEYCODES[kc] then r = { spec = { mods = mods, key = "mic" } }
    else r = { spec = { mods = mods, key = hs.keycodes.map[kc] or ("?"..tostring(kc)) } } end
  elseif kind == "tick" then
    if now - P.t0 > M.CAP_TIMEOUT then r = { cancel = true, timeout = true }
    elseif #P.cur >= 2 and now - P.tStable >= M.CAP_STABLE then r = { spec = { mods = P.cur, key = "" } } end
  end
  if r then P.done = true end
  return r
end
function M.capStop()
  if M._capTap then M._capTap:stop(); M._capTap = nil end
  if M._capTimer then M._capTimer:stop(); M._capTimer = nil end
  local was = M._capturing
  M._capturing = nil; M.CAP = nil
  if was then
    for _, h in ipairs(hk) do if h.enable then h:enable() end end
    for _, C in ipairs(M.CHORDS) do C.reset("blocked") end   -- keys still held from recording don't fire it
  end
end
function M.capFinish(r)
  local target = M.CAP and M.CAP.target or (M.cap and M.cap.target)
  M.capStop()
  if r.cancel then M.cap = nil; log("record shortcut: cancelled"..(r.timeout and " (timeout)" or ""))
  else
    local spec = { mods = KD.sort(r.spec.mods), key = r.spec.key or "" }
    M.cap = { target = target, phase = "result", spec = spec, sym = M.keySym(spec), label = keyLabel(spec), err = M.keyProblem(target, spec) or "" }
    log("record shortcut "..tostring(target)..": "..keyStr(spec)..(M.cap.err ~= "" and (" – refused: "..M.cap.err) or ""))
  end
  if pushState then pushState() end
end
function M.captureStart(target)
  if not KD.BOUND[target] then return end
  M.capStop()
  M.capBegin(target); M._capturing = target
  for _, h in ipairs(hk) do if h.disable then h:disable() end end
  local ty = hs.eventtap.event.types
  M._capTap = hs.eventtap.new({ ty.flagsChanged, ty.keyDown, ty.keyUp }, function(ev)
    local ok, eat = pcall(function()
      local t = ev:getType()
      if t == ty.keyUp then return true end
      local r
      if t == ty.flagsChanged then r = M.capFeed("flags", ev:getFlags())
      else r = M.capFeed("key", { kc = ev:getKeyCode(), fl = ev:getFlags() }) end
      if r then after(0, function() M.capFinish(r) end) end
      return t ~= ty.flagsChanged
    end)
    return ok and eat or false
  end)
  M._capTap:start()
  M._capTimer = hs.timer.doEvery(0.1, function() local r = M.capFeed("tick"); if r then M.capFinish(r) end end)
  M.cap = { target = target, phase = "listen" }
  log("record shortcut "..target..": listening")
  if pushState then pushState() end
end
function M.captureCancel() M.capStop(); M.cap = nil; if pushState then pushState() end end

-- keep the key watchers running if macOS disables them (for example after a timeout)
if M._fabTapDog then M._fabTapDog:stop() end
M._fabTapDog = hs.timer.doEvery(5, function()
  for _, p in ipairs({ { "_chordTap", "chordTapOK" }, { "_escTap", "escTapOK" }, { "_micTap", "micTapOK" } }) do
    local tap = M[p[1]]
    if tap and not tap:isEnabled() then
      tap:start(); M[p[2]] = tap:isEnabled() and true or false
      log("key watcher "..p[1]..": was disabled, restart "..(M[p[2]] and "OK" or "failed"))
      if pushState then pushState() end
    elseif tap then M[p[2]] = true end
  end
  M.fabTapOK = M.chordTapOK
end)
-- react when you switch apps, plus a light check every second for full screen changes
if M._fabAppW then M._fabAppW:stop() end
M._fabAppW = hs.application.watcher.new(function(_, ev)
  if ev == hs.application.watcher.activated or ev == hs.application.watcher.deactivated or ev == hs.application.watcher.terminated then
    after(0.15, function() M.applyFabVis() end)
  end
end)
if M._fabAppW then M._fabAppW:start() end
M._fabPoll = hs.timer.doEvery(1, function()
  if fab and state == "idle" and (cfg.hideFullscreen or M._fabHidR == "fullscreen") then M.applyFabVis() end
end)
function M.fabUpdate()
  if not fab then hideSats(); return end
  local st = state == "rec" and "rec" or (state == "busy" and "busy" or "idle")
  local armed = M.voiceActive() and st ~= "busy"
  local label = st == "rec" and T("fab_rec") or (st == "busy" and T("fab_busy") or (armed and T("fab_listening", (cfg.startPhrases or {})[1] or "") or T("fab_idle")))
  local th = fabTheme()
  fab:evaluateJavaScript(string.format("th(%q,%q,%q,%s,%s)", FABG.glassBg(th.bg, look.hc or look.rt), th.mic, th.acc, th.id == "classic" and "true" or "false", th.outline and "true" or "false"))
  fab:evaluateJavaScript(string.format("setSt(%q,%s,%q,%s,%s,%s)", st, armed and "true" or "false", label, look.hc and "true" or "false", look.rm and "true" or "false", look.rt and "true" or "false"))
  M.applyFabVis()
  if st == "rec" then showSats() else hideSats() end
end
local function showFab()
  if not cfg.floatButton then hideSats(); if fab then fab:delete(); fab = nil end; return end
  if not fab then
    fab = hs.webview.new(fabFrame(), {}, uc)
      :windowStyle({ "borderless", "nonactivating" }):level(hs.drawing.windowLevels.floating)
      :allowTextEntry(false):transparent(true):shadow(false)
      :behavior(hs.drawing.windowBehaviors.canJoinAllSpaces + hs.drawing.windowBehaviors.stationary)
      :html((fabHTML:gsub("__MSG__", MSG)))
  else fab:frame(fabFrame()) end
  hideSats()   -- rebuilt at the new size / look by fabUpdate
  if M.fabHideReason() == "" then fab:show() end; M.fabUpdate()
end
M.showFab = showFab
function M.fabRef() return fab end
-- the recording card is used when there is no floating button, or when "Show the recording card too" is on
function M.cardWanted() return (not cfg.floatButton) or cfg.cardWithFab == true end
-- the main button while recording means Stop & Paste
local function fabClick()
  if state == "rec" then M.stop("paste") else M.toggle() end
end
-- press on the button: drag it, or (if it barely moved) treat it as a click
function M.startFabDrag()
  if not fab then return end
  startDrag(fab, KP.."fabPos", function(moved, f0)
    if moved < 8 then fab:frame(f0); settings.set(KP.."fabPos", { x = f0.x + FABG.EXTRA, y = f0.y + FABG.EXTRA }); fabClick()
    else local f = fab:frame(); settings.set(KP.."fabPos", { x = f.x + FABG.EXTRA, y = f.y + FABG.EXTRA }); placeSats() end
  end)
end
-- press on a satellite: it acts when the mouse is released less than 8 px from where it went down
function M.satPress(which)
  local p0 = hs.mouse.absolutePosition(); local done = false
  local P = {}; M._press = P
  local function fin()
    if done then return end; done = true
    if P.tap then P.tap:stop() end; if P.tm then P.tm:stop() end
    local p = hs.mouse.absolutePosition()
    if math.sqrt((p.x - p0.x)^2 + (p.y - p0.y)^2) >= 8 or state ~= "rec" then return end
    if which == "copy" then M.stop("copy") elseif which == "cancel" then M.cancel() end
  end
  P.tap = hs.eventtap.new({ hs.eventtap.event.types.leftMouseUp }, function() after(0, fin); return false end)
  P.tap:start()
  local n = 0
  P.tm = hs.timer.doEvery(0.03, function() n = n + 1
    if (n > 3 and not hs.eventtap.checkMouseButtons()[1]) or n > 600 then fin() end end)
end

local function clip(s,n) s=(s or ""):gsub("\n"," "); if #s>n then return s:sub(1,n).."…" end; return s end
refresh = function()
  local icon = state=="rec" and "🔴" or (state=="busy" and "⏳" or "🎙")
  menu:setTitle(icon..((M.voiceActive() and state~="busy") and "👂" or "")..(cfg.cleanup and "" or " raw")); menu:setTooltip("Taipea")
  local items = {
    { title = T("menu_open"), fn = function() M.openApp() end },
    { title = "-" },
    { title = (state=="rec" and T("menu_stop") or T("menu_start")).."  ("..keyLabel(cfg.toggleKey)..")", fn = function() M.toggle() end },
    { title = T("menu_cleanup").."  ("..keyLabel(cfg.modeKey)..")", checked = cfg.cleanup, fn = function() M.toggleMode() end },
    { title = T("menu_autostop", tostring(cfg.silenceSeconds)), checked = cfg.autoStop, fn = function() M.toggleAutoStop() end },
    { title = T("menu_voice", (cfg.startPhrases or {})[1] or ""), checked = cfg.voiceControl, fn = function() M.handle({cmd="set", key="voiceControl", value=not cfg.voiceControl}) end },
    { title = T("menu_fab"), checked = cfg.floatButton, fn = function() M.handle({cmd="set", key="floatButton", value=not cfg.floatButton}) end },
    { title = T("menu_fab_hide").."  ("..keyLabel(cfg.fabHideKey)..")", checked = M.fabSessionHidden, disabled = not cfg.floatButton, fn = function() M.toggleFabHidden() end },
    { title = "-" },
    { title = T("menu_paste_last").."  ("..keyText(cfg.pasteLastKey)..")", disabled = #history==0, fn = function() M.pasteLast() end },
  }
  if not M.permAx then
    table.insert(items, 1, { title = T("menu_open_ax"), fn = function() M.openPerm(AX_URL) end })
    table.insert(items, 2, { title = "-" })
  end
  if M.micWarn then table.insert(items, { title = T("menu_open_mic"), fn = function() M.openPerm(MIC_URL) end }) end
  if M.updWanted and M.updWanted() then
    table.insert(items, 1, { title = T("upd_menu", M.upd.latest), fn = function() M.updOpen() end })
    table.insert(items, 2, { title = "-" })
  end
  if M.recoverable then
    table.insert(items, { title = "♻️ "..T("menu_recover", fmtSecs(M.recoverable.secs)), fn = function() M.recover() end })
    table.insert(items, { title = T("menu_discard"), fn = function() M.discardRecovery() end })
  end
  table.insert(items, { title = "-" })
  local sub = {}
  for i=1, math.min(10,#history) do
    local e = history[i]
    table.insert(sub, { title = e.time:sub(12,16).."  "..clip(finalText(e),60), fn = function() hs.pasteboard.setContents(finalText(e)); hs.alert.show(T("copied")) end })
  end
  if #sub>0 then table.insert(items, { title = T("menu_recent"), menu = sub }) end
  table.insert(items, { title = T("menu_log"), fn = function() hs.execute("open '"..logf.."'") end })
  menu:setMenu(items)
  vlSync(); M.fabUpdate()
  if pushState then pushState() end
end
M.refreshUI = function() refresh() end

-- ---------- pipeline ----------
local function finish(raw, cleaned, gen)
  if M.jobStale(gen) or cancelled then return end
  M.liveLogTimes()
  M.liveEndSession()
  state="idle"; if tick then tick:stop() end; hideOverlay()
  clearSession()
  local recovering = M._recovering; M._recovering = false
  if recovering then os.remove(recoverWav) end
  local text = ((cleaned or raw) or ""):gsub("^%s+",""):gsub("%s+$","")
  if M._dry then M._dryResult = text; log("DRY RUN result: "..text); refresh(); return end
  if text == "" then refresh(); M.micProblem(T("no_speech")); return end
  M.micWarn = false
  addHistory((raw or ""):gsub("^%s+",""):gsub("%s+$",""), cleaned and text or nil)
  refresh()
  if recovering then hs.pasteboard.setContents(text); hs.alert.show(T("recovered"), 4); log("RECOVERED: "..text)
  elseif mode=="copy" then hs.pasteboard.setContents(text); hs.alert.show(T("copied_clip")); log("COPIED: "..text)
  elseif doPaste(text, targetApp) ~= false then log("PASTED: "..text) end
end
M.finish = finish

local STYLE = {
  light = "Fix grammar, spelling, punctuation and capitalization only. Keep the wording and structure.",
  paragraphs = "You are a dictation editor. Turn the dictated TEXT into well-formed paragraphs: fix grammar, spelling, punctuation and capitalization, remove filler sounds (eh, um), stutters and accidental repetitions, and group related sentences into paragraphs separated by a blank line (start a new paragraph when the topic changes). Keep the speaker's own wording otherwise. ",
  bullets = "You are a dictation editor. Turn the dictated TEXT into a clear bulleted list. Put one idea per bullet, each line starting with '- '. Write each bullet concisely: drop fillers, repetitions and false starts, but keep every piece of information (names, numbers, dates, reasons, requests). Use several bullets, not one long bullet. Do not add a title or introduction. ",
  formal = "You are a professional editor. Rewrite the dictated TEXT in a formal, polite, professional register suitable for a business email or document: complete sentences, correct grammar and punctuation, no slang, no colloquial expressions, no fillers or repetitions. In Spanish use the formal usted form where the speaker addresses someone. Rephrase freely to sound professional, but keep all the meaning and every piece of information. Start directly with the content: do not add a greeting, salutation (like Señor or Dear), title or closing that the speaker did not say. Formal does not mean translating: any English word the speaker used inside Spanish (like the report, budget, numbers) stays in English. ",
}
-- hard rules shared by the restructuring styles (paragraphs / bullets / formal)
local STYLE_RULES = "HARD RULES: (1) NEVER translate. Write each phrase in the same language it was spoken in. If the speaker mixes Spanish and English, keep the English words in English and the Spanish words in Spanish. English text stays English; Spanish text stays Spanish. (2) Never change names of people, places, companies or products. (3) Keep all facts, numbers and dates; do not add new information and do not answer questions in the text. (4) Output ONLY the result, with no introduction, quotes, notes or comments.\n"
local STYLE_EX = {
  paragraphs = "Example input: hola eh necesito que me mandes the report antes del viernes because el cliente lo pidió. otra cosa la reunión del lunes se movió para el martes\nExample output: Hola, necesito que me mandes the report antes del viernes because el cliente lo pidió.\n\nOtra cosa: la reunión del lunes se movió para el martes.",
  bullets = "Example input: hola eh necesito que me mandes the report antes del viernes because el cliente lo pidió y también um revisa el budget con Ana and then confirma la reunión del lunes\nExample output:\n- Mándame the report antes del viernes because el cliente lo pidió.\n- Revisa el budget con Ana.\n- Confirma la reunión del lunes.\nExample input: so we need to fix the login page it crashes on old phones and also the colors are too dark and I want the new logo there by next week\nExample output:\n- Fix the login page: it crashes on old phones.\n- The colors are too dark.\n- Add the new logo by next week.",
  formal = "Example input: eh necesito que me mandes the report antes del viernes porque el cliente está como desesperado y revisa el budget\nExample output: Le agradecería que me enviara the report antes del viernes, ya que el cliente lo necesita con urgencia. Por favor, revise también el budget.\nExample input: so the app is kinda broken on old phones can you guys fix it asap\nExample output: The application is not working properly on older phones. Could you please fix it as soon as possible?",
}
local STYLE_GO = { paragraphs="Now write the paragraphs.\n", bullets="Now write the bulleted list.\n", formal="Now write the formal version.\n" }
local LANG_HINT = {
  en = "The TEXT is in English, so write the result in English only. ",
  es = "The TEXT is in Spanish, so write the result in Spanish only. ",
  mixed = "The TEXT mixes Spanish and English. Keep that mix: every English word or phrase stays in English exactly as spoken (do not translate words like 'because', 'the report', 'budget' into Spanish) and every Spanish part stays in Spanish. ",
}
local function wordSet(list) local t={} for w in list:gmatch("%S+") do t[w]=true end return t end
local EN_W = wordSet("the and to of a is it that you i we in for on with this but so be have was are not can just like what my they at as if there or do me an about all would our your one will")
local ES_W = wordSet("el la de que y en los las un una es por para con no se lo del al pero como más mi me yo tú le su sus muy ya también porque eso esto sí hay está son era fue cuando todo nos")
-- rough language guess from function words: "en", "es" or "mixed"
-- share of English among function words (0 = all Spanish, 1 = all English), and how many were seen
local function enRatio(text)
  local e, s = 0, 0
  for w in text:lower():gmatch("[%w\128-\255']+") do
    if EN_W[w] then e=e+1 end; if ES_W[w] then s=s+1 end   -- "no","me" count for both
  end
  return (e+s>0) and e/(e+s) or 0.5, e+s
end
M.enRatio = enRatio
local function guessLang(text)
  local r, n = enRatio(text)
  if n == 0 then return "mixed" end
  return r>0.85 and "en" or (r<0.15 and "es" or "mixed")
end
M.guessLang = guessLang
local function buildPrompt(raw, style)
  style = style or cfg.style
  if style=="paragraphs" or style=="bullets" or style=="formal" then
    -- instructions, examples, then the text, then a language reminder (small models weigh the end most)
    return STYLE[style]..STYLE_RULES..wordsRule()..STYLE_EX[style].."\n\nTEXT:\n"..raw.."\n\n"..LANG_HINT[guessLang(raw)]..STYLE_GO[style]
  end
  return "You are a dictation editor. "..STYLE.light.." "..
  "CRITICAL: never translate. Every word stays in the language it was spoken in; if the speaker switches between Spanish and English mid-sentence, keep that switch exactly, including small English words like because, but, so. Never change names or places (Cartagena stays Cartagena). "..
  "Do not add new ideas, do not answer questions in the text. Remove only filler sounds (eh, um); keep every real word, even if repeated. Output ONLY the resulting text, no quotes or comments. "..wordsRule().."\n"..
  "Example input: hola eh necesito que me mandes the report antes del viernes\n"..
  "Example output: Hola, necesito que me mandes the report antes del viernes.\n"..
  "Example input: vamos a la playa because hace calor en san andres\n"..
  "Example output: Vamos a la playa because hace calor en San Andrés.\n\nTEXT:\n"..raw
end
M.buildPrompt = buildPrompt


-- ---------- output sanity checks (reject empty / garbage / translated / truncated output) ----------
local ACC = { ["á"]="a",["é"]="e",["í"]="i",["ó"]="o",["ú"]="u",["ü"]="u",["ñ"]="n",["Á"]="a",["É"]="e",["Í"]="i",["Ó"]="o",["Ú"]="u",["Ü"]="u",["Ñ"]="n" }
local function contentWords(t)
  local out = {}
  t = t:gsub("[\195][\128-\191]", function(ch) return ACC[ch] or ch end):lower()
  for w in t:gmatch("[%w\128-\255]+") do if #w>=4 then table.insert(out, w) end end
  return out
end
-- share of the output's content words (4+ letters) that also appear in the input
local function wordOverlap(input, output)
  local I = {}; for _,w in ipairs(contentWords(input)) do I[w]=true end
  local O = contentWords(output); if #O==0 then return 0, 0 end
  local hit = 0; for _,w in ipairs(O) do if I[w] then hit=hit+1 end end
  return hit/#O, #O
end
M.wordOverlap = wordOverlap
-- returns nil if output is acceptable, else a reason string
-- light: must keep >=60% of the characters (it only removes fillers)
-- paragraphs: >=50%; bullets/formal: >=25% (they condense/rephrase) and <=3x length;
-- all non-light styles: >=25% of the output's content words must come from the input (catches garbage),
-- and the English/Spanish mix of function words must not swing by more than 0.6 (catches translation)
local function checkOutput(input, output, sty)
  local ni, no = #input:gsub("%s",""), #output:gsub("%s","")
  if no == 0 then return "empty" end
  local minR = ({ light=0.6, paragraphs=0.5, bullets=0.25, formal=0.25 })[sty] or 0.6
  if no < minR*ni then return string.format("too short %.2f", no/ni) end
  if sty ~= "light" then
    if ni > 40 and no > 3*ni then return string.format("too long %.2f", no/ni) end
    local ov, n = wordOverlap(input, output)
    if n >= 5 and ov < 0.25 then return string.format("low word overlap %.2f", ov) end
    -- language drift (e.g. Spanish or mixed dictation came back all in English)
    local ri, ni2 = enRatio(input); local ro, no2 = enRatio(output)
    if ni2 >= 6 and no2 >= 6 and math.abs(ro-ri) > 0.6 then return string.format("language changed %.2f->%.2f", ri, ro) end
  end
  return nil
end
-- formal: drop a salutation line the model invented ("Señor:" / "Estimado equipo:" / "Dear John,")
local function stripSalutation(input, out)
  local first, rest = out:match("^([^\n]+)\n+(.+)$")
  if not first or select(2, first:gsub("%S+","")) > 5 or not first:match("[,:]%s*$") then return out end
  local w = first:lower():match("^%s*(%S+)")
  local SAL = { ["señor"]=1, ["señora"]=1, ["señores"]=1, ["señor/a"]=1, ["señor(a)"]=1, ["estimado"]=1, ["estimada"]=1, ["estimados"]=1, ["estimadas"]=1, ["apreciado"]=1, ["apreciada"]=1, ["dear"]=1, ["to"]=1 }
  w = w and w:gsub("[,:]$","")
  if not (w and SAL[w]) or input:lower():sub(1,80):find(w, 1, true) then return out end
  rest = rest:gsub("^(%l)", string.upper):gsub("^([\195])([\161\169\173\179\186\177])", function(a,b) return a..string.char(b:byte()-32) end)
  return rest
end
-- normalise list markers to "- " and drop blank lines so chunks join into one list
local function normBullets(t)
  local lines = {}
  for line in (t.."\n"):gmatch("(.-)\n") do
    local l = line
    for _,m in ipairs({"%*", "•", "·", "–", "—", "%d+[%.%)]"}) do l = l:gsub("^%s*"..m.."%s+", "- ") end
    l = l:gsub("^%s+%- ", "- ")
    if not l:match("^%s*$") then table.insert(lines, l) end
  end
  return table.concat(lines, "\n")
end

M.checkOutput, M.normBullets, M.stripSalutation = checkOutput, normBullets, stripSalutation
-- split long text at sentence boundaries into ~250-word chunks
local function splitChunks(text, maxWords)
  maxWords = maxWords or 250
  local sentences = {}
  for sent in (text.." "):gmatch("(.-[%.%?!…]+[\"')%]]*)%s+") do table.insert(sentences, sent) end
  -- trailing text without final punctuation
  local tail = text:match("[%.%?!…][\"')%]]*%s+([^%.%?!…]+)$") or (#sentences==0 and text or nil)
  if tail and not tail:match("^%s*$") then table.insert(sentences, tail) end
  local chunks, cur, n = {}, {}, 0
  local function flush() if #cur>0 then table.insert(chunks, table.concat(cur, " ")); cur, n = {}, 0 end end
  for _,sent in ipairs(sentences) do
    local w = select(2, sent:gsub("%S+",""))
    -- a single huge sentence (no punctuation): hard-split by words
    if w > maxWords*1.5 then
      flush(); local buf = {}
      for word in sent:gmatch("%S+") do table.insert(buf, word); if #buf>=maxWords then table.insert(chunks, table.concat(buf," ")); buf={} end end
      if #buf>0 then cur, n = {table.concat(buf," ")}, #buf end
    else
      if n>0 and n+w > maxWords then flush() end
      table.insert(cur, sent); n = n + w
    end
  end
  flush()
  if #chunks==0 then chunks = {text} end
  -- don't leave a tiny last chunk (e.g. 5 words) on its own: merge it into the previous one
  if #chunks>1 and select(2, chunks[#chunks]:gsub("%S+","")) < 40 then
    chunks[#chunks-1] = chunks[#chunks-1].." "..chunks[#chunks]; chunks[#chunks] = nil end
  return chunks
end
M.splitChunks = splitChunks

-- clean text chunk by chunk (async, sequential); done(cleanedOrNil, stats)
-- style: optional override (history re-conversion); such runs ignore the dictation cancel flag
local function cleanText(raw, done, progress, style)
  local gen = M.LIVE.gen
  local sty = style or cfg.style
  local chunks = splitChunks(raw, 250)
  local outs, stats = {}, { chunks=#chunks, fallbacks=0, failed=0, t0=hs.timer.secondsSinceEpoch() }
  local model = M._modelOverride or M.activeModel()
  if not model then stats.noModel, stats.failed, stats.secs = true, #chunks, 0; log("cleanup skipped: no Ollama model installed/running"); return done(nil, stats) end
  local function step(i)
    if not style and not M._testing and (M.jobStale(gen) or cancelled) then return done(nil, stats, true) end
    if i > #chunks then
      stats.secs = hs.timer.secondsSinceEpoch()-stats.t0
      if stats.failed == #chunks then return done(nil, stats) end
      return done(table.concat(outs, sty=="paragraphs" and "\n\n" or (sty=="bullets" and "\n" or " ")), stats)
    end
    if progress then progress(i, #chunks) end
    local c, tc = chunks[i], hs.timer.secondsSinceEpoch()
    local body = hs.json.encode({ model=model, prompt=buildPrompt(c, sty), stream=false, think=false, keep_alive=cfg.ollamaKeepAlive, options={ temperature=0.1, num_ctx=8192 } })
    hs.http.asyncPost(cfg.ollamaURL, body, {["Content-Type"]="application/json"}, function(code, resp)
      local out
      if code == 200 then local ok,j=pcall(hs.json.decode,resp); if ok and j and j.response then out=j.response end end
      if out then out = out:gsub("<think>.-</think>",""):gsub("^%s+",""):gsub("%s+$","") end
      log(string.format("cleanup %s ["..sty.."] chunk %d/%d code %s %.1fs", model, i, #chunks, tostring(code), hs.timer.secondsSinceEpoch()-tc))
      if out and out~="" then
        if sty=="bullets" then out = normBullets(out) end
        if sty=="formal" then out = stripSalutation(c, out) end
        local bad = checkOutput(c, out, sty)
        if bad then log("cleanup chunk "..i.." rejected ("..bad.."), using raw"); stats.fallbacks = stats.fallbacks+1; out=nil end
      end
      if not out or out=="" then if code~=200 then stats.failed=stats.failed+1 end; out = c end
      outs[i] = out
      step(i+1)
    end)
  end
  step(1)
end
M.cleanText = cleanText

-- ---------- history re-conversion (Light / Paragraphs / Bullets / Formal) ----------
local function styleName(st) return T("style_"..st) end
M.converting = {}   -- entry table -> style being produced
-- re-run cleanup on an entry's RAW text in another style; raw stays unchanged. cb(ok, text) optional
function M.restyle(e, style, cb)
  if not e or not STYLE[style] or M.converting[e] then return end
  if not e.raw or e.raw:match("^%s*$") then hs.alert.show(T("nothing_convert")); return end
  M.converting[e] = style; if pushState then pushState() end
  cleanText(e.raw, function(out, st)
    M.converting[e] = nil
    local ok = out and not out:match("^%s*$") and st.failed < st.chunks
    log(string.format("restyle %s -> %s: %s, %d chunk(s), %d fallback(s), %.1fs", e.time or "?", style, ok and "ok" or "FAILED", st.chunks, st.fallbacks, st.secs or 0))
    if ok then
      out = applyWords(out, cfg.customWords):gsub("^%s+",""):gsub("%s+$","")
      e.cleaned, e.style = out, style
      saveHistory()
      hs.pasteboard.setContents(out)
      hs.alert.show(T("converted", styleName(style))..(st.fallbacks>0 and T("parts_raw", st.fallbacks) or ""))
    elseif st.noModel then hs.alert.show(T("styles_need_model"))
    else hs.alert.show(T("conv_failed")) end
    refresh()
    if cb then cb(ok, out) end
  end, nil, style)
end

local warnedNoModel = false
local function cleanup(raw)
  local gen = M.LIVE.gen
  local model = M.activeModel()
  if not model then
    if not warnedNoModel then warnedNoModel = true; hs.alert.show(T("cleanup_unavail"), 4) end
    log("cleanup skipped: no Ollama model; pasting raw"); return finish(raw, nil, gen)
  end
  M._cleaning = true
  setOverlay(T("ov_cleaning"), T("ov_fixing", model), true)
  cleanText(raw, function(out, st, wasCancelled)
    if M.jobStale(gen) then return end
    M._cleaning = false
    if wasCancelled or cancelled then state="idle"; hideOverlay(); refresh(); return end
    M.LIVE.tCleanup = st.secs or 0
    log(string.format("cleanup done: %d chunk(s), %d fallback(s), %d failed, %.1fs", st.chunks, st.fallbacks, st.failed, st.secs or 0))
    if st.failed==st.chunks then hs.alert.show(T("cleanup_failed"))
    elseif st.fallbacks>0 and st.chunks==1 then hs.alert.show(T("cleanup_too_much"))
    elseif st.fallbacks>0 then hs.alert.show(T("parts_kept", st.fallbacks, st.chunks)) end
    if not out or out:match("^%s*$") then finish(raw, nil, gen) else finish(raw, (applyWords(out, cfg.customWords)), gen) end
  end, function(i, n)
    if n>1 then setOverlay(T("ov_cleaning_part", i, n), T("ov_fixing", model), true) end
  end)
end

-- ---------- silence and hallucination guard ----------
-- On silence Whisper can invent text: "Thanks for watching", "Subtítulos realizados por la
-- comunidad de Amara.org", Japanese "ご視聴ありがとうございました", Cyrillic… Nothing is pasted then.
-- 1. Before Whisper the recording is measured with sox "stats" (a few ms). It is skipped when
--    its loudest 50 ms ("RMS Pk dB") is below SILENT_RMSPK, or when it is quiet (below
--    FLAT_MAX_RMSPK) and flat (loudest minus quietest under FLAT_RANGE_DB: room noise only).
-- 2. After Whisper: text with no letters is dropped. When the dictation language is English or
--    Español, text that is mostly non-Latin script is retried once with the other one (es / en)
--    and dropped if that is not usable. In Auto nothing is filtered by script: Auto works in
--    about 99 languages (Japanese, Russian, Arabic… are real dictations there).
-- 3. Output that is only a known silence phrase is dropped when the audio was quiet / short.
M.SILENT_RMSPK = -40     -- dBFS; normal speech measures about -14 to -20, a quiet room about -32
M.QUIET_RMSPK = -30      -- below this, "Thank you." / "Gracias." alone count as silence phrases
M.SHORT_SECS = 8
M.FLAT_MAX_RMSPK = -28; M.FLAT_RANGE_DB = 6
function M.parseStats(txt)
  local function num(label) local v = (txt or ""):match(label.."%s+(%-?[%w%.]+)"); if v == "-inf" then return -200 end; return tonumber(v) end
  return { pk = num("Pk lev dB"), rms = num("RMS lev dB"), rmsPk = num("RMS Pk dB"), rmsTr = num("RMS Tr dB"), len = num("Length s") }
end
function M.levelsText(lv) lv = lv or {}
  return string.format("len %.1fs, peak %s dB, RMS %s dB, loudest %s dB, quietest %s dB", lv.len or 0, tostring(lv.pk), tostring(lv.rms), tostring(lv.rmsPk), tostring(lv.rmsTr)) end
-- true when the recording is effectively silent (unknown levels = not silent)
function M.isSilent(lv)
  if not lv or not lv.rmsPk then return false end
  if lv.len and lv.len < 0.3 then return true end
  if lv.rmsPk < M.SILENT_RMSPK then return true end
  if lv.rmsTr and lv.rmsPk < M.FLAT_MAX_RMSPK and (lv.rmsPk - lv.rmsTr) < M.FLAT_RANGE_DB then return true end
  return false
end
-- letters in Latin script vs other scripts (Greek, Cyrillic, Arabic, Hebrew, Indic, Thai, CJK, kana, hangul…)
function M.scriptCounts(s)
  local lat, other = 0, 0
  pcall(function()
    for _, c in utf8.codes(s or "") do
      if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 0xC0 and c <= 0x24F and c ~= 0xD7 and c ~= 0xF7) or (c >= 0x1E00 and c <= 0x1EFF) then lat = lat + 1
      elseif (c >= 0x370 and c <= 0x1DFF) or (c >= 0x3040 and c <= 0x9FFF) or (c >= 0xAC00 and c <= 0xD7AF) or (c >= 0xF900 and c <= 0xFAFF) or (c >= 0xFF66 and c <= 0xFF9F) then other = other + 1 end
    end
  end)
  return lat, other
end
function M.mostlyNonLatin(s) local lat, other = M.scriptCounts(s); return other > 0 and other >= lat end
function M.hasLetters(s) local lat, other = M.scriptCounts(s); return (lat + other) > 0 end
-- the script filter only applies when the dictation language is English or Español
function M.scriptFilterOn(lang) lang = lang or cfg.language or "auto"; return lang == "en" or lang == "es" end
-- whole output is only a phrase Whisper makes up on silence
M.HALLU_STRONG = { "thanks for watching", "thank you for watching", "thanks for watching and see you next time", "please subscribe",
  "gracias por ver", "gracias por ver el video", "gracias por su atencion", "subtitulos realizados por la comunidad de amara org",
  "subtitulos por la comunidad de amara org", "subtitles by the amara org community", "amara org", "subtitulado por la comunidad de amara org" }
M.HALLU_WEAK = { "thank you", "thanks", "gracias", "you", "bye", "adios", "chau", "hasta luego", "muchas gracias", "ok", "okay", "hmm", "mm" }
-- the same in other scripts (Auto mode), compared without spaces and punctuation; only when quiet
M.HALLU_OTHER = { "ご視聴ありがとうございました", "ご清聴ありがとうございました", "продолжениеследует", "спасибозапросмотр",
  "字幕由amaraorg社区提供", "请不吝点赞订阅转发打赏支持明镜与点点栏目" }
local function squash(s)
  s = (s or ""):lower():gsub("[%s%p]", "")
  for _, p in ipairs({ "。", "、", "！", "？", "…", "「", "」", "，" }) do s = s:gsub(p, "") end
  return s
end
function M.isHallucination(text, lv)
  local quiet = lv and lv.rmsPk and lv.rmsPk < M.QUIET_RMSPK
  local short = lv and lv.len and lv.len < M.SHORT_SECS
  local w = table.concat(wordsOf(text), " ")
  if w ~= "" then
    for _, p in ipairs(M.HALLU_STRONG) do if w == p and (quiet or short) then return true end end
    for _, p in ipairs(M.HALLU_WEAK) do if w == p and quiet then return true end end
  end
  if quiet then local q = squash(text); for _, p in ipairs(M.HALLU_OTHER) do if q == p then return true end end end
  return false
end
-- "ok", "empty", "hallucination" or "script" (mostly non-Latin while the language is English / Español)
function M.judgeRaw(text, lv, lang)
  text = text or ""
  if not M.hasLetters(text) then return "empty" end
  if M.scriptFilterOn(lang) and M.mostlyNonLatin(text) then return "script" end
  if M.isHallucination(text, lv) then return "hallucination" end
  return "ok"
end
-- share of a text's words that are common words of the language (0..1)
function M.langFit(text, lang)
  local set = lang == "en" and EN_W or ES_W
  local w = wordsOf(text); if #w == 0 then return 0 end
  local n = 0; for _, x in ipairs(w) do if set[x] then n = n + 1 end end
  return n / #w
end
-- languages to retry with when the output was mostly non-Latin (the one already used is skipped)
function M.retryLangs(lang)
  local out = {}
  for _, l in ipairs({ "es", "en" }) do if l ~= lang then out[#out+1] = l end end
  return out
end
-- best of the forced-language retries, or nil
function M.pickRetry(cands, lv)
  local best, bestScore
  for _, c in ipairs(cands) do
    if M.judgeRaw(c.text, lv, c.lang) == "ok" then
      local sc = M.langFit(c.text, c.lang) + #wordsOf(c.text) * 0.001
      if not bestScore or sc > bestScore then best, bestScore = c, sc end
    end
  end
  return best
end
function M.nothingHeard(why)
  log("nothing heard ("..why.."): nothing pasted")
  M.liveEndSession()
  state = "idle"; if tick then tick:stop() end; hideOverlay(); clearSession(); M._recovering = false
  M.clearVoiceFlags()
  if M._dry then M._dryResult = "" end
  refresh(); hs.alert.show(T("nothing_heard"), 2)
end
-- ---------- quiet-tail trim and trailing phrase guard ----------
-- After he stops talking there are often a few quiet seconds before Stop & Paste. Whisper fills
-- that quiet with "Thank you." / "Gracias." / "Thanks for watching". Before Whisper the recording
-- is cut to the sound plus a margin (sox "silence" both ways, threshold from the room's own
-- noise floor: quietest + 10 dB, at least loudest - 18 dB, between -48 and -30 dB). Sound means 50 ms above the threshold,
-- so mouth clicks do not count. If anything about the trim fails, the original file is used.
-- After Whisper (timestamps on), a last segment that is only such a phrase is removed when it
-- starts after the last sound, or when its own time window has no voice. Each removal is logged.
M.TRIM = { ABOVE = "0.05", HEAD = 0.3, TAIL = 0.5, MIN_CUT = 0.3, MIN_SPEECH = 0.3, VOICE_DB = 4, file = DATA.."/tmp/rec-trim.wav" }
function M.trimThreshold(lv)
  local tr, pk = lv and lv.rmsTr, lv and lv.rmsPk
  if not tr or tr < -90 then tr = -58 end            -- unknown or digital silence
  local t = tr + 10                                   -- room noise floor + 10 dB
  if pk and pk > -90 then t = math.max(t, pk - 18) end  -- a moment of digital silence must not pull it below the room noise
  t = math.max(-48, math.min(-30, t))
  if pk and pk > -90 then t = math.min(t, pk - 12) end  -- always well under the voice
  return t
end
-- len = whole file, a = length left after cutting the quiet start, b = after cutting the quiet end
function M.trimPlan(len, a, b)
  local K = M.TRIM
  if not (len and a and b) or a <= 0 or b <= 0 or a > len + 0.05 or b > len + 0.05 then return nil end
  local s0, s1 = math.max(0, len - a), math.min(len, b)   -- first and last sound
  if s1 - s0 < K.MIN_SPEECH then return nil end
  local start = math.max(0, s0 - K.HEAD); if start < K.MIN_CUT then start = 0 end
  local stop = math.min(len, s1 + K.TAIL); if len - stop < K.MIN_CUT then stop = len end
  return { start = start, stop = stop, cut = (start > 0 or stop < len), speechEnd = s1 - start, len = stop - start, cutHead = start, cutTail = len - stop }
end
-- cb(path, plan): the trimmed copy, or the original file (plan nil) when trimming is not possible
function M.trimSilence(file, lv, cb)
  local sox = (cfg.rec or ""):gsub("rec$", "sox")
  if sox == "" or not fileExists(sox) or not lv or not lv.len or lv.len < 1 then cb(file, nil); return end
  local thr = M.trimThreshold(lv); local thrS = string.format("%.1fd", thr)
  local done = false
  local function fin(p, plan) if done then return end; done = true; M.trimTask = nil; cb(p, plan) end
  local script = '"$0" "$1" -n silence 1 '..M.TRIM.ABOVE..' "$2" stats 2>&1; echo "=="; "$0" "$1" -n reverse silence 1 '..M.TRIM.ABOVE..' "$2" stats 2>&1'
  M.trimTask = hs.task.new("/bin/sh", function(_, so, se)
    if done then return end
    local txt = (so or "")..(se or "")
    local p1, p2 = txt:match("^(.-)==(.*)$")
    local a = p1 and tonumber(p1:match("Length s%s+([%d%.]+)")); local b = p2 and tonumber(p2:match("Length s%s+([%d%.]+)"))
    local plan = M.trimPlan(lv.len, a, b)
    if not plan then log(string.format("trim: no clear sound above %s, using the whole recording", thrS)); fin(file, nil); return end
    plan.thr = thr
    if not plan.cut then fin(file, plan); return end
    os.remove(M.TRIM.file)
    M.trimTask = hs.task.new(sox, function(code)
      local sz = (hs.fs.attributes(M.TRIM.file) or {}).size or 0
      if code == 0 and sz > 44 + 3200 then
        log(string.format("trim: kept %.2f-%.2fs of %.2fs (cut %.2fs quiet start, %.2fs quiet end, threshold %s)", plan.start, plan.stop, lv.len, plan.cutHead, plan.cutTail, thrS))
        fin(M.TRIM.file, plan)
      else log("trim: sox failed, using the whole recording"); fin(file, nil) end
    end, { file, M.TRIM.file, "trim", string.format("%.3f", plan.start), string.format("=%.3f", plan.stop) })
    if not M.trimTask:start() then log("trim: sox did not start"); fin(file, nil) end
  end, { "-c", script, sox, file, thrS })
  if not M.trimTask:start() then fin(file, nil); return end
  after(8, function() if not done then if M.trimTask then M.trimTask:terminate() end; log("trim: timed out, using the whole recording"); fin(file, nil) end end)
end
-- whisper-cli stdout with timestamps -> text, segments {from, to, text} (plain lines are kept too)
function M.parseWhisper(out)
  local segs, plain = {}, {}
  for raw in ((out or "").."\n"):gmatch("([^\n]*)\n") do
    local line = raw:gsub("%[BLANK_AUDIO%]", "")
    local h1, m1, s1, h2, m2, s2, txt = line:match("^%s*%[(%d+):(%d+):([%d%.]+)%s*%-%->%s*(%d+):(%d+):([%d%.]+)%]%s?(.*)$")
    if h1 then
      txt = (txt:gsub("^%s+", ""):gsub("%s+$", ""))
      segs[#segs+1] = { from = h1*3600 + m1*60 + tonumber(s1), to = h2*3600 + m2*60 + tonumber(s2), text = txt }
    elseif line:match("%S") then plain[#plain+1] = (line:gsub("^%s+", ""):gsub("%s+$", "")) end
  end
  if #segs == 0 then return (#plain > 0 and " "..table.concat(plain, " ") or ""), segs end
  return M.joinSegs(segs, #segs), segs
end
function M.joinSegs(segs, upto)
  local t = {}
  for i = 1, upto do if segs[i].text:match("%S") then t[#t+1] = segs[i].text end end
  return #t > 0 and " "..table.concat(t, " ") or ""
end
M.TAIL_PHRASES = { "thank you", "thank you very much", "thank you so much", "thanks", "thanks for watching", "thank you for watching",
  "thanks for listening", "thank you for listening", "thanks for watching and see you next time", "please subscribe", "bye", "bye bye", "you",
  "gracias", "muchas gracias", "gracias por ver", "gracias por ver el video", "gracias por su atencion", "gracias por escuchar",
  "gracias por vernos", "hasta la proxima", "nos vemos", "subtitulos realizados por la comunidad de amara org",
  "subtitulos por la comunidad de amara org", "subtitulado por la comunidad de amara org", "subtitles by the amara org community", "amara org" }
-- index and phrase of a last segment that is only a tail phrase, with real text before it
function M.tailPhrase(segs)
  segs = segs or {}
  local n = #segs; while n > 0 and not M.hasLetters(segs[n].text) do n = n - 1 end
  if n < 2 then return nil end
  local w = table.concat(wordsOf(segs[n].text), " ")
  for _, p in ipairs(M.TAIL_PHRASES) do
    if w == p then for i = 1, n - 1 do if M.hasLetters(segs[i].text) then return n, p end end; return nil end
  end
  return nil
end
-- cb(text): text with a made-up trailing phrase removed, or unchanged
function M.tailGuard(text, segs, file, plan, cb)
  local n = M.tailPhrase(segs)
  if not n then cb(text); return end
  local s = segs[n]
  local function drop(why) log(string.format('tail guard: removed trailing "%s" [%.2f-%.2fs] (%s)', s.text, s.from, s.to, why)); cb(M.liveDropTail(text, segs, n)) end
  local function keep(why) log(string.format('tail guard: kept trailing "%s" [%.2f-%.2fs] (%s)', s.text, s.from, s.to, why)); cb(text) end
  if plan and plan.speechEnd and s.from >= plan.speechEnd - 0.1 then drop(string.format("starts after the last sound at %.2fs", plan.speechEnd)); return end
  local sox = (cfg.rec or ""):gsub("rec$", "sox")
  if sox == "" or not fileExists(sox) then keep("cannot measure"); return end
  local thr = (plan and plan.thr) or M.trimThreshold(M._lv)
  local done = false
  local t = hs.task.new(sox, function(_, so, se)
    if done then return end; done = true
    local lv = M.parseStats((se or "")..(so or ""))
    if lv.rmsPk and lv.rmsPk < thr + M.TRIM.VOICE_DB then drop(string.format("no voice in its window: loudest %.1f dB, voice needs %.1f dB", lv.rmsPk, thr + M.TRIM.VOICE_DB))
    else keep(lv.rmsPk and string.format("voice in its window: loudest %.1f dB", lv.rmsPk) or "window not measurable") end
  end, { file, "-n", "trim", string.format("%.3f", s.from), string.format("%.3f", math.max(0.1, s.to - s.from)), "stats" })
  if not t:start() then done = true; keep("sox did not start"); return end
  after(5, function() if not done then done = true; t:terminate(); keep("measuring timed out") end end)
end
-- timestamps stay on: with -nt Whisper drops words that cross its 30 s window and gives no segments
-- never pass -tr: Taipea does not translate
local function whisperArgs(f, lang)
  local a = { "-m", modelPath(), "-l", lang or cfg.language, "-np" }
  local hint = whisperHint()
  if M.LIVE and M.LIVE.promptOverride and M.LIVE.promptOverride ~= "" then
    hint = (hint and (hint.." ") or "")..M.LIVE.promptOverride
  end
  if hint then a[#a+1] = "--prompt"; a[#a+1] = hint end
  a[#a+1] = "-f"; a[#a+1] = f
  return a
end
M.whisperArgs = whisperArgs

function M.liveCleanupDir(dir)
  if type(dir) ~= "string" or dir == "" then return false end
  local base = DATA.."/tmp/"
  if dir:sub(1, #base) ~= base then return false end
  local name = dir:sub(#base + 1)
  if not name:match("^s%d+$") then return false end
  if not hs.fs.attributes(dir) then return false end
  for f in hs.fs.dir(dir) do
    if f ~= "." and f ~= ".." then pcall(os.remove, dir.."/"..f) end
  end
  pcall(hs.fs.rmdir, dir)
  if not hs.fs.attributes(dir) then log("live:cleanup "..name); return true end
  return false
end
function M.liveSweep(keep)
  local tmp = DATA.."/tmp"
  if not hs.fs.attributes(tmp) then return 0 end
  keep = keep or ""
  local n = 0
  for name in hs.fs.dir(tmp) do
    if type(name) == "string" and name:match("^s%d+$") then
      local d = tmp.."/"..name
      if d ~= keep and M.liveCleanupDir(d) then n = n + 1 end
    end
  end
  return n
end
function M.liveEndSession()
  local dir = M.LIVE and M.LIVE.dir or nil
  if M.LIVE then M.LIVE.dir = nil end
  return M.liveCleanupDir(dir)
end
function M.liveSessionDir(gen) return DATA.."/tmp/s"..tostring(gen or 0) end
function M.liveFallbackWhy(why) return why end
function M.liveStale(gen) return M.LIVE.gen ~= gen or M.LIVE.fallback ~= nil end
function M.liveBacklog(len, nextFrom)
  return ((len or 0) - (nextFrom or 0)) > (M.LIVE.FALLBACK_SECS or 40)
end
function M.livePendingFrom()
  local L = M.LIVE
  if L.cur and L.cur.from then return L.cur.from end
  local q = L.queue
  if q and q[1] and q[1].from then return q[1].from end
  return L.nextFrom or 0
end
-- remove a trailing hallucinated segment from joined live text (full-file path: same as joinSegs)
function M.liveDropTail(text, segs, n)
  n = n or M.tailPhrase(segs)
  if not n then return text end
  local k = #wordsOf((segs[n] and segs[n].text) or "")
  if k == 0 then return M.joinSegs(segs, n - 1) end
  local nW, seen, out = 0, 0, {}
  for _, tk in ipairs(tokens(text or "")) do if tk.w then nW = nW + 1 end end
  local keep = nW - k
  if keep < 0 then return M.joinSegs(segs, n - 1) end
  for _, tk in ipairs(tokens(text or "")) do
    if tk.w then seen = seen + 1; if seen > keep then break end end
    out[#out+1] = tk.t
  end
  return table.concat(out):gsub("%s+$", "")
end
function M.liveWindows(len, slice, overlap)
  slice = slice or M.LIVE.SLICE; overlap = overlap or M.LIVE.OVERLAP
  local step = slice - overlap
  local w = {}
  len = len or 0
  if len <= 0 then return w end
  if len <= slice then w[1] = { from = 0, to = len, last = true }; return w end
  local from = 0
  while from + slice < len - 0.001 do
    w[#w+1] = { from = from, to = from + slice, last = false }
    from = from + step
  end
  w[#w+1] = { from = from, to = len, last = true }
  return w
end
function M.liveShiftSegs(segs, off)
  local o = {}
  for i, s in ipairs(segs or {}) do o[i] = { from = s.from + off, to = s.to + off, text = s.text } end
  return o
end
function M.liveTimingLine(t)
  t = t or {}
  return string.format("timing: T_rec=%.2f T_live_sum=%.2f T_stop_to_raw=%.2f T_cleanup=%.2f T_stop_to_paste=%.2f",
    t.rec or 0, t.live or 0, t.raw or 0, t.cleanup or 0, t.paste or 0)
end
function M.liveJoin(a, b)
  a = (a or ""):gsub("^%s+", ""):gsub("%s+$", "")
  b = (b or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if a == "" then return b, 0, false end
  if b == "" then return a, 0, false end
  local aw, bw = wordsOf(a), wordsOf(b)
  local k = 0
  for n = math.min(#aw, #bw), 1, -1 do
    local ok = true
    for i = 1, n do if aw[#aw - n + i] ~= bw[i] then ok = false; break end end
    if ok then k = n; break end
  end
  local weak = k < 2
  if k == 0 then return a.." "..b, 0, true end
  local nA, seen, out = 0, 0, {}
  for _, tk in ipairs(tokens(a)) do if tk.w then nA = nA + 1 end end
  local keep = nA - k
  if keep <= 0 then
    -- keep A's wording for a pure-overlap left side; append B after the overlap
    local rest, skip = {}, 0
    for _, tk in ipairs(tokens(b)) do
      if tk.w then skip = skip + 1 end
      if skip > k then rest[#rest+1] = tk.t end
    end
    local r = table.concat(rest):gsub("^%s+", "")
    if r == "" then return a, k, weak end
    return a:gsub("%s+$", "")..(r:match("^%p") and "" or " ")..r, k, weak
  end
  for _, tk in ipairs(tokens(a)) do
    if tk.w then seen = seen + 1; if seen > keep then break end end
    out[#out+1] = tk.t
  end
  local prefix = table.concat(out):gsub("%s+$", "")
  if prefix == "" then return b, k, weak end
  local sep = prefix:match("%S$") and b:match("^%S") and " " or ""
  return prefix..sep..b, k, weak
end
function M.liveKillTasks()
  if M.trimTask then local t = M.trimTask; M.trimTask = nil; pcall(function() t:terminate() end) end
  if M.lvTask then local t = M.lvTask; M.lvTask = nil; pcall(function() t:terminate() end) end
  if M.wTask then local t = M.wTask; M.wTask = nil; pcall(function() t:terminate() end) end
  M.LIVE.task, M.LIVE.cur = nil, nil
end
function M.liveReset(on)
  local L = M.LIVE
  L.gen = (L.gen or 0) + 1
  L.on = on and true or false
  L.dir = M.liveSessionDir(L.gen)
  L.queue, L.joined, L.fallback, L.cur = {}, "", nil, nil
  L.nextFrom, L.snapN, L.tWork = 0, 0, 0
  L.lastSegs, L.lastFile, L.lastPlan, L.lastTail, L.lastOk = nil, nil, nil, nil, false
  L.finishing, L.promptOverride = false, nil
  L.stopT0, L.tRaw, L.tCleanup, L.tRec0 = nil, nil, nil, hs.timer.secondsSinceEpoch()
  M.liveSweep(L.dir)
  if not hs.fs.attributes(L.dir) then pcall(hs.fs.mkdir, L.dir) end
  return L.gen
end
function M.liveBegin()
  local gen = M.liveReset(cfg.liveTranscribe ~= false)
  wav = M.LIVE.dir.."/rec.wav"
  M.TRIM.file = M.LIVE.dir.."/rec-trim.wav"
  os.remove(wav); os.remove(M.TRIM.file)
  return gen
end
function M.liveLogTimes()
  local L = M.LIVE
  if not L.stopT0 then return end
  local now = hs.timer.secondsSinceEpoch()
  log(M.liveTimingLine({
    rec = (L.tRec0 and (L.stopT0 - L.tRec0)) or 0,
    live = L.tWork or 0,
    raw = L.tRaw and (L.tRaw - L.stopT0) or 0,
    cleanup = L.tCleanup or 0,
    paste = now - L.stopT0,
  }))
end
function M.liveFallback(why)
  why = M.liveFallbackWhy(why or "error")
  log("live:fallback "..why)
  M.LIVE.fallback = why
  M.LIVE.on = false
  M.LIVE.finishing = false
  M.liveKillTasks()
  -- during rec the wav is still growing; transcribe the finished file on stop
  if state ~= "rec" then transcribe(wav) end
end
function M.liveAfterSlices(lv, gen)
  if M.liveStale(gen) then return end
  M._lv = lv
  if M.isSilent(lv) then M.nothingHeard("silent recording, "..M.levelsText(lv)); return end
  local text, segs, file, plan = M.LIVE.joined or "", M.LIVE.lastSegs, M.LIVE.lastFile, M.LIVE.lastPlan
  local function go(t2)
    if M.liveStale(gen) then return end
    M.LIVE.tRaw = hs.timer.secondsSinceEpoch()
    M.afterRaw(t2, file)
  end
  if segs and file then M.tailGuard(text, segs, file, plan, go) else go(text) end
end
function M.liveMeasureThenFinish(gen)
  if M.liveStale(gen) then return end
  local file = wav
  local sox = (cfg.rec or ""):gsub("rec$", "sox")
  if sox ~= "" and fileExists(sox) and not M._voicePrefix then
    local done = false
    local function next_(lv)
      if done then return end; done = true; M.lvTask = nil
      if M.liveStale(gen) then return end
      if lv then log("levels: "..M.levelsText(lv)) end
      M.liveAfterSlices(lv, gen)
    end
    M.lvTask = hs.task.new(sox, function(_, so, se) next_(M.parseStats((se or "")..(so or ""))) end, { file, "-n", "stats" })
    if not M.lvTask:start() then M.lvTask = nil; next_(nil) end
    after(5, function() if not done then if M.lvTask then M.lvTask:terminate(); M.lvTask = nil end; log("levels: sox timed out"); next_(nil) end end)
  else M.liveAfterSlices(nil, gen) end
end
function M.liveCopyWav(src, dest)
  local inf = io.open(src or "", "rb"); if not inf then return false end
  local data = inf:read("*a"); inf:close()
  if not data or #data < 44 then return false end
  local out = io.open(dest, "wb"); if not out then return false end
  out:write(data); out:close()
  return M.fixWavHeader(dest) and true or fileExists(dest)
end
function M.liveSlicePath(n) return (M.LIVE.dir or (DATA.."/tmp")).."/slice-"..tostring(n)..".wav" end
function M.liveOnSlice(item, code, out, t0)
  local gen = item.gen
  -- only release handles this slice still owns, so a killed slice cannot wipe a newer Whisper run
  if M.wTask == item.task then M.wTask = nil end
  if M.LIVE.task == item.task then M.LIVE.task = nil end
  if M.LIVE.cur == item then M.LIVE.cur = nil end
  M.LIVE.tWork = (M.LIVE.tWork or 0) + (hs.timer.secondsSinceEpoch() - (t0 or hs.timer.secondsSinceEpoch()))
  if M.liveStale(gen) then return end
  if code ~= 0 then log("live:fallback whisper"); M.liveFallback("whisper"); return end
  local text, segs = M.parseWhisper(out)
  local lv = { rmsPk = -14, rmsTr = -40, len = (item.to - item.from) }
  local j = M.judgeRaw(text, lv, cfg.language or "auto")
  if j == "empty" or j == "hallucination" then text, segs = "", {}
  elseif j == "script" and M.scriptFilterOn(cfg.language) then
    -- keep the text; afterRaw on the join retries the last file if the whole output is still bad
  end
  if text:match("%S") then
    local joined, k, weak = M.liveJoin(M.LIVE.joined, text)
    if weak then log("live:seam:weak k="..tostring(k)) end
    M.LIVE.joined = joined
    local w = wordsOf(text)
    local tail, n = {}, math.min(20, #w)
    for i = #w - n + 1, #w do tail[#tail+1] = w[i] end
    M.LIVE.lastOk, M.LIVE.lastTail = true, table.concat(tail, " ")
  else M.LIVE.lastOk = false end
  if item.last then M.LIVE.lastSegs, M.LIVE.lastFile = segs, item.file end
  M.livePump(gen)
end
function M.liveRunSlice(item)
  local gen = item.gen
  if M.liveStale(gen) then return end
  M.LIVE.cur = item
  local src = wav
  M.LIVE.snapN = (M.LIVE.snapN or 0) + 1
  local snap = (M.LIVE.dir or DATA.."/tmp").."/snap-"..M.LIVE.snapN..".wav"
  local dest = M.liveSlicePath(M.LIVE.snapN)
  if not M.liveCopyWav(src, snap) then M.liveFallback("copy"); return end
  local sox = (cfg.rec or ""):gsub("rec$", "sox")
  local dur = math.max(0.05, (item.to or 0) - (item.from or 0))
  local function go(file)
    if M.liveStale(gen) then return end
    item.file = file
    M.LIVE.promptOverride = (M.LIVE.lastOk and M.LIVE.lastTail) or nil
    local t0 = hs.timer.secondsSinceEpoch()
    M.wTask = hs.task.new(cfg.whisper, function(code, out)
      M.LIVE.promptOverride = nil
      M.liveOnSlice(item, code, out, t0)
    end, whisperArgs(file))
    item.task = M.wTask
    M.LIVE.task = M.wTask
    if not M.wTask:start() then M.wTask = nil; M.LIVE.task = nil; M.liveFallback("whisper-start") end
  end
  if sox == "" or not fileExists(sox) or ((item.from or 0) <= 0 and math.abs((item.to or 0) - wavSeconds(snap)) < 0.05) then
    os.rename(snap, dest); go(dest); return
  end
  os.remove(dest)
  M.trimTask = hs.task.new(sox, function(code)
    M.trimTask = nil
    if M.liveStale(gen) then return end
    if code == 0 and fileExists(dest) then go(dest) else M.liveFallback("trim") end
  end, { snap, dest, "trim", string.format("%.3f", item.from), string.format("%.3f", dur) })
  if not M.trimTask:start() then M.trimTask = nil; M.liveFallback("trim") end
end
function M.livePump(gen)
  if M.liveStale(gen) then return end
  if M.wTask or M.LIVE.task or M.trimTask then return end
  local q = M.LIVE.queue
  if q and #q > 0 then
    local item = table.remove(q, 1)
    M.liveRunSlice(item)
    return
  end
  if M.LIVE.finishing then M.liveMeasureThenFinish(gen) end
end
function M.liveEnqueue(from, to, last, gen)
  M.LIVE.queue[#M.LIVE.queue+1] = { from = from, to = to, last = last, gen = gen }
end
function M.liveTick()
  if not M.LIVE.on or M.LIVE.finishing or state ~= "rec" then return end
  local len, slice, overlap = wavSeconds(wav), M.LIVE.SLICE, M.LIVE.OVERLAP
  if M.liveBacklog(len, M.livePendingFrom()) then M.liveFallback("backlog"); return end
  local nextFrom = M.LIVE.nextFrom or 0
  if len >= nextFrom + slice then
    M.liveEnqueue(nextFrom, nextFrom + slice, false, M.LIVE.gen)
    M.LIVE.nextFrom = nextFrom + (slice - overlap)
    M.livePump(M.LIVE.gen)
  end
end
function M.liveOnStop()
  local gen = M.LIVE.gen
  local len = wavSeconds(wav)
  if M.LIVE.fallback then transcribe(wav); return end
  if M.liveBacklog(len, M.livePendingFrom()) then M.liveFallback("backlog"); return end
  M.LIVE.finishing = true
  local from = M.LIVE.nextFrom or 0
  if len > from + 0.05 then M.liveEnqueue(from, len, true, gen)
  elseif M.LIVE.joined == "" then M.liveEnqueue(0, math.max(len, 0.1), true, gen)
  else
    -- last completed slice is the tail
    if not M.LIVE.lastFile then M.LIVE.lastSegs = nil end
  end
  M.livePump(gen)
end
function M.benchPlan(path)
  return { secs = M.wavSeconds(path), windows = M.liveWindows(M.wavSeconds(path)), live = (cfg.liveTranscribe ~= false) }
end
-- test hook: whisper + cleanup on a file, no paste/history. cb(result table)
function M.testPipeline(f, cb)
  M._testing = true
  local t0 = hs.timer.secondsSinceEpoch()
  M.testTask = hs.task.new(cfg.whisper, function(code, out)
    local tw = hs.timer.secondsSinceEpoch()-t0
    out = M.parseWhisper(out)
    cleanText(out, function(cl, st)
      M._testing = false
      cb({ whisperExit=code, whisperSecs=tw, raw=out, cleaned=cl, stats=st })
    end)
  end, whisperArgs(f))
  M.testTask:start()
end

local function afterWhisper(out)
  local gen = M.LIVE.gen
  if M.abortIfDone(gen) then return end
  out = polishRaw(out)
  if not out:match("^%s*$") then saveSession({ phase="cleaning", wav=M._sessWav, raw=out }) end
  if cfg.cleanup and not out:match("^%s*$") then cleanup(out) else finish(out, nil, gen) end
end
M.afterWhisper = afterWhisper
-- Whisper's raw text: paste it, retry with the language forced, or drop it (silence)
function M.afterRaw(out, file)
  local gen = M.LIVE.gen
  if M.abortIfDone(gen) then return end
  local lv = M._lv
  if M._voicePrefix then M.afterWhisper(out); return end
  local lang = cfg.language or "auto"
  local j = M.judgeRaw(out, lv, lang)
  if j == "ok" then M.afterWhisper(out); return end
  if j == "script" and file then
    local langs = M.retryLangs(lang)
    log("whisper gave mostly non-Latin text with -l "..lang..", retrying with -l "..table.concat(langs, ", -l "))
    setOverlay(T("ov_transcribing"), T("ov_check_lang"), true)
    local cands = {}
    local function run(i)
      local l = langs[i]
      if not l then
        local b = M.pickRetry(cands, lv)
        if b then log("retry kept -l "..b.lang..": "..b.text); M.afterWhisper(b.text) else M.nothingHeard("non-Latin text, retry gave nothing usable") end
        return
      end
      M.wTask = hs.task.new(cfg.whisper, function(code, o)
        M.wTask = nil
        if M.abortIfDone(gen) then return end
        o = M.parseWhisper(o)
        log(string.format("whisper retry -l %s exit %d RAW: %s", l, code, o))
        if code == 0 then cands[#cands+1] = { lang = l, text = o } end
        run(i + 1)
      end, whisperArgs(file, l))
      if not M.wTask:start() then M.wTask = nil; run(i + 1) end
    end
    run(1); return
  end
  M.nothingHeard(j == "script" and "non-Latin text" or j)
end
transcribe = function(file)
  file = file or wav; M._sessWav = file
  local gen = M.LIVE.gen
  M._wdKick = true
  if not cfg.whisper or not fileExists(cfg.whisper) then M.watchdogReset("whisper-cli not found", T("wd_nowhisper")); return end
  local sz = (hs.fs.attributes(file) or {}).size or 0
  if sz <= 44 + 3200 then   -- header + 0.1 s of audio
    if M.jobStale(gen) then return end
    log("watchdog: recording empty ("..sz.." bytes), back to idle")
    M.clearVoiceFlags()
    M.liveEndSession()
    state = "idle"; if tick then tick:stop() end; hideOverlay(); clearSession(); M._recovering = false; refresh()
    M.micProblem(T("wd_empty")); return
  end
  saveSession({ phase="transcribing", wav=file })
  state="busy"; refresh(); setOverlay(T("ov_transcribing"), cfg.modelName:gsub("^ggml%-",""):gsub("%.bin$","").." ("..cfg.language..")", true)
  local t0 = hs.timer.secondsSinceEpoch()
  recStart = t0
  local tsub = cfg.modelName:gsub("^ggml%-",""):gsub("%.bin$","")
  if tick then tick:stop() end
  tick = hs.timer.doEvery(1, function() if M.wTask then setOverlay(T("ov_still"), tsub, true) elseif state=="busy" then
    if overlay then local e=math.floor(hs.timer.secondsSinceEpoch()-recStart); overlay:evaluateJavaScript(string.format("document.getElementById('t').textContent=%q", string.format("%d:%02d",e//60,e%60))) end end end)
  local function go()
  M.trimSilence(file, M._lv, function(wfile, plan)
  if M.abortIfDone(gen) then return end
  M.wTask = hs.task.new(cfg.whisper, function(code, out, err)
    M.wTask = nil
    if M.abortIfDone(gen) then return end
    M.LIVE.tRaw = hs.timer.secondsSinceEpoch()
    log(string.format("whisper %s exit %d %.1fs RAW: %s", cfg.modelName, code, hs.timer.secondsSinceEpoch()-t0, out or ""))
    if code ~= 0 then
      M.clearVoiceFlags()
      M.keepAudioForRecovery(file)
      M.liveEndSession()
      state="idle"; hideOverlay(); M._recovering = false; M.checkRecovery(); refresh()
      hs.alert.show(T("trans_failed"))
      return
    end
    local text, segs = M.parseWhisper(out)
    M.tailGuard(text, segs, wfile, plan, function(t2)
      if M.abortIfDone(gen) then return end
      M.afterRaw(t2, wfile)
    end)
  end, whisperArgs(wfile))
  if not M.wTask:start() then M.wTask = nil; M.watchdogReset("whisper-cli did not start", T("wd_reset")) end
  end)
  end
  -- measure the recording first (sox stats, a few ms); a silent one is not sent to Whisper
  M._lv = nil
  local sox = (cfg.rec or ""):gsub("rec$", "sox")
  if sox ~= "" and fileExists(sox) and not M._voicePrefix then
    local done = false
    local function next_(lv)
      if done then return end; done = true
      if M.abortIfDone(gen) then return end
      M._lv = lv
      if lv then log("levels: "..M.levelsText(lv)) end
      if M.isSilent(lv) then M.nothingHeard("silent recording, "..M.levelsText(lv)); return end
      go()
    end
    M.lvTask = hs.task.new(sox, function(_, so, se) M.lvTask = nil; next_(M.parseStats((se or "")..(so or ""))) end, { file, "-n", "stats" })
    if not M.lvTask:start() then M.lvTask = nil; next_(nil) end
    after(5, function() if not done then if M.lvTask then M.lvTask:terminate(); M.lvTask = nil end; log("levels: sox timed out"); next_(nil) end end)
  else go() end
end

M.transcribeFile = function(f) return transcribe(f) end   -- test hook

-- load the cleanup model in the background (same num_ctx as cleanup, or Ollama reloads it)
function M.warmModel(model)
  model = model or M.activeModel()
  if not model then return end
  hs.http.asyncPost(cfg.ollamaURL, hs.json.encode({model=model, prompt="", keep_alive=cfg.ollamaKeepAlive, options={ num_ctx=8192 }}),
    {["Content-Type"]="application/json"}, function() end)
end
-- returns nil when dictation can run, else a friendly message
local function preflight()
  if not cfg.rec then return T("need_sox") end
  if not cfg.whisper then return T("need_whisper") end
  if not fileExists(modelPath()) then return T("need_model", keyLabel(cfg.historyKey)) end
  return nil
end
M.preflight = preflight
function M.start()
  if state ~= "idle" then return end
  do local why = preflight(); if why then hs.alert.show(why, 6); log("cannot start: "..why); return end end
  targetApp = hs.application.frontmostApplication()
  if targetApp and targetApp:bundleID()=="org.hammerspoon.Hammerspoon" then targetApp = M.lastApp end
  M.lastApp = targetApp
  cancelled, mode = false, (cfg.defaultAction=="copy" and "copy" or "paste")
  M.liveBegin()
  local gen = M.LIVE.gen
  os.remove(wav)
  saveSession({ phase="recording", wav=wav, started=os.date("%F %T") })
  local args = { "-q", "-c", "1", "-r", "16000", "-b", "16", wav }
  if cfg.autoStop then
    for _,a in ipairs({"silence","1","0.1",cfg.silenceThreshold,"1",tostring(cfg.silenceSeconds),cfg.silenceThreshold}) do table.insert(args,a) end
  end
  for _,a in ipairs({"trim","0",tostring(cfg.maxSeconds)}) do table.insert(args,a) end
  local recCmd; recCmd, args = M.recCmdArgs(args)
  if M._simInput then recCmd = cfg.rec:gsub("rec$","sox"); args = { M._simInput, "-c", "1", "-r", "16000", "-b", "16", wav } end  -- test hook
  recTask = hs.task.new(recCmd, function()
    recTask = nil
    if state=="rec" then
      state="busy"; sound("Pop")
      M.LIVE.stopT0 = hs.timer.secondsSinceEpoch()
      after(0.2, function()
        if cancelled or M.jobStale(gen) then return end
        if M.LIVE.on then M.liveOnStop() else transcribe() end
      end)
    end
  end, args)
  showOverlay()
  recTask:start(); state="rec"; recStart=hs.timer.secondsSinceEpoch()
  sound("Tink")
  if cfg.cleanup then after(0.5, function() M.warmModel() end) end
  local sub = cfg.autoStop and T("ov_autostop", tostring(cfg.silenceSeconds)) or T(cfg.escStop ~= false and "ov_press_esc" or "ov_press", keyLabel(cfg.toggleKey))
  if M.voiceActive() and (cfg.stopPhrases or {})[1] then sub = T("ov_say_stop", cfg.stopPhrases[1]) end
  after(0.3, function() setOverlay(T("ov_listening"), sub, false) end)
  tick = hs.timer.doEvery(1, function() if state=="rec" then setOverlay(T("ov_listening"), sub, false); if M.LIVE.on then M.liveTick() end end end)
  after(0, refresh)
end
function M.stop(m)
  if state ~= "rec" then return end
  local gen = M.LIVE.gen
  mode = m or "paste"; state="busy"; sound("Pop")
  M.LIVE.stopT0 = hs.timer.secondsSinceEpoch()
  if recTask then recTask:interrupt() end
  after(0.3, function()
    if cancelled or M.jobStale(gen) then return end
    if M.LIVE.on then M.liveOnStop() else transcribe() end
  end); refresh()
end
function M.cancel()
  cancelled = true; clearSession(); M._recovering = false; M._cleaning = false
  M.clearVoiceFlags()
  M.LIVE.gen = (M.LIVE.gen or 0) + 1; M.LIVE.on = false; M.LIVE.finishing = false
  if recTask then local t=recTask; recTask=nil; state="busy"; t:interrupt() end
  M.liveKillTasks()
  M.liveEndSession()
  state="idle"; if tick then tick:stop() end; hideOverlay(); sound("Basso"); refresh()
  if targetApp then targetApp:activate() end
end
function M.toggle() if state=="idle" then M.start() elseif state=="rec" then M.stop(cfg.defaultAction=="copy" and "copy" or "paste") else hs.alert.show(T("still_processing")) end end
-- transcribe the audio (or text) an interrupted dictation left behind; result goes to the clipboard and History
function M.recover()
  local r = M.recoverable
  if not r then hs.alert.show(T("recover_none")); return end
  if state ~= "idle" then hs.alert.show(T("still_processing")); return end
  M.recoverable = nil
  M.LIVE.gen = (M.LIVE.gen or 0) + 1
  cancelled, mode, M._recovering = false, "copy", true
  targetApp = nil
  showOverlay(); recStart = hs.timer.secondsSinceEpoch()
  setOverlay(T("recovering"), "", true)
  if type(r.raw)=="string" and r.raw:match("%S") then
    state="busy"; refresh(); M._sessWav = r.wav
    if cfg.cleanup then cleanup(r.raw) else finish(r.raw, nil, M.LIVE.gen) end
  else fixWavHeader(r.wav); transcribe(r.wav) end
end
local function setOpt(k,v) cfg[k]=v; saved[k]=v; saveSettings(); refresh() end
M.setOpt = setOpt
function M.toggleMode() setOpt("cleanup", not cfg.cleanup); hs.alert.show(cfg.cleanup and T("mode_clean") or T("mode_raw")) end
function M.toggleAutoStop() setOpt("autoStop", not cfg.autoStop); hs.alert.show(cfg.autoStop and T("autostop_on") or T("autostop_off")) end

-- ---------- downloads ----------
local function dlWhisper(file)
  if downloads[file] and M.dlBusy(downloads[file]) then return end
  downloads[file] = T("starting"); refresh()
  local dest = DATA.."/models/"..file
  local url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"..file
  M["t_"..file] = hs.task.new("/usr/bin/curl", function(code)
    if code==0 then os.rename(dest..".part", dest); downloads[file]=nil; hs.alert.show(T("downloaded", file))
    else downloads[file]=T("failed", tostring(code)) ; os.remove(dest..".part") end
    refresh()
  end, function(_, _, err)
    local pct = err and err:match("(%d+%.%d)%s*$") or (err and err:match("(%d+%.%d)%%"))
    if pct then downloads[file]=pct.."%"; if pushState then pushState() end end
    return true
  end, { "-L", "-f", "-#", "-o", dest..".part", url })
  M["t_"..file]:start()
end
local function dlLLM(name)
  if downloads[name] and M.dlBusy(downloads[name]) then return end
  if not cfg.ollama then hs.alert.show(T("install_ollama")); return end
  downloads[name] = T("starting"); refresh()
  M["t_"..name] = hs.task.new(cfg.ollama, function(code)
    downloads[name] = (code==0) and nil or T("failed", tostring(code)); if code==0 then hs.alert.show(T("downloaded", name)) end
    ollamaInstalled(true); refresh()
  end, function(_, out, err)
    local s = (out or "")..(err or "")
    local pct = nil; for p in s:gmatch("(%d+)%%") do pct = p end
    if pct then downloads[name] = pct.."%"; if pushState then pushState() end end
    return true
  end, { "pull", name })
  M["t_"..name]:start()
end

-- ---------- mini app ----------
pushState = function()
  if not appWin or not appWin:isVisible() then return end
  local inst = ollamaInstalled()
  local wm, lm = {}, {}
  local known = {}
  for _,m in ipairs(WHISPER) do known[m.file]=true
    table.insert(wm, { file=m.file, name=m.name, size=m.size, note=(uiLang()=="es" and m.note_es or m.note), installed=fileExists(DATA.."/models/"..m.file) }) end
  for f in hs.fs.dir(DATA.."/models") do if f:match("%.bin$") and not known[f] then table.insert(wm,{file=f,name=f,size="",note=T("note_local"),installed=true}) end end
  if cfg.modelName:sub(1,1)=="/" and fileExists(cfg.modelName) then table.insert(wm,{file=cfg.modelName,name=(cfg.modelName:match("[^/]+$")),size="",note=T("note_custom"),installed=true}) end
  local knownL = {}
  for _,m in ipairs(LLMS) do knownL[m.name]=true; table.insert(lm, { name=m.name, size=m.size, note=(uiLang()=="es" and m.note_es or m.note), installed=inst[m.name] or false }) end
  for n,_ in pairs(inst) do if not knownL[n] and not n:match(":latest$") and not n:match("embed") then table.insert(lm,{name=n,size="",note=T("note_installed"),installed=true}) end end
  local conv = {}
  for i,e in ipairs(history) do if M.converting[e] then conv[tostring(i)] = M.converting[e] end end
  local axEn, axEs = M.axPaneNames()
  local mics = M.listMics()
  local data = { history=history, conv=conv, autoLaunch=hs.autoLaunch(), cfg={ checkForUpdates=(cfg.checkForUpdates~=false), openAtLogin=cfg.openAtLogin, showAtLogin=cfg.showAtLogin, cleanup=cfg.cleanup, style=cfg.style, language=cfg.language, defaultAction=cfg.defaultAction,
     autoStop=cfg.autoStop, silenceSeconds=cfg.silenceSeconds, silenceThreshold=cfg.silenceThreshold, modelName=cfg.modelName, ollamaModel=cfg.ollamaModel, uiSize=cfg.uiSize, uiLanguage=cfg.uiLanguage, showOverlay=cfg.showOverlay,
     voiceControl=cfg.voiceControl, startPhrases=cfg.startPhrases, stopPhrases=cfg.stopPhrases, floatButton=cfg.floatButton, cardWithFab=(cfg.cardWithFab==true), textSize=cfg.textSize, contrast=cfg.contrast, customWords=cfg.customWords,
     hideFullscreen=(cfg.hideFullscreen~=false), hideApps=cfg.hideApps, floatingTheme=fabTheme().id, escStop=(cfg.escStop~=false), micKey=(cfg.micKey==true),
     inputDevice=(cfg.inputDevice or ""), inputDeviceName=(cfg.inputDeviceName or ""),
     customBg=(isHex(cfg.customBg) and cfg.customBg or DEFAULTS.customBg), customMic=(isHex(cfg.customMic) and cfg.customMic or DEFAULTS.customMic), customAccent=(isHex(cfg.customAccent) and cfg.customAccent or DEFAULTS.customAccent) },
     look=look, perm={ ax=M.permAx, mic=M.micWarn, axPane=axEn, axPaneEs=axEs },
     mics=mics, micDefault=M.micDefaultName(), micActive=M.micActive(),
     upd={ cur=M.VERSION, latest=M.upd.latest or "", banner=M.updWanted(), on=(cfg.checkForUpdates~=false), checking=M.upd.checking, result=M.upd.result or "",
       last=(tonumber(saved.updLastCheck) and os.date("%Y-%m-%d %H:%M", tonumber(saved.updLastCheck)) or "") }, pal=M.palette(), fabThemes=FAB_THEMES, fabHidden=(fab and M._fabHidR or ""), fabSessionHidden=M.fabSessionHidden, runApps=M._runApps,
     recover=(M.recoverable and fmtSecs(M.recoverable.secs) or ""),
     voice={ active=M.voiceActive(), model=(vlModel():match("[^/]+$") or ""):gsub("^ggml%-",""):gsub("%.bin$","") },
     keys=M.keysMap(keyStr), keyLabels=M.keysMap(keyLabel), keySyms=M.keysMap(M.keySym), fabTapOK=(M.fabTapOK==true), micTapOK=(M.micTapOK==true),
     defaultKeys=M.keysMap(keyLabel, DEFAULTS), defaultSyms=M.keysMap(M.keySym, DEFAULTS), cap=(M.cap or false),
     lang=uiLang(), sysLang=sysLang,
     whisperModels=wm, llmModels=lm, dl=downloads, ollama=(cfg.ollama~=nil), activeModel=M.activeModel() or "", missing=preflight() or "" }
  local js = hs.json.encode(data)
  if next(downloads)==nil then js = js:gsub('"dl":%[%]','"dl":{}') end
  if next(conv)==nil then js = js:gsub('"conv":%[%]','"conv":{}') end
  if #(cfg.customWords or {})==0 then js = js:gsub('"customWords":{}','"customWords":[]') end
  if #(cfg.hideApps or {})==0 then js = js:gsub('"hideApps":{}','"hideApps":[]') end
  if #mics==0 then js = js:gsub('"mics":{}','"mics":[]') end
  appWin:evaluateJavaScript("render("..js..")")
end

function M.handle(a)
  local c = a.cmd
  local e = a.i and history[math.floor(a.i)]
  if c=="refresh" then ollamaInstalled(true); pushState()
  elseif c=="openAx" then M.openPerm(AX_URL)
  elseif c=="openMic" then M.openPerm(MIC_URL)
  elseif c=="hideMic" then M.micWarn = false; refresh()
  elseif c=="updCheck" then M.checkUpdates(true)
  elseif c=="updOpen" then M.updOpen()
  elseif c=="updLater" then M.updLater()
  elseif c=="updSkip" then M.updSkip()
  elseif c=="close" then appWin:hide(); if M.lastApp then M.lastApp:activate() end
  elseif c=="mini" then appWin:hide(); hs.alert.show(T("hidden", keyLabel(cfg.historyKey)))
  elseif c=="dictate" then if appWin then appWin:hide() end; after(0.3, function() if M.lastApp then M.lastApp:activate() end; after(0.3, M.start) end)
  elseif c=="copy" and e then hs.pasteboard.setContents(finalText(e)); hs.alert.show(T("copied"))
  elseif c=="copyRaw" and e then hs.pasteboard.setContents(e.raw); hs.alert.show(T("copied_raw"))
  elseif c=="paste" and e then appWin:hide(); doPaste(finalText(e), M.lastApp)
  elseif c=="restyle" and e then M.restyle(e, a.style)
  elseif c=="del" and e then table.remove(history, math.floor(a.i)); saveHistory(); refresh()
  elseif c=="clearHistory" then history = {}; saveHistory(); refresh(); hs.alert.show(T("history_cleared"))
  elseif c=="resetOverlay" then settings.set("taipea.overlayPos", nil); hs.alert.show(T("overlay_reset"))
  elseif c=="resetFab" then settings.set(KP.."fabPos", nil); if fab then fab:frame(fabFrame()) end; hs.alert.show(T("fab_reset"))
  elseif c=="pasteLast" then if appWin then appWin:hide() end; M.pasteLast(M.lastApp)
  elseif c=="recover" then if appWin then appWin:hide() end; M.recover()
  elseif c=="discardRecovery" then M.discardRecovery()
  elseif c=="wordsBad" then hs.alert.show(T("words_bad"))
  elseif c=="fabHideToggle" then M.toggleFabHidden()
  elseif c=="listApps" then
    local list, seen = {}, {}
    for _, ap in ipairs(hs.application.runningApplications()) do
      local id, nm = ap:bundleID(), ap:name()
      if ap:kind() == 1 and id and nm and id ~= "org.hammerspoon.Hammerspoon" and not seen[id] then seen[id] = true; list[#list+1] = { name = nm, id = id } end
    end
    table.sort(list, function(x, y) return x.name:lower() < y.name:lower() end)
    M._runApps = list; pushState()
  elseif c=="closeApps" then M._runApps = nil; pushState()
  elseif c=="hideAppAdd" or c=="hideAppDel" then
    local list = {}; for _, x in ipairs(cfg.hideApps or {}) do if type(x)=="table" then list[#list+1] = { name = x.name, id = x.id } end end
    if c=="hideAppAdd" then
      local nm, id = tostring(a.name or ""), tostring(a.id or "")
      local dup = appMatches({ name = nm, id = id }, list)
      if nm ~= "" and not dup then list[#list+1] = { name = nm, id = id }; hs.alert.show(T("hide_added", nm)) end
    else local i = a.i and math.floor(a.i); if i and list[i] then hs.alert.show(T("hide_removed", list[i].name or "")); table.remove(list, i) end end
    setOpt("hideApps", list); M.applyFabVis(); pushState()
  elseif c=="addWord" or c=="setWord" or c=="delWord" then
    local list = {}; for _,w in ipairs(cfg.customWords or {}) do list[#list+1] = { heard=w.heard, replace=w.replace } end
    local i = a.i and math.floor(a.i)
    local h, r = (a.heard or ""):gsub("^%s+",""):gsub("%s+$",""), (a.replace or ""):gsub("^%s+",""):gsub("%s+$","")
    if c=="delWord" then if i and list[i] then table.remove(list, i) end
    elseif h=="" or r=="" then hs.alert.show(T("words_bad")); pushState(); return
    elseif c=="addWord" then list[#list+1] = { heard=h, replace=r }
    elseif i and list[i] then list[i] = { heard=h, replace=r } end
    setOpt("customWords", list); hs.alert.show(T("words_saved"))
  elseif c=="capStart" then M.captureStart(a.key)
  elseif c=="capCancel" then M.captureCancel()
  elseif c=="capSave" then
    local cp = M.cap
    if not (cp and cp.phase=="result" and cp.spec and KD.BOUND[cp.target]) then return end
    local err = M.keyProblem(cp.target, cp.spec)
    if err then hs.alert.show(err); M.cap.err = err; pushState(); return end
    M.cap = nil; setOpt(cp.target, cp.spec); bindAll(); refresh(); hs.alert.show(T("shortcut_set", keyLabel(cp.spec))); pushState()
  elseif c=="resetKeys" then
    M.capStop(); M.cap = nil
    for _,k in ipairs(M.KEY_ACTIONS) do saved[k]=nil; cfg[k]=DEFAULTS[k] end
    saveSettings(); bindAll(); refresh(); hs.alert.show(T("shortcuts_reset"))
  elseif c=="dlWhisper" then dlWhisper(a.file)
  elseif c=="dlLLM" then dlLLM(a.name)
  elseif c=="set" then
    local k, v = a.key, a.value
    if KD.BOUND[k] then
      local pk = parseKey(v)
      if not pk then hs.alert.show(T("bad_shortcut", tostring(v))); pushState(); return end
      local err = M.keyProblem(k, pk)
      if err then hs.alert.show(err); pushState(); return end
      setOpt(k, pk); bindAll(); refresh(); hs.alert.show(T("shortcut_set", keyLabel(pk)))
    elseif k=="escStop" then setOpt(k, v and true or false); hs.alert.show(cfg.escStop and T("esc_on") or T("esc_off"))
    elseif k=="micKey" then setOpt(k, v and true or false); hs.alert.show(cfg.micKey and T("mic_on") or T("mic_off"))
    elseif k=="modelName" or k=="ollamaModel" then setOpt(k, v); hs.alert.show(T("using", v))
      if k=="ollamaModel" then M.warmModel(v) end
    elseif k=="openAtLogin" then setOpt(k, v); hs.autoLaunch(v and true or false)
      hs.alert.show(v and T("login_on") or T("login_off"))
    elseif k=="voiceControl" then setOpt(k, v and true or false); vlSync(); refresh()
      hs.alert.show(cfg.voiceControl and T("voice_on", (cfg.startPhrases or {})[1] or "") or T("voice_off"))
    elseif k=="inputDevice" then
      local uid, name, missing = tostring(v or ""), "", false
      if uid ~= "" then
        local ok, d = pcall(function() return hs.audiodevice.findDeviceByUID(uid) end)
        name = (ok and d and d:name()) or ""
        if name == "" then uid = ""; missing = true; log("inputDevice: unknown UID, using system default") end
      end
      saved.inputDeviceName = name; cfg.inputDeviceName = name
      setOpt("inputDevice", uid); M._micMissingLogged = nil
      hs.alert.show(missing and T("mic_missing") or (uid ~= "" and T("mic_set", name) or T("mic_default")))
      M.restartVoiceListener()
    elseif k=="floatButton" or k=="cardWithFab" then setOpt(k, v and true or false); showFab()
      if state == "rec" then if M.cardWanted() then showOverlay() else hideOverlay() end end
      if k=="floatButton" then hs.alert.show(cfg.floatButton and T("fab_on") or T("fab_off")) else hs.alert.show(cfg.cardWithFab and T("card_on") or T("card_off")) end
    elseif k=="floatingTheme" then
      local ok = false; for _, t in ipairs(FAB_THEMES) do if t.id == v then ok = true end end
      setOpt(k, ok and v or "classic"); M.fabUpdate(); M.overlayPal(); pushState()
    elseif k=="customBg" or k=="customMic" or k=="customAccent" then
      local col = normHex(v)
      if not col then hs.alert.show(T("color_bad")); pushState(); return end
      setOpt(k, col); M.fabUpdate(); M.overlayPal(); pushState()
    elseif k=="hideFullscreen" then setOpt(k, v and true or false); M.applyFabVis(); pushState()
    elseif k=="checkForUpdates" then setOpt(k, v and true or false); hs.alert.show(v and T("upd_on") or T("upd_off")); if v then M.checkUpdates(false) end; pushState()
    elseif k=="startPhrases" or k=="stopPhrases" then
      local list = type(v)=="table" and v or splitPhrases(v)
      if #list==0 then hs.alert.show(T("voice_need_phrase")); pushState(); return end
      setOpt(k, list); hs.alert.show(T("phrases_saved"))
    elseif k=="silenceSeconds" then local n = tonumber(v); if n and n>=1 and n<=30 then setOpt(k, n) end
    elseif k=="contrast" then setOpt(k, (v=="on" or v=="off") and v or "auto"); updateLook(); if overlay then overlay:delete(); overlay=nil end; M.fabUpdate(); pushState()
    elseif k=="uiSize" or k=="textSize" then
      if k=="uiSize" then setOpt(k, v=="compact" and "compact" or "normal")
      else setOpt(k, (v=="large" or v=="xlarge") and v or "normal"); updateLook(); if overlay then overlay:delete(); overlay=nil end; if fab then fab:frame(fabFrame()) end; M.fabUpdate() end
      if appWin then local f=appWin:frame(); local scr=screenFor(f); local sf=scr:frame()
        local nw = math.min((cfg.uiSize=="compact" and 520 or 760) * look.scale, sf.w-40)
        local nh = cfg.uiSize=="compact" and math.min(700, sf.h-80) or sf.h-80
        local nf = clampFrame({x=f.x, y=f.y, w=nw, h=nh}, scr); appWin:frame(nf); settings.set("taipea.appPos", {x=nf.x, y=nf.y}) end
      pushState()
    elseif k=="uiLanguage" then
      setOpt(k, (v=="en" or v=="es") and v or "auto")
      if overlay then overlay:delete(); overlay = nil end   -- rebuilt in the new language
      hs.alert.show(T("lang_set"))
    else setOpt(k, v) end
  end
end

function M.openApp()
  local front = hs.application.frontmostApplication()
  if front and front:bundleID() ~= "org.hammerspoon.Hammerspoon" then M.lastApp = front end
  if not appWin then
    local ap = settings.get("taipea.appPos")
    local scr = ap and screenFor({x=ap.x, y=ap.y, w=1, h=1}, {x=ap.x+20, y=ap.y+20}) or hs.screen.mainScreen()
    local sf = scr:frame()
    local w, h = math.min((cfg.uiSize=="compact" and 520 or 760) * look.scale, sf.w-40), cfg.uiSize=="compact" and math.min(700, sf.h-80) or sf.h-80
    ap = ap or {x=sf.x+(sf.w-w)/2, y=sf.y+30}
    appWin = hs.webview.new(clampFrame({x=ap.x, y=ap.y, w=w, h=h}), {}, uc)
      :windowStyle({"borderless","resizable"}):windowTitle("Taipea"):transparent(true):shadow(true):level(hs.drawing.windowLevels.normal)
      :allowTextEntry(true):deleteOnClose(false)
      :url("file://"..(DATA:gsub(" ","%%20")).."/ui/app.html")
  end
  do local nf = clampFrame(appWin:frame()); appWin:frame(nf)
    local sp = settings.get("taipea.appPos"); if sp and (sp.x~=nf.x or sp.y~=nf.y) then settings.set("taipea.appPos", {x=nf.x, y=nf.y}) end end
  appWin:level(hs.drawing.windowLevels.normal):show()
  after(0.1, function() local hw=appWin:hswindow(); if hw then hw:focus() end end)
  hs.application.get("org.hammerspoon.Hammerspoon"):activate()
  updateLook()
  M.axOK()
  after(0.5, pushState)
end
M.showHistory = M.openApp
function M.appWinRef() return appWin end
function M.js(s) if appWin then appWin:evaluateJavaScript(s) end end

bindAll = function()
  for _,h in ipairs(hk) do h:delete() end; hk = {}
  local acts = { toggleKey = M.toggle, toggleKey2 = M.toggle, modeKey = M.toggleMode, historyKey = M.openApp,
    pasteLastKey = function() M.pasteLast() end, fabHideKey = function() M.toggleFabHidden() end }
  M.bound, M.CHORDS = {}, {}
  local seen = {}
  for _, a in ipairs(M.KEY_ACTIONS) do
    local k = cfg[a]
    if type(k) == "table" and type(k.mods) == "table" then
      local s = keyStr(k)
      if seen[s] then log("shortcut "..a.." ("..s..") is the same as "..seen[s]..": bound once")
      elseif (k.key or "") == "" then
        if #KD.sort(k.mods) >= 2 then seen[s] = a; M.bound[KD.BOUND[a]] = k; M.CHORDS[#M.CHORDS+1] = M.newChord(keyLabel(k), KD.sort(k.mods), acts[a])
        else log("shortcut "..a.." ("..s.."): a single modifier can't be a shortcut, skipped") end
      else
        local ok, h = pcall(hs.hotkey.bind, k.mods, k.key, acts[a])
        if ok and h then seen[s] = a; M.bound[KD.BOUND[a]] = k; table.insert(hk, h) else log("shortcut "..a.." ("..s.."): could not bind") end
      end
    end
  end
  if M._capturing then for _, h in ipairs(hk) do if h.disable then h:disable() end end end
end
bindAll()
M.bindAll = bindAll
hs.urlevent.bind("taipea", function() M.openApp() end)
if hs.autoLaunch() ~= (cfg.openAtLogin and true or false) then hs.autoLaunch(cfg.openAtLogin and true or false) end
-- show window at startup only on a fresh launch shortly after login (not on config reload)
if cfg.showAtLogin and not hs.settings.get("taipea.reloading") then
  local up = tonumber((hs.execute("sysctl -n kern.boottime"):match("sec = (%d+)"))) or 0
  if os.time() - up < 600 then after(3, function() M.openApp() end) end
end
if cfg.cleanup then M.warmModel() end
M.checkRecovery()
M.liveSweep()
if M.recoverable then after(2, function() hs.alert.show(T("recover_offer"), 6) end); log("recovery offered ("..fmtSecs(M.recoverable.secs)..")") end
-- ---------- watchdog ----------
-- Checks every 5 s while processing. If transcription never started it starts it; if processing
-- runs past 60 s with nothing working (or past 180 s at all) it resets to idle and keeps the audio.
function M.watchdogReset(reason, msg)
  log("watchdog: "..reason.." – reset to idle, audio kept for recovery")
  M._cleaning = false
  M.clearVoiceFlags()
  local keep = M.keepAudioForRecovery()
  local function keepIt() if keep and fileExists(keep) then saveSession({ phase="recording", wav=keep, started=os.date("%F %T") }) end end
  cancelled = true
  M.LIVE.gen = (M.LIVE.gen or 0) + 1; M.LIVE.on = false; M.LIVE.finishing = false
  M.liveKillTasks()
  M.liveEndSession()
  if recTask then local t = recTask; recTask = nil; t:terminate() end
  state = "idle"; if tick then tick:stop() end; hideOverlay(); M._recovering = false
  M._wdBusy, M._wdKick = nil, false
  M.checkRecovery(); refresh()
  hs.alert.show(msg or T("wd_reset"), 8)
  -- a stopped whisper/recorder reports back a moment later and clears the session: save it again
  after(1.5, function() if state == "idle" then keepIt(); M.checkRecovery(); refresh() end end)
end
M._watchdog = hs.timer.doEvery(5, function()
  if state ~= "busy" then M._wdBusy, M._wdKick = nil, false; return end
  local now = hs.timer.secondsSinceEpoch()
  M._wdBusy = M._wdBusy or now
  local age = now - M._wdBusy
  local liveBusy = (M.LIVE and (M.LIVE.task or M.LIVE.finishing or M.trimTask or M.lvTask)) or M._cleaning
  if not M._wdKick and not M.wTask and not recTask and not liveBusy and age >= 4 and not M._recovering then
    M._wdKick = true; log("watchdog: transcription never started, starting it now"); transcribe(); return
  end
  if (age > 60 and not M.wTask and not liveBusy) or age > 180 then M.watchdogReset(string.format("processing for %.0f s", age)) end
end)

-- ---------- update check (GitHub latest release) ----------
-- The only network request Taipea makes besides model downloads. At startup (after 30 s) and every
-- 24 h it asks https://api.github.com/repos/<updateRepo>/releases/latest for the newest release and,
-- if it is newer than VERSION, shows a banner in the window, a menu item and one notification per
-- version. Nothing is downloaded or run: the button only opens the GitHub release page. Errors are
-- only logged. Turn it off in Settings › Updates or with checkForUpdates = false in config.lua.
local VERSION = "0.2.12"
M.VERSION = VERSION
local function parseVer(s)
  if type(s) ~= "string" then return nil end
  local a, b, c = s:match("^%s*[vV]?(%d+)%.(%d+)%.?(%d*)")
  if not a then return nil end
  return { tonumber(a), tonumber(b), tonumber(c ~= "" and c or "0") }
end
-- 1 = a newer than b, -1 = older, 0 = same, nil = a version can't be read
local function verCmp(a, b)
  local x, y = parseVer(a), parseVer(b)
  if not x or not y then return nil end
  for i = 1, 3 do if x[i] ~= y[i] then return x[i] > y[i] and 1 or -1 end end
  return 0
end
-- only github.com links are opened; anything else becomes the repo's releases page
local function relURL(repo) return "https://github.com/"..tostring(repo).."/releases/latest" end
local function safeURL(u, repo)
  if type(u) == "string" and u:match("^https://github%.com/[%w%-%._]+/[%w%-%._]+/releases/") and not u:find("[%s\"'<>]") then return u end
  return relURL(repo)
end
M.parseVer, M.verCmp, M.safeURL = parseVer, verCmp, safeURL
local U = { latest = saved.updLatest, url = saved.updUrl, result = nil, checking = false }
M.upd, M.updSaved = U, saved
-- show the banner / menu item? (newer, not skipped, not in a "remind me later" pause)
function M.updWanted(now)
  now = now or os.time()
  if not U.latest or (verCmp(U.latest, VERSION) or 0) <= 0 then return false end
  if saved.updSkip == U.latest then return false end
  if tonumber(saved.updRemindUntil) and now < tonumber(saved.updRemindUntil) then return false end
  return true
end
-- handle GitHub's answer (separate from the request so it can be tested)
function M.updResult(code, body, manual)
  U.checking = false
  saved.updLastCheck = os.time()
  local ok, j = false, nil
  if code == 200 and type(body) == "string" then ok, j = pcall(hs.json.decode, body) end
  local tag = ok and type(j) == "table" and type(j.tag_name) == "string" and j.tag_name or nil
  local cmp = tag and verCmp(tag, VERSION)
  if cmp == nil then
    U.result = "err"; log("update check: couldn't check (HTTP "..tostring(code)..")")
  else
    local v = tag:gsub("^%s*[vV]", "")
    U.latest, U.url = v, safeURL(j.html_url, cfg.updateRepo)
    saved.updLatest, saved.updUrl = U.latest, U.url
    U.result = cmp > 0 and "new" or "ok"
    log("update check: latest v"..v..", this is v"..VERSION..(cmp > 0 and " → update available" or " → up to date"))
    if cmp > 0 and M.updWanted() and saved.updNotified ~= v then
      saved.updNotified = v
      pcall(function() hs.notify.new(function() M.openApp() end, { title = T("upd_note_t", v), informativeText = T("upd_note_b") }):send() end)
    end
  end
  saveSettings()
  if manual then
    hs.alert.show(U.result == "new" and T("upd_new", U.latest) or U.result == "ok" and T("upd_none", VERSION) or T("upd_err"), 4)
  end
  if refresh then refresh() end
end
function M.checkUpdates(manual)
  if not manual and cfg.checkForUpdates == false then return false end
  if U.checking then return false end
  U.checking = true
  if manual and pushState then pushState() end
  local url = "https://api.github.com/repos/"..tostring(cfg.updateRepo).."/releases/latest"
  hs.http.asyncGet(url, { ["User-Agent"] = "Taipea/"..VERSION.." (update check)", ["Accept"] = "application/vnd.github+json" },
    function(code, body) M.updResult(code, body, manual) end)
  return true
end
function M.updOpen() hs.urlevent.openURL(safeURL(U.url, cfg.updateRepo)) end
function M.updLater() saved.updRemindUntil = os.time() + 7*24*3600; saveSettings(); hs.alert.show(T("upd_later")); refresh() end
function M.updSkip() if U.latest then saved.updSkip = U.latest; saveSettings(); hs.alert.show(T("upd_skipped", U.latest)) end; refresh() end
if M._updT0 then M._updT0:stop() end
if M._updT then M._updT:stop() end
M._updT0 = hs.timer.doAfter(30, function() M.checkUpdates(false) end)
M._updT = hs.timer.doEvery(24*3600, function() M.checkUpdates(false) end)
showFab()
M.permSync()
if not M.permAx then log("permission: Accessibility OFF at startup"); after(2.5, function() if not M.permAx then hs.alert.show(T("perm_ax_start"), 10) end end) end
log("Taipea loaded · whisper="..tostring(cfg.whisper).." rec="..tostring(cfg.rec).." ollama="..tostring(cfg.ollama).." model="..cfg.modelName..
  " · voice="..tostring(cfg.voiceControl).." floatButton="..tostring(cfg.floatButton).." card="..tostring(M.cardWanted()).." customWords="..#(cfg.customWords or {}))
refresh()
return M
