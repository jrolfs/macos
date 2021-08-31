#!/usr/bin/env zsh

echo "\n\n\n$(date -u +"%Y-%m-%dT%H:%M:%SZ") / $(date)\n---------------------------------------------------" >> apply.log

fd --type=f '.*' ./assets --exec zsh -c 'fileicon set /Applications/$2.app $1 &>> apply.log && echo "✅ $2" || echo "❌ $2"' zsh {} {/.}

# sudo fd --type=f '.*' ./assets/System --exec zsh -c 'fileicon set /System/Applications/$2.app $1 &>> apply.log && echo "✅ $2" || echo "❌ $2"' zsh {} {/.}
