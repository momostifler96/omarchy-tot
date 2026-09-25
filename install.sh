#!/bin/bash
# Links the tot-notes / tot-sync scripts into ~/.local/bin.
#   ./install.sh             scripts only
#   ./install.sh --bindings  also append the Hyprland shortcuts to ~/.config/hypr/bindings.lua

set -euo pipefail

DIR=$(cd "$(dirname "$0")" && pwd)
BIN="$HOME/.local/bin"
BINDINGS="$HOME/.config/hypr/bindings.lua"

mkdir -p "$BIN"
chmod +x "$DIR"/bin/*
for script in tot-notes tot-sync; do
  ln -sfn "$DIR/bin/$script" "$BIN/$script"
  echo "Linked $BIN/$script"
done

if [[ ${1:-} == --bindings ]]; then
  if grep -q "tot-notes" "$BINDINGS" 2>/dev/null; then
    echo "Shortcuts already present in $BINDINGS"
  else
    cp "$BINDINGS" "$BINDINGS.bak.$(date +%s)" 2>/dev/null || true
    { echo; cat "$DIR/hypr/bindings.lua"; } >>"$BINDINGS"
    echo "Shortcuts added to $BINDINGS"
    hyprctl reload >/dev/null 2>&1 && hyprctl configerrors
  fi
fi

command -v rclone >/dev/null || [[ -x $HOME/.local/share/mise/shims/rclone ]] ||
  echo "Note: rclone is not installed (needed for cloud sync): mise use -g rclone@latest"
