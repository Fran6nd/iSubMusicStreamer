//
//  NSNotificationCenter+MainThread.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

extension NotificationCenter {
    // MARK: - Post

    @objc(postNotificationToMainThreadWithName:object:userInfo:)
    static func postNotificationToMainThread(name: String, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        guard !name.isEmpty else { return }
        if Thread.isMainThread {
            NotificationCenter.default.post(name: Notification.Name(name), object: object, userInfo: userInfo)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name(name), object: object, userInfo: userInfo)
            }
        }
    }

    @objc(postNotificationToMainThreadWithName:userInfo:)
    static func postNotificationToMainThread(name: String, userInfo: [AnyHashable: Any]?) {
        postNotificationToMainThread(name: name, object: nil, userInfo: userInfo)
    }

    @objc(postNotificationToMainThreadWithName:object:)
    static func postNotificationToMainThread(name: String, object: Any?) {
        postNotificationToMainThread(name: name, object: object, userInfo: nil)
    }

    @objc(postNotificationToMainThreadWithName:)
    static func postNotificationToMainThread(name: String) {
        postNotificationToMainThread(name: name, object: nil, userInfo: nil)
    }

    // MARK: - Add observer (sync)

    @objc(addObserverOnMainThread:selector:name:object:)
    static func addObserverOnMainThread(_ observer: Any, selector: Selector, name: String, object: Any?) {
        EX2Dispatch.runInMainThread(waitUntilDone: true) {
            NotificationCenter.default.addObserver(observer, selector: selector, name: Notification.Name(name), object: object)
        }
    }

    @objc(addObserverOnMainThread:selector:name:)
    static func addObserverOnMainThread(_ observer: Any, selector: Selector, name: String) {
        addObserverOnMainThread(observer, selector: selector, name: name, object: nil)
    }

    // MARK: - Add observer (async)

    @objc(addObserverOnMainThreadAsync:selector:name:object:)
    static func addObserverOnMainThreadAsync(_ observer: Any, selector: Selector, name: String, object: Any?) {
        EX2Dispatch.runInMainThread(waitUntilDone: false) {
            NotificationCenter.default.addObserver(observer, selector: selector, name: Notification.Name(name), object: object)
        }
    }

    @objc(addObserverOnMainThreadAsync:selector:name:)
    static func addObserverOnMainThreadAsync(_ observer: Any, selector: Selector, name: String) {
        addObserverOnMainThreadAsync(observer, selector: selector, name: name, object: nil)
    }

    // MARK: - Add observer with block

    @objc(addObserverOnMainThreadForName:object:usingBlock:)
    @discardableResult static func addObserverOnMainThread(forName name: String, object: Any?, handler: @escaping (Notification) -> Void) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(forName: Notification.Name(name), object: object, queue: .main, using: handler)
    }

    @objc(addObserverOnMainThreadForName:usingBlock:)
    @discardableResult static func addObserverOnMainThread(forName name: String, handler: @escaping (Notification) -> Void) -> NSObjectProtocol {
        addObserverOnMainThread(forName: name, object: nil, handler: handler)
    }

    // MARK: - Remove observer

    @objc(removeObserverOnMainThread:)
    static func removeObserverOnMainThread(_ observer: Any) {
        EX2Dispatch.runInMainThread(waitUntilDone: true) {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    @objc(removeObserverOnMainThread:name:object:)
    static func removeObserverOnMainThread(_ observer: Any, name: String, object: Any?) {
        EX2Dispatch.runInMainThread(waitUntilDone: true) {
            NotificationCenter.default.removeObserver(observer, name: Notification.Name(name), object: object)
        }
    }

    @objc(removeObserverOnMainThread:name:)
    static func removeObserverOnMainThread(_ observer: Any, name: String) {
        removeObserverOnMainThread(observer, name: name, object: nil)
    }
}
