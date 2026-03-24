//
//  UIDevice+Info.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Darwin
import UIKit

extension UIDevice {
    @objc static var isPad: Bool {
        current.userInterfaceIdiom == .pad
    }

    @objc static var isSmall: Bool {
        let screenSize = UIScreen.main.bounds.size
        let height = UIApplication.orientation.isPortrait ? screenSize.height : screenSize.width
        return height < 700
    }

    @objc static var platform: String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var value = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &value, &size, nil, 0)
        return String(cString: value)
    }

    @objc static var systemBuild: String {
        var mib: [Int32] = [CTL_KERN, KERN_OSVERSION]
        var size = 0
        sysctl(&mib, 2, nil, &size, nil, 0)
        var value = [CChar](repeating: 0, count: size)
        sysctl(&mib, 2, &value, &size, nil, 0)
        return String(cString: value)
    }

    @objc static var completeVersionString: String {
        "\(current.systemName) \(current.systemVersion) (\(systemBuild))"
    }
}
