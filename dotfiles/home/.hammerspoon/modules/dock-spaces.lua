-- Re-applies a Dock tile's "Assign To → All Desktops" when an application's
-- windows are not on all desktops.
--
-- macOS applies that assignment to the windows an application has at the moment
-- the menu item is chosen, and never replays it onto windows created later.
-- com.apple.spaces holds `app-bindings` keyed by bundle identifier, but that is
-- a record of the choice rather than an instruction to the window server:
-- writing it changes what the menu displays and nothing else. So every relaunch
-- comes up with windows that are not on all desktops while the menu still
-- claims they are.
--
-- Measured, with two kitty windows at once: the window that existed when the
-- menu was used reported four spaces, one created a moment later reported one.
--
-- Driving the menu is the only thing that works. Nothing can set a window's
-- collection behaviour from outside the application that owns it: hs.window has
-- no method for spaces, stickiness or collection behaviour.
--
-- Opening the menu is a visible UI action that takes focus for about two
-- seconds, so it only happens when a window is actually on fewer desktops than
-- exist. Checking that first is free and read-only, and it means a launch that
-- already came up correct costs nothing.

local M = {}

-- Timers are held here rather than as locals so they are not collected before
-- they fire.
local timers = {}
local watcher = nil
local windows = nil
local lastFlip = {}
local watching = {}

local MENU_SETTLE = 0.6
local BETWEEN_PASSES = 0.8

-- A relaunched application has no window for a moment, and one that restores a
-- session can take several seconds. Flipping before a window exists applies the
-- assignment to nothing, which is the failure this polling replaces: a fixed
-- delay after launch was too short for kitty restoring its tabs.
local SETTLE = 1.0
local ATTEMPTS = 20

-- Opening the menu twice over the same launch is worse than useless, since the
-- second pass fights the first.
local QUIET_PERIOD = 8

local function tile(appTitle)
  local dock = hs.application.find('Dock')
  if not dock then return nil end

  local ax = hs.axuielement.applicationElement(dock)
  if not ax then return nil end

  for _, child in ipairs(ax:attributeValue('AXChildren') or {}) do
    if child:attributeValue('AXRole') == 'AXList' then
      for _, item in ipairs(child:attributeValue('AXChildren') or {}) do
        if item:attributeValue('AXTitle') == appTitle then return item end
      end
    end
  end
end

-- "All Desktops", "This Desktop" and "None" are siblings under Options, below
-- an "Assign To" item that is a heading rather than a submenu.
local function pressUnderOptions(item, label)
  for _, menu in ipairs(item:attributeValue('AXChildren') or {}) do
    for _, entry in ipairs(menu:attributeValue('AXChildren') or {}) do
      if entry:attributeValue('AXTitle') == 'Options' then
        for _, submenu in ipairs(entry:attributeValue('AXChildren') or {}) do
          for _, option in ipairs(submenu:attributeValue('AXChildren') or {}) do
            if option:attributeValue('AXTitle') == label then
              option:performAction('AXPress')
              return true
            end
          end
        end
      end
    end
  end
  return false
end

local function userSpaces()
  local ids = {}
  for _, spaces in pairs(hs.spaces.allSpaces() or {}) do
    for _, id in ipairs(spaces) do
      if hs.spaces.spaceType(id) == 'user' then ids[#ids + 1] = id end
    end
  end
  return ids
end

-- How many of `spaces` contain this window. A window on all desktops is in all
-- of them; an ordinary one is in exactly one.
local function spread(win, spaces)
  local n = 0
  for _, id in ipairs(spaces) do
    for _, wid in ipairs(hs.spaces.windowsForSpace(id) or {}) do
      if wid == win:id() then n = n + 1 break end
    end
  end
  return n
end

-- nil when there is nothing to judge yet, which is the signal to wait rather
-- than to give up: an application mid-launch has no windows.
local function needsFlip(appTitle)
  local app = hs.application.get(appTitle)
  if not app then return nil end

  local spaces = userSpaces()
  if #spaces < 2 then return false end

  local judged = false
  for _, win in ipairs(app:allWindows()) do
    if win:isStandard() then
      judged = true
      if spread(win, spaces) < #spaces then return true end
    end
  end

  if not judged then return nil end
  return false
end

-- Both passes are needed. The menu still shows All Desktops ticked, since the
-- preference survived the relaunch, so choosing it again is a no-op; only the
-- transition re-applies the assignment to the windows that exist now.
local function flip(appTitle, done)
  local item = tile(appTitle)
  if not item then
    if done then done(false, 'no dock tile') end
    return
  end

  lastFlip[appTitle] = hs.timer.secondsSinceEpoch()
  item:performAction('AXShowMenu')

  timers[appTitle .. '-none'] = hs.timer.doAfter(MENU_SETTLE, function()
    local cleared = pressUnderOptions(item, 'None')

    timers[appTitle .. '-wait'] = hs.timer.doAfter(BETWEEN_PASSES, function()
      local again = tile(appTitle)
      if not again then
        if done then done(false, 'dock tile went away') end
        return
      end

      again:performAction('AXShowMenu')

      timers[appTitle .. '-all'] = hs.timer.doAfter(MENU_SETTLE, function()
        local assigned = pressUnderOptions(again, 'All Desktops')
        if done then
          done(cleared and assigned, 'none=' .. tostring(cleared) .. ' all=' .. tostring(assigned))
        end
      end)
    end)
  end)
end

M.flip = flip

local function settle(appTitle, attempt, done)
  local verdict = needsFlip(appTitle)

  if verdict == nil then
    if attempt >= ATTEMPTS then
      if done then done(false, 'no windows appeared') end
      return
    end
    timers[appTitle .. '-settle'] = hs.timer.doAfter(SETTLE, function()
      settle(appTitle, attempt + 1, done)
    end)
    return
  end

  if not verdict then
    if done then done(true, 'already on all desktops') end
    return
  end

  local last = lastFlip[appTitle]
  if last and (hs.timer.secondsSinceEpoch() - last) < QUIET_PERIOD then
    if done then done(false, 'too soon after the last flip') end
    return
  end

  flip(appTitle, done)
end

-- Exposed so it can be driven by hand, and so a flip can be asked for without
-- waiting for an application to relaunch.
function M.check(appTitle, done)
  settle(appTitle, 0, done)
end

-- `apps` is a list of application names as the Dock labels them, which is also
-- what hs.application.watcher reports.
function M.start(apps)
  M.stop()

  for _, name in ipairs(apps or {}) do watching[name] = true end

  watcher = hs.application.watcher.new(function(name, event)
    if not watching[name] then return end
    if event ~= hs.application.watcher.launched then return end
    settle(name, 0)
  end)
  watcher:start()

  -- Launch is not the only way to get a window that was never assigned: a new
  -- OS window opened later in a session comes up the same way. The check is
  -- read-only, so subscribing costs nothing when everything is already right.
  windows = hs.window.filter.new(false)
  for name in pairs(watching) do windows:setAppFilter(name, {}) end
  windows:subscribe(hs.window.filter.windowCreated, function(_, name)
    if watching[name] then settle(name, 0) end
  end)

  return M
end

function M.stop()
  if watcher then
    watcher:stop()
    watcher = nil
  end
  if windows then
    windows:unsubscribeAll()
    windows = nil
  end
  timers = {}
  lastFlip = {}
  watching = {}
end

return M
