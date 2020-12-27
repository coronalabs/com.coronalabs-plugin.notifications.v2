//
// NotificationsV2Helper.java
// Notifications V2 Plugin
//
// Copyright (c) 2017 CoronaLabs inc. All rights reserved.
//

// @formatter:off

package plugin.notifications.v2;

import com.ansca.corona.CoronaActivity;
import com.ansca.corona.CoronaData;
import com.ansca.corona.CoronaEnvironment;
import com.ansca.corona.notifications.*;
import com.ansca.corona.events.*;

import android.content.Context;
import android.os.Bundle;

import java.util.Map;

import com.google.firebase.messaging.RemoteMessage;

final class NotificationsV2Helper
{
    // message constants
    private static final String NOTIFICATION_SOURCE_NAME      = "google";
    private static final String NOTIFICATION_SOURCE_DATA_NAME = "androidPayload";

    private static String previousMessageId = null;

    // prevent the caller from creating objects of this class
    public NotificationsV2Helper() {
        throw new AssertionError();
    }

    static public void processRemoteMessage(RemoteMessage remoteMessage, Context context)
    {
        Bundle bundle = new Bundle();
        for (Map.Entry<String, String> entry : remoteMessage.getData().entrySet()) {
            bundle.putString(entry.getKey(), entry.getValue());
        }

        // get notification component
        // note: data-only messages have no notification component
        // Corona's legacy plugin uses data-only notifications
        RemoteMessage.Notification notification = remoteMessage.getNotification();



        // Set up a new status bar notification.
        NotificationServices notificationServices = new NotificationServices(context);
        StatusBarNotificationSettings settings = new StatusBarNotificationSettings();
        settings.setSourceName(NOTIFICATION_SOURCE_NAME);
        settings.setSourceLocal(false);

        // Set the title to the application name by default.
        String applicationName = com.ansca.corona.CoronaEnvironment.getApplicationName();
        settings.setContentTitle(applicationName);
        settings.setTickerText(applicationName);

        if (notification != null) {
            // alert text
            settings.setContentText(notification.getBody());
            settings.setTickerText(notification.getBody());

            // sound
            android.net.Uri uri = null;
            String sound = notification.getSound();
            String activeSound = sound;
            try {
                if (sound == null) {
                    // force sound file to nonexistent file
                    // must do this as otherwise default sound will play
                    activeSound = "doNotPlaySound";
                }
                uri = com.ansca.corona.storage.FileContentProvider.createContentUriForFile(context, activeSound.trim());
            }
            catch (Exception ex) {
                ex.printStackTrace();
            }
            // Firebase Notification Console sets the sound file to "default" which does not exist in the
            // Corona file system. Ignore it so the default alert sound is played
            if ((sound == null) || (! sound.equals("default"))) {
                settings.setSoundFileUri(uri);
            }

            // check for data component
            if (remoteMessage.getData().size() > 0) {
                CoronaData.Table notificationData = (CoronaData.Table) CoronaData.Table.from(remoteMessage.getData());
                if (! notificationData.isEmpty()) {
                    settings.setData(notificationData);
                }
            }

            // check for tag and set notification id
            String notificationTag = notification.getTag();
            if (notificationTag != null) {
                settings.setId(notificationTag.hashCode());
            }
            else {
                settings.setId(notificationServices.reserveId());
            }

            // add notification source data
            CoronaData.Table sourceData = new CoronaData.Table();
            sourceData.put(new CoronaData.String("title"), CoronaData.from(notification.getTitle()));
            sourceData.put(new CoronaData.String("title_loc_key"), CoronaData.from(notification.getTitleLocalizationKey()));
            sourceData.put(new CoronaData.String("title_loc_args"), CoronaData.from(notification.getTitleLocalizationArgs()));
            sourceData.put(new CoronaData.String("body"), CoronaData.from(notification.getBody()));
            sourceData.put(new CoronaData.String("body_loc_key"), CoronaData.from(notification.getBodyLocalizationKey()));
            sourceData.put(new CoronaData.String("body_loc_args"), CoronaData.from(notification.getBodyLocalizationArgs()));
            sourceData.put(new CoronaData.String("icon"), CoronaData.from(notification.getIcon()));
            sourceData.put(new CoronaData.String("sound"), CoronaData.from(sound));
            sourceData.put(new CoronaData.String("tag"), CoronaData.from(notificationTag));
            sourceData.put(new CoronaData.String("color"), CoronaData.from(notification.getColor()));
            sourceData.put(new CoronaData.String("click_action"), CoronaData.from(notification.getClickAction()));

            sourceData.put(new CoronaData.String("from"), CoronaData.from(remoteMessage.getFrom()));
            sourceData.put(new CoronaData.String("to"), CoronaData.from(remoteMessage.getTo()));
            sourceData.put(new CoronaData.String("collapse_key"), CoronaData.from(remoteMessage.getCollapseKey()));
            sourceData.put(new CoronaData.String("google.message_id"), CoronaData.from(remoteMessage.getMessageId()));
            sourceData.put(new CoronaData.String("message_type"), CoronaData.from(remoteMessage.getMessageType()));
            sourceData.put(new CoronaData.String("google.sent_time"), CoronaData.from(remoteMessage.getSentTime()));
            sourceData.put(new CoronaData.String("time_to_live"), CoronaData.from(remoteMessage.getTtl()));

            settings.setSourceData(sourceData);
            settings.setSourceDataName(NOTIFICATION_SOURCE_DATA_NAME);
        }
        else {
            // Copy the alert information from the bundle.
            Object value = bundle.get("alert");
            if (value instanceof String) {
                // If the alert string is a JSON table, then fetch its fields.
                String alertString = (String)value;
                boolean isJson = false;
                try {
                    org.json.JSONObject jsonObject = new org.json.JSONObject(alertString);
                    value = jsonObject.opt("title");
                    if (value instanceof String) {
                        settings.setContentTitle((String)value);
                    }
                    value = jsonObject.opt("body");
                    if (value instanceof String) {
                        settings.setContentText((String)value);
                        settings.setTickerText((String)value);
                    }
                    else {
                        value = jsonObject.opt("text");
                        if (value instanceof String) {
                            settings.setContentText((String)value);
                            settings.setTickerText((String)value);
                        }
                    }
                    value = jsonObject.opt("number");
                    if (value instanceof Number) {
                        settings.setBadgeNumber(((Number)value).intValue());
                    }
                    isJson = true;
                }
                catch (Exception ex) { }

                // If the alert string is not JSON, then accept the string as is.
                if (isJson == false) {
                    settings.setContentText(alertString);
                    settings.setTickerText(alertString);
                }
            }
            else if (value == null) {
                // If an alert field was not provided, then check the bundle itself.
                // Note: This is how Fuse provides notifications.
                value = bundle.get("title");
                if (value instanceof String) {
                    settings.setContentTitle((String)value);
                }
                value = bundle.get("body");
                if (value instanceof String) {
                    settings.setContentText((String)value);
                    settings.setTickerText((String)value);
                }
                else {
                    value = bundle.get("text");
                    if (value instanceof String) {
                        settings.setContentText((String)value);
                        settings.setTickerText((String)value);
                    }
                }
                value = bundle.get("number");
                if (value instanceof Number) {
                    settings.setBadgeNumber(((Number)value).intValue());
                }
            }

            // check for tag and set notification id
            value = bundle.get("tag");
            if (value instanceof String) {
                settings.setId(((String)value).hashCode());
            }
            else {
                settings.setId(notificationServices.reserveId());
            }

            // Set the path to a custom sound file, if provided.
            value = bundle.get("sound");
            if (value instanceof String) {
                android.net.Uri uri = null;
                try {
                    uri = com.ansca.corona.storage.FileContentProvider.createContentUriForFile(
                            context, ((String)value).trim());
                }
                catch (Exception ex) {
                    ex.printStackTrace();
                }
                settings.setSoundFileUri(uri);
            }

            // Copy the bundle's custom data, if provided.
            com.ansca.corona.CoronaData.Table customData = null;
            value = bundle.get("custom");
            if (value instanceof String) {
                try {
                    customData = com.ansca.corona.CoronaData.Table.from(new org.json.JSONObject((String)value));
                }
                catch (Exception ex) { }
            }
            else if (value instanceof android.os.Bundle) {
                customData = com.ansca.corona.CoronaData.Table.from((android.os.Bundle)value);
            }
            if (customData != null) {
                settings.setData(customData);
            }

            settings.setSourceData(com.ansca.corona.CoronaData.from(bundle));
            settings.setSourceDataName(NOTIFICATION_SOURCE_DATA_NAME);
        }

        // Post the notification to the status bar.
        notificationServices.post(settings);
    }

