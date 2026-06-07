# Sourced as the --rcfile for bash running inside the tmux pane.
# Sources the user's normal bashrc first, then adds the status-bar hook.

[ -f ~/.bashrc ] && source ~/.bashrc

_TAB_START=$SECONDS

_terminator_age() {
    local s=$(( SECONDS - _TAB_START ))
    if   (( s < 60 ));    then echo "${s}s"
    elif (( s < 3600 ));  then echo "$(( s / 60 ))m"
    elif (( s < 86400 )); then echo "$(( s / 3600 ))h"
    else                       echo "$(( s / 86400 ))d"
    fi
}

_terminator_update_status() {
    [ -z "$TMUX" ] && return
    local jobs_count
    jobs_count=$(jobs 2>/dev/null | wc -l)
    local dir="${PWD##*/}"
    tmux rename-window -t "$TMUX_PANE" \
        " $(hostname -s) | ${dir:-/} | ${jobs_count} job$( [ "$jobs_count" -ne 1 ] && echo s ) " 2>/dev/null
    tmux set-option -w -t "$TMUX_PANE" @tab_age " $(_terminator_age) " 2>/dev/null
    _TERMINATOR_NEXT_CMD=1  # arm the DEBUG trap for the next real command
}

_terminator_debug() {
    # _TERMINATOR_NEXT_CMD is set by PROMPT_COMMAND; the very first DEBUG fire
    # after a prompt is the user's command — show it, then disarm.
    [ "$_TERMINATOR_NEXT_CMD" != "1" ] && return
    _TERMINATOR_NEXT_CMD=0
    [ -z "$TMUX" ] && return
    local dir="${PWD##*/}"
    tmux rename-window -t "$TMUX_PANE" \
        " $(hostname -s) | ${dir:-/} | $BASH_COMMAND " 2>/dev/null
}

trap '_terminator_debug' DEBUG
# Prepend to PROMPT_COMMAND so it runs before any user-defined hooks.
PROMPT_COMMAND="_terminator_update_status${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# Extract the remote hostname from ssh argument list.
# Skips option flags and their values; returns the [user@]host stripped of user@.
_terminator_ssh_hostname() {
    local skip_next=0
    local arg
    for arg; do
        if (( skip_next )); then
            skip_next=0
            continue
        fi
        case "$arg" in
            # Options that consume the next token as their value
            -[bcDEeFIiJLlmOopQRSwW]) skip_next=1 ;;
            # Options with value concatenated (e.g. -p22): skip, no next token
            -[bcDEeFIiJLlmOopQRSwW]*) ;;
            # Other flags: skip
            -*) ;;
            # First non-flag argument is [user@]host
            *) echo "${arg##*@}"; return ;;
        esac
    done
}

# Wrap ssh to show the remote hostname in the status bar for the duration of
# the connection.  PROMPT_COMMAND restores auto-status when ssh returns.
ssh() {
    local remote_host dir jobs_count
    remote_host=$(_terminator_ssh_hostname "$@")
    if [ -n "$remote_host" ] && [ -n "$TMUX" ]; then
        dir="${PWD##*/}"
        jobs_count=$(jobs 2>/dev/null | wc -l)
        tmux rename-window -t "$TMUX_PANE" \
            " $remote_host | ${dir:-/} | ${jobs_count} job$( [ "$jobs_count" -ne 1 ] && echo s ) " 2>/dev/null
    fi
    command ssh "$@"
}

# Kill the tmux window AND the grouped session when this shell exits
# (e.g. Ctrl-D).  Killing only the window leaves the tmux client alive,
# so the Terminator tab stays open.  Killing the grouped session
# disconnects the client, which causes Terminator to close the tab.
_terminator_exit() {
    # Read the grouped session name that terminator-shell stamped on this window.
    # We can't use #{session_name} because $TMUX in the first tab's shell points
    # to the base "terminator" session, which must never be killed.
    local session
    session=$(tmux show-options -wqv -t "$TMUX_PANE" @grouped_session 2>/dev/null)
    if [ -n "$session" ]; then
        # Killing the grouped session disconnects the tmux client → Terminator
        # closes the tab.  The window is cleaned up automatically by tmux once
        # this shell process exits.
        tmux kill-session -t "$session" 2>/dev/null
    fi
}
trap '_terminator_exit' EXIT
