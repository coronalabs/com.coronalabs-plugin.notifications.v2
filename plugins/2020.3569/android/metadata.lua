local metadata =
{
    plugin =
    {
        format = 'jar',

        manifest =
        {
            permissions = {},
            usesPermissions = {
              "android.permission.SCHEDULE_EXACT_ALARM"--Needed for Local Notifications
            },
            usesFeatures = {},

            applicationChildElements =
            {
                [[
                    <service android:exported="true"
                        android:name="plugin.notifications.v2.CoronaFirebaseMessagingService">
                        <intent-filter>
                            <action android:name="com.google.firebase.MESSAGING_EVENT"/>
                        </intent-filter>
                    </service>
                ]]
            }
        }
    },

    coronaManifest = {
        dependencies = {
            ["shared.firebase.messaging"] = "com.coronalabs"
        }
    }
}

return metadata
