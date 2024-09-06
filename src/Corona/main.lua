-- -- Project: GooglePushNotifications
-- --
-- -- File name: main.lua
-- --
-- -- Author: Corona Labs Inc.
-- --
-- -- This sample app demonstrates how to send and receive push notifications via the
-- -- Google Cloud Messaging service (aka: GCM).
-- -- See the "build.settings" file to see what Android permissions are required.
-- -- See the "config.lua" file on how to register for push notifications with Google.
-- -- See the following website on how to set up your app for Google's push notification system.
-- --   http://developer.android.com/google/gcm/gs.html
-- --
-- -- Limitations: This sample app only works on an Android device with "Google Play" installed.
-- --
-- -- Sample code is MIT licensed, see http://www.coronalabs.com/links/code/license
-- -- Copyright (C) 2012 Corona Labs Inc. All Rights Reserved.
-- --
-- --  Supports Graphics 2.0
-- ---------------------------------------------------------------------------------------

-- local notifications = require( "plugin.notifications.v2" )

-- local centerX = display.contentCenterX
-- local centerY = display.contentCenterY
-- local _W = display.contentWidth
-- local _H = display.contentHeight

-- -- A Google API Key is needed to send push notifications. It is not needed to receive notifications.
-- -- This key can be obtained from the Google API Console here:  https://code.google.com/apis/console
-- --
-- -- firebase FCM:
-- local googleServerKey = "AAAAe-QgXmE:APA91bGQpiOHzzKqtyhsaxSxbjGXlKp0Rdo1oa47q2rFhQVW4wbBk1gTHq-vADrAH3C0oDADJbda89pYxMQMWPVRwHs2iEGLTgm2rtXA0kq6SlzyM3DY15NV6NdWtH-OIqX6lsKtkApF"

-- -- A Google registration ID is also needed to send push notifications.
-- -- This key will be obtained by the notification listener below after this app has successfully
-- -- registered with Google. See the "config.lua" file on how to register this app with Google.
-- local googleRegistrationId = nil

-- local messageCounter = 0


-- -- Show the status bar so that we can easily access the received notifications.
-- display.setStatusBar(display.DefaultStatusBar)

-- -- Set up the background.
-- local background = display.newRect(centerX, centerY, display.contentWidth, display.contentHeight)
-- background:setFillColor(0.5, 0, 0)

-- -- Display instructions.
-- local message = "Tap the screen to push a notification"
-- local textField = display.newText(message, 0, centerY, native.systemFont, 18)
-- textField:setFillColor(1, 1, 1)
-- textField.x = centerX


-- -- Called when a sent notification has succeeded or failed.
-- local function onSendNotification(event)
--     local errorMessage = nil

--     -- Determine if we have successfully sent the notification to Google's server.
--     if event.isError then
--         -- Failed to connect to the server.
--         -- This typically happens due to lack of Internet access.
--         errorMessage = "Failed to connect to the server."

--     elseif event.status == 200 then
--         -- A status code of 200 means that the notification was sent succcessfully.
--         print("Notification was sent successfully.")

--     elseif event.status == 400 then
--         -- There was an error in the sent notification's JSON data.
--         errorMessage = event.response

--     elseif event.status == 401 then
--         -- There was a user authentication error.
--         errorMessage = "Failed to authenticate the sender's Google Play account."

--     elseif (event.status >= 500) and (event.status <= 599) then
--         -- The Google Cloud Messaging server failed to process the given notification.
--         -- This indicates an internal error on the server side or the server is temporarily unavailable.
--         -- In this case, we are supposed to silently fail and try again later.
--         errorMessage = "Server failed to process the request. Please try again later."
--     end

--     -- Display an error message if there was a failure.
--     if errorMessage then
--         native.showAlert("Notification Error", errorMessage, { "OK" })
--     end
-- end

-- -- Sends the given JSON message to the Google Cloud Messaging server to be pushed to Android devices.
-- local function sendNotification(jsonMessage)
--     -- Do not continue if a Google API Key was not provided.
--     if not googleServerKey then
--         return
--     end

--     -- Print the JSON message to the log.
--     print("--- Sending Notification ----")
--     print(jsonMessage)

--     -- Send the push notification to this app.
--     local url = "https://fcm.googleapis.com/fcm/send"
--     local parameters =
--     {
--         headers =
--         {
--             ["Authorization"] = "key=" .. googleServerKey,
--             ["Content-Type"] = "application/json",
--         },
--         body = jsonMessage,
--     }
--     network.request(url, "POST", onSendNotification, parameters)
-- end

