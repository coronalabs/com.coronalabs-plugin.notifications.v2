local metadata =
{
	plugin =
	{
		format = "staticLibrary",
		staticLibs = { 'NotificationsV2Plugin',   }, 
		frameworks = { },
		frameworksOptional = { "UserNotifications", "UserNotificationsUI" },
		delegates = { "CoronaNotificationsDelegate" }
	}
}


return metadata
