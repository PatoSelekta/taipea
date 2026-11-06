-- Offline live-vs-full-file benchmark for Taipea Approach A.
-- Local WAV files only. No network. Does not talk to a running Taipea or a Mac session.
--
--   lua scripts/bench-live.lua --plan file1.wav [file2.wav ...]
--   lua scripts/bench-live.lua --run  file1.wav [file2.wav ...]
--
-- --plan prints the same 24 s / 4 s overlap windows Taipea uses (no whisper-cli).
-- --run  times whisper-cli on each slice vs the same file as one shot.
--        Needs local binaries; set TAIPEA_WHISPER and TAIPEA_MODEL if they are not
--        in the default Homebrew / Taipea data paths.
-- English-only fast engines are a later, separate benchmark — not this script.

local SLICE, OVERLAP = 24, 4

local B = {}

function B.wavSeconds(path)
  local f = io.open(path or "", "rb"); if not f then return 0 end
  local size = f:seek("end"); f:close()
  return math.max(0, (size - 44) / 32000)
end

function B.windows(len, slice, overlap)
  slice = slice or SLICE; overlap = overlap or OVERLAP
  local step, w = slice - overlap, {}
  len = len or 0
  if len <= 0 then return w end
  if len <= slice then w[1] = { from = 0, to = len, last = true }; return w end
  local from = 0
  while from + slice < len - 0.001 do
    w[#w + 1] = { from = from, to = from + slice, last = false }
    from = from + step
  end
  w[#w + 1] = { from = from, to = len, last = true }
  return w
end

function B.plan(path)
  local secs = B.wavSeconds(path)
  return { path = path, secs = secs, windows = B.windows(secs), slice = SLICE, overlap = OVERLAP }
end

function B.formatPlan(p)
  local rows = {}
  for i, w in ipairs(p.windows) do
    rows[#rows + 1] = string.format("  [%d] %.1f-%.1f%s", i, w.from, w.to, w.last and " last" or "")
  end
  return string.format("%s\n  secs=%.2f slices=%d slice=%ds overlap=%ds\n%s\n  compare: T_live_sum (sum of slice whisper) vs T_full (one whisper-cli on the same file)\n",
    p.path, p.secs, #p.windows, p.slice, p.overlap, table.concat(rows, "\n"))
end

local function shq(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

local function have(cmd) return os.execute("command -v " .. shq(cmd) .. " >/dev/null 2>&1") == true
    or os.execute("command -v " .. shq(cmd) .. " >/dev/null 2>&1") == 0 end

local function timed(cmd)
  local t0 = os.clock()
  local ok = os.execute(cmd)
  return (os.clock() - t0), (ok == true or ok == 0)
end

function B.runFile(path, whisper, model, sox)
  local p = B.plan(path)
  local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/taipea-bench-" .. tostring(os.time()) .. "-" .. tostring(math.random(10000, 99999))
  os.execute("mkdir -p " .. shq(tmp))
  local liveSum, okAll, texts = 0, true, {}
  for i, w in ipairs(p.windows) do
    local slice = string.format("%s/slice-%d.wav", tmp, i)
    local dur = math.max(0.05, w.to - w.from)
    local tSox = sox and string.format("%s %s %s trim %.3f %.3f", shq(sox), shq(path), shq(slice), w.from, dur)
      or string.format("cp %s %s", shq(path), shq(slice))
    os.execute(tSox .. " >/dev/null 2>&1")
    local out = string.format("%s/slice-%d.txt", tmp, i)
    local cmd = string.format("%s -m %s -l auto -np -f %s > %s 2>/dev/null", shq(whisper), shq(model), shq(slice), shq(out))
    local dt, ok = timed(cmd)
    liveSum = liveSum + dt
    okAll = okAll and ok
    local f = io.open(out, "r"); texts[#texts + 1] = f and f:read("*a") or ""; if f then f:close() end
  end
  local fullOut = tmp .. "/full.txt"
  local tFull, okFull = timed(string.format("%s -m %s -l auto -np -f %s > %s 2>/dev/null",
    shq(whisper), shq(model), shq(path), shq(fullOut)))
  os.execute("rm -rf " .. shq(tmp))
  return {
    plan = p, T_live_sum = liveSum, T_full = tFull, ok = okAll and okFull,
    liveText = table.concat(texts, "\n---\n"),
  }
end

local isCLI = (arg and arg[0] or ""):match("bench%-live")
if not isCLI then return B end

local mode, files = "plan", {}
for i = 1, #arg do
  if arg[i] == "--plan" then mode = "plan"
  elseif arg[i] == "--run" then mode = "run"
  elseif arg[i] == "--help" or arg[i] == "-h" then
    io.write("Usage: lua scripts/bench-live.lua --plan|--run file.wav [file2.wav ...]\nLocal files only. No network.\n")
    os.exit(0)
  elseif arg[i]:sub(1, 1) == "-" then
    io.stderr:write("unknown flag: " .. arg[i] .. "\n"); os.exit(2)
  else
    files[#files + 1] = arg[i]
  end
end
if #files == 0 then
  io.stderr:write("bench-live: pass one or more local WAV paths\n")
  os.exit(2)
end
for _, path in ipairs(files) do
  if path:match("^https?://") or path:match("^ftp://") then
    io.stderr:write("bench-live: local files only, refused " .. path .. "\n")
    os.exit(2)
  end
  local f = io.open(path, "rb")
  if not f then io.stderr:write("bench-live: not found: " .. path .. "\n"); os.exit(2) end
  f:close()
  io.write(B.formatPlan(B.plan(path)))
  if mode == "run" then
    local home = os.getenv("HOME") or ""
    local whisper = os.getenv("TAIPEA_WHISPER") or "/opt/homebrew/bin/whisper-cli"
    local model = os.getenv("TAIPEA_MODEL") or (home .. "/Library/Application Support/Taipea/models/ggml-large-v3-turbo.bin")
    local sox = os.getenv("TAIPEA_SOX") or "/opt/homebrew/bin/sox"
    if not have(whisper) then io.stderr:write("bench-live: whisper-cli not found (" .. whisper .. ")\n"); os.exit(2) end
    local mf = io.open(model, "rb"); if not mf then io.stderr:write("bench-live: model not found (" .. model .. ")\n"); os.exit(2) end; mf:close()
    if not have(sox) then sox = nil end
    local r = B.runFile(path, whisper, model, sox)
    io.write(string.format("  T_live_sum=%.2f T_full=%.2f ok=%s\n", r.T_live_sum, r.T_full, tostring(r.ok)))
  end
end
os.exit(0)
