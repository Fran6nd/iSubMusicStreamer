//
//  GenresArtistViewController.swift
//  iSub
//
//  Created by François Ganot on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(GenresArtistViewController) final class GenresArtistViewController: UITableViewController {

    @objc var listOfArtists: NSMutableArray = NSMutableArray()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        tableView.tableHeaderView = headerView
        NSLayoutConstraint.activate([
            headerView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            headerView.widthAnchor.constraint(equalTo: tableView.widthAnchor),
            headerView.topAnchor.constraint(equalTo: tableView.topAnchor)
        ])

        let playAllAndShuffleHeader = PlayAllAndShuffleHeader(playAllHandler: { [weak self] in
            ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
            EX2Dispatch.runInMainThreadAsync { self?.playAllSongs() }
        }, shuffleHandler: { [weak self] in
            ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: "Shuffling")
            EX2Dispatch.runInMainThreadAsync { self?.shuffleSongs() }
        })
        headerView.addSubview(playAllAndShuffleHeader)
        NSLayoutConstraint.activate([
            playAllAndShuffleHeader.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            playAllAndShuffleHeader.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            playAllAndShuffleHeader.topAnchor.constraint(equalTo: headerView.topAnchor),
            playAllAndShuffleHeader.bottomAnchor.constraint(equalTo: headerView.bottomAnchor)
        ])

        tableView.tableHeaderView?.layoutIfNeeded()
        tableView.tableHeaderView = tableView.tableHeaderView

        tableView.backgroundColor = UIColor(named: "isubBackgroundColor")
        tableView.separatorStyle = .none
        tableView.rowHeight = Defines.rowHeight
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationItem.rightBarButtonItem = Music.shared().showPlayerIcon
            ? UIBarButtonItem(image: UIImage(systemName: Defines.musicNoteImageSystemName), style: .plain, target: self, action: #selector(nowPlayingAction(_:)))
            : nil
    }

    // MARK: - Actions

    @IBAction private func nowPlayingAction(_ sender: Any) {
        let playerVC = PlayerViewController()
        playerVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(playerVC, animated: true)
    }

    private func pushPlayerIfNeeded() {
        Music.shared().playSong(atPosition: 0)
        if UIDevice.isPad {
            NotificationCenter.postNotificationToMainThread(name: ISMSNotification_ShowPlayer)
        } else {
            let playerVC = PlayerViewController()
            playerVC.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(playerVC, animated: true)
        }
    }

    private func dbQueue() -> FMDatabaseQueue? {
        Settings.shared().isOfflineMode ? Database.shared().songCacheDbQueue : Database.shared().genresDbQueue
    }

    private func genreQuery() -> String {
        Settings.shared().isOfflineMode
            ? "SELECT md5 FROM cachedSongsLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE"
            : "SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE"
    }

    private func collectMd5s(forArtist artistName: String? = nil) -> [String] {
        var md5s: [String] = []
        let genre = title ?? ""
        let query: String
        let args: [Any]
        if let artist = artistName {
            query = Settings.shared().isOfflineMode
                ? "SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND genre = ? ORDER BY seg2 COLLATE NOCASE"
                : "SELECT md5 FROM genresLayout WHERE seg1 = ? AND genre = ? ORDER BY seg2 COLLATE NOCASE"
            args = [artist, genre]
        } else {
            query = genreQuery()
            args = [genre]
        }
        dbQueue()?.inDatabase { db in
            if let result = db.executeQuery(query, withArgumentsIn: args) {
                while result.next() {
                    if let md5 = result.string(forColumnIndex: 0) { md5s.append(md5) }
                }
                result.close()
            }
        }
        return md5s
    }

    private func playAllSongs() {
        PlayQueue.shared().isShuffle = false
        if Settings.shared().isJukeboxEnabled {
            Database.shared().resetJukeboxPlaylist()
            Jukebox.shared().clearRemotePlaylist()
        } else {
            Database.shared().resetCurrentPlaylistDb()
        }
        for md5 in collectMd5s() {
            Song(fromGenreDbQueue: md5)?.addToCurrentPlaylistDbQueue()
        }
        if Settings.shared().isJukeboxEnabled {
            Jukebox.shared().playSong(atPosition: 0)
        }
        ViewObjects.shared().hideLoadingScreen()
        NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
        pushPlayerIfNeeded()
    }

    private func shuffleSongs() {
        PlayQueue.shared().isShuffle = false
        if Settings.shared().isJukeboxEnabled {
            Database.shared().resetJukeboxPlaylist()
            Jukebox.shared().clearRemotePlaylist()
        } else {
            Database.shared().resetCurrentPlaylistDb()
        }
        for md5 in collectMd5s() {
            Song(fromGenreDbQueue: md5)?.addToCurrentPlaylistDbQueue()
        }
        Database.shared().shufflePlaylist()
        if Settings.shared().isJukeboxEnabled {
            Jukebox.shared().playSong(atPosition: 0)
        }
        PlayQueue.shared().isShuffle = true
        ViewObjects.shared().hideLoadingScreen()
        NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
        pushPlayerIfNeeded()
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        listOfArtists.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        cell.hideCoverArt = true
        cell.hideNumberLabel = true
        cell.hideDurationLabel = true
        cell.hideSecondaryLabel = true
        let name = listOfArtists.objectAtIndexSafe(UInt(indexPath.row)) as? String
        cell.update(primaryText: name ?? "", secondaryText: nil)
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let artistName = listOfArtists.objectAtIndexSafe(UInt(indexPath.row)) as? String ?? ""

        let genresAlbumVC = GenresAlbumViewController()
        genresAlbumVC.title = artistName
        genresAlbumVC.listOfAlbums = NSMutableArray()
        genresAlbumVC.listOfSongs = NSMutableArray()
        genresAlbumVC.segment = 2
        genresAlbumVC.seg1 = artistName
        genresAlbumVC.genre = title ?? ""

        let genre = title ?? ""
        let query: String
        let args: [Any] = [artistName, genre]
        if Settings.shared().isOfflineMode {
            query = "SELECT md5, segs, seg2 FROM cachedSongsLayout WHERE seg1 = ? AND genre = ? GROUP BY seg2 ORDER BY seg2 COLLATE NOCASE"
        } else {
            query = "SELECT md5, segs, seg2 FROM genresLayout WHERE seg1 = ? AND genre = ? GROUP BY seg2 ORDER BY seg2 COLLATE NOCASE"
        }

        dbQueue()?.inDatabase { db in
            if let result = db.executeQuery(query, withArgumentsIn: args) {
                while result.next() {
                    let md5 = result.string(forColumnIndex: 0)
                    let segs = result.int(forColumnIndex: 1)
                    let seg2 = result.string(forColumnIndex: 2)
                    if segs > 2 {
                        if let md5, let seg2 {
                            genresAlbumVC.listOfAlbums.add([md5, seg2])
                        }
                    } else {
                        if let md5 { genresAlbumVC.listOfSongs.add(md5) }
                    }
                }
                result.close()
            }
        }

        pushViewControllerCustom(genresAlbumVC)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let artistName = listOfArtists.objectAtIndexSafe(UInt(indexPath.row)) as? String ?? ""
        let genre = title ?? ""

        if Settings.shared().isOfflineMode {
            return SwipeAction.downloadQueueAndDeleteConfig(downloadHandler: nil, queueHandler: { [weak self] in
                guard let self else { return }
                ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
                EX2Dispatch.runInMainThread(afterDelay: 0.05) {
                    for md5 in self.collectMd5s(forArtist: artistName) {
                        Song(fromGenreDbQueue: md5)?.addToCurrentPlaylistDbQueue()
                    }
                    NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
                    ViewObjects.shared().hideLoadingScreen()
                }
            }, deleteHandler: nil)
        } else {
            return SwipeAction.downloadQueueAndDeleteConfig(downloadHandler: { [weak self] in
                guard let self else { return }
                ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
                EX2Dispatch.runInMainThread(afterDelay: 0.05) {
                    let onlineQueue = Database.shared().genresDbQueue
                    let query = "SELECT md5 FROM genresLayout WHERE seg1 = ? AND genre = ? ORDER BY seg2 COLLATE NOCASE"
                    var md5s: [String] = []
                    onlineQueue?.inDatabase { db in
                        if let result = db.executeQuery(query, withArgumentsIn: [artistName, genre]) {
                            while result.next() {
                                if let md5 = result.string(forColumnIndex: 0) { md5s.append(md5) }
                            }
                            result.close()
                        }
                    }
                    for md5 in md5s { Song(fromGenreDbQueue: md5)?.addToCacheQueueDbQueue() }
                    ViewObjects.shared().hideLoadingScreen()
                }
            }, queueHandler: { [weak self] in
                guard let self else { return }
                ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
                EX2Dispatch.runInMainThread(afterDelay: 0.05) {
                    for md5 in self.collectMd5s(forArtist: artistName) {
                        Song(fromGenreDbQueue: md5)?.addToCurrentPlaylistDbQueue()
                    }
                    NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
                    ViewObjects.shared().hideLoadingScreen()
                }
            }, deleteHandler: nil)
        }
    }
}
