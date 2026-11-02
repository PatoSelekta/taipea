-- Taipea ("it types for you"): hands-free, 100% local dictation for macOS.
-- Hammerspoon module. https://selektdev.com · MIT License
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
  toggleKey   = { mods = {"ctrl","alt"}, key = "space" },  -- start / stop dictation
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
  restoreClipboard = true,
  autoStop    = false,
  silenceSeconds = 2.5,
  silenceThreshold = "1.5%",
  historyMax  = 500,
  openAtLogin = true, showAtLogin = false,
  showOverlay = true,                        -- floating panel with big buttons while recording
  style = "light",                           -- light | paragraphs | bullets | formal
  language = "auto",                         -- dictation language: auto (EN/ES mix) | en | es
  uiLanguage = "auto",                       -- interface language: auto (macOS language) | en | es
  defaultAction = "paste",                   -- after stopping: paste | copy
  uiSize = "normal",                         -- normal | compact
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
  k_ctrl="Ctrl", k_alt="Option", k_cmd="Cmd", k_shift="Shift", k_space="Space",
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
  k_ctrl="Ctrl", k_alt="Opción", k_cmd="Cmd", k_shift="Mayús", k_space="Espacio",
 },
}
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
M.STR, M.T, M.uiLang, M.systemLang = STR, T, uiLang, systemLang
M.cfg, M.DEFAULTS = cfg, DEFAULTS
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

-- ---------- paste ----------
local function doPaste(text, app)
  local old = hs.pasteboard.readAllData()
  hs.pasteboard.setContents(text)
  if app then app:activate() end
  hs.timer.doAfter(0.25, function()
    hs.eventtap.keyStroke({"cmd"}, "v", 0)
    if cfg.restoreClipboard and old then hs.timer.doAfter(0.6, function() hs.pasteboard.writeAllData(old) end) end
  end)
end

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
  local k = cfg.uiSize=="compact" and 0.75 or 1
  local w, h = OW*k, OH*k
  if p then return clampFrame({ x=p.x, y=p.y, w=w, h=h }) end
  return { x=sf.x+(sf.w-w)/2, y=sf.y+60, w=w, h=h }
