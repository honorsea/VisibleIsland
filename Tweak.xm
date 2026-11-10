#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <sys/sysctl.h>

CGFloat red = 0.0;
CGFloat green = 0.0;
CGFloat blue = 0.0;
CGFloat alpha = 1.0;

// Base / Idle Scale (Width & Height)
CGFloat scale = 1.15;
CGFloat scaleY = 1.15;

// Base / Idle Position
CGFloat xPos = 0.0;
CGFloat yPos = -23.0;
CGFloat xNot = 0.0;
CGFloat yNot = 40.0;

// Expanded State Settings (Below Notch)
static BOOL expandedFixEnabled = YES;
CGFloat expandedYPos = 20.0;
CGFloat expandedScale = 0.95;

// Compact Notch-Ear Mode Settings
static BOOL earModeEnabled = YES;
static BOOL hideStatusBarInEarMode = YES;
CGFloat compactScaleX = 1.55;
CGFloat compactScaleY = 1.05;
CGFloat compactYPos = -23.0;
CGFloat earSpreadOffset = 22.0;

// Original Tweak Switches
static BOOL fixEnabled;
static BOOL islandEnabled;
static BOOL posEnabled;
static BOOL hideEnabled;
static BOOL notificationFix;
static BOOL notEnabled;
static BOOL colorEnabled;
static BOOL transEnabled;
static BOOL scaleEnabled;
static BOOL lineDisabled;

// Live State Tracking (0 = Idle, 1 = Compact Active, 2 = Expanded)
static NSInteger currentIslandState = 0;

@interface FBSystemService : NSObject
+ (id)sharedInstance;
- (void)exitAndRelaunch:(BOOL)arg1;
@end

@interface SBSystemApertureWindow : UIView
- (void)vi_applyIslandTransform;
@end

@interface _SBSystemApertureMagiciansCurtainView : UIView
@end

@interface SBBannerWindow : UIView
@end

@interface _SBGainMapView : UIView
@end

@interface _SBSystemApertureContainerViewContentView : UIView
@end

@interface SBFTouchPassThroughView : UIView
@end

@interface _UIStatusBar : UIView
@end

// Weak references for instant live updates without respringing
static __weak SBSystemApertureWindow *sharedApertureWindow = nil;
static __weak _SBSystemApertureMagiciansCurtainView *sharedCurtainView = nil;
static __weak _UIStatusBar *sharedStatusBar = nil;

@interface Model : NSObject
+ (NSString *)deviceModel;
@end

@implementation Model

+ (NSString *)deviceModel {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);

    char *machine = (char *)malloc(size);
    if (machine == NULL) {
        return nil;
    }

    if (sysctlbyname("hw.machine", machine, &size, NULL, 0) == -1) {
        free(machine);
        return nil;
    }

    NSString *deviceModel = [NSString stringWithUTF8String:machine];
    free(machine);

    return deviceModel;
}

@end

static CGFloat deviceDefaultYOffset(NSString *deviceModel) {
    if ([deviceModel isEqualToString:@"iPhone13,1"]) return 19.5; // 12 Mini
    if ([deviceModel isEqualToString:@"iPhone10,3"] || [deviceModel isEqualToString:@"iPhone10,6"] ||
        [deviceModel isEqualToString:@"iPhone11,2"] || [deviceModel isEqualToString:@"iPhone12,3"]) return 20.5;
    if ([deviceModel isEqualToString:@"iPhone13,2"] || [deviceModel isEqualToString:@"iPhone13,3"]) return 21.5;
    if ([deviceModel isEqualToString:@"iPhone13,4"]) return 22.3;
    if ([deviceModel isEqualToString:@"iPhone11,6"] || [deviceModel isEqualToString:@"iPhone12,5"] ||
        [deviceModel isEqualToString:@"iPhone11,8"] || [deviceModel isEqualToString:@"iPhone12,1"] ||
        [deviceModel isEqualToString:@"iPhone14,4"]) return 22.5;
    if ([deviceModel isEqualToString:@"iPhone14,5"] || [deviceModel isEqualToString:@"iPhone14,2"] ||
        [deviceModel isEqualToString:@"iPhone14,7"]) return 24.0;
    if ([deviceModel isEqualToString:@"iPhone14,3"]) return 26.0;
    return 20.5;
}

