//
//  PlayingViewController.swift
//  iSub
//
//  Created by François Ganot on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(PlayingViewController) final class PlayingViewController: UITableViewController {

    private var dataModel: SUSNowPlayingDAO!
    private var nothingPlayingScreen: UIImageView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Now Playing"
        dataModel = SUSNowPlayingDAO(delegate: self)

        refreshControl = RefreshControl { [weak self] in
            ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
            self?.dataModel.startLoad()
        }

        tableView.rowHeight = Defines.tallRowHeight
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)

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

        ViewObjects.shared().showAlbumLoadingScreen(AppDelegate.shared().window, sender: self)
        dataModel.startLoad()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        nothingPlayingScreen?.removeFromSuperview()
        nothingPlayingScreen = nil
    }

    @objc func cancelLoad() {
        dataModel.cancelLoad()
        ViewObjects.shared().hideLoadingScreen()
        refreshControl?.endRefreshing()
    }

    // MARK: - Actions

    @IBAction private func nowPlayingAction(_ sender: Any) {
        let playerVC = PlayerViewController()
        playerVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(playerVC, animated: true)
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Int(dataModel.count)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        cell.hideHeaderLabel = false
        cell.hideNumberLabel = true
        let row = UInt(indexPath.row)
        let playTime = dataModel.playTime(for: row) ?? ""
        let username = dataModel.username(for: row) ?? ""
        let playerName = dataModel.playerName(for: row)
        if let playerName = playerName {
            cell.headerText = "\(username) @ \(playerName) - \(playTime)"
        } else {
            cell.headerText = "\(username) - \(playTime)"
        }
        cell.update(model: dataModel.song(for: row))
        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        Defines.tallRowHeight
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        dataModel.playSong(at: UInt(indexPath.row))
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        SwipeAction.downloadAndQueueConfig(model: dataModel.song(for: UInt(indexPath.row)))
    }
}

// MARK: - SUSLoaderDelegate

extension PlayingViewController: SUSLoaderDelegate {
    @objc func loadingFinished(_ loader: SUSLoader!) {
        ViewObjects.shared().hideLoadingScreen()
        tableView.reloadData()
        refreshControl?.endRefreshing()

        if dataModel.count == 0 {
            if nothingPlayingScreen == nil {
                let screen = UIImageView()
                screen.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin, .flexibleRightMargin, .flexibleBottomMargin]
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
                label.text = "Nothing Playing\non the\nServer"
                label.frame = CGRect(x: 15, y: 15, width: 210, height: 150)
                screen.addSubview(label)

                view.addSubview(screen)
                nothingPlayingScreen = screen
            }
        } else {
            nothingPlayingScreen?.removeFromSuperview()
            nothingPlayingScreen = nil
        }
    }

    @objc func loadingFailed(_ loader: SUSLoader!, withError error: Error!) {
        if Settings.shared().isPopupsEnabled {
            let message = "There was an error loading the now playing list.\n\nError \((error as NSError).code): \(error.localizedDescription)"
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        }
        ViewObjects.shared().hideLoadingScreen()
        refreshControl?.endRefreshing()
    }
}
