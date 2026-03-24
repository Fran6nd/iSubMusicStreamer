//
//  NSArray+Safe.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

extension NSArray {
    @objc func objectAtIndexSafe(_ index: UInt) -> Any? {
        guard index < UInt(count) else { return nil }
        return self[Int(index)]
    }
}
