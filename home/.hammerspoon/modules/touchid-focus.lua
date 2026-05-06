local M = {}

local watcher = nil

-- SecurityAgent shows the Touch ID / password prompt
local SECURITY_AGENT = "SecurityAgent"

local activatedAt = nil
local refocusTimer = nil

-- Only refocus if SecurityAgent loses focus within this window of first appearing
local REFOCUS_WINDOW = 0.4

local function cancelRefocus()
  if refocusTimer then
    refocusTimer:stop()
    refocusTimer = nil
  end
end

function M.start()
  if watcher then
    watcher:stop()
  end

  watcher = hs.application.watcher.new(function(appName, eventType, appObject)
    if appName ~= SECURITY_AGENT then return end

    if eventType == hs.application.watcher.activated then
      activatedAt = hs.timer.secondsSinceEpoch()
    elseif eventType == hs.application.watcher.deactivated then
      cancelRefocus()

      -- Only refocus if it lost focus suspiciously fast after appearing
      if activatedAt and appObject and appObject:isRunning() then
        local elapsed = hs.timer.secondsSinceEpoch() - activatedAt

        if elapsed < REFOCUS_WINDOW then
          refocusTimer = hs.timer.doAfter(0.05, function()
            refocusTimer = nil
            if appObject:isRunning() then
              appObject:activate()
            end
          end)
        end
      end
    elseif eventType == hs.application.watcher.terminated then
      cancelRefocus()
      activatedAt = nil
    end
  end)

  watcher:start()
end

function M.stop()
  cancelRefocus()
  activatedAt = nil

  if watcher then
    watcher:stop()
    watcher = nil
  end
end

return M
