#!/usr/bin/env zsh

local repository_root
repository_root="$(git rev-parse --show-toplevel 2>/dev/null)"

if [[ -n "$repository_root" ]]; then
  local repository_name="${repository_root##*/}"
  local subdirectory="${PWD#"$repository_root"}"

  # Strip worktree suffix (e.g. frontends.jamie-some-branch → frontends)
  if [[ "$repository_name" == *.* ]] && [[ -d "${repository_root:h}/${repository_name%%.*}/.git" ]]; then
    repository_name="${repository_name%%.*}"
  fi

  directory="…/${repository_name}${subdirectory}"
else
  directory="${PWD/#$HOME/~}"
  parts=("${(@s:/:)directory}")
  if (( ${#parts} > 3 )); then
    directory="…/${(j:/:)parts[-3,-1]}"
  fi
fi

[[ ! -w "$PWD" ]] && directory="$directory "
printf '%s' "$directory"
