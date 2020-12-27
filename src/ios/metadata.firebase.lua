local metadata =
{
	plugin =
	{
		format = 'staticLibrary',
		staticLibs = { 'NotificationsV2Plugin.firebase',   }, 
		frameworks = { 'FBLPromises', 'FirebaseCore', 'FirebaseCoreDiagnostics', 'FirebaseInstallations', 'FirebaseInstanceID', 'FirebaseMessaging', 'GoogleDataTransport', 'GoogleUtilities', 'nanopb', },
		frameworksOptional = { 'UserNotifications', 'UserNotificationsUI' },
		delegates = { 'CoronaNotificationsDelegate' }
	}
}

return metadata
