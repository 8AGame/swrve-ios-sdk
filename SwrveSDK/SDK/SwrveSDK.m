#import "SwrveSDK.h"
#import "SwrveEmpty.h"

@implementation SwrveSDK

static Swrve * _swrveSharedInstance = nil;
static dispatch_once_t sharedInstanceToken = 0;

+ (ImmutableSwrveConfig *) config {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] config];
}

+ (long)appID {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] appID];
}

+ (NSString *)apiKey {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] apiKey];
}

+ (NSString *)userID {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] userID];
}

+ (SwrveMessageController *)messaging {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] messaging];
}

+ (void)resetSwrveSharedInstance {
    if (_swrveSharedInstance) {
        [_swrveSharedInstance shutdown];
    }
    [SwrveCommon addSharedInstance:nil];
    
    _swrveSharedInstance = nil;
    sharedInstanceToken = 0;
}

+ (void)addSharedInstance:(Swrve*)instance {
    dispatch_once(&sharedInstanceToken, ^{
        _swrveSharedInstance = instance;
    });
}

+ (Swrve *)sharedInstance {
    if (!_swrveSharedInstance) {
        DebugLog(@"Warning: [SwrveSDK sharedInstance] called before sharedInstanceWithAppID:... method.", nil);
    }
    return _swrveSharedInstance;
}

+ (void)sharedInstanceWithAppID:(int)swrveAppID apiKey:(NSString *)swrveAPIKey {
    dispatch_once(&sharedInstanceToken, ^{
        _swrveSharedInstance = [SwrveSDK createInstance];
        _swrveSharedInstance = [_swrveSharedInstance initWithAppID:swrveAppID apiKey:swrveAPIKey];
    });
}

+ (void)sharedInstanceWithAppID:(int)swrveAppID apiKey:(NSString *)swrveAPIKey config:(SwrveConfig *)swrveConfig {
    dispatch_once(&sharedInstanceToken, ^{
        _swrveSharedInstance = [SwrveSDK createInstance];
        _swrveSharedInstance = [_swrveSharedInstance initWithAppID:swrveAppID apiKey:swrveAPIKey config:swrveConfig ];
    });
}

+ (Swrve *)createInstance {
    // Detect if the SDK can run on this platform, if not, create a dummy instance
    if ([SwrveCommon supportedOS]) {
        return [Swrve alloc];
    }
    
    return (Swrve*)[SwrveEmpty alloc];
}

#pragma mark Static access methods

+ (void)checkInstance {
    id instance = [SwrveSDK sharedInstance];
    if (instance == nil) {
        NSException *e = [NSException
                          exceptionWithName:@"SwrveInstanceNotFoundException"
                          reason:@"Please call [SwrveSDK init...] first"
                          userInfo:nil];
        @throw e;
    }
}

+ (int)purchaseItem:(NSString *)itemName currency:(NSString *)itemCurrency cost:(int)itemCost quantity:(int)itemQuantity {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] purchaseItem:itemName currency:itemCurrency cost:itemCost quantity:itemQuantity];
}

+ (int)iap:(SKPaymentTransaction*)transaction product:(SKProduct*) product {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] iap:transaction product:product];
}

+ (int)iap:(SKPaymentTransaction *)transaction product:(SKProduct *)product rewards:(SwrveIAPRewards *)rewards {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] iap:transaction product:product rewards:rewards];
}

+ (int)unvalidatedIap:(SwrveIAPRewards *)rewards localCost:(double)localCost localCurrency:(NSString *)localCurrency productId:(NSString *)productId productIdQuantity:(int)productIdQuantity {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] unvalidatedIap:rewards localCost:localCost localCurrency:localCurrency productId:productId productIdQuantity:productIdQuantity];
}

+ (int)event:(NSString *)eventName {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] event:eventName];
}

+ (int)event:(NSString *)eventName payload:(NSDictionary *)eventPayload {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] event:eventName payload:eventPayload];
}

+ (int)currencyGiven:(NSString *)givenCurrency givenAmount:(double)givenAmount {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] currencyGiven:givenCurrency givenAmount:givenAmount];
}

+ (int)userUpdate:(NSDictionary *)attributes {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] userUpdate:attributes];
}

+ (int)userUpdate:(NSString *)name withDate:(NSDate *) date {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] userUpdate:name withDate:date];
}

+ (void)refreshCampaignsAndResources {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] refreshCampaignsAndResources];
}

+ (SwrveResourceManager*) resourceManager {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] resourceManager];
}

+ (void)userResources:(SwrveUserResourcesCallback)callbackBlock {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] userResources:callbackBlock];
}

+ (void)userResourcesDiff:(SwrveUserResourcesDiffCallback)callbackBlock {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] userResourcesDiff:callbackBlock];
}

+ (void)realTimeUserProperties:(SwrveRealTimeUserPropertiesCallback)callbackBlock {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] realTimeUserProperties:callbackBlock];
}

+ (void)sendQueuedEvents {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] sendQueuedEvents];
}

+ (void)saveEventsToDisk {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] saveEventsToDisk];
}

+ (void)setEventQueuedCallback:(SwrveEventQueuedCallback)callbackBlock {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] setEventQueuedCallback:callbackBlock];
}

+ (int)eventWithNoCallback:(NSString* )eventName payload:(NSDictionary *)eventPayload {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] eventWithNoCallback:eventName payload:eventPayload];
}

+ (void)shutdown {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] shutdown];
}

#if !defined(SWRVE_NO_PUSH) && TARGET_OS_IOS

+ (void)setDeviceToken:(NSData *)deviceToken {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] setDeviceToken:deviceToken];
}

+ (NSString *)deviceToken {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] deviceToken];
}

+ (BOOL)didReceiveRemoteNotification:(NSDictionary *)userInfo withBackgroundCompletionHandler:(void (^)(UIBackgroundFetchResult, NSDictionary *))completionHandler {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] didReceiveRemoteNotification:userInfo withBackgroundCompletionHandler:completionHandler];
}

+ (void)sendPushEngagedEvent:(NSString*)pushId {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] sendPushNotificationEngagedEvent:pushId];
}

+ (void)processNotificationResponse:(UNNotificationResponse *)response __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] processNotificationResponse:response];
}

#endif //!defined(SWRVE_NO_PUSH)

+ (void)handleDeeplink:(NSURL *)url {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] handleDeeplink:url];
}

+ (void)handleDeferredDeeplink:(NSURL *)url {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] handleDeferredDeeplink:url];
}

+ (void)installAction:(NSURL *)url {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] installAction:url];
}

+ (void)identify:(NSString *)externalUserId
       onSuccess:(void (^)(NSString *status, NSString *swrveUserId))onSuccess
         onError:(void (^)(NSInteger httpCode, NSString *errorMessage))onError {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] identify:externalUserId onSuccess:onSuccess onError:onError];
}

+ (NSString *)externalUserId {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] externalUserId];
}

+ (void)setCustomPayloadForConversationInput:(NSMutableDictionary *)payload {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] setCustomPayloadForConversationInput:payload];
}

+ (void)start {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] start];
}

+ (void)startWithUserId:(NSString *)userId {
    [SwrveSDK checkInstance];
    [[SwrveSDK sharedInstance] startWithUserId:userId];
}

+ (BOOL)started {
    [SwrveSDK checkInstance];
    return [[SwrveSDK sharedInstance] started];
}

@end
