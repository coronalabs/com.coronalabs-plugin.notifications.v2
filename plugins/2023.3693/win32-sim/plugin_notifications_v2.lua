-- Notifications V2 plugin

local Library = require "CoronaLibrary"

-- Create library
local lib = Library:new{ name="plugin.notifications.v2", publisherId="com.coronalabs", version=1 }

-------------------------------------------------------------------------------
-- BEGIN
-------------------------------------------------------------------------------

-- This sample implements the following Lua:
-- 
--    local notifications = require "plugin.notifications.v2"
--    

local function showWarning(functionName)
    print( functionName .. " WARNING: The Notifications V2 plugin is only supported on iOS and Android devices")
end

function lib.registerForPushNotifications()
    showWarning("notifications.registerForPushNotifications()")
end

function lib.subscribe()
    showWarning("notifications.subscribe()")
end

function lib.unsubscribe()
    showWarning("notifications.unsubscribe()")
end

function lib.getDeviceToken()
    showWarning("notifications.getDeviceToken()")
end

function lib.scheduleNotification()
    showWarning("notifications.scheduleNotification()")
end

function lib.cancelNotification()
    showWarning("notifications.cancelNotification()")
end

-------------------------------------------------------------------------------
-- END
-------------------------------------------------------------------------------

-- Return an instance
return lib
