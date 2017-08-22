//
//  XMPPStream+Hooks.m
//  FMlocation
//
//  Created by Petro Korenev on 11/8/13.
//  Copyright (c) 2013 Petro Korenev. All rights reserved.
//

#import "XMPPStream+Hooks.h"

@implementation XMPPStream (Hooks)

- (BOOL)supportsInBandRegistration
{
    return YES;
}

@end
