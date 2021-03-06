#import <XCTest/XCTest.h>
#import "SwrveCampaignDelivery.h"
#import <OCMock/OCMock.h>
#import "SwrveUtils.h"
#import "SwrveTestSwrveCampaignDeliveryIOS.m"
#import "SwrveRESTClient.h"

@interface SwrveTestSwrveCampaignDeliveryIOS : XCTestCase

@property id classNSFileManagerMock;

@end

@interface SwrveCampaignDelivery ()

// Force exterl public keys
extern NSString *const SwrveDeliveryConfigKey;
extern NSString *const SwrveDeliveryRequiredConfigUserIdKey;
extern NSString *const SwrveDeliveryRequiredConfigEventsUrlKey;
extern NSString *const SwrveDeliveryRequiredConfigDeviceIdKey;
extern NSString *const SwrveDeliveryRequiredConfigSessionTokenKey;
extern NSString *const SwrveDeliveryRequiredConfigAppVersionKey;

// Force public interface for private methods.
+ (NSDictionary *)eventData:(NSDictionary *) userInfo forSeqno:(NSInteger)seqno;

@end

@implementation SwrveTestSwrveCampaignDeliveryIOS


- (void)setUp {
    [super setUp];
    // Partial mock of NSFileManager to Force a valid return when check for the valid GroupId.
    self.classNSFileManagerMock = OCMPartialMock([NSFileManager defaultManager]);
    OCMExpect([self.classNSFileManagerMock containerURLForSecurityApplicationGroupIdentifier:OCMOCK_ANY]).andReturn([NSURL new]);
}

- (void)tearDown {
    [self.classNSFileManagerMock stopMocking];
    [super tearDown];
}

- (void)testEventData {
    NSDictionary *userInfo = @{
        @"_p": @123456,
        @"sw":@{@"media":
                    @{@"title": @"tile",
                      @"body": @"body",
                      @"url": @"https://whatever.jpg"
                    },
                @"version": @1
        }
    };

    // Mock getTimeEpoch at SwrveUtils.
    id classSwrveUtilsMock = OCMClassMock([SwrveUtils class]);
    OCMStub([classSwrveUtilsMock getTimeEpoch]).andReturn(1580397679375);


    NSDictionary *expectedEventData = [SwrveCampaignDelivery eventData:userInfo forSeqno:1];
    XCTAssertEqualObjects([expectedEventData objectForKey:@"type"], @"generic_campaign_event");
    XCTAssertEqualObjects([expectedEventData objectForKey:@"time"], @1580397679375);
    XCTAssertEqualObjects([expectedEventData objectForKey:@"seqnum"], @"1");
    XCTAssertEqualObjects([expectedEventData objectForKey:@"actionType"], @"delivered");
    XCTAssertEqualObjects([expectedEventData objectForKey:@"campaignType"], @"push");
    XCTAssertEqualObjects([expectedEventData objectForKey:@"payload"], @{@"silent": [NSNumber numberWithBool:NO]});
    XCTAssertEqualObjects([expectedEventData objectForKey:@"id"], @123456);

    [classSwrveUtilsMock stopMocking];
}

- (void)testSaveDeliveryPushConfig {

    NSString *userId = @"userId";
    NSString *serverUrl = @"server.url";
    NSString *deviceId = @"deviceId";
    NSString *sessionToken = @"sessionToken";
    NSString *appVersion = @"appVersion";
    NSString *appGroupId = @"app.groupid";

    // Force an empty info into our storage.
    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:appGroupId];
    [userDefaults removeObjectForKey:SwrveDeliveryConfigKey];
    NSDictionary *storadConfigs = [userDefaults dictionaryForKey:SwrveDeliveryConfigKey];
    XCTAssertNil(storadConfigs);

    [SwrveCampaignDelivery saveConfigForPushDeliveryWithUserId:userId
                                            WithEventServerUrl:serverUrl
                                                  WithDeviceId:deviceId
                                              WithSessionToken:sessionToken
                                                WithAppVersion:appVersion
                                                 ForAppGroupID:appGroupId];

    // Update storadConfigs after save the values for final test.
    storadConfigs = [userDefaults dictionaryForKey:SwrveDeliveryConfigKey];
    XCTAssertEqualObjects(storadConfigs[SwrveDeliveryRequiredConfigUserIdKey], userId);
    XCTAssertEqualObjects(storadConfigs[SwrveDeliveryRequiredConfigEventsUrlKey], serverUrl);
    XCTAssertEqualObjects(storadConfigs[SwrveDeliveryRequiredConfigDeviceIdKey], deviceId);
    XCTAssertEqualObjects(storadConfigs[SwrveDeliveryRequiredConfigSessionTokenKey], sessionToken);
    XCTAssertEqualObjects(storadConfigs[SwrveDeliveryRequiredConfigAppVersionKey], appVersion);
}

