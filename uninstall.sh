#!/usr/bin/env bash
set -euo pipefail

HOME_DIR="${HOME:?HOME must be set}"
BIN_DIR="${WT_TMUX_BIN_DIR:-$HOME_DIR/.local/bin}"
CONFIG_DIR="${WT_TMUX_CONFIG_DIR:-$HOME_DIR/.config/tmux}"
TMUX_CONF="${WT_TMUX_CONF:-$HOME_DIR/.tmux.conf}"
BIN_PATH="$BIN_DIR/wt-tmux"
CONFIG_PATH="$CONFIG_DIR/worktree-menu.conf"
BEGIN_MARKER="# BEGIN worktree-tmux-menu"
END_MARKER="# END worktree-tmux-menu"

if [[ -e "$TMUX_CONF" ]]; then
  temporary="$(mktemp "${TMUX_CONF}.worktree-menu.XXXXXX")"
  trap 'rm -f "$temporary" "${temporary}.new"' EXIT
  awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
    $0 == begin { skipping = 1; next }
    $0 == end   { skipping = 0; next }
    !skipping   { print }
  ' "$TMUX_CONF" >"$temporary"
  cp -p "$TMUX_CONF" "${temporary}.new"
  cat "$temporary" >"${temporary}.new"
  mv "${temporary}.new" "$TMUX_CONF"
  rm -f "$temporary"
  trap - EXIT
fi

rm -f "$BIN_PATH" "$CONFIG_PATH"

if [[ "${WT_TMUX_NO_RELOAD:-0}" != "1" ]] && tmux list-sessions >/dev/null 2>&1; then
  tmux unbind-key m 2>/dev/null || true
  tmux source-file "$TMUX_CONF" 2>/dev/null || true
fi

printf 'Removed worktree-tmux-menu. Worktrunk repositories and configuration were not changed.\n'
