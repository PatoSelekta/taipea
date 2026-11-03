-- Offline tests for Taipea's text logic. Runs with plain Lua 5.4 (no Mac needed):
--   lua tests/run.lua
-- A tiny fake "hs" table stands in for Hammerspoon.
local function proxy()
  local p = {}
  return setmetatable(p, { __index = function() return proxy() end, __call = function() return proxy() end })
end
local fake = { files = {}, ollamaList = "", post = nil, now = 0 }
hs = proxy()
hs.fs = { attributes = function(p, a) local m = fake.files[p]; if a then return m end; return m and { mode = m } or nil end,
          mkdir = function() return true end, dir = function() return function() return nil end end }
hs.execute = function(cmd) if cmd:match("list") then return fake.ollamaList end; return "" end
hs.timer = setmetatable({ secondsSinceEpoch = function() fake.now = fake.now + 31; return fake.now end }, { __index = function() return proxy() end })
hs.json = { encode = function() return "{}" end, decode = function(s) return { response = s } end }
hs.http = { asyncPost = function(_, _, _, cb) cb(fake.post and 200 or 0, fake.post and fake.post() or nil) end }
hs.alert = { show = function(m) fake.lastAlert = m end }
hs.keycodes = { map = { space = 49, c = 8, h = 4, v = 9, f = 3, q = 12, b = 11, k = 40, escape = 53, f6 = 97, ["4"] = 21,
  [49] = "space", [8] = "c", [4] = "h", [9] = "v", [3] = "f", [12] = "q", [11] = "b", [53] = "escape" } }
local TY = { flagsChanged = 12, keyDown = 10, leftMouseDown = 1, rightMouseDown = 3, otherMouseDown = 25, scrollWheel = 22, leftMouseUp = 2 }
hs.eventtap = { event = { types = TY, properties = { keyboardEventAutorepeat = 8 } }, keyStroke = function() end, checkMouseButtons = function() return {} end,
  new = function(types, fn) local t = { types = types, fn = fn, on = false }
    function t:start() self.on = true; return self end; function t:stop() self.on = false; return self end
    function t:isEnabled() return self.on end
    fake.taps = fake.taps or {}; table.insert(fake.taps, t)
    if types[1] == TY.flagsChanged and not fake.tap then fake.tap = t end; return t end }
