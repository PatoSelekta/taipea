#!/usr/bin/env bash
# Taipea uninstaller. Removes Taipea itself; keeps the shared tools.
#   bash uninstall.sh            asks before deleting your history and models
#   bash uninstall.sh --purge    also deletes history, settings and models, no questions
# Homebrew, Hammerspoon, whisper.cpp, SoX and Ollama are NOT removed (other apps may use them).
set -euo pipefail

DATA="$HOME/Library/Application Support/Taipea"
HS_DIR="$HOME/.hammerspoon"
APP="$HOME/Applications/Taipea.app"
PURGE=0
for arg in "$@"; do
  case "$arg" in
    --purge) PURGE=1 ;;
    --help|-h) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

if [ -t 1 ]; then G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[1m'; N=$'\033[0m'; else G=""; Y=""; B=""; N=""; fi
ok()   { printf '%s  ✓ %s%s\n' "$G" "$*" "$N"; }
info() { printf '    %s\n' "$*"; }
ask() {
  local ans=""
  if ! { : </dev/tty; } 2>/dev/null; then return 1; fi
  printf '%s  ? %s [y/N] %s' "$B" "$1" "$N"; read -r ans </dev/tty || ans=""
  case "$ans" in y*|Y*|s*|S*) return 0 ;; *) return 1 ;; esac
}

printf '\n%sUninstalling Taipea%s\n\n' "$B" "$N"

if [ -f "$HS_DIR/taipea.lua" ]; then rm -f "$HS_DIR/taipea.lua"; ok "Removed ~/.hammerspoon/taipea.lua"; else ok "taipea.lua already gone"; fi

init="$HS_DIR/init.lua"
if [ -f "$init" ] && grep -q 'require("taipea")' "$init"; then
  backup="$init.taipea-uninstall-backup-$(date +%Y%m%d-%H%M%S)"
  cp "$init" "$backup"
  grep -v 'require("taipea")' "$backup" >"$init" || true
  ok "Removed the Taipea line from init.lua (backup: $(basename "$backup"))"
else ok "init.lua does not load Taipea"; fi

if [ -d "$APP" ]; then rm -rf "$APP"; ok "Removed ~/Applications/Taipea.app"; else ok "Taipea.app already gone"; fi

if [ -d "$DATA" ]; then
  size="$(du -sh "$DATA" 2>/dev/null | awk '{print $1}')"
  if [ "$PURGE" = 1 ] || ask "Delete your dictation history, settings and speech models ($size)?"; then
    rm -rf "$DATA"; ok "Deleted ~/Library/Application Support/Taipea"
  else
    printf '%s  ! Kept %s (delete it yourself any time)%s\n' "$Y" "$DATA" "$N"
  fi
fi

# Taipea saved window positions in Hammerspoon's settings; they are harmless and tiny.
if pgrep -xq Hammerspoon; then
  osascript -e 'quit app "Hammerspoon"' >/dev/null 2>&1 || true
  sleep 2; open -g -a Hammerspoon || true
  ok "Restarted Hammerspoon"
fi

printf '\n%sTaipea is removed.%s\n' "$B" "$N"
info "The shared tools are still installed. To remove them too:"
info "  ollama rm gemma4:e4b qwen2.5:7b       # free the cleanup models"
info "  brew services stop ollama && brew uninstall ollama"
info "  brew uninstall whisper-cpp sox"
info "  brew uninstall --cask hammerspoon     # only if nothing else uses it"
