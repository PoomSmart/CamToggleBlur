#import <substrate.h>
#import <objc/runtime.h>
#import <Preferences/Preferences.h>
#import <Preferences/PSSpecifier.h>
#import "../PS.h"

extern NSString *const PSDefaultsKey;
extern NSString *const PSValueChangedNotificationKey;
extern NSString *const PSTableCellKey;
extern NSString *const PSDefaultValueKey;
NSString *const BlurAnimationKey = @"EnableBlurAnimation";
CFStringRef BlurAnimationNotification = CFSTR("com.apple.mobileslideshow.PreferenceChanged");
CFStringRef MobileSlideShow = CFSTR("com.apple.mobileslideshow");
CFStringRef CameraConfiguration = CFSTR("CameraConfiguration");

static char blurAnimationEnabledKey;

@interface PLCameraView
- (BOOL)_didEverMoveToWindow;
- (BOOL)isBlurAnimationEnabled;
- (void)setBlurAnimationEnabled:(BOOL)enabled;
@end

@interface CAMCameraView
@end

@interface PLCameraController : NSObject
+ (PLCameraController *)sharedInstance;
- (PLCameraView *)delegate;
@end

@interface CAMCaptureController : NSObject
+ (CAMCaptureController *)sharedInstance;
- (CAMCameraView *)delegate;
@end

@interface UIDevice (Addition)
- (int)_graphicsQuality;
@end

static void _applyConfiguration_hook(id view)
{
	CFPreferencesAppSynchronize(MobileSlideShow);
	NSDictionary *cameraConfiguration = (NSDictionary *)CFPreferencesCopyAppValue(CameraConfiguration, MobileSlideShow);
	id value = [cameraConfiguration objectForKey:BlurAnimationKey];
	[view setBlurAnimationEnabled:[value boolValue]];
}

static void _saveConfiguration_hook(id view)
{
	if (view != nil) {
		if ([view _didEverMoveToWindow]) {
			CFPreferencesAppSynchronize(MobileSlideShow);
			NSDictionary *cameraConfiguration = (NSDictionary *)CFPreferencesCopyAppValue(CameraConfiguration, MobileSlideShow);
			NSMutableDictionary *mutableCameraConfiguration = [[cameraConfiguration mutableCopy] autorelease];
			id value = [view isBlurAnimationEnabled] ? @YES : @NO;
    		[mutableCameraConfiguration setObject:value forKeyedSubscript:BlurAnimationKey];
    		NSDictionary *editedCameraConfiguration = [[mutableCameraConfiguration copy] autorelease];
    		CFPreferencesSetAppValue(CameraConfiguration, editedCameraConfiguration, MobileSlideShow);
    		CFPreferencesAppSynchronize(MobileSlideShow);
		}
	}
}

static void preferencesDidChange_hook(id view)
{
	CFPreferencesAppSynchronize(MobileSlideShow);
	NSDictionary *cameraConfiguration = [(NSDictionary *)CFPreferencesCopyAppValue(CameraConfiguration, MobileSlideShow) autorelease];
	id value = [cameraConfiguration objectForKeyedSubscript:BlurAnimationKey];
	if (value != nil)
		[view setBlurAnimationEnabled:[value boolValue]];
    CFPreferencesAppSynchronize(CFSTR("com.apple.camera"));
}

//##### iOS 7 #####
%group Camera7

%hook PLApplicationCameraViewController

- (void)_applyConfiguration
{
	%orig;
	_applyConfiguration_hook(MSHookIvar<PLCameraView *>(self, "_cameraView"));
}

- (void)_saveConfiguration
{
	%orig;
	_saveConfiguration_hook(MSHookIvar<PLCameraView *>(self, "_cameraView"));
}

- (void)preferencesDidChange
{
	%orig;
	preferencesDidChange_hook(MSHookIvar<PLCameraView *>(self, "_cameraView"));
}

%end

%hook PLCameraView

%new
- (BOOL)isBlurAnimationEnabled
{
	return [objc_getAssociatedObject(self, &blurAnimationEnabledKey) boolValue];
}

