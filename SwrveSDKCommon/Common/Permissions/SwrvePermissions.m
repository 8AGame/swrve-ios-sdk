#import "SwrvePermissions.h"
#import "SwrveLocalStorage.h"
#if !defined(SWRVE_NO_PUSH) && TARGET_OS_IOS
#import <UserNotifications/UserNotifications.h>
#endif //!defined(SWRVE_NO_PUSH)

@implementation SwrvePermissions

+ (NSMutableDictionary *)permissionsStatusCache {
    static NSMutableDictionary *dic = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dic = [NSMutableDictionary new];

        // Load the push permission status from disk, as it is async and at the start of the app we won't have it on each run
        NSDictionary *savedState = [SwrveLocalStorage getPermissions];
        if (savedState != nil) {
            NSString *pushState = [savedState objectForKey:swrve_permission_push_notifications];
            if (pushState != nil) {
                [dic setValue:pushState forKey:swrve_permission_push_notifications];
            }
        }
    });
    return dic;
}

+(BOOL) processPermissionRequest:(NSString*)action withSDK:(id<SwrveCommonDelegate>)sdk {
#if !defined(SWRVE_NO_PUSH) && TARGET_OS_IOS
    if([action caseInsensitiveCompare:@"swrve.request_permission.ios.push_notifications"] == NSOrderedSame) {
        [SwrvePermissions requestPushNotifications:sdk provisional:NO];
        return YES;
    }
#else
#pragma unused(sdk)
#endif //!defined(SWRVE_NO_PUSH)
    if([action caseInsensitiveCompare:@"swrve.request_permission.ios.location.always"] == NSOrderedSame) {
        return [SwrvePermissions requestLocationAlways:sdk];
    }
    else if([action caseInsensitiveCompare:@"swrve.request_permission.ios.location.when_in_use"] == NSOrderedSame) {
        return [SwrvePermissions requestLocationWhenInUse:sdk];
    }
    if([action caseInsensitiveCompare:@"swrve.request_permission.ios.contacts"] == NSOrderedSame) {
        return [SwrvePermissions requestContacts:sdk];
    }
    if([action caseInsensitiveCompare:@"swrve.request_permission.ios.photos"] == NSOrderedSame) {
        return [SwrvePermissions requestPhotoLibrary:sdk];
    }
    if([action caseInsensitiveCompare:@"swrve.request_permission.ios.camera"] == NSOrderedSame) {
        return [SwrvePermissions requestCamera:sdk];
    }
    return NO;
}

+ (NSDictionary *)currentStatusWithSDK:(id<SwrveCommonDelegate>)sdk API_AVAILABLE(ios(7.0)) {
    NSMutableDictionary *permissionsStatus = [[NSMutableDictionary alloc] init];
    [permissionsStatus setValue:stringFromPermissionState([SwrvePermissions checkLocationAlways:sdk]) forKey:swrve_permission_location_always];
    [permissionsStatus setValue:stringFromPermissionState([SwrvePermissions checkLocationWhenInUse:sdk]) forKey:swrve_permission_location_when_in_use];
    [permissionsStatus setValue:stringFromPermissionState([SwrvePermissions checkPhotoLibrary:sdk]) forKey:swrve_permission_photos];
    [permissionsStatus setValue:stringFromPermissionState([SwrvePermissions checkCamera:sdk]) forKey:swrve_permission_camera];
    [permissionsStatus setValue:stringFromPermissionState([SwrvePermissions checkContacts:sdk]) forKey:swrve_permission_contacts];
#if !defined(SWRVE_NO_PUSH) && TARGET_OS_IOS
    NSString *pushAuthorization = [SwrvePermissions pushAuthorizationWithSDK:sdk];
    if (pushAuthorization) {
        [permissionsStatus setValue:pushAuthorization forKey:swrve_permission_push_notifications];
    }
    [SwrvePermissions bgRefreshStatusToDictionary:permissionsStatus];
#else
#pragma unused(sdk)
#endif //!defined(SWRVE_NO_PUSH)

    [SwrvePermissions updatePermissionsStatusCache:permissionsStatus];

    return permissionsStatus;
}

