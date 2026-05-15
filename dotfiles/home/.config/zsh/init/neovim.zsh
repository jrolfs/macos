
# Generated from:
# `nvim -u ~/.config/nvim/init-kitty.vim +'KittyScrollbackGenerateCommandLineEditing zsh'`

autoload -Uz edit-command-line
zle -N edit-command-line

function kitty_scrollback_edit_command_line() {
  local VISUAL='/Users/jamie/.local/share/nvim/plugged-kitty/kitty-scrollback.nvim/scripts/edit_command_line.sh'
  zle edit-command-line
  zle kill-whole-line
}
zle -N kitty_scrollback_edit_command_line

bindkey '^e' kitty_scrollback_edit_command_line

# [optional] pass arguments to kitty-scrollback.nvim in command-line editing mode
# by using the environment variable KITTY_SCROLLBACK_NVIM_EDIT_ARGS
# export KITTY_SCROLLBACK_NVIM_EDIT_ARGS=''

