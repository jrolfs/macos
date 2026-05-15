#!/usr/bin/env bash

duet=$(git duet)

if [ $? -gt 0 ]; then
  exit 1
fi

author=$(echo "$duet" | cut -d '=' -f 2 | tail -1)
committer=$(echo "$duet" | cut -d '=' -f 2 | tail -3 | head -1)

echo "author: $author / committer: $committer"

if [[ "$author" == "$committer" ]]; then
  exit 1
else
  exit 0
fi
