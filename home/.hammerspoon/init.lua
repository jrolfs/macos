require("hs.ipc")

local _ = require("modules.utilities")

_.bindHyper("h", function()
  hs.reload()
end)

_.bindHyper("c", require("modules.finder").copyPath)

local autohide = require('modules.autohide')

autohide.start({
  "1Password",
  "Dash",
  "DevDocs",
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
  -- { name = "Spotify", when = autohide.maxDisplays(1) },
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

require("modules.notifications").bind({
  leader = { {"ctrl", "alt", "cmd", "shift"}, "n" },
  activate = "return",
  details = "d",
  close = "c",
  next = "k",
  previous = "j",
})

_.alert("🔨   Loaded Hammerspoon configuration")
