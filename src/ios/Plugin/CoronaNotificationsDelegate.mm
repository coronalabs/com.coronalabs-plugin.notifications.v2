//
//  CoronaNotificationsDelegate.mm
//  Notifications V2 Plugin
//
//  Copyright (c) 2017 Corona Labs. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "CoronaNotificationsDelegate.h"
#import "CoronaLua.h"
#import "CoronaRuntime.h"

#import "IPhoneNotificationEvent.h"
#import "CoronaNotificationsV2Helper.h"
#if PLUGIN_FIREBASE
#import <FirebaseMessaging/FirebaseMessaging.h>
#endif
static int
SetLaunchArgs( UIApplication *application, NSDictionary *launchOptions, lua_State *L )
{
    int itemsPushed = 0;
    UILocalNotification *localNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    if ( localNotification )
    {
        IPhoneLocalNotificationEvent e(
                                       localNotification, IPhoneNotificationEvent::ToApplicationState( application.applicationState ) );
        e.Push( L );
        itemsPushed = 1;
    }
    
    NSDictionary *remoteNotification =
        [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    
    if ( remoteNotification )
    {
        IPhoneRemoteNotificationEvent e(
                                        remoteNotification, IPhoneNotificationEvent::ToApplicationState( application.applicationState ) );
        e.Push( L );
        itemsPushed = 1;
    }
    
    return itemsPushed;
}
@implementation CoronaNotificationsDelegate
- (int)execute:(id<CoronaRuntime>)runtime command:(NSString*)command param:(id)param
{
    lua_State *L = runtime.L;
    int itemsPushed = 0;
    if ( [command isEqualToString:@"pushLaunchArgKey"] )
    {
        lua_pushstring( L, "notification" );
        itemsPushed = 1;
    }
    else if ( [command isEqualToString:@"pushLaunchArgValue" ] )
    {
        itemsPushed = SetLaunchArgs( [UIApplication sharedApplication], param, L);
    }
    return itemsPushed;
}
- (void)willLoadMain:(id<CoronaRuntime>)runtime
{
    // NOP
}

- (void)didLoadMain:(id<CoronaRuntime>)runtime
{
    _runtime = runtime;

    // log plugin version to device log
    NSLog(@"%s: %s", PLUGIN_NAME, PLUGIN_VERSION);
}

#pragma mark UIApplicationDelegate methods
-(void)applicationDidFinishLaunching:(UIApplication *)application
{
    
}

// didReceiveRemoteNotification is only called for iOS 9 or earlier
-(void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
#if PLUGIN_FIREBASE
    // must call appDidReceiveMessage manually since Firebase App Delegate Method Swizzling is disabled
    [[FIRMessaging messaging] appDidReceiveMessage:userInfo];
#endif
    // send Lua event
    IPhoneRemoteNotificationEvent event(
        userInfo,
        IPhoneNotificationEvent::ToApplicationState( application.applicationState )
    );
    event.Dispatch( self.runtime.L );
    
    if ( completionHandler ) {
        completionHandler( UIBackgroundFetchResultNewData );
    }
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    IPhoneLocalNotificationEvent event(
        notification,
        IPhoneNotificationEvent::ToApplicationState( application.applicationState )
    );
    event.Dispatch(	self.runtime.L );
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
#if PLUGIN_FIREBASE
    // must call appDidReceiveMessage manually since Firebase App Delegate Method Swizzling is disabled
    [[FIRMessaging messaging] appDidReceiveMessage:userInfo];
#endif

    IPhoneRemoteNotificationEvent event(
        userInfo,
        IPhoneNotificationEvent::ToApplicationState( application.applicationState )
    );
    event.Dispatch( self.runtime.L );
}

static NSString*
DataToHex( NSData *data )
{
    NSMutableString *result = [NSMutableString stringWithCapacity:([data length] * 2)];
    const unsigned char *buffer = (const unsigned char *)[data bytes];
    for ( int i = 0, iMax = (int)[data length]; i < iMax; i++ ) {
        [result appendFormat:@"%02lx", (unsigned long)buffer[i]];
    }
    
    return result;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSString *data = DataToHex( deviceToken );
    [[CoronaNotificationsV2Helper shared] setAPNsToken:data];
    if ([[CoronaNotificationsV2Helper shared] useFCM]) {
#if PLUGIN_FIREBASE
        // must call setAPNSToken manually since Firebase App Delegate Method Swizzling is disabled
        // FIRInstanceIDAPNSTokenTypeUnknown will determine Sandbox-type or Production-type based on the provisioning profile
        [[FIRMessaging messaging] setAPNSToken:deviceToken type:FIRMessagingAPNSTokenTypeUnknown];
#endif
    }
    else {
        IPhoneRemoteNotificationRegistrationEvent event( data );
        event.Dispatch(self.runtime.L);
    }
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    NSLog(@"CoronaNotificationsDelegate.mm: didFailToRegisterForRemoteNotificationsWithError: %@", [error localizedDescription]);
    IPhoneRemoteNotificationRegistrationEvent event( error );
    event.Dispatch(	self.runtime.L );
}

@end
