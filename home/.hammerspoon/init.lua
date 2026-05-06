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
  "Plexamp",
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

local zed = require('modules.zed')

_.bindHyper("z", zed.toast.view)
_.bindHyper("x", zed.toast.dismiss)

_.alert("🔨   Loaded Hammerspoon configuration")
