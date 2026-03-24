//
//  SUSScrobbleLoader.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

@objc(SUSScrobbleLoader)
class SUSScrobbleLoader: SUSLoader {

    @objc var aSong: Song?
    @objc var isSubmission: Bool = false
    @objc var lfmAuthUrl: String?

    override var type: SUSLoaderType { SUSLoaderType_Scrobble }

    override func createRequest() -> URLRequest {
        let isSubmissionString = "\(isSubmission ? 1 : 0)"
        let parameters: [String: Any] = [
            "id":         aSong?.songId ?? NSNull(),
            "submission": isSubmissionString
        ]
        return NSMutableURLRequest(susAction: "scrobble", parameters: parameters)! as URLRequest
    }

    override func processResponse() {
        informDelegateLoadingFinished()
    }
}
