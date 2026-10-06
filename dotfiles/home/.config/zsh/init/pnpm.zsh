# Completion for pnpm and the `n` alias, merged from two sources because
# neither is sufficient alone.
#
# pnpm's own completion (`pnpm completion zsh`) asks the binary for candidates,
# so it tracks every subcommand and flag of whichever pnpm release is on $PATH,
# but it returns nothing for the scripts in package.json. pnpm-shell-completion
# knows the scripts, the workspace filters and the installed dependencies, and
# reads package.json itself rather than shelling out, so it still answers when
# pnpm is absent — the usual case here, since pnpm comes from a project's
# nix/devenv shell rather than the system. Querying both is what makes
# `pnpm <TAB>` offer `dlx` and `build` at the same time.
#
# Registered from .zshrc's zicompinit block (not here): compdef does not exist
# until compinit has run, and registering after zicdreplay lets this win over
# the `_pnpm` that pnpm-shell-completion puts in an earlier $fpath entry.

_pnpm_candidates() {
  local feature=$1 description=$2 target=$3
  local -a found

  (( $+commands[pnpm-shell-completion] )) || return 1

  found=(${(f)"$(FEATURE=$feature TARGET_PKG=$target ZSH=true pnpm-shell-completion 2>/dev/null)"})
  found=(${found:#})
  (( $#found )) || return 1

  _describe -t $feature $description found
}

_pnpm_with_scripts() {
  local -a subcommands
  local subcommand target_package
  local -i index

  # Neither the subcommand nor --filter's value sits at a fixed index: pnpm
  # takes its global flags before the subcommand and several of those carry a
  # value. `pnpm -F web run build` still has to see `run` as the subcommand and
  # resolve the scripts against `web` rather than the current directory.
  for (( index = 2; index < CURRENT; index++ )); do
    case ${words[index]} in
      (--filter=*) target_package=${words[index]#--filter=} ;;
      (--filter|-F) target_package=${words[index + 1]}; (( index++ )) ;;
      (--dir|-C|--store-dir|--state-dir|--registry) (( index++ )) ;;
      (-*) ;;
      (*) [[ -n $subcommand ]] || subcommand=${words[index]} ;;
    esac
  done

  # The argument to --filter is a workspace package, never a subcommand, so
  # this answers on its own. pnpm's own completion offers the whole subcommand
  # list in this position, which is just noise.
  if [[ ${words[CURRENT]} == --filter=* ]]; then
    compset -P '--filter='
    _pnpm_candidates filter 'workspace package' "$target_package"
    return
  elif [[ ${words[CURRENT - 1]} == (--filter|-F) ]]; then
    _pnpm_candidates filter 'workspace package' "$target_package"
    return
  fi

  # Silent when pnpm is off $PATH, which leaves the candidates below as the
  # whole answer rather than failing the completion outright.
  if (( $+commands[pnpm] )); then
    subcommands=(${(f)"$(
      COMP_CWORD=$(( CURRENT - 1 )) COMP_LINE="$BUFFER" COMP_POINT="$CURSOR" SHELL=zsh \
        pnpm completion-server -- "${words[@]}" 2>/dev/null
    )"})
    (( $#subcommands )) && _describe -t commands 'pnpm command' subcommands
  fi

  case $subcommand in
    (remove|rm|uninstall|un|why|update|up|upgrade)
      _pnpm_candidates deps dependency "$target_package"
      ;;
    (run|exec|test)
      _pnpm_candidates scripts script "$target_package"
      ;;
    ('')
      # `pnpm build` is shorthand for `pnpm run build`, so scripts belong
      # alongside the subcommands in the first position too.
      _pnpm_candidates scripts script "$target_package"
      ;;
  esac
}
