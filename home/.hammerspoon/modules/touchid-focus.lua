local M = {}

local watcher = nil

-- SecurityAgent shows the Touch ID / password prompt
local SECURITY_AGENT = "SecurityAgent"

-- How long after activation to keep re-focusing (seconds)
local GUARD_DURATION = 2
-- How often to check focus during the guard period
local GUARD_INTERVAL = 0.1

local guardTimer = nil

local function stopGuard()
  if guardTimer then
    guardTimer:stop()
    guardTimer = nil
  end
end

local function guardFocus(appObject)
  stopGuard()

  local expiry = hs.timer.secondsSinceEpoch() + GUARD_DURATION

  guardTimer = hs.timer.doEvery(GUARD_INTERVAL, function()
    if hs.timer.secondsSinceEpoch() > expiry then
      stopGuard()
      return
    end

    -- If SecurityAgent is still running but lost focus, bring it back
    if appObject and appObject:isRunning() then
      local frontmost = hs.application.frontmostApplication()
      if frontmost and frontmost:name() ~= SECURITY_AGENT then
        appObject:activate()
      end
    else
      stopGuard()
    end
  end)
end

function M.start()
  if watcher then
    watcher:stop()
  end

  watcher = hs.application.watcher.new(function(appName, eventType, appObject)
    if appName ~= SECURITY_AGENT then return end

    if eventType == hs.application.watcher.activated then
      guardFocus(appObject)
    elseif eventType == hs.application.watcher.deactivated then
      -- Lost focus — if still running, re-activate after a brief moment
      if appObject and appObject:isRunning() then
        hs.timer.doAfter(0.05, function()
          if appObject:isRunning() then
            appObject:activate()
          end
        end)
      end
    elseif eventType == hs.application.watcher.terminated then
      stopGuard()
    end
  end)

  watcher:start()
end

function M.stop()
  stopGuard()

  if watcher then
    watcher:stop()
    watcher = nil
  end
end

return M
