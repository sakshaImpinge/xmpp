//
//  XMPPRosterCoreDataStorage+Extensions.m
//  Copyright (c) 2013 IDS Outsource. All rights reserved.
//

#import "XMPPRosterCoreDataStorage+Extensions.h"
#import "NSString+XMPPHelper.h"
#import "XMPPGroupCoreDataStorageObject+Extensions.h"
#import "XMPPUserCoreDataStorageObject+Extensions.h"
#import "XMPPCoreDataStorageProtected.h"

@implementation XMPPRosterCoreDataStorage (Extensions)

- (NSFetchedResultsController *)getContacts
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([XMPPUserCoreDataStorageObject class])];
    
    [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"displayName" ascending:YES]]];
    //Setting predicate here to only fetch friends of logged in user from xmpp local storage
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"streamBareJidStr = %@",[[NSUserDefaults standardUserDefaults] valueForKey:kXMPPmyJID]]];
    return [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                               managedObjectContext:[self mainThreadManagedObjectContext]
                                                 sectionNameKeyPath:nil
                                                          cacheName:nil];
}

- (void)addUser:(XMPPJID *)userJid toGroup:(NSString *)group
{
    [self addUser:userJid toGroup:group noUpdate:YES];
}

- (void)createGroupsFirst
{
    [[XMPPHelper sharedHelper].xmppRosterStorage scheduleBlock:^{
        NSManagedObjectContext *context = [XMPPHelper sharedHelper].xmppRosterStorage.managedObjectContext;
        [XMPPGroupCoreDataStorageObject fetchOrInsertGroupName:@"__senders__" inManagedObjectContext:context];
        [XMPPGroupCoreDataStorageObject fetchOrInsertGroupName:@"__listeners__" inManagedObjectContext:context];
        [XMPPGroupCoreDataStorageObject fetchOrInsertGroupName:@"__contain_location__" inManagedObjectContext:context];
        [context save:nil];
    }];
}

- (void)addUser:(XMPPJID *)userJid toGroup:(NSString *)group noUpdate:(BOOL)noUpdate
{
    [[XMPPHelper sharedHelper].xmppRosterStorage scheduleBlock:^{
        NSManagedObjectContext *context = [XMPPHelper sharedHelper].xmppRosterStorage.managedObjectContext;
        
        XMPPUserCoreDataStorageObject *user = [[XMPPHelper sharedHelper].xmppRosterStorage userForJID:userJid
                                                                                           xmppStream:nil
                                                                                 managedObjectContext:context];
        
        if (!user)
        {
			NSString *streamBareJidStr = [[[[XMPPHelper sharedHelper] xmppStream] myJID] bare];
			
            XMPPUserCoreDataStorageObject *newUser;
            newUser = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPUserCoreDataStorageObject"
                                                    inManagedObjectContext:context];
            
            newUser.jidStr = userJid.bare;
            newUser.streamBareJidStr = streamBareJidStr;
            
            newUser.nickname = userJid.user;
            
            newUser.displayName = (newUser.nickname != nil) ? newUser.nickname : newUser.jidStr;
            
            newUser.subscription = @"both";
            newUser.ask = @"subscription";
            
            user = newUser;
        }
        
/*
        if (![user.groups containsObject:[XMPPGroupCoreDataStorageObject fetchOrInsertGroupName:group inManagedObjectContext:context]])
        {
*/
            [user addGroupsObject:[XMPPGroupCoreDataStorageObject fetchOrInsertGroupName:group inManagedObjectContext:context]];
            if ([group isEqualToString:@"__listeners__"])
            {
                [user addGroupsObject:[XMPPGroupCoreDataStorageObject fetchOrInsertGroupName:@"__contain_location__" inManagedObjectContext:context]];
            }
            if (!noUpdate)
            {
                if ([group isEqualToString:@"__senders__"])
                {
                    [[XMPPHelper sharedHelper] sendSystemMessageYouWereAddedToSendersGroup:user.jid];
                }
                else if ([group isEqualToString:@"__listeners__"])
                {
                    [[XMPPHelper sharedHelper] sendSystemMessageYouWereAddedToListenersGroup:user.jid];
                }
            }
            [context save:nil];
            [[[XMPPHelper sharedHelper] xmppRoster] addUser:userJid withNickname:nil];
//            [[[XMPPHelper sharedHelper] xmppRoster] addUser:userJid withNickname:nil groups:@[group] subscribeToPresence:NO];
/*
        }
*/
    }];
}

