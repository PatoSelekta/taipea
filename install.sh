#!/usr/bin/env bash
# Taipea installer: hands-free, 100% local dictation for macOS.
#   curl -fsSL https://raw.githubusercontent.com/PatoSelekta/taipea/main/install.sh | bash
# Options (also work with: ... | bash -s -- --small):
#   --small            use a smaller speech model (0.57 GB instead of 1.6 GB)
#   --whisper=NAME     turbo (default) | turbo-q5 | small
#   --llm=TAG          Ollama cleanup model (default gemma4:e4b)
#   --no-cleanup       skip Ollama: raw transcription only
#   --yes              do not ask questions, use the defaults
#   --skip-brew        do not install or start anything with Homebrew (tools must already exist)
#   --no-start         do not restart Hammerspoon, start Ollama or open System Settings
# Safe to run again: steps that are already done are skipped.
set -euo pipefail

TAIPEA_VERSION="0.2.4"
REPO="${TAIPEA_REPO:-PatoSelekta/taipea}"
REF="${TAIPEA_REF:-main}"
DATA="$HOME/Library/Application Support/Taipea"
HS_DIR="$HOME/.hammerspoon"
APP_DIR="$HOME/Applications"
HF_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main"
OLLAMA_API="http://127.0.0.1:11434"
REQUIRE_LINE='taipea = require("taipea")  -- Taipea dictation (added by the Taipea installer)'

WHISPER_CHOICE="${TAIPEA_WHISPER:-}"
LLM="${TAIPEA_LLM:-gemma4:e4b}"
LLM_SET_BY_USER=0
[ -n "${TAIPEA_LLM:-}" ] && LLM_SET_BY_USER=1
FALLBACK_LLM="qwen2.5:7b"
WITH_CLEANUP=1
ASSUME_YES=0
SKIP_BREW="${TAIPEA_SKIP_BREW:-0}"
NO_START="${TAIPEA_NO_START:-0}"

# ---------- friendly output ----------
if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; C=$'\033[36m'; N=$'\033[0m'
else B=""; G=""; Y=""; R=""; C=""; N=""; fi
step() { printf '\n%s==> %s%s\n' "$B$C" "$*" "$N"; }
ok()   { printf '%s  ✓ %s%s\n' "$G" "$*" "$N"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '%s  ! %s%s\n' "$Y" "$*" "$N"; }
die()  { printf '\n%s  ✗ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }

# ask "question" default(y/n) -> returns 0 for yes. Reads the keyboard even when piped from curl.
ask() {
  local q="$1" def="${2:-y}" ans="" hint="[Y/n]"
  [ "$def" = "n" ] && hint="[y/N]"
  if [ "$ASSUME_YES" = 1 ] || ! { : </dev/tty; } 2>/dev/null; then
    [ "$def" = "y" ]; return
  fi
  printf '%s  ? %s %s %s' "$B" "$q" "$hint" "$N"
  read -r ans </dev/tty || ans=""
  ans="$(printf '%s' "${ans:-$def}" | tr '[:upper:]' '[:lower:]')"
  [ "${ans:0:1}" = "y" ] || [ "${ans:0:1}" = "s" ]   # yes / sí
}

usage() {
  cat <<'USAGE'
Taipea installer
  bash install.sh [options]
  curl -fsSL https://raw.githubusercontent.com/PatoSelekta/taipea/main/install.sh | bash -s -- [options]
Options:
  --small            smaller speech model (0.57 GB instead of 1.6 GB)
  --whisper=NAME     turbo (default) | turbo-q5 | small
  --llm=TAG          Ollama cleanup model (default gemma4:e4b)
  --no-cleanup       skip Ollama: raw transcription only
  --yes              do not ask questions, use the defaults
  --skip-brew        do not install or start anything with Homebrew (tools must already exist)
  --no-start         do not restart Hammerspoon, start Ollama or open System Settings
USAGE
  exit 0
}

for arg in "$@"; do
  case "$arg" in
    --small) WHISPER_CHOICE="turbo-q5" ;;
    --whisper=*) WHISPER_CHOICE="${arg#*=}" ;;
    --llm=*) LLM="${arg#*=}"; LLM_SET_BY_USER=1 ;;
    --no-cleanup) WITH_CLEANUP=0 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --skip-brew) SKIP_BREW=1 ;;
    --no-start) NO_START=1 ;;
    --help|-h) usage ;;
    *) die "Unknown option: $arg (try --help)" ;;
  esac
done

printf '\n%sTaipea %s%s · it types for you · selektdev.com\n' "$B" "$TAIPEA_VERSION" "$N"
info "Everything runs on this Mac. No audio or text ever leaves it."

