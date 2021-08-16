//
// LuaLoader.java
// Notifications V2 Plugin
//
// Copyright (c) 2017 CoronaLabs inc. All rights reserved.
//

package plugin.notifications.v2;

import com.ansca.corona.CoronaActivity;
import com.ansca.corona.CoronaRuntimeTaskDispatcher;
import com.ansca.corona.CoronaEnvironment;
import com.ansca.corona.CoronaRuntime;
import com.ansca.corona.CoronaRuntimeListener;
import com.ansca.corona.Bridge;

import com.naef.jnlua.LuaState;
import com.naef.jnlua.JavaFunction;
import com.naef.jnlua.LuaType;
import com.naef.jnlua.NamedJavaFunction;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.iid.FirebaseInstanceId;

/**
 * Implements the Lua interface for the plugin.
 * <p>
 * Only one instance of this class will be created by Corona for the lifetime of the application.
 * This instance will be re-used for every new Corona activity that gets created.
 */
@SuppressWarnings({"unused", "RedundantSuppression"})
public class LuaLoader implements JavaFunction, CoronaRuntimeListener {
    private static final String PLUGIN_NAME = "plugin.notifications.v2";
    private static final String PLUGIN_VERSION = "1.0.1";

    // message constants
    private static final String CORONA_TAG = "Corona";
    private static final String ERROR_MSG = "ERROR: ";
    private static final String WARNING_MSG = "WARNING: ";

    private static String functionSignature = "";   // used in error reporting functions

    public static CoronaRuntime coronaRuntime;
    private static CoronaRuntimeTaskDispatcher coronaRuntimeTaskDispatcher = null;

    // -------------------------------------------------------
    // Plugin lifecycle events
    // -------------------------------------------------------

    /**
     * Called after the Corona runtime has been created and just before executing the "main.lua" file.
     * <p>
     * Warning! This method is not called on the main thread.
     *
     * @param runtime Reference to the CoronaRuntime object that has just been loaded/initialized.
     *                Provides a LuaState object that allows the application to extend the Lua API.
     */
    @Override
    public void onLoaded(CoronaRuntime runtime) {
        // Note that this method will not be called the first time a Corona activity has been launched.
        // This is because this listener cannot be added to the CoronaEnvironment until after
        // this plugin has been required-in by Lua, which occurs after the onLoaded() event.
        // However, this method will be called when a 2nd Corona activity has been created.

        if (coronaRuntimeTaskDispatcher == null) {
            coronaRuntimeTaskDispatcher = new CoronaRuntimeTaskDispatcher(runtime);
            coronaRuntime = runtime;
        }
    }

    /**
     * Called just after the Corona runtime has executed the "main.lua" file.
     * <p>
     * Warning! This method is not called on the main thread.
     *
     * @param runtime Reference to the CoronaRuntime object that has just been started.
     */
    @Override
    public void onStarted(CoronaRuntime runtime) {
        NotificationsV2Helper.checkForMessageData();

        // log plugin version to device log
        Log.i(CORONA_TAG, PLUGIN_NAME + ": " + PLUGIN_VERSION);
    }

    /**
     * Called just after the Corona runtime has been suspended which pauses all rendering, audio, timers,
     * and other Corona related operations. This can happen when another Android activity (ie: window) has
     * been displayed, when the screen has been powered off, or when the screen lock is shown.
     * <p>
     * Warning! This method is not called on the main thread.
     *
     * @param runtime Reference to the CoronaRuntime object that has just been suspended.
     */
    @Override
    public void onSuspended(CoronaRuntime runtime) {
    }

    /**
     * Called just after the Corona runtime has been resumed after a suspend.
     * <p>
     * Warning! This method is not called on the main thread.
     *
     * @param runtime Reference to the CoronaRuntime object that has just been resumed.
     */
    @Override
    public void onResumed(CoronaRuntime runtime) {
        NotificationsV2Helper.checkForMessageData();
    }

    /**
     * Called just before the Corona runtime terminates.
     * <p>
     * This happens when the Corona activity is being destroyed which happens when the user presses the Back button
     * on the activity, when the native.requestExit() method is called in Lua, or when the activity's finish()
     * method is called. This does not mean that the application is exiting.
     * <p>
     * Warning! This method is not called on the main thread.
     *
     * @param runtime Reference to the CoronaRuntime object that is being terminated.
     */
    @Override
    public void onExiting(final CoronaRuntime runtime) {
        coronaRuntime = null;
        coronaRuntimeTaskDispatcher = null;
        functionSignature = "";
    }

