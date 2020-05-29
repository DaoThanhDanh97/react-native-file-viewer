
#import "RNFileViewerManager.h"
#import <QuickLook/QuickLook.h>
#import <React/RCTConvert.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#define OPEN_EVENT @"RNFileViewerDidOpen"
#define DISMISS_EVENT @"RNFileViewerDidDismiss"
#define THUMBNAIL_EVENT @"RNThumbnailEvent"

@interface File: NSObject<QLPreviewItem>

@property(readonly, nullable, nonatomic) NSURL *previewItemURL;
@property(readonly, nullable, nonatomic) NSString *previewItemTitle;

- (id)initWithPath:(NSString *)file title:(NSString *)title;

@end

@interface RNFileViewer ()<QLPreviewControllerDelegate>
@end

@implementation File

- (id)initWithPath:(NSString *)file title:(NSString *)title {
    if(self = [super init]) {
        _previewItemURL = [NSURL fileURLWithPath:file];
        _previewItemTitle = title;
    }
    return self;
}

@end

@interface CustomQLViewController: QLPreviewController<QLPreviewControllerDataSource>

@property(nonatomic, strong) File *file;
@property(nonatomic, strong) NSNumber *invocation;

@end

@implementation CustomQLViewController

- (instancetype)initWithFile:(File *)file identifier:(NSNumber *)invocation {
    if(self = [super init]) {
        _file = file;
        _invocation = invocation;
        self.dataSource = self;
    }
    return self;
}

- (BOOL)prefersStatusBarHidden {
    return UIApplication.sharedApplication.isStatusBarHidden;
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller{
    return 1;
}

- (id <QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index{
    return self.file;
}

@end

@implementation RNFileViewer

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

+ (UIViewController*)topViewController {
    return [self topViewControllerWithRootViewController:[UIApplication sharedApplication].keyWindow.rootViewController];
}

+ (UIViewController*)topViewControllerWithRootViewController:(UIViewController*)viewController {
    if ([viewController isKindOfClass:[UITabBarController class]]) {
        UITabBarController* tabBarController = (UITabBarController*)viewController;
        return [self topViewControllerWithRootViewController:tabBarController.selectedViewController];
    } else if ([viewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController* navContObj = (UINavigationController*)viewController;
        return [self topViewControllerWithRootViewController:navContObj.visibleViewController];
    } else if (viewController.presentedViewController && !viewController.presentedViewController.isBeingDismissed) {
        UIViewController* presentedViewController = viewController.presentedViewController;
        return [self topViewControllerWithRootViewController:presentedViewController];
    }
    else {
        for (UIView *view in [viewController.view subviews])
        {
            id subViewController = [view nextResponder];
            if ( subViewController && [subViewController isKindOfClass:[UIViewController class]])
            {
                if ([(UIViewController *)subViewController presentedViewController]  && ![subViewController presentedViewController].isBeingDismissed) {
                    return [self topViewControllerWithRootViewController:[(UIViewController *)subViewController presentedViewController]];
                }
            }
        }
        return viewController;
    }
}

- (void)previewControllerDidDismiss:(CustomQLViewController *)controller {
    [self sendEventWithName:DISMISS_EVENT body: @{@"id": controller.invocation}];
}

RCT_EXPORT_MODULE()

- (NSArray<NSString *> *)supportedEvents {
    return @[OPEN_EVENT, DISMISS_EVENT, THUMBNAIL_EVENT];
}

RCT_EXPORT_METHOD(open:(NSString *)path invocation:(nonnull NSNumber *)invocationId
    options:(NSDictionary *)options)
{
    NSString *displayName = [RCTConvert NSString:options[@"displayName"]];
    File *file = [[File alloc] initWithPath:path title:displayName];

    QLPreviewController *controller = [[CustomQLViewController alloc] initWithFile:file identifier:invocationId];
    controller.delegate = self;

    typeof(self) __weak weakSelf = self;
    [[RNFileViewer topViewController] presentViewController:controller animated:YES completion:^{
        [weakSelf sendEventWithName:OPEN_EVENT body: @{@"id": invocationId}];
    }];
}


RCT_EXPORT_METHOD(getThumbnail: (NSString*)path invocation: (nonnull NSNumber *) invocationId)
{
    AVURLAsset* asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options: nil];
    AVAssetImageGenerator* imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    [imageGenerator setAppliesPreferredTrackTransform:TRUE];
    UIImage* image = [UIImage imageWithCGImage:[imageGenerator copyCGImageAtTime:CMTimeMake(0, 1) actualTime:nil error:nil]];
    NSData *imageData = UIImagePNGRepresentation(image);
    NSString * base64String = [imageData base64EncodedStringWithOptions:0];
    typeof(self) __weak weakSelf = self;
    [weakSelf sendEventWithName:THUMBNAIL_EVENT body: @{@"id": invocationId, @"result": base64String }];
}
@end
