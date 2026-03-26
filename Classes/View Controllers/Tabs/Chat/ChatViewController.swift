//
//  ChatViewController.swift
//  iSub
//
//  Created by François Ganot on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(ChatViewController) final class ChatViewController: UITableViewController {

    private var dataModel: SUSChatDAO!
    private let headerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 82))
    private let textInput = CustomUITextView(frame: CGRect(x: 5, y: 5, width: 240, height: 72))
    private var noChatMessagesScreen: UIImageView?

    // MARK: - Rotation

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self, let screen = self.noChatMessagesScreen, !UIDevice.isPad() else { return }
            if UIApplication.orientation().isPortrait {
                screen.transform = CGAffineTransform(translationX: 0, y: -160)
            } else {
                screen.transform = CGAffineTransform(translationX: 0, y: 42)
            }
        })
        super.viewWillTransition(to: size, with: coordinator)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Chat"

        headerView.autoresizingMask = .flexibleWidth
        headerView.backgroundColor = .lightGray

        textInput.autoresizingMask = .flexibleWidth
        textInput.font = .systemFont(ofSize: 16)
        headerView.addSubview(textInput)

        let sendButton = UIButton(type: .custom)
        sendButton.frame = CGRect(x: 252, y: 11, width: 60, height: 60)
        sendButton.autoresizingMask = .flexibleLeftMargin
        sendButton.setImage(UIImage(named: "comment-write"), for: .normal)
        sendButton.setImage(UIImage(named: "comment-write-pressed"), for: .highlighted)
        sendButton.addTarget(self, action: #selector(sendButtonAction), for: .touchUpInside)
        headerView.addSubview(sendButton)

        tableView.tableHeaderView = headerView

        refreshControl = RefreshControl { [weak self] in
            ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
            self?.dataModel.startLoad()
            ViewObjects.shared().showAlbumLoadingScreen(AppDelegate.shared().window, sender: self)
        }

        dataModel = SUSChatDAO(delegate: self)

        NotificationCenter.addObserverOnMainThread(self, selector: #selector(addURLRefBackButton), name: UIApplication.didBecomeActiveNotification.rawValue)
    }

    @objc private func addURLRefBackButton() {
        if AppDelegate.shared().referringAppUrl != nil && AppDelegate.shared().mainTabBarController.selectedIndex != 4 {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: AppDelegate.shared(), action: #selector(AppDelegate.backToReferringApp))
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        addURLRefBackButton()

        navigationItem.rightBarButtonItem = nil
        if Music.shared().showPlayerIcon {
            let image = UIImage(systemName: Defines.musicNoteImageSystemName)
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(nowPlayingAction(_:)))
        }

        dataModel.startLoad()
        ViewObjects.shared().showAlbumLoadingScreen(AppDelegate.shared().window, sender: self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        noChatMessagesScreen?.removeFromSuperview()
        noChatMessagesScreen = nil
    }

    @objc func cancelLoad() {
        dataModel.cancelLoad()
        ViewObjects.shared().hideLoadingScreen()
    }

    deinit {
        dataModel?.delegate = nil
    }

    // MARK: - Actions

    @IBAction private func nowPlayingAction(_ sender: Any) {
        let playerVC = PlayerViewController()
        playerVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(playerVC, animated: true)
    }

    @objc private func sendButtonAction() {
        guard textInput.text.count > 0 else { return }
        textInput.resignFirstResponder()

        navigationItem.rightBarButtonItem = Music.shared().showPlayerIcon
            ? UIBarButtonItem(image: UIImage(systemName: Defines.musicNoteImageSystemName), style: .plain, target: self, action: #selector(nowPlayingAction(_:)))
            : nil

        ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: "Sending")
        dataModel.sendChatMessage(textInput.text)
        textInput.text = ""
        textInput.resignFirstResponder()
    }

    // MARK: - Helpers

    private func formatDate(_ unixtime: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(unixtime))
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = .current
        return formatter.string(from: date)
    }

    private func showNoChatMessagesScreen() {
        guard noChatMessagesScreen == nil else { return }

        let screen = UIImageView()
        screen.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        screen.frame = CGRect(x: 40, y: 100, width: 240, height: 180)
        screen.center = CGPoint(x: view.bounds.width / 2, y: view.bounds.height / 2)
        screen.image = UIImage(named: "loading-screen-image")
        screen.alpha = 0.80

        let label = UILabel()
        label.backgroundColor = .clear
        label.textColor = .white
        label.font = .boldSystemFont(ofSize: 30)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "No Chat Messages\non the\nServer"
        label.frame = CGRect(x: 15, y: 15, width: 210, height: 150)
        screen.addSubview(label)

        if !UIDevice.isPad() && UIApplication.orientation().isLandscape {
            let scale = CGAffineTransform(scaleX: 0.75, y: 0.75)
            let translate = CGAffineTransform(translationX: 0, y: 42)
            screen.transform = scale.concatenating(translate)
        }

        view.addSubview(screen)
        noChatMessagesScreen = screen
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        dataModel.chatMessages?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let message = (dataModel.chatMessages?[indexPath.row] as? ISMSChatMessage)?.message else { return 60 }
        let size = (message as NSString).boundingRect(
            with: CGSize(width: 310, height: CGFloat.greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: [.font: UIFont.systemFont(ofSize: 20)],
            context: nil
        ).size
        return max(size.height, 40) + 20
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "ChatCell"
        let cell: ChatUITableViewCell
        if let dequeued = tableView.dequeueReusableCell(withIdentifier: identifier) as? ChatUITableViewCell {
            cell = dequeued
        } else {
            cell = ChatUITableViewCell(style: .default, reuseIdentifier: identifier)
            cell.selectionStyle = .none
        }
        if let msg = dataModel.chatMessages?[indexPath.row] as? ISMSChatMessage {
            cell.userNameLabel.text = "\(msg.user) - \(formatDate(msg.timestamp))"
            cell.messageLabel.text = msg.message
        }
        return cell
    }
}

// MARK: - SUSLoaderDelegate

extension ChatViewController: SUSLoaderDelegate {
    @objc func loadingFinished(_ loader: SUSLoader!) {
        ViewObjects.shared().hideLoadingScreen()
        tableView.reloadData()
        refreshControl?.endRefreshing()
    }

    @objc func loadingFailed(_ loader: SUSLoader!, withError error: Error!) {
        ViewObjects.shared().hideLoadingScreen()
        tableView.reloadData()
        refreshControl?.endRefreshing()
        if (error as NSError).code == ISMSErrorCode_CouldNotSendChatMessage {
            textInput.text = (error as NSError).userInfo["message"] as? String ?? ""
        }
    }
}
