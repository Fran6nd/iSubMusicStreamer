//
//  UIViewController+PushViewControllerCustom.swift
//  iSub
//
//  Created by François ND on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

extension UIViewController {

    func pushCustom(_ viewController: UIViewController) {
        pushViewControllerCustom(viewController)
    }

    @objc func pushViewControllerCustom(_ viewController: UIViewController) {
        if let navController = self as? UINavigationController {
            navController.pushViewController(viewController, animated: true)
        } else {
            navigationController?.pushViewController(viewController, animated: true)
        }
    }

    @objc func showPlayer() {
        if UIDevice.isPad {
            NotificationCenter.postNotificationToMainThread(name: ISMSNotification_ShowPlayer)
        } else {
            let playerViewController = PlayerViewController()
            playerViewController.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(playerViewController, animated: true)
        }
    }
}
