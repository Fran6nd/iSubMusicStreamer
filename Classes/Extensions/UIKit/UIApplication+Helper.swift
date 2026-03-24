//
//  UIApplication+Helper.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

extension UIApplication {
    @objc static var orientation: UIInterfaceOrientation {
        shared.windows.first?.windowScene?.interfaceOrientation ?? .unknown
    }

    @objc static var keyWindow: UIWindow? {
        shared.windows.first { $0.isKeyWindow }
    }

    @objc static var statusBarHeight: CGFloat {
        keyWindow?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
    }
}
