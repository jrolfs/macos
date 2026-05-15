#
# Miscellaneous

function exists {
  return $(command -v $1 >&/dev/null 2>&1)
}

function kill-port {
  lsof -iTCP:$1 | grep LISTEN | awk '{ print $2 }' | xargs kill $2
}

function npmv {
  if [[ "$2" =~ ^[0-9]+$ ]]; then
    npm info "$1" --json | jq --raw-output ".versions[-$2:][]"
  else
    npm info "$1" --json | jq --raw-output '.versions[-1]'
  fi
}

function nix-rip {
  rg -g "**/*$1*/**/default.nix" --files --hidden ~/.nix-defexpr/nixpkgs/pkgs
}

function skim { nvim $(sk); }

function ln-h {
  if [[ -L "$1" ]]; then
      ln -f "$(readlink "$1")" $1
  else
      echo "Error: '$1' is not a symbolic link"
      return 1
  fi
}

#
# Media

heic2jpg() {
  local keep
  local help
  local usage=(
    "heic2jpg [-h|--help]"
    "heic2jpg [-k|--keep]"
  )

  zmodload zsh/zutil
  zparseopts -D -F -K -- \
    {h,-help}=help \
    {k,-keep}=keep \
    || { print -l $usage && return 1 }

  [[ -z "$help" ]] || { print -l $usage && return }

  local converted=()
  while read -r file; do
      sips -s format jpeg "$file" --out "${file:r}.jpg" &>/dev/null
      converted+=("${file:t}")
  done < <(fd --regex '(?i)heic')

  if [[ -z "$keep" ]]; then
      rm "${converted[@]}"
  fi
}

function gif {
  if [[ "$2" =~ ^[0-9]+$ ]]; then
    ffmpeg -i $1 -pix_fmt rgb8 -r 20 -f gif "${1%.*}.gif" -filter:v scale=$2:-1
  else
    ffmpeg -i $1 -pix_fmt rgb8 -r 20 -f gif "${1%.*}.gif"
  fi
}

