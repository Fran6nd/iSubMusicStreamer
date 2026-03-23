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

    // Add persistent mini player above the tab bar using auto layout
    _miniPlayerView = [[MiniPlayerView alloc] initWithFrame:CGRectZero];
    __weak CustomUITabBarController *weakSelf = self;
    _miniPlayerView.openPlayerHandler = ^{
        __strong CustomUITabBarController *strongSelf = weakSelf;
        if (!strongSelf) return;
        // Avoid stacking duplicate player sheets
        if ([strongSelf.presentedViewController isKindOfClass:UINavigationController.class]) {
            UINavigationController *existing = (UINavigationController *)strongSelf.presentedViewController;
            if ([existing.topViewController isKindOfClass:PlayerViewController.class]) return;
        }
        PlayerViewController *player = [[PlayerViewController alloc] init];
        player.onDismiss = ^{
            __strong CustomUITabBarController *s = weakSelf;
            s.miniPlayerView.hidden = NO;
            [s viewDidLayoutSubviews];
        };
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:player];
        if (@available(iOS 15, *)) {
            nav.modalPresentationStyle = UIModalPresentationPageSheet;
            UISheetPresentationController *sheet = nav.sheetPresentationController;
            sheet.detents = @[UISheetPresentationControllerDetent.largeDetent];
            sheet.prefersGrabberVisible = YES;
        } else {
            nav.modalPresentationStyle = UIModalPresentationFullScreen;
        }
        strongSelf.miniPlayerView.hidden = YES;
        [strongSelf viewDidLayoutSubviews];
        if (strongSelf.presentedViewController) {
            [strongSelf dismissViewControllerAnimated:NO completion:^{
                [strongSelf presentViewController:nav animated:YES completion:nil];
            }];
        } else {
            [strongSelf presentViewController:nav animated:YES completion:nil];
        }
    };
    [self.view addSubview:_miniPlayerView];

    // Pin the mini player to the leading/trailing edges and directly above the tab bar
    [NSLayoutConstraint activateConstraints:@[
        [_miniPlayerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_miniPlayerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_miniPlayerView.bottomAnchor constraintEqualToAnchor:self.tabBar.topAnchor],
        [_miniPlayerView.heightAnchor constraintEqualToConstant:kMiniPlayerHeight]
    ]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Update safe area insets so content is never hidden behind the visible mini player
    self.additionalSafeAreaInsets = (!_miniPlayerView || _miniPlayerView.isHidden)
        ? UIEdgeInsetsZero
        : UIEdgeInsetsMake(0, 0, kMiniPlayerHeight, 0);
}

@end