+ (void)updatePermissionsStatusCache:(NSMutableDictionary *)permissionsStatus {
    NSMutableDictionary *permissionsStatusCache = [SwrvePermissions permissionsStatusCache];

    @synchronized (permissionsStatusCache) {
        [permissionsStatusCache addEntriesFromDictionary:permissionsStatus];
    }
}

#if !defined(SWRVE_NO_PUSH) && TARGET_OS_IOS

+ (NSString *)pushAuthorizationWithSDK:(id<SwrveCommonDelegate>)sdk {
    return [SwrvePermissions pushAuthorizationWithSDK:sdk WithCallback:nil];
}

+ (NSString *)pushAuthorizationWithSDK:(id<SwrveCommonDelegate>)sdk WithCallback:(nullable void (^)(NSString * pushAuthorization)) callback {
    NSDictionary *permissionsCache = [SwrvePermissions permissionsStatusCache];
    __block NSString *pushAuthorization = (permissionsCache == nil)? nil : [permissionsCache objectForKey:swrve_permission_push_notifications];
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *_Nonnull settings) {

            NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
            NSString *pushAuthorizationFromSettings = swrve_permission_status_unknown;
            if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                pushAuthorizationFromSettings = swrve_permission_status_authorized;
            } else if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
                pushAuthorizationFromSettings = swrve_permission_status_denied;
            } else if (settings.authorizationStatus == UNAuthorizationStatusNotDetermined) {
                pushAuthorizationFromSettings = swrve_permission_status_unknown;
            } else if (@available(iOS 12.0, *)) {
                if (settings.authorizationStatus == UNAuthorizationStatusProvisional) {
                    pushAuthorizationFromSettings = swrve_permission_status_provisional;
                }
            } else {
                // Fallback on earlier versions
            }
            [dictionary setValue:pushAuthorizationFromSettings forKey:swrve_permission_push_notifications];
            [sdk mergeWithCurrentDeviceInfo:dictionary]; // send now
            pushAuthorization = pushAuthorizationFromSettings;
            [SwrvePermissions updatePermissionsStatusCache:dictionary];
            if (callback) {
                callback(pushAuthorizationFromSettings);
            }
        }];
    } else {
        DebugLog(@"Checking push auth not supported, should not reach this code", nil);
    }
    return pushAuthorization;
}

+ (void)bgRefreshStatusToDictionary:(NSMutableDictionary *)permissionsStatus API_AVAILABLE(ios(7.0)) {
    NSString *backgroundRefreshStatus = swrve_permission_status_unknown;
    UIBackgroundRefreshStatus uiBackgroundRefreshStatus = [[SwrveCommon sharedUIApplication] backgroundRefreshStatus];
    if (uiBackgroundRefreshStatus == UIBackgroundRefreshStatusAvailable) {
        backgroundRefreshStatus = swrve_permission_status_authorized;
    } else if (uiBackgroundRefreshStatus == UIBackgroundRefreshStatusDenied) {
        backgroundRefreshStatus = swrve_permission_status_denied;
    } else if (uiBackgroundRefreshStatus == UIBackgroundRefreshStatusRestricted) {
        backgroundRefreshStatus = swrve_permission_status_unknown;
    }
    [permissionsStatus setValue:backgroundRefreshStatus forKey:swrve_permission_push_bg_refresh];
}

#endif //!defined(SWRVE_NO_PUSH)

