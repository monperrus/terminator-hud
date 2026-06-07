# Specification: Current Working Directory (CWD) Inheritance for New Tabs

## Goal

When the user opens a new terminal tab, it should start in the same directory as the tab they were just working in.

## Mechanism

### 1. Track the last focused pane (tmux.conf)

The `pane-focus-in` hook fires every time a pane gains focus. It records the pane ID in a global tmux variable:

```
set-hook -g pane-focus-in 'set -g @last_focused_pane "#{pane_id}"'
```

`focus-events on` must be set so the outer terminal forwards focus events to tmux.

### 2. Read the source pane's live CWD (terminal-shell)

When a new tab is opened, `terminal-shell` runs before any new tmux pane exists. At this moment `@last_focused_pane` still holds the source pane's ID — the new pane hasn't been created yet, so no `pane-focus-in` event has fired for it.

```bash
LAST_PANE=$(tmux show-options -gqv @last_focused_pane 2>/dev/null)
CWD=$([ -n "$LAST_PANE" ] && tmux display-message -t "$LAST_PANE" -p "#{pane_current_path}" 2>/dev/null)
```

`#{pane_current_path}` is tmux's built-in path format that reads `/proc/<pid>/cwd` of the pane's shell process. It reflects the current directory instantly after any `cd` — no `PROMPT_COMMAND` required.

### 3. Pass the CWD to the new window (terminal-shell)

```bash
tmux new-window -t "$GROUPED" ${CWD:+-c "$CWD"} "$SHELL_CMD"
```

If `CWD` is empty (no previous focus event, e.g. very first boot), the flag is omitted and tmux uses its default.

## Files involved

| File | Role |
|---|---|
| `tmux.conf` | `pane-focus-in` hook sets `@last_focused_pane`; `focus-events on` enables it |
| `terminal-shell` | Reads `@last_focused_pane`, queries `#{pane_current_path}`, passes `-c` to `new-window` |
| `bash-init.sh` | No CWD file I/O; PROMPT_COMMAND only updates the HUD |

## Evolution (from trajectory history)

| Attempt | Approach | Problem |
|---|---|---|
| 1 | Query `#{client_name}` (tty path) via `display-message -t` | tty paths are not valid pane targets; `CWD` always empty |
| 2 | `#{client_session}` of most recently active client | Race: `client_activity` ordering unreliable between grouped sessions |
| 3 | `pane-focus-in` writes `@last_focused_pane`; terminal-shell reads `#{pane_current_path}` | Incomplete: `@last_focused_pane` unset on first boot, not handled |
| 4 | PROMPT_COMMAND writes per-pane `/tmp` files; `ls -t` picks most-recently-modified | **Root bug:** any other pane's PROMPT_COMMAND (e.g. a background job completing) can update its file's mtime, making `ls -t` pick the wrong pane. HUD stays correct because file and HUD write are in the same function call, but the race is in `ls -t` at tab-open time. |
| 5 (current) | `pane-focus-in` + `#{pane_current_path}` (reads `/proc/<pid>/cwd` live) | No race: `@last_focused_pane` is set when user switches to the source tab, and the new pane doesn't exist until after terminal-shell reads it. No PROMPT_COMMAND dependency. |

## Edge cases

- **First tab / no prior focus event**: `@last_focused_pane` is unset; `CWD` is empty; new tab opens in tmux's default directory (`$HOME`).
- **Source pane closed before new tab opens**: `display-message -t "$LAST_PANE"` fails; `CWD` is empty; falls back to default.
- **Root directory** (`/`): `#{pane_current_path}` returns `/`; `-c /` is a valid `new-window` argument.
