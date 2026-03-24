//
//  SUSChatLoader.swift
//  iSub
//
//  Created by François Navarro on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

@objc(SUSChatLoader) class SUSChatLoader: SUSLoader {
    @objc var chatMessages: [ISMSChatMessage] = []

    override var type: SUSLoaderType { SUSLoaderType_Chat }

    override func createRequest() -> URLRequest {
        return NSMutableURLRequest(susAction: "getChatMessages", parameters: nil)! as URLRequest
    }

    override func processResponse() {
        guard let data = receivedData else {
            informDelegateLoadingFailed(NSError.withISMSCode(Int(ISMSErrorCode_NotXML)))
            return
        }
        let root = RXMLElement(fromXMLData: data)!
        guard root.isValid else {
            informDelegateLoadingFailed(NSError.withISMSCode(Int(ISMSErrorCode_NotXML)))
            return
        }
        if let error = root.child("error"), error.isValid {
            let code = Int(error.attribute("code") ?? "0") ?? 0
            let message = error.attribute("message") ?? ""
            informDelegateLoadingFailed(NSError.withISMSCode(code, message: message))
            return
        }
        var messages: [ISMSChatMessage] = []
        root.iterate("chatMessages.chatMessage") { e in
            messages.append(ISMSChatMessage(rXMLElement: e!))
        }
        chatMessages = messages
        informDelegateLoadingFinished()
    }
}
