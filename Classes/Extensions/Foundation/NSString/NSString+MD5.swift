//
//  NSString+MD5.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import CryptoKit
import Foundation

extension NSString {
    @objc(md5:) static func md5(_ str: String) -> String {
        guard !str.isEmpty else { return "" }
        let digest = Insecure.MD5.hash(data: Data(str.utf8))
        return digest.map { String(format: "%02X", $0) }.joined()
    }

    @objc var md5: String { NSString.md5(self as String) }
}
