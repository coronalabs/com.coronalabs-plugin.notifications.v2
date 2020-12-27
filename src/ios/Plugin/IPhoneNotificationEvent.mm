//
// IPhoneNotificationEvent.mm
// Copyright (c) 2017 Corona Labs, Inc. All rights reserved.
// 

#import <UIKit/UILocalNotification.h>
#import "IPhoneNotificationEvent.h"

#import "CoronaLua.h"
#import "CoronaLuaIOS.h"

// ----------------------------------------------------------------------------


static void
SetStringField( lua_State *L, int index, const char *dstKey, id srcObject, NSString *srcKey )
{
	id value = [srcObject valueForKey:srcKey];
	if ( [value isKindOfClass:[NSString class]] ) {
		const char *str = [(NSString*)value UTF8String];
		if ( str ) {
			lua_pushstring( L, str );
			lua_setfield( L, index, dstKey );
		}
	}
    else if ( [value isKindOfClass:[NSDictionary class]] ){
        if ( CoronaLuaPushValue( L, (NSDictionary *)value ) > 0 ) {
            lua_setfield( L, index, dstKey );
        }
    }
}

NotificationEvent::ApplicationState
IPhoneNotificationEvent::ToApplicationState( UIApplicationState state )
{
	NotificationEvent::ApplicationState result = NotificationEvent::kBackground;

	switch ( state )
	{
		case UIApplicationStateActive:
			result = NotificationEvent::kActive;
			break;
		case UIApplicationStateInactive:
			result = NotificationEvent::kInactive;
			break;
		default:
			break;
	}

	return result;
}

// ----------------------------------------------------------------------------

IPhoneNotificationEvent::IPhoneNotificationEvent( Type t, ApplicationState state, id notification )
:	Super( t, state ),
	fNotification( notification )
{
}

IPhoneNotificationEvent::~IPhoneNotificationEvent()
{
}

// ----------------------------------------------------------------------------

UILocalNotification*
IPhoneLocalNotificationEvent::CreateAndSchedule( lua_State *L, int index )
{
	UILocalNotification *notification = [[UILocalNotification alloc] init];
	NSDate *fireTime = nil;

	// Get fire time
	if ( lua_istable( L, index ) )
	{
		NSDateComponents *components = [[NSDateComponents alloc] init];
		NSDate *now = [NSDate date];
		NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
		NSDateComponents *nowComp = [gregorian components:(NSCalendarUnitYear | NSCalendarUnitMonth |  NSCalendarUnitDay ) fromDate:now];

		NSTimeZone *timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
		[gregorian setTimeZone:timeZone];

		lua_getfield( L, index, "year" );
		[components setYear: lua_isnumber( L, -1 ) ? lua_tointeger( L, -1 ) : [nowComp year]];
		lua_pop( L, 1 );

		lua_getfield( L, index, "month" );
		lua_Integer month = lua_tointeger( L, -1 );
		if ( month <= 0 || month > 12 )
		{
			month = [nowComp month];
		}
		[components setMonth:month];
		lua_pop( L, 1 );

		lua_getfield( L, index, "day" );
		[components setDay: lua_isnumber( L, -1 ) ? lua_tointeger( L, -1 ) : [nowComp day]];
		lua_pop( L, 1 );

		lua_getfield( L, index, "hour" );
		[components setHour: lua_tointeger( L, -1 )];
		lua_pop( L, 1 );

		lua_getfield( L, index, "min" );
		[components setMinute: lua_tointeger( L, -1 )];
		lua_pop( L, 1 );

		lua_getfield( L, index, "sec" );
		[components setSecond: lua_tointeger( L, -1 )];
		lua_pop( L, 1 );

		fireTime = [gregorian dateFromComponents:components];
	}
	else if ( LUA_TNUMBER == lua_type( L, index ) )
	{
		fireTime = [NSDate dateWithTimeIntervalSinceNow:lua_tonumber( L, index )];
	}
	else
	{
		luaL_typerror( L, index, "number or table" );
	}

	notification.fireDate = fireTime;

	// Move to next argument
	++index;
	if ( lua_istable( L, index ) )
	{
		lua_getfield( L, index, "alert" );
		const char *body = lua_tostring( L, -1 );
		if ( body )
		{
			notification.alertBody = [NSString stringWithUTF8String:body];
		}
		else if ( lua_istable( L, -1 ) )
		{
			lua_getfield( L, -1, "body" );
			body = lua_tostring( L, -1 );
			if ( body )
			{
				notification.alertBody = [NSString stringWithUTF8String:body];
			}
			lua_pop( L, 1 );

			lua_getfield( L, -1, "action" );
			const char *action = lua_tostring( L, -1 );
			if ( action )
			{
				notification.alertAction = [NSString stringWithUTF8String:action];
			}
			lua_pop( L, 1 );

			lua_getfield( L, -1, "launchImage" );
			const char *launchImage = lua_tostring( L, -1 );
			if ( launchImage )
			{
				notification.alertLaunchImage = [NSString stringWithUTF8String:launchImage];
			}
			lua_pop( L, 1 );			
		}
		lua_pop( L, 1 );

		// if tonumber "fails", it returns 0, which means "no change"
		lua_getfield( L, index, "badge" );
		notification.applicationIconBadgeNumber = lua_tonumber( L, -1 );
		lua_pop( L, 1 );

		lua_getfield( L, index, "sound" );
		const char *soundName = lua_tostring( L, -1 );
		if ( soundName )
		{
			notification.soundName = [NSString stringWithUTF8String:soundName];
		}
		lua_pop( L, 1 );		

		lua_getfield( L, index, "custom" );
		if ( lua_istable( L, -1 ) )
		{
			int index = lua_gettop( L );
			NSDictionary *custom = CoronaLuaCreateDictionary( L, index );
			notification.userInfo = custom;
		}
		lua_pop( L, 1 );
	}

    return notification;
}


