# terminator-hud

A custom shell command for the [Terminator](https://gnome-terminator.org/) terminal emulator that adds a persistent green status bar and syncs every Terminator tab to a tmux window.

```
┌─────────────────────────────────────────────────────┐
│  $ vim src/main.py                                  │
│  ~                                                  │
│                                                     │
├─────────────────────────────────────────────────────┤
│  hostname | src | vim src/main.py                   │  ← green status bar
└─────────────────────────────────────────────────────┘
```

## Features

- **Status bar** — always-visible green bar at the bottom showing:
  - hostname
  - current directory (basename only)
  - number of background jobs
  - the currently running command (while a command is executing)
- **Tab sync** — each Terminator tab maps 1-to-1 to a tmux window; opening a tab creates a window, closing a tab destroys it
- **Custom status text** — `Ctrl-b S` lets you type arbitrary text into the bar (empty input resets to auto)

## Requirements

- [Terminator](https://gnome-terminator.org/) (any recent version)
- [tmux](https://github.com/tmux/tmux) ≥ 3.0

## Setup

1. Clone this repo somewhere permanent:

   ```sh
   git clone https://github.com/monperrus/terminator-hud ~/.config/terminator-hud
   ```

2. Open Terminator → **Preferences → Profiles → (your profile) → Command**
   - Check **"Run a custom command instead of my shell"**
   - Set the command to:
     ```
     /home/<you>/.config/terminator-hud/terminator-shell
     ```

3. Close and reopen Terminator.

## How it works

`terminator-shell` is what Terminator runs instead of bash. It starts (or joins) a tmux session named `terminator`:

- **First tab** creates the session (tmux window 0).
- **Subsequent tabs** call `tmux new-window -P -d` to get a fresh window, then attach directly to it — so each Terminator tab is an independent tmux client focused on its own window.
- **Closing a tab** fires an `EXIT` trap in bash that calls `tmux kill-window`, keeping tmux in sync.

Inside each pane, `bash-init.sh` is sourced as the rcfile. It:

1. Sources `~/.bashrc` so your normal environment is preserved.
2. Adds a `PROMPT_COMMAND` hook that pushes `hostname | dir | N jobs` into the tmux user-variable `@auto_status` after each command.
3. Adds a `DEBUG` trap that fires before each command runs and updates `@auto_status` to show the command name, giving live feedback while long-running programs execute.

`tmux.conf` renders `@auto_status` (or `@custom_status` when set) in the status bar.

## Keybindings

| Shortcut | Action |
|---|---|
| `Ctrl-b S` | Prompt for custom status text; leave empty to reset to auto |

The tmux prefix is the default `Ctrl-b`. All other standard tmux keybindings work normally.
