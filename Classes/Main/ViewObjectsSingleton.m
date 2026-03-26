//
//  ViewObjectsSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ViewObjectsSingleton.h"
#import "iSubAppDelegate.h"
#import "Defines.h"
#import "SavedSettings.h"
#import "EX2Kit.h"
#import "Swift.h"

#define HUD_GRACE_TIME 0.5

// MARK: - Native loading HUD

@interface ViewObjectsSingleton()
@property (nullable, strong) UIView *hudOverlay;
@property (nullable, strong) NSTimer *hudGraceTimer;
@property (nullable, strong) UILabel *hudLabel;
@property BOOL isLoadingScreenShowing;
@end

@implementation ViewObjectsSingleton

// MARK: - Loading screen

- (void)showLoadingScreenOnMainWindowNotification:(NSNotification *)notification {
    [self showLoadingScreenOnMainWindowWithMessage:notification.userInfo[@"message"]];
}

- (void)showLoadingScreenOnMainWindowWithMessage:(NSString *)message {
	[self showLoadingScreen:appDelegateS.window withMessage:message];
}

- (void)showLoadingScreen:(UIView *)view withMessage:(NSString *)message {
	if (self.isLoadingScreenShowing) {
        self.hudLabel.text = message ? message : self.hudLabel.text;
		return;
    }

	self.isLoadingScreenShowing = YES;

    NSString *labelText = message ? message : @"Loading";
    __weak ViewObjectsSingleton *weakSelf = self;
    self.hudGraceTimer = [NSTimer scheduledTimerWithTimeInterval:HUD_GRACE_TIME repeats:NO block:^(NSTimer *timer) {
        if (weakSelf.isLoadingScreenShowing) {
            [weakSelf presentHUDOnView:view message:labelText cancelTarget:nil];
        }
    }];
}

- (void)showAlbumLoadingScreenOnMainWindowNotification:(NSNotification *)notification {
    [self showAlbumLoadingScreenOnMainWindowWithSender:notification.userInfo[@"sender"]];
}

- (void)showAlbumLoadingScreenOnMainWindowWithSender:(id)sender {
    [self showAlbumLoadingScreen:appDelegateS.window sender:sender];
}

- (void)showAlbumLoadingScreen:(UIView *)view sender:(id)sender {
	if (self.isLoadingScreenShowing) return;

	self.isLoadingScreenShowing = YES;

    __weak ViewObjectsSingleton *weakSelf = self;
    id cancelTarget = [sender respondsToSelector:@selector(cancelLoad)] ? sender : nil;
    self.hudGraceTimer = [NSTimer scheduledTimerWithTimeInterval:HUD_GRACE_TIME repeats:NO block:^(NSTimer *timer) {
        if (weakSelf.isLoadingScreenShowing) {
            [weakSelf presentHUDOnView:appDelegateS.window message:@"Loading" cancelTarget:cancelTarget];
        }
    }];
}

