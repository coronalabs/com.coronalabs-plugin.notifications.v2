//
//  NotificationsV2Plugin.mm
//  Notifications V2 Plugin
//
//  Copyright (c) 2017 Corona Labs Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "CoronaRuntime.h"
#import "CoronaAssert.h"
#import "CoronaEvent.h"
#import "CoronaLua.h"
#import "CoronaLibrary.h"
#import "CoronaLuaIOS.h"

// Local and Firebase Messaging
#import "NotificationsV2Plugin.h"
#import "IPhoneNotificationEvent.h"
#import "CoronaNotificationsV2Helper.h"
#if PLUGIN_FIREBASE
#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseMessaging/FirebaseMessaging.h>
#endif
#import <UserNotifications/UserNotifications.h> // iOS 10+

// some macros to make life easier, and code more readable
#define UTF8StringWithFormat(format, ...) [[NSString stringWithFormat:format, ##__VA_ARGS__] UTF8String]
#define UTF8IsEqual(utf8str1, utf8str2) (strcmp(utf8str1, utf8str2) == 0)
#define MsgFormat(format, ...) [NSString stringWithFormat:format, ##__VA_ARGS__]

// ----------------------------------------------------------------------------
// Plugin Constants
// ----------------------------------------------------------------------------

static const char NOTIFICATION_METATABLE[] = "notification";

// message constants
static NSString * const ERROR_MSG   = @"ERROR: ";

static BOOL pluginDidInit = NO;

// ----------------------------------------------------------------------------
// plugin class and delegate definitions
// ----------------------------------------------------------------------------

#if PLUGIN_FIREBASE
@interface CoronaNotificationsPluginDelegate: NSObject <FIRMessagingDelegate, UNUserNotificationCenterDelegate>
#else
@interface CoronaNotificationsPluginDelegate: NSObject <UNUserNotificationCenterDelegate>
#endif

@property (nonatomic, assign) id<CoronaRuntime> coronaRuntime;         // Pointer to the Corona runtime
@end

// ----------------------------------------------------------------------------

class NotificationsV2Plugin
{
	public:
        typedef NotificationsV2Plugin Self;

	public:
        static const char kName[];
		
	public:
        static int Open( lua_State *L );
        static int Finalizer( lua_State *L );
        static Self *ToLibrary( lua_State *L );

	protected:
        NotificationsV2Plugin();
        bool Initialize( void *platformContext );
		
	public: // plugin API
        static int registerForPushNotifications( lua_State *L );
        static int getDeviceToken( lua_State *L );
        static int scheduleNotification( lua_State *L );
        static int cancelNotification( lua_State *L );
        static int subscribe( lua_State *L );
        static int unsubscribe( lua_State *L );
        static int areNotificationsEnabled( lua_State *L ); // New Function

    private: // internal helper functions
        static void logMsg( lua_State *L, NSString *msgType,  NSString *errorMsg );

	private:
        NSString *functionSignature;                                // used in logMsg to identify function
        UIViewController *coronaViewController;                     // application's view controller
};

const char NotificationsV2Plugin::kName[] = PLUGIN_NAME;
CoronaNotificationsPluginDelegate *notificationsPluginDelegate;       // Notifications V2 delegate

static bool isFirebaseLinked() {
#if PLUGIN_FIREBASE
	return true;
#else
	return false;
#endif
}
// ----------------------------------------------------------------------------
// helper functions
// ----------------------------------------------------------------------------

static int
NotificationTypeForString( const char *value )
{
    int result;

    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_9_x_Max) {
        result = UIUserNotificationTypeNone;
        
        if ( UTF8IsEqual(value, "badge") ) {
            result = UIUserNotificationTypeBadge;
        }
        else if ( UTF8IsEqual(value, "sound") ) {
            result = UIUserNotificationTypeSound;
        }
        else if ( UTF8IsEqual(value, "alert") ) {
            result = UIUserNotificationTypeAlert;
        }
    }
    else { // iOS 10 or later
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
        result = UNAuthorizationOptionNone;
        
        if ( UTF8IsEqual(value, "badge") ) {
            result = UNAuthorizationOptionBadge;
        }
        else if ( UTF8IsEqual(value, "sound") ) {
            result = UNAuthorizationOptionSound;
        }
        else if ( UTF8IsEqual(value, "alert") ) {
            result = UNAuthorizationOptionAlert;
        }
#endif
    }
    
    return result;
}

