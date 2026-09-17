# Project-aware tab titles for kitty
[[ -n "$KITTY_INSTALLATION_DIR" ]] || return 0

typeset -g _ktt_icon=""
typeset -g _ktt_cached_dir=""

# Central store for manually-pinned titles, keyed by absolute directory path.
# Persists across restarts and lives outside any repo (no gitignore needed).
typeset -g _ktt_override_file="${XDG_STATE_HOME:-$HOME/.local/state}/kitty/tab-titles"

# Look up the pinned title covering $PWD, preferring the deepest pinned ancestor
# so a pin follows you into a project's subdirectories. Comparing against
# "$dir"/* rather than a bare prefix keeps sibling worktrees distinct: a pin on
# frontends must not leak into frontends.jamie-some-branch.
# Sets REPLY to the title and REPLY_DIR to the directory it is keyed under (which
# may be an ancestor of $PWD), returns 0 on hit, else 1.
_ktt_lookup_override() {
  REPLY=""
  REPLY_DIR=""
  [[ -f "$_ktt_override_file" ]] || return 1
  local dir title
  while IFS=$'\t' read -r dir title || [[ -n "$dir" ]]; do
    [[ -n "$dir" ]] || continue
    [[ "$PWD" == "$dir" || "$PWD" == "$dir"/* ]] || continue
    (( ${#dir} > ${#REPLY_DIR} )) || continue
    REPLY_DIR="$dir"
    REPLY="$title"
  done < "$_ktt_override_file"
  [[ -n "$REPLY_DIR" ]]
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

# OSC 2 only sets the *window* title, and kitty refuses to derive a tab's title
# from its window once that tab's title has been set explicitly — which every
# session-file `new_tab <title>` line and every use of the set_tab_title action
# does (it shows up as `title_overridden` in `kitty @ ls`). Reaching the tab bar
# in those tabs requires remote control. An empty title clears the override and
# hands the tab back to tracking its active window.
#
# Whether *this* shell is the one currently holding the tab's title. Only used to
# decide if we're entitled to hand the tab back; never to skip a push, because
# the title is tab-wide state that a sibling window, the set_tab_title action or
# a session reload can change behind our back.
typeset -g _ktt_owns_tab_title=0

# kitty's remote control protocol is also reachable over the tty as a DCS escape
# sequence, which costs nothing to emit — no fork, no round trip, unlike `kitty @`
# which spawns a kitten and waits ~80ms. Cheap enough to re-assert every prompt.
# Silently does nothing if allow_remote_control is off.
_ktt_push_tab_title() {
  local title="${1//[[:cntrl:]]/}"
  title="${title//\\/\\\\}"
  title="${title//\"/\\\"}"
  printf '\eP@kitty-cmd{"cmd":"set-tab-title","version":[0,14,2],"no_response":true,"payload":{"title":"%s"}}\e\\' "$title"
}

# Slow, but it reports failure, so the interactive path uses it to surface a
# kitty that won't accept remote control at all.
_ktt_push_tab_title_verbose() {
  (( $+commands[kitty] )) || return 1
  kitty @ set-tab-title -- "$1" >/dev/null 2>&1
}

_ktt_set_title() {
  # A pinned title for this directory wins over the automatic one.
  local REPLY REPLY_DIR
  if _ktt_lookup_override; then
    print -n "\e]2;${REPLY}\a"
    _ktt_push_tab_title "$REPLY"
    _ktt_owns_tab_title=1
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

  # Only relinquish a tab this shell is currently holding, so tabs titled by a
  # session file keep that title until something pins over them.
  if (( _ktt_owns_tab_title )); then
    _ktt_push_tab_title ""
    _ktt_owns_tab_title=0
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _ktt_set_title

# Rewrite the store, dropping any existing entry for directory $1. If $2 is
# non-empty it is appended as the new title for $1.
_ktt_write_override() {
  local target="$1" title="$2" tab=$'\t' tmp dir t
  mkdir -p -- "${_ktt_override_file:h}"
  tmp="${_ktt_override_file}.tmp.$$"
  : > "$tmp"
  if [[ -f "$_ktt_override_file" ]]; then
    while IFS=$'\t' read -r dir t || [[ -n "$dir" ]]; do
      [[ "$dir" == "$target" ]] && continue
      print -r -- "${dir}${tab}${t}"
    done < "$_ktt_override_file" >> "$tmp"
  fi
  [[ -n "$title" ]] && print -r -- "${target}${tab}${title}" >> "$tmp"
  mv -- "$tmp" "$_ktt_override_file"
}

# Pin a custom kitty tab title for the current directory. Persisted centrally,
# keyed by absolute path, applies to subdirectories too, and overrides the
# automatic project-aware title.
#
#   tab-title Deploy prod   # pin a title for $PWD (quotes optional)
#   tab-title               # show the pinned title in effect here, if any
#   tab-title -c            # clear the pinned title in effect here
tab-title() {
  local REPLY REPLY_DIR
  case "$1" in
    -c | --clear)
      if ! _ktt_lookup_override; then
        print -u2 -r -- "tab-title: no pinned title in effect for $PWD"
        return 1
      fi
      # The pin in effect may be keyed to an ancestor, so say what was removed
      # rather than silently touching a directory the caller did not name.
      _ktt_write_override "$REPLY_DIR" ""
      print -r -- "tab-title: cleared pin for $REPLY_DIR"
      _ktt_cached_dir=""   # force the auto title to recompute
      # _ktt_set_title now either falls back to a shallower pinned ancestor or,
      # since this shell was holding the title it just deleted, hands the tab back.
      _ktt_set_title
      ;;
    "")
      if ! _ktt_lookup_override; then
        print -r -- "no pinned title for $PWD"
        return 1
      fi
      print -r -- "$REPLY"
      [[ "$REPLY_DIR" == "$PWD" ]] || print -r -- "(inherited from $REPLY_DIR)"
      ;;
    *)
      _ktt_write_override "$PWD" "$*"
      print -n "\e]2;$*\a"
      _ktt_owns_tab_title=1
      _ktt_push_tab_title_verbose "$*" ||
        print -u2 -r -- "tab-title: pinned for $PWD, but kitty remote control failed — tab bar not updated"
      ;;
  esac
}
