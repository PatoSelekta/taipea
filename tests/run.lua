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
hs.keycodes = { map = { space = 49, c = 8, h = 4, v = 9, f = 3 } }
local TY = { flagsChanged = 12, keyDown = 10, leftMouseDown = 1, rightMouseDown = 3, otherMouseDown = 25, scrollWheel = 22, leftMouseUp = 2 }
hs.eventtap = { event = { types = TY }, keyStroke = function() end, checkMouseButtons = function() return {} end,
  new = function(types, fn) local t = { types = types, fn = fn, on = false }
    function t:start() self.on = true; return self end; function t:stop() self.on = false; return self end
    function t:isEnabled() return self.on end
    if types[1] == TY.flagsChanged then fake.tap = t end; return t end }
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
check("default toggle key", table.concat(D.toggleKey.mods, "+") .. "+" .. D.toggleKey.key == "ctrl+alt+space")
check("default mode key", table.concat(D.modeKey.mods, "+") .. "+" .. D.modeKey.key == "ctrl+alt+c")
check("default history key", table.concat(D.historyKey.mods, "+") .. "+" .. D.historyKey.key == "ctrl+alt+h")
local b = table.concat(fake.binds or {}, ",")
check("hotkeys bound at load", b == "ctrl+alt+space,ctrl+alt+c,ctrl+alt+h,ctrl+alt+v")
check("bound uses defaults", M.bound.toggle == D.toggleKey and M.bound.mode == D.modeKey and M.bound.history == D.historyKey and M.bound.pasteLast == D.pasteLastKey and M.bound.fabHide == nil)
check("no Ctrl+Option+F any more", D.fabHideKey == nil and not b:find("ctrl+alt+f", 1, true))
do local seen, dup, cmdAlt = {}, false, false
  for _, k in ipairs({ "toggleKey", "modeKey", "historyKey", "pasteLastKey" }) do
    local m = {}; for _, x in ipairs(D[k].mods) do m[x] = true end
    if m.cmd and m.alt then cmdAlt = true end   -- would also be a Cmd+Option press, which the tap ignores anyway
    local s = table.concat(D[k].mods, "+") .. "+" .. D[k].key; if seen[s] then dup = true end; seen[s] = true end
  check("default shortcuts don't collide", not dup)
  check("no default shortcut uses Cmd+Option (the tap)", not cmdAlt) end
