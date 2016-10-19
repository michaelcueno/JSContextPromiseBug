//
//  JSContextPromiseTests.m
//  JSContextPromiseTests
//
//  Created by Cueno, Michael on 10/18/16.
//  Copyright © 2016 test. All rights reserved.
//

#import <JavaScriptCore/JavaScriptCore.h>
#import <XCTest/XCTest.h>


//////////////////// TEST HELPERS /////////////////////////
void waitAsync() {
    __block BOOL done = NO;
    NSDate* timeoutDate = [NSDate dateWithTimeIntervalSinceNow:5];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(50 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        done = YES;
    });
    while(!done) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeoutDate];
    }
}

@interface JSContextTestFixture : NSObject
@property JSContext* context;
@property JSValue* result;
- (instancetype)initWithJSContext:(JSContext*)jsContext;
- (void)waitForAndValidateResultUsing:(void(^)(JSValue* actual))validator;
@end

@implementation JSContextTestFixture
- (instancetype)initWithJSContext:(JSContext*)jsContext;
{
    if (self = [super init]) {
        _context = jsContext;
    }
    self.context[@"report"] = ^(JSValue* obj){
        _result = obj;
    };
    self.context[@"sendMessage"] = ^(JSValue* obj){
        NSLog(@"Ping!");
    };
    self.context[@"window"] = self.context.globalObject;
    
    self.context[@"setTimeout"] = ^(JSValue* function, JSValue* timeout) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout.toInt32 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            [function callWithArguments:@[]];
        });
    };
    
    [self injectAsset:@"PromiseTests"];
    return self;
}

- (void)waitForAndValidateResultUsing:(void (^)(JSValue* actual))validator
{
    while(!self.result){
        waitAsync();  // block until result is obtained
    }
    validator(self.result);
    self.result = nil;
}

- (void)injectAsset:(NSString*)name {
    NSString* stringPath = [[NSBundle mainBundle] pathForResource:name ofType:@"js"];
    NSString* content = [NSString stringWithContentsOfFile:stringPath encoding:NSUTF8StringEncoding error:nil];
    [self.context evaluateScript:content withSourceURL:[NSURL URLWithString:stringPath]];
}

@end

//////////////////// TEST HELPERS END /////////////////////////

@interface JSContextPromiseTests : XCTestCase
@property (nonatomic) JSContextTestFixture* fixture;
@property (nonatomic) JSContext* context;
@property (nonatomic) JSValue* result;
@end

@implementation JSContextPromiseTests

- (void)setUp {
    [super setUp];
    self.context = [JSContext new];
    self.fixture = [[JSContextTestFixture alloc] initWithJSContext:self.context];
}

- (void)tearDown {
    [super tearDown];
}

/**
 * I believe this test failure demonstrates the bug. See the file PromiseTests.js in supporting files for the JS function.
 */
- (void)testBrokenWithNativePromises {
    [self.context evaluateScript:@"performTest()"];
    [self.fixture waitForAndValidateResultUsing:^(JSValue *actual) {
        XCTAssert([actual.toString isEqualToString:@"success"]);
    }];
}

/**
 * This test performs the same javascript, only it replaces native promises with javascript promises first. 
 */
- (void)testWorkingWithoutNativePromises {
    [self.context evaluateScript:@"window.Promise = undefined;"];
    [self.fixture injectAsset:@"Promise"]; // es-6 Prmoises
    [self.context evaluateScript:@"performTest()"];
    [self.fixture waitForAndValidateResultUsing:^(JSValue *actual) {
        XCTAssert([actual.toString isEqualToString:@"success"]);
    }];
}

/**
 * Resolves the promise in the thenable of the nested promise.
 */
- (void)testBrokenWithNativePromisesWorking {
    [self.context evaluateScript:@"performTestWorking()"];
    [self.fixture waitForAndValidateResultUsing:^(JSValue *actual) {
        XCTAssert([actual.toString isEqualToString:@"success"]);
    }];
}

@end
