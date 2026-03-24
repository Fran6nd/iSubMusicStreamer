//
//  NSURL+QueryParameterDictionary.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

extension NSURL {
    @objc(queryParameterDictionary) var queryParameterDictionary: [String: String] {
        guard let components = URLComponents(url: self as URL, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return [:] }
        var dict = [String: String]()
        for item in items {
            dict[item.name] = item.value ?? ""
        }
        return dict
    }
}
