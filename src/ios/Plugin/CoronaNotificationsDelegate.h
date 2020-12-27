//
//  CoronaNotificationsDelegate.h
//  Notifications V2 Plugin
//
//  Copyright (c) 2017 Corona Labs. All rights reserved.
//

#ifndef _CoronaNotificationsDelegate_H__
#define _CoronaNotificationsDelegate_H__

#import "CoronaDelegate.h"
#import "CoronaLua.h"

@interface CoronaNotificationsDelegate : NSObject<CoronaDelegate>

@property(strong) id<CoronaRuntime> runtime;

@end

#endif // _CoronaNotificationsDelegate_H__
