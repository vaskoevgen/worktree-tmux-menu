#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="${HOME:?HOME must be set}"
BIN_DIR="${WT_TMUX_BIN_DIR:-$HOME_DIR/.local/bin}"
CONFIG_DIR="${WT_TMUX_CONFIG_DIR:-$HOME_DIR/.config/tmux}"
TMUX_CONF="${WT_TMUX_CONF:-$HOME_DIR/.tmux.conf}"
BIN_PATH="$BIN_DIR/wt-tmux"
CONFIG_PATH="$CONFIG_DIR/worktree-menu.conf"
BEGIN_MARKER="# BEGIN worktree-tmux-menu"
END_MARKER="# END worktree-tmux-menu"

for command_name in git jq tmux wt; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 1
  fi
done

mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$(dirname "$TMUX_CONF")"
install -m 0755 "$ROOT_DIR/bin/wt-tmux" "$BIN_PATH"

escaped_bin="$(printf '%s' "$BIN_PATH" | sed 's/[\\&|]/\\&/g')"
sed "s|@WT_TMUX_BIN@|$escaped_bin|g" \
  "$ROOT_DIR/tmux/worktree-menu.conf.in" >"$CONFIG_PATH"
chmod 0644 "$CONFIG_PATH"

if [[ ! -e "$TMUX_CONF" ]]; then
  touch "$TMUX_CONF"
fi
if [[ ! -e "$TMUX_CONF.worktree-tmux-menu.bak" ]]; then
  cp "$TMUX_CONF" "$TMUX_CONF.worktree-tmux-menu.bak"
fi

temporary="$(mktemp "${TMUX_CONF}.worktree-menu.XXXXXX")"
trap 'rm -f "$temporary" "${temporary}.new"' EXIT
awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
  $0 == begin { skipping = 1; next }
  $0 == end   { skipping = 0; next }
  !skipping   { print }
' "$TMUX_CONF" >"$temporary"

cp -p "$TMUX_CONF" "${temporary}.new"
{
  cat "$temporary"
  printf '%s\n' "$BEGIN_MARKER"
  printf 'source-file "%s"\n' "$CONFIG_PATH"
  printf '%s\n' "$END_MARKER"
} >"${temporary}.new"
mv "${temporary}.new" "$TMUX_CONF"

if [[ "${WT_TMUX_NO_RELOAD:-0}" != "1" ]] && tmux list-sessions >/dev/null 2>&1; then
  if tmux source-file "$TMUX_CONF"; then
    printf 'Reloaded %s\n' "$TMUX_CONF"
  else
    printf 'Installed, but tmux could not reload %s; press prefix+r or restart tmux.\n' "$TMUX_CONF" >&2
  fi
fi

printf '\nInstalled worktree-tmux-menu:\n'
printf '  helper: %s\n' "$BIN_PATH"
printf '  menu:   %s\n' "$CONFIG_PATH"
printf '  tmux:   %s\n' "$TMUX_CONF"
printf '\nOpen the menu with your tmux prefix followed by m.\n'
