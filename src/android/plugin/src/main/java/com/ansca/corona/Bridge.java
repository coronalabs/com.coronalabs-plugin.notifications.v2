//
// Bridge.java
// Notifications V2 Plugin
//
// Copyright (c) 2017 CoronaLabs inc. All rights reserved.
//

package com.ansca.corona;

import android.content.Context;
import com.naef.jnlua.LuaState;

/**
 * Implements the Lua interface for a Corona plugin.
 * <p>
 * Only one instance of this class will be created by Corona for the lifetime of the application.
 * This instance will be re-used for every new Corona activity that gets created.
 */
public class Bridge extends NativeToJavaBridge {
	public Bridge(Context context) {
		super(context);
	}

	public static int scheduleNotification(LuaState L, int index) {
		int id = notificationSchedule(L, index);
		L.pushInteger(id);
		return 1;
	}

	public static void cancelNotification(int id) {
		callNotificationCancel(id);
	}

	public static void cancelAllNotifications() {
		callNotificationCancelAll(null);
	}
}
