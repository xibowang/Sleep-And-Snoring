//
//  APIFetcher.m
//  OAuthDemo
//
//  Created by Jiao Liu on 15/6/3.
//  Copyright (c) 2015年 Xibo Wang. All rights reserved.
//

#import "APIFetcher.h"
#import "GTMHTTPFetcher.h"
#import "FitbitAPI.h"
#import "SSKeychain.h"
// UserDefaults
static NSString *const vServiceProvider = @"Fitbit";
static NSString *const vClientID        = @"229Q8T";
static NSString *const vClientSecret    = @"1515d15713ba40771aee66b4cbc33e9b";

// keys
static NSString *const kOAuth2AccessTokenKey    = @"access_token";
static NSString *const kOAuth2RefreshTokenKey   = @"refresh_token";


// keychains constants
static NSString *const kSleepAndSnoringService          = @"Sleep And Snoring";
static NSString *const kSleepAndSnoringAccessAccount    = @"com.sleepandsnoring.accesstoken";
static NSString *const kSleepAndSnoringRefreshAccount   = @"com.sleepandsnoring.refreshtoken";


@interface APIFetcher ()

@property (strong, nonatomic)NSString *apiBaseURL;
@property (strong, nonatomic)NSDate *currentSyncTime;
@end

@implementation APIFetcher


+ (APIFetcher *)fetcherWithOAuth2:(OAuth2Authentication *)auth
                      accessToken:(NSString *)accessToken
                     refreshToken:(NSString *)refreshToken {
    APIFetcher *fetcher = [[APIFetcher alloc] init];
    fetcher.auth = auth;
    fetcher.apiBaseURL = auth.apiBaseURL;
    fetcher.refreshToken = refreshToken;
    fetcher.accessToken = accessToken;
    
    return fetcher;
}


// fetch api

- (void)sendGetRequestToAPIPath:(NSString *)path onCompletion:(void (^)(NSData *, NSError *))handler {
    
    NSMutableURLRequest *request = [self setCustomURLRequestWithAPIPath:path];
    GTMHTTPFetcher *fetcher = [GTMHTTPFetcher fetcherWithRequest:request];
    [fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error) {
        if (error) {
            // try to refresh the token to solve the error
            [self.auth refreshAccessTokenByRefreshToken:self.refreshToken onCompletion:^(NSData *refreshData, NSError *refreshError) {
                
                // success refresh access token
                if (!refreshError) {
                    
                    // get refreshed data
                    NSDictionary *fetchResult = [NSJSONSerialization JSONObjectWithData:refreshData
                                                                                options:kNilOptions
                                                                                  error:nil];
                    
                    self.accessToken = [fetchResult objectForKey:kOAuth2AccessTokenKey];
                    self.refreshToken = [fetchResult objectForKey:kOAuth2RefreshTokenKey];
                    
                    // set the access/refresh token after refreshing
                    [SSKeychain setPassword:self.accessToken forService:kSleepAndSnoringService account:kSleepAndSnoringAccessAccount];
                    [SSKeychain setPassword:self.refreshToken forService:kSleepAndSnoringService account:kSleepAndSnoringRefreshAccount];
                    
                    // redo fetching data after successfully refresh tokens
                    [self sendGetRequestToAPIPath:path onCompletion:^(NSData *data, NSError *error) {
                        handler(data, error);
                    }];
                    
                    NSLog(@"Refresh Result : %@", fetchResult);

                } else {
                    NSDictionary *errorResult = [NSJSONSerialization JSONObjectWithData:refreshData
                                                                                options:kNilOptions
                                                                                  error:nil];
                    NSLog(@"error : %@ ", errorResult);
                    // report if fail to refresh access token
                    handler(refreshData, refreshError);
                }
                
            }];
        }
        // if no error then get data successfully
        else {
            handler(data, error);
        }
        
        /*
         Print error use the same way as print data
         
        NSError* errorInSerialization;
        NSDictionary *errorDictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                    options:kNilOptions
                                                                      error:&errorInSerialization];
        NSLog(@"Error happens during fetching data from %@ : %@",path, errorDictionary);
        */
        
    }];
}

