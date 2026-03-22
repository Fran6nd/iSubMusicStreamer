//
//  HapticEngine.swift
//  iSub
//
//  A centralized haptic feedback engine that wraps UIFeedbackGenerator instances
//  and provides semantic feedback methods aligned with the app's interaction model.
//  All methods respect the system-level haptics setting automatically.
//

import UIKit

/// Centralized haptic feedback engine. Use the shared instance to produce feedback
/// and call `prepare()` in `viewWillAppear` of any screen that fires haptics to
/// minimize latency on first use.
@objc final class HapticEngine: NSObject {

    // MARK: - Shared Instance

    @objc static let shared = HapticEngine()

    // MARK: - Private Generators

    private let primaryImpact = UIImpactFeedbackGenerator(style: .medium)
    private let lightImpact   = UIImpactFeedbackGenerator(style: .light)
    private let selection     = UISelectionFeedbackGenerator()
    private let notification  = UINotificationFeedbackGenerator()

    private override init() { super.init() }

    // MARK: - Preparation

    /// Pre-warms all generators. Call in `viewWillAppear(_:)` on screens that
    /// produce haptic feedback to reduce latency on the first triggered event.
    @objc func prepare() {
        primaryImpact.prepare()
        lightImpact.prepare()
        selection.prepare()
    }

    // MARK: - Semantic Feedback Methods

    /// Primary transport action: play, pause, previous track, next track.
    @objc func playbackAction() {
        primaryImpact.impactOccurred()
    }

    /// Mode toggle: shuffle on/off, repeat cycle, equalizer on/off.
    @objc func modeToggle() {
        selection.selectionChanged()
    }

    /// Secondary action: quick-skip, bookmark, add to queue.
    @objc func secondaryAction() {
        lightImpact.impactOccurred()
    }

    /// Successful completion of an operation (bookmark saved, playlist saved, etc.).
    @objc func success() {
        notification.notificationOccurred(.success)
    }

    /// An error occurred during an operation.
    @objc func error() {
        notification.notificationOccurred(.error)
    }
}