# ---------- 1. this Mac ----------
step "Checking this Mac"
[ "$(uname -s)" = "Darwin" ] || die "Taipea only runs on macOS."
macos="$(sw_vers -productVersion)"
[ "${macos%%.*}" -ge 13 ] || die "Taipea needs macOS 13 (Ventura) or newer. This Mac has $macos."
ok "macOS $macos"
arch="$(uname -m)"
if [ "$arch" = "arm64" ]; then ok "Apple Silicon"; else warn "Intel Mac: it works, but transcription is much slower. Consider --small."; fi
ram_gb=$(( $(sysctl -n hw.memsize) / 1073741824 ))
if [ "$ram_gb" -lt 8 ]; then warn "${ram_gb} GB of memory: use --small --no-cleanup for the best experience."
elif [ "$ram_gb" -lt 16 ]; then ok "${ram_gb} GB of memory (16 GB is recommended for Gemma 4 E4B)"
else ok "${ram_gb} GB of memory"; fi

# ---------- choose models ----------
if [ -z "$WHISPER_CHOICE" ]; then
  WHISPER_CHOICE="turbo"
  if [ "$ram_gb" -lt 16 ] && ask "Use the smaller speech model (0.57 GB, a bit less accurate)?" n; then WHISPER_CHOICE="turbo-q5"; fi
fi
case "$WHISPER_CHOICE" in
  turbo)    WHISPER_FILE="ggml-large-v3-turbo.bin";      WHISPER_GB=1.6 ;;
  turbo-q5) WHISPER_FILE="ggml-large-v3-turbo-q5_0.bin"; WHISPER_GB=0.6 ;;
  small)    WHISPER_FILE="ggml-small.bin";               WHISPER_GB=0.5 ;;
  *) die "Unknown speech model '$WHISPER_CHOICE'. Use turbo, turbo-q5 or small." ;;
esac
if [ "$WITH_CLEANUP" = 1 ] && [ "$LLM_SET_BY_USER" = 0 ] && [ "$ram_gb" -lt 16 ]; then
  if ask "Your Mac has ${ram_gb} GB. Use the lighter cleanup model $FALLBACK_LLM instead of $LLM?" y; then LLM="$FALLBACK_LLM"; fi
fi
need_gb=$(awk "BEGIN{print int($WHISPER_GB + ($WITH_CLEANUP ? 10 : 0) + 2 + 0.99)}")
free_gb=$(( $(df -k "$HOME" | awk 'NR==2{print $4}') / 1048576 ))
if [ "$free_gb" -lt "$need_gb" ]; then
  warn "About $need_gb GB is needed, but only $free_gb GB is free."
  ask "Continue anyway?" n || die "Free some disk space and run the installer again."
else ok "$free_gb GB free on disk (about $need_gb GB needed)"; fi

# ---------- 2. Homebrew ----------
if [ "$SKIP_BREW" = 1 ]; then
  step "Checking tools (--skip-brew: nothing is installed)"
  BIN=""
  for d in /opt/homebrew/bin /usr/local/bin; do [ -x "$d/whisper-cli" ] && BIN="$d" && break; done
  [ -n "$BIN" ] || die "whisper-cli not found in /opt/homebrew/bin or /usr/local/bin."
  [ -x "$BIN/rec" ] || die "rec not found in $BIN (install sox)."
  [ -d /Applications/Hammerspoon.app ] || [ -d "$HOME/Applications/Hammerspoon.app" ] || warn "Hammerspoon.app not found."
  ok "Tools found in $BIN"
  OLLAMA_KIND=""
  if [ "$WITH_CLEANUP" = 1 ]; then
    if [ -x "$BIN/ollama" ]; then OLLAMA_KIND="brew"; elif [ -d /Applications/Ollama.app ]; then OLLAMA_KIND="app"
    else warn "Ollama not found: cleanup will be off until you install it."; WITH_CLEANUP=0; fi
  fi
else
step "Homebrew"
BREW=""
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && BREW="$b" && break; done
[ -z "$BREW" ] && command -v brew >/dev/null 2>&1 && BREW="$(command -v brew)"
if [ -z "$BREW" ]; then
  warn "Homebrew is not installed. Taipea uses it to install its free tools."
  ask "Install Homebrew now (from brew.sh, asks for your Mac password)?" y || die "Install Homebrew from https://brew.sh and run this again."
  brew_installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if { : </dev/tty; } 2>/dev/null; then /bin/bash -c "$brew_installer" </dev/tty
  else NONINTERACTIVE=1 /bin/bash -c "$brew_installer"; fi
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && BREW="$b" && break; done
  [ -n "$BREW" ] || die "Homebrew did not install correctly."
fi
eval "$("$BREW" shellenv)"
ok "Homebrew at $BREW"

