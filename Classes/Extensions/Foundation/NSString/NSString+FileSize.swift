//
//  NSString+FileSize.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

extension NSString {
    @objc(formatFileSize:) static func formatFileSize(_ size: UInt64) -> String {
        switch size {
        case 0..<1024:
            return "\(size) bytes"
        case 1024..<1_048_576:
            return String(format: "%.02f KB", Double(size) / 1024)
        case 1_048_576..<1_073_741_824:
            return String(format: "%.02f MB", Double(size) / 1024 / 1024)
        default:
            return String(format: "%.02f GB", Double(size) / 1024 / 1024 / 1024)
        }
    }

    @objc var fileSizeFromFormat: UInt64 {
        let digits = CharacterSet(charactersIn: "0123456789.").inverted
        let pureNumbers = (self as String).components(separatedBy: digits).joined()
        var fileSize = Double(pureNumbers) ?? 0

        let multipliers: [(String, Double)] = [
            ("g", 1024 * 1024 * 1024),
            ("m", 1024 * 1024),
            ("k", 1024),
        ]
        let lower = lowercased
        for (suffix, factor) in multipliers {
            if lower.contains(suffix) {
                fileSize *= factor
                break
            }
        }
        return UInt64(fileSize)
    }
}