- (void)testSendPushDelivery {
    // Mocked userInfo
    NSNumber *pushId = @123456;
    NSDictionary *userInfo = @{
        @"_p": pushId,
        @"sw":@{@"media":
                    @{@"title": @"tile",
                      @"body": @"body",
                      @"url": @"https://whatever.jpg"
                    },
                @"version": @1

        }
   };

    NSString *userId = @"userId";
    NSString *serverUrl = @"server.url";
    NSString *deviceId = @"deviceId";
    NSString *sessionToken = @"sessionToken";
    NSString *appVersion = @"appVersion";
    NSString *appGroupId = @"app.groupid";

    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:appGroupId];
    // Mock SwrveDeliveryConfigKey in userDefaults.
    [userDefaults setObject:@{
        SwrveDeliveryRequiredConfigUserIdKey: userId,
        SwrveDeliveryRequiredConfigEventsUrlKey: serverUrl,
        SwrveDeliveryRequiredConfigDeviceIdKey: deviceId,
        SwrveDeliveryRequiredConfigSessionTokenKey: sessionToken,
        SwrveDeliveryRequiredConfigAppVersionKey: appVersion
    } forKey:SwrveDeliveryConfigKey];

    // Mock our SwrveRESTClient class
    id classDeliveryMock = OCMClassMock([SwrveRESTClient class]);
    OCMStub([classDeliveryMock alloc]).andReturn(classDeliveryMock);
    OCMStub([classDeliveryMock initWithTimeoutInterval:10]).andReturn(classDeliveryMock);

    // Mock getTimeEpoch at SwrveUtils.
    id classSwrveUtilsMock = OCMClassMock([SwrveUtils class]);
    OCMStub([classSwrveUtilsMock getTimeEpoch]).andReturn(1580732959342);

    // ExpectedURL
    NSURL *expectedURL = [NSURL URLWithString:@"1/batch" relativeToURL:[NSURL URLWithString:@"server.url"]];
    NSError *jsonError;
    NSData *expectedEventBatchNSData = [NSJSONSerialization dataWithJSONObject:@{
        @"app_version":appVersion,
        @"unique_device_id": deviceId,
        @"data":@[
                @{
                    @"seqnum": @"1",
                    @"actionType": @"delivered",
                    @"time":@1580732959342,
                    @"campaignType":@"push",
                    @"id": pushId,
                    @"payload":@{
                            @"silent":[NSNumber numberWithBool:NO]
                    },
                    @"type":@"generic_campaign_event"
                }
        ],
        @"session_token": sessionToken,
        @"user": userId,
    } options:0 error:&jsonError];

    XCTAssertNil(jsonError);
    // Expected call with expectedURL and expectedEventBatchNSData.
    OCMExpect([classDeliveryMock sendHttpPOSTRequest:expectedURL jsonData:expectedEventBatchNSData completionHandler:OCMOCK_ANY]);
    [SwrveCampaignDelivery sendPushDelivery:userInfo withAppGroupID:appGroupId];

    // Reset userDefauls
    [userDefaults setObject:nil forKey:SwrveDeliveryConfigKey];
    NSString *seqNumKey = [userId stringByAppendingString:@"swrve_event_seqnum"];
    [userDefaults setObject:nil forKey:seqNumKey];

    OCMVerifyAll(classDeliveryMock);

    [classDeliveryMock stopMocking];
    [classSwrveUtilsMock stopMocking];
}

@end
