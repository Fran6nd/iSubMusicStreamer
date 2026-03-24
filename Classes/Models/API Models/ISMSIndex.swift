//
//  ISMSIndex.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

@objc(ISMSIndex)
final class ISMSIndex: NSObject {
    @objc var name: String?
    @objc var position: UInt = UInt.max
    @objc var count: UInt = UInt.max
}
