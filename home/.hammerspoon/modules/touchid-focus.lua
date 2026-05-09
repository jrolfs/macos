local _ = require('modules.utilities')

local M = {}

local SECURITY_AGENT = "SecurityAgent"

local watcher = nil

_.bindHyper("f12", function()
  local agent = hs.application.get(SECURITY_AGENT)

  if agent then
    agent:activate()
  end
end)

function M.start()
  if watcher then
    watcher:stop()
  end

  watcher = hs.application.watcher.new(function(appName, eventType, appObject)
    if appName ~= SECURITY_AGENT then return end

    if eventType == hs.application.watcher.launched then
      hs.timer.doAfter(0.1, function()
        if appObject and appObject:isRunning() then
          appObject:activate()
        end
      end)
    end
  end)

  watcher:start()
end

function M.stop()
  if watcher then
    watcher:stop()
    watcher = nil
  end
end

return M
