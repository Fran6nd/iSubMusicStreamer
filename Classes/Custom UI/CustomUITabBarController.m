//
//  CustomUITabBarController.m
//  iSub
//
//  Created by Benjamin Baron on 10/18/13.
//  Copyright (c) 2013 Ben Baron. All rights reserved.
//

#import "CustomUITabBarController.h"
#import "SavedSettings.h"
#import "ViewObjectsSingleton.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "Swift.h"

static const CGFloat kMiniPlayerHeight = 64.0;

@interface CustomUITabBarController ()
@property (nonatomic, strong) MiniPlayerView *miniPlayerView;
@end

@implementation CustomUITabBarController

+ (void)customizeMoreTabTableView:(UITabBarController *)tabBarController {
    // Customize more tab
    tabBarController.moreNavigationController.navigationBar.barStyle = UIBarStyleBlack;
    UIViewController *moreController = tabBarController.moreNavigationController.topViewController;
    if ([moreController.view isKindOfClass:UITableView.class]) {
        UITableView *moreTableView = (UITableView *)moreController.view;
        moreTableView.backgroundColor = [UIColor colorNamed:@"isubBackgroundColor"];
        moreTableView.rowHeight = Defines.rowHeight;
        moreTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
}

- (BOOL)shouldAutorotate {
    if (settingsS.isRotationLockEnabled && UIDevice.currentDevice.orientation != UIDeviceOrientationPortrait) {
        return NO;
    }
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [viewObjectsS orderMainTabBarController];
    [self.class customizeMoreTabTableView:self];

    // Add persistent mini player above the tab bar
    _miniPlayerView = [[MiniPlayerView alloc] initWithFrame:CGRectZero];
    __weak CustomUITabBarController *weakSelf = self;
    _miniPlayerView.openPlayerHandler = ^{
        UIViewController *top = weakSelf.selectedViewController;
        // Unwrap navigation controller to get its top VC
        if ([top isKindOfClass:[UINavigationController class]]) {
            top = [(UINavigationController *)top topViewController];
        }
        [top showPlayer];
    };
    [self.view addSubview:_miniPlayerView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutMiniPlayer];
}

- (void)layoutMiniPlayer {
    if (!_miniPlayerView || _miniPlayerView.isHidden) {
        self.additionalSafeAreaInsets = UIEdgeInsetsZero;
        return;
    }

    CGFloat tabBarY = self.tabBar.frame.origin.y;
    _miniPlayerView.frame = CGRectMake(0,
                                       tabBarY - kMiniPlayerHeight,
                                       self.view.bounds.size.width,
                                       kMiniPlayerHeight);
    // Lift child view controller content so nothing is hidden behind the mini player
    self.additionalSafeAreaInsets = UIEdgeInsetsMake(0, 0, kMiniPlayerHeight, 0);
}

@end
