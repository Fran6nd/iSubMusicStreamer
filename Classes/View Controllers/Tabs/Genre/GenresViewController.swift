//
//  GenresViewController.swift
//  iSub
//
//  Created by François Ganot on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(GenresViewController) final class GenresViewController: UITableViewController {

    private var noGenresScreen: UIImageView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Genres"

        if Settings.shared().isOfflineMode {
            navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gearshape.fill"), style: .plain, target: self, action: #selector(settingsAction(_:)))
        }

        tableView.backgroundColor = UIColor(named: "isubBackgroundColor")
        tableView.separatorStyle = .none
        tableView.rowHeight = Defines.rowHeight
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
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: Defines.musicNoteImageSystemName), style: .plain, target: self, action: #selector(nowPlayingAction(_:)))
        }

        let count = genreCount()
        if count == 0 { showNoGenresScreen() }

        tableView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        noGenresScreen?.removeFromSuperview()
        noGenresScreen = nil
    }

    // MARK: - Helpers

    private func dbQueue() -> FMDatabaseQueue? {
        Settings.shared().isOfflineMode ? Database.shared().songCacheDbQueue : Database.shared().genresDbQueue
    }

    private func genreCount() -> Int {
        var count = 0
        dbQueue()?.inDatabase { db in
            if let result = db.executeQuery("SELECT COUNT(*) FROM genres", withArgumentsIn: []) {
                if result.next() { count = Int(result.int(forColumnIndex: 0)) }
                result.close()
            }
        }
        return count
    }

    private func genreName(at row: Int) -> String? {
        var name: String?
        dbQueue()?.inDatabase { db in
            if let result = db.executeQuery("SELECT genre FROM genres WHERE ROWID = ?", withArgumentsIn: [row + 1]) {
                if result.next() { name = result.string(forColumnIndex: 0) }
                result.close()
            }
        }
        return name
    }

    private func showNoGenresScreen() {
        guard noGenresScreen == nil else { return }

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
        label.text = Settings.shared().isOfflineMode ? "No Cached\nSongs" : "Load The\nSongs Tab\nFirst"
        label.frame = CGRect(x: 20, y: 20, width: 200, height: 140)
        screen.addSubview(label)

        view.addSubview(screen)
        noGenresScreen = screen
    }

    // MARK: - Actions

    @objc private func settingsAction(_ sender: Any) {
        let serverVC = ServerListViewController(nibName: "ServerListViewController", bundle: nil)
        serverVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(serverVC, animated: true)
    }

    @IBAction private func nowPlayingAction(_ sender: Any) {
        let playerVC = PlayerViewController()
        playerVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(playerVC, animated: true)
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        genreCount()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        cell.hideSecondaryLabel = true
        cell.hideDurationLabel = true
        cell.hideCoverArt = true
        cell.hideNumberLabel = true
        cell.update(primaryText: genreName(at: indexPath.row) ?? "", secondaryText: nil)
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let artistVC = GenresArtistViewController(nibName: "GenresArtistViewController", bundle: nil)

        let genreName = self.genreName(at: indexPath.row) ?? ""
        artistVC.title = genreName

        let isOffline = Settings.shared().isOfflineMode
        let query = isOffline
            ? "SELECT seg1 FROM cachedSongsLayout a INNER JOIN genresSongs b ON a.md5 = b.md5 WHERE b.genre = ? GROUP BY seg1 ORDER BY seg1 COLLATE NOCASE"
            : "SELECT seg1 FROM genresLayout a INNER JOIN genresSongs b ON a.md5 = b.md5 WHERE b.genre = ? GROUP BY seg1 ORDER BY seg1 COLLATE NOCASE"

        var artists: [String] = []
        dbQueue()?.inDatabase { db in
            if let result = db.executeQuery(query, withArgumentsIn: [genreName]) {
                while result.next() {
                    if let artist = result.string(forColumnIndex: 0) { artists.append(artist) }
                }
                result.close()
            }
        }
        artistVC.listOfArtists = NSMutableArray(array: artists)
        pushViewControllerCustom(artistVC)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let genre = genreName(at: indexPath.row)

        if Settings.shared().isOfflineMode {
            return SwipeAction.downloadQueueAndDeleteConfig(downloadHandler: nil, queueHandler: { [weak self] in
                guard let self else { return }
                ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
                EX2Dispatch.runInMainThreadAsync {
                    self.queueSongsForGenre(genre, download: false, offline: true)
                    NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
                    ViewObjects.shared().hideLoadingScreen()
                }
            }, deleteHandler: nil)
        } else {
            return SwipeAction.downloadQueueAndDeleteConfig(downloadHandler: { [weak self] in
                guard let self else { return }
                ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
                EX2Dispatch.runInMainThreadAsync {
                    self.queueSongsForGenre(genre, download: true, offline: false)
                    ViewObjects.shared().hideLoadingScreen()
                }
            }, queueHandler: { [weak self] in
                guard let self else { return }
                ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
                EX2Dispatch.runInMainThreadAsync {
                    self.queueSongsForGenre(genre, download: false, offline: false)
                    NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
                    ViewObjects.shared().hideLoadingScreen()
                }
            }, deleteHandler: nil)
        }
    }

    private func queueSongsForGenre(_ genre: String?, download: Bool, offline: Bool) {
        let db = offline ? Database.shared().songCacheDbQueue : Database.shared().genresDbQueue
        let query = offline
            ? "SELECT md5 FROM cachedSongsLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE"
            : "SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE"

        var md5s: [String] = []
        db?.inDatabase { fmdb in
            if let result = fmdb.executeQuery(query, withArgumentsIn: [genre as Any]) {
                while result.next() {
                    if let md5 = result.string(forColumnIndex: 0) { md5s.append(md5) }
                }
                result.close()
            }
        }

        for md5 in md5s {
            if let song = Song(fromGenreDbQueue: md5) {
                if download {
                    song.addToCacheQueueDbQueue()
                } else {
                    song.addToCurrentPlaylistDbQueue()
                }
            }
        }
    }
}
