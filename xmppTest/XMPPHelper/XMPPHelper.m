//
//  XMPPHelper.m
//  Copyright (c) 2013 IDS Outsource. All rights reserved.
//

#import "XMPPHelper.h"

#import "NSString+XMPPHelper.h"
#import "XMPPMessage+Extensions.h"
#import "XMPPCoreDataStorageProtected.h"
#import "XMPPRosterCoreDataStorage+Extensions.h"
#import "Reachability.h"

#import "AppDelegate.h"

#import "DDLog.h"
#import "DDTTYLogger.h"

#import <CFNetwork/CFNetwork.h>

#import "StorageManager.h"

#import "XMPPCoreDataStorage.h"
#import "XMPPRosterCoreDataStorage.h"
#import "XMPPMessageArchivingCoreDataStorage.h"
#import "XMPPvCardCoreDataStorage.h"
#import "XMPPvCardTemp.h"
#import "XMPPCapabilitiesCoreDataStorage.h"
#import "XMPPSearchUser.h"
#import "DataManager.h"
#import "JSONKit.h"
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@interface XMPPHelper () <XMPPStreamDelegate, CLLocationManagerDelegate>
{
    dispatch_source_t timer;
    dispatch_source_t idleTimer;
    dispatch_source_t shareLocTimer;
    dispatch_source_t checkerTimer;
    CLLocation *lastloc;
    dispatch_source_t trackingTimer;

}
@property (nonatomic, strong) NSMutableArray *mLocationArray;
@property (nonatomic, strong, readwrite) XMPPStream *xmppStream;
@property (nonatomic, strong, readwrite) XMPPReconnect *xmppReconnect;
@property (nonatomic, strong, readwrite) XMPPRoster *xmppRoster;
@property (nonatomic, strong, readwrite) XMPPRosterCoreDataStorage *xmppRosterStorage;
@property (nonatomic, strong, readwrite) XMPPMessageArchiving *xmppMessageArchiving;
@property (nonatomic, strong, readwrite) XMPPMessageArchivingCoreDataStorage *xmppMessageArchivingStorage;
@property (nonatomic, strong, readwrite) XMPPvCardCoreDataStorage *xmppvCardStorage;
@property (nonatomic, strong, readwrite) XMPPvCardTempModule *xmppvCardTempModule;
@property (nonatomic, strong, readwrite) XMPPvCardAvatarModule *xmppvCardAvatarModule;
@property (nonatomic, strong, readwrite) XMPPCapabilities *xmppCapabilities;
@property (nonatomic, strong, readwrite) XMPPCapabilitiesCoreDataStorage *xmppCapabilitiesStorage;
@property (nonatomic, strong, readwrite) XMPPSearchUser *xmppSearchUser;

@property (nonatomic, strong, readwrite) CLLocationManager *locationManager;
@property (nonatomic, strong, readwrite) CLLocation *location;

@property (nonatomic, strong, readwrite) NSArray *messageTypes;
@property (nonatomic,strong)  NSMutableArray *liveTrackingData;
@end

@implementation XMPPHelper

@synthesize xmppRoster,xmppRosterStorage,xmppAutoPing,resultsController,mLocationArray;

+ (XMPPHelper *)sharedHelper
{
    static XMPPHelper* sharedHelper;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        [DDLog addLogger:[DDTTYLogger sharedInstance]];
        sharedHelper.allowSelfSignedCertificates = YES;
        
        sharedHelper = [[XMPPHelper alloc] initAndSetupStream];
        
        sharedHelper.messageTypes     = @[kMessageTypeInvalid,
                                          kMessageTypeText,
                                          kMessageTypeLocationStart,
                                          kMessageTypeLocation,
                                          kMessageTypeLocationStop];
        
//        sharedHelper.locationManager = [[CLLocationManager alloc] init];
//        sharedHelper.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
//        sharedHelper.locationManager.delegate = sharedHelper;
////        sharedHelper.locationManager.activityType = CLActivityTypeAutomotiveNavigation;
//        [sharedHelper.locationManager setDesiredAccuracy:kCLLocationAccuracyBest];
//         sharedHelper.locationManager.activityType = CLActivityTypeFitness;
//         sharedHelper.locationManager.distanceFilter = 10;
//        [sharedHelper.locationManager startMonitoringSignificantLocationChanges];
//        [sharedHelper.locationManager startUpdatingLocation];
//        sharedHelper.isDoingNudge = false;
//        sharedHelper.doAutoLogin = true;
//        sharedHelper.location = sharedHelper.locationManager.location;
//        sharedHelper.mLocationArray=[NSMutableArray new];
//        // [sharedHelper loadContactsFromCoreData];
        
        sharedHelper.locationManager = [[CLLocationManager alloc] init];
        sharedHelper.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        sharedHelper.locationManager.delegate = sharedHelper;
        sharedHelper.locationManager.activityType = CLActivityTypeAutomotiveNavigation;
        [sharedHelper.locationManager startUpdatingLocation];
        sharedHelper.isDoingNudge = false;
        sharedHelper.doAutoLogin = true;
        sharedHelper.location = sharedHelper.locationManager.location;
        
        sharedHelper.liveTrackingData = [NSMutableArray new];
        
    });
    
    if(!sharedHelper.xmppStream)
    {
        [sharedHelper setupStream];
    }
    
    return sharedHelper;
}


