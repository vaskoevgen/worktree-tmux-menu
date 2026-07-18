# worktree-tmux-menu

A tmux command palette for [Worktrunk](https://worktrunk.dev). Create, open,
review, publish, merge, and remove Git worktrees without leaving tmux — all from
a single keystroke-driven menu.

Each worktree gets one reusable tmux session with three panes:

```text
┌──────────────────────┬──────────────────────┐
│                      │ editor               │
│ coding agent         ├──────────────────────┤
│                      │ shell                │
└──────────────────────┴──────────────────────┘
```

The defaults are Claude in the left pane, Neovim in the top-right pane, and
your normal shell in the bottom-right pane. Session names include the repository,
branch, and a short hash, so branches with the same name in different repositories
do not collide.

## Requirements

- macOS or Linux
- Bash 3.2+
- tmux 3.2+
- Git
- [Worktrunk](https://worktrunk.dev) (`wt`)
- `jq`
- Optional: `gh` for GitHub PR actions
- Optional: Claude and Neovim, or configure other pane commands

Example installation on macOS:

```bash
brew install tmux git jq gh worktrunk
wt config shell install
gh auth login
```

## Install

```bash
mkdir -p ~/src
git clone https://github.com/vaskoevgen/worktree-tmux-menu.git \
  ~/src/worktree-tmux-menu
cd ~/src/worktree-tmux-menu
./install.sh
```

The installer:

1. Copies `wt-tmux` to `~/.local/bin/wt-tmux`.
2. Generates `~/.config/tmux/worktree-menu.conf`.
3. Adds one managed `source-file` block to `~/.tmux.conf`.
4. Reloads tmux when a server is running.
5. Saves the original tmux configuration once as
   `~/.tmux.conf.worktree-tmux-menu.bak`.

It is safe to run the installer again. It updates the installed files without
duplicating the managed block.

Open the menu with your normal tmux prefix followed by `m`. For example,
`Ctrl+b m`, or `Ctrl+a m` if your prefix is `Ctrl+a`.

## Menu

| Key | Action | What it does |
| --- | --- | --- |
| `w` | Open/switch worktree | Pick an existing worktree, local branch, or remote branch |
| `N` | New feature branch | Create a worktree from the default or specified base |
| `R` | Review GitHub PR | Open `pr:<number>` as a worktree |
| `B` | New branch from PR | Create a new branch based on a PR head |
| `W` | Worktree status | Show `wt list --full` |
| `C` | Commit changes | Run `wt step commit` |
| `G` | Publish GitHub PR | Push the current branch and run `gh pr create` |
| `M` | Merge into default | Confirm, run `wt merge`, switch sessions, and clean up |
| `X` | Remove worktree | Safely run `wt remove` and clean up its session |
| `H` | Command guide | Show helper commands and configuration |

The menu also retains common tmux window, pane, session, and detach actions.

## Workflows

### Start a feature

1. Open the menu and press `N`.
2. Enter a branch name such as `feature/auth`.
3. Leave the base empty to use the repository default branch, or enter another
   branch, `@` for the current branch, or `pr:123`.
4. Worktrunk creates the branch/worktree and the helper opens its three-pane
   tmux session.

### Open an existing branch or worktree

Press `w` to open Worktrunk's interactive picker. Selecting a branch creates its
worktree when necessary, then creates or reuses the matching tmux session.

### Review a GitHub PR

Press `R`, enter the PR number, and Worktrunk resolves `pr:<number>`. This requires
an authenticated GitHub CLI:

```bash
gh auth status
```

### Publish a PR

Use `C` to commit, then `G` to push and run the interactive `gh pr create` flow.
After the PR is merged remotely, use `X` to remove the local worktree.

### Merge locally

Press `M`. Worktrunk's normal merge policy may commit, squash, rebase, run hooks,
fast-forward the default branch, and remove the feature worktree. After success,
the helper opens the default-branch session and closes the completed feature
session. A failed or cancelled merge leaves the current session intact.

## Configuration

Set pane commands in `~/.tmux.conf`. `set-environment -g` updates the environment
owned by the tmux server, so it works even when the server was started before your
shell exports were set:

```tmux
set-environment -g WT_TMUX_AGENT "claude"
set-environment -g WT_TMUX_EDITOR "nvim ."
```

Other examples:

```tmux
set-environment -g WT_TMUX_AGENT "codex"
set-environment -g WT_TMUX_EDITOR "vim ."
```

Worktrunk controls where worktrees live. For sibling directories, put this in
`~/.config/worktrunk/config.toml`:

```toml
worktree-path = "{{ repo_path }}/../{{ repo }}.{{ (branch | sanitize)[:35] }}"
```

The installer supports alternate destinations:

```bash
WT_TMUX_BIN_DIR="$HOME/bin" \
WT_TMUX_CONFIG_DIR="$HOME/.config/tmux" \
WT_TMUX_CONF="$HOME/.tmux.conf" \
./install.sh
```

Use the same variables with `uninstall.sh`.

## Avoid duplicate tmux sessions

This project owns tmux session creation. If a repository already has Worktrunk
hooks that run `tmux new-session` or `tmux kill-session`, remove those hooks from
the repository's `.config/wt.toml`.

For example, remove old blocks like:

```toml
[post-start]
tmux = "tmux new-session ..."

[pre-remove]
tmux = "tmux kill-session ..."
```

Keep unrelated hooks such as dependency installation, environment setup, tests,
or clipboard actions. Worktrunk may retain old approvals in
`~/.config/worktrunk/approvals.toml`; those approvals are harmless after the hooks
are removed.

## Update

```bash
cd ~/src/worktree-tmux-menu
git pull --ff-only
./install.sh
```

## Uninstall

```bash
cd ~/src/worktree-tmux-menu
./uninstall.sh
```

Uninstall removes only the installed helper, generated menu, and managed block.
It does not delete Git worktrees, tmux sessions, or Worktrunk configuration.

## Troubleshooting

- Run worktree actions from a tmux pane whose current directory is inside a Git
  worktree. Errors remain visible in the popup until you press a key.
- If `w` shows no remote branches, run `git fetch` or check the repository remote.
- If PR actions fail, run `gh auth status` and verify the repository is hosted on
  GitHub.
- If two sessions appear for one new worktree, remove repository-level tmux hooks
  as described above.
- Run `wt config show` to see the active user and project configuration.
- Run `~/.local/bin/wt-tmux help` for direct helper commands.

## Development

```bash
./tests/test.sh
```

The test performs syntax and lint checks, verifies idempotent install/uninstall,
loads the generated configuration in an isolated tmux server, and confirms that
opening one worktree twice still produces exactly three panes.

## License

[MIT](LICENSE)