check("default paste-last key", table.concat(D.pasteLastKey.mods, "+") .. "+" .. D.pasteLastKey.key == "ctrl+alt+v")
check("v0.2 defaults", D.voiceControl == false and D.floatButton == true and D.cardWithFab == false and D.textSize == "normal" and D.contrast == "auto"
  and D.silenceSeconds == 3 and #D.customWords == 0 and D.startPhrases[1] == "Taipea escribe" and D.stopPhrases[1] == "listo")
check("default values", D.style == "light" and D.cleanup == true and D.ollamaModel == "gemma4:e4b" and D.language == "auto"
  and D.uiLanguage == "auto" and D.showOverlay == true and D.uiSize == "normal" and D.defaultAction == "paste"
  and D.openAtLogin == true and D.historyMax == 500 and D.maxSeconds == 1800 and D.autoStop == false)

-- interface language: auto follows macOS (stubbed as es-CO), and can be forced
check("auto -> Spanish Mac", M.uiLang() == "es")
check("Spanish string", M.T("ov_listening") == "Escuchando…")
check("Spanish key label", M.keyLabel(D.toggleKey) == "Ctrl + Opción + Espacio")
M.cfg.uiLanguage = "en"
check("forced English", M.uiLang() == "en" and M.T("ov_listening") == "Listening…")
check("English key label", M.keyLabel(D.toggleKey) == "Ctrl + Option + Space")
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

-- ---------- v0.2.3: Option + Command tap ----------
local function tapSeq(steps)
  M.FT.seq, M.FT.both, M.FT.dirty = false, false, false
  local fired = false
  for _, s in ipairs(steps) do if M.fabTapFeed(s[1], s[2], s[3]) then fired = true end end
  return fired
end
local F = "flags"
for _, c in ipairs({
  { "tap, one key then the other", true, { { F, { cmd = true }, 0 }, { F, { cmd = true, alt = true }, 0.1 }, { F, { alt = true }, 0.2 }, { F, {}, 0.25 } } },
  { "tap, both at once", true, { { F, { cmd = true, alt = true }, 0 }, { F, {}, 0.1 } } },
  { "Cmd+Option+key does not toggle", false, { { F, { cmd = true }, 0 }, { F, { cmd = true, alt = true }, 0.1 }, { "key", nil, 0.2 }, { F, { cmd = true }, 0.3 }, { F, {}, 0.35 } } },
  { "Cmd+Option+click does not toggle", false, { { F, { cmd = true, alt = true }, 0 }, { "mouse", nil, 0.1 }, { F, {}, 0.2 } } },
  { "with Shift does not toggle", false, { { F, { cmd = true, alt = true }, 0 }, { F, { cmd = true, alt = true, shift = true }, 0.1 }, { F, {}, 0.2 } } },
  { "with Control does not toggle", false, { { F, { ctrl = true, cmd = true, alt = true }, 0 }, { F, {}, 0.2 } } },
  { "with Fn does not toggle", false, { { F, { fn = true, cmd = true, alt = true }, 0 }, { F, {}, 0.2 } } },
  { "too slow (1.4 s) does not toggle", false, { { F, { cmd = true }, 0 }, { F, { cmd = true, alt = true }, 0.5 }, { F, {}, 1.4 } } },
  { "Command alone does not toggle", false, { { F, { cmd = true }, 0 }, { F, {}, 0.1 } } },
  { "Option alone does not toggle", false, { { F, { alt = true }, 0 }, { F, {}, 0.1 } } },
  { "Cmd+Tab then Option does not toggle", false, { { F, { cmd = true }, 0 }, { "key", nil, 0.05 }, { F, { cmd = true, alt = true }, 0.1 }, { F, {}, 0.2 } } },
}) do check("tap: " .. c[1], tapSeq(c[3]) == c[2]) end
check("tap: a clean tap right after a cancelled one", tapSeq({ { F, { cmd = true, alt = true }, 0 }, { "key", nil, 0.05 }, { F, {}, 0.1 } }) == false
  and tapSeq({ { F, { cmd = true, alt = true }, 1 }, { F, {}, 1.1 } }) == true)
-- the real event tap: started, watches the right events, never consumes them
local tap = fake.tap
check("event tap started", tap ~= nil and tap.on == true and M.fabTapOK == true)
local function ev(t, fl) return { getType = function() return t end, getFlags = function() return fl or {} end } end
check("event tap never consumes keys", tap.fn(ev(TY.keyDown)) == false and tap.fn(ev(TY.flagsChanged, { cmd = true })) == false
  and tap.fn(ev(TY.flagsChanged, { cmd = true, alt = true })) == false and tap.fn(ev(TY.flagsChanged, {})) == false)
local watches = {}; for _, x in ipairs(tap.types) do watches[x] = true end
check("event tap watches keys, clicks and scrolls", watches[TY.flagsChanged] and watches[TY.keyDown] and watches[TY.leftMouseDown] and watches[TY.scrollWheel])
check("tap label in both languages", M.STR.en.fab_tap_key == "Option + Command" and M.STR.es.fab_tap_key == "Opción + Comando")
check("hidden alert names the tap", M.T("fab_hidden", M.T("fab_tap_key")):find("Opción + Comando", 1, true) ~= nil)
M.cfg.uiLanguage = "en"
check("hidden alert names the tap (en)", M.T("fab_hidden", M.T("fab_tap_key")) == "Floating button hidden (tap Option + Command to show it again)")
M.cfg.uiLanguage = "auto"
print(string.format("%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