-(void)loadContactsFromCoreData
{
    if (![XMPPHelper sharedHelper].resultsController) {
        [[XMPPHelper sharedHelper] setManualDisconnect:NO];
        [[XMPPHelper sharedHelper].xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
        
        [XMPPHelper sharedHelper].resultsController = [[XMPPHelper sharedHelper] xmppRosterStorage].getContacts;
        [XMPPHelper sharedHelper].resultsController.delegate = self;
        [[XMPPHelper sharedHelper].resultsController performFetch:nil];
    }
}


- (id)initAndSetupStream
{
    self = [super init];
    
    if(self)
    {
        [self setupStream];
    }
    
    return self;
}

- (void)dealloc
{
    [self teardownStream];
}

#pragma mark -
#pragma mark Setup / Delete Stream

- (void)setupStream
{
    NSAssert(self.xmppStream == nil, @"Method setupStream invoked multiple times");
    
    // Setup xmpp stream
    //
    // The XMPPStream is the base class for all activity.
    // Everything else plugs into the xmppStream, such as modules/extensions and delegates.
    
    self.xmppStream = [[XMPPStream alloc] init];
    
#if !TARGET_IPHONE_SIMULATOR
    {
        // Want xmpp to run in the background?
        //
        // P.S. - The simulator doesn't support backgrounding yet.
        //        When you try to set the associated property on the simulator, it simply fails.
        //        And when you background an app on the simulator,
        //        it just queues network traffic til the app is foregrounded again.
        //        We are patiently waiting for a fix from Apple.
        //        If you do enableBackgroundingOnSocket on the simulator,
        //        you will simply see an error message from the xmpp stack when it fails to set the property.
        
        self.xmppStream.enableBackgroundingOnSocket = YES;
    }
#endif
    
    // Setup reconnect
    //
    // The XMPPReconnect module monitors for "accidental disconnections" and
    // automatically reconnects the stream for you.
    // There's a bunch more information in the XMPPReconnect header file.
    
    self.xmppReconnect = [[XMPPReconnect alloc] init];
    [self.xmppReconnect setAutoReconnect:YES];
    
    [self.xmppReconnect addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    // Setup capabilities
    //
    // The XMPPCapabilities module handles all the complex hashing of the caps protocol (XEP-0115).
    // Basically, when other clients broadcast their presence on the network
    // they include information about what capabilities their client supports (audio, video, file transfer, etc).
    // But as you can imagine, this list starts to get pretty big.
    // This is where the hashing stuff comes into play.
    // Most people running the same version of the same client are going to have the same list of capabilities.
    // So the protocol defines a standardized way to hash the list of capabilities.
    // Clients then broadcast the tiny hash instead of the big list.
    // The XMPPCapabilities protocol automatically handles figuring out what these hashes mean,
    // and also persistently storing the hashes so lookups aren't needed in the future.
    //
    // Similarly to the roster, the storage of the module is abstracted.
    // You are strongly encouraged to persist caps information across sessions.
    //
    // The XMPPCapabilitiesCoreDataStorage is an ideal solution.
    // It can also be shared amongst multiple streams to further reduce hash lookups.
    
    // Activate xmpp modules
    
    self.xmppCapabilitiesStorage = [XMPPCapabilitiesCoreDataStorage sharedInstance];
    self.xmppCapabilities = [[XMPPCapabilities alloc] initWithCapabilitiesStorage:self.xmppCapabilitiesStorage];
    
    self.xmppCapabilities.autoFetchHashedCapabilities = YES;
    self.xmppCapabilities.autoFetchNonHashedCapabilities = NO;
    //    self.xmppStream.autoStartTLS = YES;
    
    // self.xmppSearchUser = [[XMPPSearchUser alloc] init];
    //
    //    xmppRosterStorage = [[XMPPRosterCoreDataStorage alloc] init];
    //
    //    //	xmppRosterStorage = [[XMPPRosterCoreDataStorage alloc] initWithInMemoryStore];
    //
    //    xmppRoster = [[XMPPRoster alloc] initWithRosterStorage:xmppRosterStorage];
    //    xmppRoster.autoFetchRoster = YES;
    //	xmppRoster.autoAcceptKnownPresenceSubscriptionRequests = YES;
    //
    //
    //    [self.xmppRoster activate:self.xmppStream];
    
    // [self setupRoster];
    
    // xmppAutoPing =  [[XMPPAutoPing alloc] init];
    // [xmppAutoPing setPingInterval:10];
    // [xmppAutoPing addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    
    xmppRosterStorage = [[XMPPRosterCoreDataStorage alloc] init];
    
    
    xmppRoster = [[XMPPRoster alloc] initWithRosterStorage:xmppRosterStorage];
    
    xmppRoster.autoFetchRoster = YES;
    xmppRoster.autoAcceptKnownPresenceSubscriptionRequests = YES;
    [xmppRoster addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    [self setupMessageArchiving];
    [self.xmppStream setKeepAliveInterval:10.0];
    [self.xmppReconnect               activate:self.xmppStream];
    [self.xmppRoster                  activate:self.xmppStream];
    // [self.xmppAutoPing               activate:self.xmppStream];
    [self.xmppvCardTempModule         activate:self.xmppStream];
    [self.xmppvCardAvatarModule       activate:self.xmppStream];
    [self.xmppCapabilities            activate:self.xmppStream];
    // [self.xmppSearchUser              activate:self.xmppStream];
    
    // Add ourself as a delegate to anything we may be interested in
    
    // dispatch_queue_t background = dispatch_queue_create("com.beacon.xmppstream", 0);
    
    [self.xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    //[self.xmppRoster addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    // Optional:
    //
    // Replace me with the proper domain and port.
    // The example below is setup for a typical google talk account.
    //
    // If you don't supply a hostName, then it will be automatically resolved using the JID (below).
    // For example, if you supply a JID like 'user@quack.com/rsrc'
    // then the xmpp framework will follow the xmpp specification, and do a SRV lookup for quack.com.
    //
    // If you don't specify a hostPort, then the default (5222) will be used.
    
    [self.xmppStream setHostName:kServerHostname];
    //	[xmppStream setHostPort:5222];
    
    // You may need to alter these settings depending on the server you're connecting to
    self.allowSelfSignedCertificates = YES;
    self.allowSSLHostNameMismatch = YES;
    
    //self.xmppStream.enableBackgroundingOnSocket = NO;

}

- (void)teardownStream
{
    [self.xmppStream removeDelegate:self];
    [self.xmppRoster removeDelegate:self];
    
    [self.xmppReconnect               deactivate];
    [self.xmppRoster                  deactivate];
    [self.xmppMessageArchiving        deactivate];
    [self.xmppvCardTempModule         deactivate];
    [self.xmppvCardAvatarModule       deactivate];
    
    [self.xmppStream disconnect];
    
    self.xmppStream = nil;
    self.xmppReconnect = nil;
    self.xmppRoster = nil;
    self.xmppRosterStorage = nil;
    self.xmppMessageArchiving = nil;
    self.xmppMessageArchivingStorage = nil;
    self.xmppvCardStorage = nil;
    self.xmppvCardTempModule = nil;
    self.xmppvCardAvatarModule = nil;
}

#pragma mark -
#pragma mark Registration

- (BOOL)registerWithFirstName:(NSString *)firstName lastName:(NSString *)lastName username:(NSString *)username jid:(NSString *)jid  email:(NSString *)email password:(NSString *)password
{//birthday
    NSXMLElement *jidElement = [NSXMLElement elementWithName:@"username" stringValue:username]; //jid without domain name. Use only for create JID
    NSXMLElement *passwordElement = [NSXMLElement elementWithName:@"password" stringValue:password];
    NSXMLElement *firstNameElement = [NSXMLElement elementWithName:@"first" stringValue:firstName];
    NSXMLElement *lastNameElement = [NSXMLElement elementWithName:@"last" stringValue:lastName];
    NSXMLElement *usernameElement = [NSXMLElement elementWithName:@"nick" stringValue:username ]; //username = nickname = displayname
    NSXMLElement *emailElement = [NSXMLElement elementWithName:@"email" stringValue:email];
    
    NSArray *registrationElements = @[jidElement,
                                      passwordElement,
                                      firstNameElement,
                                      lastNameElement,
                                      usernameElement,
                                      emailElement];
    
    NSLog(@"Registration elements = %@", registrationElements);
    
    NSError *error = nil;
    
    if(![self.xmppStream registerWithElements:registrationElements error:&error])
    {
        DDLogError(@"Error registration: %@", error);
        
        return NO;
    }
    
    return YES;
}

#pragma mark -
#pragma mark Connect / disconnect

- (BOOL)connectWithEmail:(NSString *)email password:(NSString *)password
{
    return [self connectWithJidStr:[NSString jidFromEmail:email] password:password];
}

- (BOOL)connectWithUsername:(NSString *)username password:(NSString *)password
{
    return [self connectWithJidStr:[NSString jidFromUsername:username] password:password];
}

- (void)disconnect
{
    self.manualDisconnect = YES;
    [self goOffline];
    [self.xmppStream disconnect];
}



-(void)startMonitoringReachability
{
    //    self.internetReachability = [Reachability reachabilityForInternetConnection];
    //	[self.internetReachability startNotifier];
    //	[self reconnectLogin:self.internetReachability];
    //
    //    self.hostReachability = [Reachability reachabilityWithHostName:kServerHostname];
    //	[self.hostReachability startNotifier];
    //	[self reconnectLogin:self.hostReachability];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    
    self.internetReachability = [Reachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
    //	[self reconnectLogin:self.internetReachability];
    
    //    self.wifiReachability = [Reachability reachabilityForLocalWiFi];
    //	[self.wifiReachability startNotifier];
    //	[self reconnectLogin:self.wifiReachability];
}

- (void)reachabilityChanged:(NSNotification *)note
{
    Reachability* curReach = [note object];
    NSParameterAssert([curReach isKindOfClass:[Reachability class]]);
    [self reconnectLogin:curReach];
}

- (void)reconnectLogin:(Reachability *)reachability
{
    NetworkStatus netStatus = [reachability currentReachabilityStatus];
    BOOL connectionRequired = [reachability connectionRequired];
    NSString* statusString = @"";
    
    //    if (connectionRequired) {
    //        [[XMPPHelper sharedHelper] reconnect];
    //    }
    
    
    switch (netStatus)
    {
        case NotReachable:        {
            statusString = NSLocalizedString(@"Access Not Available", @"Text field text for access is not available");
            // imageView.image = [UIImage imageNamed:@"stop-32.png"] ;
            /*
             Minor interface detail- connectionRequired may return YES even when the host is unreachable. We cover that up here...
             */
            
            // BOOL isHostReachable = NO/*[(AppDelegate*)[[UIApplication sharedApplication] delegate] isHostReachable]*/;
            
            // dispatch_sync(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"noInternet" object:nil];
            
            //  });
            
            connectionRequired = NO;
            [self reconnect];
            break;
        }
            
        case ReachableViaWWAN:        {
            statusString = NSLocalizedString(@"Reachable WWAN", @"");
            //imageView.image = [UIImage imageNamed:@"WWAN5.png"];
            [self reconnect];
            break;
        }
        case ReachableViaWiFi:        {
            statusString= NSLocalizedString(@"Reachable WiFi", @"");
            //imageView.image = [UIImage imageNamed:@"Airport.png"];
            [self reconnect];
            break;
        }
    }
    
    if (connectionRequired)
    {
        NSString *connectionRequiredFormatString = NSLocalizedString(@"%@, Connection Required", @"Concatenation of status string with connection requirement");
        statusString= [NSString stringWithFormat:connectionRequiredFormatString, statusString];
    }
}




-(void)reconnect
{
    if (!self.manualDisconnect) {
        
        [[XMPPHelper sharedHelper].xmppStream disconnect];
        
        if(![[XMPPHelper sharedHelper] connectWithUsername:[NSString userFromJidStr:[[NSUserDefaults standardUserDefaults] objectForKey:kXMPPmyJID]]
                                                  password:[[DataManager sharedDataManager] getVerifyCode]])
        {
            NSLog(@"Reconnecting ...");
            //  self.lblNetState.text = @"REconnecting...";
        }
        else {
            //  self.lblNetState.text = @"connected";
            [[NSUserDefaults standardUserDefaults] setValue:@"connected" forKey:@"netstate"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        
        
    }
    
    
    
}


#pragma mark -
#pragma mark vCard Managment

- (BOOL)createvCardFromData:(NSDictionary *)vcardDict
{
    return [self updatevCardWithData:vcardDict shouldCreateNewvCard:YES];
}

- (BOOL)updatevCardWithNewData:(NSDictionary *)vcardDict
{
    return [self updatevCardWithData:vcardDict shouldCreateNewvCard:NO];
}

#pragma mark -
#pragma mark Go Online / Offline

-(void)sendPresence
{
    NSString * status = [[NSUserDefaults standardUserDefaults] valueForKey:@"myState"];
    
    if (!status) {
        status = @"off";
    }
    XMPPPresence *presence = [XMPPPresence presence]; // type="available" is implicit
    
    DDXMLElement *element = [DDXMLElement elementWithName:@"nick" stringValue:status];
    DDXMLElement * element2=  [DDXMLElement elementWithName:@"status" stringValue:status];
    
    [presence addChild: element];
    [presence addChild:element2];
    
    NSLog(@"Presence Sent %@",presence);
    
    [[self xmppStream] sendElement:presence];
    
}


- (void)goOnline
{
    [self sendPresence];
    // [self setupRoster];
    ///  [self setupMessageArchiving];
    // [self setupvCard];
    
    // [self.xmppvCardTempModule fetchvCardTempForJID:self.xmppStream.myJID ignoreStorage:YES];
    [self fetchTheRoster];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    NSString * myState = [[NSUserDefaults standardUserDefaults] valueForKey:@"myState"];
    
    if (myState) {
        if ([myState isEqualToString:@"on"]) {
            [self didBecomeActive:nil];
            [self startTimer];
        }
    }
    
    //  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
}


-(void)startCheckerTimer
{
    checkerTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));
    if (checkerTimer)
    {
        dispatch_source_set_timer(checkerTimer, 20000 * 60.f *15.f,20000 * 60.f *15.f * 10000, NSEC_PER_SEC /10);
        dispatch_source_set_event_handler(checkerTimer, ^()
                                          {
                                              [self checkIfLocShareOrEmergency];
                                          });
        dispatch_resume(checkerTimer);
    }
    
}

-(void)checkIfLocShareOrEmergency
{
    //Immediate Notification Not needed
//    if (timer) {
//        UILocalNotification * theNotification = [[UILocalNotification alloc] init];
//        theNotification.alertBody = @"Are you still in an emergency ? If not, please turn off the Alert feature in Silent Beacon App.";
//        theNotification.alertAction = @"send alerts";
//        if ([[DataManager sharedDataManager] getSoundToggle]) {
//            theNotification.soundName = @"beep-1";
//        }
//        [[UIApplication sharedApplication] presentLocalNotificationNow:theNotification];
//        
//    }
//    else
    if(shareLocTimer)
    {
        UILocalNotification * theNotification = [[UILocalNotification alloc] init];
        theNotification.alertBody = @"Footsteps shares your location continuously. Please turn it off if you don't need to share your location anymore.";
        theNotification.alertAction = @"send alerts";
        if ([[DataManager sharedDataManager] getSoundToggle]) {
            theNotification.soundName = @"beep-1";
        }
        [[UIApplication sharedApplication] presentLocalNotificationNow:theNotification];
        
    }
}

- (void)goOffline
{
    XMPPPresence *presence = [XMPPPresence presenceWithType:@"unavailable"];
    
    [self.xmppStream sendElement:presence];
    
    [self stopTimer];
    [self stopShareLocTimer];
    [self stopIdleTimerOnSocket];
}

- (void)startTimer
{
    
//    if (!resultsController) {
//        [self loadContactsFromCoreData];
//    }
//    else
//    {
    
            if (!resultsController) {
                [self loadContactsFromCoreData];
            }
        [self stopShareLocTimer];
        [self stopIdleTimerOnSocket];
    
    
    //Live tracking timer
    if (!trackingTimer)
    {
        _trackinID = [self randomStringWithLength:10];
        NSLog(@"Tracking ID : %@",_trackinID);
        
        trackingTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));
        
        dispatch_source_set_timer(trackingTimer, dispatch_walltime(NULL, 0), NSEC_PER_SEC * 25.f, NSEC_PER_SEC);
        dispatch_source_set_event_handler(trackingTimer, ^()
                                          {
                                              [self startShareLocationsForLiveTracking];
                                          });
        dispatch_resume(trackingTimer);
    }

    
    // Share ypur location with other users in your list
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));
        if (timer)
        {
            dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), NSEC_PER_SEC * 2.f, NSEC_PER_SEC);
            dispatch_source_set_event_handler(timer, ^()
                                              {
                                                  [self informEverybodyAboutMyLocation];
                                              });
            dispatch_resume(timer);
        }
        
    
   //}
    checkerTimer = nil;
    [self startCheckerTimer];
    
}

