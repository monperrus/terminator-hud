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
    local label=" $(hostname -s) | ${dir:-/} | ${jobs_count} job$( [ "$jobs_count" -ne 1 ] && echo s ) "
    tmux set-option -g @auto_status "$label" 2>/dev/null
    tmux set-window-option -t "$TMUX_PANE" @tab_age " $(_terminator_age) " 2>/dev/null
    _TERMINATOR_NEXT_CMD=1  # arm the DEBUG trap for the next real command
}

_terminator_debug() {
    # _TERMINATOR_NEXT_CMD is set by PROMPT_COMMAND; the very first DEBUG fire
    # after a prompt is the user's command — show it, then disarm.
    [ "$_TERMINATOR_NEXT_CMD" != "1" ] && return
    _TERMINATOR_NEXT_CMD=0
    [ -z "$TMUX" ] && return
    local dir="${PWD##*/}"
    tmux set-option -g @auto_status " $(hostname -s) | ${dir:-/} | $BASH_COMMAND " 2>/dev/null
}

trap '_terminator_debug' DEBUG
# Prepend to PROMPT_COMMAND so it runs before any user-defined hooks.
PROMPT_COMMAND="_terminator_update_status${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# Kill the tmux window when this shell exits (i.e. when the Terminator tab closes).
trap 'tmux kill-window 2>/dev/null' EXIT
