//
//  NSError+ISMSError.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

extension NSError {

    @objc(descriptionFromISMSCode:)
    static func description(fromISMSCode code: UInt) -> String? {
        switch code {
        case UInt(ISMSErrorCode_NotASubsonicServer):      return ISMSErrorDesc_NotASubsonicServer
        case UInt(ISMSErrorCode_NotXML):                  return ISMSErrorDesc_NotXML
        case UInt(ISMSErrorCode_CouldNotCreateConnection): return ISMSErrorDesc_CouldNotCreateConnection
        default: return nil
        }
    }

    @objc(errorWithISMSCode:)
    static func withISMSCode(_ code: Int) -> NSError {
        var userInfo: [String: Any] = [:]
        if let desc = description(fromISMSCode: UInt(code)) {
            userInfo[NSLocalizedDescriptionKey] = desc
        }
        return NSError(domain: ISMSErrorDomain, code: code, userInfo: userInfo.isEmpty ? nil : userInfo)
    }

    @objc(errorWithISMSCode:extraAttributes:)
    static func withISMSCode(_ code: Int, extraAttributes attributes: [AnyHashable: Any]) -> NSError {
        var dict = attributes as? [String: Any] ?? [:]
        dict[NSLocalizedDescriptionKey] = description(fromISMSCode: UInt(code))
        return NSError(domain: ISMSErrorDomain, code: code, userInfo: dict)
    }

    @objc(errorWithISMSCode:message:)
    static func withISMSCode(_ code: Int, message: String) -> NSError {
        NSError(domain: SUSErrorDomain, code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
