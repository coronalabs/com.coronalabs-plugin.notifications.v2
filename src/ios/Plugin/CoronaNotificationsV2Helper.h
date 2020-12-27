//
//  CoronaNotificationsV2Helper.h
//  Notifications V2 Plugin
//
// (C) Corona Labs 2017
//

#import <Foundation/Foundation.h>

#define PLUGIN_NAME    "plugin.notifications.v2"      // used for plugin name / Corona Beacon
#define PLUGIN_VERSION "1.0.1"                        // used for Corona Beacon


@interface CoronaNotificationsV2Helper : NSObject
{
    NSString *APNsToken;
    BOOL useFCM;
}

@property (nonatomic, copy) NSString *APNsToken;    // save APNs token for future use
@property (nonatomic, assign) BOOL useFCM;          // when false, the APNs token will be reported instead on FCM token

+ (instancetype)shared;

@end