#pragma mark -- Live Tracking Methods

-(void)startShareLocationsForLiveTracking
{

    NSLog(@"Share Live Track");
    if(_liveTrackingData.count)
    {
    NSString * postString;
    NSString * username = [[DataManager sharedDataManager] getYourFirstName];
    Request * request = [Request sharedInstance];
//    postString = [NSString stringWithFormat:@"&track_id=%@&location_data=%@&name=%@&device_type=%@",_trackinID,[_liveTrackingData JSONString],username,@"iPhone"];
    postString = [postString stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
    request.delegate = (id)self;
        
    NSDictionary *dict =     @{@"track_id"          : _trackinID,
                              @"location_data"     : _liveTrackingData,
                              @"name"              :username,
                              @"device_type"       :@"iPhone"
                              };
        
        NSError * err;
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&err];
        NSString * myString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [request performAsynchronousPOSTRequest:@"method=setTrackingRecords" PostDict:myString];
    }
}

-(void)stopTimerForLiveTracking
{
    NSLog(@"Stop Live Track");
    if (trackingTimer)
    {
        dispatch_source_cancel(trackingTimer);
        trackingTimer = nil;
        
        [self startShareLocationsForLiveTracking];
        _trackinID = nil;
        [_liveTrackingData removeAllObjects];
    }

}

