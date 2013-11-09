//
//  FSQLocationResolver.m
//  FivesquareKit
//
//  Created by John Clayton on 6/23/2008.
//  Copyright Fivesquare Software, LLC 2008. All rights reserved.
//

#import "FSQLocationResolver.h"

#import "FSQLogging.h"


#ifndef kSPLocationLoggingEnabled
	#define kSPLocationLoggingEnabled DEBUG && 1
#endif

#if kSPLocationLoggingEnabled
	#define LocLog(frmt, ...) FLogMark( ([NSString stringWithFormat:@"LOCATION.%@",_identifier]) , frmt, ##__VA_ARGS__)
#else
	#define LocLog(frmt, ...)
#endif



NSString *kFSQLocationResolverStoppedUpdatingNotification = @"FSQLocationResolverStoppedUpdatingNotification";
NSString *kFSQLocationResolverKeyLocation = @"Location";
NSString *kFSQLocationResolverKeyError = @"Error";
NSString *kFSQLocationResolverKeyAborted = @"Aborted";

NSTimeInterval kFSQLocationResolverInfiniteTimeInterval = -1;

#define kFSQLocationResolverAccuracyBest 5

@interface FSQLocationResolver()

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) NSDate *locationUpdatesStartedOn;
@property (nonatomic, strong) NSTimer *timedResolutionAbortTimer;
@property (nonatomic, strong) NSTimer *initialFixTimer;
@property (nonatomic, strong) NSMutableSet *locationUpdateHandlers;
@property (strong) CLLocation *lastUpdatedLocation; ///< The last location we got from the location manager. May or may/not be better than the best effort location.

@property (nonatomic, strong) NSMutableDictionary *regionBeginHandlersByIdentifier;
@property (nonatomic, strong) NSMutableDictionary *regionEnterHandlersByIdentifier;
@property (nonatomic, strong) NSMutableDictionary *regionExitHandlersByIdentifier;
@property (nonatomic, strong) NSMutableDictionary *regionFailureHandlersByIdentifier;

- (void) timedResolutionTimeLimitReached:(NSTimer *)timer;
- (void) initialFixTimeLimitReached:(NSTimer *)timer;

@end


@implementation FSQLocationResolver


// ========================================================================== //

#pragma mark - Properties

@dynamic activityType;
- (void) setActivityType:(CLActivityType)activityType {
	self.locationManager.activityType = activityType;
}

- (CLActivityType) activityType {
	return self.locationManager.activityType;
}

- (CLLocationManager *) locationManager {
    if(_locationManager == nil) {
        CLLocationManager *locationManager = [CLLocationManager new];
        locationManager.delegate = self;
        _locationManager = locationManager;
		self.currentLocation = _locationManager.location;
    }
    return _locationManager;
}

- (BOOL) resolvingContinuously {
	BOOL resolvingContinuously = (_currentTimeout == kFSQLocationResolverInfiniteTimeInterval);
	return resolvingContinuously;
}


// ========================================================================== //

#pragma mark - Object



- (void)dealloc {
	[_locationUpdateHandlers removeAllObjects];
	if([self.timedResolutionAbortTimer isValid]) {
		[self.timedResolutionAbortTimer invalidate];
	}
	if([self.initialFixTimer isValid]) {
		[self.initialFixTimer invalidate];
	}
}

