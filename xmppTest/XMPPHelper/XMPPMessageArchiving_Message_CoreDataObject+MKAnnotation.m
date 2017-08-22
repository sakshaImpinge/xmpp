//
//  XMPPMessageArchiving_Message_CoreDataObject+MKAnnotation.m
//  FindMe
//
//  Created by Oleg Komaristov on 14.11.13.
//  Copyright (c) 2013 Petro Korenev. All rights reserved.
//

#import "XMPPMessageArchiving_Message_CoreDataObject+MKAnnotation.h"
#import "XMPPMessage+Extensions.h"

@implementation XMPPMessageArchiving_Message_CoreDataObject (MKAnnotation)

- (CLLocationCoordinate2D)coordinate
{
    NSArray *components = [self.message.attachment componentsSeparatedByString:@","];
    double latitude = 0.f;
    double longitude = 0.f;
    
    if (components.count >= 2)
    {
        latitude = [components.firstObject doubleValue];
        longitude = [components.lastObject doubleValue];
    }
    
    return CLLocationCoordinate2DMake(latitude, longitude);
}

- (NSString *)title
{

    NSArray * bodyComps = [self.message.body componentsSeparatedByString:@","];
    //check if this is string at start and end components
    
    if ([bodyComps[0] isKindOfClass:[NSString class]])
    {
        if(bodyComps.count>3)
        {
        if([bodyComps[3] isKindOfClass:[NSString class]])
        {
        // loc_starts, loc_ends, loc
        
        if(self.message.messageType == MessageTypeLocationStart && [bodyComps[3] isEqualToString:@"footsteps-on"])
            return @"FootSteps Start";
        else if(self.message.messageType == MessageTypeLocationStop && [bodyComps[3] isEqualToString:@"footsteps-off"] )
           return  @"FootSteps End";
        else if(self.message.messageType == MessageTypeLocationStart && [bodyComps[3] isEqualToString:@"on"] )
            return  @"Alert Start";
        else if(self.message.messageType == MessageTypeLocationStop && [bodyComps[3] isEqualToString:@"off"] )
            return @"Alert End";
        // footsteps-on, footsteps-off, off(Alert), on (Alert)
        }
        }
    
    }
        
    if (self.message.messageType == MessageTypeLocationStart && [self.message.body containsString:@"on"]) {
        return @"Alert started";
    }
    else if(self.message.messageType == MessageTypeLocationStop && [self.message.body containsString:@"off"])
    {
        return @"Alert ended";
    }
    else if(self.message.messageType == MessageTypeLocationStart && [self.message.body containsString:@"footsteps-on"])
    {
        return @"FootSteps started";
    }
    else if(self.message.messageType == MessageTypeLocationStop && [self.message.body containsString:@"footsteps-off"])
    {
        return @"FootSteps ended";
    }
    
    else if (self.message.messageType == MessageTypeLocation)
    {
        if ([self.message.body containsString:@"footsteps"]) {
            return @"FootSteps";
        }
        else if([self.message.body containsString:@"on"])
        {
            return @"Alert";
        }
        else if([self.message.body containsString:@"off"])
        {
            return @"Location";
        }
    }
    else if(self.message.messageType == MessageTypeLocationStart)
    {
        return @"Alert started";
    }
    else if(self.message.messageType == MessageTypeLocationStop)
    {
        return @"Alert ended";
    }
    else
    {
        return self.message.body;
    }
    return @"";
    
}

-(NSString*)messagebody
{
    return self.message.body;
}

- (NSString *)subtitle
{
   
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    
    return [dateFormatter stringFromDate:self.timestamp];
}

@end
