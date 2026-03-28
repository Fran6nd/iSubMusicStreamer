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
        // Keep the mini player flush above the tab bar.
        // tabBar.frame.height is valid only after layout, so we update the
        // constant here rather than using tabBar.topAnchor (which UIKit may
        // reset to 0 when the bar is hidden).
        miniPlayerBottomConstraint.constant = -tabBar.frame.height
    }

    // MARK: - Tab Bar Appearance

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

        // Anchor the mini player to view.bottomAnchor and update the constant
        // in viewDidLayoutSubviews once UIKit has placed the tab bar.
        // Using tabBar.topAnchor directly fails because UIKit resets the tab bar
        // frame to y=0 when hidden, which would place the mini player off-screen.
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
        applyMiniPlayerInset(visible: initialVisible)
    }

    // MARK: - Mini Player Inset

    private func applyMiniPlayerInset(visible: Bool) {
        // Setting additionalSafeAreaInsets on self (UITabBarController) does NOT propagate to
        // grandchildren when those children use edgesForExtendedLayout = [] — their frames stop
        // at tabBar.top so they never reach the inset region UIKit would otherwise adjust.
        // The reliable fix is to stamp the inset directly on every currently-visible VC.
        let inset = visible
            ? UIEdgeInsets(top: 0, left: 0, bottom: miniPlayerHeight, right: 0)
            : UIEdgeInsets.zero
        let navControllers = (viewControllers ?? []).compactMap { $0 as? UINavigationController }
            + [moreNavigationController]
        for nav in navControllers {
            nav.topViewController?.additionalSafeAreaInsets = inset
        }
    }

    // MARK: - Song State Visibility

    /// Slides the mini player in from the left (matching nav push direction) when a song
    /// starts, and slides it back out when playback ends.
    private func animateMiniPlayerVisibility(_ visible: Bool) {
        guard !tabBar.isHidden else {
            miniPlayerView.isHidden = !visible
            miniPlayerView.isUserInteractionEnabled = false
            return
        }
        if visible {
            miniPlayerView.isHidden = false
            miniPlayerView.alpha = 0
        }
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
            self.miniPlayerView.alpha = visible ? 1 : 0
            self.applyMiniPlayerInset(visible: visible)
        } completion: { _ in
            if !visible { self.miniPlayerView.isHidden = true }
        }
        miniPlayerView.isUserInteractionEnabled = visible
    }

    // MARK: - Nav Controller Delegate Chain

    private func updateNavControllerDelegate() {
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
        // Only the full-screen player hides the tab bar and mini player.
        let hidingTabBar = viewController is PlayerViewController

        // Stamp the mini player inset directly on the incoming VC.
        // (applyMiniPlayerInset handles existing VCs; this covers newly-pushed ones.)
        viewController.additionalSafeAreaInsets = (hasSong && !hidingTabBar)
            ? UIEdgeInsets(top: 0, left: 0, bottom: miniPlayerHeight, right: 0)
            : .zero
        let width = navigationController.view.bounds.width

        let playerTarget: CGAffineTransform = (hidingTabBar || !hasSong)
            ? CGAffineTransform(translationX: -width, y: 0)
            : .identity
        let barTarget: CGAffineTransform = hidingTabBar
            ? CGAffineTransform(translationX: -width, y: 0)
            : .identity

        // Pre-empt UIKit's default vertical tab-bar slide by holding it visible
        // and driving a horizontal transform ourselves.
        tabBar.layer.removeAllAnimations()
        if !hidingTabBar && tabBar.isHidden {
            tabBar.transform = CGAffineTransform(translationX: -width, y: 0)
        }
        tabBar.isHidden = false

        guard animated, let coordinator = navigationController.transitionCoordinator else {
            miniPlayerView.transform = playerTarget
            tabBar.transform = .identity
            tabBar.isHidden = hidingTabBar
            applyMiniPlayerInset(visible: !hidingTabBar && hasSong)
            miniPlayerView.isUserInteractionEnabled = !hidingTabBar && hasSong
            return
        }

        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.miniPlayerView.transform = playerTarget
            self?.tabBar.transform = barTarget
            self?.applyMiniPlayerInset(visible: !hidingTabBar && hasSong)
        }, completion: { [weak self] ctx in
            guard let self else { return }
            if ctx.isCancelled {
                // The transition was cancelled — restore state for the VC we stayed on.
                let stayingIsPlayer = navigationController.topViewController is PlayerViewController
                let showMini = hasSong && !stayingIsPlayer
                self.miniPlayerView.transform = showMini ? .identity : CGAffineTransform(translationX: -width, y: 0)
                self.miniPlayerView.isUserInteractionEnabled = showMini
                self.tabBar.isHidden = stayingIsPlayer
                self.tabBar.transform = .identity
                self.applyMiniPlayerInset(visible: showMini)
            } else {
                self.miniPlayerView.transform = playerTarget
                self.miniPlayerView.isUserInteractionEnabled = !hidingTabBar && hasSong
                self.tabBar.isHidden = hidingTabBar
                self.tabBar.transform = .identity
                self.applyMiniPlayerInset(visible: !hidingTabBar && hasSong)
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
