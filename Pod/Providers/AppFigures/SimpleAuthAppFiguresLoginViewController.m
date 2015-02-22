//
//  SimpleAuthAppFiguresLoginViewController.m
//  Pods
//
//  Created by Jake Marsh on 2/21/15.
//
//

#import "SimpleAuthAppFiguresLoginViewController.h"

@interface SimpleAuthAppFiguresLoginViewController ()

@end

@implementation SimpleAuthAppFiguresLoginViewController

#pragma mark - SimpleAuthWebViewController

- (instancetype) initWithOptions:(NSDictionary *)options requestToken:(NSDictionary *)requestToken {
    self = [super initWithOptions:options requestToken:requestToken];
    if (!self) return nil;
    
    self.title = @"AppFigures";
    
    return self;
}


- (NSURLRequest *) initialRequest {
    NSDictionary *parameters = @{ @"oauth_token" : self.requestToken[@"oauth_token"] };
    
    NSString *URLString = [NSString stringWithFormat:
                           @"https://api.appfigures.com/v2/oauth/authorize?%@",
                           [CMDQueryStringSerialization queryStringWithDictionary:parameters]];
    
    NSURL *URL = [NSURL URLWithString:URLString];
    
    return [NSURLRequest requestWithURL:URL];
}

@end
