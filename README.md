# worktree-tmux-menu

A tmux command palette for [Worktrunk](https://worktrunk.dev). Create, open,
review, publish, merge, and remove Git worktrees without leaving tmux.

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
- `fzf`
- `jq`
- Optional: `gh` for GitHub PR actions
- Optional: Claude and Neovim, or configure other pane commands

Example installation on macOS:

```bash
brew install tmux git fzf jq gh worktrunk
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
| `w` | Open/switch worktree | Search repositories, then pick a worktree or branch |
| `N` | New feature branch | Choose a repository and create a worktree from the default or specified base |
| `R` | Review GitHub PR | Choose a repository and open `pr:<number>` as a worktree |
| `B` | New branch from PR | Choose a repository and create a new branch based on a PR head |
| `W` | Worktree status | Show `wt list --full` |
| `C` | Commit changes | Run `wt step commit` |
| `G` | Publish GitHub PR | Push the current branch and run `gh pr create` |
| `M` | Merge into default | Confirm, run `wt merge`, switch sessions, and clean up |
| `X` | Remove worktree | Safely run `wt remove` and clean up its session |
| `H` | Command guide | Show helper commands and configuration |

The menu also retains common tmux window and pane actions. Its session actions
are:

| Key | Action | What it does |
| --- | --- | --- |
| `S` | New session | Prompt for a name and create a session in the current directory |
| `s` | List sessions | Choose and switch to another tmux session |
| `K` | Delete session | Confirm, then stop the current session and all programs in it |
| `d` | Detach | Disconnect the client while leaving the session running |

Deleting a tmux session with `K` does not delete its Git branch or Worktrunk
worktree. Use `X` when you intend to remove a worktree and clean up its matching
session together.

## End-to-end walkthrough

This walkthrough uses this repository as an example. Start inside tmux in the
repository's default worktree:

```bash
cd ~/src/worktree-tmux-menu
git status
```

Worktree menu commands use the active pane's current directory to identify the
repository. The `w` action opens a searchable repository picker with that
repository selected by default. Open the menu with your tmux prefix followed by
`m` (normally `Ctrl+b m`).

### 1. Check the repository worktrees

Press `W` for **wt: worktree status**. The popup runs:

```bash
wt list --full
```

This shows the default worktree, feature worktrees, their branches, and their
current state. Press `q` to close the pager.

### 2. Create a feature worktree

1. Open the menu and press `N`.
2. Choose a repository, or press Enter to keep the current repository.
3. At `Feature branch:`, enter a name such as `docs/menu-walkthrough`.
4. At `Base branch [default]:`, press Enter to use the repository's default
   branch. You can instead enter another branch, `@` for the current branch, or
   `pr:123` to use a GitHub PR as the base.
5. Worktrunk creates the branch and its worktree.
6. The helper creates and switches to a tmux session for that worktree.

The new session contains three panes:

```text
┌──────────────────────┬──────────────────────┐
│                      │ editor               │
│ coding agent         ├──────────────────────┤
│                      │ shell                │
└──────────────────────┴──────────────────────┘
```

The panes all start in the new worktree. The left pane runs `WT_TMUX_AGENT`, the
top-right pane runs `WT_TMUX_EDITOR`, and the bottom-right pane is a normal shell.
If the session already exists, the helper reuses it instead of creating duplicate
panes.

### 3. Make and inspect changes

Edit files in the agent or editor pane. In the shell pane, normal Git commands
still work:

```bash
git status
git diff
```

Press `W` at any time to see the Worktrunk view of every worktree in the
repository.

### 4. Commit the changes

Open the menu and press `C` for **wt: commit changes**. The popup runs:

```bash
wt step commit
```

Follow the Worktrunk prompts to select and commit the changes. The popup remains
open when it needs you to inspect output or acknowledge an error.

### 5. Publish a GitHub pull request

1. Make sure `gh auth status` succeeds.
2. Open the menu and press `G` for **wt: publish GitHub PR**.
3. The helper pushes the current branch with an upstream:

   ```bash
   git push --set-upstream origin docs/menu-walkthrough
   ```

4. It then starts the interactive `gh pr create` flow. Choose the PR title and
   body and confirm creation.

### 6. Finish the work

Choose one of these paths; do not use both for the same feature worktree.

#### Merge locally with Worktrunk

1. Press `M` for **wt: merge into default branch**.
2. Review the confirmation and enter `y`.
3. Worktrunk applies its configured merge policy. It may commit, squash, rebase,
   run hooks, update the default branch, and remove the feature worktree.
4. After success, the helper creates or reuses the default-branch tmux session,
   switches to it, and closes the completed feature session.

If the merge fails or is cancelled, the worktree and current tmux session remain
available so you can fix the problem.

#### Merge on GitHub, then clean up locally

1. Merge the pull request on GitHub.
2. Return to the feature worktree's tmux session.
3. Press `X` for **wt: remove current worktree**.
4. Review the confirmation and enter `y`.
5. Worktrunk removes the worktree when it considers that safe. The helper then
   switches to the default-branch session and closes the removed worktree's
   session.

The default worktree cannot be removed with `X` or merged into itself with `M`.

## Other worktree workflows

### Open an existing worktree or branch

Press `w` to open the searchable repository picker. The repository containing
the active pane is first and selected by default, so press Enter to keep using
it. Type to filter entries, use the arrow keys to choose one, or press Escape to
cancel. Entries marked `[repo]` open a repository, `[dir]` browse into a
directory, and `[..]` moves to the parent directory. After choosing a repository,
Worktrunk's picker includes existing worktrees, local branches, and remote
branches. Selecting a branch creates its worktree when necessary and then
creates or reuses its tmux session.

### Review a GitHub PR without creating a feature branch

1. Confirm that `gh auth status` succeeds.
2. Press `R` and choose a repository, or press Enter for the current repository.
3. Enter only the numeric PR number, such as `123`.
4. Worktrunk resolves `pr:123`, creates or selects its worktree, and opens its
   tmux session.

### Start new work based on a GitHub PR

1. Press `B`.
2. Choose a repository, or press Enter for the current repository.
3. Enter a new local branch name.
4. Enter the numeric PR number to use as the base.
5. Worktrunk creates the new branch with `pr:<number>` as its base and opens the
   new worktree session.

This is useful when you want to modify or extend a PR without working directly
on its head branch.

### Get help inside tmux

Press `H` to show the helper's command guide. The same guide is available from a
shell:

```bash
~/.local/bin/wt-tmux help
```

## How the menu works

The flow for every `wt:` menu item is:

```text
prefix + m
    -> tmux opens a popup in the active pane's directory
    -> the popup runs ~/.local/bin/wt-tmux
    -> wt-tmux asks Worktrunk to manage the branch/worktree
    -> wt-tmux creates, reuses, switches, or removes the matching tmux session
```

`tmux/worktree-menu.conf.in` defines the complete menu. `install.sh` replaces the
helper path placeholder, writes the generated menu to
`~/.config/tmux/worktree-menu.conf`, sources it from `~/.tmux.conf`, and reloads
tmux. `bin/wt-tmux` implements the worktree and session behavior. `tests/test.sh`
uses a temporary home directory and isolated tmux server to verify installation,
configuration loading, session reuse, and uninstallation without changing your
real tmux configuration.

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

By default, `w` starts browsing in the current repository's parent directory.
You can move up with `[..]` or enter folders marked `[dir]`. Set a fixed initial
directory when your repositories live together elsewhere:

```tmux
set-environment -g WT_TMUX_REPOS_DIR "$HOME/src"
```

Repository discovery scans one directory level at a time as you navigate, so it
does not perform a slow recursive filesystem scan. Additional worktrees
belonging to the same Git repository are omitted from the repository picker
because Worktrunk shows them in the following worktree picker.

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