+ (void)compareStatusAndQueueEventsWithSDK:(id<SwrveCommonDelegate>)sdk {
    NSDictionary *lastStatus = [SwrveLocalStorage getPermissions];
    NSDictionary *currentStatus = [self currentStatusWithSDK:sdk];
    if (lastStatus != nil) {
        [self compareStatusAndQueueEvent:swrve_permission_location_always lastStatus:lastStatus currentStatus:currentStatus withSDK:sdk];
        [self compareStatusAndQueueEvent:swrve_permission_location_when_in_use lastStatus:lastStatus currentStatus:currentStatus withSDK:sdk];
        [self compareStatusAndQueueEvent:swrve_permission_photos lastStatus:lastStatus currentStatus:currentStatus withSDK:sdk];
        [self compareStatusAndQueueEvent:swrve_permission_camera lastStatus:lastStatus currentStatus:currentStatus withSDK:sdk];
        [self compareStatusAndQueueEvent:swrve_permission_contacts lastStatus:lastStatus currentStatus:currentStatus withSDK:sdk];
        [self compareStatusAndQueueEvent:swrve_permission_push_notifications lastStatus:lastStatus currentStatus:currentStatus withSDK:sdk];
    }
    [SwrveLocalStorage savePermissions:currentStatus];
}

+ (NSArray *)currentPermissionFilters {
    NSMutableArray* filters = [[NSMutableArray alloc] init];
    NSMutableDictionary * permissionsStatusCache = [SwrvePermissions permissionsStatusCache];
    if(permissionsStatusCache == nil) {
        return filters;
    }
    @synchronized (permissionsStatusCache) {
        [SwrvePermissions checkPermissionNameAndAddFilters:swrve_permission_location_always to:filters withCurrentStatus:permissionsStatusCache];
        [SwrvePermissions checkPermissionNameAndAddFilters:swrve_permission_location_when_in_use to:filters withCurrentStatus:permissionsStatusCache];
        [SwrvePermissions checkPermissionNameAndAddFilters:swrve_permission_photos to:filters withCurrentStatus:permissionsStatusCache];
        [SwrvePermissions checkPermissionNameAndAddFilters:swrve_permission_camera to:filters withCurrentStatus:permissionsStatusCache];
        [SwrvePermissions checkPermissionNameAndAddFilters:swrve_permission_contacts to:filters withCurrentStatus:permissionsStatusCache];

        // Check that we haven't already asked for push permissions
        if (![SwrvePermissions didWeAskForPushPermissionsAlready]) {
            NSString *currentPushPermission = [permissionsStatusCache objectForKey:swrve_permission_push_notifications];
            if ([currentPushPermission isEqualToString:swrve_permission_status_unknown] || [currentPushPermission isEqualToString:swrve_permission_status_provisional]) {
                [filters addObject:[[swrve_permission_push_notifications lowercaseString] stringByAppendingString:swrve_permission_requestable]];
            }
        }
    }
    return filters;
}

+ (BOOL)didWeAskForPushPermissionsAlready {
    return [SwrveLocalStorage askedForPushPermission];
}

+ (void)checkPermissionNameAndAddFilters:(NSString*)permissionName to:(NSMutableArray*)filters withCurrentStatus:(NSDictionary*)currentStatus {
    if (currentStatus == nil) {
        return;
    }

    if ([[currentStatus objectForKey:permissionName] isEqualToString:swrve_permission_status_unknown]) {
        [filters addObject:[[permissionName lowercaseString] stringByAppendingString:swrve_permission_requestable]];
    }
}

+ (void)compareStatusAndQueueEvent:(NSString *)permissioName lastStatus:(NSDictionary *)lastStatus currentStatus:(NSDictionary*)currentStatus withSDK:(id<SwrveCommonDelegate>)sdk {
    NSString *lastStatusString = [lastStatus objectForKey:permissioName];
    NSString *currentStatusString = [currentStatus objectForKey:permissioName];
    if (![lastStatusString isEqualToString:swrve_permission_status_authorized] && [currentStatusString isEqualToString:swrve_permission_status_authorized]) {
        // Send event as the permission has been granted
        [SwrvePermissions sendPermissionEvent:permissioName withState:SwrvePermissionStateAuthorized withSDK:sdk];
    } else if (![lastStatusString isEqualToString:swrve_permission_status_denied] && [currentStatusString isEqualToString:swrve_permission_status_denied]) {
        // Send event as the permission has been denied
        [SwrvePermissions sendPermissionEvent:permissioName withState:SwrvePermissionStateDenied withSDK:sdk];
    }
}

