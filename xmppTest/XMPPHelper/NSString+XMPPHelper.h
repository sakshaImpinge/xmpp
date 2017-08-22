//
//  NSString+XMPPHelper.h
//  Copyright (c) 2013 IDS Outsource. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (XMPPHelper)

+ (NSString *)jidFromEmail:(NSString *)email;
+ (NSString *)jidFromEmailWithoutDomainName:(NSString *)email;

+ (NSString *)jidFromUsername:(NSString *)username;

+ (NSString *)userFromJidStr:(NSString *)jidStr;

@end
