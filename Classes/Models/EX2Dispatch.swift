//
//  EX2Dispatch.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

@objc class EX2Dispatch: NSObject {

    // MARK: - Run after delay

    @objc(runInQueue:delay:block:)
    static func run(in queue: DispatchQueue, delay: TimeInterval, block: @escaping () -> Void) {
        queue.asyncAfter(deadline: .now() + delay, execute: block)
    }

    @objc static func runInMainThread(afterDelay delay: TimeInterval, block: @escaping () -> Void) {
        run(in: .main, delay: delay, block: block)
    }

    @objc static func runInBackground(afterDelay delay: TimeInterval, block: @escaping () -> Void) {
        run(in: .global(), delay: delay, block: block)
    }

    // MARK: - Sync / async

    @objc(runInQueue:waitUntilDone:block:)
    static func run(in queue: DispatchQueue, waitUntilDone: Bool, block: @escaping () -> Void) {
        if waitUntilDone {
            queue.sync(execute: block)
        } else {
            queue.async(execute: block)
        }
    }

    @objc(runInMainThreadAndWaitUntilDone:block:)
    static func runInMainThread(waitUntilDone: Bool, block: @escaping () -> Void) {
        // Calling sync on the main queue from the main thread causes a deadlock — run directly
        if Thread.isMainThread && waitUntilDone {
            block()
            return
        }
        run(in: .main, waitUntilDone: waitUntilDone, block: block)
    }

    // MARK: - Async convenience

    @objc(runAsync:block:)
    static func runAsync(_ queue: DispatchQueue, block: @escaping () -> Void) {
        queue.async(execute: block)
    }

    @objc static func runInBackgroundAsync(_ block: @escaping () -> Void) {
        runAsync(.global(), block: block)
    }

    @objc static func runInMainThreadAsync(_ block: @escaping () -> Void) {
        runAsync(.main, block: block)
    }
}
