//
//  CustomUITabBarController.swift
//  iSub
//
//  Created by Francois ND on 3/23/26.
//  Copyright © 2026 Francois ND. All rights reserved.
//

import UIKit

private let miniPlayerHeight: CGFloat = 64

@objc(CustomUITabBarController)
final class CustomUITabBarController: UITabBarController {

    // MARK: - Properties

    private let miniPlayerView = MiniPlayerView()
    private var miniPlayerBottomConstraint: NSLayoutConstraint!

    /// Swift KVO token — retained for observation lifetime, auto-invalidated on release.
    private var tabBarObservation: NSKeyValueObservation?

    // MARK: - More Tab Customization

    @objc static func customizeMoreTabTableView(_ tabBarController: UITabBarController) {
        tabBarController.moreNavigationController.navigationBar.barStyle = .black
        let moreController = tabBarController.moreNavigationController.topViewController
        if let moreTableView = moreController?.view as? UITableView {
            moreTableView.backgroundColor = UIColor(named: "isubBackgroundColor")
            moreTableView.rowHeight = Defines.rowHeight
            moreTableView.separatorStyle = .none
        }
    }

    // MARK: - Rotation

    override var shouldAutorotate: Bool {
        if Settings.shared().isRotationLockEnabled && UIDevice.current.orientation != .portrait {
            return false
        }
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        ViewObjects.shared().orderMainTabBarController()
        Self.customizeMoreTabTableView(self)

        setupMiniPlayer()

        // Swift KVO — type-safe, no context pointer, auto-invalidated when token is released.
        tabBarObservation = tabBar.observe(\.isHidden, options: [.new]) { [weak self] _, change in
            guard let self, let hiding = change.newValue else { return }
            self.handleTabBarVisibilityChange(hiding: hiding)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Keep mini player flush above the tab bar by tracking its current frame.
        miniPlayerBottomConstraint.constant = -tabBar.frame.height

        // Reserve space only when the mini player is actually on screen.
        let visible = !tabBar.isHidden && !miniPlayerView.isHidden
        let newInsets = visible ? UIEdgeInsets(top: 0, left: 0, bottom: miniPlayerHeight, right: 0) : .zero
        if additionalSafeAreaInsets != newInsets {
            additionalSafeAreaInsets = newInsets
        }
    }

    // MARK: - Mini Player Setup

    private func setupMiniPlayer() {
        miniPlayerView.openPlayerHandler = { [weak self] in
            self?.openPlayer()
        }

        miniPlayerView.visibilityChanged = { [weak self] visible in
            self?.animateMiniPlayerVisibility(visible)
        }

        view.addSubview(miniPlayerView)

        miniPlayerBottomConstraint = miniPlayerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            miniPlayerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            miniPlayerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            miniPlayerBottomConstraint,
            miniPlayerView.heightAnchor.constraint(equalToConstant: miniPlayerHeight),
        ])
    }

    // MARK: - Song State Visibility

    /// Animates the mini player and its safe-area inset when a song starts or ends
    /// while the tab bar is already visible (no navigation transition in flight).
    private func animateMiniPlayerVisibility(_ visible: Bool) {
        guard !tabBar.isHidden else { return }
        let targetAlpha: CGFloat = visible ? 1 : 0
        let targetInsets = visible
            ? UIEdgeInsets(top: 0, left: 0, bottom: miniPlayerHeight, right: 0)
            : .zero
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
            self.miniPlayerView.alpha = targetAlpha
            self.additionalSafeAreaInsets = targetInsets
        }
        miniPlayerView.isUserInteractionEnabled = visible
    }

    // MARK: - Tab Bar Visibility

    private func handleTabBarVisibilityChange(hiding: Bool) {
        let hasSong = !miniPlayerView.isHidden
        let targetAlpha: CGFloat = (hiding || !hasSong) ? 0 : 1

        // The mini player is bottom chrome — animate with a crossfade, matching the tab bar's
        // own fade behaviour rather than sliding horizontally with the navigation content.
        let nav = selectedViewController as? UINavigationController
        let coordinator = nav?.transitionCoordinator

        if let coordinator {
            if !hiding {
                // Prepare starting state for pop-back: invisible, no transform.
                miniPlayerView.alpha = 0
            }
            coordinator.animate(alongsideTransition: { [weak self] _ in
                self?.miniPlayerView.alpha = targetAlpha
            }, completion: { [weak self] ctx in
                guard let self else { return }
                if ctx.isCancelled {
                    let restore = !self.tabBar.isHidden && hasSong
                    self.miniPlayerView.alpha = restore ? 1 : 0
                } else {
                    self.miniPlayerView.isUserInteractionEnabled = !hiding && hasSong
                }
            })
        } else {
            miniPlayerView.alpha = targetAlpha
            miniPlayerView.isUserInteractionEnabled = !hiding && hasSong
        }
    }

    // MARK: - Open Player

    @objc func openPlayer() {
        // Avoid stacking duplicate player sheets.
        if let existing = presentedViewController as? UINavigationController,
           existing.topViewController is PlayerViewController { return }

        let player = PlayerViewController()
        let nav = UINavigationController(rootViewController: player)
        if #available(iOS 15, *) {
            nav.modalPresentationStyle = .pageSheet
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
        } else {
            nav.modalPresentationStyle = .fullScreen
        }
        if presentedViewController != nil {
            dismiss(animated: false) { [weak self] in
                self?.present(nav, animated: true)
            }
        } else {
            present(nav, animated: true)
        }
    }
}
