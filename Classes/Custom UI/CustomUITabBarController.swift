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
    private var miniPlayerConstraints: [NSLayoutConstraint] = []

    /// Previously installed delegate on the observed nav controller, forwarded in delegate callbacks.
    private weak var forwardNavDelegate: UINavigationControllerDelegate?
    /// The nav controller we are currently injected into as UINavigationControllerDelegate.
    private weak var observedNavController: UINavigationController?
    /// KVO token that fires when the user switches tabs, so we re-point the nav delegate.
    private var selectedVCObservation: NSKeyValueObservation?

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

        // Track tab changes so we always observe the selected navigation controller.
        selectedVCObservation = observe(\.selectedViewController, options: [.new]) { [weak self] _, _ in
            self?.updateNavControllerDelegate()
        }
        // Seed on first load after tabs are wired up.
        updateNavControllerDelegate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Reserve space only when the mini player is actually on screen.
        let visible = !tabBar.isHidden && !miniPlayerView.isHidden
        let newInsets = visible ? UIEdgeInsets(top: 0, left: 0, bottom: miniPlayerHeight, right: 0) : .zero
        if additionalSafeAreaInsets != newInsets {
            additionalSafeAreaInsets = newInsets
        }
    }

    // MARK: - Mini Player Setup

    private func setupMiniPlayer() {
        miniPlayerView.openPlayerHandler = { [weak self] in self?.openPlayer() }
        miniPlayerView.visibilityChanged = { [weak self] visible in
            self?.animateMiniPlayerVisibility(visible)
        }
    }

    // MARK: - Mini Player Reparenting

    /// Moves the mini player into `nav`'s view so it participates in navigation transitions.
    private func attachMiniPlayer(to nav: UINavigationController) {
        // Deactivate any previous constraints (including cross-hierarchy ones that
        // removeFromSuperview does not clean up automatically).
        NSLayoutConstraint.deactivate(miniPlayerConstraints)
        miniPlayerConstraints = []

        miniPlayerView.removeFromSuperview()
        nav.view.addSubview(miniPlayerView)

        // Anchor bottom to tabBar.topAnchor rather than nav.view.bottomAnchor.
        // nav.view extends full-screen (behind the tab bar), so nav.view.bottomAnchor
        // is at the screen bottom. A cross-hierarchy constraint to the actual tab bar
        // positions the mini player correctly above it regardless of nav view framing.
        let constraints = [
            miniPlayerView.leadingAnchor.constraint(equalTo: nav.view.leadingAnchor),
            miniPlayerView.trailingAnchor.constraint(equalTo: nav.view.trailingAnchor),
            miniPlayerView.bottomAnchor.constraint(equalTo: tabBar.topAnchor),
            miniPlayerView.heightAnchor.constraint(equalToConstant: miniPlayerHeight),
        ]
        NSLayoutConstraint.activate(constraints)
        miniPlayerConstraints = constraints

        // UIKit's navigation content container is a sibling; bring the mini player to
        // front so it renders above the navigation hierarchy.
        nav.view.bringSubviewToFront(miniPlayerView)

        // If the tab bar is already hidden (e.g. switched to a tab whose top VC hides it),
        // start the mini player in its off-screen position.
        let alreadyHidden = tabBar.isHidden
        miniPlayerView.transform = alreadyHidden
            ? CGAffineTransform(translationX: -nav.view.bounds.width, y: 0)
            : .identity
        miniPlayerView.isUserInteractionEnabled = !alreadyHidden && !miniPlayerView.isHidden
    }

    // MARK: - Song State Visibility

    /// Fades the mini player when a song starts or ends while no navigation transition is in flight.
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

    // MARK: - Nav Controller Delegate Chain

    /// Installs `self` as the UINavigationControllerDelegate for the selected nav controller,
    /// storing any pre-existing delegate so we can forward calls to it.
    private func updateNavControllerDelegate() {
        // Restore the previously observed nav controller's original delegate.
        observedNavController?.delegate = forwardNavDelegate

        guard let nav = selectedViewController as? UINavigationController else {
            NSLayoutConstraint.deactivate(miniPlayerConstraints)
            miniPlayerConstraints = []
            miniPlayerView.removeFromSuperview()
            observedNavController = nil
            forwardNavDelegate = nil
            return
        }

        forwardNavDelegate = nav.delegate
        nav.delegate = self
        observedNavController = nav

        attachMiniPlayer(to: nav)
    }

    // MARK: - Open Player

    @objc func openPlayer() {
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

// MARK: - UINavigationControllerDelegate

extension CustomUITabBarController: UINavigationControllerDelegate {

    func navigationController(_ navigationController: UINavigationController,
                               willShow viewController: UIViewController,
                               animated: Bool) {
        forwardNavDelegate?.navigationController?(navigationController,
                                                   willShow: viewController,
                                                   animated: animated)

        let hasSong = !miniPlayerView.isHidden
        let hidingTabBar = viewController.hidesBottomBarWhenPushed
        let width = navigationController.view.bounds.width

        // Slide the mini player off to the left when the tab bar hides; return it on pop.
        let targetTransform: CGAffineTransform = (hidingTabBar || !hasSong)
            ? CGAffineTransform(translationX: -width, y: 0)
            : .identity

        guard animated, let coordinator = navigationController.transitionCoordinator else {
            miniPlayerView.transform = targetTransform
            miniPlayerView.isUserInteractionEnabled = !hidingTabBar && hasSong
            return
        }

        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.miniPlayerView.transform = targetTransform
        }, completion: { [weak self] ctx in
            guard let self else { return }
            if ctx.isCancelled {
                // Interactive pop cancelled — restore to off-screen (tab bar still hidden).
                self.miniPlayerView.transform = CGAffineTransform(translationX: -width, y: 0)
            } else {
                self.miniPlayerView.transform = targetTransform
                self.miniPlayerView.isUserInteractionEnabled = !hidingTabBar && hasSong
            }
        })
    }

    func navigationController(_ navigationController: UINavigationController,
                               didShow viewController: UIViewController,
                               animated: Bool) {
        forwardNavDelegate?.navigationController?(navigationController,
                                                   didShow: viewController,
                                                   animated: animated)
    }
}