- (void)removeUser:(XMPPJID *)userJid fromGroup:(NSString *)groupName
{
    [self removeUser:userJid fromGroup:groupName noUpdate:YES];
}

- (void)removeUser:(XMPPJID *)userJid fromGroup:(NSString *)groupName noUpdate:(BOOL)noUpdate
{
    [[XMPPHelper sharedHelper].xmppRosterStorage scheduleBlock:^{
        NSManagedObjectContext *context = [XMPPHelper sharedHelper].xmppRosterStorage.managedObjectContext;
        
        XMPPUserCoreDataStorageObject *user = [[XMPPHelper sharedHelper].xmppRosterStorage userForJID:userJid
                                                                                           xmppStream:nil
                                                                                 managedObjectContext:context];
        XMPPGroupCoreDataStorageObject *group = (XMPPGroupCoreDataStorageObject *)[XMPPGroupCoreDataStorageObject fetchOrInsertGroupName:groupName inManagedObjectContext:context];
        
/*
        if ([user.groups containsObject:group])
        {
*/
            [user removeGroupsObject:group];
//            [user sendUpdatedUser];
            if (!noUpdate)
            {
                if ([groupName isEqualToString:@"__senders__"])
                {
                    [[XMPPHelper sharedHelper] sendSystemMessageYouWereRemovedFromSendersGroup:user.jid];
                }
                else if ([groupName isEqualToString:@"__listeners__"])
                {
                    [[XMPPHelper sharedHelper] sendSystemMessageYouWereRemovedFromListenersGroup:user.jid];
                }
            }
            [context save:nil];
/*
        }
*/
    }];
}

- (void)addUserToSenderAndContainLocationGroups:(XMPPJID *)userJid
{
    [[XMPPHelper sharedHelper].xmppRosterStorage scheduleBlock:^{
        NSManagedObjectContext *context = [XMPPHelper sharedHelper].xmppRosterStorage.managedObjectContext;
        
        XMPPUserCoreDataStorageObject *user = [[XMPPHelper sharedHelper].xmppRosterStorage userForJID:userJid
                                                                                           xmppStream:nil
                                                                                 managedObjectContext:context];
        
        if (![user.groups containsObject:[XMPPGroupCoreDataStorageObject fetchOrInsertGroupName:@"__contain_location__" inManagedObjectContext:context]] ||
            ![user.groups containsObject:[XMPPGroupCoreDataStorageObject fetchOrInsertGroupName:@"__senders__" inManagedObjectContext:context]])
        {
            [[[XMPPHelper sharedHelper] xmppRoster] addUser:userJid withNickname:nil groups:@[@"__contain_location__", @"__senders__"] subscribeToPresence:NO];
        }
    }];
}

- (void)addUserToListenersGroup:(XMPPJID *)userJid
{
    [self addUserToListenersGroup:userJid noUpdate:NO];
}

- (void)addUserToListenersGroup:(XMPPJID *)userJid noUpdate:(BOOL)noUpdate
{
    [self addUser:userJid toGroup:@"__listeners__" noUpdate:noUpdate];
}

- (void)addUserToSendersGroup:(XMPPJID *)userJid
{
    [self addUserToSendersGroup:userJid noUpdate:NO];
}

- (void)addUserToSendersGroup:(XMPPJID *)userJid noUpdate:(BOOL)noUpdate
{
    [self addUser:userJid toGroup:@"__senders__" noUpdate:noUpdate];
}

- (void)addUserToContainLocaitonGroup:(XMPPJID *)userJid
{
    [self addUser:userJid toGroup:@"__contain_location__"];
}

- (void)removeUserFromListenersGoup:(XMPPJID *)userJid
{
    [self removeUserFromListenersGoup:userJid noUpdate:NO];
}

- (void)removeUserFromListenersGoup:(XMPPJID *)userJid noUpdate:(BOOL)noUpdate
{
    [self removeUser:userJid fromGroup:@"__listeners__" noUpdate:noUpdate];
}

- (void)removeUserFromSendersGoup:(XMPPJID *)userJid
{
    [self removeUserFromSendersGoup:userJid noUpdate:NO];
}

- (void)removeUserFromSendersGoup:(XMPPJID *)userJid noUpdate:(BOOL)noUpdate
{
    [self removeUser:userJid fromGroup:@"__senders__" noUpdate:noUpdate];
}

@end