- (id)init {
    self = [super init];
    if (self) {
        _locationUpdateHandlers = [NSMutableSet new];
		_regionBeginHandlersByIdentifier = [NSMutableDictionary new];
		_regionEnterHandlersByIdentifier = [NSMutableDictionary new];
		_regionExitHandlersByIdentifier = [NSMutableDictionary new];
		_regionFailureHandlersByIdentifier = [NSMutableDictionary new];
		
		_identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}



// ========================================================================== //

#pragma mark - Public



- (BOOL) resolveLocationAccurateTo:(CLLocationAccuracy)accuracy within:(NSTimeInterval)timeout {
	return [self resolveLocationAccurateTo:accuracy within:timeout completionHandler:nil];
}

- (BOOL) resolveLocationContinuouslyPausingAutomaticallyAccurateTo:(CLLocationAccuracy)accuracy updateHandler:(FSQLocationResolverLocationUpdateHandler)handler {
	return [self resolveLocationAccurateTo:accuracy within:kFSQLocationResolverInfiniteTimeInterval completionHandler:handler];
}

- (BOOL) resolveLocationAccurateTo:(CLLocationAccuracy)accuracy within:(NSTimeInterval)timeout completionHandler:(FSQLocationResolverLocationUpdateHandler)handler {
	
	if (NO == [CLLocationManager locationServicesEnabled]) return NO;
	
	[_locationUpdateHandlers addObject:[handler copy]];
	if (self.isResolving) return YES;
	
	self.resolving = YES;
	self.aborted = NO;
	
//	self.completionHandler = handler;
	
	self.locationUpdatesStartedOn = [NSDate date];
    self.locationManager.desiredAccuracy = accuracy;
	self.currentTimeout = timeout;
	
#ifdef TARGET_OS_IPHONE
	self.locationManager.pausesLocationUpdatesAutomatically = self.resolvingContinuously;
#endif

	// Let's at least see make sure there is a value, even if bogus
	self.currentLocation = self.locationManager.location;

//	LocLog(@"locationManager.pausesLocationUpdatesAutomatically: %@",@(self.locationManager.pausesLocationUpdatesAutomatically));
	[self.locationManager startUpdatingLocation];
	
	if (self.timedResolutionAbortTimer) {
		[self.timedResolutionAbortTimer invalidate];
		self.timedResolutionAbortTimer = nil;
	}
	if (timeout != kFSQLocationResolverInfiniteTimeInterval) {
		self.timedResolutionAbortTimer = [NSTimer scheduledTimerWithTimeInterval:timeout target:self selector:@selector(timedResolutionTimeLimitReached:) userInfo:nil repeats:NO];
	}

	// experimenting with getting a cached location
	//	self.currentLocation = self.locationManager.location;
	
	return YES;
}

- (void) stopResolving {
	[self.locationManager stopUpdatingLocation];

	if (self.timedResolutionAbortTimer) {
		[self.timedResolutionAbortTimer invalidate];
		self.timedResolutionAbortTimer = nil;
	}
	
	[_locationUpdateHandlers removeAllObjects];
	
	self.resolving = NO;
}

- (BOOL) onSignificantLocationChange:(FSQLocationResolverLocationUpdateHandler)onLocationChange {
	return [self onSignificantLocationChange:onLocationChange initialFixWithin:kFSQLocationResolverInfiniteTimeInterval];
}

- (BOOL) onSignificantLocationChange:(FSQLocationResolverLocationUpdateHandler)onLocationChange initialFixWithin:(NSTimeInterval)initialTimeout {
	if (NO == [CLLocationManager significantLocationChangeMonitoringAvailable]) return NO;
	[_locationUpdateHandlers addObject:[onLocationChange copy]];
	if (self.isMonitoringSignificantChanges) {
		return YES;
	}
	self.monitoringSignificantChanges = YES;
	
	if (self.isResolving) {
		[self stopResolving];
	}

	self.currentTimeout = initialTimeout;
	
	self.locationUpdatesStartedOn = [NSDate date];
	self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
	// Let's at least see make sure there is a value, even if bogus
	self.currentLocation = self.locationManager.location;

	[self.locationManager startMonitoringSignificantLocationChanges];
	
	if (self.initialFixTimer) {
		[self.initialFixTimer invalidate];
		self.initialFixTimer = nil;
	}
	if (initialTimeout != kFSQLocationResolverInfiniteTimeInterval) {
		self.initialFixTimer = [NSTimer scheduledTimerWithTimeInterval:initialTimeout target:self selector:@selector(initialFixTimeLimitReached:) userInfo:nil repeats:NO];
	}
	
	return YES;
}

- (void) stopMonitoringSignificantLocationChange {
	[self.locationManager stopMonitoringSignificantLocationChanges];
	[_locationUpdateHandlers removeAllObjects];
	self.monitoringSignificantChanges = NO;
}

- (BOOL) startMonitoringForRegion:(CLRegion *)region onEnter:(FSQLocationResolverRegionUpdateHandler)onEnter onFailure:(FSQLocationResolverRegionUpdateHandler)onFailure {
	return [self startMonitoringForRegion:region onBegin:nil onEnter:onEnter onExit:nil onFailure:onFailure];
}

- (BOOL) startMonitoringForRegion:(CLRegion *)region onExit:(FSQLocationResolverRegionUpdateHandler)onExit onFailure:(FSQLocationResolverRegionUpdateHandler)onFailure {
	return [self startMonitoringForRegion:region onBegin:nil onEnter:nil onExit:onExit onFailure:onFailure];
}

- (BOOL) startMonitoringForRegion:(CLRegion *)region onBegin:(FSQLocationResolverRegionUpdateHandler)onBegin onEnter:(FSQLocationResolverRegionUpdateHandler)onEnter onExit:(FSQLocationResolverRegionUpdateHandler)onExit  onFailure:(FSQLocationResolverRegionUpdateHandler)onFailure {
	NSParameterAssert(region != nil);
	if (NO == [CLLocationManager isMonitoringAvailableForClass:[region class]]) return NO;
	if (nil == region) return NO;
	
	if (onBegin) {
		_regionBeginHandlersByIdentifier[region.identifier] = [onBegin copy];
	}
	if (onEnter) {
		_regionEnterHandlersByIdentifier[region.identifier] = [onEnter copy];
	}
	if (onExit) {
		_regionExitHandlersByIdentifier[region.identifier] = [onExit copy];
	}
	if (onFailure) {
		_regionFailureHandlersByIdentifier[region.identifier] = [onFailure copy];
	}
	[self.locationManager startMonitoringForRegion:region];
	return YES;
}

- (void) stopMonitoringRegion:(CLRegion *)region {
	[self.locationManager stopMonitoringForRegion:region];
	[_regionBeginHandlersByIdentifier removeObjectForKey:region.identifier];
	[_regionEnterHandlersByIdentifier removeObjectForKey:region.identifier];
	[_regionExitHandlersByIdentifier removeObjectForKey:region.identifier];
	[_regionFailureHandlersByIdentifier removeObjectForKey:region.identifier];
}



// ========================================================================== //

#pragma mark - CLLocationManagerDelegate

//- (void) locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {

- (void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    LocLog(@"didUpdateLocations:%@",locations);
	
	CLLocation *newLocation = [locations lastObject];
	
	NSDate *eventDate = newLocation.timestamp;
    NSTimeInterval fromWhenUpdatesStarted = [eventDate timeIntervalSinceDate:self.locationUpdatesStartedOn];
	LocLog(@"fromWhenUpdatesStarted: %@",@(fromWhenUpdatesStarted));
	
	if (self.isResolving && fromWhenUpdatesStarted <= 0) { // this update was cached before we started resolving
		LocLog(@"Stale location while resolving, will keep trying ..");
		return;
	}
	
	LocLog(@"newLocation.horizontalAccuracy:%f",newLocation.horizontalAccuracy);
	if (newLocation.horizontalAccuracy < 0) { // an invalid location
		LocLog(@"No horizontal accuracy, will keep trying ..");
		return;
	}

	self.lastUpdatedLocation = newLocation;
	
	// If we got at least as good a location update consider this test to pass since a new location may actually be as good as our last one (i.e. our current one may actually be pretty good)

	LocLog(@"currentLocation.horizontalAccuracy:%f",self.currentLocation.horizontalAccuracy);
	LocLog(@"locationManager.desiredAccuracy:%f",self.locationManager.desiredAccuracy);

	CLLocationDistance locationDelta = [self.currentLocation distanceFromLocation:newLocation];
	LocLog(@"locationDelta: %@",@(locationDelta));
	
	if (self.currentLocation == nil || self.currentLocation.horizontalAccuracy >= newLocation.horizontalAccuracy) {
		LocLog(@"Got decent location, setting it to best effort location");
        self.currentLocation = newLocation;

		LocLog(@"kCLLocationAccuracyBestForNavigation:%f",kCLLocationAccuracyBestForNavigation);
		LocLog(@"kCLLocationAccuracyBest:%f",kCLLocationAccuracyBest);
		
		// When caller has set desired accuracy to one of the "best" values, they will actually be negative, which in a location update would indicate invalid, so just check for <= the kFSQLocationResolverAccuracyBest, which seems to be the best possible accuracy we get
        if (newLocation.horizontalAccuracy <= self.locationManager.desiredAccuracy || (self.locationManager.desiredAccuracy < 0 && newLocation.horizontalAccuracy <= kFSQLocationResolverAccuracyBest) ) {
			LocLog(@"Got a good enough location: newLocation.horizontalAccuracy:%f",newLocation.horizontalAccuracy);
			self.currentLocation = newLocation;
#ifdef TARGET_OS_IPHONE
			if (self.resolvingContinuously) {
				LocLog(@"locationManager.pausesLocationUpdatesAutomatically: %@",@(self.locationManager.pausesLocationUpdatesAutomatically));
				LocLog(@"Running continuously, handling location change");
				[self handleLocationUpdate];
				return;
			}
#endif
			if (self.isMonitoringSignificantChanges) {
				LocLog(@"Handling significant location change");
				[self handleLocationUpdate];
			}
			else if (self.isResolving) {
				LocLog(@"Stopping updates");
				[self.locationManager stopUpdatingLocation];
				[self handleFailureOrCompletion];
			}
        }
		else {
			LocLog(@"Location not good enough, will keep trying ..");
		}
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    if ([error code] != kCLErrorLocationUnknown) { // Unknown means we could recover
		[self.locationManager stopUpdatingLocation];
		self.currentLocation = self.locationManager.location; // use the best location we can
		self.error = error;
		[self handleFailureOrCompletion];
	}
}

- (void) locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
	LocLog(@"didEnterRegion:%@",region);
	FSQLocationResolverRegionUpdateHandler handler = _regionEnterHandlersByIdentifier[region.identifier];
	if (handler) {
		dispatch_async(dispatch_get_main_queue(), ^{
			handler(region,nil);
		});
	}
}

- (void) locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
	LocLog(@"didExitRegion:%@",region);
	FSQLocationResolverRegionUpdateHandler handler = _regionExitHandlersByIdentifier[region.identifier];
	if (handler) {
		dispatch_async(dispatch_get_main_queue(), ^{
			handler(region,nil);
		});
	}
}