-(NSString *) randomStringWithLength: (int) len {
    
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
    
    for (int i=0; i<len; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random_uniform([letters length])]];
    }
    
    return randomString;
}

- (void)requestFinishedSuccessfully:(Request *)request withDictionaryInResponse:(NSMutableDictionary *)responseDictionary
{
    NSLog(@"response here !%@", responseDictionary);
    
}


- (void)startIdleTimerOnSocket
{
    idleTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));
    if (idleTimer)
    {
        dispatch_source_set_timer( idleTimer, dispatch_walltime(NULL, 0), NSEC_PER_SEC * 9.f, NSEC_PER_SEC / 10);
        dispatch_source_set_event_handler(idleTimer, ^()
                                          {
                                              [self sendIdleMessageOnSocket];
                                          });
        dispatch_resume(idleTimer);
    }
}

-(void)stopIdleTimerOnSocket
{
    if (idleTimer) {
        dispatch_source_cancel(idleTimer);
        idleTimer = nil;
        
    }
}



- (void)stopTimer
{
    if (timer)
    {
        dispatch_source_cancel(timer);
        timer = nil;
    }
    
    [self stopTimerForLiveTracking];
}


- (void)removeUserFromRoster:(XMPPJID*)jid
{
    [[self xmppRosterStorage] removeUserWith:jid xmppStream:self.xmppStream];
}

- (void)informEverybodyAboutMyLocation
{
    
    if (!resultsController) {
        [self loadContactsFromCoreData];
    }
    
    [[XMPPHelper sharedHelper].xmppRosterStorage scheduleBlock:^{
        
        
        for (XMPPUserCoreDataStorageObject *user in resultsController.fetchedObjects){
            
           // NSString * contactNumber = [user.jidStr stringByReplacingOccurrencesOfString:kServerAtHostname withString:@""];            //if ([user.subscription isEqualToString:@"both"]) {
            [self sendMessageOfType:MessageTypeLocation forJID:user.jid withText:@" "];
            //}
        }
    }];
}


- (void)sendIdleMessageOnSocket;
{
    XMPPJID * jid = [XMPPJID jidWithString:[NSString stringWithFormat:@"admin%@", kServerAtHostname]];
    
    [self sendMessageOfType:MessageTypeInvalid forJID:jid withText:@""];
}


-(void)shareLoc
{
    
    if (!resultsController) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadContactsFromCoreData];
        });
    
    }
    
    [[XMPPHelper sharedHelper].xmppRosterStorage scheduleBlock:^{
        
        
        for (XMPPUserCoreDataStorageObject *user in resultsController.fetchedObjects){
            
            NSString * contactNumber = [user.jidStr stringByReplacingOccurrencesOfString:kServerAtHostname withString:@""];
            
            if ([[[DataManager sharedDataManager] getSendFootsteps:contactNumber ] isEqualToString:@"1"]) {
                [self sendMessageOfType:MessageTypeLocation forJID:user.jid withText:@" "];
            }
        }
    }];
    
}

- (void)startShareLocTimer
{
    [self stopIdleTimerOnSocket];
    shareLocTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));
    if (shareLocTimer)
    {
        dispatch_source_set_timer(shareLocTimer, dispatch_walltime(NULL, 0), NSEC_PER_SEC * 8.f, NSEC_PER_SEC / 5);
        dispatch_source_set_event_handler(shareLocTimer, ^()
                                          {
                                              [self shareLoc];
                                          });
        dispatch_resume(shareLocTimer);
    }
    timer = nil;
    [self stopTimer];
    [self startCheckerTimer];
    
    
}

- (void)stopShareLocTimer
{
    if (shareLocTimer)
    {
        dispatch_source_cancel(shareLocTimer);
        shareLocTimer = nil;
    }
    
    [self startIdleTimerOnSocket];
    
    
}



- (void)sendMarkerToAllListeners:(MessageType)marker
{
    NSAssert(marker == MessageTypeLocationStart || marker == MessageTypeLocationStop, @"crash ololo");
    
    if (!resultsController) {
        [self loadContactsFromCoreData];
    }
    
    for (XMPPUserCoreDataStorageObject *user in resultsController.fetchedObjects){
            
        //    NSString * contactNumber = [user.jidStr stringByReplacingOccurrencesOfString:kServerAtHostname withString:@""];        // if ([user.subscription isEqualToString:@"both"]){
        
        [self sendMessageOfType:marker forJID:user.jid withText:@" "];
        //  }
        
    }
}

- (void)sendStopMarkerToAll
{
    //if the state is out of emergency only then send stop marker to all listeners not in any other case.
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"myState"] isEqualToString:@"off"]) {
        [self sendMarkerToAllListeners:MessageTypeLocationStop];
        
    }
}

- (void)sendStartMarkerToAll
{
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"myState"] isEqualToString:@"on"]) {
        [self sendMarkerToAllListeners:MessageTypeLocationStart];
        
    }
}


#pragma mark -
#pragma mark Log Out

- (void)logOut
{
    [self goOffline];
    [self.xmppStream disconnectAfterSending];
    [self teardownStream];
}

#pragma mark - plugins setup


- (void)setupRoster
{
    self.xmppRosterStorage      = [[XMPPRosterCoreDataStorage alloc] init];
    
    self.xmppRoster = [[XMPPRoster alloc] initWithRosterStorage:self.xmppRosterStorage];
    [self.xmppRoster addDelegate:self delegateQueue:dispatch_queue_create("roster", 0)];
    
    
    self.xmppRoster.autoAcceptKnownPresenceSubscriptionRequests = YES;
    [self.xmppRoster setAutoFetchRoster:YES];
    
    [self.xmppRoster activate:self.xmppStream];
}

- (void)setupMessageArchiving
{
//    NSString *messageArchivingStorageName = [[StorageManager sharedStorageManager] storageNameOfType:kStorageTypeMessageArchiving
//                                                                                          forBareJID:self.xmppStream.myJID.bare];
    self.xmppMessageArchivingStorage = [[XMPPMessageArchivingCoreDataStorage alloc] init];
    
    self.xmppMessageArchiving = [[XMPPMessageArchiving alloc] initWithMessageArchivingStorage:self.xmppMessageArchivingStorage];
    
    NSXMLElement *preferences = [self.xmppMessageArchiving preferences];
    
    NSXMLElement *resendSession = [NSXMLElement elementWithName:kElementNameSession];
    [resendSession addAttributeWithName:kAttributeNameThread stringValue:kThreadNameResend];
    [resendSession addAttributeWithName:@"save" stringValue:@"false"];
    
    [preferences addChild:resendSession];
    
    [self.xmppMessageArchiving setPreferences:preferences];
    
    [self.xmppMessageArchiving activate:self.xmppStream];
}