// log message to console
void
NotificationsV2Plugin::logMsg(lua_State *L, NSString* msgType, NSString* errorMsg)
{
    Self *context = ToLibrary(L);
    
    if (context) {
        Self& library = *context;
        
        NSString *functionID = [library.functionSignature copy];
        if (functionID.length > 0) {
            functionID = [functionID stringByAppendingString:@", "];
        }

        CoronaLuaLogPrefix(L, [msgType UTF8String], UTF8StringWithFormat(@"%@%@", functionID, errorMsg));
    }
}

// ----------------------------------------------------------------------------
// plugin implementation
// ----------------------------------------------------------------------------

int
NotificationsV2Plugin::Open( lua_State *L )
{
	// Register __gc callback
	const char kMetatableName[] = __FILE__; // Globally unique string to prevent collision
	CoronaLuaInitializeGCMetatable( L, kMetatableName, Finalizer );
	
	void *platformContext = CoronaLuaGetContext(L);

	// Set library as upvalue for each library function
	Self *library = new Self;

	if (library->Initialize(platformContext)) {
		// Functions in library
		static const luaL_Reg kFunctions[] = {
            {"registerForPushNotifications", registerForPushNotifications},
            {"scheduleNotification", scheduleNotification},
            {"cancelNotification", cancelNotification},
            {"getDeviceToken", getDeviceToken},
            {"subscribe", subscribe},
            {"unsubscribe", unsubscribe},
            {"areNotificationsEnabled", areNotificationsEnabled}, // New Function
			{NULL, NULL}
        };

		// Register functions as closures, giving each access to the
		// 'library' instance via ToLibrary()
		{
			CoronaLuaPushUserdata(L, library, kMetatableName);
			luaL_openlib(L, kName, kFunctions, 1); // leave "library" on top of stack
		}
	}

	return 1;
}

// New method to check if notifications are enabled
int
NotificationsV2Plugin::areNotificationsEnabled(lua_State *L)
{
    Self *context = ToLibrary(L);
    
    if (!context) {
        return 0;
    }
    
    Self& library = *context;
    
    library.functionSignature = @"notifications.areNotificationsEnabled()";
    
    __block BOOL enabled = NO;
    
    if (@available(iOS 10.0, *)) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            enabled = (settings.authorizationStatus == UNAuthorizationStatusAuthorized);
            dispatch_semaphore_signal(semaphore);
        }];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    } else {
        // Fallback for iOS 9 and lower
        UIUserNotificationSettings *settings = [[UIApplication sharedApplication] currentUserNotificationSettings];
        enabled = (settings.types != UIUserNotificationTypeNone);
    }
    
    lua_pushboolean(L, enabled);
    return 1;
}

int
NotificationsV2Plugin::Finalizer( lua_State *L )
{
    Self *library = (Self *)CoronaLuaToUserdata(L, 1);
    
    notificationsPluginDelegate = nil;
    delete library;
    
	return 0;
}

NotificationsV2Plugin*
NotificationsV2Plugin::ToLibrary( lua_State *L )
{
	// library is pushed as part of the closure
	Self *library = (Self *)CoronaLuaToUserdata( L, lua_upvalueindex( 1 ) );
	return library;
}

NotificationsV2Plugin::NotificationsV2Plugin()
: coronaViewController(nil)
{
}

bool
NotificationsV2Plugin::Initialize( void *platformContext )
{
	bool shouldInit = ( ! coronaViewController );

	if ( shouldInit ) {
		id<CoronaRuntime> runtime = (__bridge id<CoronaRuntime>)platformContext;
		coronaViewController = runtime.appViewController;
        
        functionSignature = @"";
        
        // initialize delegate
        notificationsPluginDelegate = [CoronaNotificationsPluginDelegate new];
        notificationsPluginDelegate.coronaRuntime = runtime;
	}

	return shouldInit;
}

