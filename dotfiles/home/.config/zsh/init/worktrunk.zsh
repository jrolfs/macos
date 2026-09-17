# Completion for the `wt restore <worktree-dir>` alias. wt's clap-generated
# completion asks the binary for candidates, so it knows nothing about alias
# arguments; this wrapper special-cases restore and delegates everything else.
#
# Registered from .zshrc's wt atload (not here): init files source before the
# wt shell init, and the later compdef wins at zicdreplay.

_wt_restore_candidates() {
  local -aU dirs
  dirs=(${(f)"$(command git for-each-ref --format='%(refname:strip=2)' 'refs/wip' 2>/dev/null)"})
  dirs+=(${(f)"$(command git ls-remote origin 'refs/wip/*' 2>/dev/null | sed 's|.*refs/wip/||')"})
  dirs=(${dirs:#})
  (( $#dirs )) && compadd -a dirs
}

_wt_with_restore() {
  if (( CURRENT == 3 )) && [[ ${words[2]} == restore ]]; then
    _wt_restore_candidates
  elif (( $+functions[_wt_lazy_complete] )); then
    _wt_lazy_complete "$@"
  fi
}
