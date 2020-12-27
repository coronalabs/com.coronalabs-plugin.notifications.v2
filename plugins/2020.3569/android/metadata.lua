local metadata =
{
    plugin =
    {
        format = 'jar',
        
        manifest = 
        {
            permissions = {},
            usesPermissions = {},
            usesFeatures = {},

            applicationChildElements =
            {
                [[
                    <service
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
