local _ = require("modules.utilities")

_.bindHyper("c", require("modules.finder").copyPath)

require('modules.autohide').start({
  "Dash",
  "Find My",
  "Music",
  "Sirius",
  "YouTube",
  "kitty",
})

_.bindHyper("h", function()
  hs.reload()
end)

local littleSnitch = require("modules.little-snitch")

_.bindHyper("l", littleSnitch.enableLittleSnitch)
_.bindHyper("o", littleSnitch.disableLittleSnitch)

_.alert("🔨   Loaded Hammerspoon configuration")