%hook SBSystemApertureWindow

- (void)layoutSubviews {
    %orig;
    sharedApertureWindow = self;
    [self vi_applyIslandTransform];
}

%new
- (void)vi_applyIslandTransform {
    NSString *deviceModel = [Model deviceModel];

    // Determine target X/Y scale and X/Y position based on current Island state
    CGFloat targetScaleX = scaleEnabled ? scale : 1.0;
    CGFloat targetScaleY = scaleEnabled ? scaleY : 1.0;
    CGFloat targetXPos = posEnabled ? xPos : 0.0;
    CGFloat targetYPos = 0.0;

    if (fixEnabled) {
        targetYPos = deviceDefaultYOffset(deviceModel);
    } else if (posEnabled) {
        targetYPos = yPos;
    }

    // Override for Expanded State (respects the notch & screen width on 12 mini)
    if (currentIslandState == 2 && expandedFixEnabled) {
        targetScaleX = expandedScale;
        targetScaleY = expandedScale;
        targetXPos = 0.0;
        targetYPos = expandedYPos;
    }
    // Override for Active Compact State (Notch Ears Mode)
    else if (currentIslandState == 1 && earModeEnabled) {
        targetScaleX = compactScaleX;
        targetScaleY = compactScaleY;
        targetYPos = compactYPos;
    }

    // Prevent invalid zero/negative scale
    if (targetScaleX <= 0.1) targetScaleX = 1.0;
    if (targetScaleY <= 0.1) targetScaleY = 1.0;

    // Reset transform to Identity first so UIKit frame math never corrupts bounds
    self.transform = CGAffineTransformIdentity;
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    self.frame = screenBounds;

    if (scaleEnabled || fixEnabled || posEnabled ||
        (currentIslandState == 2 && expandedFixEnabled) ||
        (currentIslandState == 1 && earModeEnabled)) {

        self.transform = CGAffineTransformMakeScale(targetScaleX, targetScaleY);

        CGRect frame = self.frame;
        frame.origin.y = targetYPos / targetScaleY;
        if (targetXPos != 0.0) {
            frame.origin.x = targetXPos / targetScaleX;
        }
        self.frame = frame;
    }
}

%end

%hook _SBSystemApertureMagiciansCurtainView

- (void)didMoveToWindow {
    %orig;
    sharedCurtainView = self;
    self.hidden = (fixEnabled || posEnabled || earModeEnabled || expandedFixEnabled);
}

- (void)layoutSubviews {
    %orig;
    sharedCurtainView = self;
    self.hidden = (fixEnabled || posEnabled || earModeEnabled || expandedFixEnabled);
}

%end

%hook _SBGainMapView

- (void)didMoveToWindow {
    %orig;
    if (hideEnabled && currentIslandState == 0) {
        self.alpha = 0.0;
    } else {
        self.alpha = 1.0;
    }
}

- (void)layoutSubviews {
    %orig;
    if (hideEnabled && currentIslandState == 0) {
        self.alpha = 0.0;
    } else {
        self.alpha = 1.0;
    }
}

%end

%hook _SBSystemApertureContainerViewContentView