- (void) locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
	LocLog(@"didStartMonitoringForRegion:%@",region);
	FSQLocationResolverRegionUpdateHandler handler = _regionBeginHandlersByIdentifier[region.identifier];
	if (handler) {
		dispatch_async(dispatch_get_main_queue(), ^{
			handler(region,nil);
		});
	}
}

- (void) locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
	LocLog(@"monitoringDidFailForRegion:%@ withError: %@",region,error);
	FSQLocationResolverRegionUpdateHandler handler = _regionFailureHandlersByIdentifier[region.identifier];
	if (handler) {
		dispatch_async(dispatch_get_main_queue(), ^{
			handler(region,error);
		});
	}
}

// ========================================================================== //

#pragma mark - Timeouts


- (void) timedResolutionTimeLimitReached:(NSTimer *)timer {
	self.aborted = YES;
	self.currentTimeout = 0;
	
	[self.locationManager stopUpdatingLocation];	
	self.currentLocation = self.locationManager.location; // get the best location we can
	
	NSError *abortError = [NSError errorWithDomain:kCLErrorDomain code:kCLErrorLocationUnknown userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"Timed out resolving location, using best effort location.", @"FSQLocationResolver timeout error description") }];
	self.error = abortError;
	
	LocLog(@"Timed resolution timeout reached, sending update with best effort location: %@",self.currentLocation);
	[self handleFailureOrCompletion];
}

