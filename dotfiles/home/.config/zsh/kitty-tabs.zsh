# Project-aware tab titles for kitty
[[ -n "$KITTY_INSTALLATION_DIR" ]] || return 0

typeset -g _ktt_icon=""
typeset -g _ktt_cached_dir=""

# Central store for manually-pinned titles, keyed by absolute directory path.
# Persists across restarts and lives outside any repo (no gitignore needed).
typeset -g _ktt_override_file="${XDG_STATE_HOME:-$HOME/.local/state}/kitty/tab-titles"

# Look up a pinned title for $PWD. Sets REPLY and returns 0 on hit, else 1.
_ktt_lookup_override() {
  [[ -f "$_ktt_override_file" ]] || return 1
  local dir title
  while IFS=$'\t' read -r dir title || [[ -n "$dir" ]]; do
    if [[ "$dir" == "$PWD" ]]; then
      REPLY="$title"
      return 0
    fi
  done < "$_ktt_override_file"
  return 1
}

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
  # A pinned title for this directory wins over the automatic one.
  local REPLY
  if _ktt_lookup_override; then
    print -n "\e]2;${REPLY}\a"
    return
  fi

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

# Rewrite the store, dropping any existing entry for $PWD. If $1 is non-empty
# it is appended as the new title for $PWD.
_ktt_write_override() {
  local title="$1" tab=$'\t' tmp dir t
  mkdir -p -- "${_ktt_override_file:h}"
  tmp="${_ktt_override_file}.tmp.$$"
  : > "$tmp"
  if [[ -f "$_ktt_override_file" ]]; then
    while IFS=$'\t' read -r dir t || [[ -n "$dir" ]]; do
      [[ "$dir" == "$PWD" ]] && continue
      print -r -- "${dir}${tab}${t}"
    done < "$_ktt_override_file" >> "$tmp"
  fi
  [[ -n "$title" ]] && print -r -- "${PWD}${tab}${title}" >> "$tmp"
  mv -- "$tmp" "$_ktt_override_file"
}

# Pin a custom kitty tab title for the current directory. Persisted centrally,
# keyed by absolute path, and overrides the automatic project-aware title.
#
#   tab-title Deploy prod   # pin a title for $PWD (quotes optional)
#   tab-title               # show the pinned title for $PWD, if any
#   tab-title -c            # clear the pinned title for $PWD
tab-title() {
  case "$1" in
    -c | --clear)
      _ktt_write_override ""
      _ktt_cached_dir=""   # force the auto title to recompute
      _ktt_set_title
      ;;
    "")
      local REPLY
      if _ktt_lookup_override; then
        print -r -- "$REPLY"
      else
        print -r -- "no pinned title for $PWD"
      fi
      ;;
    *)
      _ktt_write_override "$*"
      print -n "\e]2;$*\a"
      ;;
  esac
}