- (void)layoutSubviews {
    UIColor *backgroundColor = [self backgroundColor];
    if (colorEnabled) {
        if (!backgroundColor) {
            UIColor *customColor = [[UIColor alloc] initWithRed:red green:green blue:blue alpha:alpha];
            [self setBackgroundColor:customColor];
        }
    }
    %orig;

    // Detect Dynamic Island state from the live pill container size
    CGRect bounds = self.bounds;
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;

    NSInteger detectedState = 0; // 0 = Idle
    if (height > 62.0) {
        detectedState = 2; // Expanded
    } else if (width > 130.0) {
        detectedState = 1; // Compact Active (Music, Timer, etc.)
    }

    if (detectedState != currentIslandState) {
        currentIslandState = detectedState;
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            if (sharedApertureWindow) {
                [sharedApertureWindow vi_applyIslandTransform];
            }
            if (sharedStatusBar) {
                BOOL shouldHideSB = (currentIslandState == 1 && earModeEnabled && hideStatusBarInEarMode);
                sharedStatusBar.alpha = shouldHideSB ? 0.0 : 1.0;
            }
        } completion:nil];
    }

    // In Compact Notch-Ear Mode, counter-scale subviews so icons aren't stretched
    // and push left/right items outward into the two notch ears
    if (currentIslandState == 1 && earModeEnabled) {
        CGFloat safeScaleX = (compactScaleX > 0.1) ? compactScaleX : 1.0;
        CGFloat safeScaleY = (compactScaleY > 0.1) ? compactScaleY : 1.0;
        CGFloat invScaleX = safeScaleY / safeScaleX; // Keeps 1:1 aspect ratio for icons
        CGFloat midX = width / 2.0;

        for (UIView *sub in self.subviews) {
            CGFloat subCenterX = sub.center.x;
            CGFloat horizontalPush = 0.0;
            if (subCenterX < midX - 5.0) {
                horizontalPush = -earSpreadOffset; // Push left item into left ear
            } else if (subCenterX > midX + 5.0) {
                horizontalPush = earSpreadOffset;  // Push right item into right ear
            }
            CGAffineTransform unstretch = CGAffineTransformMakeScale(invScaleX, 1.0);
            CGAffineTransform spread = CGAffineTransformMakeTranslation(horizontalPush, 0.0);
            sub.transform = CGAffineTransformConcat(unstretch, spread);
        }
    } else {
        for (UIView *sub in self.subviews) {
            sub.transform = CGAffineTransformIdentity;
        }
    }
}

%end

%hook SBFTouchPassThroughView

- (void)layoutSubviews {
    %orig;

    if (transEnabled) {
        if (self.subviews.count == 4) {
            UIView *targetSubview = self.subviews[2];
            if (targetSubview.alpha == 1.0 && targetSubview.userInteractionEnabled == 0) {
                targetSubview.alpha = alpha;
            }
        }
    }
    if (lineDisabled) {
        if (self.subviews.count == 4) {
            UIView *lineView = self.subviews[1];
            if (lineView.alpha == 1.0 && lineView.userInteractionEnabled == 0) {
                lineView.hidden = YES;
            }
        }
    }
}

%end

%hook _UIStatusBar

- (void)layoutSubviews {
    %orig;
    sharedStatusBar = self;
    BOOL shouldHideSB = (currentIslandState == 1 && earModeEnabled && hideStatusBarInEarMode);
    self.alpha = shouldHideSB ? 0.0 : 1.0;
}

%end

%hook SBBannerWindow

