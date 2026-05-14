require("hs.ipc")

local _ = require("modules.utilities")

_.bindHyper("h", function()
  hs.reload()
end)

_.bindHyper("c", require("modules.finder").copyPath)

require('modules.autohide').start({
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

local notifications = require("modules.notifications")
local notificationMode = hs.hotkey.modal.new({"ctrl", "alt", "cmd", "shift"}, "n")

notificationMode:bind({}, "n", function() notificationMode:exit(); notifications.activate() end)
notificationMode:bind({}, "d", function() notificationMode:exit(); notifications.details() end)
notificationMode:bind({}, "c", function() notificationMode:exit(); notifications.close() end)
notificationMode:bind({}, "escape", function() notificationMode:exit() end)

_.alert("🔨   Loaded Hammerspoon configuration")
