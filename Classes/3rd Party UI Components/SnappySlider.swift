//
//  SnappySlider.swift
//  iSub
//
//  Created by François Nadeau on 2026-03-26.
//  Copyright © 2026 iSub. All rights reserved.
//
//  Swift port of SnappySlider by Aaron Brethorst (2011).
//  Allows full slider range but snaps the thumb to detent values
//  when the drag position is within `snapDistance` of one.
//

import UIKit

@objc(SnappySlider) final class SnappySlider: UISlider {

    /// Sorted list of values the slider snaps to.
    @objc var detents: [NSNumber] = [] {
        didSet {
            sortedDetents = detents.map { CGFloat($0.floatValue) }.sorted()
        }
    }

    /// How close (in slider-value units) the thumb must be to a detent to snap.
    @objc var snapDistance: CGFloat = 0

    // MARK: - Private

    private var sortedDetents: [CGFloat] = []

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Snapping

    override func setValue(_ value: Float, animated: Bool) {
        guard !sortedDetents.isEmpty else {
            super.setValue(value, animated: animated)
            return
        }

        let candidate = sortedDetents.min(by: { abs($0 - CGFloat(value)) < abs($1 - CGFloat(value)) })!
        let distance = abs(candidate - CGFloat(value))

        if distance <= snapDistance {
            super.setValue(Float(candidate), animated: animated)
        } else {
            super.setValue(value, animated: animated)
        }
    }
}
