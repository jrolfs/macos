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
  "Music",
  "Obsidian",
  "Photos",
  "Sirius",
  "Spotify",
  "Yaak",
  "YouTube",
  "iPhone Mirroring",
  "kitty",
})

_.alert("🔨   Loaded Hammerspoon configuration")
