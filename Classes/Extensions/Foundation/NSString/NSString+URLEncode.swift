//
//  NSString+URLEncode.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

extension NSString {
    @objc(URLQueryEncodeString:) static func urlQueryEncodeString(_ string: String) -> String? {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }

    @objc(URLQueryEncodeString) var urlQueryEncodeString: String? {
        NSString.urlQueryEncodeString(self as String)
    }
}
