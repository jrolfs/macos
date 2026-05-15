#!/usr/bin/env zsh

duet=$(git duet)

author=$(echo "$duet" | cut -d '=' -f 2 | tail -2 | head -1 | tr -d "'" | cut -d ' ' -f 1)
committer=$(echo "$duet" | cut -d '=' -f 2 | tail -4 | head -1 | tr -d "'" | cut -d ' ' -f 1)

echo "${author} ✕ ${committer}"