- (void)setupvCard
{
    // Setup vCard support
    //
    // The vCard Avatar module works in conjuction with the standard vCard Temp module to download user avatars.
    // The XMPPRoster will automatically integrate with XMPPvCardAvatarModule to cache roster photos in the roster.
    
    NSString *vCardStorageName = [[StorageManager sharedStorageManager] storageNameOfType:kStorageTypevCard
                                                                               forBareJID:self.xmppStream.myJID.bare];
    
    self.xmppvCardStorage = [[XMPPvCardCoreDataStorage alloc] initWithDatabaseFilename:vCardStorageName
                                                                          storeOptions:nil];
    
    self.xmppvCardTempModule = [[XMPPvCardTempModule alloc] initWithvCardStorage:self.xmppvCardStorage];
    
    self.xmppvCardAvatarModule = [[XMPPvCardAvatarModule alloc] initWithvCardTempModule:self.xmppvCardTempModule];
}

#pragma mark -
#pragma mark Avatars

- (UIImage *)getMyAvatar
{
    UIImage *noUserImage = [UIImage imageNamed:@"NoUserImage.png"];
    
    NSData *photoData = [[[XMPPHelper sharedHelper] xmppvCardAvatarModule] photoDataForJID:self.xmppStream.myJID.bareJID];
    if (photoData != nil)
    {
        return [UIImage imageWithData:photoData];
    }
    
    return noUserImage;
}

- (UIImage *)getContactAvatarWithJid:(XMPPJID *)contactJid
{
    UIImage *noUserImage = [UIImage imageNamed:@"NoUserImage.png"];
    
    XMPPUserCoreDataStorageObject *user =
    [[[XMPPHelper sharedHelper] xmppRosterStorage] userForJID:contactJid
                                                   xmppStream:nil
                                         managedObjectContext:[[[XMPPHelper sharedHelper] xmppRosterStorage] mainThreadManagedObjectContext]];
    if (user.photo != nil)
    {
        return user.photo;
    }
    else
    {
        NSData *photoData = [[[XMPPHelper sharedHelper] xmppvCardAvatarModule] photoDataForJID:user.jid];
        if (photoData != nil)
        {
            return [UIImage imageWithData:photoData];
        }
    }
    
    return noUserImage;
}

- (void)setMyAvatar:(UIImage *)newAvatar
{
    if(!newAvatar)
    {
        return;
    }
    
    XMPPvCardTemp *vcard = [[self xmppvCardTempModule] myvCardTemp];
    
    if(!vcard)
    {
        UIAlertView *cannotUploadAvatarAlertView = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Your avatar has not been upload. Please try again" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            [cannotUploadAvatarAlertView show];
        });
        return;
    }
    
    [vcard setPhoto:UIImagePNGRepresentation(newAvatar)];
    
    [[self xmppvCardTempModule] updateMyvCardTemp:vcard];
}

#pragma mark - send message

- (void)sendMessageOfType:(MessageType)type
                   forJID:(XMPPJID*)jid
                 withText:(NSString*)text
{
    if (MessageTypeInvalid == type) {
        [self sendMessageOfType:type forJID:jid withText:text elementId:nil expire:0 shouldArchive:NO];
    }else
    {
        [self sendMessageOfType:type forJID:jid withText:text elementId:nil expire:0 shouldArchive:YES];
    }
    
}


- (void)sendMessageOfType:(MessageType)type
                   forJID:(XMPPJID*)jid
{
    [self sendMessageOfType:type forJID:jid withText:@"1" elementId:nil expire:0 shouldArchive:NO];
}


- (void)sendMessageOfType:(MessageType)type
                   forJID:(XMPPJID *)jid
                 withText:(NSString *)text
                elementId:(NSString *)elementId
{
    [self sendMessageOfType:type forJID:jid withText:text elementId:elementId expire:0 shouldArchive:YES];
}

- (void)sendMessageOfType:(MessageType)type
                   forJID:(XMPPJID *)jid
                 withText:(NSString *)text
                elementId:(NSString *)elementId
            shouldArchive:(BOOL)shouldArchive
{
    [self sendMessageOfType:type forJID:jid withText:text elementId:elementId expire:0 shouldArchive:shouldArchive];
}

- (void)sendMessageOfType:(MessageType)type
                   forJID:(XMPPJID*)jid
                 withText:(NSString*)text
                elementId:(NSString*)elementId
                   expire:(NSUInteger)expire
            shouldArchive:(BOOL)shouldArchive
{
    [self sendMessageOfType:type forJID:jid withText:text elementId:elementId expire:expire shouldArchive:shouldArchive additionalElement:nil];
}

- (void)sendMessageOfType:(MessageType)type
                   forJID:(XMPPJID*)jid
                 withText:(NSString*)text
                elementId:(NSString*)elementId
                   expire:(NSUInteger)expire
            shouldArchive:(BOOL)shouldArchive
        additionalElement:(NSString*)additionalElement
{
    if(!elementId)
    {
        elementId = [XMPPStream generateUUID];
    }
    
    XMPPMessage *message = [XMPPMessage messageWithType:@"chat" to:jid elementID:elementId];
    NSString * status = [[NSUserDefaults standardUserDefaults] valueForKey:@"myState"];
    
    
    if(!shouldArchive)
    {
        [message setResendThread];
    }
    //   [message addBody:text.length ? text : @" "];
    
    if (MessageTypeLocation == type) {
       // NSLog(@"Distance from previous loc: %f", [lastloc distanceFromLocation:self.locationManager.location]);
        //////////////////////
        // if (!lastloc || [lastloc    distanceFromLocation:self.location] > 0) {
        if(self.location.coordinate.latitude!=oldLocation.coordinate.latitude&&self.location.coordinate.longitude!=oldLocation.coordinate.longitude)
        {
        [message addBody:[NSString stringWithFormat:@"loc,%f,%f,%@", self.location.coordinate.latitude, self.location.coordinate.longitude,status.length>0?status:@"on"]];
        NSLog(@"MessageBody:%@",message.body);
            
        if(![_liveTrackingData containsObject:[NSString stringWithFormat:@"loc,%f,%f,%@", self.location.coordinate.latitude, self.location.coordinate.longitude,status.length>0?status:@"on"]])
        [_liveTrackingData addObject:[NSString stringWithFormat:@"loc,%f,%f,%@", self.location.coordinate.latitude, self.location.coordinate.longitude,status.length>0?status:@"on"]];
        }
        else
        {
            return;
        }
        //        lastloc = self.locationManager.location;
        //
        //
        //        }
        //        else
        //        {
        //            // send no location if its same as previous location
        //            return ;
        //        }
        
    }
    else if(MessageTypeLocationStart == type)
    {
        [message addBody:[NSString stringWithFormat:@"loc_starts,%f,%f,%@", self.locationManager.location.coordinate.latitude, self.locationManager.location.coordinate.longitude,status.length>0?status:@"on"]];
        if(![_liveTrackingData containsObject:[NSString stringWithFormat:@"loc_starts,%f,%f,%@", self.locationManager.location.coordinate.latitude, self.locationManager.location.coordinate.longitude,status.length>0?status:@"on"]])
        {
        [_liveTrackingData addObject:[NSString stringWithFormat:@"loc_starts,%f,%f,%@", self.locationManager.location.coordinate.latitude, self.locationManager.location.coordinate.longitude,status.length>0?status:@"on"]];
        }
        
        lastloc = self.locationManager.location;
    }
    else if( MessageTypeLocationStop== type)
    {
        [message addBody:[NSString stringWithFormat:@"loc_ends,%f,%f,%@", self.locationManager.location.coordinate.latitude, self.locationManager.location.coordinate.longitude,status.length>0?status:@"off"]];
        
        if(![_liveTrackingData containsObject:[NSString stringWithFormat:@"loc_ends,%f,%f,%@", self.locationManager.location.coordinate.latitude, self.locationManager.location.coordinate.longitude,status.length>0?status:@"off"]])
        {
          [_liveTrackingData addObject:[NSString stringWithFormat:@"loc_ends,%f,%f,%@", self.locationManager.location.coordinate.latitude, self.locationManager.location.coordinate.longitude,status.length>0?status:@"off"]];
        }
            lastloc = self.locationManager.location;
    }
    
    if (type != MessageTypeInvalid) {
        [message setAttachment:[NSString stringWithFormat:@"%f,%f", self.locationManager.location.coordinate.latitude, self.locationManager.location.coordinate.longitude]];
    }
    
    [message setMessageType:type];
    [self.xmppStream sendElement:message];
    
}