    // --------------------------------------------------------------------------
    // helper functions
    // --------------------------------------------------------------------------

    // log message to console
    private void logMsg(String msgType, String errorMsg) {
        String functionID = functionSignature;
        if (!functionID.isEmpty()) {
            functionID += ", ";
        }

        Log.i(CORONA_TAG, msgType + functionID + errorMsg);
    }

    // -------------------------------------------------------
    // plugin implementation
    // -------------------------------------------------------

    /**
     * <p>
     * Note that a new LuaLoader instance will not be created for every CoronaActivity instance.
     * That is, only one instance of this class will be created for the lifetime of the application process.
     * This gives a plugin the option to do operations in the background while the CoronaActivity is destroyed.
     */
    @SuppressWarnings("unused")
    public LuaLoader() {
        // Set up this plugin to listen for Corona runtime events to be received by methods
        // onLoaded(), onStarted(), onSuspended(), onResumed(), and onExiting().

        CoronaEnvironment.addRuntimeListener(this);
    }

    /**
     * Called when this plugin is being loaded via the Lua require() function.
     * <p>
     * Note that this method will be called every time a new CoronaActivity has been launched.
     * This means that you'll need to re-initialize this plugin here.
     * <p>
     * Warning! This method is not called on the main UI thread.
     *
     * @param L Reference to the Lua state that the require() function was called from.
     * @return Returns the number of values that the require() function will return.
     * <p>
     * Expected to return 1, the library that the require() function is loading.
     */
    @Override
    public int invoke(LuaState L) {
        // Register this plugin into Lua with the following functions.
        NamedJavaFunction[] luaFunctions = new NamedJavaFunction[]{
                new RegisterForPushNotifications(),
                new GetDeviceToken(),
                new Subscribe(),
                new Unsubscribe(),
                new ScheduleNotification(),
                new CancelNotification()
        };
        String libName = L.toString(1);
        L.register(libName, luaFunctions);

        // Returning 1 indicates that the Lua require() function will return the above Lua library
        return 1;
    }

    // [Lua] registerForPushNotifications( {options} )
    private class RegisterForPushNotifications implements NamedJavaFunction {
        /**
         * Gets the name of the Lua function as it would appear in the Lua script.
         *
         * @return Returns the name of the custom Lua function.
         */
        @Override
        public String getName() {
            return "registerForPushNotifications";
        }

        /**
         * This method is called when the Lua function is called.
         * <p>
         * Warning! This method is not called on the main UI thread.
         *
         * @param L Reference to the Lua state.
         *                 Needed to retrieve the Lua function's parameters and to return values back to Lua.
         * @return Returns the number of values to be returned by the Lua function.
         */
        @Override
        public int invoke(final LuaState L) {

            if(L.isTable(1)) {
                L.getField(1, "useFCM");
                if(L.type(-1) == LuaType.BOOLEAN) {
                    SharedPreferences preferences = CoronaEnvironment.getApplicationContext().getSharedPreferences(CoronaFirebaseMessagingService.PREFERENCE_FILE, Context.MODE_PRIVATE);
                    SharedPreferences.Editor editor = preferences.edit();
                    editor.putBoolean(CoronaFirebaseMessagingService.SKIP_FCM, !L.toBoolean(-1));
                    editor.apply();
                }
                L.pop(1);
            }

            return 0;
        }
    }

    // [Lua] GetDeviceToken()
    private class GetDeviceToken implements NamedJavaFunction {
        /**
         * Gets the name of the Lua function as it would appear in the Lua script.
         *
         * @return Returns the name of the custom Lua function.
         */
        @Override
        public String getName() {
            return "getDeviceToken";
        }

        /**
         * This method is called when the Lua function is called.
         * <p>
         * Warning! This method is not called on the main UI thread.
         *
         * @param luaState Reference to the Lua state.
         *                 Needed to retrieve the Lua function's parameters and to return values back to Lua.
         * @return Returns the number of values to be returned by the Lua function.
         */
        @Override
        public int invoke(final LuaState luaState) {
            functionSignature = "notifications.getDeviceToken()";

            // check number of args
            int nargs = luaState.getTop();
            if (nargs != 0) {
                logMsg(ERROR_MSG, "Expected no arguments, got " + nargs);
                return 0;
            }

            String deviceToken = FirebaseInstanceId.getInstance().getToken();

            if (deviceToken == null) {
                deviceToken = "unknown";
            }

            luaState.pushString(deviceToken);

            return 1;
        }
    }

