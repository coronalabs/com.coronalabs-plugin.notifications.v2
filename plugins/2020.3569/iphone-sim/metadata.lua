local metadata =
{
	plugin =
	{
		format = "staticLibrary",
		staticLibs = { 'NotificationsV2Plugin',   }, 
		frameworks = { 'GoogleUtilities', 'protobuf', 'FBLPromises', 'FirebaseInstanceID', 'FirebaseMessaging', 'FirebaseInstallations', 'FirebaseCore', },
		frameworksOptional = { "UserNotifications", "UserNotificationsUI" },
		delegates = { "CoronaNotificationsDelegate" }
	}
}

return metadata
