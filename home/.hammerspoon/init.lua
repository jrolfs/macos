local _ = require("modules.utilities")

_.bindHyper("c", require("modules.finder").copyPath)

require('modules.autohide').start({
  "kitty",
  "YouTube"
})

_.bindHyper("h", function()
  hs.reload()
end)

_.alert("🔨   Loaded Hammerspoon configuration")
