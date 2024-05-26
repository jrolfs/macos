-- Function to copy the current Finder directory path to clipboard
local function copyFinderPath()
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
    hs.alert.show("Path copied to clipboard")
  else
    hs.alert.show("Error copying path")
  end
end

-- Bind the function to a hotkey, e.g., Cmd + Shift + C
hs.hotkey.bind({ "ctrl", "alt", "cmd", "shift" }, "C", copyFinderPath)
