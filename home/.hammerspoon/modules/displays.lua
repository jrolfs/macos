local _ = require('modules.utilities')

local M = {}

-- The MacBook's internal panel. Matches "Built-in Retina Display",
-- "Built-in Liquid Retina XDR Display", etc.
local function builtinScreen()
  for _, s in ipairs(hs.screen.allScreens()) do
    if s:name():find("Built%-in") then
      return s
    end
  end
  return hs.screen.primaryScreen()
end

-- The display to move around the built-in one. With a laptop + iPad Sidecar
-- that's the single non-built-in screen. (Compare by id -- allScreens()
-- hands back fresh userdata each call, so == on the objects is unreliable.)
local function secondaryScreen(builtin)
  for _, s in ipairs(hs.screen.allScreens()) do
    if s:id() ~= builtin:id() then
      return s
    end
  end
  return nil
end

-- Position the secondary display on the given side of the built-in one,
-- edges flush. Horizontal sides align tops; vertical sides align left edges.
function M.place(side)
  local builtin = builtinScreen()
  local other = secondaryScreen(builtin)
  if not other then
    _.alert("No second display to arrange")
    return
  end

  local b = builtin:fullFrame()
  local o = other:fullFrame()

  local origin = ({
    left  = { x = b.x - o.w, y = b.y },
    right = { x = b.x + b.w, y = b.y },
    above = { x = b.x, y = b.y - o.h },
    below = { x = b.x, y = b.y + b.h },
  })[side]

  if not origin then
    _.alert("Unknown side: " .. tostring(side))
    return
  end

  -- setOrigin moves the display in the global coordinate space; macOS
  -- persists the arrangement for this display set until it changes again.
  other:setOrigin(origin.x, origin.y)
  _.alert("🖥️   " .. other:name() .. " → " .. side)
end

-- Prompt for a side with a searchable chooser, then apply it.
function M.choose()
  local chooser = hs.chooser.new(function(choice)
    if choice then
      M.place(choice.side)
    end
  end)

  chooser:choices({
    { text = "Left of laptop",  subText = "Secondary display on the left",  side = "left" },
    { text = "Right of laptop", subText = "Secondary display on the right", side = "right" },
    { text = "Above laptop",    subText = "Secondary display on top",       side = "above" },
    { text = "Below laptop",    subText = "Secondary display below",        side = "below" },
  })

  chooser:rows(4)
  chooser:show()
end

return M