IPhoneLocalNotificationEvent::IPhoneLocalNotificationEvent( UILocalNotification *notification, ApplicationState state )
:	Super( Super::kLocal, state, notification )
{
}

int
IPhoneLocalNotificationEvent::Push( lua_State *L ) const
{
	if ( Super::Push( L ) )
	{
		UILocalNotification *notification = GetNotification();

		int index = lua_gettop( L );

		SetStringField( L, index, "alert", notification, @"alertBody" );
		SetStringField( L, index, "action", notification, @"alertAction" );
		SetStringField( L, index, "launchImage", notification, @"alertLaunchImage" );
		SetStringField( L, index, "sound", notification, @"soundName" );

		lua_pushinteger( L, notification.applicationIconBadgeNumber );
		lua_setfield( L, -2, "badge" );

		CoronaLuaPushValue( L, notification.userInfo );
		lua_setfield( L, -2, "custom" );
	}

	return 1;
}

// ----------------------------------------------------------------------------

IPhoneRemoteNotificationRegistrationEvent::IPhoneRemoteNotificationRegistrationEvent( NSString *token )
:	Super( Super::kRemoteRegistration, Super::kActive ), // App is active when registering for the event
    fToken(token != nil ? token : @"unknown"),
	fError( nil )
{
}

IPhoneRemoteNotificationRegistrationEvent::IPhoneRemoteNotificationRegistrationEvent( NSError *error )
:	Super( Super::kRemoteRegistration, Super::kActive ), // App is active when registering for the event
	fToken( nil ),
	fError( error )
{
}

IPhoneRemoteNotificationRegistrationEvent::~IPhoneRemoteNotificationRegistrationEvent()
{
}

int
IPhoneRemoteNotificationRegistrationEvent::Push( lua_State *L ) const
{
	if ( Super::Push( L ) )
	{
		if ( fToken )
		{
			NSString *data = fToken;
			lua_pushstring( L, [data UTF8String] );
			lua_setfield( L, -2, "token" );
		}
		else
		{
			lua_pushstring( L, [[fError localizedDescription] UTF8String] );
			lua_setfield( L, -2, "error" );
		}
	}

	return 1;
}

// ----------------------------------------------------------------------------

IPhoneRemoteNotificationEvent::IPhoneRemoteNotificationEvent( NSDictionary *notification, ApplicationState state )
:	Super( Super::kRemote, state, notification )
{
}

