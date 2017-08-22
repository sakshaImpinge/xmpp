//
//  XMPPSearchUser.h
//  Copyright (c) 2013 IDS Outsource. All rights reserved.
//

#import "XMPPModule.h"

@interface XMPPSearchUser : XMPPModule

- (void)searchUsersContainsString:(NSString *)searchString orJID:(NSString*)jid;


- (void)searchExistingUsersByFacebookIds:(NSArray *)facebookIdsArr;
- (void)searchExistingUsersByPhonesAndEmails:(NSArray *)phonesAndEmailsArr;

@end

@protocol XMPPSearchUserDelegate
@optional

- (void)xmppSearchUser:(XMPPSearchUser *)xmppSearchUser didFindUsers:(NSArray *)foundUsers;

- (void)xmppSearchUser:(XMPPSearchUser *)xmppSearchUser failedToFindUsersWithError:(NSError *)error;

@end