- (void)sendSystemMessageUserHasClearedConversation:(XMPPJID*)conversation
{
    XMPPMessage *message = [XMPPMessage messageWithType:kMessageTypeSystem to:conversation elementID:[[NSUUID UUID] UUIDString]];
    [message addAttributeWithName:kAttributeNameAction stringValue:kActionSystemMessageUserHasClearedConversation];
    [self.xmppStream sendElement:message];
}

- (void)sendSystemMessageYouWereAddedToSendersGroup:(XMPPJID *)conversation
{
    XMPPMessage *message = [XMPPMessage messageWithType:kMessageTypeSystem to:conversation elementID:[[NSUUID UUID] UUIDString]];
    [message addAttributeWithName:kAttributeNameAction stringValue:@"senders_group"];
    [self.xmppStream sendElement:message];
}

- (void)sendSystemMessageYouWereAddedToListenersGroup:(XMPPJID *)conversation
{
    XMPPMessage *message = [XMPPMessage messageWithType:kMessageTypeSystem to:conversation elementID:[[NSUUID UUID] UUIDString]];
    [message addAttributeWithName:kAttributeNameAction stringValue:@"listeners_group"];
    [self.xmppStream sendElement:message];
}

- (void)sendSystemMessageYouWereRemovedFromSendersGroup:(XMPPJID *)conversation
{
    XMPPMessage *message = [XMPPMessage messageWithType:kMessageTypeSystem to:conversation elementID:[[NSUUID UUID] UUIDString]];
    [message addAttributeWithName:kAttributeNameAction stringValue:@"senders_group_remove"];
    [self.xmppStream sendElement:message];
}

- (void)sendSystemMessageYouWereRemovedFromListenersGroup:(XMPPJID *)conversation
{
    XMPPMessage *message = [XMPPMessage messageWithType:kMessageTypeSystem to:conversation elementID:[[NSUUID UUID] UUIDString]];
    [message addAttributeWithName:kAttributeNameAction stringValue:@"listeners_group_remove"];
    [self.xmppStream sendElement:message];
}

#pragma mark - helper functions

- (void)sendFirstMessageToShowConversationList
{
    /*
     if([self.xmppStream.myJID.bare isEqualToString:@"soxjke@jabber.hot-chilli.net"])
     {
     //        [self.xmppRosterStorage addUserToFriendsGroup:[XMPPJID jidWithString:@"matu_hotchili@jabber.hot-chilli.net"] withUsername:@"Daniil"];
     //        [self.xmppRoster addUser:[XMPPJID jidWithString:@"matu_hotchili@jabber.hot-chilli.net"] withNickname:@"Daniil" groups:@[kRosterGroupNameFriends]];
     [self sendMessageOfType:MessageTypeText forJID:[XMPPJID jidWithString:@"matu_hotchili@jabber.hot-chilli.netasd"] withText:@"Hi!"];
     }
     else
     {
     [self.xmppRoster addUser:[XMPPJID jidWithString:@"mail.com@54.214.47.102"] withNickname:@"Mail.com" groups:@[kRosterGroupNameFriends]];
     //        [self.xmppRoster addUser:[XMPPJID jidWithString:@"matu@jabber.ru"] withNickname:@"Daniil34" groups:@[kRosterGroupNameBlocked, kRosterGroupNameFriends]];
     //        [self.xmppRosterStorage addUserToFriendsGroup:[XMPPJID jidWithString:@"soxjke@jabber.hot-chilli.net"] withUsername:@"Petr89"];
     //        [self.xmppRosterStorage addUserToFriendsGroup:[XMPPJID jidWithString:@"matu@jabber.ru"] withUsername:@"Daniil34"];
     //        [self sendMessageOfType:kTextMessageType forJID:[XMPPJID jidWithString:@"mail.com@54.214.47.102"] withText:@"Hi!"];
     }
     */
}

#pragma mark -
#pragma mark Private

- (BOOL)updatevCardWithData:(NSDictionary *)vcardDict shouldCreateNewvCard:(BOOL)shouldCreate
{
    XMPPvCardTemp *vcard = nil;
    if(shouldCreate)
    {
        vcard = [XMPPvCardTemp vCardTemp];
    }
    else
    {
        vcard = [[self xmppvCardTempModule] myvCardTemp];
    }
    
    if(!vcard)
    {
        return NO;
    }
    
    if(vcardDict[kvCardFieldJID])
    {
        vcard.jid = vcardDict[kvCardFieldJID];
    }
    if(vcardDict[kvCardFieldUsername])
    {
        vcard.nickname = vcardDict[kvCardFieldUsername];
    }
    if(vcardDict[kvCardFieldFirstName])
    {
        vcard.givenName = vcardDict[kvCardFieldFirstName];
    }
    if(vcardDict[kvCardFieldLastName])
    {
        vcard.familyName = vcardDict[kvCardFieldLastName];
    }
    if(vcardDict[kvCardFieldBirthday])
    {
        vcard.bday = vcardDict[kvCardFieldBirthday];
    }
    if(vcardDict[kvCardFieldPhoto])
    {
        vcard.photo = UIImagePNGRepresentation(vcardDict[kvCardFieldPhoto]);
    }
    if(vcardDict[kvCardFieldEmail])
    {
        //        for(NSString *emailStr in vcardDict[kvCardFieldEmail])
        //        {
        //            XMPPvCardTempEmail *email = [XMPPvCardTempEmail vCardEmailFromElement:[NSXMLElement elementWithName:@"EMAIL"]];
        //            email.userid = emailStr;
        //            [vcard addEmailAddress:email];
        //        }
        
        //        XMPPvCardTempEmail *email = [XMPPvCardTempEmail vCardEmailFromElement:[NSXMLElement elementWithName:@"EMAIL"]];
        //        email.userid = vcardDict[kvCardFieldEmail];
        [vcard setEmailAddresses:@[vcardDict[kvCardFieldEmail]]];
        
    }
    if(vcardDict[kvCardFieldPhone])
    {
        //        for(NSString *phoneStr in vcardDict[kvCardFieldPhone])
        //        {
        //            XMPPvCardTempTel *phone = [XMPPvCardTempTel vCardTelFromElement:[NSXMLElement elementWithName:@"TEL"]];
        //            phone.number = phoneStr;
        //            [vcard addTelecomsAddress:phone];
        //        }
        //        XMPPvCardTempTel *phone = [XMPPvCardTempTel vCardTelFromElement:[NSXMLElement elementWithName:@"TEL"]];
        //        phone.number = vcardDict[kvCardFieldPhone];
        [vcard setTelecomsAddresses:@[vcardDict[kvCardFieldPhone]]];
    }
    /*
     if(vcardDict[kvCardFieldFacebookId])
     {
     vcard.facebookId = vcardDict[kvCardFieldFacebookId];
     }
     */
    
    [self.xmppvCardTempModule updateMyvCardTemp:vcard];
    
    return YES;
}

