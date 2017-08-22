//
//  XMPPGroupCoreDataStorageObject+Extensions.h
//  Copyright (c) 2013 IDS Outsource. All rights reserved.
//

#import "XMPPGroupCoreDataStorageObject.h"

@interface XMPPGroupCoreDataStorageObject (Extensions)

+ (XMPPGroupCoreDataStorageObject *)listenersGroup;
+ (XMPPGroupCoreDataStorageObject *)sendersGroup;
+ (XMPPGroupCoreDataStorageObject *)containLocationGroup;

@end
