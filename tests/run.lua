-- Offline tests for Taipea's text logic. Runs with plain Lua 5.4 (no Mac needed):
--   lua tests/run.lua
-- A tiny fake "hs" table stands in for Hammerspoon.
local function proxy()
  local p = {}
  return setmetatable(p, { __index = function() return proxy() end, __call = function() return proxy() end })
end
local fake = { files = {}, ollamaList = "", post = nil, now = 0 }
hs = proxy()
hs.fs = {
  attributes = function(p, a) local m = fake.files[p]; if a then return m end; return m and { mode = m } or nil end,
  mkdir = function(p) fake.files[p] = "directory"; return true end,
  rmdir = function(p)
    fake.files[p] = nil
    local prefix = p .. "/"
    for k in pairs(fake.files) do
      if k:sub(1, #prefix) == prefix then fake.files[k] = nil end
    end
    return true
  end,
  dir = function(p)
    local prefix = (p or ""):sub(-1) == "/" and p or ((p or "") .. "/")
    local names, seen, i = {}, {}, 0
    for k in pairs(fake.files) do
      if k:sub(1, #prefix) == prefix then
        local name = k:sub(#prefix + 1):match("^([^/]+)")
        if name and not seen[name] then seen[name] = true; names[#names + 1] = name end
      end
    end
    return function() i = i + 1; return names[i] end
  end,
}
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
hs.task = { new = function(cmd, cb, args) local t = { cmd = cmd, cb = cb, args = args, terminated = false, interrupted = false }
  function t:start() fake.tasks[#fake.tasks + 1] = t; return t end
  function t:terminate() self.terminated = true end
  function t:interrupt() self.interrupted = true end
  return t end }
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
M.updResult(200, gh("v0.2.11"), false)
check("newer release: banner, latest saved without v", U.result == "new" and U.latest == "0.2.11" and S.updLatest == "0.2.11" and M.updWanted() == true)
check("newer release: link saved", U.url == "https://github.com/PatoSelekta/taipea/releases/tag/v0.2.11" and S.updUrl == U.url)
check("newer release: one notification", notes == 1 and S.updNotified == "0.2.11")
M.updResult(200, gh("v0.2.11"), false)
check("same new release again: no second notification", notes == 1)
M.updResult(200, gh("v0.2.12", "https://evil.example/x"), false)
check("bad html_url replaced by the releases page", U.url == rel and notes == 2)
-- remind me later (7 days) / skip this version
local now = os.time()
M.updLater()
check("remind later: hidden now and for 6 days", M.updWanted(now) == false and M.updWanted(now + 6 * 86400) == false)
check("remind later: back after 7 days", M.updWanted(now + 7 * 86400 + 60) == true)
check("remind later: alert", fake.lastAlert == M.T("upd_later"))
S.updRemindUntil = nil
M.updSkip()
check("skip: this version hidden", S.updSkip == "0.2.12" and M.updWanted() == false and fake.lastAlert == M.T("upd_skipped", "0.2.12"))
M.updResult(200, gh("v0.2.13"), false)
check("skip: a newer version shows again", M.updWanted() == true and notes == 3)
-- errors are only logged; the last good answer is kept
for _, c in ipairs({ { -1, nil, "no network" }, { 403, '{"message":"API rate limit exceeded"}', "HTTP 403" }, { 200, "<html>oops</html>", "bad JSON" },
  { 200, '{"tag_name":"nightly"}', "unreadable tag" }, { 200, '{"name":"x"}', "no tag" } }) do
  fake.lastAlert = nil
  local okc = pcall(M.updResult, c[1], c[2], false)
  check("error (" .. c[3] .. "): no crash, result err, nothing shown", okc and U.result == "err" and fake.lastAlert == nil and U.latest == "0.2.13" and notes == 3)
end
M.updResult(-1, nil, true)
check("manual check error: alert", fake.lastAlert == M.T("upd_err"))
-- the request itself
local got = {}
hs.http.asyncGet = function(url, headers, cb) got[#got + 1] = { url = url, headers = headers }; cb(200, gh("v0.2.13")) end
check("auto check runs when on", M.checkUpdates(false) == true and #got == 1)
check("request goes to the GitHub API", got[1].url == "https://api.github.com/repos/PatoSelekta/taipea/releases/latest"
  and got[1].headers["User-Agent"] == "Taipea/" .. M.VERSION .. " (update check)")
M.cfg.checkForUpdates = false
check("auto check skipped when off", M.checkUpdates(false) == false and #got == 1)
fake.lastAlert = nil
check("Check now works when off", M.checkUpdates(true) == true and #got == 2 and fake.lastAlert == M.T("upd_new", "0.2.13"))
U.checking = true
check("no second request while checking", M.checkUpdates(true) == false and #got == 2)
U.checking = false
M.cfg.checkForUpdates = true
check("update strings in both languages", M.STR.es.upd_menu:find("Nueva versión", 1, true) and M.STR.en.upd_menu:find("New version", 1, true))
hs.json.decode, hs.notify, hs.http.asyncGet = realDecode, realNotify, realAsyncGet
reset(); for k, v in pairs(savedCopy) do S[k] = v end
M.cfg.uiLanguage = "auto"
-- ---------- v0.2.6: silence and hallucination guard ----------
do
  local SIL = "Pk lev dB       -inf\nRMS lev dB      -inf\nRMS Pk dB       -inf\nRMS Tr dB       -inf\nLength s       2.000\n"
  local ROOM = "Pk lev dB     -24.10\nRMS lev dB    -31.50\nRMS Pk dB     -29.80\nRMS Tr dB     -33.20\nLength s       4.100\n"
  local SPEECH = "Pk lev dB      -3.20\nRMS lev dB    -19.00\nRMS Pk dB     -14.50\nRMS Tr dB     -41.00\nLength s      12.400\n"
  local QUIETSPEECH = "Pk lev dB     -20.00\nRMS lev dB    -33.00\nRMS Pk dB     -31.00\nRMS Tr dB     -48.00\nLength s       3.000\n"
  local lvS, lvR, lvP, lvQ = M.parseStats(SIL), M.parseStats(ROOM), M.parseStats(SPEECH), M.parseStats(QUIETSPEECH)
  check("stats: -inf read as -200", lvS.rmsPk == -200 and lvS.len == 2)
  check("stats: numbers read", lvP.pk == -3.2 and lvP.rms == -19 and lvP.rmsPk == -14.5 and lvP.rmsTr == -41 and lvP.len == 12.4)
  check("stats: garbage gives nils", M.parseStats("sox FAIL").rmsPk == nil)
  check("silent: digital silence", M.isSilent(lvS) == true)
  check("silent: below -40 dB", M.isSilent({ rmsPk = -45, rmsTr = -60, len = 3 }) == true)
  check("silent: flat room noise", M.isSilent(lvR) == true)
  check("not silent: speech", M.isSilent(lvP) == false)
  check("not silent: quiet speech that rises above the room", M.isSilent(lvQ) == false)
  check("not silent: unknown levels", M.isSilent(nil) == false and M.isSilent({}) == false)
  check("silent: under 0.3 s", M.isSilent({ rmsPk = -15, len = 0.2 }) == true)
  -- scripts
  local JA, RU = "ご視聴ありがとうございました", "Продолжение следует..."
  check("non-Latin: Japanese", M.mostlyNonLatin(JA) == true and M.mostlyNonLatin(RU) == true)
  check("Latin: Spanish with accents", M.mostlyNonLatin("¿Mañana vamos a la reunión?") == false)
  check("Latin: Vietnamese counts as Latin", M.mostlyNonLatin("Tiếng Việt rất đẹp") == false)
  check("Latin: a Japanese word inside Spanish", M.mostlyNonLatin("La palabra arigato es ありがとう en japonés") == false)
  check("letters: punctuation only has none", M.hasLetters(" ... !? ") == false and M.hasLetters("ok") == true and M.hasLetters(JA) == true)
  check("script filter only for en / es", M.scriptFilterOn("en") and M.scriptFilterOn("es") and not M.scriptFilterOn("auto"))
  -- judge
  check("judge: empty", M.judgeRaw("  . . ", lvP, "auto") == "empty" and M.judgeRaw("", lvP, "en") == "empty")
  check("judge: Japanese with English set -> retry", M.judgeRaw(JA .. " 日本語", lvP, "en") == "script")
  check("judge: Japanese with Español set -> retry", M.judgeRaw("こんにちは世界", lvP, "es") == "script")
  check("judge: Japanese in Auto is a real dictation", M.judgeRaw("こんにちは、今日は良い天気です", lvP, "auto") == "ok")
  check("judge: Russian in Auto is a real dictation", M.judgeRaw("Привет, как дела?", lvP, "auto") == "ok")
  check("judge: Auto silence phrase in Japanese when quiet", M.judgeRaw(JA .. "。", lvQ, "auto") == "hallucination")
  check("judge: Auto Japanese phrase when loud is kept", M.judgeRaw(JA, lvP, "auto") == "ok")
  check("judge: Thanks for watching, short clip", M.judgeRaw("Thanks for watching!", { rmsPk = -18, len = 3 }, "auto") == "hallucination")
  check("judge: Amara subtitles, quiet", M.judgeRaw("Subtítulos realizados por la comunidad de Amara.org", lvQ, "es") == "hallucination")
  check("judge: Thanks for watching inside a long loud dictation is kept", M.judgeRaw("Thanks for watching", lvP, "en") == "ok")
  check("judge: Gracias alone when quiet is dropped", M.judgeRaw("Gracias.", lvQ, "auto") == "hallucination")
  check("judge: Gracias alone when loud is kept", M.judgeRaw("Gracias.", { rmsPk = -16, len = 1.5 }, "auto") == "ok")
  check("judge: phrase only as the whole output", M.judgeRaw("Gracias por ver el informe de ventas", lvQ, "es") == "ok")
  check("judge: normal text", M.judgeRaw("Hola, necesito the report", nil, "auto") == "ok")
  -- retries
  check("retry langs skip the one used", table.concat(M.retryLangs("en"), ",") == "es" and table.concat(M.retryLangs("es"), ",") == "en")
  local b = M.pickRetry({ { lang = "es", text = "Hola, cómo estás, yo creo que está bien" }, { lang = "en", text = "Hola como estas yo creo" } }, lvP)
  check("retry: better fit kept", b and b.lang == "es")
  check("retry: nothing usable", M.pickRetry({ { lang = "en", text = JA }, { lang = "es", text = "..." } }, lvP) == nil)
  -- afterRaw flow
  local realAW, got = M.afterWhisper, nil
  M.afterWhisper = function(t) got = t end
  local oldLang, oldWhisper = M.cfg.language, M.cfg.whisper
  M.cfg.whisper = "/usr/local/bin/whisper-cli"
  M.cfg.uiLanguage = "en"
  M._lv = lvP
  M.cfg.language = "auto"; got = nil; local nt = #fake.tasks
  M.afterRaw("こんにちは、今日は良い天気です", "/tmp/x.wav")
  check("afterRaw Auto: non-Latin pasted, no retry", got == "こんにちは、今日は良い天気です" and #fake.tasks == nt)
  M.cfg.language = "en"; got = nil; nt = #fake.tasks
  M.afterRaw("Hello there, how are you", "/tmp/x.wav")
  check("afterRaw: normal text passes", got == "Hello there, how are you" and #fake.tasks == nt)
  got = nil; nt = #fake.tasks; fake.lastAlert = nil
  M.afterRaw(JA, "/tmp/x.wav")
  local tk = fake.tasks[#fake.tasks]
  local function argOf(t, flag) for i, a in ipairs(t.args or {}) do if a == flag then return t.args[i + 1] end end end
  check("afterRaw English: one retry with -l es", #fake.tasks == nt + 1 and argOf(tk, "-l") == "es" and got == nil)
  tk.cb(0, "\n[00:00:00.000 --> 00:00:02.500]   Hola, ¿cómo estás? Yo creo que está bien.\n\n")
  check("afterRaw English: usable retry pasted", got == " Hola, ¿cómo estás? Yo creo que está bien.")
  got = nil; nt = #fake.tasks; fake.lastAlert = nil
  M.cfg.language = "es"
  M.afterRaw(RU, "/tmp/x.wav")
  tk = fake.tasks[#fake.tasks]
  check("afterRaw Español: retry with -l en", #fake.tasks == nt + 1 and argOf(tk, "-l") == "en")
  tk.cb(0, "Продолжение следует")
  check("afterRaw: unusable retry -> nothing heard", got == nil and fake.lastAlert == M.T("nothing_heard"))
  fake.lastAlert = nil
  M.afterRaw(" ... ", "/tmp/x.wav")
  check("afterRaw: no letters -> nothing heard", got == nil and fake.lastAlert == "Nothing heard · nothing was pasted")
  M.cfg.uiLanguage = "es"; fake.lastAlert = nil; M._lv = lvQ
  M.afterRaw("Thank you.", "/tmp/x.wav")
  check("afterRaw: silence phrase -> nothing heard (Spanish UI)", got == nil and fake.lastAlert == "No se escuchó nada · no se pegó nada")
  M._voicePrefix = "hola"; M._lv = lvQ
  M.afterRaw("Thank you.", "/tmp/x.wav")
  check("afterRaw: voice start phrase session is never dropped", got == "Thank you.")
  M._voicePrefix = nil
  -- transcribe measures the recording with sox first
  local base = os.tmpname()
  for _, n in ipairs({ "_rec", "_sox", "_whisper" }) do local f = io.open(base .. n, "w"); f:write("x"); f:close() end
  local oldRec, oldAttr = M.cfg.rec, hs.fs.attributes
  M.cfg.rec, M.cfg.whisper = base .. "_rec", base .. "_whisper"
  hs.fs.attributes = function(p, a) if p == "/tmp/x.wav" then return a and nil or { size = 200000 } end; return oldAttr(p, a) end
  M.cfg.uiLanguage = "en"; M.cfg.language = "auto"
  nt = #fake.tasks; fake.lastAlert = nil
  M.transcribeFile("/tmp/x.wav")
  tk = fake.tasks[#fake.tasks]
  check("transcribe: sox stats runs first", #fake.tasks == nt + 1 and tk.cmd == base .. "_sox" and tk.args[1] == "/tmp/x.wav" and tk.args[3] == "stats")
  tk.cb(0, "", SIL)
  check("transcribe: silent recording skips Whisper", #fake.tasks == nt + 1 and fake.lastAlert == M.T("nothing_heard"))
  nt = #fake.tasks; fake.lastAlert = nil
  M.transcribeFile("/tmp/x.wav")
  fake.tasks[#fake.tasks].cb(0, "", SPEECH)
  tk = fake.tasks[#fake.tasks]
  check("transcribe: quiet start/end measured after the levels", #fake.tasks == nt + 2 and tk.cmd == "/bin/sh" and tk.args[3] == base .. "_sox" and tk.args[4] == "/tmp/x.wav" and tk.args[5] == "-31.0d")
  -- 12.4 s recording: sound from 1.4 s to 9.0 s -> keep 1.1-9.5 s
  local trimF = M.TRIM.file
  hs.fs.attributes = function(p, a) if p == "/tmp/x.wav" or p == trimF then return a and nil or { size = 200000 } end; return oldAttr(p, a) end
  tk.cb(0, "Length s      11.000\n==\nLength s       9.000\n", "")
  tk = fake.tasks[#fake.tasks]
  check("transcribe: sox cuts the quiet tail", #fake.tasks == nt + 3 and tk.cmd == base .. "_sox" and tk.args[2] == trimF and tk.args[3] == "trim" and tk.args[4] == "1.100" and tk.args[5] == "=9.500")
  tk.cb(0, "", "")
  tk = fake.tasks[#fake.tasks]
  check("transcribe: speech goes on to Whisper", #fake.tasks == nt + 4 and tk.cmd == base .. "_whisper" and argOf(tk, "-l") == "auto" and fake.lastAlert == nil)
  check("transcribe: Whisper gets the trimmed file", argOf(tk, "-f") == trimF)
  local hasNt = false; for _, a in ipairs(tk.args) do if a == "-nt" then hasNt = true end end
  check("transcribe: Whisper runs with timestamps (no -nt)", not hasNt)
  check("transcribe: levels kept for the checks", M._lv and M._lv.rmsPk == -14.5)
  got = nil; tk.cb(0, "\n[00:00:00.000 --> 00:00:07.900]   Hola equipo, mañana a las nueve.\n[00:00:07.900 --> 00:00:08.400]   Thank you.\n\n")
  check("transcribe: made-up Thank you after the last sound removed", got == " Hola equipo, mañana a las nueve.")
  -- the same, but the last sound is later: the phrase's window is measured
  nt = #fake.tasks
  M.transcribeFile("/tmp/x.wav")
  fake.tasks[#fake.tasks].cb(0, "", SPEECH)
  fake.tasks[#fake.tasks].cb(0, "Length s      11.000\n==\nLength s       9.000\n", "")
  fake.tasks[#fake.tasks].cb(0, "", "")
  got = nil; fake.tasks[#fake.tasks].cb(0, "[00:00:00.000 --> 00:00:06.000]   Can you check the notes?\n[00:00:06.000 --> 00:00:07.200]   Thank you.\n")
  tk = fake.tasks[#fake.tasks]
  check("transcribe: spoken-looking Thank you gets its window measured", got == nil and tk.cmd == base .. "_sox" and tk.args[1] == trimF and tk.args[3] == "trim" and tk.args[4] == "6.000" and tk.args[5] == "1.200")
  tk.cb(0, "", "RMS Pk dB     -16.00\n")
  check("transcribe: Thank you with voice in its window is kept", got == " Can you check the notes? Thank you.")
  -- trimming fails -> the whole recording is used
  nt = #fake.tasks
  M.transcribeFile("/tmp/x.wav")
  fake.tasks[#fake.tasks].cb(0, "", SPEECH)
  fake.tasks[#fake.tasks].cb(0, "Length s      11.000\n==\nLength s       9.000\n", "")
  hs.fs.attributes = function(p, a) if p == "/tmp/x.wav" then return a and nil or { size = 200000 } end; return oldAttr(p, a) end
  fake.tasks[#fake.tasks].cb(2, "", "sox FAIL")
  tk = fake.tasks[#fake.tasks]
  check("transcribe: failed trim falls back to the original", tk.cmd == base .. "_whisper" and argOf(tk, "-f") == "/tmp/x.wav")
  got = nil; tk.cb(0, " Hola equipo, mañana a las nueve.\n")
  check("transcribe: plain Whisper output still works", got == " Hola equipo, mañana a las nueve.")
  -- unreadable trim analysis -> the whole recording is used
  M.transcribeFile("/tmp/x.wav")
  fake.tasks[#fake.tasks].cb(0, "", SPEECH)
  fake.tasks[#fake.tasks].cb(1, "sox FAIL", "")
  check("transcribe: unreadable trim analysis falls back to the original", fake.tasks[#fake.tasks].cmd == base .. "_whisper" and argOf(fake.tasks[#fake.tasks], "-f") == "/tmp/x.wav")
  nt = #fake.tasks
  M.transcribeFile("/tmp/x.wav")
  fake.tasks[#fake.tasks].cb(1, "", "sox FAIL formats")
  check("transcribe: unreadable levels still transcribe", fake.tasks[#fake.tasks].cmd == base .. "_whisper" and #fake.tasks == nt + 2)
  for _, n in ipairs({ "_rec", "_sox", "_whisper" }) do os.remove(base .. n) end
  os.remove(base)
  hs.fs.attributes, M.cfg.rec, M.cfg.whisper, M.cfg.language = oldAttr, oldRec, oldWhisper, oldLang
  M.afterWhisper, M._lv = realAW, nil
  M.cfg.uiLanguage = "auto"
  check("version 0.2.10", M.VERSION == "0.2.10")
end
-- ---------- v0.2.8: quiet-tail trim and trailing phrase guard ----------
do
  check("trim threshold: room floor + 10 dB", M.trimThreshold({ rmsTr = -42.1, rmsPk = -16.5 }) == -32.1)
  check("trim threshold: digital silence does not pull it under the room", M.trimThreshold({ rmsTr = -200, rmsPk = -18 }) == -36)
  check("trim threshold: never above -30 dB", M.trimThreshold({ rmsTr = -25, rmsPk = -10 }) == -30)
  check("trim threshold: never below -48 dB", M.trimThreshold({ rmsTr = -80, rmsPk = -70 }) == -82)
  check("trim threshold: unknown levels", M.trimThreshold(nil) == -48)
  local pl = M.trimPlan(31.45, 30.23, 30.17)
  check("trim plan: keeps 0.3 s before and 0.5 s after the sound", pl and math.abs(pl.start - 0.92) < 0.01 and math.abs(pl.stop - 30.67) < 0.01 and pl.cut)
  check("trim plan: speech end in the trimmed file", pl and math.abs(pl.speechEnd - (30.17 - 0.92)) < 0.01)
  local p2 = M.trimPlan(5.0, 4.9, 4.7)
  check("trim plan: tiny margins are not cut", p2 and p2.start == 0 and p2.stop == 5.0 and not p2.cut and math.abs(p2.speechEnd - 4.7) < 0.001)
  check("trim plan: no sound -> nil", M.trimPlan(5.0, 0.1, 0.1) == nil)
  check("trim plan: missing numbers -> nil", M.trimPlan(5.0, nil, 4) == nil and M.trimPlan(nil, 4, 4) == nil)
  check("trim plan: bad numbers -> nil", M.trimPlan(5.0, 9, 4) == nil and M.trimPlan(5.0, 0, 4) == nil)
  local p3 = M.trimPlan(10, 9.9, 9.95)
  check("trim plan: never past the end", p3 and p3.stop == 10)
  local txt, segs = M.parseWhisper("\n[00:00:00.000 --> 00:00:29.640]   Hola equipo.\n[00:00:30.000 --> 00:01:03.060]   [BLANK_AUDIO] Nos vemos mañana.\n\n")
  check("parse: segments with times", #segs == 2 and segs[1].from == 0 and math.abs(segs[1].to - 29.64) < 0.001 and segs[2].from == 30 and math.abs(segs[2].to - 63.06) < 0.001)
  check("parse: text joined, BLANK_AUDIO removed", txt == " Hola equipo. Nos vemos mañana.")
  local t2, s2 = M.parseWhisper(" Plain text\n second line\n")
  check("parse: plain output kept", t2 == " Plain text second line" and #s2 == 0)
  check("parse: nothing", (M.parseWhisper("")) == "" and (M.parseWhisper(nil)) == "")
  local function S(...) local r = {}; for i, t in ipairs({ ... }) do r[i] = { from = i - 1, to = i, text = t } end; return r end
  check("tail phrase: Thank you as the last segment", M.tailPhrase(S("Can you check it?", "Thank you.")) == 2)
  check("tail phrase: Gracias as the last segment", M.tailPhrase(S("Mira esos links.", "¡Gracias!")) == 2)
  check("tail phrase: Amara subtitles", M.tailPhrase(S("Hola.", "Subtítulos realizados por la comunidad de Amara.org")) == 2)
  check("tail phrase: empty last segments skipped", M.tailPhrase(S("Hola.", "Gracias.", " ")) == 2)
  check("tail phrase: Thank you inside the sentence is not one", M.tailPhrase(S("Can you check it? Thank you.")) == nil)
  check("tail phrase: alone is left to the silence guard", M.tailPhrase(S("Thank you.")) == nil)
  check("tail phrase: other last words are kept", M.tailPhrase(S("Hola.", "Gracias por venir.")) == nil and M.tailPhrase(S("Hi.", "Thanks to Ana.")) == nil)
  check("tail phrase: needs real text before it", M.tailPhrase(S("...", "Thank you.")) == nil)
  -- tailGuard directly
  local res
  M.tailGuard(" Hola. Gracias.", { { from = 0, to = 2, text = "Hola." }, { from = 2.6, to = 3.1, text = "Gracias." } }, "/tmp/x.wav", { speechEnd = 2.5, thr = -32 }, function(t) res = t end)
  check("tail guard: after the last sound -> removed", res == " Hola.")
  res = nil
  local n0, oldRec2 = #fake.tasks, M.cfg.rec
  M.cfg.rec = "/nonexistent/bin/rec"
  M.tailGuard(" Hola. Gracias.", { { from = 0, to = 2, text = "Hola." }, { from = 2.0, to = 3.0, text = "Gracias." } }, "/tmp/x.wav", nil, function(t) res = t end)
  check("tail guard: without sox it is kept", res == " Hola. Gracias." and #fake.tasks == n0)
  local b2 = os.tmpname(); for _, n in ipairs({ "_rec", "_sox" }) do local f = io.open(b2 .. n, "w"); f:write("x"); f:close() end
  M.cfg.rec = b2 .. "_rec"
  res = nil
  M.tailGuard(" Hola. Gracias.", { { from = 0, to = 2, text = "Hola." }, { from = 2.0, to = 3.0, text = "Gracias." } }, "/tmp/x.wav", { speechEnd = 2.9, thr = -32 }, function(t) res = t end)
  local tk2 = fake.tasks[#fake.tasks]
  check("tail guard: overlapping the voice -> its window is measured", res == nil and tk2.cmd == b2 .. "_sox" and tk2.args[4] == "2.000")
  tk2.cb(0, "", "RMS Pk dB     -40.00\n")
  check("tail guard: no voice in the window -> removed", res == " Hola.")
  res = nil
  M.tailGuard(" Hola. Gracias.", { { from = 0, to = 2, text = "Hola." }, { from = 2.0, to = 3.0, text = "Gracias." } }, "/tmp/x.wav", { speechEnd = 2.9, thr = -32 }, function(t) res = t end)
  fake.tasks[#fake.tasks].cb(0, "", "RMS Pk dB     -18.00\n")
  check("tail guard: voice in the window -> kept", res == " Hola. Gracias.")
  res = nil
  M.tailGuard(" Hola. Gracias.", { { from = 0, to = 2, text = "Hola." }, { from = 2.0, to = 3.0, text = "Gracias." } }, "/tmp/x.wav", { speechEnd = 2.9, thr = -32 }, function(t) res = t end)
  fake.tasks[#fake.tasks].cb(1, "", "sox FAIL")
  check("tail guard: unmeasurable window -> kept", res == " Hola. Gracias.")
  res = nil
  M.tailGuard(" Can you check it? Thank you.", { { from = 0, to = 3, text = "Can you check it? Thank you." } }, "/tmp/x.wav", { speechEnd = 1, thr = -32 }, function(t) res = t end)
  check("tail guard: phrase inside the last segment is never touched", res == " Can you check it? Thank you.")
  for _, n in ipairs({ "_rec", "_sox" }) do os.remove(b2 .. n) end; os.remove(b2)
  M.cfg.rec = oldRec2
end
-- ---------- live overlapping slices (Approach A) ----------
do
  check("liveTranscribe default on", D.liveTranscribe == true)
  check("language still Auto", D.language == "auto")
  check("live constants: 24 s slice, 4 s overlap, 40 s backlog", M.LIVE.SLICE == 24 and M.LIVE.OVERLAP == 4 and M.LIVE.FALLBACK_SECS == 40)
  local w15 = M.liveWindows(15)
  check("windows: short clip is one last slice", #w15 == 1 and w15[1].from == 0 and w15[1].to == 15 and w15[1].last)
  local w50 = M.liveWindows(50)
  check("windows: 50 s is 0-24, 20-44, 40-50", #w50 == 3
    and w50[1].from == 0 and w50[1].to == 24 and not w50[1].last
    and w50[2].from == 20 and w50[2].to == 44 and not w50[2].last
    and w50[3].from == 40 and w50[3].to == 50 and w50[3].last)
  local w24 = M.liveWindows(24)
  check("windows: exactly one slice", #w24 == 1 and w24[1].to == 24 and w24[1].last)
  local w44 = M.liveWindows(44)
  check("windows: 44 s last window is 20-44", #w44 == 2 and w44[2].from == 20 and w44[2].to == 44 and w44[2].last)
  local w48 = M.liveWindows(48)
  check("windows: 48 s is 0-24, 20-44, 40-48", #w48 == 3 and w48[3].from == 40 and w48[3].to == 48 and w48[3].last)
  check("windows: empty / zero", #M.liveWindows(0) == 0 and #M.liveWindows(nil) == 0)
  check("backlog: 50 s with nothing done", M.liveBacklog(50, 0) == true)
  check("backlog: 50 s after first 24 s is ok", M.liveBacklog(50, 20) == false)
  check("backlog: 15 s whole remainder is ok", M.liveBacklog(15, 0) == false)
  check("backlog: exactly 40 s leftover is ok", M.liveBacklog(40, 0) == false)
  check("backlog: 40.1 s leftover falls back", M.liveBacklog(40.1, 0) == true)

  M.LIVE.cur, M.LIVE.queue, M.LIVE.nextFrom = { from = 0 }, { { from = 20 } }, 40
  check("pending: in-flight start wins", M.livePendingFrom() == 0)
  M.LIVE.cur = nil
  check("pending: queue head", M.livePendingFrom() == 20)
  M.LIVE.queue = {}
  check("pending: nextFrom when idle", M.livePendingFrom() == 40)
  M.LIVE.nextFrom = nil
  check("pending: zero when empty", M.livePendingFrom() == 0)

  local j, k, weak = M.liveJoin("necesito the report", "the report antes del viernes")
  check("stitch: 2-word overlap mixed EN/ES", j == "necesito the report antes del viernes" and k == 2 and not weak)
  j, k, weak = M.liveJoin("necesito the", "the report")
  check("stitch: 1-word overlap keeps both sides", j == "necesito the report" and k == 1 and weak)
  j, k, weak = M.liveJoin("hola mundo", "equipo mañana")
  check("stitch: no overlap concatenates and is weak", j == "hola mundo equipo mañana" and k == 0 and weak)
  j, k, weak = M.liveJoin("Hola equipo. Nos vemos", "nos vemos mañana.")
  check("stitch: folded overlap, drop older tail", j == "Hola equipo. nos vemos mañana." and k == 2 and not weak)
  j, k, weak = M.liveJoin("áé team report", "ae team report done")
  check("stitch: accents fold for the overlap", j == "áé team report done" and k == 3 and not weak)
  check("stitch: empty left", M.liveJoin("", "hola") == "hola")
  check("stitch: empty right", M.liveJoin("hola", "") == "hola")
  check("stitch: punctuation after overlap", (M.liveJoin("Hola equipo.", "equipo. Listo.")) == "Hola equipo. Listo.")
  local dropKeep = M.liveDropTail(
    "Hola equipo. nos vemos mañana. Thank you.",
    { { from = 0, to = 2, text = "nos vemos mañana." }, { from = 2, to = 3, text = "Thank you." } },
    2)
  check("drop tail keeps earlier live slices", dropKeep == "Hola equipo. nos vemos mañana.")
  check("drop tail no-op without index", M.liveDropTail("hola", { { from = 0, to = 1, text = "hola" } }, nil) == "hola")

  local segs = {
    { from = 0, to = 2, text = "Hola." },
    { from = 2, to = 4, text = "Gracias." },
  }
  local shifted = M.liveShiftSegs(segs, 20)
  check("shift segs into session time", shifted[1].from == 20 and shifted[2].to == 24 and segs[1].from == 0)

  M.LIVE.gen = 7
  M.LIVE.fallback = nil
  check("stale: other gen", M.liveStale(3) == true)
  check("stale: current gen", M.liveStale(7) == false)
  M.LIVE.fallback = "trim"
  check("stale: fallback flags current gen", M.liveStale(7) == true)
  M.LIVE.fallback = nil
  M._setState("rec")
  local trimT = { terminated = false, terminate = function(self) self.terminated = true end }
  local lvT = { terminated = false, terminate = function(self) self.terminated = true end }
  local wT = { terminated = false, terminate = function(self) self.terminated = true end }
  M.trimTask, M.lvTask, M.wTask = trimT, lvT, wT
  local cancelDir = M.liveSessionDir(7)
  fake.files[cancelDir] = "directory"
  fake.files[cancelDir .. "/rec.wav"] = "file"
  M.LIVE.dir = cancelDir
  M.cancel()
  check("cancel terminates trimTask", trimT.terminated == true)
  check("cancel terminates lvTask", lvT.terminated == true)
  check("cancel terminates wTask", wT.terminated == true)
  check("cancel bumps live gen so in-flight cbs are stale", M.liveStale(7) == true)
  check("cancel cleared trim/lv slots", M.trimTask == nil and M.lvTask == nil)
  check("cancel cleared live task/cur", M.LIVE.task == nil and M.LIVE.cur == nil)
  check("cancel removes the session dir", fake.files[cancelDir] == nil and M.LIVE.dir == nil)

  local a = M.whisperArgs("/tmp/s1/slice.wav")
  local hasNt, hasTr, hasF, hasNp = false, false, false, false
  for i, x in ipairs(a) do
    if x == "-nt" then hasNt = true end
    if x == "-tr" or x == "--translate" then hasTr = true end
    if x == "-f" and a[i + 1] == "/tmp/s1/slice.wav" then hasF = true end
    if x == "-np" then hasNp = true end
  end
  check("live whisper args: timestamps on (no -nt)", not hasNt)
  check("live whisper args: never translate", not hasTr)
  check("live whisper args: file and -np", hasF and hasNp)
  check("live whisper args: language Auto", (function()
    for i, x in ipairs(a) do if x == "-l" then return a[i + 1] == "auto" end end
  end)())

  local src = io.open((arg[0]:match("^(.*)/") or ".") .. "/../src/taipea.lua"):read("*a")
  local nloc = 0
  for line in (src .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^local%s+function%s+") then
      nloc = nloc + 1
    elseif line:match("^local%s+") then
      local left = (line:match("^local%s+([^=]+)") or ""):gsub("%-%-.*$", "")
      for name in left:gmatch("([A-Za-z_][A-Za-z0-9_]*)") do nloc = nloc + 1 end
    end
  end
  check("main-chunk locals stay at or under 200 (" .. nloc .. ")", nloc <= 200)

  local dir = M.liveSessionDir(3)
  check("session dir is isolated under tmp/s<gen>", type(dir) == "string" and dir:find("/tmp/s3", 1, true) ~= nil)
  check("session dir is not the shared rec.wav root", not dir:match("tmp/rec%.wav$"))

  local tmpRoot = dir:match("^(.*)/s3$")
  fake.files[tmpRoot] = "directory"
  fake.files[dir] = "directory"
  fake.files[dir .. "/rec.wav"] = "file"
  fake.files[tmpRoot .. "/rec.wav"] = "file"
  fake.files[tmpRoot .. "/foo"] = "directory"
  check("cleanup refuses empty", M.liveCleanupDir("") == false and M.liveCleanupDir(nil) == false)
  check("cleanup refuses a path outside Taipea tmp", M.liveCleanupDir("/tmp/s3") == false and fake.files[dir] == "directory")
  check("cleanup refuses non-s* tmp dirs", M.liveCleanupDir(tmpRoot .. "/foo") == false and fake.files[tmpRoot .. "/foo"] == "directory")
  check("cleanup refuses the shared rec.wav", M.liveCleanupDir(tmpRoot .. "/rec.wav") == false and fake.files[tmpRoot .. "/rec.wav"] == "file")
  check("cleanup removes only an s<gen> dir", M.liveCleanupDir(dir) == true and fake.files[dir] == nil)
  fake.files[dir] = "directory"
  fake.files[M.liveSessionDir(1)] = "directory"
  fake.files[M.liveSessionDir(2)] = "directory"
  local swept = M.liveSweep(dir)
  check("sweep deletes other s* dirs only", swept == 2
    and fake.files[M.liveSessionDir(1)] == nil and fake.files[M.liveSessionDir(2)] == nil
    and fake.files[dir] == "directory" and fake.files[tmpRoot .. "/rec.wav"] == "file"
    and fake.files[tmpRoot .. "/foo"] == "directory")
  M.LIVE.dir = dir
  check("end session removes the active dir", M.liveEndSession() == true and M.LIVE.dir == nil and fake.files[dir] == nil)
  fake.files[M.liveSessionDir(1)] = "directory"
  fake.files[M.liveSessionDir(99)] = "directory"
  local newGen = M.liveReset(true)
  local keepDir = M.liveSessionDir(newGen)
  check("liveReset sweeps stale s* and keeps the new dir", fake.files[M.liveSessionDir(1)] == nil
    and fake.files[keepDir] == "directory")

  local heardDir = M.liveSessionDir(M.LIVE.gen)
  fake.files[heardDir] = "directory"
  M.LIVE.dir = heardDir
  M.nothingHeard("unit test")
  check("nothing-heard removes the session dir", fake.files[heardDir] == nil and M.LIVE.dir == nil)

  local wdDir = M.liveSessionDir(M.LIVE.gen + 1)
  fake.files[wdDir] = "directory"
  M.LIVE.dir = wdDir
  M.watchdogReset("unit test")
  check("watchdog reset removes the session dir", fake.files[wdDir] == nil and M.LIVE.dir == nil)

  check("finish / empty / whisper-fail / load sweep call liveEndSession or liveSweep",
    src:find("M.liveEndSession()", 1, true) ~= nil
    and src:find("M.liveSweep()", 1, true) ~= nil
    and src:find("M.liveSweep(L.dir)", 1, true) ~= nil)

  local g0 = M.LIVE.gen
  M.cfg.liveTranscribe = true
  local g1 = M.liveBegin()
  check("liveBegin bumps gen and turns on", g1 == g0 + 1 and M.LIVE.on == true)
  check("liveBegin session dir matches gen", M.LIVE.dir == M.liveSessionDir(g1))
  M.cfg.liveTranscribe = false
  local g2 = M.liveBegin()
  check("liveBegin respects liveTranscribe=false", M.LIVE.on == false and g2 == g1 + 1)
  M.cfg.liveTranscribe = true
  M.liveBegin()

  check("fallback reason helper", M.liveFallbackWhy("whisper") == "whisper" and M.liveFallbackWhy("backlog") == "backlog")
  local line = M.liveTimingLine({ rec = 12.3, live = 8.1, raw = 1.4, cleanup = 2.2, paste = 3.7 })
  check("timing log names every clock", line:find("T_rec=12.30", 1, true) and line:find("T_live_sum=8.10", 1, true)
    and line:find("T_stop_to_raw=1.40", 1, true) and line:find("T_cleanup=2.20", 1, true)
    and line:find("T_stop_to_paste=3.70", 1, true))

  -- live finish: silent whole file still wins over stitched text
  local realNH, heard = M.nothingHeard, nil
  M.nothingHeard = function(why) heard = why end
  M.LIVE.on, M.LIVE.fallback, M.LIVE.joined, M.LIVE.lastSegs = true, nil, "Thank you.", { { from = 0, to = 1, text = "Thank you." } }
  M.LIVE.gen = M.LIVE.gen + 1
  local g = M.LIVE.gen
  M.cfg.liveTranscribe = true
  M.liveAfterSlices({ rmsPk = -45, rmsTr = -50, len = 8 }, g)
  check("live: silent recording ignores live text", type(heard) == "string" and heard:find("silent", 1, true) ~= nil)
  M.nothingHeard = realNH

  -- stale callback after gen bump does not paste
  local got = nil
  local realAW = M.afterWhisper
  M.afterWhisper = function(t) got = t end
  M.LIVE.joined = "Hola equipo"
  M.liveAfterSlices({ rmsPk = -14, rmsTr = -40, len = 8 }, g - 1)
  check("live: stale gen does not continue the pipeline", got == nil)
  M.afterWhisper = realAW

  -- fallback while recording only flags; the growing wav is transcribed on stop
  local nTasks = #fake.tasks
  M._setState("rec")
  M.LIVE.on, M.LIVE.fallback, M.LIVE.finishing = true, nil, true
  M.liveFallback("whisper")
  check("fallback during rec does not start full transcribe", M.LIVE.fallback == "whisper" and M.LIVE.on == false and #fake.tasks == nTasks)
  M._setState("idle")

  M.LIVE.promptOverride = "the report"
  local a2 = M.whisperArgs("/tmp/s1/slice.wav")
  local bad = false
  for _, x in ipairs(a2) do if x == "-nt" or x == "-tr" or x == "--translate" then bad = true end end
  check("prompt override never adds -nt/-tr", not bad)
  M.LIVE.promptOverride = nil

  local bp = os.tmpname()
  local bf = io.open(bp, "wb")
  bf:write("RIFF" .. string.pack("<I4", 0) .. "WAVEfmt " .. string.pack("<I4", 16) .. string.rep("\0", 16) .. "data" .. string.pack("<I4", 0) .. string.rep("\1", 32000 * 50)); bf:close()
  M.fixWavHeader(bp)
  local plan = M.benchPlan(bp)
  check("benchPlan: 50 s has three live windows", plan.secs == 50 and #plan.windows == 3 and plan.windows[1].to == 24 and plan.windows[3].last)
  check("benchPlan: live flag follows config", plan.live == true)
  local dest = bp .. "-copy.wav"
  check("liveCopyWav snapshots and fixes the header", M.liveCopyWav(bp, dest) == true and M.wavSeconds(dest) == 50)
  os.remove(dest)

  local ui = io.open((arg[0]:match("^(.*)/") or ".") .. "/../src/ui/app.html"):read("*a")
  check("no liveTranscribe UI toggle", not ui:find("liveTranscribe", 1, true))
  local ex = io.open((arg[0]:match("^(.*)/") or ".") .. "/../src/config.example.lua"):read("*a")
  check("config.example documents liveTranscribe", ex:find("liveTranscribe", 1, true) ~= nil)

  local script = (arg[0]:match("^(.*)/") or ".") .. "/../scripts/bench-live.lua"
  local lua = arg[-1] or "lua"
  local h = io.popen(string.format("%s %q --plan %q", lua, script, bp))
  local out = h:read("*a") or ""
  local okp, _, code = h:close()
  check("bench --plan runs offline on a local wav", (okp or code == 0) and out:find("0.0-24.0", 1, true) and out:find("T_full", 1, true) and not out:find("http", 1, true))
  os.remove(bp)
  M.cfg.liveTranscribe = true
end

-- ---------- v0.2.10: dictation-pipeline stability ----------
do
  local src = io.open((arg[0]:match("^(.*)/") or ".") .. "/../src/taipea.lua"):read("*a")
  local ui = io.open((arg[0]:match("^(.*)/") or ".") .. "/../src/ui/app.html"):read("*a")

  check("helpers live on the module (no extra main-chunk locals)",
    type(M.keepAudioForRecovery) == "function" and type(M.jobStale) == "function"
    and type(M.abortIfDone) == "function" and type(M.clearVoiceFlags) == "function"
    and type(M.finish) == "function" and type(M._setCancelled) == "function")

  -- 1. reload recovery order: checkRecovery before the load-time liveSweep()
  local recAt, sweepAt
  do
    local i = 0
    while true do
      local a, b = src:find("\nM.checkRecovery()\n", i, true)
      if not a then break end
      recAt = a; i = b
    end
    i = 0
    while true do
      local a, b = src:find("\nM.liveSweep()\n", i, true)
      if not a then break end
      sweepAt = a; i = b
    end
  end
  check("load recovers interrupted audio before sweeping leftover session folders",
    recAt and sweepAt and recAt < sweepAt)

  -- keepAudioForRecovery moves the wav out of tmp/s<gen>/ so a later sweep cannot delete it
  local srcWav = os.tmpname()
  local recoverWav = "/nonexistent-home/Library/Application Support/Taipea/tmp/recover.wav"
  do local rf = io.open(srcWav, "wb"); if rf then rf:write("RIFF" .. string.rep("x", 100)); rf:close() end end
  if M.keepAudioForRecovery then
    local moved
    local realRename = os.rename
    os.rename = function(a, b)
      if a == srcWav then moved = b; os.remove(a); return true end
      return realRename(a, b)
    end
    local kept = M.keepAudioForRecovery(srcWav)
    os.rename = realRename
    check("keepAudioForRecovery moves the recording out of the session folder",
      kept == recoverWav and moved == recoverWav)
    check("session-folder copy is gone after keep", io.open(srcWav, "r") == nil)
  else
    check("keepAudioForRecovery moves the recording out of the session folder", false)
    check("session-folder copy is gone after keep", false)
  end
  os.remove(srcWav)

  -- 2. whisper-failure path keeps audio before liveEndSession deletes the folder
  do
    local i = src:find('T("trans_failed")', 1, true)
    local fail = i and src:sub(i - 400, i) or ""
    check("whisper failure keeps audio before deleting the session folder",
      fail:find("keepAudioForRecovery", 1, true) ~= nil
      and fail:find("liveEndSession", 1, true) ~= nil
      and fail:find("keepAudioForRecovery") < fail:find("liveEndSession")
      and fail:find("clearVoiceFlags", 1, true) ~= nil)
  end

  -- 3. cancel-then-start: leftover callbacks must not touch the new job
  local ready = type(M.jobStale) == "function" and type(M.abortIfDone) == "function"
    and type(M._setCancelled) == "function" and type(M.finish) == "function"
  M.LIVE.gen = 5
  check("jobStale: other gen", ready and M.jobStale(3) == true)
  check("jobStale: current gen", ready and M.jobStale(5) == false)
  check("jobStale: nil gen", ready and M.jobStale(nil) == true)

  if ready then
    M._setCancelled(false)
    M._setState("busy")
    check("abortIfDone: live job continues", M.abortIfDone(5) == false)
    check("abortIfDone: replaced job is dropped", M.abortIfDone(4) == true)
    fake.lastAlert = nil
    M.toggle()
    check("replaced-job abort does not force the new recording to idle", fake.lastAlert == M.T("still_processing"))

    M._setCancelled(true)
    M._setState("busy")
    check("abortIfDone: same-gen cancel returns to idle", M.abortIfDone(5) == true)
    fake.lastAlert = nil
    M.toggle()
    check("same-gen cancel leaves state idle", fake.lastAlert ~= M.T("still_processing"))

    M._setCancelled(true)
    M._dry, M._dryResult = true, nil
    M.LIVE.gen = 8
    M.finish("old leftover text", nil, 8)
    check("finish does not write History or paste when cancelled", M._dryResult == nil)
    M._setCancelled(false)
    M.finish("old leftover text", nil, 7)
    check("finish does not paste when the job was replaced", M._dryResult == nil)
    M.finish("hello from this job", nil, 8)
    check("finish pastes the live job", M._dryResult == "hello from this job")
    M._dry, M._dryResult = nil, nil

    -- recover bumps gen so leftover cleanup/finish cannot paste into it
    M._setCancelled(true)
    M._setState("idle")
    local g0 = M.LIVE.gen
    M.recoverable = { raw = "recovered words for the clipboard", wav = recoverWav, secs = 3 }
    M.cfg.cleanup = false
    M._dry, M._dryResult = true, nil
    M.recover()
    check("recover bumps live gen", M.LIVE.gen == g0 + 1)
    check("recover runs the current job", M._dryResult == "recovered words for the clipboard")
    local saved = M._dryResult
    M.finish("leftover from the cancelled take", nil, g0)
    check("recover ignores leftover finish from the replaced job", M._dryResult == saved)
    M._dry, M._dryResult, M.cfg.cleanup = nil, nil, true
  else
    check("abortIfDone: live job continues", false)
    check("abortIfDone: replaced job is dropped", false)
    check("replaced-job abort does not force the new recording to idle", false)
    check("abortIfDone: same-gen cancel returns to idle", false)
    check("same-gen cancel leaves state idle", false)
    check("finish does not write History or paste when cancelled", false)
    check("finish does not paste when the job was replaced", false)
    check("finish pastes the live job", false)
    check("recover bumps live gen", false)
    check("recover runs the current job", false)
    check("recover ignores leftover finish from the replaced job", false)
  end

  check("stop timers ignore a replaced job",
    src:find("if cancelled or M.jobStale(gen) then return end", 1, true) ~= nil)
  check("dictation cleanText aborts a replaced job",
    src:find("M.jobStale(gen) or cancelled", 1, true) ~= nil)

  -- 4. a killed live-slice Whisper callback must not clear a newer full-file handle
  local sliceTask, fullTask = { id = "slice" }, { id = "full" }
  local item = { gen = M.LIVE.gen - 1, task = sliceTask }
  M.wTask, M.LIVE.task, M.LIVE.cur = fullTask, fullTask, { other = true }
  M.liveOnSlice(item, 1, "", 0)
  check("killed slice does not clear a newer Whisper handle",
    M.wTask == fullTask and M.LIVE.task == fullTask and M.LIVE.cur ~= nil)
  item.task, M.wTask, M.LIVE.task, M.LIVE.cur = sliceTask, sliceTask, sliceTask, item
  M.liveOnSlice(item, 1, "", 0)
  check("slice clears only the handle it still owns",
    M.wTask == nil and M.LIVE.task == nil and M.LIVE.cur == nil)
  check("live slice stores its own task on the item", src:find("item.task = M.wTask", 1, true) ~= nil)

  -- 5. long Ollama cleanup is busy work for the 60s watchdog; 180s ceiling stays
  check("watchdog treats in-flight cleanup as busy work", src:find("or M._cleaning", 1, true) ~= nil)
  check("watchdog keeps a 180-second hard ceiling", src:find("age > 180", 1, true) ~= nil)
  M._cleaning = true
  M.watchdogReset("cleanup-flag check")
  check("watchdog reset clears the in-flight cleanup flag", M._cleaning == false)

  local held
  local realPost = hs.http.asyncPost
  fake.ollamaList = "NAME\ngemma4:e4b x\n"
  hs.http.asyncPost = function(_, _, _, cb) held = cb end
  if type(M._setCancelled) == "function" then M._setCancelled(false) end
  M._setState("busy")
  M.cfg.cleanup = true
  M._cleaning = false
  M.afterWhisper("hola equipo esto es una prueba bastante larga para la limpieza")
  check("cleanup marks the job as in-flight", M._cleaning == true)
  local gClean = M.LIVE.gen
  M.LIVE.gen = gClean + 1
  M._dry, M._dryResult = true, nil
  if held then held(200, "Hola equipo, esto es una prueba bastante larga para la limpieza.") end
  check("stale cleanup callback does not paste into the new job", M._dryResult == nil)
  check("stale cleanup callback does not clear a newer job's cleaning flag", M._cleaning == true)
  M._cleaning = false
  hs.http.asyncPost = realPost
  M._dry, M._dryResult = nil, nil
  M.LIVE.gen = gClean

  -- 6. voice start/stop flags must not leak after watchdog, whisper fail, or empty recording
  M._voiceSession, M._voicePrefix, M._voiceStopped = true, "hola", true
  if M.clearVoiceFlags then M.clearVoiceFlags() end
  check("clearVoiceFlags resets start/stop session flags",
    type(M.clearVoiceFlags) == "function"
    and M._voiceSession == false and M._voicePrefix == nil and M._voiceStopped == false)

  M._voiceSession, M._voicePrefix, M._voiceStopped = true, "prefijo", true
  M.watchdogReset("voice-flag check")
  check("watchdog reset clears voice-session flags",
    M._voiceSession == false and M._voicePrefix == nil and M._voiceStopped == false)

  M._voiceStopped, M._voicePrefix, M._voiceSession = true, "x", true
  M.nothingHeard("voice-flag check")
  check("nothing-heard still clears voice-session flags",
    M._voiceSession == false and M._voicePrefix == nil and M._voiceStopped == false)

  local whisperBin = os.tmpname()
  do local f = io.open(whisperBin, "w"); f:write("x"); f:close() end
  local oldWhisper, oldAttr = M.cfg.whisper, hs.fs.attributes
  M.cfg.whisper = whisperBin
  hs.fs.attributes = function(p, a)
    if p == "/tmp/empty-rec.wav" then return a and nil or { size = 44 } end
    return oldAttr(p, a)
  end
  M._voiceSession, M._voicePrefix, M._voiceStopped = true, "queda", true
  M.transcribeFile("/tmp/empty-rec.wav")
  check("empty recording clears voice-session flags",
    M._voiceSession == false and M._voicePrefix == nil and M._voiceStopped == false)
  hs.fs.attributes, M.cfg.whisper = oldAttr, oldWhisper
  os.remove(whisperBin)

  check("whisper-fail and empty-recording paths call clearVoiceFlags",
    src:find("M.clearVoiceFlags()", 1, true) ~= nil)

  -- 7. failed model download is retryable; Models UI shows a Retry button
  check("dlBusy: in-progress", type(M.dlBusy) == "function" and M.dlBusy("Starting…") == true and M.dlBusy("12.3%") == true and M.dlBusy("Empezando…") == true)
  check("dlBusy: failed English and Spanish are retryable",
    type(M.dlBusy) == "function" and M.dlBusy("Failed (22)") == false and M.dlBusy("Falló (22)") == false)
  check("dlBusy: idle", type(M.dlBusy) == "function" and M.dlBusy(nil) == false)

  local nTasks = #fake.tasks
  M.cfg.uiLanguage = "es"
  M.handle({ cmd = "dlWhisper", file = "ggml-tiny.bin" })
  check("download starts", #fake.tasks == nTasks + 1)
  nTasks = #fake.tasks
  M.handle({ cmd = "dlWhisper", file = "ggml-tiny.bin" })
  check("in-progress download is not restarted", #fake.tasks == nTasks)
  fake.tasks[#fake.tasks].cb(22)
  nTasks = #fake.tasks
  M.handle({ cmd = "dlWhisper", file = "ggml-tiny.bin" })
  check("failed download can be retried without reloading Hammerspoon", #fake.tasks == nTasks + 1)
  fake.tasks[#fake.tasks].cb(0)
  M.cfg.uiLanguage = "auto"

  nTasks = #fake.tasks
  M.handle({ cmd = "dlLLM", name = "gemma4:e2b" })
  fake.tasks[#fake.tasks].cb(1)
  nTasks = #fake.tasks
  M.handle({ cmd = "dlLLM", name = "gemma4:e2b" })
  check("failed Ollama pull can be retried without reloading Hammerspoon", #fake.tasks == nTasks + 1)

  check("Models UI has Retry in English and Spanish",
    ui:find("retry:'Retry'", 1, true) ~= nil and ui:find("retry:'Reintentar'", 1, true) ~= nil)
  check("failed download shows a Retry button (large control class) instead of the failure text",
    ui:find("t('retry')", 1, true) ~= nil and ui:find("/^Failed|^Falló/", 1, true) ~= nil
    and ui:find("(S.dl[m.file]?t('retry'):t('download'))", 1, true) ~= nil
    and ui:find("class=y", 1, true) ~= nil)
  check("Retry uses the same large download button class (60px)",
    ui:find("button class=y", 1, true) ~= nil and ui:find("button{height:60px", 1, true) ~= nil)
end
print(string.format("%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