-- -- Sends a push notification when the screen has been tapped.
-- local function onTap(event)
--     -- Do not continue if this app has not been registered for push notifications yet.
--     if not googleRegistrationId then
--         return
--     end

--     messageCounter = messageCounter + 1

--     -- Set up a JSON message to send a push notification to this app.
--     -- The "registration_ids" tells Google to whom this push notification should be delivered to.
--     -- The "alert" field sets the message to be displayed when the notification has been received.
--     -- The "sound" field is optional and will play a sound file in the app's ResourceDirectory.
--     -- The "custom" field is optional and will be delivered by the notification event's "event.custom" property.

--     local jsonGcmMessage =
-- [[
-- {
--     "registration_ids": ["]] .. tostring(googleRegistrationId) .. [["],
--     "data":
--     {
--         "alert":
--         {
--             "title": "My Title",
--             "body": "My body text ]] .. tostring(messageCounter) .. [[",
--             "number": 123
--         },
--         "sound": "notification.wav",
--         "notification_id": "Hello Vlad",
--         "name": "My Name",
--         "tag": "mytag",
--         "custom":
--         {
--             "boolean": true,
--             "number": 123.456,
--             "string": "Custom data test.",
--             "array": [ true, false, 0, 1, "", "This is a test." ],
--             "table": { "x": 1, "y": 2 }
--         }
--     }
-- }
-- ]]

--     local jsonFcmMessage =
-- [[
-- {
--     "registration_ids": ["]] .. tostring(googleRegistrationId) .. [["],
--     "data": {
--         "boolean": true,
--         "number": 123.456,
--         "string": "Custom data test.",
--         "array": [ true, false, 0, 1, "", "This is a test." ],
--         "table": { "x": 1, "y": 2 }
--     }
--     "notification": {
--         "title": "My Title",
--         "body": "My body text ]] .. tostring(messageCounter) .. [[",
--         "sound": "notification.wav",
--         "tag": "myTag"
--     }
-- }
-- ]]

--     sendNotification(jsonGcmMessage)
-- end
-- Runtime:addEventListener("tap", onTap)

-- -- Prints all contents of a Lua table to the log.
-- local function printTable(table, stringPrefix)
--     if not stringPrefix then
--         stringPrefix = "### "
--     end
--     if type(table) == "table" then
--         for key, value in pairs(table) do
--             if type(value) == "table" then
--                 print(stringPrefix .. tostring(key))
--                 print(stringPrefix .. "{")
--                 printTable(value, stringPrefix .. "   ")
--                 print(stringPrefix .. "}")
--             else
--                 print(stringPrefix .. tostring(key) .. ": " .. tostring(value))
--             end
--         end
--     end
-- end

-- -- Called when a notification event has been received.
-- local function onNotification(event)
--     if event.type == "remoteRegistration" then
--         if event.token ~= "unknown" then
--             -- This device has just been registered for Google Cloud Messaging (GCM) push notifications.
--             -- Store the Registration ID that was assigned to this application by Google.
--             googleRegistrationId = event.token

--             -- Display a message indicating that registration was successful.
--             local message = "This app has successfully registered for Google push notifications."
--             native.showAlert("Information", message, { "OK" })

--             -- Print the registration event to the log.
--             print("### --- Registration Event ---")
--             printTable(event)
--         end
--     else
--         -- A push notification has just been received. Print it to the log.
--         print("### --- Notification Event ---")
--         printTable(event)
--     end
-- end

-- -- Set up a notification listener.
-- Runtime:addEventListener("notification", onNotification)

-- -- iOS only
-- notifications.registerForPushNotifications{ useFCM=true }

-- -- get device token on app launch (must do this as token is automatically reported on first launch only)
-- timer.performWithDelay(2500, function()
--     notifications.getDeviceToken()
-- end)

-- -- Print this app's launch arguments to the log.
-- -- This allows you to view what these arguments provide when this app is started by tapping a notification.
-- local launchArgs = ...
-- if ( launchArgs and launchArgs.notification ) then
--     print(">>>> launching app from a notification...")
--     onNotification( launchArgs.notification )
-- end
--
--  main.lua
--  Firebase Messaging Sample App
--
--  Copyright (c) 2017 Corona Labs Inc. All rights reserved.
--

-- ============================================================================================================

-- use launch args for detecting app launch from tapping a notification (local notifications only)
local launchArgs = ...
 
local notifications = require("plugin.notifications.v2")
local widget = require("widget")
local json = require("json")

--------------------------------------------------------------------------
-- set up UI
--------------------------------------------------------------------------

