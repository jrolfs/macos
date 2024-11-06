local _ = require('modules.utilities')


-- Function to copy the current Finder directory path to clipboard
local function copyFinderPath()
  local script = [[
    tell application "Finder"
      if front window exists then
        set finderPath to (quoted form of POSIX path of (target of front window as alias))
        return finderPath
      else
        return ""
      end if
    end tell
  ]]
  local ok, finderPath = hs.osascript.applescript(script)
  if ok then
    hs.pasteboard.setContents(finderPath)
    _.alert("Path copied to clipboard")
  else
    _.alert("Error copying path")
  end
end

_.bindHyper("C", copyFinderPath)

-- Apps to auto-hide when they lose focus
local autoHide = { "kitty", "YouTube" }

local function shouldAutoHide(appName)
  if not appName then return false end

  local lowerAppName = string.lower(appName)

  for _, name in ipairs(autoHide) do
    if string.lower(name) == lowerAppName then
      return true
    end
  end
  return false
end

-- Hide application using System Events
local function hideApp(appName)
  local script = string.format([[
        tell application "System Events"
            set visible of process "%s" to false
        end tell
    ]], appName)

  local ok, _ = hs.osascript.applescript(script)

  return ok
end

-- Application watcher
local autoHideWatcher = hs.application.watcher.new(function(_, eventType, appObject)
  if eventType == hs.application.watcher.deactivated then
    if appObject and shouldAutoHide(appObject:name()) then
      local success = hideApp(appObject:name())
      if not success then
        _.alert("Failed to hide " .. appObject:name())
      end
    end
  end
end)

-- Start the application watcher
autoHideWatcher:start()

-- Reload Hammerspoon configuration
_.bindHyper("h", function()
  hs.reload()
end)

_.alert("🔨   Loaded Hammerspoon configuration")