- (CGRect)frame {
    if (notificationFix) {
        NSString *deviceModel = [Model deviceModel];
        if ([deviceModel isEqualToString:@"iPhone10,3"] || [deviceModel isEqualToString:@"iPhone10,6"] ||
            [deviceModel isEqualToString:@"iPhone11,2"] || [deviceModel isEqualToString:@"iPhone12,3"]) {
            %orig;
            return CGRectMake(0, 35, 375, 812);
        } else if ([deviceModel isEqualToString:@"iPhone11,6"] || [deviceModel isEqualToString:@"iPhone12,5"] ||
                   [deviceModel isEqualToString:@"iPhone11,8"] || [deviceModel isEqualToString:@"iPhone12,1"]) {
            %orig;
            return CGRectMake(0, 37, 414, 896);
        } else if ([deviceModel isEqualToString:@"iPhone13,2"] || [deviceModel isEqualToString:@"iPhone13,3"]) {
            %orig;
            return CGRectMake(0, 35, 390, 844);
        } else if ([deviceModel isEqualToString:@"iPhone13,1"]) {
            %orig;
            return CGRectMake(0, 33, 360, 780);
        } else if ([deviceModel isEqualToString:@"iPhone13,4"]) {
            %orig;
            return CGRectMake(0, 38, 428, 926);
        } else if ([deviceModel isEqualToString:@"iPhone14,5"] || [deviceModel isEqualToString:@"iPhone14,2"] ||
                   [deviceModel isEqualToString:@"iPhone14,7"]) {
            %orig;
            return CGRectMake(0, 40, 390, 844);
        } else if ([deviceModel isEqualToString:@"iPhone14,4"]) {
            %orig;
            return CGRectMake(0, 38, 360, 780);
        } else if ([deviceModel isEqualToString:@"iPhone14,3"]) {
            %orig;
            return CGRectMake(0, 42, 428, 926);
        }
    } else if (notEnabled) {
        NSString *deviceModel = [Model deviceModel];
        if ([deviceModel isEqualToString:@"iPhone10,3"] || [deviceModel isEqualToString:@"iPhone10,6"] ||
            [deviceModel isEqualToString:@"iPhone11,2"] || [deviceModel isEqualToString:@"iPhone12,3"]) {
            %orig;
            return CGRectMake(xNot, yNot, 375, 812);
        } else if ([deviceModel isEqualToString:@"iPhone11,6"] || [deviceModel isEqualToString:@"iPhone12,5"] ||
                   [deviceModel isEqualToString:@"iPhone11,8"] || [deviceModel isEqualToString:@"iPhone12,1"]) {
            %orig;
            return CGRectMake(xNot, yNot, 414, 896);
        } else if ([deviceModel isEqualToString:@"iPhone13,2"] || [deviceModel isEqualToString:@"iPhone13,3"] ||
                   [deviceModel isEqualToString:@"iPhone14,5"] || [deviceModel isEqualToString:@"iPhone14,2"] ||
                   [deviceModel isEqualToString:@"iPhone14,7"]) {
            %orig;
            return CGRectMake(xNot, yNot, 390, 844);
        } else if ([deviceModel isEqualToString:@"iPhone13,1"] || [deviceModel isEqualToString:@"iPhone14,4"]) {
            %orig;
            return CGRectMake(xNot, yNot, 360, 780);
        } else if ([deviceModel isEqualToString:@"iPhone13,4"] || [deviceModel isEqualToString:@"iPhone14,3"]) {
            %orig;
            return CGRectMake(xNot, yNot, 428, 926);
        }
    }
    return %orig;
}

