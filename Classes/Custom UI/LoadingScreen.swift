//
//  LoadingScreen.swift
//  iSub
//
//  Created by François ND on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(LoadingScreen) final class LoadingScreen: UIViewController {

    @IBOutlet @objc var inputBlocker: UIButton!
    @IBOutlet @objc var loadingScreenRectangle: UIImageView!
    @IBOutlet @objc var loadingLabel: UILabel!
    @IBOutlet @objc var loadingTitle1: UILabel!
    @IBOutlet @objc var loadingMessage1: UILabel!
    @IBOutlet @objc var loadingTitle2: UILabel!
    @IBOutlet @objc var loadingMessage2: UILabel!
    @IBOutlet @objc var activityIndicator: UIActivityIndicatorView!

    @objc(initOnView:withMessage:blockInput:mainWindow:)
    init(onView superView: UIView, message: [String]?, blockInput: Bool, mainWindow: Bool) {
        super.init(nibName: "LoadingScreen", bundle: nil)

        superView.addSubview(view)
        view.center = CGPoint(x: superView.bounds.size.width / 2, y: superView.bounds.size.height / 2)

        if mainWindow {
            let shift: CGFloat = -40
            loadingScreenRectangle.frame.origin.y += shift
            loadingLabel.frame.origin.y += shift
            loadingTitle1.frame.origin.y += shift
            loadingMessage1.frame.origin.y += shift
            loadingTitle2.frame.origin.y += shift
            loadingMessage2.frame.origin.y += shift
            activityIndicator.frame.origin.y += shift
        }

        setAllMessages(message)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @IBAction private func inputBlockerAction(_ sender: Any) {
        // intentionally empty — blocks touches while loading
    }

    @objc func setAllMessagesText(_ messages: [String]?) {
        setAllMessages(messages)
    }

    @objc func setMessage1Text(_ message: String) {
        loadingMessage1.text = message
    }

    @objc func setMessage2Text(_ message: String) {
        loadingMessage2.text = message
    }

    @objc func hide() {
        view.removeFromSuperview()
    }

    // MARK: - Private

    private func setAllMessages(_ messages: [String]?) {
        if let msgs = messages, msgs.count == 4 {
            loadingTitle1.text   = msgs[0]
            loadingMessage1.text = msgs[1]
            loadingTitle2.text   = msgs[2]
            loadingMessage2.text = msgs[3]
        } else {
            loadingTitle1.text   = ""
            loadingMessage1.text = ""
            loadingTitle2.text   = ""
            loadingMessage2.text = ""
        }
    }
}