# ---------- 3. tools ----------
step "Installing tools (skips anything already installed)"
brew_formula() { # formula label
  if "$BREW" list --formula "$1" >/dev/null 2>&1; then ok "$2 already installed"
  else info "Installing $2…"; "$BREW" install "$1"; ok "$2 installed"; fi
}
if [ -d /Applications/Hammerspoon.app ] || [ -d "$HOME/Applications/Hammerspoon.app" ] || "$BREW" list --cask hammerspoon >/dev/null 2>&1; then ok "Hammerspoon already installed"
else info "Installing Hammerspoon…"; "$BREW" install --cask hammerspoon; ok "Hammerspoon installed"; fi
brew_formula whisper-cpp "whisper.cpp (speech to text)"
brew_formula sox "SoX (microphone recording)"
OLLAMA_KIND=""
if [ "$WITH_CLEANUP" = 1 ]; then
  if "$BREW" list --formula ollama >/dev/null 2>&1; then OLLAMA_KIND="brew"; ok "Ollama already installed"
  elif [ -d /Applications/Ollama.app ]; then OLLAMA_KIND="app"; ok "Ollama app already installed"
  else info "Installing Ollama (grammar cleanup)…"; "$BREW" install ollama; OLLAMA_KIND="brew"; ok "Ollama installed"; fi
else
  info "Skipping Ollama (--no-cleanup). Taipea will paste raw transcriptions."
fi
BIN="$("$BREW" --prefix)/bin"
[ -x "$BIN/whisper-cli" ] || die "whisper-cli not found in $BIN. Try: brew reinstall whisper-cpp"
[ -x "$BIN/rec" ] || die "rec not found in $BIN. Try: brew reinstall sox"
fi

# ---------- 4. Taipea files ----------
step "Copying Taipea files"
SRC=""
here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$here" ] && [ -f "$here/src/taipea.lua" ]; then SRC="$here"
else
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  info "Downloading Taipea from github.com/$REPO…"
  curl -fsSL "https://github.com/$REPO/archive/refs/heads/$REF.tar.gz" | tar xz -C "$tmp" --strip-components=1 \
    || die "Could not download github.com/$REPO (branch $REF)."
  SRC="$tmp"
fi
mkdir -p "$DATA/models" "$DATA/logs" "$DATA/tmp" "$DATA/ui" "$HS_DIR"
install -m 644 "$SRC/src/taipea.lua" "$HS_DIR/taipea.lua"
install -m 644 "$SRC/src/ui/app.html" "$DATA/ui/app.html"
install -m 644 "$SRC/src/config.example.lua" "$DATA/config.example.lua"
ok "Program: ~/.hammerspoon/taipea.lua"
ok "Data folder: ~/Library/Application Support/Taipea"
if [ -f "$DATA/config.lua" ]; then
  ok "Kept your existing config.lua"
else
  cleanup_flag=true; [ "$WITH_CLEANUP" = 1 ] || cleanup_flag=false
  cat >"$DATA/config.lua" <<CFG
-- Taipea settings. See config.example.lua (same folder) for every option.
return {
  modelName   = "$WHISPER_FILE",
  ollamaModel = "$LLM",
  cleanup     = $cleanup_flag,
}
CFG
  ok "Created config.lua"
fi

# ---------- 5. speech model ----------
step "Speech model ($WHISPER_FILE, about $WHISPER_GB GB)"
dest="$DATA/models/$WHISPER_FILE"
if [ -f "$dest" ] && [ "$(stat -Lf %z "$dest")" -gt 100000000 ]; then ok "Already downloaded"
else
  info "Downloading from Hugging Face (ggerganov/whisper.cpp). This can take a few minutes…"
  curl -fL --retry 3 -C - --progress-bar -o "$dest.part" "$HF_URL/$WHISPER_FILE" || die "Download failed. Run the installer again to resume."
  mv "$dest.part" "$dest"
  ok "Downloaded"
fi

