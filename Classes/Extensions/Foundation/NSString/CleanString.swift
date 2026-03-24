//
//  CleanString.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

extension NSString {
    @objc var cleanString: String {
        let htmlDecoded = (gtm_stringByUnescapingFromHTML() as String?) ?? (self as String)
        return htmlDecoded.removingPercentEncoding ?? htmlDecoded
    }
}

extension NSNull {
    @objc var cleanString: String? { nil }
}

extension NSNumber {
    @objc var cleanString: String? { stringValue }
}
