#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/worktree-tmux-menu-test.XXXXXX")"
TEST_HOME="$TEMP_ROOT/home"
TEST_REPO="$TEMP_ROOT/repo"
TEST_OTHER_REPO="$TEMP_ROOT/other repo"
TEST_BARE_REPO="$TEMP_ROOT/bare-repo.git"
TEST_WORKTREE="$TEMP_ROOT/repo-feature"
TEST_CONFIGURED_DIR="$TEMP_ROOT/configured-repos"
TEST_CONFIGURED_REPO="$TEST_CONFIGURED_DIR/configured"
TEST_NESTED_REPO="$TEMP_ROOT/nested/container/deep-repo"
FAKE_WT="$ROOT_DIR/tests/fake-wt.sh"
FAKE_FZF="$ROOT_DIR/tests/fake-fzf.sh"
WT_LOG="$TEMP_ROOT/wt.log"
FZF_ARGS_LOG="$TEMP_ROOT/fzf-args.log"
FZF_INPUT_LOG="$TEMP_ROOT/fzf-input.log"
FZF_CHOICES_FILE="$TEMP_ROOT/fzf-choices"
FZF_STATE_FILE="$TEMP_ROOT/fzf-state"
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

canonical_dir() {
  (cd "$1" && pwd -P)
}

bash -n "$ROOT_DIR/bin/wt-tmux"
bash -n "$ROOT_DIR/install.sh"
bash -n "$ROOT_DIR/uninstall.sh"
bash -n "$FAKE_WT"
bash -n "$FAKE_FZF"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$ROOT_DIR/bin/wt-tmux" "$ROOT_DIR/install.sh" \
    "$ROOT_DIR/uninstall.sh" "$FAKE_WT" "$FAKE_FZF" "$0"
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

git init -q -b main "$TEST_OTHER_REPO"
git -C "$TEST_OTHER_REPO" config user.name test
git -C "$TEST_OTHER_REPO" config user.email test@example.invalid
git -C "$TEST_OTHER_REPO" commit -q --allow-empty -m initial
git init -q --bare "$TEST_BARE_REPO"

mkdir -p "$TEST_CONFIGURED_DIR" "$(dirname "$TEST_NESTED_REPO")"
git init -q -b main "$TEST_CONFIGURED_REPO"
git -C "$TEST_CONFIGURED_REPO" config user.name test
git -C "$TEST_CONFIGURED_REPO" config user.email test@example.invalid
git -C "$TEST_CONFIGURED_REPO" commit -q --allow-empty -m initial
git init -q -b main "$TEST_NESTED_REPO"
git -C "$TEST_NESTED_REPO" config user.name test
git -C "$TEST_NESTED_REPO" config user.email test@example.invalid
git -C "$TEST_NESTED_REPO" commit -q --allow-empty -m initial
git -C "$TEST_REPO" worktree add -q -b feature "$TEST_WORKTREE"

TEST_REPO="$(canonical_dir "$TEST_REPO")"
TEST_OTHER_REPO="$(canonical_dir "$TEST_OTHER_REPO")"
TEST_BARE_REPO="$(canonical_dir "$TEST_BARE_REPO")"
TEST_WORKTREE="$(canonical_dir "$TEST_WORKTREE")"
TEST_CONFIGURED_DIR="$(canonical_dir "$TEST_CONFIGURED_DIR")"
TEST_CONFIGURED_REPO="$(canonical_dir "$TEST_CONFIGURED_REPO")"
TEST_NESTED_REPO="$(canonical_dir "$TEST_NESTED_REPO")"

: >"$WT_LOG"
: >"$FZF_ARGS_LOG"
: >"$FZF_INPUT_LOG"

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

: >"$WT_LOG"
DEFAULT_OUTPUT="$(
  cd "$TEST_REPO"
  FZF_BIN="$FAKE_FZF" \
  FZF_TEST_ARGS_LOG="$FZF_ARGS_LOG" \
  FZF_TEST_INPUT_LOG="$FZF_INPUT_LOG" \
  WT_BIN="$FAKE_WT" \
  WT_TEST_LOG="$WT_LOG" \
  WT_TMUX_SOCKET="$SOCKET" \
  WT_TMUX_NO_ATTACH=1 \
  WT_TMUX_AGENT=: \
  WT_TMUX_EDITOR=: \
    "$TEST_HOME/.local/bin/wt-tmux" open-ui
)"
test -z "$DEFAULT_OUTPUT"
test "$(head -n 1 "$FZF_INPUT_LOG" | cut -f2)" = "$TEST_REPO"
grep -Fq -- '--no-sort' "$FZF_ARGS_LOG"
grep -Fq -- '--info=hidden' "$FZF_ARGS_LOG"
grep -Fq -- '--prompt=Repository> ' "$FZF_ARGS_LOG"
grep -Fq -- "-C $TEST_REPO switch" "$WT_LOG"
test "$(wc -l <"$WT_LOG" | tr -d ' ')" -eq 1

