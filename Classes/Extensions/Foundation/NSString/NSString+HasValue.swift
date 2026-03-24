//
//  NSString+HasValue.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

extension NSString {
    /// Returns true if the string is non-empty.
    /// When called on nil via ObjC messaging, the runtime returns false automatically.
    @objc var hasValue: Bool {
        return self != ""
    }
}