end
local function overlayHTML() return [[
<html lang="]]..uiLang()..[["><head><meta charset="utf-8"><style>
*{box-sizing:border-box}html,body{width:100%;height:100%;margin:0;background:transparent!important}
body{font:600 22px -apple-system;color:#fff;overflow:hidden;-webkit-user-select:none}
#panel{width:100%;height:100%;background:rgba(25,25,30,.95);border-radius:18px;overflow:hidden;cursor:move}
#panel button{cursor:pointer}
#top{display:flex;align-items:center;gap:14px;padding:18px 22px 6px;cursor:move}
#dot{width:30px;height:30px;border-radius:50%;background:#ff3b30;animation:p 1s infinite}
.busy #dot{background:#ffcc00;animation:s 1s linear infinite;border-radius:6px}
@keyframes p{0%,100%{transform:scale(.7);opacity:.6}50%{transform:scale(1.1);opacity:1}}
@keyframes s{to{transform:rotate(360deg)}}
#t{margin-left:auto;font-variant-numeric:tabular-nums;color:#ccc}
#sub{padding:0 22px;font:400 16px -apple-system;color:#aaa;height:22px}
#b{display:flex;gap:10px;padding:16px;width:100%}
button{flex:1;min-width:0;height:110px;border:0;border-radius:14px;font:700 21px -apple-system;color:#fff;cursor:pointer}
#stop{background:#34c759;flex:1.4}#copy{background:#0a84ff}#cancel{background:#ff453a}
button:hover{filter:brightness(1.2)} .busy button{opacity:.35;pointer-events:none}
.busy #cancel{opacity:1;pointer-events:auto}
</style></head><body><div id=panel>
<div id=top><div id=dot></div><div id=st>]]..T("ov_listening")..[[</div><div id=t>0:00</div></div>
<div id=sub></div>
<div id=b><button id=stop onclick="s('stop')">]]..T("ov_stop")..[[</button><button id=copy onclick="s('copy')">]]..T("ov_copy")..[[</button><button id=cancel onclick="s('cancel')">]]..T("ov_cancel")..[[</button></div></div>
<script>document.documentElement.style.zoom=window.__tpZoom||1;function s(a){webkit.messageHandlers.taipea.postMessage(a)}
document.getElementById('panel').addEventListener('mousedown',e=>{if(e.button===0&&!e.target.closest('button')){e.preventDefault();s({cmd:'dragOverlay'})}});
function upd(st,t,sub,busy){document.getElementById('st').textContent=st;document.getElementById('t').textContent=t;
document.getElementById('sub').textContent=sub;document.body.className=busy?'busy':''}</script></body></html>]] end

-- ---------- hotkeys ----------
local hk = {}
-- "ctrl+alt+space" (editable form) and "Ctrl + Option + Space" (shown to people)
local function keyStr(k) local m={}; for _,x in ipairs(k.mods) do table.insert(m, x) end; table.insert(m,k.key); return table.concat(m,"+") end
local function keyLabel(k)
  local m={}
  for _,x in ipairs(k.mods) do table.insert(m, T("k_"..x)) end
  table.insert(m, k.key=="space" and T("k_space") or k.key:upper())
  return table.concat(m," + ")
end
M.keyStr, M.keyLabel = keyStr, keyLabel
local function parseKey(s)
  local parts = {}; for p in (s or ""):lower():gsub("%s",""):gmatch("[^+]+") do table.insert(parts,p) end
  if #parts < 2 then return nil end
  local key = table.remove(parts); local mods={}
  local map={ctrl="ctrl",control="ctrl",alt="alt",option="alt",opt="alt",cmd="cmd",command="cmd",shift="shift"}
  for _,p in ipairs(parts) do if not map[p] then return nil end; table.insert(mods,map[p]) end
  if not hs.keycodes.map[key] then return nil end
  return { mods=mods, key=key }
end
local bindAll
-- ---------- app window push ----------
local pushState
local function onMsg(m)
  local a = m.body
  if a=="stop" then M.stop(cfg.defaultAction=="copy" and "copy" or "paste") elseif a=="copy" then M.stop("copy") elseif a=="cancel" then M.cancel()
  elseif type(a)=="table" and a.cmd=="dragStart" then M.startAppDrag()
  elseif type(a)=="table" and a.cmd=="dragOverlay" then M.startOverlayDrag()
  elseif type(a)=="table" then M.handle(a) end
end
-- window drag: poll mouse until left button released (works with head mice that send no drag events)
local function startDrag(w, key)
  if not w then return end
  if M._dragEnd then M._dragEnd() end
  local p0, f0 = hs.mouse.absolutePosition(), w:frame()
  local n, timer, upTap = 0, nil, nil
  local function finishDrag()
    if timer then timer:stop(); timer = nil end
    if upTap then upTap:stop(); upTap = nil end
    M._appDragTimer, M._dragEnd = nil, nil
    local nf = clampFrame(w:frame()); w:frame(nf); settings.set(key, {x=nf.x, y=nf.y})
  end
  M._dragEnd = finishDrag
  -- end on the real mouse-up event too: checkMouseButtons() reads hardware state and can miss
  -- releases sent by assistive/head-mouse software, which left the window following the pointer
  upTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseUp}, function() hs.timer.doAfter(0, finishDrag); return false end)
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
  if cfg.showOverlay == false then return end
  if not overlay then
    overlay = hs.webview.new(overlayFrame(), {}, uc)
      :windowStyle({"borderless","nonactivating"}):level(hs.drawing.windowLevels.floating)
      :allowTextEntry(false):transparent(true):shadow(true)
      :behavior(hs.drawing.windowBehaviors.canJoinAllSpaces + hs.drawing.windowBehaviors.stationary)
      :html(overlayHTML())
  end
  overlay:frame(overlayFrame()):show()
  overlay:evaluateJavaScript("window.__tpZoom="..(cfg.uiSize=="compact" and 0.75 or 1)..";document.documentElement.style.zoom=window.__tpZoom")
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
local function clip(s,n) s=(s or ""):gsub("\n"," "); if #s>n then return s:sub(1,n).."…" end; return s end
refresh = function()
  local icon = state=="rec" and "🔴" or (state=="busy" and "⏳" or "🎙")
  menu:setTitle(icon..(cfg.cleanup and "" or " raw")); menu:setTooltip("Taipea")
  local items = {
    { title = T("menu_open"), fn = function() M.openApp() end },
    { title = "-" },
    { title = (state=="rec" and T("menu_stop") or T("menu_start")).."  ("..keyLabel(cfg.toggleKey)..")", fn = function() M.toggle() end },
    { title = T("menu_cleanup").."  ("..keyLabel(cfg.modeKey)..")", checked = cfg.cleanup, fn = function() M.toggleMode() end },
    { title = T("menu_autostop", tostring(cfg.silenceSeconds)), checked = cfg.autoStop, fn = function() M.toggleAutoStop() end },
    { title = "-" },
  }
  local sub = {}
  for i=1, math.min(10,#history) do
    local e = history[i]
    table.insert(sub, { title = e.time:sub(12,16).."  "..clip(finalText(e),60), fn = function() hs.pasteboard.setContents(finalText(e)); hs.alert.show(T("copied")) end })
  end
  if #sub>0 then table.insert(items, { title = T("menu_recent"), menu = sub }) end
  table.insert(items, { title = T("menu_log"), fn = function() hs.execute("open '"..logf.."'") end })
  menu:setMenu(items)
  if pushState then pushState() end
end

-- ---------- pipeline ----------
local function finish(raw, cleaned)
  state="idle"; if tick then tick:stop() end; hideOverlay()
  local text = ((cleaned or raw) or ""):gsub("^%s+",""):gsub("%s+$","")
  if text == "" then hs.alert.show(T("no_speech")); refresh(); return end
  addHistory((raw or ""):gsub("^%s+",""):gsub("%s+$",""), cleaned and text or nil)
  refresh()
  if cancelled then return end
  if mode=="copy" then hs.pasteboard.setContents(text); hs.alert.show(T("copied_clip")); log("COPIED: "..text)
  else doPaste(text, targetApp); log("PASTED: "..text) end
end

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
    return STYLE[style]..STYLE_RULES..STYLE_EX[style].."\n\nTEXT:\n"..raw.."\n\n"..LANG_HINT[guessLang(raw)]..STYLE_GO[style]
  end
  return "You are a dictation editor. "..STYLE.light.." "..
  "CRITICAL: never translate. Every word stays in the language it was spoken in; if the speaker switches between Spanish and English mid-sentence, keep that switch exactly, including small English words like because, but, so. Never change names or places (Cartagena stays Cartagena). "..
  "Do not add new ideas, do not answer questions in the text. Remove only filler sounds (eh, um); keep every real word, even if repeated. Output ONLY the resulting text, no quotes or comments.\n"..
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
  for l in (t.."\n"):gmatch("(.-)\n") do
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
  local sty = style or cfg.style
  local chunks = splitChunks(raw, 250)
  local outs, stats = {}, { chunks=#chunks, fallbacks=0, failed=0, t0=hs.timer.secondsSinceEpoch() }
  local model = M._modelOverride or M.activeModel()
  if not model then stats.noModel, stats.failed, stats.secs = true, #chunks, 0; log("cleanup skipped: no Ollama model installed/running"); return done(nil, stats) end
  local function step(i)
    if cancelled and not M._testing and not style then return done(nil, stats, true) end
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
      out = out:gsub("^%s+",""):gsub("%s+$","")
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
  local model = M.activeModel()
  if not model then
    if not warnedNoModel then warnedNoModel = true; hs.alert.show(T("cleanup_unavail"), 4) end
    log("cleanup skipped: no Ollama model; pasting raw"); return finish(raw, nil)
  end
  setOverlay(T("ov_cleaning"), T("ov_fixing", model), true)
  cleanText(raw, function(out, st, wasCancelled)
    if wasCancelled or cancelled then state="idle"; hideOverlay(); refresh(); return end
    log(string.format("cleanup done: %d chunk(s), %d fallback(s), %d failed, %.1fs", st.chunks, st.fallbacks, st.failed, st.secs or 0))
    if st.failed==st.chunks then hs.alert.show(T("cleanup_failed"))
    elseif st.fallbacks>0 and st.chunks==1 then hs.alert.show(T("cleanup_too_much"))
    elseif st.fallbacks>0 then hs.alert.show(T("parts_kept", st.fallbacks, st.chunks)) end
    if not out or out:match("^%s*$") then finish(raw, nil) else finish(raw, out) end
  end, function(i, n)
    if n>1 then setOverlay(T("ov_cleaning_part", i, n), T("ov_fixing", model), true) end
  end)
end

local function whisperArgs(f) return { "-m", modelPath(), "-l", cfg.language, "-nt", "-np", "-f", f } end
-- test hook: whisper + cleanup on a file, no paste/history. cb(result table)
function M.testPipeline(f, cb)
  M._testing = true
  local t0 = hs.timer.secondsSinceEpoch()
  M.testTask = hs.task.new(cfg.whisper, function(code, out)
    local tw = hs.timer.secondsSinceEpoch()-t0
    out = (out or ""):gsub("%[BLANK_AUDIO%]",""):gsub("\n"," ")
    cleanText(out, function(cl, st)
      M._testing = false
      cb({ whisperExit=code, whisperSecs=tw, raw=out, cleaned=cl, stats=st })
    end)
  end, whisperArgs(f))
  M.testTask:start()
end

local function transcribe()
  state="busy"; refresh(); setOverlay(T("ov_transcribing"), cfg.modelName:gsub("^ggml%-",""):gsub("%.bin$","").." ("..cfg.language..")", true)
  local t0 = hs.timer.secondsSinceEpoch()
  recStart = t0
  local tsub = cfg.modelName:gsub("^ggml%-",""):gsub("%.bin$","")
  if tick then tick:stop() end
  tick = hs.timer.doEvery(1, function() if M.wTask then setOverlay(T("ov_still"), tsub, true) elseif state=="busy" then
    if overlay then local e=math.floor(hs.timer.secondsSinceEpoch()-recStart); overlay:evaluateJavaScript(string.format("document.getElementById('t').textContent=%q", string.format("%d:%02d",e//60,e%60))) end end end)
  M.wTask = hs.task.new(cfg.whisper, function(code, out, err)
    M.wTask = nil
    if cancelled then state="idle"; hideOverlay(); refresh(); return end
    log(string.format("whisper %s exit %d %.1fs RAW: %s", cfg.modelName, code, hs.timer.secondsSinceEpoch()-t0, out or ""))
    if code ~= 0 then state="idle"; hideOverlay(); refresh(); hs.alert.show(T("trans_failed")); return end
    out = (out or ""):gsub("%[BLANK_AUDIO%]",""):gsub("\n"," ")
    if cfg.cleanup and not out:match("^%s*$") then cleanup(out) else finish(out, nil) end
  end, whisperArgs(wav))
  M.wTask:start()
end

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
  os.remove(wav)
  local args = { "-q", "-c", "1", "-r", "16000", "-b", "16", wav }
  if cfg.autoStop then
    for _,a in ipairs({"silence","1","0.1",cfg.silenceThreshold,"1",tostring(cfg.silenceSeconds),cfg.silenceThreshold}) do table.insert(args,a) end
  end
  for _,a in ipairs({"trim","0",tostring(cfg.maxSeconds)}) do table.insert(args,a) end
  recTask = hs.task.new(cfg.rec, function()
    recTask = nil
    if state=="rec" then state="busy"; sound("Pop"); hs.timer.doAfter(0.2, transcribe) end
  end, args)
  showOverlay()
  recTask:start(); state="rec"; recStart=hs.timer.secondsSinceEpoch()
  sound("Tink")
  if cfg.cleanup then hs.timer.doAfter(0.5, function() M.warmModel() end) end
  local sub = cfg.autoStop and T("ov_autostop", tostring(cfg.silenceSeconds)) or T("ov_press", keyLabel(cfg.toggleKey))
  hs.timer.doAfter(0.3, function() setOverlay(T("ov_listening"), sub, false) end)
  tick = hs.timer.doEvery(1, function() if state=="rec" then setOverlay(T("ov_listening"), sub, false) end end)
  hs.timer.doAfter(0, refresh)
end
function M.stop(m)
  if state ~= "rec" then return end
  mode = m or "paste"; state="busy"; sound("Pop")
  if recTask then recTask:interrupt() end
  hs.timer.doAfter(0.3, transcribe); refresh()
end
function M.cancel()
  cancelled = true
  if recTask then local t=recTask; recTask=nil; state="busy"; t:interrupt() end
  if M.wTask then M.wTask:terminate() end
  state="idle"; if tick then tick:stop() end; hideOverlay(); sound("Basso"); refresh()
  if targetApp then targetApp:activate() end
end
function M.toggle() if state=="idle" then M.start() elseif state=="rec" then M.stop(cfg.defaultAction=="copy" and "copy" or "paste") else hs.alert.show(T("still_processing")) end end
local function setOpt(k,v) cfg[k]=v; saved[k]=v; saveSettings(); refresh() end
M.setOpt = setOpt
function M.toggleMode() setOpt("cleanup", not cfg.cleanup); hs.alert.show(cfg.cleanup and T("mode_clean") or T("mode_raw")) end
function M.toggleAutoStop() setOpt("autoStop", not cfg.autoStop); hs.alert.show(cfg.autoStop and T("autostop_on") or T("autostop_off")) end

-- ---------- downloads ----------
local function dlWhisper(file)
  if downloads[file] then return end
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
  if downloads[name] then return end
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
  local data = { history=history, conv=conv, autoLaunch=hs.autoLaunch(), cfg={ openAtLogin=cfg.openAtLogin, showAtLogin=cfg.showAtLogin, cleanup=cfg.cleanup, style=cfg.style, language=cfg.language, defaultAction=cfg.defaultAction,
     autoStop=cfg.autoStop, silenceSeconds=cfg.silenceSeconds, silenceThreshold=cfg.silenceThreshold, modelName=cfg.modelName, ollamaModel=cfg.ollamaModel, uiSize=cfg.uiSize, uiLanguage=cfg.uiLanguage, showOverlay=cfg.showOverlay },
     keys={ toggleKey=keyStr(cfg.toggleKey), modeKey=keyStr(cfg.modeKey), historyKey=keyStr(cfg.historyKey) },
     keyLabels={ toggleKey=keyLabel(cfg.toggleKey), modeKey=keyLabel(cfg.modeKey), historyKey=keyLabel(cfg.historyKey) },
     defaultKeys={ toggleKey=keyLabel(DEFAULTS.toggleKey), modeKey=keyLabel(DEFAULTS.modeKey), historyKey=keyLabel(DEFAULTS.historyKey) },
     lang=uiLang(), sysLang=sysLang,
     whisperModels=wm, llmModels=lm, dl=downloads, ollama=(cfg.ollama~=nil), activeModel=M.activeModel() or "", missing=preflight() or "" }
  local js = hs.json.encode(data)
  if next(downloads)==nil then js = js:gsub('"dl":%[%]','"dl":{}') end
  if next(conv)==nil then js = js:gsub('"conv":%[%]','"conv":{}') end
  appWin:evaluateJavaScript("render("..js..")")
end

function M.handle(a)
  local c = a.cmd
  local e = a.i and history[math.floor(a.i)]
  if c=="refresh" then ollamaInstalled(true); pushState()
  elseif c=="close" then appWin:hide(); if M.lastApp then M.lastApp:activate() end
  elseif c=="mini" then appWin:hide(); hs.alert.show(T("hidden", keyLabel(cfg.historyKey)))
  elseif c=="dictate" then if appWin then appWin:hide() end; hs.timer.doAfter(0.3, function() if M.lastApp then M.lastApp:activate() end; hs.timer.doAfter(0.3, M.start) end)
  elseif c=="copy" and e then hs.pasteboard.setContents(finalText(e)); hs.alert.show(T("copied"))
  elseif c=="copyRaw" and e then hs.pasteboard.setContents(e.raw); hs.alert.show(T("copied_raw"))
  elseif c=="paste" and e then appWin:hide(); doPaste(finalText(e), M.lastApp)
  elseif c=="restyle" and e then M.restyle(e, a.style)
  elseif c=="del" and e then table.remove(history, math.floor(a.i)); saveHistory(); refresh()
  elseif c=="clearHistory" then history = {}; saveHistory(); refresh(); hs.alert.show(T("history_cleared"))
  elseif c=="resetOverlay" then settings.set("taipea.overlayPos", nil); hs.alert.show(T("overlay_reset"))
  elseif c=="resetKeys" then
    for _,k in ipairs({"toggleKey","modeKey","historyKey"}) do saved[k]=nil; cfg[k]=DEFAULTS[k] end
    saveSettings(); bindAll(); refresh(); hs.alert.show(T("shortcuts_reset"))
  elseif c=="dlWhisper" then dlWhisper(a.file)
  elseif c=="dlLLM" then dlLLM(a.name)
  elseif c=="set" then
    local k, v = a.key, a.value
    if k=="toggleKey" or k=="modeKey" or k=="historyKey" then
      local pk = parseKey(v)
      if not pk then hs.alert.show(T("bad_shortcut", tostring(v))); pushState(); return end
      setOpt(k, pk); bindAll(); hs.alert.show(T("shortcut_set", keyLabel(pk)))
    elseif k=="modelName" or k=="ollamaModel" then setOpt(k, v); hs.alert.show(T("using", v))
      if k=="ollamaModel" then M.warmModel(v) end
    elseif k=="openAtLogin" then setOpt(k, v); hs.autoLaunch(v and true or false)
      hs.alert.show(v and T("login_on") or T("login_off"))
    elseif k=="uiSize" then setOpt(k, v=="compact" and "compact" or "normal")
      if appWin then local f=appWin:frame(); local scr=screenFor(f); local sf=scr:frame()
        local nw = math.min(cfg.uiSize=="compact" and 520 or 760, sf.w-40)
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
    local w, h = math.min(cfg.uiSize=="compact" and 520 or 760, sf.w-40), cfg.uiSize=="compact" and math.min(700, sf.h-80) or sf.h-80
    ap = ap or {x=sf.x+(sf.w-w)/2, y=sf.y+30}
    appWin = hs.webview.new(clampFrame({x=ap.x, y=ap.y, w=w, h=h}), {}, uc)
      :windowStyle({"borderless","resizable"}):windowTitle("Taipea"):transparent(true):shadow(true):level(hs.drawing.windowLevels.normal)
      :allowTextEntry(true):deleteOnClose(false)
      :url("file://"..(DATA:gsub(" ","%%20")).."/ui/app.html")
  end
  do local nf = clampFrame(appWin:frame()); appWin:frame(nf)
    local sp = settings.get("taipea.appPos"); if sp and (sp.x~=nf.x or sp.y~=nf.y) then settings.set("taipea.appPos", {x=nf.x, y=nf.y}) end end
  appWin:level(hs.drawing.windowLevels.normal):show()
  hs.timer.doAfter(0.1, function() local hw=appWin:hswindow(); if hw then hw:focus() end end)
  hs.application.get("org.hammerspoon.Hammerspoon"):activate()
  hs.timer.doAfter(0.5, pushState)
end
M.showHistory = M.openApp
function M.appWinRef() return appWin end
function M.js(s) if appWin then appWin:evaluateJavaScript(s) end end

bindAll = function()
  for _,h in ipairs(hk) do h:delete() end; hk = {}
  M.bound = { toggle=cfg.toggleKey, mode=cfg.modeKey, history=cfg.historyKey }
  table.insert(hk, hs.hotkey.bind(cfg.toggleKey.mods, cfg.toggleKey.key, M.toggle))
  table.insert(hk, hs.hotkey.bind(cfg.modeKey.mods, cfg.modeKey.key, M.toggleMode))
  table.insert(hk, hs.hotkey.bind(cfg.historyKey.mods, cfg.historyKey.key, M.openApp))
end
bindAll()
hs.urlevent.bind("taipea", function() M.openApp() end)
if hs.autoLaunch() ~= (cfg.openAtLogin and true or false) then hs.autoLaunch(cfg.openAtLogin and true or false) end
-- show window at startup only on a fresh launch shortly after login (not on config reload)
if cfg.showAtLogin and not hs.settings.get("taipea.reloading") then
  local up = tonumber((hs.execute("sysctl -n kern.boottime"):match("sec = (%d+)"))) or 0
  if os.time() - up < 600 then hs.timer.doAfter(3, function() M.openApp() end) end
end
if cfg.cleanup then M.warmModel() end
log("Taipea loaded · whisper="..tostring(cfg.whisper).." rec="..tostring(cfg.rec).." ollama="..tostring(cfg.ollama).." model="..cfg.modelName)
refresh()
return M
