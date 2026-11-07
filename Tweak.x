#import <UIKit/UIKit.h>
#import <rootless.h>

@interface SBIcon : NSObject
- (NSString *)applicationBundleID;
@end

@interface SBIconImageView : UIView
@property (nonatomic, retain) SBIcon *icon;
@end

static NSDictionary *gConfig = nil;
static NSString *gBaseDir = nil;
static NSCache *gImageCache = nil;

static void loadConfig(void) {
    gBaseDir = ROOT_PATH_NS(@"/var/mobile/Library/RenameIcons");
    NSString *path = [gBaseDir stringByAppendingPathComponent:@"config.plist"];
    gConfig = [NSDictionary dictionaryWithContentsOfFile:path] ?: @{};
    gImageCache = [[NSCache alloc] init];
}

static void respringCallback(CFNotificationCenterRef center, void *observer,
                             CFNotificationName name, const void *object,
                             CFDictionaryRef userInfo) {
    exit(0); // SpringBoard перезапустится сам
}

static NSString *bundleIDFor(id icon) {
    if (icon && [icon respondsToSelector:@selector(applicationBundleID)]) {
        return [icon applicationBundleID];
    }
    return nil;
}

static NSString *customName(id icon) {
    NSString *bid = bundleIDFor(icon);
    if (!bid) return nil;
    NSDictionary *entry = gConfig[bid];
    if (![entry isKindOfClass:[NSDictionary class]]) return nil;
    NSString *name = entry[@"name"];
    return ([name isKindOfClass:[NSString class]] && name.length) ? name : nil;
}

static UIImage *customImage(id icon) {
    NSString *bid = bundleIDFor(icon);
    if (!bid) return nil;
    NSDictionary *entry = gConfig[bid];
    if (![entry isKindOfClass:[NSDictionary class]]) return nil;
    NSString *file = entry[@"icon"];
    if (![file isKindOfClass:[NSString class]] || !file.length) return nil;
    UIImage *img = [gImageCache objectForKey:file];
    if (!img) {
        img = [UIImage imageWithContentsOfFile:[gBaseDir stringByAppendingPathComponent:file]];
        if (img) [gImageCache setObject:img forKey:file];
    }
    return img;
}

%hook SBIcon
- (NSString *)displayNameForLocation:(NSInteger)location {
    NSString *name = customName(self);
    return name ?: %orig;
}
%end

%hook SBApplicationIcon
- (NSString *)displayNameForLocation:(NSInteger)location {
    NSString *name = customName(self);
    return name ?: %orig;
}
%end

%hook SBIconImageView
- (UIImage *)contentsImage {
    UIImage *custom = customImage(self.icon);
    return custom ?: %orig;
}
%end

%ctor {
    loadConfig();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL, respringCallback,
                                    CFSTR("com.user.renameicons/respring"), NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}
