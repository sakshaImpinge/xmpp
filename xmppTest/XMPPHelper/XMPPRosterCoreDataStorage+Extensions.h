//
//  XMPPRosterCoreDataStorage+Extensions.h
//  Copyright (c) 2013 IDS Outsource. All rights reserved.
//

#import "XMPPRosterCoreDataStorage.h"

@interface XMPPRosterCoreDataStorage (Extensions)

- (NSFetchedResultsController *)getContacts;

- (void)createGroupsFirst;

- (void)addUserToListenersGroup:(XMPPJID *)userJid;
- (void)addUserToSendersGroup:(XMPPJID *)userJid;
- (void)addUserToListenersGroup:(XMPPJID *)userJid noUpdate:(BOOL)noUpdate;
- (void)addUserToSendersGroup:(XMPPJID *)userJid noUpdate:(BOOL)noUpdate;

- (void)addUserToContainLocaitonGroup:(XMPPJID *)userJid;
- (void)addUserToSenderAndContainLocationGroups:(XMPPJID *)userJid;

- (void)removeUserFromListenersGoup:(XMPPJID *)userJid;
- (void)removeUserFromSendersGoup:(XMPPJID *)userJid;
- (void)removeUserFromListenersGoup:(XMPPJID *)userJid noUpdate:(BOOL)noUpdate;
- (void)removeUserFromSendersGoup:(XMPPJID *)userJid noUpdate:(BOOL)noUpdate;

@end
