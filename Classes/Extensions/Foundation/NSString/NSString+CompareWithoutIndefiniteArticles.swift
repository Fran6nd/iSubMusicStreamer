//
//  NSString+CompareWithoutIndefiniteArticles.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

extension NSString {
    @objc static func indefiniteArticles() -> [String] {
        ["the", "los", "las", "les", "el", "la", "le"]
    }

    @objc(stringWithoutIndefiniteArticle) var stringWithoutIndefiniteArticle: String {
        for article in NSString.indefiniteArticles() {
            if lowercased.hasPrefix("\(article) ") && length > article.count + 1 {
                let afterArticle = substring(from: article.count + 1)
                let articlePart  = substring(to: article.count)
                return "\(afterArticle), \(articlePart)"
            }
        }
        return self as String
    }

    @objc(compareWithoutIndefiniteArticles:)
    func compareWithoutIndefiniteArticles(_ other: String) -> ComparisonResult {
        stringWithoutIndefiniteArticle.compare(
            (other as NSString).stringWithoutIndefiniteArticle
        )
    }

    @objc(caseInsensitiveCompareWithoutIndefiniteArticles:)
    func caseInsensitiveCompareWithoutIndefiniteArticles(_ other: String) -> ComparisonResult {
        stringWithoutIndefiniteArticle.caseInsensitiveCompare(
            (other as NSString).stringWithoutIndefiniteArticle
        )
    }
}
