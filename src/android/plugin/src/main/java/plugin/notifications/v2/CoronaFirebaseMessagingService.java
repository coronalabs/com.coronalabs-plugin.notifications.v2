//
// CoronaFirebaseMessagingService.java
// Notifications V2 Plugin
//
// Copyright (c) 2017 CoronaLabs inc. All rights reserved.
//

// @formatter:off

package plugin.notifications.v2;

import android.content.Context;
import android.content.SharedPreferences;

import com.ansca.corona.CoronaEnvironment;
import com.ansca.corona.events.NotificationRegistrationTask;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

// -------------------------------------------------------
// Class definition
// -------------------------------------------------------

public class CoronaFirebaseMessagingService extends FirebaseMessagingService
{
    public static String PREFERENCE_FILE = "fcm-notifications";
    public static String SKIP_FCM = "skipFCM";

    public CoronaFirebaseMessagingService() {
        super();
    }

    private boolean ignoreFCM() {
        SharedPreferences preferences = CoronaEnvironment.getApplicationContext().getSharedPreferences(PREFERENCE_FILE, Context.MODE_PRIVATE);
        return preferences.getBoolean(SKIP_FCM, false);
    }

    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        if(ignoreFCM()) return;;
        super.onMessageReceived(remoteMessage);
        NotificationsV2Helper.processRemoteMessage(remoteMessage, getApplicationContext());
    }

    @Override
    public void onNewToken( String deviceToken ) {
        if(ignoreFCM()) return;;
        super.onNewToken(deviceToken);
        NotificationRegistrationTask registrationTask = new NotificationRegistrationTask(deviceToken);
        for (com.ansca.corona.CoronaRuntime runtime : com.ansca.corona.CoronaRuntimeProvider.getAllCoronaRuntimes()) {
            runtime.getTaskDispatcher().send(registrationTask);
        }
    }
}