// [Lua] registerForPushNotifications( [ options ] )
int
NotificationsV2Plugin::registerForPushNotifications(lua_State *L)
{
    Self *context = ToLibrary(L);
    
    if (! context) { // abort if no valid context
        return 0;
    }
    
    Self& library = *context;
    
    library.functionSignature = @"notifications.registerForPushNotifications( [ options ] )";
    
    // check number or args
    int nargs = lua_gettop(L);
    if (nargs > 1) {
        logMsg(L, ERROR_MSG, MsgFormat(@"Expected 0 or 1 argument, got %d", nargs));
        return 0;
    }
    
    if (pluginDidInit) {
        logMsg(L, ERROR_MSG, @"notifications V2 already initialized");
        return 0;
    }
    
    bool useFCM = false;
    
    // check for options table
    if (! lua_isnoneornil(L, 1)) {
        if (lua_type(L, 1) == LUA_TTABLE) {
            // traverse and validate all the options
            for (lua_pushnil(L); lua_next(L, 1) != 0; lua_pop(L, 1)) {
                const char *key = lua_tostring(L, -2);
                
                // check for FCM usage (for backward compatibility)
                if (UTF8IsEqual(key, "useFCM")) {
                    if (lua_type(L, -1) == LUA_TBOOLEAN) {
                        useFCM = lua_toboolean(L, -1);
                        if(useFCM && !isFirebaseLinked()) {
							logMsg(L, ERROR_MSG, MsgFormat(@"options.useFCM is true but no Firebase framework is linked!"));
							useFCM = false;
						}
                    }
                    else {
                        logMsg(L, ERROR_MSG, MsgFormat(@"options.useFCM (boolean) expected, got %s", luaL_typename(L, -1)));
                        return 0;
                    }
                }
                else {
                    logMsg(L, ERROR_MSG, MsgFormat(@"Invalid option '%s'", key));
                    return 0;
                }
            }
        }
        else {
            logMsg(L, ERROR_MSG, MsgFormat(@"options table expected, got %s", luaL_typename(L, 1)));
            return 0;
        }
    }
    
    // set FCM usage (for backwards compatibility with legacy plugin).
    // when false, only the APNs token will be reported in the registration event
    [[CoronaNotificationsV2Helper shared] setUseFCM:useFCM];

#if PLUGIN_FIREBASE
    if (useFCM) {
		
        // get options from plist generated by Firebase
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"GoogleService-Info" ofType:@"plist"];
        FIROptions *firOptions = [[FIROptions alloc] initWithContentsOfFile:filePath];
        if (firOptions == nil) {
            logMsg(L, ERROR_MSG, @"Cannot find GoogleService-Info.plist");
            return 0;
        }
    
        // configure and connect
        if([FIRApp defaultApp] == NULL){
            [FIRApp configureWithOptions:firOptions];
        }
    }
#endif
    
    // Looks in config.lua to see if the following table exists:
    //	application =
    //	{
    //		notification =
    //		{
    //			iphone =
    //			{
    //				types =
    //				{
    //					"badge",
    //					"sound",
    //					"alert"
    //				}
    //			},
    //		},
    //	}
    
    int allowedTypes = 0;
    
    // check if config has been loaded before
    lua_getglobal( L, "package" );
    lua_getfield( L, -1, "loaded" );
    lua_getfield( L, -1, "config" );
    bool userLoadedConfig = lua_type( L, -1 ) != LUA_TNIL;
    lua_pop( L, 3 );
    
    // load config
    lua_getglobal( L, "require" );
    lua_pushstring( L, "config" );
    lua_call( L, 1, 0 );
    
    // read config
    lua_getglobal( L, "application" );
    if ( lua_type( L, -1 ) == LUA_TTABLE )
    {
        lua_getfield( L, -1, "notification" );
        if ( lua_type( L, -1 ) == LUA_TTABLE )
        {
            lua_getfield( L, -1, "iphone" );
            if ( lua_type( L, -1 ) == LUA_TTABLE )
            {
                lua_getfield( L, -1, "types" );
                if ( lua_type( L, -1 ) == LUA_TTABLE )
                {
                    int configTypes = lua_gettop( L );
                    size_t maxTypes = lua_objlen( L, -1 );
                    
                    for ( int i = 1; i <= maxTypes; i++ ) {
                        lua_rawgeti( L, configTypes, i );
                        int notificationType = NotificationTypeForString( lua_tostring( L, -1 ) );
                        allowedTypes = ( allowedTypes | notificationType );
                        lua_pop( L, 1 );
                    }
                }
                lua_pop( L, 1 ); // pop types
            }
            lua_pop( L, 1 ); // pop iphone
        }
        lua_pop( L, 1 ); // pop notification
    }
    lua_pop( L, 1 ); // pop application
   
    // Clean up but make sure that if require("config") was already called it won't wipe it out
    if ( ! userLoadedConfig ) {
        // set application = nil
        lua_pushnil( L );
        lua_setglobal( L, "application" );

        // set package.loaded.config = nil
        lua_getglobal( L, "package" );
        lua_getfield( L, -1, "loaded" );
        lua_pushnil( L );
        lua_setfield( L, -2, "config" );
        lua_pop( L, 2 );
    }

    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_9_x_Max) {
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:allowedTypes categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    }
    else { // iOS 10 or later
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
        [[UNUserNotificationCenter currentNotificationCenter]
         requestAuthorizationWithOptions:allowedTypes
         completionHandler:^(BOOL granted, NSError * _Nullable error) {
             if (granted) {
                 NSLog(@"UNUserNotificationCenter permissions granted");
             }
             else {
                 NSLog(@"UNUserNotificationCenter permissions NOT GRANTED");
             }
         }
         ];
        
        [UNUserNotificationCenter currentNotificationCenter].delegate = notificationsPluginDelegate;
	#if PLUGIN_FIREBASE
        [FIRMessaging messaging].delegate = notificationsPluginDelegate;
	#endif
#endif
    }
    
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    
    return 0;
}

