//
//  CleanString.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

extension NSNull {
    @objc var cleanString: String? { nil }
}

extension NSNumber {
    @objc var cleanString: String? { stringValue }
}