+ (SwrvePermissionState)checkLocationAlways:(id<SwrveCommonDelegate>)sdk {
    id<SwrvePermissionsDelegate> del = sdk.permissionsDelegate;
    if (del != nil && [del respondsToSelector:@selector(locationAlwaysPermissionState)]) {
        return [del locationAlwaysPermissionState];
    }
    return SwrvePermissionStateNotImplemented;
}

+ (BOOL)requestLocationAlways:(id<SwrveCommonDelegate>)sdk {
    id<SwrvePermissionsDelegate> del = sdk.permissionsDelegate;
    if (del != nil && [del respondsToSelector:@selector(requestLocationAlways:)]) {
        [del requestLocationAlwaysPermission:^(BOOL processed) {
            if (processed) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [sdk mergeWithCurrentDeviceInfo:[SwrvePermissions currentStatusWithSDK:sdk]];
                });
            }
        }];
        return TRUE;
    }
    return FALSE;
}

+ (SwrvePermissionState)checkLocationWhenInUse:(id<SwrveCommonDelegate>)sdk {
    id<SwrvePermissionsDelegate> del = sdk.permissionsDelegate;
    if (del != nil && [del respondsToSelector:@selector(locationWhenInUsePermissionState)]) {
        return [del locationWhenInUsePermissionState];
    }
    return SwrvePermissionStateNotImplemented;
}

+ (BOOL)requestLocationWhenInUse:(id<SwrveCommonDelegate>)sdk {
    id<SwrvePermissionsDelegate> del = sdk.permissionsDelegate;
    if (del != nil && [del respondsToSelector:@selector(requestLocationWhenInUse:)]) {
        [del requestLocationWhenInUsePermission:^(BOOL processed) {
            if (processed) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [sdk mergeWithCurrentDeviceInfo:[SwrvePermissions currentStatusWithSDK:sdk]];
                });
            }
        }];
        return TRUE;
    }
    return FALSE;
}

+ (SwrvePermissionState)checkPhotoLibrary:(id<SwrveCommonDelegate>)sdk {
    id<SwrvePermissionsDelegate> del = sdk.permissionsDelegate;
    if (del != nil && [del respondsToSelector:@selector(photoLibraryPermissionState)]) {
        return [del photoLibraryPermissionState];
    }
    return SwrvePermissionStateNotImplemented;
}

+ (BOOL)requestPhotoLibrary:(id<SwrveCommonDelegate>)sdk {
    id<SwrvePermissionsDelegate> del = sdk.permissionsDelegate;
    if (del != nil && [del respondsToSelector:@selector(requestPhotoLibrary:)]) {
        [del requestPhotoLibraryPermission:^(BOOL processed) {
            if (processed) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [sdk mergeWithCurrentDeviceInfo:[SwrvePermissions currentStatusWithSDK:sdk]];
                });
            }
        }];
        return TRUE;
    }
    return FALSE;
}

+(SwrvePermissionState)checkCamera:(id<SwrveCommonDelegate>)sdk {
    id<SwrvePermissionsDelegate> del = sdk.permissionsDelegate;
    if (del != nil && [del respondsToSelector:@selector(cameraPermissionState)]) {
        return [del cameraPermissionState];
    }
    return SwrvePermissionStateNotImplemented;
}

+(BOOL)requestCamera:(id<SwrveCommonDelegate>)sdk {
    id<SwrvePermissionsDelegate> del = sdk.permissionsDelegate;
    if (del != nil && [del respondsToSelector:@selector(requestCameraPermission:)]) {
        [del requestCameraPermission:^(BOOL processed) {
            if (processed) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [sdk mergeWithCurrentDeviceInfo:[SwrvePermissions currentStatusWithSDK:sdk]];
                });
            }
        }];
        return TRUE;
    }
    return FALSE;
}

+(SwrvePermissionState)checkContacts:(id<SwrveCommonDelegate>)sdk {
    id<SwrvePermissionsDelegate> del = sdk.permissionsDelegate;
    if (del != nil && [del respondsToSelector:@selector(contactPermissionState)]) {
        return [del contactPermissionState];
    }
    return SwrvePermissionStateNotImplemented;
}

