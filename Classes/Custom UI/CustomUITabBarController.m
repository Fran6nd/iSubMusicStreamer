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
@property (nonatomic, strong) NSLayoutConstraint *miniPlayerBottomConstraint;
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

    // Mini player — sits above the tab bar, mirrors tab bar lifetime (never hidden programmatically)
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
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:player];
        if (@available(iOS 15, *)) {
            nav.modalPresentationStyle = UIModalPresentationPageSheet;
            UISheetPresentationController *sheet = nav.sheetPresentationController;
            sheet.detents = @[UISheetPresentationControllerDetent.largeDetent];
            sheet.prefersGrabberVisible = YES;
        } else {
            nav.modalPresentationStyle = UIModalPresentationFullScreen;
        }
        if (strongSelf.presentedViewController) {
            [strongSelf dismissViewControllerAnimated:NO completion:^{
                [strongSelf presentViewController:nav animated:YES completion:nil];
            }];
        } else {
            [strongSelf presentViewController:nav animated:YES completion:nil];
        }
    };

    [self.view addSubview:_miniPlayerView];

    // Anchor to view.bottomAnchor — constant is kept in sync with tabBar height in viewDidLayoutSubviews.
    // This decouples us from tabBar.topAnchor, which UIKit repositions during sheet presentations.
    _miniPlayerBottomConstraint = [_miniPlayerView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:0];
    [NSLayoutConstraint activateConstraints:@[
        [_miniPlayerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_miniPlayerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        _miniPlayerBottomConstraint,
        [_miniPlayerView.heightAnchor constraintEqualToConstant:kMiniPlayerHeight],
    ]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    // Keep mini player flush above the tab bar by tracking its current frame.
    _miniPlayerBottomConstraint.constant = -self.tabBar.frame.size.height;

    // Reserve space so child view controllers are never obscured by the mini player.
    self.additionalSafeAreaInsets = _miniPlayerView.isHidden
        ? UIEdgeInsetsZero
        : UIEdgeInsetsMake(0, 0, kMiniPlayerHeight, 0);
}

@end