: >"$WT_LOG"
: >"$FZF_INPUT_LOG"
(
  cd "$TEST_REPO"
  FZF_BIN="$FAKE_FZF" \
  FZF_TEST_ARGS_LOG="$FZF_ARGS_LOG" \
  FZF_TEST_INPUT_LOG="$FZF_INPUT_LOG" \
  FZF_TEST_MATCH_PATH="$TEST_OTHER_REPO" \
  WT_BIN="$FAKE_WT" \
  WT_TEST_LOG="$WT_LOG" \
  WT_TMUX_SOCKET="$SOCKET" \
  WT_TMUX_NO_ATTACH=1 \
  WT_TMUX_AGENT=: \
  WT_TMUX_EDITOR=: \
    "$TEST_HOME/.local/bin/wt-tmux" open-ui
) >/dev/null
test "$(head -n 1 "$FZF_INPUT_LOG" | cut -f2)" = "$TEST_REPO"
cut -f2 "$FZF_INPUT_LOG" | grep -Fqx "$TEST_OTHER_REPO"
if cut -f2 "$FZF_INPUT_LOG" | grep -Fqx "$TEST_WORKTREE"; then
  printf 'A sibling worktree was shown as a separate repository.\n' >&2
  exit 1
fi
if cut -f1,2 "$FZF_INPUT_LOG" | grep -Fqx "[repo]	$TEST_BARE_REPO"; then
  printf 'A bare Git repository was shown as a worktree repository.\n' >&2
  exit 1
fi
if cut -f2 "$FZF_INPUT_LOG" | grep -Fqx "$TEST_NESTED_REPO"; then
  printf 'Repository discovery unexpectedly recursed into nested directories.\n' >&2
  exit 1
fi
grep -Fq -- "-C $TEST_OTHER_REPO switch" "$WT_LOG"
test "$(wc -l <"$WT_LOG" | tr -d ' ')" -eq 1

: >"$WT_LOG"
: >"$FZF_INPUT_LOG"
(
  cd "$TEST_REPO"
  FZF_BIN="$FAKE_FZF" \
  FZF_TEST_ARGS_LOG="$FZF_ARGS_LOG" \
  FZF_TEST_INPUT_LOG="$FZF_INPUT_LOG" \
  FZF_TEST_MATCH_PATH="$TEST_CONFIGURED_REPO" \
  WT_BIN="$FAKE_WT" \
  WT_TEST_LOG="$WT_LOG" \
  WT_TMUX_REPOS_DIR="$TEST_CONFIGURED_DIR" \
  WT_TMUX_SOCKET="$SOCKET" \
  WT_TMUX_NO_ATTACH=1 \
  WT_TMUX_AGENT=: \
  WT_TMUX_EDITOR=: \
    "$TEST_HOME/.local/bin/wt-tmux" open-ui
) >/dev/null
test "$(head -n 1 "$FZF_INPUT_LOG" | cut -f2)" = "$TEST_REPO"
cut -f2 "$FZF_INPUT_LOG" | grep -Fqx "$TEST_CONFIGURED_REPO"
if cut -f2 "$FZF_INPUT_LOG" | grep -Fqx "$TEST_OTHER_REPO"; then
  printf 'Repository picker ignored WT_TMUX_REPOS_DIR.\n' >&2
  exit 1
fi
grep -Fq -- "-C $TEST_CONFIGURED_REPO switch" "$WT_LOG"

: >"$WT_LOG"
(
  cd "$TEST_REPO"
  printf 'feature/from-other\n\n' |
    FZF_BIN="$FAKE_FZF" \
    FZF_TEST_ARGS_LOG="$FZF_ARGS_LOG" \
    FZF_TEST_INPUT_LOG="$FZF_INPUT_LOG" \
    FZF_TEST_MATCH_PATH="$TEST_OTHER_REPO" \
    WT_BIN="$FAKE_WT" \
    WT_TEST_LOG="$WT_LOG" \
    WT_TMUX_SOCKET="$SOCKET" \
    WT_TMUX_NO_ATTACH=1 \
      "$TEST_HOME/.local/bin/wt-tmux" feature-ui
) >/dev/null
grep -Fq -- "-C $TEST_OTHER_REPO switch --create feature/from-other --base ^" "$WT_LOG"

: >"$WT_LOG"
(
  cd "$TEST_REPO"
  printf '123\n' |
    FZF_BIN="$FAKE_FZF" \
    FZF_TEST_ARGS_LOG="$FZF_ARGS_LOG" \
    FZF_TEST_INPUT_LOG="$FZF_INPUT_LOG" \
    FZF_TEST_MATCH_PATH="$TEST_OTHER_REPO" \
    WT_BIN="$FAKE_WT" \
    WT_TEST_LOG="$WT_LOG" \
    WT_TMUX_SOCKET="$SOCKET" \
    WT_TMUX_NO_ATTACH=1 \
      "$TEST_HOME/.local/bin/wt-tmux" pr-ui
) >/dev/null
grep -Fq -- "-C $TEST_OTHER_REPO switch pr:123" "$WT_LOG"