/// Builds and displays the HUD overlay. Must be called on the main thread.
- (void)presentHUDOnView:(UIView *)view message:(NSString *)message cancelTarget:(nullable id)cancelTarget {
    // Full-screen dimming overlay (does not intercept touches so the cancel button works)
    UIView *overlay = [[UIView alloc] initWithFrame:view.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
    overlay.alpha = 0;
    [view addSubview:overlay];
    self.hudOverlay = overlay;

    // Blurred bezel
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    UIVisualEffectView *bezel = [[UIVisualEffectView alloc] initWithEffect:blur];
    bezel.layer.cornerRadius = 14;
    bezel.clipsToBounds = YES;
    bezel.translatesAutoresizingMaskIntoConstraints = NO;
    [overlay addSubview:bezel];
    [NSLayoutConstraint activateConstraints:@[
        [bezel.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
        [bezel.centerYAnchor constraintEqualToAnchor:overlay.centerYAnchor],
        [bezel.widthAnchor constraintGreaterThanOrEqualToConstant:130],
        [bezel.heightAnchor constraintGreaterThanOrEqualToConstant:100],
    ]];

    UIView *content = bezel.contentView;

    // Spinner
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [spinner startAnimating];
    [content addSubview:spinner];

    // Label
    UILabel *label = [[UILabel alloc] init];
    label.text = message;
    label.textColor = UIColor.labelColor;
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:label];
    self.hudLabel = label;

    [NSLayoutConstraint activateConstraints:@[
        [spinner.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [spinner.topAnchor constraintEqualToAnchor:content.topAnchor constant:20],
        [label.topAnchor constraintEqualToAnchor:spinner.bottomAnchor constant:10],
        [label.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [label.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [label.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-20],
    ]];

    // Optional cancel button covering the bezel
    if (cancelTarget) {
        UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
        cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
        [cancelButton addTarget:cancelTarget action:@selector(cancelLoad) forControlEvents:UIControlEventTouchUpInside];
        [overlay addSubview:cancelButton];
        [NSLayoutConstraint activateConstraints:@[
            [cancelButton.leadingAnchor constraintEqualToAnchor:bezel.leadingAnchor],
            [cancelButton.trailingAnchor constraintEqualToAnchor:bezel.trailingAnchor],
            [cancelButton.topAnchor constraintEqualToAnchor:bezel.topAnchor],
            [cancelButton.bottomAnchor constraintEqualToAnchor:bezel.bottomAnchor],
        ]];
    }

    // Fade in
    [UIView animateWithDuration:0.25 animations:^{
        overlay.alpha = 1;
    }];
}

- (void)hideLoadingScreen {
	if (!self.isLoadingScreenShowing) return;
	self.isLoadingScreenShowing = NO;

    [self.hudGraceTimer invalidate];
    self.hudGraceTimer = nil;
    self.hudLabel = nil;

    UIView *overlay = self.hudOverlay;
    self.hudOverlay = nil;
    [UIView animateWithDuration:0.2 animations:^{
        overlay.alpha = 0;
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
    }];
}

- (UIColor *)currentDarkColor {
	switch(settingsS.cachedSongCellColorType) {
		case 0: return self.darkRed;
		case 1: return self.darkYellow;
		case 2: return self.darkGreen;
		case 3: return self.darkBlue;
		default: return self.darkBlue;
	}
}

#pragma mark Tab Saving

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    // Prevent view controllers from going under the navigation bar
    viewController.edgesForExtendedLayout = UIRectEdgeNone;

    // Remember selected tab
    if (!settingsS.isOfflineMode) {
        [[NSUserDefaults standardUserDefaults] setInteger:appDelegateS.mainTabBarController.selectedIndex forKey:@"mainTabBarControllerSelectedIndex"];
    }

    // Fix iOS bug customizing the more tab controller
    if (appDelegateS.currentTabBarController == appDelegateS.mainTabBarController && ![viewController.navigationController isKindOfClass:CustomUINavigationController.class]) {
        [CustomUITabBarController customizeMoreTabTableView:appDelegateS.mainTabBarController];
    }
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    // Remember selected tab
    if (!settingsS.isOfflineMode) {
		[[NSUserDefaults standardUserDefaults] setInteger:appDelegateS.mainTabBarController.selectedIndex forKey:@"mainTabBarControllerSelectedIndex"];
    }
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    // Remember selected tab
    if (!settingsS.isOfflineMode) {
		[[NSUserDefaults standardUserDefaults] setInteger:appDelegateS.mainTabBarController.selectedIndex forKey:@"mainTabBarControllerSelectedIndex"];
    }
}

- (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed {
    NSUInteger count = tabBarController.viewControllers.count;
    NSMutableArray *savedTabsOrder = [[NSMutableArray alloc] initWithCapacity:count];
    for (int i = 0; i < count; i ++) {
        [savedTabsOrder addObject:@([[[tabBarController.viewControllers objectAtIndexSafe:i] tabBarItem] tag])];
    }
    [NSUserDefaults.standardUserDefaults setObject:savedTabsOrder forKey:@"mainTabBarTabsOrder"];
	[NSUserDefaults.standardUserDefaults synchronize];
}

- (void)applyTabBarSFSymbolsToController:(UITabBarController *)tabBarController {
    NSDictionary<NSNumber *, NSString *> *tagToSymbol = @{
        @(0): @"folder",
        @(1): @"square.stack",
        @(2): @"music.note",
        @(3): @"music.note.list",
        @(4): @"bookmark",
        @(5): @"play.circle",
        @(6): @"guitars",
        @(7): @"arrow.down.circle",
        @(8): @"message",
        @(9): @"house",
    };
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];
    for (UIViewController *vc in tabBarController.viewControllers) {
        NSString *symbolName = tagToSymbol[@(vc.tabBarItem.tag)];
        if (symbolName) {
            UIImage *image = [UIImage systemImageNamed:symbolName withConfiguration:config];
            vc.tabBarItem.image = image;
            vc.tabBarItem.selectedImage = image;
        }
    }
}

- (void)orderMainTabBarController {
//	appDelegateS.currentTabBarController = appDelegateS.mainTabBarController;
	appDelegateS.mainTabBarController.delegate = self;

	NSArray *savedTabsOrderArray = [[NSUserDefaults standardUserDefaults] arrayForKey:@"mainTabBarTabsOrder"];

	// If this is an old device, remove Albums and Songs tabs
	if (!settingsS.isSongsTabEnabled) {
		NSMutableArray *tabs = [[NSMutableArray alloc] init];
		for (UIViewController *controller in appDelegateS.mainTabBarController.viewControllers) {
			if (controller.tabBarItem.tag != 1 && controller.tabBarItem.tag != 2 && controller.tabBarItem.tag != 6) {
				[tabs addObject:controller];
			}
		}
		appDelegateS.mainTabBarController.viewControllers = tabs;

		tabs = [[NSMutableArray alloc] init];
		for (NSNumber *tag in savedTabsOrderArray) {
			if (tag.intValue != 1 && tag.intValue != 2 && tag.intValue != 6) {
				[tabs addObject:tag];
			}
		}
		savedTabsOrderArray = tabs;
	}

	NSUInteger count = appDelegateS.mainTabBarController.viewControllers.count;
	if (savedTabsOrderArray.count == count) {
		BOOL needsReordering = NO;

		NSMutableDictionary *tabsOrderDictionary = [[NSMutableDictionary alloc] initWithCapacity:count];
		for (int i = 0; i < count; i ++) {
			NSNumber *tag = @([[[appDelegateS.mainTabBarController.viewControllers objectAtIndexSafe:i] tabBarItem] tag]);
			[tabsOrderDictionary setObject:@(i) forKey:[tag stringValue]];

			if (!needsReordering && ![(NSNumber *)[savedTabsOrderArray objectAtIndexSafe:i] isEqualToNumber:tag]) {
				needsReordering = YES;
			}
		}

		if (needsReordering) {
			NSMutableArray *tabsViewControllers = [[NSMutableArray alloc] initWithCapacity:count];
			for (int i = 0; i < count; i ++) {
				[tabsViewControllers addObject:[appDelegateS.mainTabBarController.viewControllers objectAtIndexSafe:[(NSNumber *)[tabsOrderDictionary objectForKey:[(NSNumber *)[savedTabsOrderArray objectAtIndexSafe:i] stringValue]] intValue]]];
			}

			appDelegateS.mainTabBarController.viewControllers = [NSArray arrayWithArray:tabsViewControllers];
		}
	}

    appDelegateS.mainTabBarController.moreNavigationController.delegate = self;

    if ([NSUserDefaults.standardUserDefaults integerForKey:@"mainTabBarControllerSelectedIndex"]) {
        if ([NSUserDefaults.standardUserDefaults integerForKey:@"mainTabBarControllerSelectedIndex"] == 2147483647) {
            appDelegateS.mainTabBarController.selectedViewController = appDelegateS.mainTabBarController.moreNavigationController;
        } else {
            appDelegateS.mainTabBarController.selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"mainTabBarControllerSelectedIndex"];
        }
    }

    [self applyTabBarSFSymbolsToController:appDelegateS.mainTabBarController];
}

- (void)setup {
	_darkRed = [UIColor colorWithRed:226/255.0 green:0/255.0 blue:0/255.0 alpha:1];
	_darkYellow = [UIColor colorWithRed:255/255.0 green:215/255.0 blue:0/255.0 alpha:1];
	_darkGreen = [UIColor colorWithRed:103/255.0 green:227/255.0 blue:0/255.0 alpha:1];
	_darkBlue = [UIColor colorWithRed:28/255.0 green:163/255.0 blue:255/255.0 alpha:1];

	_windowColor = [UIColor colorWithWhite:.3 alpha:1];
	_jukeboxColor = [UIColor colorWithRed:140.0/255.0 green:0.0 blue:0.0 alpha:1.0];

    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(showAlbumLoadingScreenOnMainWindowNotification:) name:ISMSNotification_ShowAlbumLoadingScreenOnMainWindow object:nil];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(showLoadingScreenOnMainWindowNotification:) name:ISMSNotification_ShowLoadingScreenOnMainWindow object:nil];
    [NSNotificationCenter addObserverOnMainThread:self selector:@selector(hideLoadingScreen) name:ISMSNotification_HideLoadingScreen object:nil];
}

+ (instancetype)sharedInstance {
    static ViewObjectsSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