- (BOOL)connectWithJidStr:(NSString *)jidStr password:(NSString *)password
{
    if (![self.xmppStream isDisconnected]) {
        return YES;
    }
    
    NSString *myJID = jidStr;
    NSString *myPassword = password;
    
    //
    // If you don't want to use the Settings view to set the JID,
    // uncomment the section below to hard code a JID and password.
    //
    // myJID = @"user@gmail.com/xmppframework";
    // myPassword = @"";
    
    if (myJID == nil || myPassword == nil) {
        return NO;
    }
    
    [self.xmppStream setMyJID:[XMPPJID jidWithString:myJID]];
    
    //    XMPPPlainAuthentication * auth = [[XMPPPlainAuthentication alloc] initWithStream:self.xmppStream password:password];
    //
    NSError *error = nil;
    //    [auth start:nil];
    
    
    
    if (![self.xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:&error])
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error connecting"
                                                            message:@"See console for error details."
                                                           delegate:nil
                                                  cancelButtonTitle:@"Ok"
                                                  otherButtonTitles:nil];
        [alertView show];
        
        DDLogError(@"Error connecting: %@", error);
        
        return NO;
    }
    
    return YES;
}

#pragma mark -
#pragma mark XMPPStream Delegate

- (void)xmppStreamDidConnect:(XMPPStream *)sender{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    
    
    [[XMPPHelper sharedHelper] setIsXmppConnected:YES];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"Connected" object:nil];
    
    
    NSError *error = nil;
    if (!self.isRegistering && self.doAutoLogin) {
        if (![[[XMPPHelper sharedHelper] xmppStream] authenticateWithPassword:[[DataManager sharedDataManager] getVerifyCode]error:&error])
        {
            // NSLog(@"Error authenticating: %@", error);
        }
    }
}


- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
    
    [[XMPPHelper sharedHelper] goOnline];
    sender.enableBackgroundingOnSocket= true;
    [[NSUserDefaults standardUserDefaults] setValue:@"connected" forKey:@"netstate"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"connection" object:nil];
    [self.xmppRoster fetchRoster];
    
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error;
{
    NSLog(@"didNotAuthenticate xmpphelper:%@",error.description);
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
    
    
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    [[XMPPHelper sharedHelper] setIsXmppConnected:false];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"Reconnecting" object:nil];
    
    if (!self.manualDisconnect)
    {
        
        
        [[NSUserDefaults standardUserDefaults] setValue:@"disconnected" forKey:@"netstate"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"connection" object:nil];
        
        
       // BOOL isHostReachable = NO;
        
        
        
        [self startMonitoringReachability];
        
        
    }
}

- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    if (!self.allowSelfSignedCertificates)
    {
        [settings setObject:[NSNumber numberWithBool:YES] forKey:(NSString *)kCFStreamSSLAllowsAnyRoot];
    }
    
    if (self.allowSSLHostNameMismatch)
    {
        [settings setObject:[NSNull null] forKey:(NSString *)kCFStreamSSLPeerName];
    }
    else
    {
        // Google does things incorrectly (does not conform to RFC).
        // Because so many people ask questions about this (assume xmpp framework is broken),
        // I've explicitly added code that shows how other xmpp clients "do the right thing"
        // when connecting to a google server (gmail, or google apps for domains).
        
        NSString *expectedCertName = nil;
        
        NSString *serverDomain = self.xmppStream.hostName;
        NSString *virtualDomain = [self.xmppStream.myJID domain];
        
        if ([serverDomain isEqualToString:@"talk.google.com"])
        {
            if ([virtualDomain isEqualToString:@"gmail.com"])
            {
                expectedCertName = virtualDomain;
            }
            else
            {
                expectedCertName = serverDomain;
            }
        }
        else if (serverDomain == nil)
        {
            expectedCertName = virtualDomain;
        }
        else
        {
            expectedCertName = serverDomain;
        }
        
        if (expectedCertName)
        {
            [settings setObject:expectedCertName forKey:(NSString *)kCFStreamSSLPeerName];
            //[settings setObject:<#(id)#> forKey:<#(id<NSCopying>)#>]
        }
    }
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
    
    DDLogVerbose(@"%@: %@ %@", THIS_FILE, THIS_METHOD, presence);
    
    
    NSString *type = [presence type];
    
    if ([self.xmppStream.myJID isEqual:[presence from]])
    {
        return;
    }
    
    if ([type isEqualToString:@"unavailable"])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kChangeUserStatusNotification object:nil userInfo:@{kChangeUserStatusUserJidProp: [presence from], kChangeUserStatusIsUserOnlineProp: @NO}];
    }
    else if ([type isEqualToString:@"available"])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kChangeUserStatusNotification object:nil userInfo:@{kChangeUserStatusUserJidProp: [presence from], kChangeUserStatusIsUserOnlineProp: @YES}];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"distress" object:nil];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    DDLogVerbose(@"%@: %@ %@", THIS_FILE, THIS_METHOD, message);
    
    
    
    
        if ([message isChatMessage]) {
    
         if( message.messageType == MessageTypeLocation || message.messageType == MessageTypeLocationStart)
         {
            
             //[self.xmppRosterStorage addUserToContainLocaitonGroup:message.from];
             [[NSUserDefaults standardUserDefaults]
              setValue:@"reset"
              forKey:[ message.from.bare stringByAppendingString:@"map"]];
             [[NSUserDefaults standardUserDefaults] synchronize];
             
                //stringByAppendingString:@"map"]];
         }
            return;
    }
    //    else if([message isSystemMessage])
    //    {
    //        if ([message hasAttributeActionWithValue:@"senders_group"])
    //        {
    //            [self.xmppRosterStorage addUserToListenersGroup:message.from noUpdate:YES];
    //            return;
    //        }
    //
    //        if ([message hasAttributeActionWithValue:@"listeners_group"])
    //        {
    //            [self.xmppRosterStorage addUserToSendersGroup:message.from noUpdate:YES];
    //            return;
    //        }
    //        if ([message hasAttributeActionWithValue:@"senders_group_remove"])
    //        {
    //            [self.xmppRosterStorage removeUserFromListenersGoup:message.from noUpdate:YES];
    //            return;
    //        }
    //
    //        if ([message hasAttributeActionWithValue:@"listeners_group_remove"])
    //        {
    //            [self.xmppRosterStorage removeUserFromSendersGoup:message.from noUpdate:YES];
    //            return;
    //        }
    //    }
}

