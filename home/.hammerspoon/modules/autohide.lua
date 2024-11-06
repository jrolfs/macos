local _ = require('modules.utilities')

local M = {}

local autoHideWatcher = nil
local appsToHide = {}

local function shouldAutoHide(appName)
  if not appName then return false end

  local lowerAppName = string.lower(appName)

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

  -- Ensure focus returns to the app we switched to
  if frontmost then
    frontmost:activate()
  end

  return ok
end

-- Create the watcher
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

-- Public functions remain the same
function M.start(apps)
  if autoHideWatcher then
    autoHideWatcher:stop()
  end

  appsToHide = apps or {}

  autoHideWatcher = createWatcher()
  autoHideWatcher:start()
end

function M.stop()
  if autoHideWatcher then
    autoHideWatcher:stop()
    autoHideWatcher = nil
  end
end

function M.updateApps(apps)
  appsToHide = apps or {}
end

return M
