//
//  SimpleAuthAppFiguresProvider.m
//  Pods
//
//  Created by Jake Marsh on 2/21/15.
//
//

#import "SimpleAuthAppFiguresProvider.h"
#import "SimpleAuthAppFiguresLoginViewController.h"

#import "UIViewController+SimpleAuthAdditions.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <cocoa-oauth/GCOAuth.h>

@implementation SimpleAuthAppFiguresProvider

+ (NSString *) type {
    return @"appfigures";
}

+ (NSDictionary *) defaultOptions {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:[super defaultOptions]];
    dictionary[SimpleAuthRedirectURIKey] = @"simple-auth://appfigures.auth";
    return dictionary;
}

- (void) authorizeWithCompletion:(SimpleAuthRequestHandler)completion {
    [[[[[self requestToken]
        flattenMap:^(NSDictionary *response) {
            NSArray *signals = @[
                                 [RACSignal return:response],
                                 [self authenticateWithRequestToken:response]
                                 ];
            return [RACSignal zip:signals];
        }]
       flattenMap:^(RACTuple *response) {
           return [self accessTokenWithRequestToken:response.first authenticationResponse:response.second];
       }]
      flattenMap:^(NSDictionary *response) {
          NSArray *signals = @[
                               [self accountWithAccessToken:response],
                               [RACSignal return:response]
                               ];
          return [self rac_liftSelector:@selector(responseDictionaryWithRemoteAccount:accessToken:) withSignalsFromArray:signals];
      }]
     subscribeNext:^(NSDictionary *response) {
         completion(response, nil);
     }
     error:^(NSError *error) {
         completion(nil, error);
     }];
}

#pragma mark - Private

- (RACSignal *) requestToken {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        NSDictionary *parameters = @{ @"oauth_callback" : self.options[SimpleAuthRedirectURIKey] };
        NSURLRequest *request = [GCOAuth
                                 URLRequestForPath:@"/v2/oauth/request_token"
                                 POSTParameters:parameters
                                 scheme:@"https"
                                 host:@"api.appfigures.com"
                                 consumerKey:self.options[@"consumer_key"]
                                 consumerSecret:self.options[@"consumer_secret"]
                                 accessToken:nil
                                 tokenSecret:nil];
        [NSURLConnection sendAsynchronousRequest:request queue:self.operationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 99)];
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            if ([indexSet containsIndex:statusCode] && data) {
                NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSDictionary *dictionary = [CMDQueryStringSerialization dictionaryWithQueryString:string];
                [subscriber sendNext:dictionary];
                [subscriber sendCompleted];
            }
            else {
                NSMutableDictionary *dictionary = [NSMutableDictionary new];
                if (connectionError) {
                    dictionary[NSUnderlyingErrorKey] = connectionError;
                }
                dictionary[SimpleAuthErrorStatusCodeKey] = @(statusCode);
                NSError *error = [NSError errorWithDomain:SimpleAuthErrorDomain code:SimpleAuthErrorNetwork userInfo:dictionary];
                [subscriber sendError:error];
            }
        }];
        return nil;
    }];
}

- (RACSignal *) authenticateWithRequestToken:(NSDictionary *)requestToken {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        dispatch_async(dispatch_get_main_queue(), ^{
            SimpleAuthAppFiguresLoginViewController *controller = [[SimpleAuthAppFiguresLoginViewController alloc] initWithOptions:self.options requestToken:requestToken];
            controller.completion = ^(UIViewController *controller, NSURL *URL, NSError *error) {
                [controller dismissViewControllerAnimated:YES completion:nil];
                
                // Parse URL
                NSString *query = [URL query];
                NSDictionary *dictionary = [CMDQueryStringSerialization dictionaryWithQueryString:query];
                NSString *token = dictionary[@"oauth_token"];
                NSString *verifier = dictionary[@"oauth_verifier"];
                
                // Check for error
                if (![token length] || ![verifier length]) {
                    [subscriber sendError:error];
                    return;
                }
                
                // Send completion
                [subscriber sendNext:dictionary];
                [subscriber sendCompleted];
            };
            [self presentLoginViewController:controller];
        });
        return nil;
    }];
}

