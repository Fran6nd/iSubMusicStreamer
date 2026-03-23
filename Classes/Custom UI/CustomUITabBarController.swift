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
        configureTabBarAppearance()

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
        // Only keep the mini player flush above the tab bar.
        // Inset management is owned exclusively by animateMiniPlayerVisibility
        // and the nav-transition coordinator to avoid snapping in-flight animations.
        miniPlayerBottomConstraint.constant = -tabBar.frame.height
    }

    // MARK: - Tab Bar Appearance

    /// Configures a consistent opaque black tab bar appearance using modern iOS APIs.
    /// This replaces the legacy barTintColor / translucent approach and also prevents
    /// the bar from going transparent when a scroll view's edge is visible behind it.
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.shadowColor = nil

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = .white
        tabBar.unselectedItemTintColor = UIColor.white.withAlphaComponent(0.4)
    }

    // MARK: - Mini Player Setup

    private func setupMiniPlayer() {
        miniPlayerView.openPlayerHandler = { [weak self] in self?.openPlayer() }
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

        // Sync initial state without animation. MiniPlayerView.refresh() ran
        // during init (before the callback was wired), so isHidden already
        // reflects whether a song is queued. Mirror that into insets/alpha here.
        let initialVisible = !miniPlayerView.isHidden
        miniPlayerView.alpha = initialVisible ? 1 : 0
        miniPlayerView.isUserInteractionEnabled = initialVisible
        additionalSafeAreaInsets = initialVisible
            ? UIEdgeInsets(top: 0, left: 0, bottom: miniPlayerHeight, right: 0)
            : .zero
    }

    // MARK: - Song State Visibility

    /// Fades the mini player in or out when a song starts or stops.
    /// This is the single owner of `isHidden`, `alpha`, and `additionalSafeAreaInsets`
    /// for song-state transitions, so it doesn't conflict with layout passes.
    private func animateMiniPlayerVisibility(_ visible: Bool) {
        // When the tab bar is hidden (deep nav push) there is nothing to animate;
        // just track the logical state so we can restore correctly on pop.
        guard !tabBar.isHidden else {
            miniPlayerView.isHidden = !visible
            miniPlayerView.isUserInteractionEnabled = false
            return
        }
        if visible {
            // Reveal before the animation so alpha fades in from nothing.
            miniPlayerView.isHidden = false
            miniPlayerView.alpha = 0
        }
        let targetInsets = visible
            ? UIEdgeInsets(top: 0, left: 0, bottom: miniPlayerHeight, right: 0)
            : .zero
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
            self.miniPlayerView.alpha = visible ? 1 : 0
            self.additionalSafeAreaInsets = targetInsets
        } completion: { _ in
            // Collapse after the fade so layout reclaims the space cleanly.
            if !visible { self.miniPlayerView.isHidden = true }
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
            observedNavController = nil
            forwardNavDelegate = nil
            return
        }

        forwardNavDelegate = nav.delegate
        nav.delegate = self
        observedNavController = nav
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

        // Slide the mini player left when the tab bar hides; return it on pop.
        let targetTransform: CGAffineTransform = (hidingTabBar || !hasSong)
            ? CGAffineTransform(translationX: -width, y: 0)
            : .identity
        // Insets must match tab bar visibility so pushed VCs don't gain phantom space.
        let targetInsets = (!hidingTabBar && hasSong)
            ? UIEdgeInsets(top: 0, left: 0, bottom: miniPlayerHeight, right: 0)
            : .zero

        guard animated, let coordinator = navigationController.transitionCoordinator else {
            miniPlayerView.transform = targetTransform
            additionalSafeAreaInsets = targetInsets
            miniPlayerView.isUserInteractionEnabled = !hidingTabBar && hasSong
            return
        }

        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.miniPlayerView.transform = targetTransform
            self?.additionalSafeAreaInsets = targetInsets
        }, completion: { [weak self] ctx in
            guard let self else { return }
            if ctx.isCancelled {
                // Interactive pop cancelled — restore to off-screen (tab bar still hidden).
                self.miniPlayerView.transform = CGAffineTransform(translationX: -width, y: 0)
                self.additionalSafeAreaInsets = .zero
            } else {
                self.miniPlayerView.transform = targetTransform
                self.additionalSafeAreaInsets = targetInsets
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
