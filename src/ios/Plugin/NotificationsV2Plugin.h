//
//  NotificationsV2Plugin.h
//  Notifications V2 Plugin
//
//  Copyright (c) 2017 Corona Labs Inc. All rights reserved.
//

#ifndef NotificationsV2Plugin_H
#define NotificationsV2Plugin_H

#import "CoronaLua.h"
#import "CoronaMacros.h"

// This corresponds to the name of the library, e.g. [Lua] require "plugin.library"
// where the '.' is replaced with '_'
CORONA_EXPORT int luaopen_plugin_notifications_v2( lua_State *L );
#if PLUGIN_FIREBASE
CORONA_EXPORT int luaopen_plugin_notifications_v2_firebase( lua_State *L );
#endif

#endif // NotificationsV2Plugin_H
