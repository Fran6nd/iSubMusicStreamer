//
//  EX2NetworkIndicator.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

// NOTE: Only works on devices before the iPhone X (no-notch displays)
@objc class EX2NetworkIndicator: NSObject {

    private static let lock = NSLock()
    private static var networkUseCount: UInt = 0

    @objc static func usingNetwork() {
        lock.lock()
        defer { lock.unlock() }
        networkUseCount += 1
        EX2Dispatch.runInMainThread(waitUntilDone: true) {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
        }
    }

    @objc static func doneUsingNetwork() {
        lock.lock()
        defer { lock.unlock() }
        guard networkUseCount > 0 else { return }
        networkUseCount -= 1
        if networkUseCount == 0 {
            EX2Dispatch.runInMainThread(waitUntilDone: true) {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
        }
    }

    @objc static func goingOffline() {
        lock.lock()
        defer { lock.unlock() }
        networkUseCount = 0
        EX2Dispatch.runInMainThread(waitUntilDone: true) {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }
    }
}
