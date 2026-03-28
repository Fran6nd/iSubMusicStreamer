//
//  CustomUINavigationController.swift
//  iSub
//
//  Created by Francois ND on 3/23/26.
//  Copyright © 2026 Francois ND. All rights reserved.
//

import UIKit

@objc(CustomUINavigationController)
final class CustomUINavigationController: UINavigationController {

    // MARK: - Rotation

    override var shouldAutorotate: Bool {
        if Settings.shared().isRotationLockEnabled && UIDevice.current.orientation != .portrait {
            return false
        }
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationBarAppearance()
        // Install self as delegate so we can keep VCs from extending under the nav bar.
        // CustomUITabBarController will override this and forward back here.
        delegate = self
    }

    // MARK: - Navigation Bar Appearance

    static func makeBarAppearance() -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.shadowColor = nil
        return appearance
    }

    private func configureNavigationBarAppearance() {
        let appearance = Self.makeBarAppearance()
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = .white
    }
}

// MARK: - UINavigationControllerDelegate

extension CustomUINavigationController: UINavigationControllerDelegate {

    func navigationController(_ navigationController: UINavigationController,
                               willShow viewController: UIViewController,
                               animated: Bool) {
    }
}
