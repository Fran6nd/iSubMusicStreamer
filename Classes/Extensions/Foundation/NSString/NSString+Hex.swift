//
//  NSString+Hex.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

extension NSString {
    @objc(stringFromHex:) static func string(fromHex hex: String) -> String? {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        return String(data: data, encoding: .utf8)
    }

    @objc(stringToHex:) static func string(toHex str: String) -> String {
        str.unicodeScalars.map { String(format: "%02x", $0.value) }.joined()
    }

    @objc var fromHex: String? { NSString.string(fromHex: self as String) }
    @objc var toHex: String   { NSString.string(toHex: self as String) }
}
