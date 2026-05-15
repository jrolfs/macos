setopt extendedglob

mkdir -p $XDG_CONFIG_HOME/zsh/completions
source $XDG_CONFIG_HOME/zsh/starship.zsh

# Editors
export EDITOR='nvim'
export VISUAL='nvim'
export PAGER='less'

export ZLE_RPROMPT_INDENT=0

#
# Language
#

if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
fi

#
# Paths
#

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path

# ZSH function search path
fpath+=(
  ${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh/site-functions
  $XDG_CONFIG_HOME/zsh/themes
  $XDG_CONFIG_HOME/zsh/completions
)

# Executable search path
path=(
  /opt/homebrew/bin
  /usr/local/{bin,sbin}
  $GOPATH/bin
  $SPICETIFY_INSTALL
  $WORK_BIN
  $path
)

source $XDG_CONFIG_HOME/zsh/mise.zsh

#
# Less
#

# Set the default Less options.
# Mouse-wheel scrolling has been disabled by -X (disable screen clearing).
# Remove -X and -F (exit if the content fits on one screen) to enable it.
export LESS='-F -g -i -M -R -S -w -X -z-4'

# Set the Less input preprocessor.
# Try both `lesspipe` and `lesspipe.sh` as either might exist on a system.
if (( $#commands[(i)lesspipe(|.sh)] )); then
  export LESSOPEN="| /usr/bin/env $commands[(i)lesspipe(|.sh)] %s 2>&-"
fi

#
# Temporary Files
#

TMPPREFIX="$(mktemp -d)/zsh"

# If installed, make OrbStack `docker` CLI etc. available
# on `$PATH` and add associated completions to `$fpath`
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