- (void)setFrame:(CGRect)frame {
    if (notificationFix) {
        NSString *deviceModel = [Model deviceModel];
        if ([deviceModel isEqualToString:@"iPhone10,3"] || [deviceModel isEqualToString:@"iPhone10,6"] ||
            [deviceModel isEqualToString:@"iPhone11,2"] || [deviceModel isEqualToString:@"iPhone12,3"]) {
            %orig(CGRectMake(0, 35, 375, 812));
        } else if ([deviceModel isEqualToString:@"iPhone11,6"] || [deviceModel isEqualToString:@"iPhone12,5"] ||
                   [deviceModel isEqualToString:@"iPhone11,8"] || [deviceModel isEqualToString:@"iPhone12,1"]) {
            %orig(CGRectMake(0, 37, 414, 896));
        } else if ([deviceModel isEqualToString:@"iPhone13,2"] || [deviceModel isEqualToString:@"iPhone13,3"]) {
            %orig(CGRectMake(0, 35, 390, 844));
        } else if ([deviceModel isEqualToString:@"iPhone13,1"]) {
            %orig(CGRectMake(0, 33, 360, 780));
        } else if ([deviceModel isEqualToString:@"iPhone13,4"]) {
            %orig(CGRectMake(0, 38, 428, 926));
        } else if ([deviceModel isEqualToString:@"iPhone14,5"] || [deviceModel isEqualToString:@"iPhone14,2"] ||
                   [deviceModel isEqualToString:@"iPhone14,7"]) {
            %orig(CGRectMake(0, 40, 390, 844));
        } else if ([deviceModel isEqualToString:@"iPhone14,4"]) {
            %orig(CGRectMake(0, 38, 360, 780));
        } else if ([deviceModel isEqualToString:@"iPhone14,3"]) {
            %orig(CGRectMake(0, 42, 428, 926));
        }
    } else if (notEnabled) {
        NSString *deviceModel = [Model deviceModel];
        if ([deviceModel isEqualToString:@"iPhone10,3"] || [deviceModel isEqualToString:@"iPhone10,6"] ||
            [deviceModel isEqualToString:@"iPhone11,2"] || [deviceModel isEqualToString:@"iPhone12,3"]) {
            %orig(CGRectMake(xNot, yNot, 375, 812));
        } else if ([deviceModel isEqualToString:@"iPhone11,6"] || [deviceModel isEqualToString:@"iPhone12,5"] ||
                   [deviceModel isEqualToString:@"iPhone11,8"] || [deviceModel isEqualToString:@"iPhone12,1"]) {
            %orig(CGRectMake(xNot, yNot, 414, 896));
        } else if ([deviceModel isEqualToString:@"iPhone13,2"] || [deviceModel isEqualToString:@"iPhone13,3"] ||
                   [deviceModel isEqualToString:@"iPhone14,5"] || [deviceModel isEqualToString:@"iPhone14,2"] ||
                   [deviceModel isEqualToString:@"iPhone14,7"]) {
            %orig(CGRectMake(xNot, yNot, 390, 844));
        } else if ([deviceModel isEqualToString:@"iPhone13,1"] || [deviceModel isEqualToString:@"iPhone14,4"]) {
            %orig(CGRectMake(xNot, yNot, 360, 780));
        } else if ([deviceModel isEqualToString:@"iPhone13,4"] || [deviceModel isEqualToString:@"iPhone14,3"]) {
            %orig(CGRectMake(xNot, yNot, 428, 926));
        }
    } else {
        %orig(frame);
    }
}

%end

static void respring(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[%c(FBSystemService) sharedInstance] exitAndRelaunch:YES];
}