- (RACSignal *) accessTokenWithRequestToken:(NSDictionary *)requestToken authenticationResponse:(NSDictionary *)authenticationResponse {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        NSDictionary *parameters = @{ @"oauth_verifier" : authenticationResponse[@"oauth_verifier"] };
        NSURLRequest *request = [GCOAuth
                                 URLRequestForPath:@"/v2/oauth/access_token"
                                 GETParameters:parameters
                                 scheme:@"https"
                                 host:@"api.appfigures.com"
                                 consumerKey:self.options[@"consumer_key"]
                                 consumerSecret:self.options[@"consumer_secret"]
                                 accessToken:authenticationResponse[@"oauth_token"]
                                 tokenSecret:requestToken[@"oauth_token_secret"]];
        [NSURLConnection sendAsynchronousRequest:request queue:self.operationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 99)];
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            if ([indexSet containsIndex:statusCode] && data) {
                NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSDictionary *dictionary = [CMDQueryStringSerialization dictionaryWithQueryString:string];
                [subscriber sendNext:dictionary];
                [subscriber sendCompleted];
            } else {
                NSMutableDictionary *dictionary = [NSMutableDictionary new];
                if (connectionError) {
                    dictionary[NSUnderlyingErrorKey] = connectionError;
                }
                dictionary[SimpleAuthErrorStatusCodeKey] = @(statusCode);
                NSError *error = [NSError errorWithDomain:SimpleAuthErrorDomain code:SimpleAuthErrorNetwork userInfo:dictionary];
                [subscriber sendError:error];
            }
        }];
        return nil;
    }];
}

- (RACSignal *) accountWithAccessToken:(NSDictionary *)accessToken {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        NSURLRequest *request = [GCOAuth
                                 URLRequestForPath:@"/v2"
                                 GETParameters:nil
                                 scheme:@"https"
                                 host:@"api.appfigures.com"
                                 consumerKey:self.options[@"consumer_key"]
                                 consumerSecret:self.options[@"consumer_secret"]
                                 accessToken:accessToken[@"oauth_token"]
                                 tokenSecret:accessToken[@"oauth_token_secret"]];
        [NSURLConnection sendAsynchronousRequest:request queue:self.operationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 99)];
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            if ([indexSet containsIndex:statusCode] && data) {
                NSError *parseError = nil;
                NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&parseError];
                if (dictionary) {
                    [subscriber sendNext:dictionary];
                    [subscriber sendCompleted];
                }
                else {
                    NSMutableDictionary *dictionary = [NSMutableDictionary new];
                    if (parseError) {
                        dictionary[NSUnderlyingErrorKey] = parseError;
                    }
                    NSError *error = [NSError errorWithDomain:SimpleAuthErrorDomain code:SimpleAuthErrorInvalidData userInfo:dictionary];
                    [subscriber sendNext:error];
                }
            }
            else {
                NSMutableDictionary *dictionary = [NSMutableDictionary new];
                if (connectionError) {
                    dictionary[NSUnderlyingErrorKey] = connectionError;
                }
                dictionary[SimpleAuthErrorStatusCodeKey] = @(statusCode);
                NSError *error = [NSError errorWithDomain:SimpleAuthErrorDomain code:SimpleAuthErrorNetwork userInfo:dictionary];
                [subscriber sendError:error];
            }
        }];
        return nil;
    }];
}

- (NSDictionary *) responseDictionaryWithRemoteAccount:(NSDictionary *)remoteAccount accessToken:(NSDictionary *)accessToken {
    return @{
        @"provider": [[self class] type],
        @"uid": remoteAccount[@"user"][@"id"],
        @"credentials": [self credentialsDictionaryWithRemoteAccount:remoteAccount accessToken:accessToken],
        @"extra": remoteAccount,
        @"info": [self infoDictionaryWithRemoteAccount:remoteAccount accessToken:accessToken]
    };
}

- (NSDictionary *) credentialsDictionaryWithRemoteAccount:(NSDictionary *)remoteAccount accessToken:(NSDictionary *)accessToken {
    return @{
        @"token" : accessToken[@"oauth_token"],
        @"secret" : accessToken[@"oauth_token_secret"]
    };
}

- (NSDictionary *) infoDictionaryWithRemoteAccount:(NSDictionary *)remoteAccount accessToken:(NSDictionary *)accessToken {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];

    dictionary[@"email"] = [remoteAccount valueForKeyPath:@"user.email"];
    dictionary[@"name"] = [remoteAccount valueForKeyPath:@"user.name"];
    dictionary[@"image"] = [remoteAccount valueForKeyPath:@"user.avatar_url"];

    return dictionary;
}

@end
