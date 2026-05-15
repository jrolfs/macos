# XXX: workaround to allow starship to be disabled when Git makes it
# super slow, see https://github.com/starship/starship/issues/1617
if [[ -a "$(pwd)/.git/_starship_disable" ]]; then
  zstyle ':prezto:module:prompt' theme 'pure'
  unset STARSHIP_ENABLED
else
  zstyle ':prezto:module:prompt' theme 'default'
  STARSHIP_ENABLED=1
fi

# Prints new line between prompts
precmd() {
  $funcstack[1]() {
    echo
  }
}
