//
//  BassEffectValue.swift
//  iSub
//
//  Created by François Navarro on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

@objc(BassEffectValue) class BassEffectValue: NSObject {
    @objc var type: BassEffectType = .parametricEQ
    @objc var percentX: CGFloat = 0
    @objc var percentY: CGFloat = 0
    @objc var isDefault: Bool = true
}