- (void) initialFixTimeLimitReached:(NSTimer *)timer {
	self.currentTimeout = 0;
	self.currentLocation = self.locationManager.location; // get the best location we can
	LocLog(@"Initial fix timeout reached, sending update with best effort location: %@",self.currentLocation);
	[self handleLocationUpdate];
}

// ========================================================================== //

#pragma mark - Handlers

- (void) handleFailureOrCompletion {
	if (self.timedResolutionAbortTimer) {
		[self.timedResolutionAbortTimer invalidate];
		self.timedResolutionAbortTimer = nil;
	}
			
	NSMutableDictionary *info = [NSMutableDictionary new];
	if (self.currentLocation) {
		[info setObject:self.currentLocation forKey:kFSQLocationResolverKeyLocation];
	}
	if (self.error) {
		[info setObject:self.error forKey:kFSQLocationResolverKeyError];
	}
	[info setObject:@(self.aborted) forKey:kFSQLocationResolverKeyAborted];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kFSQLocationResolverStoppedUpdatingNotification object:self userInfo:info];
	[_locationUpdateHandlers enumerateObjectsUsingBlock:^(FSQLocationResolverLocationUpdateHandler handler, BOOL *stop) {
		dispatch_async(dispatch_get_main_queue(), ^{
			handler(self.currentLocation,self.error);
		});
	}];
	[_locationUpdateHandlers removeAllObjects];
	
	self.resolving = NO;
}

- (void) handleLocationUpdate {
	NSMutableDictionary *info = [NSMutableDictionary new];
	if (self.currentLocation) {
		[info setObject:self.currentLocation forKey:kFSQLocationResolverKeyLocation];
	}
	if (self.error) {
		[info setObject:self.error forKey:kFSQLocationResolverKeyError];
	}
	[info setObject:@(self.aborted) forKey:kFSQLocationResolverKeyAborted];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kFSQLocationResolverStoppedUpdatingNotification object:self userInfo:info];
	[_locationUpdateHandlers enumerateObjectsUsingBlock:^(FSQLocationResolverLocationUpdateHandler handler, BOOL *stop) {
		dispatch_async(dispatch_get_main_queue(), ^{
			handler(self.currentLocation,self.error);
		});
	}];
}

@end