// [Lua] getDeviceToken()
int
NotificationsV2Plugin::getDeviceToken(lua_State *L)
{
    Self *context = ToLibrary(L);
    
    if (! context) { // abort if no valid context
        return 0;
    }
    
    Self& library = *context;
    
    library.functionSignature = @"notifications.getDeviceToken()";
    
    // check number or args
    int nargs = lua_gettop(L);
    if ((nargs != 0)) {
        logMsg(L, ERROR_MSG, MsgFormat(@"Expected no arguments, got %d", nargs));
        return 0;
    }
    
    NSString *token = nil;
    
    if ([[CoronaNotificationsV2Helper shared] useFCM]) {
#if PLUGIN_FIREBASE
        token = [[FIRMessaging messaging] FCMToken];
#endif
    }
    else {
        token = [[CoronaNotificationsV2Helper shared] APNsToken];
    }
    
    lua_pushstring(L, token == nil ? "unknown" : [token UTF8String]);
    
    return 1;
}

// [Lua] subscribe( topic )
int
NotificationsV2Plugin::subscribe(lua_State *L)
{
    Self *context = ToLibrary(L);
    
    if (! context) { // abort if no valid context
        return 0;
    }
    
    Self& library = *context;
    
    library.functionSignature = @"notifications.subscribe( topic )";
    
    // check number or args
    int nargs = lua_gettop(L);
    if ((nargs != 1)) {
        logMsg(L, ERROR_MSG, MsgFormat(@"Expected 1 argument, got %d", nargs));
        return 0;
    }
    
    const char *topic = NULL;
    
    // check topic
    if ( lua_type( L, 1 ) == LUA_TSTRING ) {
        topic = lua_tostring( L, 1 );
    }
    else {
        logMsg( L, ERROR_MSG, MsgFormat(@"options.topic (string) expected, got %s", luaL_typename( L, 1 )));
        return 0;
    }
    
#if PLUGIN_FIREBASE
    [[FIRMessaging messaging] subscribeToTopic:@(topic)];
#else
    logMsg( L, ERROR_MSG, @"notification.subscribe only work in Firebase plugin");
#endif
    
    return 0;
}

// [Lua] unsubscribe( topic )
int
NotificationsV2Plugin::unsubscribe(lua_State *L)
{
    Self *context = ToLibrary(L);
    
    if (! context) { // abort if no valid context
        return 0;
    }
    
    Self& library = *context;
    
    library.functionSignature = @"notifications.unsubscribe( topic )";
    
    // check number or args
    int nargs = lua_gettop(L);
    if ((nargs != 1)) {
        logMsg(L, ERROR_MSG, MsgFormat(@"Expected 1 argument, got %d", nargs));
        return 0;
    }
    
    const char *topic = NULL;
    
    // check for topic
    if ( lua_type( L, 1 ) == LUA_TSTRING ) {
        topic = lua_tostring( L, 1 );
    }
    else {
        logMsg( L, ERROR_MSG, MsgFormat(@"options.topic (string) expected, got %s", luaL_typename( L, 1 )));
        return 0;
    }
    
#if PLUGIN_FIREBASE
    [[FIRMessaging messaging] unsubscribeFromTopic:@(topic)];
#else
    logMsg( L, ERROR_MSG, @"notifications.unsubscribe only work in Firebase plugin");
#endif
    
    return 0;
}