void preferencesChanged() {
    CFPreferencesAppSynchronize(CFSTR("com.ethxnn88.visibleislandprefs"));
    NSDictionary *prefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.ethxnn88.visibleislandprefs"];

    fixEnabled = (prefs && [prefs objectForKey:@"fixEnabled"] ? [[prefs valueForKey:@"fixEnabled"] boolValue] : NO);
    islandEnabled = (prefs && [prefs objectForKey:@"islandEnabled"] ? [[prefs valueForKey:@"islandEnabled"] boolValue] : NO);
    posEnabled = (prefs && [prefs objectForKey:@"posEnabled"] ? [[prefs valueForKey:@"posEnabled"] boolValue] : NO);
    hideEnabled = (prefs && [prefs objectForKey:@"hideEnabled"] ? [[prefs valueForKey:@"hideEnabled"] boolValue] : NO);
    notificationFix = (prefs && [prefs objectForKey:@"notificationFix"] ? [[prefs valueForKey:@"notificationFix"] boolValue] : NO);
    notEnabled = (prefs && [prefs objectForKey:@"notEnabled"] ? [[prefs valueForKey:@"notEnabled"] boolValue] : NO);
    colorEnabled = (prefs && [prefs objectForKey:@"colorEnabled"] ? [[prefs valueForKey:@"colorEnabled"] boolValue] : NO);
    transEnabled = (prefs && [prefs objectForKey:@"transEnabled"] ? [[prefs valueForKey:@"transEnabled"] boolValue] : NO);
    scaleEnabled = (prefs && [prefs objectForKey:@"scaleEnabled"] ? [[prefs valueForKey:@"scaleEnabled"] boolValue] : NO);
    lineDisabled = (prefs && [prefs objectForKey:@"lineDisabled"] ? [[prefs valueForKey:@"lineDisabled"] boolValue] : NO);

    xPos = (prefs && [prefs objectForKey:@"xPos"]) ? [[prefs objectForKey:@"xPos"] floatValue] : 0.0;
    yPos = (prefs && [prefs objectForKey:@"yPos"]) ? [[prefs objectForKey:@"yPos"] floatValue] : -23.0;
    xNot = (prefs && [prefs objectForKey:@"xNot"]) ? [[prefs objectForKey:@"xNot"] floatValue] : 0.0;
    yNot = (prefs && [prefs objectForKey:@"yNot"]) ? [[prefs objectForKey:@"yNot"] floatValue] : 40.0;
    red = (prefs && [prefs objectForKey:@"red"]) ? [[prefs objectForKey:@"red"] floatValue] : 0.0;
    green = (prefs && [prefs objectForKey:@"green"]) ? [[prefs objectForKey:@"green"] floatValue] : 0.0;
    blue = (prefs && [prefs objectForKey:@"blue"]) ? [[prefs objectForKey:@"blue"] floatValue] : 0.0;
    alpha = (prefs && [prefs objectForKey:@"alpha"]) ? [[prefs objectForKey:@"alpha"] floatValue] : 1.0;

    // Independent Width (scale) and Height (scaleY)
    scale = (prefs && [prefs objectForKey:@"scale"] && [[prefs objectForKey:@"scale"] floatValue] > 0.1) ? [[prefs objectForKey:@"scale"] floatValue] : 1.15;
    scaleY = (prefs && [prefs objectForKey:@"scaleY"] && [[prefs objectForKey:@"scaleY"] floatValue] > 0.1) ? [[prefs objectForKey:@"scaleY"] floatValue] : scale;

    // Expanded Notch Avoidance
    expandedFixEnabled = (prefs && [prefs objectForKey:@"expandedFixEnabled"] ? [[prefs valueForKey:@"expandedFixEnabled"] boolValue] : YES);
    expandedYPos = (prefs && [prefs objectForKey:@"expandedYPos"]) ? [[prefs objectForKey:@"expandedYPos"] floatValue] : 20.0;
    expandedScale = (prefs && [prefs objectForKey:@"expandedScale"] && [[prefs objectForKey:@"expandedScale"] floatValue] > 0.1) ? [[prefs objectForKey:@"expandedScale"] floatValue] : 0.95;

    // Notch-Ear Compact Previews
    earModeEnabled = (prefs && [prefs objectForKey:@"earModeEnabled"] ? [[prefs valueForKey:@"earModeEnabled"] boolValue] : YES);
    hideStatusBarInEarMode = (prefs && [prefs objectForKey:@"hideStatusBarInEarMode"] ? [[prefs valueForKey:@"hideStatusBarInEarMode"] boolValue] : YES);
    compactScaleX = (prefs && [prefs objectForKey:@"compactScaleX"] && [[prefs objectForKey:@"compactScaleX"] floatValue] > 0.1) ? [[prefs objectForKey:@"compactScaleX"] floatValue] : 1.55;
    compactScaleY = (prefs && [prefs objectForKey:@"compactScaleY"] && [[prefs objectForKey:@"compactScaleY"] floatValue] > 0.1) ? [[prefs objectForKey:@"compactScaleY"] floatValue] : 1.05;
    compactYPos = (prefs && [prefs objectForKey:@"compactYPos"]) ? [[prefs objectForKey:@"compactYPos"] floatValue] : -23.0;
    earSpreadOffset = (prefs && [prefs objectForKey:@"earSpreadOffset"]) ? [[prefs objectForKey:@"earSpreadOffset"] floatValue] : 22.0;

    // Apply changes immediately on the main thread without needing a respring
    dispatch_async(dispatch_get_main_queue(), ^{
        if (sharedCurtainView) {
            sharedCurtainView.hidden = (fixEnabled || posEnabled || earModeEnabled || expandedFixEnabled);
        }
        if (sharedApertureWindow) {
            [sharedApertureWindow vi_applyIslandTransform];
            [sharedApertureWindow setNeedsLayout];
            [sharedApertureWindow layoutIfNeeded];
        }
    });
}

%ctor {
    preferencesChanged();

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)preferencesChanged, CFSTR("com.ethxnn88.visibleislandprefs-updated"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

    if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, respring, CFSTR("com.ethxnn88.visibleislandprefs-respring"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    }
}
