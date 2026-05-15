local _ = require('modules.utilities')

local M = {}

-- Function to copy the current Finder directory path to clipboard
function M.copyPath()
  local script = [[
    tell application "Finder"
      if front window exists then
        set finderPath to (quoted form of POSIX path of (target of front window as alias))
        return finderPath
      else
        return ""
      end if
    end tell
  ]]
  local ok, finderPath = hs.osascript.applescript(script)
  if ok then
    hs.pasteboard.setContents(finderPath)
    _.alert("Path copied to clipboard")
  else
    _.alert("Error copying path")
  end
end

return M