int
IPhoneRemoteNotificationEvent::Push( lua_State *L ) const
{
	if ( Super::Push( L )) {
		NSDictionary *receivedNotification = GetNotification();
        NSDictionary *notificationData = nil;
        NSDictionary *customDictionary = receivedNotification;
        
		int index = lua_gettop( L );
        BOOL isNotificationTypeMessage = NO;
        
        // check for notification-type message
        notificationData = [receivedNotification valueForKey:@"notification"];
        
        if ( notificationData != nil ) {
            isNotificationTypeMessage = YES;
        }
        else {
            // check for aps key (iOS 9 or earlier)
            notificationData = [receivedNotification valueForKey:@"aps"];
            
            // if no aps key found assume all keys are in the root of the recieved notification (iOS 10+)
            if ( notificationData == nil ) {
                notificationData = receivedNotification;
            }
            
            // check if this is a notification type message on iOS 9 or earlier
            isNotificationTypeMessage = [receivedNotification valueForKey:@"gcm.message_id"] != nil;
        }
        
        if ( isNotificationTypeMessage ) {
            if ( notificationData[@"body"] != nil ) {
                SetStringField( L, index, "alert", notificationData, @"body" );
            }
            else {
                SetStringField( L, index, "alert", notificationData, @"alert" );
            }
            SetStringField( L, index, "action", notificationData, @"action-loc-key" );
            SetStringField( L, index, "launchImage", notificationData, @"launch-image" );
            
            NSNumber *badge = [notificationData valueForKey:@"badge"];
            if ( badge ) {
                lua_pushinteger( L, [badge intValue] );
                lua_setfield( L, -2, "badge" );
            }
            
            SetStringField( L, index, "sound", notificationData, @"sound" );
            
            // build custom data
            NSMutableDictionary *notificationTypeCustomData = [NSMutableDictionary new];
            for (NSString *key in receivedNotification) {
                if (! [key isEqualToString:@"collapse_key"] &&
                    ! [key isEqualToString:@"notification"] &&
                    ! [key isEqualToString:@"from"] &&
                    ! [key isEqualToString:@"aps"] &&
                    ! [key hasPrefix:@"google."] &&
                    ! [key hasPrefix:@"gcm."]
                ) {
                    notificationTypeCustomData[key] = receivedNotification[key];
                }
            }
            
            if ( [notificationTypeCustomData count] > 0 ) {
                customDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:notificationTypeCustomData, @"custom", nil];
            }
        }
        else { // assume data-type message
            id alert = [notificationData valueForKey:@"alert"];
            if ( alert ) {
                if ( [alert isKindOfClass:[NSDictionary class]] ) {
                    SetStringField( L, index, "alert", alert, @"body" );
                    SetStringField( L, index, "action", alert, @"action-loc-key" );
                    SetStringField( L, index, "launchImage", alert, @"launch-image" );
                }
                else {
                    SetStringField( L, index, "alert", notificationData, @"alert" );
                }
            }

            NSNumber *badge = [notificationData valueForKey:@"badge"];
            if ( badge ) {
                lua_pushinteger( L, [badge intValue] );
                lua_setfield( L, -2, "badge" );
            }

            SetStringField( L, index, "sound", notificationData, @"sound" );
        }

		// This is to preserve backwards compatibility
		// We check and see if the custom field is in the main dictionary and
		// if it is we use that custom field, otherwise we set our custom field source
		// to the aps dictionary (which is how Android works and previous iOS functionality worked)
		if (! [customDictionary objectForKey:@"custom"]) {
			customDictionary = notificationData;
		}
		
		if ( CoronaLuaPushValue( L, [customDictionary valueForKey:@"custom"] ) > 0 ) {
			lua_setfield( L, -2, "custom" );
		}
		
		// This code allows us to convert the dictionary and push it to the listener in the case
		// new fields have been added
		NSError *error;
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:receivedNotification options:NSJSONWritingPrettyPrinted error:&error];
		if ( jsonData ) {
			NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
			lua_pushstring( L, [jsonString UTF8String] );
			lua_setfield( L, -2, "iosPayload" );
		}
	}

	return 1;
}

// ----------------------------------------------------------------------------

