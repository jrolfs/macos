#!/usr/bin/env zsh

echo "\n\n\n$(date -u +"%Y-%m-%dT%H:%M:%SZ") / $(date)\n---------------------------------------------------" >> apply.log

# The app name is the icon's path relative to ./assets with the extension
# dropped, so the asset tree mirrors /Applications: "Slack.png" → Slack.app,
# "Maxon Cinema 4D 2026/Cinema 4D.icns" → "Maxon Cinema 4D 2026/Cinema 4D.app".
fd --type=f '\.(icns|png)$' ./assets --exec zsh -c '
  icon="$1"
  rel="${icon#./assets/}"; rel="${rel#assets/}"
  name="${rel%.*}"
  fileicon set "/Applications/$name.app" "$icon" &>> apply.log \
    && echo "✅ $(whoami)@$(id -gn) $name" \
    || echo "❌ $name"
' zsh {}

# sudo fd --type=f '\.(icns|png)$' ./assets/System --exec zsh -c '
#   icon="$1"
#   rel="${icon#./assets/System/}"; rel="${rel#assets/System/}"
#   name="${rel%.*}"
#   fileicon set "/System/Applications/$name.app" "$icon" &>> apply.log \
#     && echo "✅ $name" || echo "❌ $name"
# ' zsh {}