: >"$WT_LOG"
(
  cd "$TEST_REPO"
  printf 'feature/from-pr\n456\n' |
    FZF_BIN="$FAKE_FZF" \
    FZF_TEST_ARGS_LOG="$FZF_ARGS_LOG" \
    FZF_TEST_INPUT_LOG="$FZF_INPUT_LOG" \
    FZF_TEST_MATCH_PATH="$TEST_OTHER_REPO" \
    WT_BIN="$FAKE_WT" \
    WT_TEST_LOG="$WT_LOG" \
    WT_TMUX_SOCKET="$SOCKET" \
    WT_TMUX_NO_ATTACH=1 \
      "$TEST_HOME/.local/bin/wt-tmux" branch-from-pr-ui
) >/dev/null
grep -Fq -- "-C $TEST_OTHER_REPO switch --create feature/from-pr --base pr:456" "$WT_LOG"

: >"$WT_LOG"
(
  cd "$TEST_REPO"
  FZF_BIN="$FAKE_FZF" \
  FZF_TEST_ARGS_LOG="$FZF_ARGS_LOG" \
  FZF_TEST_INPUT_LOG="$FZF_INPUT_LOG" \
  FZF_TEST_CANCEL=1 \
  WT_BIN="$FAKE_WT" \
  WT_TEST_LOG="$WT_LOG" \
    "$TEST_HOME/.local/bin/wt-tmux" feature-ui
) >/dev/null
test ! -s "$WT_LOG"

: >"$WT_LOG"
: >"$FZF_STATE_FILE"
printf '%s\n' \
  "$(dirname "$(dirname "$TEST_NESTED_REPO")")" \
  "$(dirname "$TEST_NESTED_REPO")" \
  "$TEST_NESTED_REPO" >"$FZF_CHOICES_FILE"
(
  cd "$TEST_REPO"
  FZF_BIN="$FAKE_FZF" \
  FZF_TEST_ARGS_LOG="$FZF_ARGS_LOG" \
  FZF_TEST_INPUT_LOG="$FZF_INPUT_LOG" \
  FZF_TEST_CHOICES_FILE="$FZF_CHOICES_FILE" \
  FZF_TEST_STATE_FILE="$FZF_STATE_FILE" \
  WT_BIN="$FAKE_WT" \
  WT_TEST_LOG="$WT_LOG" \
  WT_TMUX_SOCKET="$SOCKET" \
  WT_TMUX_NO_ATTACH=1 \
  WT_TMUX_AGENT=: \
  WT_TMUX_EDITOR=: \
    "$TEST_HOME/.local/bin/wt-tmux" open-ui
) >/dev/null
test "$(<"$FZF_STATE_FILE")" -eq 3
grep -Fq -- "-C $TEST_NESTED_REPO switch" "$WT_LOG"

: >"$WT_LOG"
: >"$FZF_STATE_FILE"
printf '%s\n' "$(dirname "$(canonical_dir "$TEMP_ROOT")")" CANCEL >"$FZF_CHOICES_FILE"
(
  cd "$TEST_REPO"
  FZF_BIN="$FAKE_FZF" \
  FZF_TEST_ARGS_LOG="$FZF_ARGS_LOG" \
  FZF_TEST_INPUT_LOG="$FZF_INPUT_LOG" \
  FZF_TEST_CHOICES_FILE="$FZF_CHOICES_FILE" \
  FZF_TEST_STATE_FILE="$FZF_STATE_FILE" \
  WT_BIN="$FAKE_WT" \
  WT_TEST_LOG="$WT_LOG" \
  WT_TMUX_SOCKET="$SOCKET" \
  WT_TMUX_NO_ATTACH=1 \
    "$TEST_HOME/.local/bin/wt-tmux" open-ui
) >/dev/null
test "$(<"$FZF_STATE_FILE")" -eq 2
test ! -s "$WT_LOG"

: >"$WT_LOG"
(
  cd "$TEST_REPO"
  FZF_BIN="$FAKE_FZF" \
  FZF_TEST_ARGS_LOG="$FZF_ARGS_LOG" \
  FZF_TEST_INPUT_LOG="$FZF_INPUT_LOG" \
  FZF_TEST_CANCEL=1 \
  WT_BIN="$FAKE_WT" \
  WT_TEST_LOG="$WT_LOG" \
  WT_TMUX_SOCKET="$SOCKET" \
  WT_TMUX_NO_ATTACH=1 \
    "$TEST_HOME/.local/bin/wt-tmux" open-ui
) >/dev/null
test ! -s "$WT_LOG"

HOME="$TEST_HOME" WT_TMUX_NO_RELOAD=1 "$ROOT_DIR/uninstall.sh" >/dev/null
test ! -e "$TEST_HOME/.local/bin/wt-tmux"
test ! -e "$TEST_HOME/.config/tmux/worktree-menu.conf"
test "$(grep -c '^# BEGIN worktree-tmux-menu$' "$TEST_HOME/.tmux.conf" || true)" -eq 0
grep -q '^set -g mouse on$' "$TEST_HOME/.tmux.conf"

printf 'All tests passed.\n'
