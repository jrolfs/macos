# Execute code that does not affect the current session in the background.
{
  # Compile the completion dump to increase startup speed.
  zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
  if [[ -s "$zcompdump" && (! -s "${zcompdump}.zwc" || "$zcompdump" -nt "${zcompdump}.zwc") ]]; then
    zcompile "$zcompdump"
  fi
} &!

# Execute code only if STDERR is bound to a TTY.
[[ -o INTERACTIVE && -t 2 ]] && {

  #
  # Welcome message

  echo "\r"

  if (( $+commands[figlet] )); then
    local -a entries=(
      "isometric3 5"
      "fraktur    4"
      "cosmic     4"
      "whimsy     3"
      "univers    2"
      "poison     3"
      "nvscript   3"
      "lean       5"
      "larry3d    4"
      "broadway   3"
      "banner3-D  2"
    )

    local total=0 entry font rate

    for entry in $entries; do
      rate=${entry##* }
      (( total += rate ** 2 ))
    done

    local pick cumul=0
    local host=$(hostname -s | tr '-' ' ')

    (( pick = RANDOM % total ))

    for entry in $entries; do
      font=${entry%% *}
      rate=${entry##* }

      (( cumul += rate ** 2 ))
      (( pick < cumul )) && { print -n '\e[90m'; figlet -f "$font" "$host"; print -n '\e[0m'; break }
    done
  fi

  echo "\r"

  if (( $+commands[fortune] )); then
    print -n '\e[35m'
    fortune -s | dotacat -p 20 -S 70
    print '\e[0m'
  fi

} >&2
