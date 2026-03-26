//
//  GenresAlbumViewController.swift
//  iSub
//
//  Created by François Ganot on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(GenresAlbumViewController) final class GenresAlbumViewController: UITableViewController {

    @objc var listOfAlbums: NSMutableArray = NSMutableArray()
    @objc var listOfSongs: NSMutableArray = NSMutableArray()
    @objc var segment: Int = 2
    @objc var seg1: String = ""
    @objc var genre: String = ""

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
        if UIDevice.isPad {
            NotificationCenter.postNotificationToMainThread(name: ISMSNotification_ShowPlayer)
        } else {
            let playerVC = PlayerViewController()
            playerVC.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(playerVC, animated: true)
        }
    }

    // MARK: - Helpers

    private func dbQueue() -> FMDatabaseQueue? {
        Settings.shared().isOfflineMode ? Database.shared().songCacheDbQueue : Database.shared().genresDbQueue
    }

    private func playQuery() -> String {
        let table = Settings.shared().isOfflineMode ? "cachedSongsLayout" : "genresLayout"
        return "SELECT md5 FROM \(table) WHERE seg1 = ? AND seg\(segment - 1) = ? AND genre = ? ORDER BY seg\(segment) COLLATE NOCASE"
    }

    private func collectMd5s(forAlbumName albumName: String? = nil) -> [String] {
        var md5s: [String] = []
        let q = playQuery()
        let args: [Any] = [seg1, albumName ?? title ?? "", genre]
        dbQueue()?.inDatabase { db in
            if let result = db.executeQuery(q, withArgumentsIn: args) {
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
        Music.shared().playSong(atPosition: 0)
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
        Music.shared().playSong(atPosition: 0)
        PlayQueue.shared().isShuffle = true
        ViewObjects.shared().hideLoadingScreen()
        NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
        pushPlayerIfNeeded()
    }

    private func coverArtId(forMd5 md5: String) -> String? {
        var coverArtId: String?
        dbQueue()?.inDatabase { db in
            if let result = db.executeQuery("SELECT coverArtId FROM genresSongs WHERE md5 = ?", withArgumentsIn: [md5]) {
                if result.next() { coverArtId = result.string(forColumnIndex: 0) }
                result.close()
            }
        }
        return coverArtId
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        listOfAlbums.count + listOfSongs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        if indexPath.row < listOfAlbums.count {
            let pair = listOfAlbums.objectAtIndexSafe(UInt(indexPath.row)) as? NSArray
            let md5 = pair?.objectAtIndexSafe(0) as? String ?? ""
            let name = pair?.objectAtIndexSafe(1) as? String ?? ""
            cell.hideNumberLabel = true
            cell.hideCoverArt = false
            cell.hideDurationLabel = false
            cell.hideSecondaryLabel = true
            cell.update(primaryText: name, secondaryText: nil, coverArtId: coverArtId(forMd5: md5))
        } else {
            let songRow = indexPath.row - listOfAlbums.count
            let md5 = listOfSongs.objectAtIndexSafe(UInt(songRow)) as? String ?? ""
            let song = Song(fromGenreDbQueue: md5)
            cell.hideCoverArt = true
            cell.hideDurationLabel = false
            cell.hideSecondaryLabel = false
            cell.update(model: song)
            if let track = song?.track, track.intValue != 0 {
                cell.hideNumberLabel = false
                cell.number = track.intValue
            } else {
                cell.hideNumberLabel = true
            }
        }
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row < listOfAlbums.count {
            let pair = listOfAlbums.objectAtIndexSafe(UInt(indexPath.row)) as? NSArray
            let albumName = pair?.objectAtIndexSafe(1) as? String ?? ""

            let nextVC = GenresAlbumViewController(nibName: "GenresAlbumViewController", bundle: nil)
            nextVC.title = albumName
            nextVC.listOfAlbums = NSMutableArray()
            nextVC.listOfSongs = NSMutableArray()
            nextVC.segment = segment + 1
            nextVC.seg1 = seg1
            nextVC.genre = genre

            let table = Settings.shared().isOfflineMode ? "cachedSongsLayout" : "genresLayout"
            let query = "SELECT md5, segs, seg\(segment + 1) FROM \(table) WHERE seg1 = ? AND seg\(segment) = ? AND genre = ? GROUP BY seg\(segment + 1) ORDER BY seg\(segment + 1) COLLATE NOCASE"

            dbQueue()?.inDatabase { db in
                if let result = db.executeQuery(query, withArgumentsIn: [seg1, albumName, genre]) {
                    while result.next() {
                        let md5 = result.string(forColumnIndex: 0)
                        let segs = result.int(forColumnIndex: 1)
                        let seg = result.string(forColumnIndex: 2)
                        if segs > Int32(segment + 1) {
                            if let md5, let seg { nextVC.listOfAlbums.add([md5, seg]) }
                        } else {
                            if let md5 { nextVC.listOfSongs.add(md5) }
                        }
                    }
                    result.close()
                }
            }
            pushViewControllerCustom(nextVC)
        } else {
            let songRow = indexPath.row - listOfAlbums.count
            if Settings.shared().isJukeboxEnabled {
                Database.shared().resetJukeboxPlaylist()
                Jukebox.shared().clearRemotePlaylist()
            } else {
                Database.shared().resetCurrentPlaylistDb()
            }
            var songIds: [String] = []
            for item in listOfSongs {
                if let md5 = item as? String, let song = Song(fromGenreDbQueue: md5) {
                    song.addToCurrentPlaylistDbQueue()
                    if Settings.shared().isJukeboxEnabled, let sid = song.songId { songIds.append(sid) }
                }
            }
            if Settings.shared().isJukeboxEnabled {
                Jukebox.shared().stop()
                Jukebox.shared().clearPlaylist()
                Jukebox.shared().addSongs(songIds)
            }
            PlayQueue.shared().isShuffle = false
            NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
            Music.shared().playSong(atPosition: songRow)
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row < listOfAlbums.count else { return nil }
        let pair = listOfAlbums.objectAtIndexSafe(UInt(indexPath.row)) as? NSArray
        let albumName = pair?.objectAtIndexSafe(1) as? String ?? ""
        let table = Settings.shared().isOfflineMode ? "cachedSongsLayout" : "genresLayout"
        let swipeQuery = "SELECT md5 FROM \(table) WHERE seg1 = ? AND seg\(segment) = ? AND genre = ? ORDER BY seg\(segment + 1) COLLATE NOCASE"

        func queueSongs(download: Bool) {
            let q = swipeQuery
            var md5s: [String] = []
            dbQueue()?.inDatabase { db in
                if let result = db.executeQuery(q, withArgumentsIn: [seg1, albumName, genre]) {
                    while result.next() {
                        if let md5 = result.string(forColumnIndex: 0) { md5s.append(md5) }
                    }
                    result.close()
                }
            }
            for md5 in md5s {
                if let song = Song(fromGenreDbQueue: md5) {
                    if download { song.addToCacheQueueDbQueue() }
                    else { song.addToCurrentPlaylistDbQueue() }
                }
            }
        }

        if Settings.shared().isOfflineMode {
            return SwipeAction.downloadQueueAndDeleteConfig(downloadHandler: nil, queueHandler: { [weak self] in
                guard let self else { return }
                ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
                EX2Dispatch.runInMainThread(afterDelay: 0.05) {
                    queueSongs(download: false)
                    NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
                    ViewObjects.shared().hideLoadingScreen()
                }
            }, deleteHandler: nil)
        } else {
            return SwipeAction.downloadQueueAndDeleteConfig(downloadHandler: { [weak self] in
                guard let self else { return }
                ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
                EX2Dispatch.runInMainThread(afterDelay: 0.05) {
                    queueSongs(download: true)
                    ViewObjects.shared().hideLoadingScreen()
                }
            }, queueHandler: { [weak self] in
                guard let self else { return }
                ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
                EX2Dispatch.runInMainThread(afterDelay: 0.05) {
                    queueSongs(download: false)
                    NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
                    ViewObjects.shared().hideLoadingScreen()
                }
            }, deleteHandler: nil)
        }
    }
}