display.setStatusBar( display.HiddenStatusBar )
display.setDefault( "background", 1 )

local firebaseLogo = display.newImage( "firebaselogo.png" )
firebaseLogo.anchorY = 0
firebaseLogo:scale( 0.5, 0.5 )
firebaseLogo.x, firebaseLogo.y = display.contentCenterX, -5

local subTitle = display.newText {
    text = "Notifications V2 plugin for Corona SDK",
    font = display.systemFont,
    fontSize = 14
}
subTitle:setTextColor( 0.2, 0.2, 0.2 )
subTitle.x, subTitle.y = display.contentCenterX, 60

eventDataTextBox = native.newTextBox( display.contentCenterX, display.contentHeight - 20, display.contentWidth - 10, 100)
eventDataTextBox.placeholder = "Event data will appear here"
eventDataTextBox.hasBackground = false

local processEventTable = function(event) 
    local logString = json.prettify(event):gsub("\\","")
    print(logString)
    eventDataTextBox.text = logString .. eventDataTextBox.text
end

-- --------------------------------------------------------------------------
-- -- plugin implementation
-- --------------------------------------------------------------------------

local localNotification

-- Listen for notifications
local notificationsListener = function( event )
    processEventTable(event)
end

print("token", notifications.getDeviceToken())

notifications.registerForPushNotifications( {useFCM=true})

-- use runtime listener for both local and Firebase notifications
Runtime:addEventListener( "notification", notificationsListener )

local subscribeToNewsTopic = widget.newButton {
    label = "Subscribe to News",
    width = 200,
    height = 40,
    labelColor = { default={ 0, 0, 0 }, over={ 0.7, 0.7, 0.7 } },
    onRelease = function(event)
        notifications.subscribe("news")
    end
}
subscribeToNewsTopic.x, subscribeToNewsTopic.y = display.contentCenterX, 130

local unsubscribeFromNewsTopic = widget.newButton {
    label = "Unsubscribe from News",
    width = 200,
    height = 40,
    labelColor = { default={ 0, 0, 0 }, over={ 0.7, 0.7, 0.7 } },
    onRelease = function(event)
        notifications.unsubscribe("news")
    end
}
unsubscribeFromNewsTopic.x, unsubscribeFromNewsTopic.y = display.contentCenterX, subscribeToNewsTopic.y + 40

local scheduleLocalNotification = widget.newButton {
    label = "Local notification (in 10s)",
    width = 200,
    height = 40,
    labelColor = { default={ 0, 0, 0 }, over={ 0.7, 0.7, 0.7 } },
    onRelease = function(event)
        local options = {
            alert = {title="Cool Title Here", body="Cool Body Here"},--alert="Title Here"
            sound = "notification.wav",
            badge = 2,
            custom = { foo = "bar" }
        }
         
        localNotification = notifications.scheduleNotification( 10, options )
    end
}
scheduleLocalNotification.x, scheduleLocalNotification.y = display.contentCenterX, unsubscribeFromNewsTopic.y + 60

local cancelLocalNotification = widget.newButton {
    label = "Cancel Local Notification",
    width = 200,
    height = 40,
    labelColor = { default={ 0, 0, 0 }, over={ 0.7, 0.7, 0.7 } },
    onRelease = function(event)
        notifications.cancelNotification(localNotification)
    end
}
cancelLocalNotification.x, cancelLocalNotification.y = display.contentCenterX, scheduleLocalNotification.y + 40

local getDeviceTokenButton = widget.newButton {
    label = "Get device token",
    width = 200,
    height = 40,
    labelColor = { default={ 0, 0, 0 }, over={ 0.7, 0.7, 0.7 } },
    onRelease = function(event)
        print("token", notifications.getDeviceToken())
    end
}
getDeviceTokenButton.x, getDeviceTokenButton.y = display.contentCenterX, cancelLocalNotification.y + 60

local areNotificationsEnabledButton = widget.newButton {
    label = "Are notifications enabled",
    width = 200,
    height = 40,
    labelColor = { default={ 0, 0, 0 }, over={ 0.7, 0.7, 0.7 } },
    onRelease = function(event)
        print("notifications enabled", notifications.areNotificationsEnabled())
    end
}
areNotificationsEnabledButton.x, areNotificationsEnabledButton.y = display.contentCenterX, getDeviceTokenButton.y + 40

-- local notifications: check for launch args and call listener
if ( launchArgs and launchArgs.notification ) then
    print(">>>> launching app from notification...")
    notificationsListener( launchArgs.notification )
end
