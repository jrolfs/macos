local _ = require("modules.utilities")
local ax = require("hs.axuielement")

local M = {}

local highlight = nil
local alerts = {}
local currentIndex = 0
local closeWatcher = nil

local navMode = nil

local SUBROLE_ALERT = "AXNotificationCenterAlert"
local SUBROLE_BANNER = "AXNotificationCenterBanner"
local SUBROLE_STACK = "AXNotificationCenterBannerStack"

local HIGHLIGHT_INSET = 0
local HIGHLIGHT_COLOR = { hex = "#5a524c", alpha = 0.35 }
local HIGHLIGHT_WIDTH = 4
local HIGHLIGHT_RADIUS = 22

-- Notification Center access

local function getNotificationCenterApp()
  for _, app in ipairs(hs.application.runningApplications()) do
    if app:name() == "Notification Center" then
      return app
    end
  end
  return nil
end

local function isNotificationCenterVisible()
  local app = getNotificationCenterApp()
  if not app then return false end
  local el = ax.applicationElement(app)
  if not el then return false end
  for _, win in ipairs(el:attributeValue("AXWindows") or {}) do
    if win:attributeValue("AXSubrole") == "AXSystemDialog" then
      return true
    end
  end
  return false
end

-- Finding notifications

local function isNotificationElement(el)
  local sub = el:attributeValue("AXSubrole")
  return sub == SUBROLE_ALERT or sub == SUBROLE_BANNER or sub == SUBROLE_STACK
end

local function findAllAlerts()
  local results = {}
  local app = getNotificationCenterApp()
  if not app then return results end

  local appElement = ax.applicationElement(app)
  if not appElement then return results end

  for _, win in ipairs(appElement:attributeValue("AXWindows") or {}) do
    local stack = { win }
    while #stack > 0 do
      local el = table.remove(stack)
      if isNotificationElement(el) then
        table.insert(results, el)
      else
        for _, child in ipairs(el:attributeValue("AXChildren") or {}) do
          table.insert(stack, child)
        end
      end
    end
  end

  return results
end

local function performActionOnElement(element, actionName)
  if not element then
    _.alert("No notification found")
    return
  end

  for _, action in ipairs(element:actionNames() or {}) do
    if action == actionName or action:find(actionName) then
      element:performAction(action)
      return
    end
  end

  _.alert("Action not available: " .. actionName)
end

-- Highlight

local function clearHighlight()
  if highlight then
    highlight:delete()
    highlight = nil
  end
end

local function drawHighlight(frame)
  clearHighlight()
  if not frame then return end

  local outer = HIGHLIGHT_INSET + HIGHLIGHT_WIDTH

  highlight = hs.canvas.new({
    x = frame.x - outer,
    y = frame.y - outer,
    w = frame.w + outer * 2,
    h = frame.h + outer * 2,
  })

  if not highlight then
    _.alert("Unable to create notification highlight")
    return
  end

  highlight:appendElements(
    {
      type = "rectangle",
      action = "fill",
      fillColor = HIGHLIGHT_COLOR,
      roundedRectRadii = { xRadius = HIGHLIGHT_RADIUS + HIGHLIGHT_WIDTH, yRadius = HIGHLIGHT_RADIUS + HIGHLIGHT_WIDTH },
    },
    {
      type = "rectangle",
      action = "fill",
      fillColor = { red = 0, green = 0, blue = 0, alpha = 1 },
      compositeRule = "destinationOut",
      frame = {
        x = HIGHLIGHT_WIDTH,
        y = HIGHLIGHT_WIDTH,
        w = frame.w + HIGHLIGHT_INSET * 2,
        h = frame.h + HIGHLIGHT_INSET * 2,
      },
      roundedRectRadii = { xRadius = HIGHLIGHT_RADIUS, yRadius = HIGHLIGHT_RADIUS },
    }
  )

  highlight:level(hs.canvas.windowLevels.overlay)
  highlight:show()
end

local function highlightCurrent()
  local alert = alerts[currentIndex]
  if not alert then
    clearHighlight()
    return
  end

  local frame = alert:attributeValue("AXFrame")
  if frame then
    drawHighlight(frame)
  end
end

-- Close watcher

local function stopCloseWatcher()
  if closeWatcher then
    closeWatcher:stop()
    closeWatcher = nil
  end
