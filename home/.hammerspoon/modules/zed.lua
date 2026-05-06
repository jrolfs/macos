local _ = require("modules.utilities")
local ax = require("hs.axuielement")

local M = {}
M.toast = {}

local function findZed()
  return hs.application.find("dev.zed.Zed") or hs.application.find("Zed")
end

local function findButton(element, titlePattern, depth)
  if depth > 10 or not element then return nil end

  local role = element:attributeValue("AXRole")
  if role == "AXButton" then
    local title = element:attributeValue("AXTitle")
                  or element:attributeValue("AXDescription")
                  or ""
    if title:find(titlePattern) then return element end
  end

  for _, child in ipairs(element:attributeValue("AXChildren") or {}) do
    local hit = findButton(child, titlePattern, depth + 1)
    if hit then return hit end
  end

  return nil
end

local function pressToastButton(titlePattern, label)
  local zed = findZed()
  if not zed then
    _.alert("Zed not running")
    return
  end

  local appElement = ax.applicationElement(zed)
  if not appElement then
    zed:activate()
    return
  end

  for _, win in ipairs(appElement:attributeValue("AXWindows") or {}) do
    local btn = findButton(win, titlePattern, 0)
    if btn then
      zed:activate()
      btn:performAction("AXPress")
      return
    end
  end

  _.alert("No Zed toast found")
end

function M.toast.view()
  pressToastButton("View", "View")
end

function M.toast.dismiss()
  pressToastButton("Dismiss", "Dismiss")
end

return M
