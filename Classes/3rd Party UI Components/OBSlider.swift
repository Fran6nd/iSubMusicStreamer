//
//  OBSlider.swift
//  iSub
//
//  Created by François Nadeau on 2026-03-26.
//  Copyright © 2026 iSub. All rights reserved.
//
//  Swift port of OBSlider by Ole Begemann (2011).
//  Adds variable scrubbing speed: sliding finger vertically away from the
//  track slows the scrubbing rate, mimicking the iOS music app behavior.
//

import UIKit

@objc(OBSlider) final class OBSlider: UISlider {

    // MARK: - Public

    /// Current scrubbing speed (read-only; changes as the user drags).
    @objc private(set) var scrubbingSpeed: Float = 1.0

    /// Speed multipliers applied at each vertical offset tier (default: 1.0, 0.5, 0.25, 0.1).
    @objc var scrubbingSpeeds: [Float] = [1.0, 0.5, 0.25, 0.1]

    /// Y-offset thresholds (in points) at which each speed tier activates
    /// (default: 0, 50, 100, 150).
    @objc var scrubbingSpeedChangePositions: [CGFloat] = [0, 50, 100, 150]

    // MARK: - Private

    private var beganTrackingLocation: CGPoint = .zero
    private var realPositionValue: Float = 0

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        scrubbingSpeed = scrubbingSpeeds[0]
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        scrubbingSpeed = scrubbingSpeeds[0]
    }

    // MARK: - Hit area expansion

    private static let hitExtensionPhone: CGFloat = -10
    private static let hitExtensionPad: CGFloat = -30

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let inset = UIDevice.current.userInterfaceIdiom == .pad
            ? OBSlider.hitExtensionPad
            : OBSlider.hitExtensionPhone
        let expanded = bounds.insetBy(dx: 0, dy: inset)
        return expanded.contains(point)
    }

    // MARK: - Touch tracking

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let began = super.beginTracking(touch, with: event)
        if began {
            beganTrackingLocation = touch.location(in: self)
            realPositionValue = value
        }
        return began
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard isTracking else { return false }

        let previous = touch.previousLocation(in: self)
        let current  = touch.location(in: self)
        let dx = current.x - previous.x

        let verticalOffset = abs(current.y - beganTrackingLocation.y)
        let speedIndex = indexOfLowerSpeed(for: verticalOffset)
        scrubbingSpeed = scrubbingSpeeds[speedIndex]

        let trackWidth = trackRect(forBounds: bounds).width
        let range = maximumValue - minimumValue
        realPositionValue += range * Float(dx / trackWidth)

        let returningToSlider = (beganTrackingLocation.y < current.y && current.y < previous.y)
                             || (beganTrackingLocation.y > current.y && current.y > previous.y)

        let baseDelta = scrubbingSpeed * range * Float(dx / trackWidth)
        if returningToSlider {
            let verticalDist = Float(abs(current.y - beganTrackingLocation.y))
            let snap = (realPositionValue - value) / (1 + verticalDist)
            value += baseDelta + snap
        } else {
            value += baseDelta
        }

        if isContinuous {
            sendActions(for: .valueChanged)
        }
        return isTracking
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        if isTracking {
            scrubbingSpeed = scrubbingSpeeds[0]
            sendActions(for: .valueChanged)
        }
    }

    // MARK: - Helpers

    /// Returns the index of the speed tier whose threshold is just above `offset`,
    /// clamped to the last valid index.
    private func indexOfLowerSpeed(for offset: CGFloat) -> Int {
        for (i, threshold) in scrubbingSpeedChangePositions.enumerated() {
            if offset < threshold { return max(0, i - 1) }
        }
        return scrubbingSpeeds.count - 1
    }
}
