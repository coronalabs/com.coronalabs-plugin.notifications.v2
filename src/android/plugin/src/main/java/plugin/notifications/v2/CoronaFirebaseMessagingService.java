//
// CoronaFirebaseMessagingService.java
// Notifications V2 Plugin
//
// Copyright (c) 2017 CoronaLabs inc. All rights reserved.
//

// @formatter:off

package plugin.notifications.v2;

import com.ansca.corona.events.NotificationRegistrationTask;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

// -------------------------------------------------------
// Class definition
// -------------------------------------------------------

public class CoronaFirebaseMessagingService extends FirebaseMessagingService
{
    public CoronaFirebaseMessagingService() {
        super();
    }

    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        super.onMessageReceived(remoteMessage);
        NotificationsV2Helper.processRemoteMessage(remoteMessage, getApplicationContext());
    }

    @Override
    public void onNewToken( String deviceToken ) {
        super.onNewToken(deviceToken);
        NotificationRegistrationTask registrationTask = new NotificationRegistrationTask(deviceToken);
        for (com.ansca.corona.CoronaRuntime runtime : com.ansca.corona.CoronaRuntimeProvider.getAllCoronaRuntimes()) {
            runtime.getTaskDispatcher().send(registrationTask);
        }
    }
}
