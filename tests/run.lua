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
hs.keycodes = { map = { space = 49, c = 8, h = 4, v = 9 } }
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
check("bound uses defaults", M.bound.toggle == D.toggleKey and M.bound.mode == D.modeKey and M.bound.history == D.historyKey and M.bound.pasteLast == D.pasteLastKey)
check("default paste-last key", table.concat(D.pasteLastKey.mods, "+") .. "+" .. D.pasteLastKey.key == "ctrl+alt+v")
check("v0.2 defaults", D.voiceControl == false and D.floatButton == true and D.textSize == "normal" and D.contrast == "auto"
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

print(string.format("%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
