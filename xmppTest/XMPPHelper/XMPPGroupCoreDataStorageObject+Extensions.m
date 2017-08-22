//
//  XMPPGroupCoreDataStorageObject+Extensions.m
//  Copyright (c) 2013 IDS Outsource. All rights reserved.
//

#import "XMPPGroupCoreDataStorageObject+Extensions.h"
#import "XMPPHelper.h"
#import "XMPPRosterCoreDataStorage.h"

@implementation XMPPGroupCoreDataStorageObject (Extensions)

+ (XMPPGroupCoreDataStorageObject *)listenersGroup
{
    return [XMPPGroupCoreDataStorageObject fetchOrInsertGroupName:@"__listeners__" inManagedObjectContext:[[XMPPHelper sharedHelper] xmppRosterStorage].mainThreadManagedObjectContext];
}

+ (XMPPGroupCoreDataStorageObject *)sendersGroup
{
    return [XMPPGroupCoreDataStorageObject fetchOrInsertGroupName:@"__senders__" inManagedObjectContext:[[XMPPHelper sharedHelper] xmppRosterStorage].mainThreadManagedObjectContext];
}

+ (XMPPGroupCoreDataStorageObject *)containLocationGroup
{
    return [XMPPGroupCoreDataStorageObject fetchOrInsertGroupName:@"__contain_location__" inManagedObjectContext:[[XMPPHelper sharedHelper] xmppRosterStorage].mainThreadManagedObjectContext];
}

@end
