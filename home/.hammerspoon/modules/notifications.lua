local _ = require("modules.utilities")
local ax = require("hs.axuielement")

local M = {}

local function findNotificationAlert()
  for _, app in ipairs(hs.application.runningApplications()) do
    if app:name() == "Notification Center" then
      local appElement = ax.applicationElement(app)
      if not appElement then return nil end

      for _, win in ipairs(appElement:attributeValue("AXWindows") or {}) do
        local stack = { win }
        while #stack > 0 do
          local el = table.remove(stack)
          if el:attributeValue("AXSubrole") == "AXNotificationCenterAlert" then
            return el
          end
          for _, child in ipairs(el:attributeValue("AXChildren") or {}) do
            table.insert(stack, child)
          end
        end
      end
    end
  end

  return nil
end

local function performAction(actionName)
  local alert = findNotificationAlert()
  if not alert then
    _.alert("No notification found")
    return
  end

  for _, action in ipairs(alert:actionNames() or {}) do
    if action == actionName or action:find(actionName) then
      alert:performAction(action)
      return
    end
  end

  _.alert("Action not available: " .. actionName)
end

function M.activate()
  performAction("AXPress")
end

function M.details()
  performAction("Show Details")
end

function M.close()
  performAction("Close")
end

return M
