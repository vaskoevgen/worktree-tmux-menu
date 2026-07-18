#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/worktree-tmux-menu-test.XXXXXX")"
TEST_HOME="$TEMP_ROOT/home"
TEST_REPO="$TEMP_ROOT/repo"
SOCKET="worktree-tmux-menu-test-$$"

cleanup() {
  tmux -L "$SOCKET" kill-server 2>/dev/null || true
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

file_mode() {
  local mode
  mode="$(stat -f '%Lp' "$1" 2>/dev/null || true)"
  if [[ "$mode" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$mode"
  else
    stat -c '%a' "$1"
  fi
}

bash -n "$ROOT_DIR/bin/wt-tmux"
bash -n "$ROOT_DIR/install.sh"
bash -n "$ROOT_DIR/uninstall.sh"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$ROOT_DIR/bin/wt-tmux" "$ROOT_DIR/install.sh" "$ROOT_DIR/uninstall.sh" "$0"
fi
machine_path_pattern='/''Users/|/''home/[^/]+/|~/''source/[^/]+/'
if git -C "$ROOT_DIR" grep -n -E "$machine_path_pattern" -- .; then
  printf 'Found a machine-specific home path in tracked content.\n' >&2
  exit 1
fi

mkdir -p "$TEST_HOME"
printf 'set -g mouse on\n' >"$TEST_HOME/.tmux.conf"
chmod 0644 "$TEST_HOME/.tmux.conf"

HOME="$TEST_HOME" WT_TMUX_NO_RELOAD=1 "$ROOT_DIR/install.sh" >/dev/null
HOME="$TEST_HOME" WT_TMUX_NO_RELOAD=1 "$ROOT_DIR/install.sh" >/dev/null

test -x "$TEST_HOME/.local/bin/wt-tmux"
test -f "$TEST_HOME/.config/tmux/worktree-menu.conf"
test "$(grep -c '^# BEGIN worktree-tmux-menu$' "$TEST_HOME/.tmux.conf")" -eq 1
test "$(file_mode "$TEST_HOME/.tmux.conf")" = 644
if grep -q '@WT_TMUX_BIN@' "$TEST_HOME/.config/tmux/worktree-menu.conf"; then
  printf 'Template placeholder was not replaced.\n' >&2
  exit 1
fi

tmux -L "$SOCKET" -f /dev/null new-session -d -s config-test -c "$TEST_HOME"
tmux -L "$SOCKET" source-file "$TEST_HOME/.tmux.conf"
tmux -L "$SOCKET" list-keys -T prefix m | grep -q 'wt: open/switch worktree'
tmux -L "$SOCKET" list-keys -T prefix m | grep -q 'Delete session.*kill-session'

git init -q -b main "$TEST_REPO"
git -C "$TEST_REPO" config user.name test
git -C "$TEST_REPO" config user.email test@example.invalid
git -C "$TEST_REPO" commit -q --allow-empty -m initial

WT_TMUX_SOCKET="$SOCKET" \
WT_TMUX_NO_ATTACH=1 \
WT_TMUX_AGENT=: \
WT_TMUX_EDITOR=: \
  "$TEST_HOME/.local/bin/wt-tmux" session "$TEST_REPO"
WT_TMUX_SOCKET="$SOCKET" \
WT_TMUX_NO_ATTACH=1 \
WT_TMUX_AGENT=: \
WT_TMUX_EDITOR=: \
  "$TEST_HOME/.local/bin/wt-tmux" session "$TEST_REPO"

SESSION="$(tmux -L "$SOCKET" list-sessions -F '#{session_name}' | grep '^wt-')"
test "$(tmux -L "$SOCKET" list-panes -t "=$SESSION" -F '#{pane_id}' | wc -l | tr -d ' ')" -eq 3

HOME="$TEST_HOME" WT_TMUX_NO_RELOAD=1 "$ROOT_DIR/uninstall.sh" >/dev/null
test ! -e "$TEST_HOME/.local/bin/wt-tmux"
test ! -e "$TEST_HOME/.config/tmux/worktree-menu.conf"
test "$(grep -c '^# BEGIN worktree-tmux-menu$' "$TEST_HOME/.tmux.conf" || true)" -eq 0
grep -q '^set -g mouse on$' "$TEST_HOME/.tmux.conf"

printf 'All tests passed.\n'
