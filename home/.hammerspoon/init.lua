local _ = require("modules.utilities")

_.bindHyper("h", function()
  hs.reload()
end)

_.bindHyper("c", require("modules.finder").copyPath)

require('modules.autohide').start({
  "Dash",
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

local littleSnitch = require("modules.little-snitch")

_.bindHyper("l", littleSnitch.enableLittleSnitch)
_.bindHyper("o", littleSnitch.disableLittleSnitch)

_.alert("🔨   Loaded Hammerspoon configuration")