    // [Lua] subscribe(topic)
    private class Subscribe implements NamedJavaFunction {
        /**
         * Gets the name of the Lua function as it would appear in the Lua script.
         *
         * @return Returns the name of the custom Lua function.
         */
        @Override
        public String getName() {
            return "subscribe";
        }

        /**
         * This method is called when the Lua function is called.
         * <p>
         * Warning! This method is not called on the main UI thread.
         *
         * @param luaState Reference to the Lua state.
         *                 Needed to retrieve the Lua function's parameters and to return values back to Lua.
         * @return Returns the number of values to be returned by the Lua function.
         */
        @Override
        public int invoke(final LuaState luaState) {
            functionSignature = "notifications.subscribe(topic)";

            // check number of args
            int nargs = luaState.getTop();
            if (nargs != 1) {
                logMsg(ERROR_MSG, "Expected 1 argument, got " + nargs);
                return 0;
            }

            final String topic;

            // check for topic
            if (luaState.type(1) == LuaType.STRING) {
                topic = luaState.toString(1);
            } else {
                logMsg(ERROR_MSG, "options.topic (string) expected, got " + luaState.typeName(1));
                return 0;
            }

            final CoronaActivity coronaActivity = CoronaEnvironment.getCoronaActivity();
            if (coronaActivity != null) {
                coronaActivity.runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        FirebaseMessaging.getInstance().subscribeToTopic(topic);
                    }
                });
            }

            return 0;
        }
    }

    // [Lua] unsubscribe(topic)
    private class Unsubscribe implements NamedJavaFunction {
        /**
         * Gets the name of the Lua function as it would appear in the Lua script.
         *
         * @return Returns the name of the custom Lua function.
         */
        @Override
        public String getName() {
            return "unsubscribe";
        }

        /**
         * This method is called when the Lua function is called.
         * <p>
         * Warning! This method is not called on the main UI thread.
         *
         * @param luaState Reference to the Lua state.
         *                 Needed to retrieve the Lua function's parameters and to return values back to Lua.
         * @return Returns the number of values to be returned by the Lua function.
         */
        @Override
        public int invoke(final LuaState luaState) {
            functionSignature = "notifications.unsubscribe(topic)";

            // check number of args
            int nargs = luaState.getTop();
            if (nargs != 1) {
                logMsg(ERROR_MSG, "Expected 1 argument, got " + nargs);
                return 0;
            }

            final String topic;

            // check for topic
            if (luaState.type(1) == LuaType.STRING) {
                topic = luaState.toString(1);
            } else {
                logMsg(ERROR_MSG, "options.topic (string) expected, got " + luaState.typeName(1));
                return 0;
            }

            final CoronaActivity coronaActivity = CoronaEnvironment.getCoronaActivity();

            if (coronaActivity != null) {
                coronaActivity.runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        FirebaseMessaging.getInstance().unsubscribeFromTopic(topic);
                    }
                });
            }

            return 0;
        }
    }

    // [Lua] scheduleNotification(time [, options])
    private class ScheduleNotification implements NamedJavaFunction {
        /**
         * Gets the name of the Lua function as it would appear in the Lua script.
         *
         * @return Returns the name of the custom Lua function.
         */
        @Override
        public String getName() {
            return "scheduleNotification";
        }

        /**
         * This method is called when the Lua function is called.
         * <p>
         * Warning! This method is not called on the main UI thread.
         *
         * @param luaState Reference to the Lua state.
         *                 Needed to retrieve the Lua function's parameters and to return values back to Lua.
         * @return Returns the number of values to be returned by the Lua function.
         */
        @Override
        public int invoke(final LuaState luaState) {
            functionSignature = "notifications.scheduleNotification(time [, options])";

            // check number of args
            int nargs = luaState.getTop();
            if ((nargs < 1) || (nargs > 2)) {
                logMsg(ERROR_MSG, "Expected 1 or 2 arguments, got " + nargs);
                return 0;
            }

            // check time parameter
            //noinspection StatementWithEmptyBody
            if (luaState.type(1) == LuaType.NUMBER) {
                // time is a number
                // will be handled by the Corona Core
            } else if (luaState.type(1) == LuaType.TABLE) {
                // traverse and validate all the options
                for (luaState.pushNil(); luaState.next(2); luaState.pop(1)) {
                    String key = luaState.toString(-2);

                    switch (key) {
                        case "year":
                            if (luaState.type(-1) != LuaType.NUMBER) {
                                logMsg(ERROR_MSG, "time.year (number) expected, got " + luaState.typeName(-1));
                            }
                            break;
                        case "month":
                            if (luaState.type(-1) != LuaType.NUMBER) {
                                logMsg(ERROR_MSG, "time.month (number) expected, got " + luaState.typeName(-1));
                            }
                            break;
                        case "day":
                            if (luaState.type(-1) != LuaType.NUMBER) {
                                logMsg(ERROR_MSG, "time.day (number) expected, got " + luaState.typeName(-1));
                            }
                            break;
                        case "hour":
                            if (luaState.type(-1) != LuaType.NUMBER) {
                                logMsg(ERROR_MSG, "time.hour (number) expected, got " + luaState.typeName(-1));
                            }
                            break;
                        case "min":
                            if (luaState.type(-1) != LuaType.NUMBER) {
                                logMsg(ERROR_MSG, "time.min (number) expected, got " + luaState.typeName(-1));
                            }
                            break;
                        case "sec":
                            if (luaState.type(-1) != LuaType.NUMBER) {
                                logMsg(ERROR_MSG, "time.sec (number) expected, got " + luaState.typeName(-1));
                            }
                            break;
                        default:
                            logMsg(WARNING_MSG, "Invalid option '" + key + "'");
                            break;
                    }
                }
            } else {
                logMsg(ERROR_MSG, "time (number or table) expected, got " + luaState.typeName(1));
                return 0;
            }

            // check for options table
            if (!luaState.isNoneOrNil(2)) {
                if (luaState.type(2) == LuaType.TABLE) {
                    // traverse and validate all the options
                    for (luaState.pushNil(); luaState.next(2); luaState.pop(1)) {
                        String key = luaState.toString(-2);
                        switch (key) {
                            case "alert":
                                if (luaState.type(-1) != LuaType.STRING) {
                                    logMsg(ERROR_MSG, "options.alert (string) expected, got " + luaState.typeName(-1));
                                }
                                break;
                            case "badge":
                                if (luaState.type(-1) != LuaType.NUMBER) {
                                    logMsg(ERROR_MSG, "options.badge (number) expected, got " + luaState.typeName(-1));
                                }
                                break;
                            case "sound":
                                if (luaState.type(-1) != LuaType.STRING) {
                                    logMsg(ERROR_MSG, "options.sound (string) expected, got " + luaState.typeName(-1));
                                }
                                break;
                            case "custom":
                                if (luaState.type(-1) != LuaType.TABLE) {
                                    logMsg(ERROR_MSG, "options.custom (table) expected, got " + luaState.typeName(-1));
                                }
                                break;
                            default:
                                logMsg(WARNING_MSG, "Invalid option '" + key + "'");
                                break;
                        }
                    }
                } else {
                    logMsg(ERROR_MSG, "options table expected, got " + luaState.typeName(2));
                    return 0;
                }
            }

            return Bridge.scheduleNotification(luaState, 1);
        }
    }

    // [Lua] cancelNotification( [notificationId] )
    private class CancelNotification implements NamedJavaFunction {
        /**
         * Gets the name of the Lua function as it would appear in the Lua script.
         *
         * @return Returns the name of the custom Lua function.
         */
        @Override
        public String getName() {
            return "cancelNotification";
        }

        /**
         * This method is called when the Lua function is called.
         * <p>
         * Warning! This method is not called on the main UI thread.
         *
         * @param luaState Reference to the Lua state.
         *                 Needed to retrieve the Lua function's parameters and to return values back to Lua.
         * @return Returns the number of values to be returned by the Lua function.
         */
        @Override
        public int invoke(final LuaState luaState) {
            functionSignature = "notifications.cancelNotification( [notificationId] )";

            // check number of args
            int nargs = luaState.getTop();
            if (nargs > 1) {
                logMsg(ERROR_MSG, "Expected 0 or 1 arguments, got " + nargs);
                return 0;
            }

            // check the notificationId parameter
            if (!luaState.isNoneOrNil(1)) {
                if (luaState.type(1) != LuaType.NUMBER) {
                    logMsg(ERROR_MSG, "notificationId (number) expected, got " + luaState.typeName(1));
                }
            }

            if (luaState.isNoneOrNil(1)) {
                Bridge.cancelAllNotifications();
            } else {
                int id = Double.valueOf(luaState.toNumber(1)).intValue();
                Bridge.cancelNotification(id);
            }

            return 0;
        }
    }
}