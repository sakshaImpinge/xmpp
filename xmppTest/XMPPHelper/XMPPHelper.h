#import <Foundation/Foundation.h>

#import <CoreData/CoreData.h>
#import "XMPPFramework.h"
#import "Reachability.h"

@class XMPPRosterCoreDataStorage;
@class XMPPMessageArchivingCoreDataStorage;
@class XMPPvCardCoreDataStorage;
@class XMPPCapabilitiesCoreDataStorage;
@class XMPPSearchUser;

@interface XMPPHelper : NSObject <XMPPReconnectDelegate, NSFetchedResultsControllerDelegate>
{
    CLLocation *oldLocation;
}
@property (nonatomic, strong, readonly) XMPPStream *xmppStream;
@property (nonatomic, strong, readonly) XMPPReconnect *xmppReconnect;
@property (nonatomic, strong, readonly) XMPPRoster *xmppRoster;
@property (nonatomic, strong, readonly) XMPPRosterCoreDataStorage *xmppRosterStorage;
@property (nonatomic, strong, readonly) XMPPMessageArchiving *xmppMessageArchiving;
@property (nonatomic, strong, readonly) XMPPMessageArchivingCoreDataStorage *xmppMessageArchivingStorage;
@property (nonatomic, strong, readonly) XMPPvCardCoreDataStorage *xmppvCardStorage;
@property (nonatomic, strong, readonly) XMPPvCardTempModule *xmppvCardTempModule;
@property (nonatomic, strong, readonly) XMPPvCardAvatarModule *xmppvCardAvatarModule;
@property (nonatomic, strong, readonly) XMPPCapabilities *xmppCapabilities;
@property (nonatomic, strong, readonly) XMPPCapabilitiesCoreDataStorage *xmppCapabilitiesStorage;
@property (nonatomic, strong, readonly) XMPPSearchUser *xmppSearchUser;
@property (nonatomic, strong, readonly) XMPPPing *xmppPing;
@property (nonatomic, strong, readonly) XMPPAutoPing *xmppAutoPing;
@property (nonatomic, strong) NSFetchedResultsController *resultsController;

@property (nonatomic, strong, readonly) XMPPTime *xmppTime;

@property (nonatomic) BOOL allowSelfSignedCertificates;
@property (nonatomic) BOOL allowSSLHostNameMismatch;
@property (nonatomic) BOOL isXmppConnected;
@property (nonatomic) BOOL isRegistering;
@property (nonatomic) BOOL doAutoLogin;
@property (nonatomic) BOOL isDoingNudge;
@property (strong, nonatomic) Reachability * internetReachability;

@property (nonatomic) BOOL manualDisconnect;

@property (nonatomic, strong, readonly) NSArray *messageTypes;
@property (nonatomic,strong) NSString *trackinID;

+ (XMPPHelper*)sharedHelper;

- (BOOL)registerWithFirstName:(NSString *)firstName lastName:(NSString *)lastName username:(NSString *)username jid:(NSString *)jid  email:(NSString *)email password:(NSString *)password;

- (BOOL)connectWithEmail:(NSString *)email password:(NSString *)password;
- (BOOL)connectWithUsername:(NSString *)username password:(NSString *)password;
- (void)disconnect;

- (BOOL)createvCardFromData:(NSDictionary *)vcardDict;
- (BOOL)updatevCardWithNewData:(NSDictionary *)vcardDict;

- (void)goOnline;
- (void)goOffline;
-(void)sendPresence;

- (void)logOut;
- (void)startTimer;
- (void)stopTimer;

- (void)sendMessageOfType:(MessageType)type
                   forJID:(XMPPJID*)jid
                 withText:(NSString*)text;

- (void)sendMessageOfType:(MessageType)type
                   forJID:(XMPPJID*)jid
                 withText:(NSString*)text
                elementId:(NSString*)elementId;

- (void)sendMessageOfType:(MessageType)type
                   forJID:(XMPPJID*)jid
                 withText:(NSString*)text
                elementId:(NSString*)elementId
            shouldArchive:(BOOL)shouldArchive;

- (void)sendMessageOfType:(MessageType)type
                   forJID:(XMPPJID*)jid
                 withText:(NSString*)text
                elementId:(NSString*)elementId
                   expire:(NSUInteger)expire
            shouldArchive:(BOOL)shouldArchive;
- (void)sendMessageOfType:(MessageType)type
                   forJID:(XMPPJID*)jid;

//- (void)sendMessageOfType:(MessageType)type
//          toConversations:(NSSet*)jids
//                 withText:(NSString*)text
//                elementId:(NSString*)elementId
//                   expire:(NSUInteger)expire
//            shouldArchive:(BOOL)shouldArchive;

- (void)sendSystemMessageYouWereAddedToSendersGroup:(XMPPJID *)conversation;
- (void)sendSystemMessageYouWereAddedToListenersGroup:(XMPPJID *)conversation;

- (void)sendSystemMessageYouWereRemovedFromSendersGroup:(XMPPJID *)conversation;
- (void)sendSystemMessageYouWereRemovedFromListenersGroup:(XMPPJID *)conversation;

- (void)sendSystemMessageUserHasClearedConversation:(XMPPJID*)conversation;

- (void)removeUserFromRoster:(XMPPJID*)jid;

- (UIImage *)getMyAvatar;
- (UIImage *)getContactAvatarWithJid:(XMPPJID *)contactJid;
- (void)sendMarkerToAllListeners:(MessageType)marker;
- (void)setMyAvatar:(UIImage *)newAvatar;
- (void)reconnect;
- (void)fetchTheRoster;
- (void)loadContactsFromCoreData;

- (void)startShareLocTimer;
- (void)stopShareLocTimer;

- (void)startIdleTimerOnSocket;
- (void)stopIdleTimerOnSocket;

@end
