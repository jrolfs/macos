local _ = require("modules.utilities")
local ax = require("hs.axuielement")

local M = {}
M.toast = {}

local function findZed()
  return hs.application.find("dev.zed.Zed") or hs.application.find("Zed")
end

-- GPUI doesn't expose AX children, so we locate the toast window
-- (AXSystemDialog, 450x72) and click by coordinate offset.
local function findToast()
  local zed = findZed()
  if not zed then
    _.alert("Zed not running")
    return nil
  end

  local appElement = ax.applicationElement(zed)
  if not appElement then return nil end

  for _, win in ipairs(appElement:attributeValue("AXWindows") or {}) do
    if win:attributeValue("AXSubrole") == "AXSystemDialog" then
      return win, zed
    end
  end

  _.alert("No Zed toast found")
  return nil
end

local function clickToastOffset(offsetX, offsetY)
  local win, zed = findToast()
  if not win then return end

  local pos = win:attributeValue("AXPosition")
  local clickAt = hs.geometry.point(pos.x + offsetX, pos.y + offsetY)

  if not zed then
    _.alert("Unable to find Zed toast")
    return
  end

  zed:activate()

  hs.timer.doAfter(0.05, function()
    local prev = hs.mouse.absolutePosition()
    hs.eventtap.leftClick(clickAt, 20000)
    hs.mouse.absolutePosition(prev)
  end)
end

-- "View" button: upper-right area of 450x72 toast
function M.toast.view()
  clickToastOffset(415, 25)
end

-- "Dismiss" text: below "View" in the right area
function M.toast.dismiss()
  clickToastOffset(415, 52)
end

return M
