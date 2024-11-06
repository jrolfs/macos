local M = {}

function M.alert(message, duration)
  local alpha = 0.8
  local styling = {
    strokeWidth = 0,
    fillColor = { hex = "#32302F", alpha = alpha },
    strokeColor = { hex = "#32302F", alpha = alpha },
    textColor = { hex = "#bdae93" },
    fadeInDuration = 0.15,
    fadeOutDuration = 0.15,
    radius = 10,
    padding = 20,
    atScreenEdge = 0,
    textFont = "IBM Plex Sans",
    textSize = 24,
    -- Hammerspoon uses NS* constants for font weight
    -- Common values: "thin", "regular", "medium", "bold", "heavy"
  }

  -- Default duration of 1 second if not specified
  duration = duration or 1

  hs.alert.show(message, styling, duration)
end

local hyper = { "ctrl", "alt", "cmd", "shift" }

function M.bindHyper(key, fn)
  hs.hotkey.bind(hyper, key, fn)
end

return M
