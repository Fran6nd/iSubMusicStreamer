//
//  CacheAlbumViewController.swift
//  iSub
//
//  Created by François Ganot on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(CacheAlbumViewController) final class CacheAlbumViewController: UITableViewController {

    @objc var artistName: String?
    @objc var listOfAlbums: NSMutableArray = NSMutableArray()
    @objc var listOfSongs: NSMutableArray = NSMutableArray()
    @objc var sectionInfo: [Any]?
    @objc var segments: [Any]?

    // MARK: - Lifecycle

    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = artistName

        tableView.backgroundColor = UIColor(named: "isubBackgroundColor")
        tableView.separatorStyle = .none
        tableView.rowHeight = Defines.rowHeight
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)

        listOfAlbums.sort(comparator: { obj1, obj2 in
            let name1 = (obj1 as? NSArray)?.objectAtIndexSafe(1) as? NSString ?? ""
            let name2 = (obj2 as? NSArray)?.objectAtIndexSafe(1) as? NSString ?? ""
            return name1.caseInsensitiveCompareWithoutIndefiniteArticles(name2 as String)
        })
        tableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationItem.rightBarButtonItem = nil
        if Music.shared().showPlayerIcon {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: Defines.musicNoteImageSystemName), style: .plain, target: self, action: #selector(nowPlayingAction(_:)))
        }

        addHeaderAndIndex()

        NotificationCenter.addObserverOnMainThread(self, selector: #selector(cachedSongDeleted), name: "cachedSongDeleted")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.removeObserverOnMainThread(self, name: "cachedSongDeleted")
    }

    // MARK: - Header & Section Index

    private func addHeaderAndIndex() {
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
            EX2Dispatch.runInBackgroundAsync { self?.loadPlayAllPlaylist(false) }
        }, shuffleHandler: { [weak self] in
            ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: "Shuffling")
            EX2Dispatch.runInBackgroundAsync { self?.loadPlayAllPlaylist(true) }
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

        guard listOfAlbums.count > 10 else { return }

        var secInfo: [Any]?
        Database.shared().albumListCacheDbQueue?.inDatabase { db in
            db.executeUpdate("DROP TABLE IF EXISTS albumIndex", withArgumentsIn: [])
            db.executeUpdate("CREATE TEMP TABLE albumIndex (album TEXT)", withArgumentsIn: [])
            db.beginTransaction()
            for rowId in listOfAlbums {
                db.executeUpdate("INSERT INTO albumIndex SELECT title FROM albumsCache WHERE rowid = ?", withArgumentsIn: [rowId as Any])
            }
            db.commit()
            secInfo = Database.shared().sectionInfo(fromTable: "albumIndex", in: db, withColumn: "album")
            db.executeUpdate("DROP TABLE IF EXISTS albumIndex", withArgumentsIn: [])
        }

        if let info = secInfo, info.count >= 5 {
            sectionInfo = info
            tableView.reloadData()
        } else {
            sectionInfo = nil
        }
    }

    // MARK: - Data reload

    @objc private func cachedSongDeleted() {
        let segment = segments?.count ?? 0

        listOfAlbums = NSMutableArray()
        listOfSongs = NSMutableArray()

        var query = "SELECT md5, segs, seg\(segment + 1), track FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? "
        for i in 2...max(2, segment) where i <= segment {
            query += " AND seg\(i) = ? "
        }
        query += "GROUP BY seg\(segment + 1) ORDER BY seg\(segment + 1) COLLATE NOCASE"

        Database.shared().songCacheDbQueue?.inDatabase { [weak self] db in
            guard let self else { return }
            if let result = db.executeQuery(query, withArgumentsIn: self.segments as? [Any] ?? []) {
                while result.next() {
                    autoreleasepool {
                        let md5 = result.string(forColumnIndex: 0)
                        let segs = result.int(forColumnIndex: 1)
                        let seg = result.string(forColumnIndex: 2)
                        let track = result.int(forColumnIndex: 3)
                        let discNumber = result.int(forColumn: "discNumber")

                        if segs > Int32(segment + 1) {
                            if let md5, let seg { self.listOfAlbums.add([md5, seg]) }
                        } else if let md5 {
                            let entry: [Any] = [md5, NSNumber(value: track), NSNumber(value: discNumber)]
                            self.listOfSongs.add(entry)
                            self.sortSongsIfNoDuplicateTracks()
                        }
                    }
                }
                result.close()
            }
        }

        if listOfAlbums.count + listOfSongs.count == 0 {
            DispatchQueue.main.async {
                if UIDevice.isPad() {
                    AppDelegate.shared().padRootViewController.currentContentNavigationController?.popToRootViewController(animated: true)
                } else if AppDelegate.shared().currentTabBarController.selectedIndex == 4 {
                    let moreNav = AppDelegate.shared().currentTabBarController.moreNavigationController
                    if moreNav.viewControllers.count > 1 {
                        moreNav.popToViewController(moreNav.viewControllers[1], animated: true)
                    }
                } else {
                    (AppDelegate.shared().currentTabBarController.selectedViewController as? UINavigationController)?.popToRootViewController(animated: true)
                }
            }
        } else {
            tableView.reloadData()
        }
    }

    private func sortSongsIfNoDuplicateTracks() {
        var trackNumbers: [NSNumber] = []
        for item in listOfSongs {
            guard let arr = item as? NSArray, let track = arr.objectAtIndexSafe(1) as? NSNumber else { continue }
            if trackNumbers.contains(track) { return }
            trackNumbers.append(track)
        }
        listOfSongs.sort(comparator: trackAndDiscComparator)
    }

    // MARK: - Play All

    private func loadPlayAllPlaylist(_ shuffle: Bool) {
        let segment = segments?.count ?? 0

        if Settings.shared().isJukeboxEnabled {
            Database.shared().resetJukeboxPlaylist()
            Jukebox.shared().clearRemotePlaylist()
        } else {
            Database.shared().resetCurrentPlaylistDb()
        }

        var query = "SELECT md5 FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? "
        for i in 2...max(2, segment) where i <= segment {
            query += " AND seg\(i) = ? "
        }
        query += "ORDER BY seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8 COLLATE NOCASE"

        var md5s: [String] = []
        Database.shared().songCacheDbQueue?.inDatabase { [weak self] db in
            if let result = db.executeQuery(query, withArgumentsIn: self?.segments as? [Any] ?? []) {
                while result.next() {
                    autoreleasepool {
                        if let md5 = result.string(forColumnIndex: 0) { md5s.append(md5) }
                    }
                }
                result.close()
            }
        }

        for md5 in md5s {
            Song(fromCacheDbQueue: md5)?.addToCurrentPlaylistDbQueue()
        }

        if shuffle {
            PlayQueue.shared().isShuffle = true
            Database.shared().resetShufflePlaylist()
            Database.shared().currentPlaylistDbQueue?.inDatabase { db in
                db.executeUpdate("INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist ORDER BY RANDOM()", withArgumentsIn: [])
            }
        } else {
            PlayQueue.shared().isShuffle = false
        }

        NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
        EX2Dispatch.runInMainThreadAsync {
            ViewObjects.shared().hideLoadingScreen()
            Music.shared().playSong(atPosition: 0)
            if UIDevice.isPad() {
                NotificationCenter.postNotificationToMainThread(name: ISMSNotification_ShowPlayer)
            } else {
                let playerVC = PlayerViewController()
                playerVC.hidesBottomBarWhenPushed = true
                self.navigationController?.pushViewController(playerVC, animated: true)
            }
        }
    }

    // MARK: - Actions

    @IBAction private func nowPlayingAction(_ sender: Any) {
        let playerVC = PlayerViewController()
        playerVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(playerVC, animated: true)
    }

    // MARK: - Helpers

    private func albumAtIndexPath(_ indexPath: IndexPath) -> Album {
        let entry = listOfAlbums.objectAtIndexSafe(UInt(indexPath.row)) as? NSArray
        let md5 = entry?.objectAtIndexSafe(0) as? String ?? ""
        let album = Album()
        album.title = entry?.objectAtIndexSafe(1) as? String
        album.artistName = artistName
        Database.shared().songCacheDbQueue?.inDatabase { db in
            if let result = db.executeQuery("SELECT coverArtId FROM cachedSongs WHERE md5 = ?", withArgumentsIn: [md5]) {
                if result.next() { album.coverArtId = result.string(forColumn: "coverArtId") }
                result.close()
            }
        }
        return album
    }

    private func songAtIndexPath(_ indexPath: IndexPath) -> Song? {
        let md5 = (listOfSongs.objectAtIndexSafe(UInt(indexPath.row - listOfAlbums.count)) as? NSArray)?.firstObject as? String
        return Song(fromCacheDbQueue: md5 ?? "")
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension CacheAlbumViewController {

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        sectionInfo?.compactMap { ($0 as? NSArray)?.objectAtIndexSafe(0) as? String }
    }

    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        if index == 0 {
            tableView.scrollRectToVisible(CGRect(x: 0, y: 50, width: 320, height: 40), animated: false)
        } else {
            let i = index - 1
            let row = (sectionInfo != nil && i < sectionInfo!.count)
                ? ((sectionInfo![i] as? NSArray)?.objectAtIndexSafe(1) as? NSNumber)?.intValue ?? 0
                : 0
            tableView.scrollToRow(at: IndexPath(row: row, section: 0), at: .top, animated: false)
        }
        return -1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        listOfAlbums.count + listOfSongs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        if indexPath.row < listOfAlbums.count {
            cell.hideCacheIndicator = true
            cell.hideNumberLabel = true
            cell.hideCoverArt = false
            cell.hideDurationLabel = true
            cell.update(model: albumAtIndexPath(indexPath))
        } else {
            cell.hideCacheIndicator = true
            cell.hideCoverArt = true
            cell.hideDurationLabel = false
            let song = songAtIndexPath(indexPath)
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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row < listOfAlbums.count {
            let segment = (segments?.count ?? 0) + 1
            let entry = listOfAlbums.objectAtIndexSafe(UInt(indexPath.row)) as? NSArray
            let albumName = entry?.objectAtIndexSafe(1) as? String

            let cacheAlbumVC = CacheAlbumViewController()
            cacheAlbumVC.artistName = albumName
            cacheAlbumVC.listOfAlbums = NSMutableArray()
            cacheAlbumVC.listOfSongs = NSMutableArray()

            var query = "SELECT md5, segs, seg\(segment + 1), track, cachedSongs.discNumber FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? "
            for i in 2...max(2, segment) where i <= segment {
                query += " AND seg\(i) = ? "
            }
            query += "GROUP BY seg\(segment + 1) ORDER BY seg\(segment + 1) COLLATE NOCASE"

            var newSegments = (segments ?? []) + [albumName as Any]
            cacheAlbumVC.segments = newSegments

            Database.shared().songCacheDbQueue?.inDatabase { db in
                if let result = db.executeQuery(query, withArgumentsIn: newSegments) {
                    while result.next() {
                        autoreleasepool {
                            let md5 = result.string(forColumnIndex: 0)
                            let segs = result.int(forColumnIndex: 1)
                            let seg = result.string(forColumnIndex: 2)
                            let track = result.int(forColumnIndex: 3)
                            let discNumber = result.int(forColumn: "discNumber")

                            if segs > Int32(segment + 1) {
                                if let md5, let seg { cacheAlbumVC.listOfAlbums.add([md5, seg]) }
                            } else if let md5 {
                                var entry: [Any] = [md5, NSNumber(value: track)]
                                if discNumber != 0 { entry.append(NSNumber(value: discNumber)) }
                                cacheAlbumVC.listOfSongs.add(entry)

                                // Check for duplicate track+disc combos
                                var trackNumbers: [NSNumber] = []
                                var multipleSame = false
                                for item in cacheAlbumVC.listOfSongs {
                                    guard let arr = item as? NSArray,
                                          let t = arr.objectAtIndexSafe(1) as? NSNumber else { continue }
                                    let d = arr.objectAtIndexSafe(2) as? NSNumber
                                    if let existing = trackNumbers.firstIndex(of: t) {
                                        let existingDisc = (cacheAlbumVC.listOfSongs[existing] as? NSArray)?.objectAtIndexSafe(2) as? NSNumber
                                        if d == nil || existingDisc == d {
                                            multipleSame = true
                                            break
                                        }
                                    }
                                    trackNumbers.append(t)
                                }
                                if !multipleSame {
                                    cacheAlbumVC.listOfSongs.sort(comparator: trackAndDiscComparator)
                                }
                            }
                        }
                    }
                    result.close()
                }
            }

            pushViewControllerCustom(cacheAlbumVC)
        } else {
            let a = indexPath.row - listOfAlbums.count

            if Settings.shared().isJukeboxEnabled {
                Database.shared().resetJukeboxPlaylist()
                Jukebox.shared().clearRemotePlaylist()
            } else {
                Database.shared().resetCurrentPlaylistDb()
            }
            for item in listOfSongs {
                let md5 = (item as? NSArray)?.objectAtIndexSafe(0) as? String ?? ""
                Song(fromCacheDbQueue: md5)?.addToCurrentPlaylistDbQueue()
            }

            PlayQueue.shared().isShuffle = false
            Music.shared().playSong(atPosition: a)
            NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if indexPath.row < listOfAlbums.count {
            let album = albumAtIndexPath(indexPath)
            return SwipeAction.downloadQueueAndDeleteConfig(downloadHandler: nil, queueHandler: { [weak self] in
                guard let self else { return }
                ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
                EX2Dispatch.runInBackgroundAsync {
                    var newSegments = (self.segments ?? []) + [album.title as Any]
                    let segment = newSegments.count
                    var query = "SELECT md5 FROM cachedSongsLayout WHERE segs = \(segment + 1)"
                    for i in 1...segment { query += " AND seg\(i) = ? " }
                    query += "ORDER BY seg\(segment + 1) COLLATE NOCASE"

                    var md5s: [String] = []
                    Database.shared().songCacheDbQueue?.inDatabase { db in
                        if let result = db.executeQuery(query, withArgumentsIn: newSegments) {
                            while result.next() {
                                if let md5 = result.string(forColumnIndex: 0) { md5s.append(md5) }
                            }
                            result.close()
                        }
                    }
                    for md5 in md5s { Song(fromCacheDbQueue: md5)?.addToCurrentPlaylistDbQueue() }
                    NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
                    EX2Dispatch.runInMainThreadAsync { ViewObjects.shared().hideLoadingScreen() }
                }
            }, deleteHandler: { [weak self] in
                guard let self else { return }
                ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: "Deleting")
                EX2Dispatch.runInBackgroundAsync {
                    var newSegments = (self.segments ?? []) + [album.title as Any]
                    let segment = newSegments.count
                    var query = "SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? "
                    for i in 2...max(2, segment) where i <= segment { query += " AND seg\(i) = ? " }

                    var md5s: [String] = []
                    Database.shared().songCacheDbQueue?.inDatabase { db in
                        if let result = db.executeQuery(query, withArgumentsIn: newSegments) {
                            while result.next() {
                                if let md5 = result.string(forColumnIndex: 0) { md5s.append(md5) }
                            }
                            result.close()
                        }
                    }
                    for md5 in md5s { _ = Song.removeFromCacheDbQueue(byMD5: md5) }
                    Cache.shared().findCacheSize()
                    NotificationCenter.postNotificationToMainThread(name: "cachedSongDeleted")
                    if let mgr = ISMSCacheQueueManager.sharedInstance(), !mgr.isQueueDownloading {
                        mgr.startDownloadQueue()
                    }
                    EX2Dispatch.runInMainThreadAsync { ViewObjects.shared().hideLoadingScreen() }
                }
            })
        } else {
            let md5 = (listOfSongs.objectAtIndexSafe(UInt(indexPath.row - listOfAlbums.count)) as? NSArray)?.firstObject as? String ?? ""
            return SwipeAction.downloadQueueAndDeleteConfig(downloadHandler: nil, queueHandler: {
                Song(fromCacheDbQueue: md5)?.addToCurrentPlaylistDbQueue()
                NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
            }, deleteHandler: {
                _ = Song.removeFromCacheDbQueue(byMD5: md5)
                Cache.shared().findCacheSize()
                NotificationCenter.postNotificationToMainThread(name: "cachedSongDeleted")
            })
        }
    }
}

// MARK: - Track/Disc sort comparator

private func trackAndDiscComparator(_ obj1: Any, _ obj2: Any) -> ComparisonResult {
    let a1 = obj1 as? NSArray
    let a2 = obj2 as? NSArray
    let track1 = (a1?.objectAtIndexSafe(1) as? NSNumber)?.intValue ?? 0
    let track2 = (a2?.objectAtIndexSafe(1) as? NSNumber)?.intValue ?? 0
    let disc1 = (a1?.objectAtIndexSafe(2) as? NSNumber)?.intValue ?? 0
    let disc2 = (a2?.objectAtIndexSafe(2) as? NSNumber)?.intValue ?? 0
    if disc1 < disc2 { return .orderedAscending }
    if disc1 > disc2 { return .orderedDescending }
    if track1 < track2 { return .orderedAscending }
    if track1 > track2 { return .orderedDescending }
    return .orderedSame
}