-(void)refreshAccessToken {
    [self.auth refreshAccessTokenByRefreshToken:self.refreshToken onCompletion:^(NSData *refreshData, NSError *refreshError) {
        
        // success refresh access token
        if (!refreshError) {
            
            NSDictionary *fetchResult = [NSJSONSerialization JSONObjectWithData:refreshData
                                                                        options:kNilOptions
                                                                          error:nil];
            
            self.accessToken = [fetchResult objectForKey:kOAuth2AccessTokenKey];
            self.refreshToken = [fetchResult objectForKey:kOAuth2RefreshTokenKey];
            
            // set the access token after refreshing
            [SSKeychain setPassword:self.accessToken forService:kSleepAndSnoringService account:kSleepAndSnoringAccessAccount];
            [SSKeychain setPassword:self.refreshToken forService:kSleepAndSnoringService account:kSleepAndSnoringRefreshAccount];
            NSLog(@"Refresh Result : %@", fetchResult);
            
        } else {
            NSDictionary *errorResult = [NSJSONSerialization JSONObjectWithData:refreshData
                                                                        options:kNilOptions
                                                                          error:nil];
            NSLog(@"Fail to refresh : %@ ", errorResult);
            // report if fail to refresh access token
        }
        
    }];
}



- (void)sendTestRquestToAPI:(NSURLRequest *)request onCompletion:(void (^)(NSData *data, NSError *error))handler {
    // test get user profile
    [self getUserProfile];
}

#pragma mark private methods

- (NSMutableURLRequest *)setCustomURLRequestWithAPIPath:(NSString *)path {
    
    // api resource url
    NSURL *url = [NSURL URLWithString:path relativeToURL:[NSURL URLWithString:self.apiBaseURL]];
    
    // set request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", self.accessToken] forHTTPHeaderField:@"Authorization"];
    return request;
    
}

- (void)getUserProfile {
    // api resource url
    NSString *path = @"/1/user/-/profile.json";

    // send request
    [self sendGetRequestToAPIPath:path onCompletion:^(NSData *data, NSError *error) {
        if (error) {
            // failed; either an NSURLConnection error occurred, or the server returned
            // a status value of at least 300
            NSData *errorData = [error.userInfo objectForKey:@"data"];
            NSString *base64Decoded = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
            NSLog(@"The error data : %@", base64Decoded);
            
            [self.auth refreshAccessTokenByRefreshToken:self.refreshToken onCompletion:^(NSData *data, NSError *error) {
                
                NSError* errorInSerialization;
                NSDictionary *fetchResult = [NSJSONSerialization JSONObjectWithData:data
                                                                            options:kNilOptions
                                                                              error:&errorInSerialization];
                
                self.accessToken = [fetchResult objectForKey:kOAuth2AccessTokenKey];
                self.refreshToken = [fetchResult objectForKey:kOAuth2RefreshTokenKey];
                NSLog(@"Refresh Result : %@", fetchResult);
                
            }];
            
        } else {
            NSString *base64Decoded = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"The result data : %@", base64Decoded);
            // fetch succeeded
        }

    }];

}


-(void)getLastSyncTimeOnCompletion:(void (^)(BOOL , NSError *))handler {
    // api path
    NSString *path = @"/1/user/-/devices.json";
    
    // api request
    [self sendGetRequestToAPIPath:path onCompletion:^(NSData *data, NSError *error) {
        if (error) {
            // todo
        } else {
            // fetch result is an array
            NSDictionary *fetchResult = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
            // first item in the array
            NSDictionary *firstDevice = [((NSArray *)fetchResult) objectAtIndex:0];
            NSLog(@"fetch result : %@", fetchResult);
            
            // get last sync time from dictionary
            NSString *dateString = [firstDevice objectForKey:kFitbitDeviceLastSyncTimeKey];
            dateString = [dateString substringToIndex:19];
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
            NSDate *lastSyncTime = [dateFormatter dateFromString:dateString];
            
            if (!self.currentSyncTime) {
                self.currentSyncTime = lastSyncTime;
                handler(YES, error);
                NSLog(@"No current sync time.");
            } else if ([self.currentSyncTime compare:lastSyncTime] == NSOrderedAscending) {
                NSLog(@"There is an new sync update.");
                handler(YES, error);
            } else {
                NSLog(@"NO new update");
                handler(NO, error);
            }
        
        
        }
    }];
}


- (NSString *)description {
    return [NSString stringWithFormat:@""];
}



@end
