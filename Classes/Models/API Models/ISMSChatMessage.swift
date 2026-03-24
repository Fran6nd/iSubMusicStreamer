//
//  ISMSChatMessage.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

@objc(ISMSChatMessage)
final class ISMSChatMessage: NSObject, NSCopying {
    @objc var timestamp: Int = Int.min
    @objc var user: String = ""
    @objc var message: String = ""

    override init() {
        super.init()
    }

    @objc init(rXMLElement element: RXMLElement) {
        super.init()
        if let time = element.attribute("time") as String? {
            timestamp = Int(String(time.prefix(10))) ?? Int.min
        }
        user = (element.attribute("username") as NSString?)?.cleanString ?? ""
        message = (element.attribute("message") as NSString?)?.cleanString ?? ""
    }

    func copy(with zone: NSZone? = nil) -> Any {
        let copy = ISMSChatMessage()
        copy.timestamp = timestamp
        copy.user = user
        copy.message = message
        return copy
    }
}