%new
- (void)setBlurAnimationEnabled:(BOOL)enabled
{
	objc_setAssociatedObject(self, &blurAnimationEnabledKey, enabled ? @YES : @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%end

%hook CAMBlurredSnapshotView

- (id)initWithView:(id)view
{
	self = %orig;
	if (self)
		MSHookIvar<BOOL>(self, "__supportsBlur") = [[[%c(PLCameraController) sharedInstance] delegate] isBlurAnimationEnabled];
	return self;
}

%end

%end

//##### iOS 8 #####
%group Camera8

%hook CAMApplicationCameraViewController

- (void)_applyConfiguration
{
	%orig;
	_applyConfiguration_hook(MSHookIvar<CAMCameraView *>(self, "_cameraView"));
}

- (void)_saveConfiguration
{
	%orig;
	_saveConfiguration_hook(MSHookIvar<CAMCameraView *>(self, "_cameraView"));
}

- (void)preferencesDidChange
{
	%orig;
	preferencesDidChange_hook(MSHookIvar<CAMCameraView *>(self, "_cameraView"));
}

%end

%hook CAMCameraView

%new
- (BOOL)isBlurAnimationEnabled
{
	return [objc_getAssociatedObject(self, &blurAnimationEnabledKey) boolValue];
}

%new
- (void)setBlurAnimationEnabled:(BOOL)enabled
{
	objc_setAssociatedObject(self, &blurAnimationEnabledKey, enabled ? @YES : @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%end

%hook CAMBlurredSnapshotView

- (id)initWithView:(id)view
{
	self = %orig;
	if (self)
		MSHookIvar<BOOL>(self, "__supportsBlur") = [[[%c(CAMCaptureController) sharedInstance] delegate] isBlurAnimationEnabled];
	return self;
}

%end

%end

%group Pref

static char blurSpecifierKey;

@interface MSSSettingsController : UIViewController
@property (retain, nonatomic, getter=_blur_specifier, setter=_set_blur_specifier:) PSSpecifier *blurSpecifier;
@end

%hook MSSSettingsController

%new(v@:@)
- (void)_set_blur_specifier:(id)object
{
    objc_setAssociatedObject(self, &blurSpecifierKey, object, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new(@@:)
- (id)_blur_specifier
{
    return objc_getAssociatedObject(self, &blurSpecifierKey);
}

%new
- (id)cameraWantsBlurAnimation:(PSSpecifier *)specifier
{
	CFPreferencesAppSynchronize(MobileSlideShow);
	NSDictionary *cameraConfiguration = [(NSDictionary *)CFPreferencesCopyAppValue(CameraConfiguration, MobileSlideShow) autorelease];
	id value = [cameraConfiguration objectForKeyedSubscript:BlurAnimationKey];
	if (value != nil)
		return value;
	return @([[UIDevice currentDevice] _graphicsQuality] == 100);
}

%new
- (void)setCameraWantsBlurAnimation:(id)value specifier:(PSSpecifier *)specifier
{
    CFPreferencesAppSynchronize(MobileSlideShow);
	NSDictionary *cameraConfiguration = [(NSDictionary *)CFPreferencesCopyAppValue(CameraConfiguration, MobileSlideShow) autorelease];
	NSMutableDictionary *mutableCameraConfiguration = [[cameraConfiguration mutableCopy] autorelease];
    [mutableCameraConfiguration setObject:value forKeyedSubscript:BlurAnimationKey];
    NSDictionary *editedCameraConfiguration = [[mutableCameraConfiguration copy] autorelease];
    CFPreferencesSetAppValue(CameraConfiguration, editedCameraConfiguration, MobileSlideShow);
    CFPreferencesAppSynchronize(MobileSlideShow);
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), BlurAnimationNotification, NULL, NULL, NO);
}

- (NSMutableArray *)specifiers
{
	if (MSHookIvar<NSMutableArray *>(self, "_specifiers") != nil)
		return %orig();
	NSMutableArray *specifiers = %orig();
	NSUInteger insertionIndex;
	for (PSSpecifier *spec in specifiers) {
		if ([[spec propertyForKey:@"label"] isEqualToString:@"CAMERA"])
			insertionIndex = [specifiers indexOfObject:spec];
	}
	if (insertionIndex == NSNotFound)
		return specifiers;
	insertionIndex++;
	PSSpecifier *blurSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Blur Animation" target:self set:@selector(setCameraWantsBlurAnimation:specifier:) get:@selector(cameraWantsBlurAnimation:) detail:nil cell:[PSTableCell cellTypeFromString:@"PSSwitchCell"] edit:nil];
	id defaultValue = @([[UIDevice currentDevice] _graphicsQuality] == 100);
	[blurSpecifier setProperty:defaultValue forKey:PSDefaultsKey];
	[blurSpecifier setProperty:(NSString *)BlurAnimationNotification forKey:PSValueChangedNotificationKey];
	[blurSpecifier setProperty:defaultValue forKey:PSDefaultValueKey];
	[specifiers insertObject:blurSpecifier atIndex:insertionIndex];
	self.blurSpecifier = blurSpecifier;
	return specifiers;
}

%end

%end

%ctor
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	BOOL isPrefApp = [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.Preferences"];
	if (isPrefApp) {
		dlopen("/System/Library/PreferenceBundles/MobileSlideShowSettings.bundle/MobileSlideShowSettings", RTLD_LAZY);
		%init(Pref);
	} else {
		dlopen("/System/Library/PrivateFrameworks/PhotoLibrary.framework/PhotoLibrary", RTLD_LAZY);
		dlopen("/System/Library/PrivateFrameworks/CameraKit.framework/CameraKit", RTLD_LAZY);
		if (isiOS8) {
			%init(Camera8);
		} else {
			%init(Camera7);
		}
	}
	[pool drain];
}