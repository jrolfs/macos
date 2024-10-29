-- Common alert settings
local function alert(message, duration)
  local alpha = 0.8
  local styling = {
    strokeWidth = 0,
    fillColor = { hex = "#32302F", alpha = alpha },
    strokeColor = { hex = "#32302F", alpha = alpha },
    textColor = { hex = "#bdae93" },
    fadeInDuration = 0.15,
    fadeOutDuration = 0.15,
    radius = 10,
    padding = 20,
    atScreenEdge = 0,
    textFont = "IBM Plex Sans",
    textSize = 24,
    -- Hammerspoon uses NS* constants for font weight
    -- Common values: "thin", "regular", "medium", "bold", "heavy"
  }

  -- Default duration of 1 second if not specified
  duration = duration or 1

  hs.alert.show(message, styling, duration)
end

local hyper = { "ctrl", "alt", "cmd", "shift" }

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
    alert("Path copied to clipboard")
  else
    alert("Error copying path")
  end
end

hs.hotkey.bind(hyper, "C", copyFinderPath)

-- Apps to auto-hide when they lose focus
local autoHide = { "kitty" }

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
        alert("Failed to hide " .. appObject:name())
      end
    end
  end
end)

-- Start the application watcher
autoHideWatcher:start()

-- Reload Hammerspoon configuration
hs.hotkey.bind(hyper, "h", function()
  hs.reload()
end)

alert("🔨   Loaded Hammerspoon configuration")
