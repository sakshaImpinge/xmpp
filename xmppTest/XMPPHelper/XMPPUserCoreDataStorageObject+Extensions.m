//
//  XMPPUserCoreDataStorageObject+Extensions.m
//  Copyright (c) 2013 IDS Outsource. All rights reserved.
//

#import "XMPPUserCoreDataStorageObject+Extensions.h"

#import "XMPPRosterCoreDataStorage+Extensions.h"
#import "NSString+XMPPHelper.h"

@implementation XMPPUserCoreDataStorageObject (Extensions)

#pragma mark - Update user on the server side

- (void)sendUpdatedUser
{
    NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	[item addAttributeWithName:@"jid" stringValue:self.jidStr];
    
	if(self.nickname)
	{
		[item addAttributeWithName:@"name" stringValue:self.nickname];
	}
    
	for (XMPPGroupCoreDataStorageObject *group in self.groups) {
		NSXMLElement *groupElement = [NSXMLElement elementWithName:@"group"];
		[groupElement setStringValue:group.name];
		[item addChild:groupElement];
	}
    
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:roster"];
	[query addChild:item];
    
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"type" stringValue:@"set"];
	[iq addChild:query];
    
	[[[XMPPHelper sharedHelper] xmppStream] sendElement:iq];
}

@end
