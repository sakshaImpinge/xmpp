//
//  NSString+XMPPHelper.m
//  Copyright (c) 2013 IDS Outsource. All rights reserved.
//

#import "NSString+XMPPHelper.h"
#import "XMPPHelper.h"

@implementation NSString (XMPPHelper)

+ (NSString *)jidFromEmail:(NSString *)email
{
    email = [NSString jidFromEmailWithoutDomainName:email]; // if provided username is actually email
    return [email jidByAddingServerHostName];
}

+ (NSString *)jidFromEmailWithoutDomainName:(NSString *)email
{
    return [email stringByReplacingOccurrencesOfString:@"@" withString:@""];
}

+ (NSString *)jidFromUsername:(NSString *)username
{
    return [username jidByAddingServerHostName];
}

+ (NSString *)userFromJidStr:(NSString *)jidStr
{
    return [[XMPPJID jidWithString:jidStr] user];
}

#pragma mark -
#pragma mark Private

- (NSString *)jidByAddingServerHostName
{
    return [NSString stringWithFormat:@"%@@%@", self, kServerHostname];
}

@end