hs.settings = { get = function() return true end, set = function() end }
hs.host = { locale = { preferredLanguages = function() return { fake.lang or "en-US" } end, current = function() return "en_US" end } }
hs.hotkey = { bind = function(mods, key) fake.binds = fake.binds or {}; table.insert(fake.binds, table.concat(mods, "+") .. "+" .. key); return { delete = function() end } end }
fake.lang = "es-CO"
local scr = { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end, name = function() return "Test" end }
hs.screen = { mainScreen = function() return scr end, allScreens = function() return { scr } end }
hs.drawing = { windowBehaviors = { canJoinAllSpaces = 1, stationary = 16 }, windowLevels = { floating = 3, normal = 0 } }
fake.tasks = {}
hs.task = { new = function(cmd, cb, args) local t = { cmd = cmd, cb = cb, args = args }
  function t:start() fake.tasks[#fake.tasks + 1] = t; return t end; function t:terminate() end; function t:interrupt() end; return t end }
local front = { bundleID = function() return "com.apple.TextEdit" end, activate = function() end }
hs.application = setmetatable({ frontmostApplication = function() return front end,
  watcher = { new = function() return { start = function() end } end, activated = 1 } }, { __index = function() return proxy() end })
hs.caffeinate = { watcher = { new = function() return { start = function() end } end }, sessionProperties = function() return {} end }
hs.webview = setmetatable({}, { __index = function() return proxy() end })

package.preload["hs.ipc"] = function() return true end
local HOME = "/nonexistent-home"
os.getenv = function(k) if k == "HOME" then return HOME end end
fake.files["/opt/homebrew/bin/ollama"] = "file"
fake.files["/usr/local/bin/whisper-cli"] = "file"   -- Intel-style path must also be found

local M = dofile((arg[0]:match("^(.*)/") or ".") .. "/../src/taipea.lua")

local pass, fail = 0, 0
local function check(name, cond) if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. name) end end

-- language guess
check("guess en", M.guessLang("I think that we can do this for you and the team") == "en")
check("guess es", M.guessLang("yo creo que el equipo de la empresa no está muy bien porque hay más trabajo") == "es")
check("guess mixed", M.guessLang("necesito que me mandes the report antes del viernes because el cliente is waiting for it") == "mixed")

-- chunking: long text splits on sentences, keeps every word
local sents = {}
for i = 1, 60 do sents[#sents + 1] = "Esta es la frase número " .. i .. " y tiene varias palabras para contar bien." end
local long = table.concat(sents, " ")
local chunks = M.splitChunks(long, 250)
local words = 0
for _, c in ipairs(chunks) do local n = select(2, c:gsub("%S+", "")); words = words + n; check("chunk size", n <= 375) end
check("several chunks", #chunks >= 2)
check("no words lost", words == select(2, long:gsub("%S+", "")))
check("short text one chunk", #M.splitChunks("hola mundo") == 1)
check("no punctuation hard split", #M.splitChunks(string.rep("palabra ", 900)) >= 3)

-- output checks
local inp = "hola eh necesito que me mandes the report antes del viernes because el cliente lo pidió y revisa el budget con Ana"
check("light ok", M.checkOutput(inp, "Hola, necesito que me mandes the report antes del viernes because el cliente lo pidió y revisa el budget con Ana.", "light") == nil)
check("empty rejected", M.checkOutput(inp, "", "light") == "empty")
check("too short rejected", M.checkOutput(inp, "Hola.", "light") ~= nil)
check("garbage rejected", M.checkOutput(inp, "Lorem ipsum dolor amet consectetur adipiscing elit sed eiusmod tempor", "formal") ~= nil)
local es = "yo creo que el equipo de la empresa no está muy bien porque hay más trabajo que nunca y eso es un problema para todos"
check("translation rejected", M.checkOutput(es, "I think that the team at the company is not doing well because there is more work than ever and that is a problem for all of us", "paragraphs") ~= nil)

-- bullets / salutation
check("bullets normalised", M.normBullets("* uno\n\n• dos\n1. tres") == "- uno\n- dos\n- tres")
check("salutation stripped", M.stripSalutation("necesito el informe", "Estimado equipo:\nnecesito el informe.") == "Necesito el informe.")
check("salutation kept when spoken", M.stripSalutation("estimado equipo necesito", "Estimado equipo:\nNecesito.") == "Estimado equipo:\nNecesito.")

-- cleanup model selection with fallback
fake.ollamaList = "NAME ID SIZE\nqwen2.5:7b abc 4.7 GB\n"
check("fallback model used", M.activeModel() == "qwen2.5:7b")
fake.ollamaList = "NAME ID SIZE\nqwen2.5:7b abc 4.7 GB\ngemma4:e4b def 9.6 GB\n"
check("default model preferred", M.activeModel() == "gemma4:e4b")
fake.ollamaList = ""
check("no model -> nil", M.activeModel() == nil)

-- cleanText: no model -> raw (nil) ; model -> cleaned ; server error -> raw chunk
local got, st
M.cleanText("hola mundo esto es una prueba", function(o, s) got, st = o, s end)
check("no model returns nil", got == nil and st.noModel)
fake.ollamaList = "NAME\ngemma4:e4b x\n"
fake.post = function() return "Hola mundo, esto es una prueba." end
M.cleanText("hola mundo esto es una prueba", function(o, s) got, st = o, s end)
check("cleaned text", got == "Hola mundo, esto es una prueba." and st.fallbacks == 0)
fake.post = nil
M.cleanText("hola mundo esto es una prueba", function(o, s) got, st = o, s end)
check("server down -> nil (raw)", got == nil and st.failed == st.chunks)

-- prompts keep the language rules
check("prompt bullets", M.buildPrompt("hola", "bullets"):find("NEVER translate", 1, true) ~= nil)
check("prompt light", M.buildPrompt("hola", "light"):find("never translate", 1, true) ~= nil)

-- preflight: rec missing on this fake Mac
check("preflight mentions sox", (M.preflight() or ""):find("sox", 1, true) ~= nil)

-- defaults: shortcuts are bound even with no config.lua / settings.json
local D = M.DEFAULTS
check("default toggle key: Control + Command", M.keyStr(D.toggleKey) == "ctrl+cmd" and D.toggleKey.key == "")
check("backup toggle key", M.keyStr(D.toggleKey2) == "ctrl+alt+space")
check("hide key: Option + Command", M.keyStr(D.fabHideKey) == "alt+cmd")
check("default mode key", table.concat(D.modeKey.mods, "+") .. "+" .. D.modeKey.key == "ctrl+alt+c")
check("default history key", table.concat(D.historyKey.mods, "+") .. "+" .. D.historyKey.key == "ctrl+alt+h")
local b = table.concat(fake.binds or {}, ",")
check("hotkeys bound at load", b == "ctrl+alt+space,ctrl+alt+c,ctrl+alt+h,ctrl+alt+v")
check("bound uses defaults", M.bound.toggle == D.toggleKey and M.bound.mode == D.modeKey and M.bound.history == D.historyKey and M.bound.pasteLast == D.pasteLastKey and M.bound.toggle2 == D.toggleKey2 and M.bound.fabHide == D.fabHideKey)
check("no Ctrl+Option+F any more", not b:find("ctrl+alt+f", 1, true))
do local seen, dup, cmdAlt = {}, false, false
  for _, k in ipairs(M.KEY_ACTIONS) do
    local m = {}; for _, x in ipairs(D[k].mods) do m[x] = true end
    if m.cmd and m.alt and k ~= "fabHideKey" then cmdAlt = true end
    local s = M.keyStr(D[k]); if seen[s] then dup = true end; seen[s] = true
    if M.keyProblem(k, D[k]) then dup = true end end
  check("default shortcuts don't collide and are all allowed", not dup)
  check("only the hide key uses Cmd+Option", not cmdAlt) end
check("default paste-last key", table.concat(D.pasteLastKey.mods, "+") .. "+" .. D.pasteLastKey.key == "ctrl+alt+v")
check("v0.2 defaults", D.voiceControl == false and D.floatButton == true and D.cardWithFab == false and D.textSize == "normal" and D.contrast == "auto"
  and D.silenceSeconds == 3 and #D.customWords == 0 and D.startPhrases[1] == "Taipea escribe" and D.stopPhrases[1] == "listo")
check("default values", D.style == "light" and D.cleanup == true and D.ollamaModel == "gemma4:e4b" and D.language == "auto"
  and D.uiLanguage == "auto" and D.showOverlay == true and D.uiSize == "normal" and D.defaultAction == "paste"
  and D.openAtLogin == true and D.historyMax == 500 and D.maxSeconds == 1800 and D.autoStop == false)

-- interface language: auto follows macOS (stubbed as es-CO), and can be forced
check("auto -> Spanish Mac", M.uiLang() == "es")
check("Spanish string", M.T("ov_listening") == "Escuchando…")
check("Spanish key label", M.keyLabel(D.toggleKey2) == "Control + Opción + Espacio" and M.keyLabel(D.toggleKey) == "Control + Comando")
M.cfg.uiLanguage = "en"
check("forced English", M.uiLang() == "en" and M.T("ov_listening") == "Listening…")
check("English key label", M.keyLabel(D.toggleKey2) == "Control + Option + Space" and M.keyLabel(D.toggleKey) == "Control + Command")
check("format args", M.T("parts_kept", 2, 5) == "2 of 5 parts kept raw (cleanup removed too much)")
M.cfg.uiLanguage = "auto"

-- every string exists in both languages with the same placeholders
local function ph(str) local t = {}; for x in str:gmatch("%%[sd]") do t[#t + 1] = x end; return table.concat(t) end
for k, v in pairs(M.STR.en) do
  check("es has " .. k, M.STR.es[k] ~= nil)
  if M.STR.es[k] then check("placeholders " .. k, ph(v) == ph(M.STR.es[k])) end
end
for k in pairs(M.STR.es) do check("en has " .. k, M.STR.en[k] ~= nil) end

-- ---------- v0.2: custom words ----------
local R = { { heard = "select dev", replace = "selektdev" }, { heard = "tai pea", replace = "Taipea" }, { heard = "taipei", replace = "Taipea" } }
check("words whole + case", (M.applyWords("Visit Select Dev today, and select-dev.", R)) == "Visit selektdev today, and selektdev.")
check("words accents", (M.applyWords("Taipéi es genial; tai pea también.", R)) == "Taipea es genial; Taipea también.")
check("words not inside words", (M.applyWords("selecting devs and Taipeian food", R)) == "selecting devs and Taipeian food")
check("words count", select(2, M.applyWords("select dev, select dev", R)) == 2)
check("hint words", table.concat(M.hintWords(R), ",") == "Taipea,selektdev")
check("prompt echo", M.isPromptEcho(" Taipea, selektdev.", R) and not M.isPromptEcho("Taipea is great", R))
M.cfg.customWords = R
check("whisper hint", M.whisperHint() == "Taipea, selektdev.")
check("cleanup prompt protects words", M.buildPrompt("hola", "light"):find("respell them: Taipea, selektdev", 1, true) ~= nil
  and M.buildPrompt("hola", "bullets"):find("respell them: Taipea, selektdev", 1, true) ~= nil)
check("polish applies words", M.polishRaw("Check select dev.") == "Check selektdev.")
check("polish drops prompt echo", M.polishRaw(" Taipea, selektdev.") == "")
M.cfg.customWords = {}
check("no words -> no hint", M.whisperHint() == nil and M.wordsRule() == "")

-- ---------- v0.2: voice commands (inputs are real Whisper outputs for these phrases) ----------
local SP, ST = D.startPhrases, D.stopPhrases
for _, x in ipairs({ { "Tapirite.", "start" }, { "Taipéa escribe.", "start" }, { "Taipea, escribe.", "start" }, { "Tapia, right.", "start" },
  { "Taipei, write!", "start" }, { "Listo.", "stop" }, { "done", "stop" }, { "Taipei ha listo.", "stop" } }) do
  check("command " .. x[1], M.classifyBurst(x[1], SP, ST, {}) == x[2])
end
for _, x in ipairs({ "Thank you.", "Okay.", "The weather is nice today.", "Ya terminé, está listo el informe.", "Type it right.", "Alright.",
  "Copyright.", "Describe it.", "Está listo.", "I'm done.", "Escribe.", "you", "" }) do
  check("not a command: " .. x, M.classifyBurst(x, SP, ST, {}) == nil)
end
check("text after start phrase", select(2, M.classifyBurst("Taipea escribe, hola mundo.", SP, ST, {})) == "hola mundo.")
check("strip stop", M.stripStop("Send the report to Ana. Listo.", ST, {}) == "Send the report to Ana.")
check("strip misheard stop", M.stripStop("Send it, Taipei ha listo.", ST, {}) == "Send it")
check("strip stop + stray words", M.stripStop("Revisa el budget. Done. Thank you.", ST, {}) == "Revisa el budget.")
check("keep early words", M.stripStop("I am done with it and more words here now", ST, {}) == "I am done with it and more words here now")
check("strip start", M.stripStart("Taipea escribe. Hola.", SP, {}) == "Hola.")
check("split phrases", table.concat(M.splitPhrases(" listo, done ,, Taipea listo "), "|") == "listo|done|Taipea listo")

-- ---------- v0.2: recovery ----------
local wp = os.tmpname()
local wf = io.open(wp, "wb")
wf:write("RIFF" .. string.pack("<I4", 0) .. "WAVEfmt " .. string.pack("<I4", 16) .. string.rep("\0", 16) .. "data" .. string.pack("<I4", 0) .. string.rep("\1", 32000)); wf:close()
local okw, dl = M.fixWavHeader(wp)
wf = io.open(wp, "rb"); local hdr = wf:read(44); wf:close()
check("wav header fixed", okw and dl == 32000 and string.unpack("<I4", hdr, 5) == 32036 and string.unpack("<I4", hdr, 41) == 32000)
check("wav seconds", M.wavSeconds(wp) == 1.0)
check("not a wav", M.fixWavHeader("/nonexistent") == false)
os.remove(wp)

-- ---------- v0.2: voice start goes through the normal recorder ----------
fake.files["/opt/homebrew/bin/rec"] = "file"
M.cfg.rec = "/opt/homebrew/bin/rec"
local n0 = #fake.tasks
check("voice off by default", M.voiceActive() == false)
check("start phrase while idle", M.voiceHeard("Taipea escribe.") == "start")
-- no speech model on this fake Mac, so start() must stop at the friendly preflight message
check("voice start uses the normal start (preflight)", #fake.tasks == n0 and (fake.lastAlert or ""):find("modelo", 1, true) ~= nil)
check("look scale", M.look.scale == 1 and M.look.hc == false)

-- ---------- v0.2: floating button satellites and the recording card ----------
local SR = { x = 0, y = 25, w = 1440, h = 875 }
local function noOverlap(a, b) return a.x + a.w <= b.x or b.x + b.w <= a.x or a.y + a.h <= b.y or b.y + b.h <= a.y end
local function onScreen(f) return f.x >= SR.x and f.y >= SR.y and f.x + f.w <= SR.x + SR.w and f.y + f.h <= SR.y + SR.h end
for _, c in ipairs({ { { x = 1306, y = 520, w = 104, h = 104 }, "left" }, { { x = 10, y = 400, w = 104, h = 104 }, "right" },
  { { x = 10, y = 30, w = 104, h = 104 }, "right" }, { { x = 700, y = 790, w = 104, h = 104 }, "up" } }) do
  local side, fr = M.satLayout(c[1], 92, SR)
  check("satellites go " .. c[2], side == c[2])
  check("satellites on screen (" .. c[2] .. ")", onScreen(fr[1]) and onScreen(fr[2]))
  check("satellites clear of the button (" .. c[2] .. ")", noOverlap(fr[1], c[1]) and noOverlap(fr[2], c[1]) and noOverlap(fr[1], fr[2]))
end
local tight = { x = 0, y = 25, w = 300, h = 120 }
local sideT, frT = M.satLayout({ x = 98, y = 25, w = 104, h = 104 }, 92, tight)
check("tight screen: satellites still on screen", frT[1].x >= 0 and frT[2].x + frT[2].w <= 300 and frT[1].y >= 25)
check("defaults: card hidden with the button", D.floatButton == true and D.cardWithFab == false)
M.cfg.floatButton, M.cfg.cardWithFab = true, false
check("button on: no card", M.cardWanted() == false)
M.cfg.cardWithFab = true
check("button on + card too: card", M.cardWanted() == true)
M.cfg.floatButton, M.cfg.cardWithFab = false, false
check("button off: card", M.cardWanted() == true)
M.cfg.floatButton = true
check("satellite labels es", M.T("sat_copy") == "Parar y solo copiar" and M.T("sat_cancel") == "Cancelar" and M.T("fab_rec") == "Parar y pegar")
check("satellite labels en", M.STR.en.sat_copy == "Stop & Copy only" and M.STR.en.fab_rec == "Stop & Paste")
check("icons", M.ICON.paste:find("<svg", 1, true) and M.ICON.copy:find("<svg", 1, true) and M.ICON.x:find("<svg", 1, true) and M.ICON.mic:find("<svg", 1, true))

check("watchdog present", type(M.watchdogReset) == "function" and type(M._timers) == "table")
check("watchdog strings", M.STR.en.wd_reset ~= nil and M.STR.es.wd_reset ~= nil and M.STR.es.wd_empty ~= nil)

-- ---------- v0.2.2: colour sets ----------
check("v0.2.2 defaults", D.floatingTheme == "classic" and D.hideFullscreen == true and #D.hideApps == 0
  and M.isHex(D.customBg) and M.isHex(D.customMic) and M.isHex(D.customAccent))
check("8 colour sets", #M.FAB_THEMES == 8 and M.FAB_THEMES[1].id == "classic" and M.FAB_THEMES[2].id == "studio" and M.FAB_THEMES[8].id == "custom")
check("isHex", M.isHex("#0A6CD6") and M.isHex("#abcdef") and not M.isHex("0A6CD6") and not M.isHex("#0A6CD") and not M.isHex("#GGGGGG") and not M.isHex(nil))
check("normHex", M.normHex(" e8503a ") == "#E8503A" and M.normHex("#0f0") == "#00FF00" and M.normHex("#12345") == nil and M.normHex("red") == nil and M.normHex(5) == nil)
local function withTheme(id, bg, mic, acc) M.cfg.floatingTheme, M.cfg.customBg, M.cfg.customMic, M.cfg.customAccent = id, bg, mic, acc; return M.fabTheme() end
check("unknown set -> Classic", withTheme("nope").id == "classic")
check("custom with bad colour -> Classic", withTheme("custom", "#12", "#FFFFFF", "#E8503A").id == "classic")
check("custom kept", withTheme("custom", "#1A1A1A", "#FFFFFF", "#E8503A").id == "custom")
local cl = M.buildPalette(M.FAB_THEMES[1])
check("Classic keeps the original colours", cl.cl == true and cl.panel == "#1C1C20" and cl.focus == "#0A84FF" and cl.acc == "#0A6CD6" and cl.acctx == "#FFFFFF")
check("Classic accent contrast 5.09", M.palReport(cl).accent == 5.09)
for _, th in ipairs(M.FAB_THEMES) do if th.id ~= "custom" then
  local r = M.palReport(M.buildPalette(th))
  check("contrast " .. th.id, r.text >= 4.5 and r.accent >= 4.5 and r.muted >= 4.5 and r.warn >= 4.5)
end end
local stp = M.buildPalette(M.FAB_THEMES[2])
check("Studio: accent fill stays coral", stp.acc == "#E8503A" and M.palReport(stp).accent >= 4.5)
check("Paper is a light set", M.buildPalette(M.FAB_THEMES[7]).light == true)
-- unreadable Custom combinations are fixed automatically
for _, c in ipairs({ { "#808080", "#888888", "#7F7F7F" }, { "#FFFFFF", "#FFFF00", "#FFFFFF" }, { "#000000", "#111111", "#000000" }, { "#3366CC", "#3366CC", "#3366CC" } }) do
  local r = M.palReport(M.buildPalette({ id = "custom", bg = c[1], mic = c[2], acc = c[3] }))
  check("custom fixed " .. table.concat(c, "/"), r.text >= 4.5 and r.accent >= 4.5 and r.muted >= 4.5)
end
withTheme("classic", D.customBg, D.customMic, D.customAccent)
check("palette is Classic again", M.palette().cl == true)

-- ---------- v0.2.2: hiding the floating button ----------
local H = M.hideDecision
check("hide: nothing -> show", H({ state = "idle" }) == "")
check("hide: shortcut", H({ state = "idle", session = true }) == "shortcut")
check("hide: app in list", H({ state = "idle", inList = true }) == "app")
check("hide: full screen", H({ state = "idle", hideFullscreen = true, fullscreen = true }) == "fullscreen")
check("hide: full screen setting off", H({ state = "idle", hideFullscreen = false, fullscreen = true }) == "")
for _, st in ipairs({ "rec", "busy" }) do
  check("never hide while " .. st, H({ state = st, session = true, inList = true, hideFullscreen = true, fullscreen = true }) == "")
end
local L2 = { { name = "VLC", id = "org.videolan.vlc" }, { name = "TV", id = "" } }
local function app(n, id) return { name = function() return n end, bundleID = function() return id end } end
check("app match by id", M.appMatches(app("Other name", "org.videolan.vlc"), L2))
check("app match by name, any case", M.appMatches(app("tv", "com.apple.TV"), L2))
check("app no match", not M.appMatches(app("TextEdit", "com.apple.TextEdit"), L2) and not M.appMatches(nil, L2))
check("app match table form", M.appMatches({ name = "VLC", id = "x" }, L2))
local SF = { x = 0, y = 0, w = 1440, h = 900 }
local function win(o) return { isFullScreen = function() return o.fs end, role = function() return o.role or "AXWindow" end,
  frame = function() return o.f end, screen = function() return { fullFrame = function() return SF end } end } end
check("native full screen", M.isFullscreenWin(win({ fs = true, f = { x = 100, y = 100, w = 10, h = 10 } })))
check("borderless window covering the screen", M.isFullscreenWin(win({ f = { x = 0, y = 0, w = 1440, h = 900 } })))
check("normal window is not full screen", not M.isFullscreenWin(win({ f = { x = 0, y = 25, w = 1440, h = 875 } })))
check("desktop is not full screen", not M.isFullscreenWin(win({ role = "AXScrollArea", f = SF })) and not M.isFullscreenWin(nil))
check("idle by default: hide reason uses the session flag", (function() M.fabSessionHidden = true; local r = M.fabHideReason(); M.fabSessionHidden = false; return r end)() == "shortcut")
check("TextEdit in front, nothing listed -> show", M.fabHideReason() == "")

-- ---------- v0.2.2: permissions ----------
local pb = { set = nil, read = 0, write = 0 }
local realPB = hs.pasteboard
hs.pasteboard = { setContents = function(t) pb.set = t end, readAllData = function() pb.read = pb.read + 1; return { old = 1 } end,
  writeAllData = function() pb.write = pb.write + 1 end }
local realAx = M.axCheck
M.axCheck = function() return false end
local activated = false
local r = M.doPaste("hola mundo", { activate = function() activated = true end })
check("paste blocked returns false", r == false)
check("paste blocked: text left on the clipboard", pb.set == "hola mundo")
check("paste blocked: old clipboard not read or restored", pb.read == 0 and pb.write == 0)
check("paste blocked: app brought back", activated)
check("paste blocked: alert shown", fake.lastAlert == M.T("perm_ax_paste"))
check("permission state off", M.permAx == false)
M.axCheck = function() return true end
check("paste allowed returns true", M.doPaste("hola", nil) == true and pb.read == 1)
check("permission state back on", M.permAx == true and fake.lastAlert == M.T("perm_ax_back"))
M.axCheck, hs.pasteboard = realAx, realPB
M.micProblem(M.T("no_speech"))
check("mic hint shown", M.micWarn == true and (fake.lastAlert or ""):find(M.T("perm_mic_hint"), 1, true) ~= nil)
check("permission URLs", M.AX_URL:find("Privacy_Accessibility", 1, true) and M.MIC_URL:find("Privacy_Microphone", 1, true))

-- ---------- v0.2.5: modifier-only shortcuts act on press (Control + Command, Option + Command) ----------
local F = "flags"
local function chordRun(steps, mods)
  local C = M.newChord("test", mods or { "ctrl", "cmd" }); local n = 0
  for _, s in ipairs(steps) do if C.feed(s[1], s[2], s[3]) then n = n + 1 end end
  return n, C
end
local CC = { ctrl = true, cmd = true }
for _, c in ipairs({
  { "press and hold fires once (on press)", 1, { { F, { ctrl = true }, 0 }, { F, CC, 0.05 }, { "tick", nil, 0.33 }, { "tick", nil, 0.6 }, { F, { cmd = true }, 2 }, { F, {}, 2.1 } } },
  { "quick tap fires on release", 1, { { F, CC, 0 }, { F, { ctrl = true }, 0.1 } } },
  { "latched keys (virtual keyboard) fire with no release", 1, { { F, { ctrl = true }, 0 }, { F, CC, 1.5 }, { "tick", nil, 1.8 } } },
  { "Control+Command+Q does not fire", 0, { { F, CC, 0 }, { "key", nil, 0.1 }, { "tick", nil, 0.3 }, { F, {}, 0.5 } } },
  { "with Option does not fire", 0, { { F, CC, 0 }, { F, { ctrl = true, cmd = true, alt = true }, 0.1 }, { "tick", nil, 0.3 }, { F, {}, 0.5 } } },
  { "with Shift held first does not fire", 0, { { F, { shift = true }, 0 }, { F, { shift = true, ctrl = true, cmd = true }, 0.1 }, { "tick", nil, 0.4 }, { F, {}, 0.5 } } },
  { "Fn is ignored", 1, { { F, { fn = true, ctrl = true, cmd = true }, 0 }, { "tick", nil, 0.3 } } },
  { "clicks don't cancel it", 1, { { F, CC, 0 }, { "mouse", nil, 0.1 }, { "tick", nil, 0.3 } } },
  { "Control alone does not fire", 0, { { F, { ctrl = true }, 0 }, { "tick", nil, 0.5 }, { F, {}, 0.6 } } },
  { "tick too early does not fire", 0, { { F, CC, 0 }, { "tick", nil, 0.1 } } },
  { "held: no second fire until a key is let go", 1, { { F, CC, 0 }, { "tick", nil, 0.3 }, { F, CC, 0.5 }, { "tick", nil, 0.9 } } },
  { "two presses, 1 s apart, fire twice", 2, { { F, CC, 0 }, { "tick", nil, 0.3 }, { F, {}, 0.4 }, { F, CC, 1.5 }, { "tick", nil, 1.8 } } },
  { "a second press within the cooldown is ignored", 1, { { F, CC, 0 }, { F, {}, 0.1 }, { F, CC, 0.3 }, { F, {}, 0.4 } } },
  { "after a blocked shortcut, a clean press works", 1, { { F, CC, 0 }, { "key", nil, 0.1 }, { F, {}, 0.3 }, { F, CC, 2 }, { "tick", nil, 2.3 } } },
}) do local n = chordRun(c[3]); check("chord: " .. c[1], n == c[2]) end
do local n = chordRun({ { F, { alt = true, cmd = true }, 0 }, { "tick", nil, 0.3 } }, { "alt", "cmd" })
  check("chord: Option + Command works the same", n == 1) end
do local fired = 0; local C = M.newChord("t", { "ctrl", "cmd" }, function() fired = fired + 1 end)
  C.feed(F, CC, 0); C.feed("tick", nil, 0.3); check("chord: calls its action", fired == 1 and C.phase == "fired") end
-- the real key watcher: started, never consumes keys, builds one chord per modifier-only shortcut
local tap = fake.tap
check("key watcher started", tap ~= nil and tap.on == true and M.fabTapOK == true and M.chordTapOK == true)
local function ev(t, fl, kc, rep) return { getType = function() return t end, getFlags = function() return fl or {} end,
  getKeyCode = function() return kc or 0 end, getProperty = function() return rep or 0 end } end
check("key watcher never consumes keys", tap.fn(ev(TY.keyDown)) == false and tap.fn(ev(TY.flagsChanged, { cmd = true })) == false
  and tap.fn(ev(TY.flagsChanged, CC)) == false and tap.fn(ev(TY.flagsChanged, {})) == false)
do local w = {}; for _, x in ipairs(tap.types) do w[x] = true end
  check("key watcher watches modifiers and keys only (not clicks)", w[TY.flagsChanged] and w[TY.keyDown] and not w[TY.leftMouseDown]) end
check("two chords from the defaults", #M.CHORDS == 2 and M.CHORDS[1].mods[1] == "ctrl" and M.CHORDS[1].mods[2] == "cmd"
  and M.CHORDS[2].mods[1] == "alt" and M.CHORDS[2].mods[2] == "cmd")
check("tap label in both languages", M.STR.en.fab_tap_key == "Option + Command" and M.STR.es.fab_tap_key == "Opción + Comando")
check("hidden alert names the keys", M.T("fab_hidden", M.keyLabel(D.fabHideKey)):find("Opción + Comando", 1, true) ~= nil)
M.cfg.uiLanguage = "en"
check("hidden alert names the keys (en)", M.T("fab_hidden", M.keyLabel(D.fabHideKey)) == "Floating button hidden (press Option + Command to show it again)")
check("modifier-only labels", M.keyLabel(D.toggleKey) == "Control + Command" and M.keySym(D.toggleKey) == "⌃ ⌘" and M.keySym(D.toggleKey2) == "⌃ ⌥ Space")
check("labels use Apple's order", M.keyLabel({ mods = { "cmd", "shift", "ctrl" }, key = "k" }) == "Control + Shift + Command + K")
check("key strings sorted", M.keyStr({ mods = { "cmd", "ctrl" }, key = "" }) == "ctrl+cmd" and M.keyStr({ mods = { "alt", "ctrl" }, key = "space" }) == "ctrl+alt+space")
M.cfg.uiLanguage = "auto"
-- typed shortcuts: modifiers only are allowed now
local pk = M.parseKey
check("parse: modifier-only", pk("Control + Command") and M.keyStr(pk("Control + Command")) == "ctrl+cmd" and pk("cmd+ctrl").key == "")
check("parse: with a key", M.keyStr(pk("option+ctrl+space")) == "ctrl+alt+space")
check("parse: bad words", pk("ctrl+banana+c") == nil and pk("ctrl+zz") == nil and pk("") == nil)
-- refusals
local kp = function(t, s) return M.keyProblem(t, type(s) == "string" and pk(s) or s) end
check("refuse: one modifier alone", kp("toggleKey", { mods = { "ctrl" }, key = "" }) == M.T("k_need2"))
check("refuse: a plain key", kp("toggleKey", { mods = {}, key = "c" }) == M.T("k_single") and kp("toggleKey", { mods = { "shift" }, key = "c" }) == M.T("k_single"))
check("allow: F-key alone", kp("toggleKey", { mods = {}, key = "f6" }) == nil)
check("refuse: macOS shortcuts", kp("toggleKey", "cmd+q") == M.T("k_system") and kp("toggleKey", "ctrl+cmd+space") == M.T("k_system")
  and kp("toggleKey", { mods = { "alt", "cmd" }, key = "escape" }) == M.T("k_system") and kp("toggleKey", { mods = { "cmd", "shift" }, key = "4" }) == M.T("k_system"))
check("refuse: the Mic key", kp("toggleKey", { mods = {}, key = "mic" }) == M.T("k_mic"))
check("refuse: unknown key", kp("toggleKey", { mods = { "ctrl" }, key = "?999" }) == M.T("k_unknown"))
check("refuse: used by another shortcut", kp("modeKey", "ctrl+cmd") == M.T("k_dup", M.T("k_lbl_toggleKey")) and kp("toggleKey2", "ctrl+alt+c") ~= nil)
check("allow: same as itself", kp("toggleKey", "ctrl+cmd") == nil and kp("toggleKey", "ctrl+shift+cmd") == nil)
-- recording a shortcut (decision logic)
local function capRun(steps)
  M.capBegin("toggleKey", 0); local r
  for _, s in ipairs(steps) do local x = M.capFeed(s[1], s[2], s[3]); r = r or x end
  M.CAP = nil; return r
end
local r = capRun({ { F, { ctrl = true }, 0.1 }, { F, CC, 0.2 }, { F, { cmd = true }, 0.4 }, { F, {}, 0.5 } })
check("record: modifier-only on release", r and r.spec and M.keyStr(r.spec) == "ctrl+cmd")
r = capRun({ { F, { ctrl = true }, 0.1 }, { F, { ctrl = true, alt = true }, 0.2 }, { "key", { kc = 49, fl = { ctrl = true, alt = true } }, 0.3 } })
check("record: modifiers + key", r and r.spec and M.keyStr(r.spec) == "ctrl+alt+space")
r = capRun({ { F, CC, 0.1 }, { "tick", nil, 0.5 }, { "tick", nil, 1.0 } })
check("record: latched modifiers end after a moment", r and r.spec and M.keyStr(r.spec) == "ctrl+cmd")
check("record: Escape cancels", (capRun({ { "key", { kc = 53, fl = {} }, 0.1 } }) or {}).cancel == true)
check("record: times out", (capRun({ { "tick", nil, 21 } }) or {}).cancel == true)
r = capRun({ { "key", { kc = 176, fl = { fn = true } }, 0.1 } })
check("record: Mic key is seen (and refused later)", r and r.spec.key == "mic" and M.keyProblem("toggleKey", r.spec) == M.T("k_mic"))
r = capRun({ { "key", { kc = 49, fl = {} }, 0.1 }, { "key", { kc = 8, fl = { ctrl = true, alt = true } }, 0.2 } })
check("record: only the first result counts", r and M.keyStr(r.spec) == "space")
-- the window flow: Record, result, Save; refused ones are not saved
M.handle({ cmd = "capStart", key = "toggleKey" })
check("record: listening pauses the shortcuts", M._capturing == "toggleKey" and M.cap and M.cap.phase == "listen")
M.capFinish({ spec = { mods = { "cmd", "ctrl", "shift" }, key = "" } })
check("record: result shown", M._capturing == nil and M.cap.phase == "result" and M.cap.label == "Control + Mayúsculas + Comando" and M.cap.err == "")
fake.binds = {}
M.handle({ cmd = "capSave" })
check("record: saved and bound", M.keyStr(M.cfg.toggleKey) == "ctrl+shift+cmd" and M.cap == nil and M.CHORDS[1].mods[2] == "shift")
M.handle({ cmd = "capStart", key = "modeKey" }); M.capFinish({ spec = { mods = { "cmd" }, key = "q" } })
check("record: refused one shows why", M.cap.err == M.T("k_system"))
M.handle({ cmd = "capSave" })
check("record: refused one is not saved", M.keyStr(M.cfg.modeKey) == "ctrl+alt+c")
M.handle({ cmd = "capCancel" })
check("record: cancel clears it", M.cap == nil and M._capturing == nil)
M.handle({ cmd = "set", key = "historyKey", value = "ctrl+cmd+space" })
check("typed: macOS shortcut refused", M.keyStr(M.cfg.historyKey) == "ctrl+alt+h")
M.handle({ cmd = "set", key = "fabHideKey", value = "ctrl+alt+b" })
check("typed: new key saved", M.keyStr(M.cfg.fabHideKey) == "ctrl+alt+b" and M.CHORDS[2] == nil)
M.handle({ cmd = "resetKeys" })
check("reset: all six back to defaults", M.keyStr(M.cfg.toggleKey) == "ctrl+cmd" and M.keyStr(M.cfg.fabHideKey) == "alt+cmd" and #M.CHORDS == 2)
-- old saved settings: an override is kept; a backup equal to it is bound once
do local saveT = M.cfg.toggleKey
  M.cfg.toggleKey = { mods = { "ctrl", "alt" }, key = "space" }; fake.binds = {}; M.bindAll()
  check("migration: typed override kept, no double bind", table.concat(fake.binds, ",") == "ctrl+alt+space,ctrl+alt+c,ctrl+alt+h,ctrl+alt+v" and #M.CHORDS == 1 and M.bound.toggle2 == nil)
  M.cfg.toggleKey = saveT; M.bindAll() end
-- Escape while recording = stop & paste
local esc = nil; for _, t in ipairs(fake.taps) do if t == M._escTap then esc = t end end
check("Escape watcher started", esc ~= nil and esc.on and M.escTapOK == true)
local realStop, stopped = M.stop, nil
M.stop = function(how) stopped = how end
check("Escape ignored when not recording", M.escWanted(53, {}) == false and esc.fn(ev(TY.keyDown, {}, 53)) == false)
M._setState("rec")
check("Escape wanted while recording", M.escWanted(53, {}) == true and M.escWanted(53, { cmd = true, alt = true }) == false and M.escWanted(12, {}) == false)
check("Escape swallowed while recording", esc.fn(ev(TY.keyDown, {}, 53)) == true and esc.fn(ev(TY.keyUp, {}, 53)) == true)
M.cfg.escStop = false
check("Escape setting off", M.escWanted(53, {}) == false)
M.cfg.escStop = true
M._setState("idle"); M.stop = realStop
check("Escape default on", D.escStop == true)
-- Mic key: off by default, swallowed and toggles when on
local mic = M._micTap
check("Mic key off by default", D.micKey == false and mic.fn(ev(TY.keyDown, { fn = true }, 176)) == false)
local realToggle = M.toggle; M.toggle = function() end
M.cfg.micKey = true
check("Mic key on: swallowed", mic.fn(ev(TY.keyDown, { fn = true }, 176)) == true and mic.fn(ev(TY.keyUp, { fn = true }, 176)) == true
  and mic.fn(ev(TY.keyDown, {}, 96)) == false)
M.cfg.micKey = false; M.toggle = realToggle
-- the overlay hint names Escape
check("overlay hint mentions Esc", M.T("ov_press_esc", "x"):find("Esc", 1, true) ~= nil)
-- ---------- v0.2.4: update check ----------
local vc = M.verCmp
check("semver: 0.2.10 > 0.2.9", vc("0.2.10", "0.2.9") == 1 and vc("0.2.9", "0.2.10") == -1)
check("semver: 0.10.0 > 0.9.12", vc("0.10.0", "0.9.12") == 1)
check("semver: 1.0.0 > 0.99.99", vc("1.0.0", "0.99.99") == 1)
check("semver: v prefix and same", vc("v0.2.4", "0.2.4") == 0 and vc("V0.2.5", "0.2.4") == 1)
check("semver: -beta suffix and missing patch", vc("0.2.5-beta", "0.2.4") == 1 and vc("0.3", "0.2.9") == 1 and vc("0.2", "0.2.0") == 0)
check("semver: garbage gives nil", vc("latest", "0.2.4") == nil and vc(nil, "0.2.4") == nil and vc("", "0.2.4") == nil)
check("version matches install.sh", (function()
  local f = io.open((arg[0]:match("^(.*)/") or ".") .. "/../install.sh"); if not f then return false end
  local v = f:read("a"):match('TAIPEA_VERSION="([^"]+)"'); f:close(); return v == M.VERSION end)())
check("update check on by default", M.cfg.checkForUpdates == true and M.cfg.updateRepo == "PatoSelekta/taipea")
-- link safety: only github.com release pages are opened
local repo, rel = "PatoSelekta/taipea", "https://github.com/PatoSelekta/taipea/releases/latest"
check("link: GitHub release page kept", M.safeURL("https://github.com/PatoSelekta/taipea/releases/tag/v0.2.5", repo) == "https://github.com/PatoSelekta/taipea/releases/tag/v0.2.5")
for _, u in ipairs({ "https://evil.example/PatoSelekta/taipea/releases/tag/v1", "http://github.com/PatoSelekta/taipea/releases/tag/v1",
  "https://github.com.evil.example/a/b/releases/x", "https://github.com/a/b/releases/x\" onclick=\"x", "https://github.com/a/b/releases/x y",
  "https://github.com/PatoSelekta/taipea/archive/main.zip", "javascript:alert(1)", 42 }) do
  check("link: rejected " .. tostring(u), M.safeURL(u, repo) == rel)
end
check("link: nil falls back", M.safeURL(nil, repo) == rel)
-- GitHub answers: a tiny JSON decoder that fails on anything that is not an object
local realDecode, realNotify, realAsyncGet = hs.json.decode, hs.notify, hs.http.asyncGet
hs.json.decode = function(b)
  if not b:match("^%s*{") then error("bad json") end
  return { tag_name = b:match('"tag_name"%s*:%s*"([^"]*)"'), html_url = b:match('"html_url"%s*:%s*"([^"]*)"') }
end
local notes = 0
hs.notify = { new = function() return { send = function() notes = notes + 1 end } end }
local U, S = M.upd, M.updSaved
local function reset() U.latest, U.url, U.result = nil, nil, nil; S.updSkip, S.updRemindUntil, S.updNotified, S.updLatest, S.updUrl = nil, nil, nil, nil, nil end
local function gh(tag, url) return '{"tag_name":"' .. tag .. '","html_url":"' .. (url or ("https://github.com/PatoSelekta/taipea/releases/tag/" .. tag)) .. '"}' end
local savedCopy = {}; for k, v in pairs(S) do savedCopy[k] = v end
reset()
M.cfg.uiLanguage = "en"
M.updResult(200, gh("v0.2.3"), true)
check("older release: no banner", U.result == "ok" and M.updWanted() == false and notes == 0)
check("manual check says up to date", fake.lastAlert == M.T("upd_none", M.VERSION))
M.updResult(200, gh(M.VERSION), false)
check("same release: no banner", U.result == "ok" and M.updWanted() == false)
M.updResult(200, gh("v0.2.10"), false)
check("newer release: banner, latest saved without v", U.result == "new" and U.latest == "0.2.10" and S.updLatest == "0.2.10" and M.updWanted() == true)
check("newer release: link saved", U.url == "https://github.com/PatoSelekta/taipea/releases/tag/v0.2.10" and S.updUrl == U.url)
check("newer release: one notification", notes == 1 and S.updNotified == "0.2.10")
M.updResult(200, gh("v0.2.10"), false)
check("same new release again: no second notification", notes == 1)
M.updResult(200, gh("v0.2.11", "https://evil.example/x"), false)
check("bad html_url replaced by the releases page", U.url == rel and notes == 2)
-- remind me later (7 days) / skip this version
local now = os.time()
M.updLater()
check("remind later: hidden now and for 6 days", M.updWanted(now) == false and M.updWanted(now + 6 * 86400) == false)
check("remind later: back after 7 days", M.updWanted(now + 7 * 86400 + 60) == true)
check("remind later: alert", fake.lastAlert == M.T("upd_later"))
S.updRemindUntil = nil
M.updSkip()
check("skip: this version hidden", S.updSkip == "0.2.11" and M.updWanted() == false and fake.lastAlert == M.T("upd_skipped", "0.2.11"))
M.updResult(200, gh("v0.2.12"), false)
check("skip: a newer version shows again", M.updWanted() == true and notes == 3)
-- errors are only logged; the last good answer is kept
for _, c in ipairs({ { -1, nil, "no network" }, { 403, '{"message":"API rate limit exceeded"}', "HTTP 403" }, { 200, "<html>oops</html>", "bad JSON" },
  { 200, '{"tag_name":"nightly"}', "unreadable tag" }, { 200, '{"name":"x"}', "no tag" } }) do
  fake.lastAlert = nil
  local okc = pcall(M.updResult, c[1], c[2], false)
  check("error (" .. c[3] .. "): no crash, result err, nothing shown", okc and U.result == "err" and fake.lastAlert == nil and U.latest == "0.2.12" and notes == 3)
end
M.updResult(-1, nil, true)
check("manual check error: alert", fake.lastAlert == M.T("upd_err"))
-- the request itself
local got = {}
hs.http.asyncGet = function(url, headers, cb) got[#got + 1] = { url = url, headers = headers }; cb(200, gh("v0.2.12")) end
check("auto check runs when on", M.checkUpdates(false) == true and #got == 1)
check("request goes to the GitHub API", got[1].url == "https://api.github.com/repos/PatoSelekta/taipea/releases/latest"
  and got[1].headers["User-Agent"] == "Taipea/" .. M.VERSION .. " (update check)")
M.cfg.checkForUpdates = false
check("auto check skipped when off", M.checkUpdates(false) == false and #got == 1)
fake.lastAlert = nil
check("Check now works when off", M.checkUpdates(true) == true and #got == 2 and fake.lastAlert == M.T("upd_new", "0.2.12"))
U.checking = true
check("no second request while checking", M.checkUpdates(true) == false and #got == 2)
U.checking = false
M.cfg.checkForUpdates = true
check("update strings in both languages", M.STR.es.upd_menu:find("Nueva versión", 1, true) and M.STR.en.upd_menu:find("New version", 1, true))
hs.json.decode, hs.notify, hs.http.asyncGet = realDecode, realNotify, realAsyncGet
reset(); for k, v in pairs(savedCopy) do S[k] = v end
M.cfg.uiLanguage = "auto"
print(string.format("%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