+(BOOL)requestContacts:(id<SwrveCommonDelegate>)sdk {
    id<SwrvePermissionsDelegate> del = sdk.permissionsDelegate;
    if (del != nil && [del respondsToSelector:@selector(requestContactsPermission:)]) {
        [del requestContactsPermission:^(BOOL processed) {
            if (processed) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [sdk mergeWithCurrentDeviceInfo:[SwrvePermissions currentStatusWithSDK:sdk]];
                });
            }
        }];
        return TRUE;
    }
    return FALSE;
}

#if !defined(SWRVE_NO_PUSH) && TARGET_OS_IOS
+(void)requestPushNotifications:(id<SwrveCommonDelegate>)sdk provisional:(BOOL)provisional {
    if (@available(iOS 10.0, *)) {
        UNAuthorizationOptions notificationAuthOptions = (UNAuthorizationOptionAlert + UNAuthorizationOptionSound + UNAuthorizationOptionBadge);
        if (provisional) {
            if (@available(iOS 12.0, *)) {
                notificationAuthOptions = notificationAuthOptions + UNAuthorizationOptionProvisional;
            } else {
                DebugLog(@"Provisional push permission is only supported on iOS 12 and up.", nil);
                return;
            }
        }
        [SwrvePermissions registerForRemoteNotifications:notificationAuthOptions withCategories:sdk.notificationCategories andSDK:sdk];
    } else {
        DebugLog(@"Could not request push permission, not supported (should not reach this code)", nil);
    }
}

+(void)registerForRemoteNotifications:(UNAuthorizationOptions)notificationAuthOptions withCategories:(NSSet<UNNotificationCategory *> *)notificationCategories andSDK:(id<SwrveCommonDelegate>)sdk {
    UIApplication* app = [SwrveCommon sharedUIApplication];

    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:notificationAuthOptions
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
                              if (granted) {
                                  /** Add sdk-defined categories **/
                                  if (notificationCategories != nil && [notificationCategories count] > 0) {
                                      [center setNotificationCategories:notificationCategories];
                                  }
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      [app registerForRemoteNotifications];
                                  });
                              }

                              if (error) {
                                  DebugLog(@"Error obtaining permission for notification center: %@ %@", [error localizedDescription], [error localizedFailureReason]);
                              } else {
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      if (sdk != nil) {
                                          [sdk mergeWithCurrentDeviceInfo:[SwrvePermissions currentStatusWithSDK:sdk]];
                                      }
                                  });
                              }
                          }];

    // Remember we asked for push permissions
    [SwrveLocalStorage saveAskedForPushPermission:YES];
}
#endif //!defined(SWRVE_NO_PUSH)

+(void)sendPermissionEvent:(NSString*)eventName withState:(SwrvePermissionState)state withSDK:(id<SwrveCommonDelegate>)sdk {
    NSString *eventNameWithState = [eventName stringByAppendingString:((state == SwrvePermissionStateAuthorized)? @".on" : @".off")];
    [sdk eventInternal:eventNameWithState payload:nil triggerCallback:false];
}

+ (void)refreshDeviceToken:(id<SwrveCommonDelegate>)sdk {
    // If the user denied push prompt initially and then reenabled it in settings we need to check for this scenario
    if (@available(iOS 10.0, *)) {
        UIApplication* app = [SwrveCommon sharedUIApplication];
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *_Nonnull settings) {
            BOOL refreshToken = (settings.authorizationStatus == UNAuthorizationStatusAuthorized);
#if TARGET_OS_IOS /** exclude tvOS **/
            if (@available(iOS 12.0, *)) {
                refreshToken = refreshToken || (settings.authorizationStatus == UNAuthorizationStatusProvisional);
            }
#endif

            if (refreshToken) {
#if TARGET_OS_IOS /** exclude tvOS **/
                if (sdk.notificationCategories != nil && [sdk.notificationCategories count] > 0) {
                    [center setNotificationCategories:sdk.notificationCategories];
                }
#endif
                dispatch_async(dispatch_get_main_queue(), ^{
                    [app registerForRemoteNotifications];
                });
            }
        }];
    }
}

@end