# ---------- 6. cleanup model ----------
if [ "$WITH_CLEANUP" = 1 ]; then
  step "Cleanup model ($LLM)"
  if [ "$OLLAMA_KIND" = "brew" ]; then OLLAMA="$BIN/ollama"; else OLLAMA="/Applications/Ollama.app/Contents/Resources/ollama"; fi
  if curl -fs "$OLLAMA_API/api/version" >/dev/null 2>&1; then
    ok "Ollama is already running"
  elif [ "$NO_START" = 1 ] || { [ "$SKIP_BREW" = 1 ] && [ "$OLLAMA_KIND" = "brew" ]; }; then
    warn "Ollama is not running and was not started (--no-start / --skip-brew)."
  elif [ "$OLLAMA_KIND" = "brew" ]; then
    "$BREW" services start ollama >/dev/null 2>&1 || "$BREW" services restart ollama >/dev/null 2>&1 || true
    ok "Ollama runs in the background and starts at login (brew services)"
  else
    open -g -a Ollama || true
    ok "Started the Ollama app"
  fi
  up=0
  for _ in $(seq 1 30); do curl -fs "$OLLAMA_API/api/version" >/dev/null 2>&1 && up=1 && break; sleep 1; done
  if [ "$up" != 1 ]; then
    warn "Ollama did not answer. Dictation still works (raw text). Later run: ollama pull $LLM"
  elif "$OLLAMA" list 2>/dev/null | awk 'NR>1{print $1}' | grep -qx "$LLM"; then
    ok "$LLM already downloaded"
  else
    info "Downloading $LLM. This is the biggest download, please wait…"
    if "$OLLAMA" pull "$LLM"; then ok "$LLM ready"
    elif [ "$LLM" != "$FALLBACK_LLM" ]; then
      warn "Could not download $LLM (your Ollama may need an update: brew upgrade ollama). Trying $FALLBACK_LLM…"
      if "$OLLAMA" pull "$FALLBACK_LLM"; then ok "$FALLBACK_LLM ready (Taipea uses it automatically as the fallback)"
      else warn "No cleanup model downloaded. Dictation still works with raw text."; fi
    else warn "No cleanup model downloaded. Dictation still works with raw text."; fi
  fi
fi

# ---------- 7. Hammerspoon config ----------
step "Connecting Taipea to Hammerspoon"
init="$HS_DIR/init.lua"
if [ -f "$init" ] && grep -q 'require("taipea")' "$init"; then ok "init.lua already loads Taipea"
else
  if [ -f "$init" ]; then
    backup="$init.taipea-backup-$(date +%Y%m%d-%H%M%S)"
    cp "$init" "$backup"; ok "Backed up your init.lua to $(basename "$backup")"
    printf '\n%s\n' "$REQUIRE_LINE" >>"$init"
  else
    printf '%s\n' "$REQUIRE_LINE" >"$init"
  fi
  ok "Added one line to ~/.hammerspoon/init.lua (your other settings are untouched)"
fi

# ---------- 8. Taipea.app ----------
step "Creating Taipea.app"
TAIPEA_VERSION="$TAIPEA_VERSION" bash "$SRC/scripts/build-app.sh" "$APP_DIR/Taipea.app" "$SRC/assets/Taipea.icns" >/dev/null
ok "Taipea.app is in ~/Applications (it opens the Taipea window; you can add it to the Dock)"

# ---------- 9. start ----------
step "Starting Taipea"
if [ "$NO_START" = 1 ]; then
  info "Not starting Hammerspoon (--no-start). Choose Hammerspoon › Reload Config when ready."
else
  if pgrep -xq Hammerspoon; then
    info "Restarting Hammerspoon to load Taipea…"
    osascript -e 'quit app "Hammerspoon"' >/dev/null 2>&1 || true
    sleep 2
  fi
  open -g -a Hammerspoon && ok "Hammerspoon is running (look for 🎙 in the menu bar)"
fi

# ---------- 10. permissions ----------
step "One-time permissions / Permisos (una sola vez)"
info "macOS asks for these; Taipea cannot grant them itself."
info "macOS los pide; Taipea no puede darlos por sí solo."
info ""
info "1. Accessibility → turn ON Hammerspoon. Needed to paste the text."
info "   System Settings › Privacy & Security › Accessibility"
info "   Accesibilidad → activa Hammerspoon. Se necesita para pegar el texto."
info "   Ajustes del Sistema › Privacidad y seguridad › Accesibilidad"
info ""
info "2. Microphone → macOS asks the first time you dictate: click Allow."
info "   If the recording is always empty, check:"
info "   System Settings › Privacy & Security › Microphone › Hammerspoon"
info "   Micrófono → macOS pregunta la primera vez que dictas: haz clic en Permitir."
info "   Si la grabación siempre sale vacía, revisa:"
info "   Ajustes del Sistema › Privacidad y seguridad › Micrófono › Hammerspoon"
info ""
info "If a switch was already on but Taipea does not paste, turn it off and on again."
info "Si el interruptor ya estaba activado pero Taipea no pega, apágalo y vuelve a encenderlo."
if [ "$NO_START" != 1 ]; then
  if ask "Open the Accessibility settings now? / ¿Abrir los ajustes de Accesibilidad ahora?" y; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
  fi
  if ask "Open the Microphone settings too? / ¿Abrir también los ajustes de Micrófono?" n; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone" || true
  fi
fi

printf '\n%s%s  Taipea is installed!%s\n' "$B" "$G" "$N"
info "Ctrl + Option + Space   start / stop dictation (text is pasted where your cursor is)"
info "Ctrl + Option + C       cleanup on / off (raw text)"
info "Ctrl + Option + H       open the Taipea window (history, settings, models)"
info "Problems? Read the Troubleshooting section: https://github.com/$REPO#troubleshooting"