function 1080 {
  setopt local_options nullglob

  for file in *.mov *.mp4; do
    if [[ $file != *_1080.mp4 ]]; then
      if [[ $# -eq 0 ]] || [[ $file == *"$1"* ]]; then
        output="${file%.*}_1080.mp4"

        if [[ $file == *.mov ]] || [[ $file == *.mp4 ]]; then
          ffmpeg -i "$file" -crf 10 -vf "scale=-2:1080" "$output"
        fi
      fi
    fi
  done
}

function video-speed {
  setopt local_options nullglob

  # Default speed factor
  local factor=${1:-2.0}

  # Check if factor is a valid number
  if ! [[ $factor =~ ^[0-9]*\.?[0-9]+$ ]]; then
    echo "Error: Invalid speed factor. Please use a positive number."
    return 1
  fi

  # Determine if we're slowing down or speeding up
  local operation
  if (( $(echo "$factor > 1" | bc -l) )); then
    operation="slow"
  else
    operation="fast"
  fi

  # Format the factor for the filename
  local factor_str
  if [[ $factor == *.0 || $factor == *. ]]; then
    factor_str=$(printf "%.0f" $factor)
  else
    factor_str=$factor
  fi

  for file in *.mov *.mp4; do
    if [[ $file != *_${operation}*.mp4 ]]; then
      if [[ $# -le 1 ]] || [[ $file == *"$2"* ]]; then
        output="${file%.*}_${operation}-${factor_str}x.mp4"

        if [[ $file == *.mov ]] || [[ $file == *.mp4 ]]; then
          ffmpeg -i "$file" -filter:v "setpts=${factor}*PTS,minterpolate='mi_mode=mci:mc_mode=aobmc:vsbmc=1:fps=60'" -crf 18 "$output"
          echo "Processed $file with speed factor $factor"
        fi
      fi
    fi
  done
}

#
# Git

function add-fork {
  local source_remote=${1:-upstream}
  local source_url=$(git remote get-url $source_remote)

  local target_user=${2:-jrolfs}
  local target_remote=${3:-origin}

  local target_url=$(sed "s/:.*\//:$target_user\//" <<< $source_url)

  git remote add $target_remote $target_url
}

function git-stash-drop {
  if [[ "$1" =~ ^[0-9]+$ ]] && ! [ $2 ]; then
    git stash drop "stash@{$1}"
  else
    git stash drop "$@"
  fi
}

function git-prune-local {
  local remote=${1:-origin}

  git remote prune $remote

  echo "\nPruning local branches"
  git branch -r | awk '{ print $1 }' | egrep -v -f /dev/fd/0 <(git branch -vv | grep origin) | awk '{ print $1 }' | egrep -v '^\+' | xargs git branch -D
}

function ... {
  cd $(git rev-parse --show-cdup)
}

# Hover

function unreleased {
  git log --pretty=oneline $(curl -s https://web-react.$1.4hover.app/health | jq -r '.releaseID')..$2
}

function unreleased-gh {
  echo "https://github.com/hoverinc/web-react/compare/$(curl -s https://web-react.$1.4hover.app/health | jq -r '.releaseID')..$2" | pbcopy
}


#
# GitHub

function gh-rr {
  for f in $(gh run list --workflow $1.yml | grep failure | awk '{ print $(NF-2) }'); do
    gh run rerun $f;
  done
}

#
# Kitty

# Font size
function kfs {
  # Remove all but the newest socket
  /bin/ls -t ~/.local/share/kitty | egrep '^socket' | awk 'NR>1' | xargs -I {} rm -- ~/.local/share/kitty/{}

  /opt/homebrew/bin/kitty @ --to unix:$(/run/current-system/sw/bin/fd socket ~/.local/share/kitty | tail -1) set-font-size $1
}

#
# GPG

function gpgp { echo $1 | gpg-preset-passphrase --preset 91C155A78968EEE863ED8B22626AE770762AC2F3 }

function pin() {
    local gpg_agent_conf="$HOME/.gnupg/gpg-agent.conf"
    local pinentry_program_mac="/run/current-system/sw/bin/pinentry-mac"
    local pinentry_program_default="/run/current-system/sw/bin/pinentry"
    local temp_file="/tmp/gpg-agent.conf.tmp"

    local current_pinentry_program
    current_pinentry_program=$(grep "^pinentry-program" "$gpg_agent_conf")

    if [[ "$current_pinentry_program" == *"$pinentry_program_mac"* ]]; then
        sed "s|$pinentry_program_mac|$pinentry_program_default|g" "$gpg_agent_conf" > "$temp_file"
        echo -ne "\033[1;33m\033[0m Using \033[1mdefault\033[0m pinentry"
    else
        sed "s|$pinentry_program_default|$pinentry_program_mac|g" "$gpg_agent_conf" > "$temp_file"
        echo -ne "\033[1;33m󰌋\033[0m Using \033[1mmacOS\033[0m pinentry"
    fi

    mv "$temp_file" "$gpg_agent_conf"

    # Restart gpg-agent
    echo -n ". Restarting \033[1mgpg-agent\033[0m... \033[32m󱎝 \033[0m"
    gpg-connect-agent reloadagent /bye
}



#
#
# Reference
#
#

# zparseopts
#
# Resources:
# - https://xpmo.gitlab.io/post/using-zparseopts/
# - https://zsh.sourceforge.io/Doc/Release/Zsh-Modules.html#index-zparseopts
#
# Features:
# - supports short and long flags (ie: -v|--verbose)
# - supports short and long key/value options (ie: -f <file> | --filename <file>)
# - does NOT support short and long key/value options with equals assignment (ie: -f=<file> | --filename=<file>)
# - supports short option chaining (ie: -vh)
# - everything after -- is positional even if it looks like an option (ie: -f)
# - once we hit an arg that isn't an option flag, everything after that is considered positional
function zparseopts_demo() {
  local flag_help flag_verbose
  local arg_filename=(myfile)  # set a default
  local usage=(
    "zparseopts_demo [-h|--help]"
    "zparseopts_demo [-v|--verbose] [-f|--filename=<file>] [<message...>]"
  )

  # -D pulls parsed flags out of $@
  # -E allows flags/args and positionals to be mixed, which we don't want in this example
  # -F says fail if we find a flag that wasn't defined
  # -M allows us to map option aliases (ie: h=flag_help -help=h)
  # -K allows us to set default values without zparseopts overwriting them
  # Remember that the first dash is automatically handled, so long options are -opt, not --opt
  zmodload zsh/zutil
  zparseopts -D -F -K -- \
    {h,-help}=flag_help \
    {v,-verbose}=flag_verbose \
    {f,-filename}:=arg_filename ||
    return 1

  [[ -z "$flag_help" ]] || { print -l $usage && return }
  if (( $#flag_verbose )); then
    print "verbose mode"
  fi

  echo "--verbose: $flag_verbose"
  echo "--filename: $arg_filename[-1]"
  echo "positional: $@"
}
