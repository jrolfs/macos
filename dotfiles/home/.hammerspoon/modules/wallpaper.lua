-- The desktop picture, across every space.
--
-- macOS keeps the picture in a store WallpaperAgent owns rather than reads
-- (~/Library/Application Support/com.apple.wallpaper/Store/Index.plist), so
-- writing the preference does nothing: the only public way in is NSWorkspace,
-- which is hs.screen:desktopImageURL here. That paints the *active* space of
-- each screen and nothing else — System Settings writes an "all spaces and
-- displays" scope no public API reaches — so covering the rest means going to
-- each space in turn, which is what hs.spaces is for.
--
-- Driven from home-manager activation (modules/home/wallpaper.nix), which is
-- where the path is declared.

local M = {}

-- gotoSpace returns as soon as it has pressed the Mission Control button, not
-- when the switch has landed. Painting before it lands repaints the space we
-- came from and leaves the new one alone.
M.settleTime = 1.0

-- Held so the one-shot timer driving the walk can't be collected mid-walk.
local walking = nil

local function screens()
  return hs.screen.allScreens()
end

local function userSpaces()
  local spaces = {}

  for _, ids in pairs(hs.spaces.allSpaces() or {}) do
    for _, id in ipairs(ids) do
      -- Fullscreen spaces belong to their app's window, not to the desktop.
      if hs.spaces.spaceType(id) == "user" then
        spaces[#spaces + 1] = id
      end
    end
  end

  return spaces
end

local function paint(url)
  for _, screen in ipairs(screens()) do
    screen:desktopImageURL(url)
  end
end

local function painted(url)
  for _, screen in ipairs(screens()) do
    if screen:desktopImageURL() ~= url then
      return false
    end
  end

  return true
end

-- Point every space on every attached screen at `path`.
--
-- Returns immediately: "missing" if the file isn't there, "unchanged" if every
-- attached screen already shows it, otherwise "walking" — the remaining spaces
-- are painted on a timer from here, taking about a second each.
function M.apply(path)
  -- Percent-encoded file:// URL via NSURL, so it compares equal to what the
  -- getter hands back. Nil for a path that doesn't exist, which is the check we
  -- want anyway: pointing the desktop at a missing file paints it black.
  local url = hs.fs.urlFromPath(path)

  if not url then
    return "missing"
  end

  if painted(url) then
    return "unchanged"
  end

  local origin = hs.spaces.focusedSpace()
  local remaining = {}

  for _, id in ipairs(userSpaces()) do
    if id ~= origin then
      remaining[#remaining + 1] = id
    end
  end

  paint(url)

  local index = 0

  local function step()
    index = index + 1
    local id = remaining[index]

    if not id then
      walking = nil

      if hs.spaces.focusedSpace() ~= origin then
        hs.spaces.gotoSpace(origin)
      end

      return
    end

    -- Needs Accessibility, since it drives Mission Control. A space we can't
    -- reach keeps its old picture; the rest still get painted.
    local ok, err = hs.spaces.gotoSpace(id)

    if not ok then
      print("wallpaper: could not reach space " .. tostring(id) .. ": " .. tostring(err))
      return step()
    end

    walking = hs.timer.doAfter(M.settleTime, function()
      paint(url)
      step()
    end)
  end

  step()

  return "walking"
end

return M
