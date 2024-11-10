local u = require("modules.utilities")

local M = {}

local function silenceLittleSnitch(silence)
  local command = string.format(
    "sudo /Applications/Little\\ Snitch.app/Contents/Components/littlesnitch write-preference activeSilentMode %d",
    silence and 1 or 0
  )

  local success, _, rawOutput = hs.execute(command)

  if not success then
    u.alert(string.format("Failed to %s Little Snitch alerting: %s",
      silence and "silence" or "restore",
      rawOutput or "unknown error"))
  end
  return success
end

function M.enableLittleSnitch()
  silenceLittleSnitch(false)
end

function M.disableLittleSnitch()
  silenceLittleSnitch(true)
end

-- Create a caffeinate watcher for session changes
-- local caffeinateWatcher = hs.caffeinate.watcher.new(function(eventType)
--   local currentUser = hs.host.consoleUser()

--   if eventType == hs.caffeinate.watcher.sessionDidBecomeActive or
--       eventType == hs.caffeinate.watcher.screensDidUnlock then
--     if currentUser == "jocelyn" then
--       controlLittleSnitch(false)       -- Set to silent mode
--     elseif currentUser == "jamie" then
--       controlLittleSnitch(true)        -- Set to normal mode
--     end
--   end
-- end)

-- caffeinateWatcher:start()

return M
