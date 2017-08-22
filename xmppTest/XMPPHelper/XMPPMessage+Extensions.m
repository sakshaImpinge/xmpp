//
//  XMPPMessage+Extensions.m
//  Copyright (c) 2013 IDS Outsource. All rights reserved.
//

#import "XMPPMessage+Extensions.h"

NSString * const kMessageTypeElement    = @"messageType";
NSString * const kExpireElement         = @"expire";
NSString * const kAttachmentElement     = @"attachment";

@implementation XMPPMessage (Extensions)

- (void)setMessageType:(MessageType)type
{
    NSXMLElement *messageTypeElement = [NSXMLElement elementWithName:kMessageTypeElement stringValue:[[[XMPPHelper sharedHelper] messageTypes] objectAtIndex:type]];
    [self addChild:[messageTypeElement copy]];
}

- (MessageType)messageType
{
    NSXMLElement *messageTypeElement = [self elementForName:kMessageTypeElement];
    NSString *messageTypeString = [messageTypeElement stringValue];
    NSUInteger index = [[[XMPPHelper sharedHelper] messageTypes] indexOfObject:messageTypeString];
    if(index == NSNotFound)
    {
        return MessageTypeInvalid;
    }
    
    return (MessageType)index;
}

- (void)setExpire:(NSUInteger)expire
{
    NSXMLElement *expireElement = [NSXMLElement elementWithName:kExpireElement stringValue:[@(expire) stringValue]];
    [self addChild:[expireElement copy]];
}

- (NSUInteger)expire
{
    NSXMLElement *expireElement = [self elementForName:kExpireElement];
    return [expireElement stringValueAsNSUInteger];
}

- (void)setAttachment:(NSString*)attachment
{
    NSXMLElement *expireElement = [NSXMLElement elementWithName:kAttachmentElement stringValue:attachment];
    [self addChild:[expireElement copy]];
}

- (NSString*)attachment
{
    NSXMLElement *expireElement = [self elementForName:kAttachmentElement];
    return [expireElement stringValue];
}

- (BOOL)isSystemMessage
{
    return [[[self attributeForName:@"type"] stringValue] isEqualToString:@"system"];
}

- (BOOL)isSystemMessageScreenshotWasTaken
{
    return [self isSystemMessage] && [self hasAttributeActionWithValue:kActionSystemMessageScreenshotWasTaken];
}

- (BOOL)isSystemMessageUserHasReadMessage
{
    return [self isSystemMessage] && [self hasAttributeActionWithValue:kActionSystemMessageUserHasReadMessage];
}

- (BOOL)isSystemMessageUserHasDeletedMessage
{
    return [self isSystemMessage] && [self hasAttributeActionWithValue:kActionSystemMessageUserHasDeletedMessage];
}

- (BOOL)isSystemMessageUserHasClearedConversation
{
    return [self isSystemMessage] && [self hasAttributeActionWithValue:kActionSystemMessageUserHasClearedConversation];
}

- (BOOL)isSystemMessageMediaIsUploaded
{
    return [self isSystemMessage] && [self hasAttributeActionWithValue:kActionSystemMessageMediaHasUploaded];
}

- (void)setResendThread
{
    NSXMLElement *thread = [NSXMLElement elementWithName:kAttributeNameThread stringValue:kThreadNameResend];
    [self addChild:thread];
}

#pragma mark -
#pragma mark Private

- (BOOL)hasAttributeActionWithValue:(NSString *)value
{
    return [[self attributeStringValueForName:kAttributeNameAction] isEqualToString:value];
}

@end