end

local function exitNavigation()
  stopCloseWatcher()
  clearHighlight()
  alerts = {}
  currentIndex = 0
end

local function startCloseWatcher()
  stopCloseWatcher()
  closeWatcher = hs.timer.doEvery(0.25, function()
    if not isNotificationCenterVisible() then
      exitNavigation()
      if navMode then navMode:exit() end
    end
  end)
end

-- Navigation actions

local function refreshAlerts()
  alerts = findAllAlerts()
  if #alerts > 0 then
    currentIndex = math.min(currentIndex, #alerts)
    if currentIndex == 0 then currentIndex = 1 end
    highlightCurrent()
  else
    currentIndex = 0
    clearHighlight()
    _.alert("No notifications")
  end
end

-- Toast actions (act on first visible banner)

local function toastActivate()
  performActionOnElement(findAllAlerts()[1], "AXPress")
end

local function toastDetails()
  performActionOnElement(findAllAlerts()[1], "Show Details")
end

local function toastClose()
  local el = findAllAlerts()[1]
  if not el then
    _.alert("No notification found")
    return
  end

  for _, action in ipairs(el:actionNames() or {}) do
    if action:find("Close") or action:find("Clear All") then
      el:performAction(action)
      return
    end
  end

  _.alert("No close action available")
end

-- Navigation actions (act on highlighted notification)

local function navActivate()
  local el = alerts[currentIndex]
  if not el then
    _.alert("No notification found")
    return
  end

  local isStack = el:attributeValue("AXSubrole") == SUBROLE_STACK
  performActionOnElement(el, "AXPress")

  if isStack then
    hs.timer.doAfter(0.05, refreshAlerts)
  else
    navMode:exit()
    exitNavigation()
  end
end

local function navDetails()
  local el = alerts[currentIndex]
  if not el then
    _.alert("No notification found")
    return
  end

  performActionOnElement(el, "Show Details")
  hs.timer.doAfter(0.3, refreshAlerts)
end

local function navClose()
  local fresh = findAllAlerts()[currentIndex]
  if not fresh then
    _.alert("No notification found")
    return
  end

  for _, action in ipairs(fresh:actionNames() or {}) do
    if action:find("Close") or action:find("Clear All") then
      fresh:performAction(action)
      hs.timer.doAfter(0.3, refreshAlerts)
      return
    end
  end

  _.alert("No close action available")
end

local function navNext()
  if #alerts == 0 then return end
  currentIndex = currentIndex % #alerts + 1
  highlightCurrent()
end

local function navPrevious()
  if #alerts == 0 then return end
  currentIndex = (currentIndex - 2) % #alerts + 1
  highlightCurrent()
end

-- Public API

function M.bind(keys)
  local leaderMods, leaderKey = keys.leader[1], keys.leader[2]

  navMode = hs.hotkey.modal.new()

  hs.hotkey.bind(leaderMods, leaderKey, function()
    if isNotificationCenterVisible() then
      refreshAlerts()
      startCloseWatcher()
      navMode:enter()
    else
      local found = findAllAlerts()
      if #found == 0 then return end

      -- Toast mode: bind keys, auto-exit after action or timeout
      local toast = hs.hotkey.modal.new()

      local function done()
        toast:exit()
        toast:delete()
      end

      if keys.activate then
        toast:bind({}, keys.activate, function() done(); toastActivate() end)
      end
      if keys.details then
        toast:bind({}, keys.details, function() done(); toastDetails() end)
      end
      if keys.close then
        toast:bind({}, keys.close, function() done(); toastClose() end)
      end
      toast:bind({}, "escape", done)

      toast:enter()
      hs.timer.doAfter(2, function()
        pcall(done)
      end)
    end
  end)

  -- Navigation mode bindings
  if keys.next then navMode:bind({}, keys.next, navNext) end
  if keys.previous then navMode:bind({}, keys.previous, navPrevious) end
  if keys.activate then navMode:bind({}, keys.activate, navActivate) end
  if keys.details then navMode:bind({}, keys.details, navDetails) end
  if keys.close then navMode:bind({}, keys.close, navClose) end
  navMode:bind({}, "escape", function()
    navMode:exit()
    exitNavigation()
  end)
end

return M
