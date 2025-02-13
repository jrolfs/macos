local _ = require('modules.utilities')

local M = {}

local autoHideWatcher = nil
local appsToHide = {}
local lastHideTime = {}

local DEBOUNCE_INTERVAL = 1 -- Adjust this value (in seconds) as needed

local function shouldAutoHide(appName)
  if not appName then return false end

  local lowerAppName = string.lower(appName)

  -- Check if we've hidden this app recently
  local currentTime = hs.timer.secondsSinceEpoch()
  local lastTime = lastHideTime[lowerAppName]

  if lastTime and (currentTime - lastTime) < DEBOUNCE_INTERVAL then
    return false
  end

  for _, name in ipairs(appsToHide) do
    if string.lower(name) == lowerAppName then
      return true
    end
  end
  return false
end

local function hideApp(appName)
  local frontmost = hs.application.frontmostApplication()

  local script = string.format([[
        tell application "System Events"
            set visible of process "%s" to false
        end tell
    ]], appName)

  local ok, _ = hs.osascript.applescript(script)

  -- Record the hide time if successful
  if ok then
    lastHideTime[string.lower(appName)] = hs.timer.secondsSinceEpoch()
  end

  -- Ensure focus returns to the app we switched to
  if frontmost then
    frontmost:activate()
  end

  return ok
end

local function createWatcher()
  return hs.application.watcher.new(function(_, eventType, appObject)
    if eventType == hs.application.watcher.deactivated then
      if appObject and shouldAutoHide(appObject:name()) then
        -- Small delay to ensure the focus transition has completed
        hs.timer.doAfter(0.1, function()
          local success = hideApp(appObject:name())
          if not success then
            _.alert("Failed to hide " .. appObject:name())
          end
        end)
      end
    end
  end)
end

function M.start(apps)
  if autoHideWatcher then
    autoHideWatcher:stop()
  end

  appsToHide = apps or {}
  lastHideTime = {} -- Reset the hide times when starting

  autoHideWatcher = createWatcher()
  autoHideWatcher:start()
end

function M.stop()
  if autoHideWatcher then
    autoHideWatcher:stop()
    autoHideWatcher = nil
  end
  lastHideTime = {} -- Clear the hide times when stopping
end

function M.updateApps(apps)
  appsToHide = apps or {}
end

return M