- (void)xmppStream:(XMPPStream *)sender didFailToSendMessage:(XMPPMessage *)message error:(NSError *)error
{
    DDLogVerbose(@"%@: %@ %@", THIS_FILE, THIS_METHOD, message);
    /*
     [[[XMPPHelper sharedHelper] xmppMessageArchivingStorage] findEntities:NSStringFromClass([XMPPMessageArchiving_Message_CoreDataObject class])
     byAttribute:@"elementId"
     containedIn:@[message.elementID]
     andPerformOperation:^(XMPPMessageArchiving_Message_CoreDataObject *message)
     {
     message.isFailed = YES;
     }
     withCompletion:nil
     ];
     */
}

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message
{
    DDLogVerbose(@"%@: %@ %@", THIS_FILE, THIS_METHOD, message);
    /*
     if (message.elementID)
     {
     [[[XMPPHelper sharedHelper] xmppMessageArchivingStorage] findEntities:NSStringFromClass([XMPPMessageArchiving_Message_CoreDataObject class])
     byAttribute:@"elementId"
     containedIn:@[message.elementID]
     andPerformOperation:^(XMPPMessageArchiving_Message_CoreDataObject *message)
     {
     message.isFailed = NO;
     }
     withCompletion:nil
     ];
     
     if (!message.hasChatState)
     {
     if(![self.xmppRosterStorage userExistsWithJID:[message to] xmppStream:nil])
     {
     [self.xmppRoster addUser:[message from] withNickname:[NSString userFromJidStr:[[message from] bare]] groups:@[kRosterGroupNameOther] subscribeToPresence:NO];
     
     [self.xmppRosterStorage askToAddUser:[message to]];
     }
     }
     }
     */
}

- (void)locationManager:(CLLocationManager*)manager didUpdateLocations:(nonnull NSArray<CLLocation *> *)locations
{
    if (locations.count)
    {
        CLLocation *newLocation=[locations lastObject];

        //if (newLocation.horizontalAccuracy < 21) {
            if ((oldLocation.coordinate.latitude == 0 || oldLocation.coordinate.longitude == 0))
            {
                oldLocation=newLocation;
                self.location=newLocation;
            }
            else
            {
            //CLLocationDistance distance = [newLocation distanceFromLocation:oldLocation];
            if(oldLocation.coordinate.latitude != newLocation.coordinate.latitude && oldLocation.coordinate.longitude != newLocation.coordinate.longitude)// && (distance>3.0 && distance<60.48))
            {
                oldLocation=self.location;
                self.location=newLocation;
            }
            else
            {
                oldLocation=newLocation;
            }
                
            }
       // }
//        else
//        {
//            self.location=newLocation;
//            oldLocation=newLocation;
//        }
    }
}

- (void)didBecomeActive:(NSNotification*)note
{
    
    
    //  [self sendStartMarkerToAll];
    
}

- (void)willResignActive:(NSNotification*)note
{
    
    //  [self sendStopMarkerToAll];
    
    
}

#pragma mark - XMPPRoster Delegates

- (void)xmppRoster:(XMPPRoster *)sender didReceivePresenceSubscriptionRequest:(XMPPPresence *)presence
{
    NSLog(@"roster didreceivePresenceSubscriptionRequested Called");
}

/**
 * Sent when a Roster Push is received as specified in Section 2.1.6 of RFC 6121.
 **/
- (void)xmppRoster:(XMPPRoster *)sender didReceiveRosterPush:(XMPPIQ *)iq
{
    NSLog(@"roster didreceiveRosterPush Called");
}

/**
 * Sent when the initial roster is received.
 **/
- (void)xmppRosterDidBeginPopulating:(XMPPRoster *)sender{
    NSLog(@"roster RosterDidBeginPopulating Called");
    
    //    int total = [[DataManager sharedDataManager] getTotalContacts];
    //
    //      for (int i = 0; i<total; i++) {
    //        [sender addUser:[XMPPJID jidWithString:[NSString stringWithFormat:@"%@%@",[[DataManager sharedDataManager] getContactUsername:i],kServerAtHostname]] withNickname:[[DataManager sharedDataManager] getContactName:i]];
    //       }
    // [sender addUser:[XMPPJID jidWithString:[NSString stringWithFormat:@"admin%@",kServerAtHostname]] withNickname:@"admin"];
}


- (void)fetchTheRoster
{
    [self.xmppRoster fetchRoster];
}


/**
 * Sent when the initial roster has been populated into storage.
 **/
- (void)xmppRosterDidEndPopulating:(XMPPRoster *)sender{
    NSLog(@"roster RosterDidEndPopulating Called");
}

/**
 * Sent when the roster recieves a roster item.
 *
 * Example:
 *
 * <item jid='romeo@example.net' name='Romeo' subscription='both'>
 *   <group>Friends</group>
 * </item>
 **/
- (void)xmppRoster:(XMPPRoster *)sender didRecieveRosterItem:(NSXMLElement *)item{
    NSLog(@"roster didreceiveRosterItem Called");
    
    // [item attributeStringValueForName:@"subscription"]
    
    // NSString * name =[item attributeStringValueForName:@"name"];
    // XMPPJID * contactJID = [XMPPJID jidWithString:[item attributeStringValueForName:@"jid"]];
    
    // NSString * phoneNumber = [contactJID user];
    
    //    if ([[item attributeStringValueForName:@"subscription"] isEqualToString:@"both"]) {
    //
    //
    //        if (![[DataManager sharedDataManager] doesUserExistWithNumber:phoneNumber]) {
    //            [[DataManager sharedDataManager] addContactToDefaults:name nNumber:phoneNumber nEmail:@""];
    //
    //            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    //
    //
    //              //  [[self appDelegate] subscribeToParsePush:phoneNumber];
    //            });
    //        }
    //    }
    //
    //    else if ([[item attributeStringValueForName:@"subscription"] isEqualToString:@"none"])
    //    {
    //        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    //
    //           // [[self appDelegate] unSubscribeToParsePush:phoneNumber];
    //        });
    //
    //    }
    
    
}


-(AppDelegate*)appDelegate
{
    return  (AppDelegate*)[[UIApplication sharedApplication] delegate];
    
}

- (void)xmppRosterDidChange:(XMPPRosterCoreDataStorage *)sender
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    //	roster = [sender sortedUsersByAvailabilityName];
    //
    //	[rosterTable abortEditing];
    //	[rosterTable selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
    //	[rosterTable reloadData];
    
  //  [[XMPPHelper sharedHelper] updateFriends];
}


- (void)xmppReconnect:(XMPPReconnect *)sender didDetectAccidentalDisconnect:(SCNetworkConnectionFlags)connectionFlags;
{
    //    dispatch_sync(dispatch_get_main_queue(), ^{
    //        [[[UIAlertView alloc] initWithTitle:@"Disconnected"
    //                                    message:[NSString stringWithFormat:@" An accidental internet disconnection detected! We are trying to log you back in ..."]
    //                                   delegate:nil
    //                          cancelButtonTitle:@"Ok"
    //                          otherButtonTitles:nil] show];
    //    });
    NSLog(@"****************************** ???????? ************\nAccidental Disconnect detected ...in XMPPhelper class ******");
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"Reconnecting" object:nil];
    
    [[NSUserDefaults standardUserDefaults] setValue:@"Retrying..." forKey:@"netstate"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    //[[NSNotificationCenter defaultCenter] postNotificationName:@"Reconnecting" object:nil];
}


- (BOOL)xmppReconnect:(XMPPReconnect *)sender shouldAttemptAutoReconnect:(SCNetworkReachabilityFlags)reachabilityFlags{
    
    [[NSUserDefaults standardUserDefaults] setValue:@"Retrying..." forKey:@"netstate"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    return YES;
    
}


- (void)xmppAutoPingDidSendPing:(XMPPAutoPing *)sender
{
    NSLog(@"did send ping");
}
- (void)xmppAutoPingDidReceivePong:(XMPPAutoPing *)sender{
    
    NSLog(@"did receive pong");
}

- (void)xmppAutoPingDidTimeout:(XMPPAutoPing *)sender{
    
    [self reconnect];
    
}


@end
