//
//  XMPPSearchUser.m
//  Copyright (c) 2013 IDS Outsource. All rights reserved.
//

#import "XMPPSearchUser.h"

@interface XMPPSearchUser ()

@property (nonatomic, strong) NSString *iqUUID;

@end

@implementation XMPPSearchUser

- (void)searchUsersContainsString:(NSString *)searchString orJID:(NSString*)jid
{
    self.iqUUID = [XMPPStream generateUUID];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:[XMPPJID jidWithString:[[NSUserDefaults standardUserDefaults] objectForKey:kXMPPmyJID]] elementID:self.iqUUID];
    [iq addAttributeWithName:@"from" stringValue:[[NSUserDefaults standardUserDefaults] objectForKey:kXMPPmyJID]];
    [iq addAttributeWithName:@"xml:lang" stringValue:@"en"];
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:search"];
    
    NSXMLElement *firstNameElement = [NSXMLElement elementWithName:@"first" stringValue:searchString];
    NSXMLElement *lastNameElement = [NSXMLElement elementWithName:@"last" stringValue:searchString];
    NSXMLElement *usernameElement = [NSXMLElement elementWithName:@"user_name" stringValue:searchString];
    NSXMLElement *emailElement = [NSXMLElement elementWithName:@"email" stringValue:searchString];
 //   NSXMLElement * usernameElement = [NSXMLElement elementWithName:@"user_name" stringValue:searchString ];

    NSXMLElement * jidElement = [NSXMLElement elementWithName:@"jid" stringValue:jid ];
    
    [query addChild:firstNameElement];
    [query addChild:lastNameElement];
    [query addChild:usernameElement];
    [query addChild:emailElement];
    [query addChild:jidElement];
    
   // [query addChild:usernameElement];
    
    [iq addChild:query];
    
    NSLog(@"Search Query is: %@",query);
    
    [[[XMPPHelper sharedHelper] xmppStream] sendElement:iq];
}

- (void)searchExistingUsersByFacebookIds:(NSArray *)facebookIdsArr
{
    self.iqUUID = [XMPPStream generateUUID];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"setmany" to:[XMPPJID jidWithString:[[NSUserDefaults standardUserDefaults] objectForKey:kXMPPmyJID]] elementID:self.iqUUID];
    [iq addAttributeWithName:@"from" stringValue:[[NSUserDefaults standardUserDefaults] objectForKey:kXMPPmyJID]];
    [iq addAttributeWithName:@"xml:lang" stringValue:@"en"];
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:search"];
    
    [facebookIdsArr enumerateObjectsUsingBlock:^(NSString *facebookIdStr, NSUInteger idx, BOOL *stop) {
        NSXMLElement *itemElement = [NSXMLElement elementWithName:@"item"];
        NSXMLElement *idElement = [NSXMLElement elementWithName:@"Id" stringValue:facebookIdStr];
        NSXMLElement *facebookIdElement = [NSXMLElement elementWithName:@"facebook_id" stringValue:facebookIdStr];
        [itemElement addChild:idElement];
        [itemElement addChild:facebookIdElement];
        [query addChild:itemElement];
    }];
    
    [iq addChild:query];
    
    [[[XMPPHelper sharedHelper] xmppStream] sendElement:iq];
}

- (void)searchExistingUsersByPhonesAndEmails:(NSArray *)phonesAndEmailsArr
{
    NSLog(@"%s: arr = %@", __PRETTY_FUNCTION__, phonesAndEmailsArr);
    self.iqUUID = [XMPPStream generateUUID];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"setmany" to:[XMPPJID jidWithString:[[NSUserDefaults standardUserDefaults] objectForKey:kXMPPmyJID]] elementID:self.iqUUID];
    [iq addAttributeWithName:@"from" stringValue:[[NSUserDefaults standardUserDefaults] objectForKey:kXMPPmyJID]];
    [iq addAttributeWithName:@"xml:lang" stringValue:@"en"];
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:search"];
    
    [phonesAndEmailsArr enumerateObjectsUsingBlock:^(NSString *phoneOrEmailStr, NSUInteger idx, BOOL *stop) {
        NSXMLElement *itemElement = [NSXMLElement elementWithName:@"item"];
        NSXMLElement *idElement = [NSXMLElement elementWithName:@"Id" stringValue:phoneOrEmailStr];
        NSString *searchElementName;
        if([phoneOrEmailStr rangeOfString:@"@"].location == NSNotFound)
        {
            searchElementName = @"phone";
        }
        else
        {
            searchElementName = @"email";
        }
        
        NSXMLElement *searchElement = [NSXMLElement elementWithName:searchElementName stringValue:phoneOrEmailStr];
        [itemElement addChild:idElement];
        [itemElement addChild:searchElement];
        [query addChild:itemElement];
    }];
    
    [iq addChild:query];
    
    [[[XMPPHelper sharedHelper] xmppStream] sendElement:iq];
}

#pragma mark -
#pragma mark XMPPStream Delegate

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    if([iq isResultIQ] && [[iq elementID] isEqualToString:self.iqUUID])
    {
        NSXMLElement *query = [iq elementForName:@"query"];
        NSMutableArray *foundUsersJid = [[NSMutableArray alloc] init];
        for(NSXMLElement *item in [query elementsForName:@"item"])
        {
            NSString *jidStr = [[item elementForName:@"jid"] stringValue];
            NSString *idStr = [[item elementForName:@"Id"] stringValue];
            
            NSMutableDictionary *dict = [NSMutableDictionary new];
            
            dict[@"jid"]           = jidStr;
            if (idStr) dict[@"id"] = idStr;
            
            [foundUsersJid addObject:dict];
        }
        [(id <XMPPSearchUserDelegate>)multicastDelegate xmppSearchUser:self
                                                          didFindUsers:foundUsersJid];
        
        return NO;
    }
    
    if([iq isErrorIQ] && [[iq elementID] isEqualToString:self.iqUUID])
    {
        [(id <XMPPSearchUserDelegate>)multicastDelegate xmppSearchUser:self
                                            failedToFindUsersWithError:nil];
        return NO;
    }
	
    return NO;
}

@end
