local _ = require("modules.utilities")

_.bindHyper("h", function()
  hs.reload()
end)

_.bindHyper("c", require("modules.finder").copyPath)

require('modules.autohide').start({
  "Dash",
  "Discord",
  "Find My",
  "Music",
  "Obsidian",
  "Sirius",
  "Spotify",
  "YouTube",
  "iPhone Mirroring",
  "kitty",
})

require('modules.raycast-focus').start();

_.alert("🔨   Loaded Hammerspoon configuration")
