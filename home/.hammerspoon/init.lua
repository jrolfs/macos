local _ = require("modules.utilities")

_.bindHyper("h", function()
  hs.reload()
end)

_.bindHyper("c", require("modules.finder").copyPath)

require('modules.autohide').start({
  "1Password",
  "Dash",
  "Discord",
  "Find My",
  "Linear",
  "Maps",
  "Music",
  "Obsidian",
  "Photos",
  "Reminders",
  "Resilio Sync",
  "Sirius",
  "Spotify",
  "Yaak",
  "YouTube",
  "iPhone Mirroring",
  "kitty",
})

require('modules.touchid-focus').start()

_.alert("🔨   Loaded Hammerspoon configuration")
