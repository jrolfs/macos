local appsToHide = {"Safari", "Mail", "Calendar"} -- List of applications to hide

-- Function to check if an application is in the list
local function shouldHideApp(appName)
    for _, name in ipairs(appsToHide) do
        if name == appName then
            return true
        end
    end
    return false
end

-- Watcher function that gets called when the active application changes
local appWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
    if eventType == hs.application.watcher.deactivated then
        if shouldHideApp(appName) then
            appObject:hide()
        end
    end
end)

-- Start the application watcher
appWatcher:start()
