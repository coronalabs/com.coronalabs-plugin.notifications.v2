//
//  CoronaNotificationsV2Helper.mm
//  Notifications V2 Plugin
//
// (C) Corona Labs 2017
//

#import "CoronaNotificationsV2Helper.h"

@implementation CoronaNotificationsV2Helper

@synthesize APNsToken;
@synthesize useFCM;

+ (instancetype)shared
{
    static CoronaNotificationsV2Helper *helper = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        helper = [[self alloc] init];
    });
    
    return helper;
}

- (instancetype)init {
    if (self = [super init]) {
        self.APNsToken = nil;
        self.useFCM = NO;
    }
    
    return self;
}

@end
