local hud = require("modules.hud")

local M = {}

-- Callers predate the options table and pass a bare duration.
function M.alert(message, options)
  if type(options) == "number" then
    options = { duration = options }
  end

  return hud.show(message, options)
end

local hyper = { "ctrl", "alt", "cmd", "shift" }

function M.bindHyper(key, fn)
  hs.hotkey.bind(hyper, key, fn)
end

return M
