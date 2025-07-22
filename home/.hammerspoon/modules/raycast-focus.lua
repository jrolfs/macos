local _ = require('modules.utilities')

local M = {}

local raycastFocusWatcher = nil

local function createWatcher()
  local watcher = hs.window.filter.new(false)
  if not watcher then
    print("⚠️ Failed to create window filter, retrying...")
    return nil
  end
  return watcher:setAppFilter('Raycast', {})
end

local function fixFocus(window)
  print("🔧 Auto-fixing kitty focus issue for AI Chat")

  -- Force focus to the AI Chat window
  window:focus()
  window:raise()

  -- Also ensure Raycast app has focus
  local raycast = hs.application.find("Raycast")
  if raycast then
    raycast:activate(true)
  end

  -- _.alert("Fixed focus issue!")
end

local function setupWatcherCallbacks(watcher)
  watcher:subscribe(hs.window.filter.windowCreated, function(window, appName)
    if window:title() == "AI Chat" then
      print("🤖 Raycast AI Chat window created")

      -- Check if focus is properly transferred after a short delay
      hs.timer.doAfter(0.1, function()
        local frontApp = hs.application.frontmostApplication()
        local focusedWindow = hs.window.focusedWindow()

        if frontApp and frontApp:name() == "kitty" then
          print("🐱 Focus issue detected: AI Chat opened but kitty still has focus")
          -- _.alert("Kitty focus issue with AI Chat!")

          -- Optional: Print more debug info
          if focusedWindow then
            print("  Currently focused window:", focusedWindow:application():name(), "-", focusedWindow:title())
          end

          -- Fix the focus issue
          fixFocus(window)
        else
          print("✅ Focus correctly transferred to:", frontApp:name())
        end
      end)
    end
  end)

  watcher:subscribe(hs.window.filter.windowFocused, function(window, appName)
    if window:title() == "AI Chat" then
      print("🎯 AI Chat window received focus")

      -- Double-check that the application also has focus
      hs.timer.doAfter(0.05, function()
        local frontApp = hs.application.frontmostApplication()
        if frontApp and frontApp:name() ~= "Raycast" then
          print("🐱 Focus mismatch: AI Chat window focused but", frontApp:name(), "app still has focus")
          -- _.alert("Focus mismatch detected!")

          -- Fix the focus mismatch
          fixFocus(window)
        end
      end)
    end
  end)
end

function M.start()
  if raycastFocusWatcher then
    raycastFocusWatcher:stop()
  end

  -- Delay the watcher creation to ensure extensions are loaded
  hs.timer.doAfter(0.5, function()
    raycastFocusWatcher = createWatcher()

    if raycastFocusWatcher then
      setupWatcherCallbacks(raycastFocusWatcher)
      raycastFocusWatcher:start()
      print("Raycast AI focus watcher started")
    else
      print("❌ Failed to create Raycast focus watcher")
      -- Retry after a longer delay
      hs.timer.doAfter(2, function()
        M.start()
      end)
    end
  end)
end

function M.stop()
  if raycastFocusWatcher then
    raycastFocusWatcher:stop()
    raycastFocusWatcher = nil
  end

  print("Raycast AI focus watcher stopped")
end

return M
