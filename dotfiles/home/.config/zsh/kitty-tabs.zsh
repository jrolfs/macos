# Project-aware tab titles for kitty
[[ -n "$KITTY_INSTALLATION_DIR" ]] || return 0

typeset -g _ktt_icon=""
typeset -g _ktt_cached_dir=""

_ktt_detect_project() {
  [[ "$PWD" == "$_ktt_cached_dir" ]] && return
  _ktt_cached_dir="$PWD"
  _ktt_icon=""

  local dir="$PWD"
  local git_found=0

  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/tsconfig.json" ]];      then _ktt_icon=" "; return; fi
    if [[ -f "$dir/package.json" ]];      then _ktt_icon=" "; return; fi
    if [[ -f "$dir/Cargo.toml" ]];        then _ktt_icon=" "; return; fi
    if [[ -f "$dir/go.mod" ]];            then _ktt_icon=" "; return; fi
    if [[ -f "$dir/pyproject.toml" ]] ||
       [[ -f "$dir/setup.py" ]] ||
       [[ -f "$dir/requirements.txt" ]];  then _ktt_icon=" "; return; fi
    if [[ -f "$dir/Gemfile" ]] ||
       [[ -f "$dir/.ruby-version" ]];     then _ktt_icon=" "; return; fi
    if [[ -f "$dir/pom.xml" ]] ||
       [[ -f "$dir/build.gradle" ]] ||
       [[ -f "$dir/.java-version" ]];     then _ktt_icon=" "; return; fi
    if [[ -f "$dir/flake.nix" ]] ||
       [[ -f "$dir/default.nix" ]];       then _ktt_icon=" "; return; fi

    if (( ! git_found )) && [[ -d "$dir/.git" ]]; then
      git_found=1
    fi

    dir="${dir:h}"
  done

  if (( git_found )); then
    _ktt_icon=" "
  else
    _ktt_icon=""
  fi
}

typeset -g _ktt_max_title_len=24

_ktt_set_title() {
  _ktt_detect_project
  local title="${(%):-%1~}"

  # Shorten worktree prefixes: frontends.branch-name → f.branch-name
  if [[ "$title" == *.* ]]; then
    local prefix="${title%%.*}"
    local rest="${title#*.}"
    if [[ -d "${PWD:h}/${prefix}" ]]; then
      rest="${rest#jamie-}"
      title="${prefix[1]}.${rest}"
    fi
  fi

  (( ${#title} > _ktt_max_title_len )) && title="${title:0:$((_ktt_max_title_len - 1))} "
  print -n "\e]2;${_ktt_icon}${title}\a"
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _ktt_set_title
