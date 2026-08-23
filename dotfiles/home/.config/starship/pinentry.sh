#!/bin/sh
#
# Prompt indicator for the current pinentry mode, read from the same state
# file the `pin` function writes (.config/zsh/init/gpg.zsh). The mode is not
# in gpg-agent.conf because that file is declarative — pinentry-program there
# points at a dispatcher which reads this. Anything that is not "mac" means
# curses, so no file at all means curses.
#
# Accurate for this prompt's own session, which is what it is describing — a
# terminal is exactly the case where the dispatcher honours the state file.

state="${XDG_STATE_HOME:-$HOME/.local/state}/pinentry"

if [ "$(cat "$state" 2>/dev/null)" = mac ]; then
    echo "󰌋"
else
    echo ""
fi