// [Lua] scheduleNotification()
int
NotificationsV2Plugin::scheduleNotification(lua_State *L)
{
    Self *context = ToLibrary(L);
    
    if (! context) { // abort if no valid context
        return 0;
    }
    
    Self& library = *context;
    
    library.functionSignature = @"notifications.scheduleNotification(time [,options])";
    
    // check number or args
    int nargs = lua_gettop(L);
    if ((nargs < 1) || (nargs > 2)) {
        logMsg(L, ERROR_MSG, MsgFormat(@"Expected 1 or 2 arguments, got %d", nargs));
        return 0;
    }

    UILocalNotification *notification = IPhoneLocalNotificationEvent::CreateAndSchedule( L, 1 );
    int allowedNotificationTypes = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
    Class cls = NSClassFromString(@"UIUserNotificationSettings");
    id settings = [cls settingsForTypes:allowedNotificationTypes categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    [[UIApplication sharedApplication] scheduleLocalNotification:notification];
    
    if ( notification ) {
        NSLog(@"we have a notification");
        CoronaLuaPushUserdata( L, (void *)CFBridgingRetain(notification), NOTIFICATION_METATABLE );
    }
    else {
        lua_pushnil( L );
    }
    
    return 1;
}

// [Lua] cancelNotification()
int
NotificationsV2Plugin::cancelNotification( lua_State *L )
{
    Self *context = ToLibrary( L );
    
    if (! context) { // abort if no valid context
        return 0;
    }
    
    Self& library = *context;
    
    library.functionSignature = @"notifications.cancelNotification( time [, options ])";
    
    // check number or args
    int nargs = lua_gettop( L );
    if ( nargs > 1 ) {
        logMsg( L, ERROR_MSG, MsgFormat( @"Expected 0 or 1 argument, got %d", nargs ));
        return 0;
    }
    
    if ( lua_isuserdata( L, 1 ) || lua_isnoneornil( L, 1 )) {
        void *notificationId = lua_isnone( L, 1 ) ? NULL : CoronaLuaCheckUserdata( L, 1, NOTIFICATION_METATABLE );
        
        UIApplication *application = [UIApplication sharedApplication];
        
        if ( notificationId ) {
            UILocalNotification *notification = (__bridge UILocalNotification *) notificationId;
            [application cancelLocalNotification: notification];
        }
        else {
            [application cancelAllLocalNotifications];
            application.applicationIconBadgeNumber = 0;
        }
    }
    
    return 0;
}

// ============================================================================
// plugin delegate implementation
// ============================================================================

@implementation CoronaNotificationsPluginDelegate
/*
//TODO: Migrate to modern notifications for iOS10+

// Receive displayed notifications for iOS 10 devices.
// Handle incoming notification messages while app is in the foreground.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
	   willPresentNotification:(UNNotification *)notification
		 withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
	
	NSDictionary *userInfo = [[[notification request] content] userInfo];
	if(userInfo) {
		if([notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
			
			IPhoneRemoteNotificationEvent event(
												userInfo,
												IPhoneNotificationEvent::ToApplicationState( [UIApplication sharedApplication].applicationState )
												);
			event.Dispatch( self.coronaRuntime.L );
			
#if PLUGIN_FIREBASE
			[[FIRMessaging messaging] appDidReceiveMessage:userInfo];
#endif
		} else {
			IPhoneLocalNotificationEvent event(
											   notification,
											   IPhoneNotificationEvent::ToApplicationState( [UIApplication sharedApplication].applicationState )
											   );
			event.Dispatch( self.coronaRuntime.L );
		}
	}
	
	// Change this to your preferred presentation option
	completionHandler(UNNotificationPresentationOptionBadge | UNNotificationPresentationOptionAlert);
}

// Handle notification messages after display notification is tapped by the user.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
		 withCompletionHandler:(void(^)(void))completionHandler {
	NSDictionary *userInfo = [[[[response notification] request] content ] userInfo];
	
	if(userInfo) {
		IPhoneRemoteNotificationEvent event(
											userInfo,
											IPhoneNotificationEvent::ToApplicationState( [UIApplication sharedApplication].applicationState )
											);
		event.Dispatch( self.coronaRuntime.L );
		
#if PLUGIN_FIREBASE
		[[FIRMessaging messaging] appDidReceiveMessage:userInfo];
#endif
	}

	completionHandler();
}
*/

#if PLUGIN_FIREBASE


- (void)messaging:(FIRMessaging *)messaging didReceiveRegistrationToken:(NSString *)fcmToken {
    if ([[CoronaNotificationsV2Helper shared] useFCM]) {
        // abort if no token
        if (fcmToken == nil) {
            return;
        }
        
        // send Corona Lua event
        IPhoneRemoteNotificationRegistrationEvent event( fcmToken );
        event.Dispatch(	self.coronaRuntime.L );
    }
}
#endif

@end

// ----------------------------------------------------------------------------

CORONA_EXPORT int luaopen_plugin_notifications_v2( lua_State *L )
{
    return NotificationsV2Plugin::Open(L);
}

#if PLUGIN_FIREBASE
CORONA_EXPORT int luaopen_plugin_notifications_v2_firebase( lua_State *L )
{
    return NotificationsV2Plugin::Open(L);
}
#endif
