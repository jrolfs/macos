eval "$(mise activate zsh)"

# Disable mise in directories with Nix environments
local -a __mise_nix_markers=(
  flake.nix
  devbox.json
  devenv.nix
)

__mise_in_nix_dir() {
  local directory=$PWD marker

  while [[ $directory != "/" ]]; do
    for marker in $__mise_nix_markers; do
      [[ -f "$directory/$marker" ]] && return 0
    done

    [[ -d "$directory/.git" ]] && break

    directory=${directory:h}
  done

  return 1
}

# Wrap mise's hooks to no-op in nix/devbox/devenv directories
functions[__mise_hook_precmd_orig]=$functions[_mise_hook_precmd]
functions[__mise_hook_chpwd_orig]=$functions[_mise_hook_chpwd]

_mise_hook_precmd() {
  __mise_in_nix_dir || __mise_hook_precmd_orig
}

_mise_hook_chpwd() {
  __mise_in_nix_dir || __mise_hook_chpwd_orig
}
