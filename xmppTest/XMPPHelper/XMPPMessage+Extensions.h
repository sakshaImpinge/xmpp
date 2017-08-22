//
//  XMPPMessage+Extensions.h
//  Copyright (c) 2013 IDS Outsource. All rights reserved.
//

#import "XMPPMessage.h"

@interface XMPPMessage (Extensions)

@property (nonatomic) MessageType messageType;
@property (nonatomic) NSUInteger expire;
@property (nonatomic) NSString *attachment;

- (BOOL)isSystemMessage;
- (BOOL)isSystemMessageScreenshotWasTaken;
- (BOOL)isSystemMessageUserHasReadMessage;
- (BOOL)isSystemMessageUserHasDeletedMessage;
- (BOOL)isSystemMessageUserHasClearedConversation;
- (BOOL)isSystemMessageMediaIsUploaded;

- (BOOL)hasAttributeActionWithValue:(NSString *)value;

- (void)setResendThread;

@end