    // check for message data from a notification-activated app launch
    // used by notification-type messages only.
    // data-type messages are handled by Corona Core launch args
    static void checkForMessageData()
    {
        final CoronaActivity coronaActivity = CoronaEnvironment.getCoronaActivity();

        if (coronaActivity != null) {
            Bundle extras = coronaActivity.getIntent().getExtras();

            if (extras != null) { // send data from tapped notification
                // prevent app resume from dispatching the same notification more than once
                String currentMessageId = extras.getString("google.message_id");
                if ((currentMessageId != null) && (! currentMessageId.equals(previousMessageId))) {
                    previousMessageId = currentMessageId;

                    // configure the notification
                    StatusBarNotificationSettings settings = new StatusBarNotificationSettings();

                    settings.setSourceName(NOTIFICATION_SOURCE_NAME);
                    settings.setSourceLocal(false);

                    // Set the title to the application name by default
                    String applicationName = com.ansca.corona.CoronaEnvironment.getApplicationName();
                    settings.setContentTitle(applicationName);
                    settings.setTickerText(applicationName);

                    // process custom data
                    CoronaData.Table notificationData = new CoronaData.Table();
                    for (String key: extras.keySet()) {
                        // filter system data from custom user data
                        if ((! key.equals("collapse_key")) && (! key.startsWith("google.")) && (! key.equals("from"))) {
                            Object value = extras.get(key);
                            notificationData.put(new CoronaData.String(key), CoronaData.from(value));
                        }
                    }
                    if (notificationData.size() > 0) {
                        settings.setData(notificationData);
                    }

                    // add notification source data
                    CoronaData.Table sourceData = CoronaData.Table.from(extras);
                    settings.setSourceData(sourceData);
                    settings.setSourceDataName(NOTIFICATION_SOURCE_DATA_NAME);

                    // dispatch the event
                    for (com.ansca.corona.CoronaRuntime runtime : com.ansca.corona.CoronaRuntimeProvider.getAllCoronaRuntimes()) {
                        NotificationReceivedTask event = new NotificationReceivedTask("inactive", settings);
                        runtime.getTaskDispatcher().send(event);
                    }
                }
            }
        }
    }
}
