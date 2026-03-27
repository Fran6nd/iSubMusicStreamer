//
//  CacheOfflineFoldersViewController.swift
//  iSub
//
//  Created by François Ganot on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(CacheOfflineFoldersViewController) final class CacheOfflineFoldersViewController: UITableViewController {

    @objc var isNoSongsScreenShowing: Bool = false
    @objc var noSongsScreen: UIImageView?
    @objc var showIndex: Bool = false
    @objc var listOfArtists: NSMutableArray = NSMutableArray()
    @objc var listOfArtistsSections: NSMutableArray = NSMutableArray()
    @objc var sectionInfo: [Any]?

    // MARK: - Rotation

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if !UIDevice.isPad() && isNoSongsScreenShowing {
            coordinator.animate(alongsideTransition: { _ in
                if UIApplication.orientation().isPortrait {
                    self.noSongsScreen?.transform = self.noSongsScreen!.transform.translatedBy(x: 0, y: 110)
                } else {
                    self.noSongsScreen?.transform = self.noSongsScreen!.transform.translatedBy(x: 0, y: -23)
                }
            })
        }
        super.viewWillTransition(to: size, with: coordinator)
    }

    // MARK: - Lifecycle

    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }

    private func registerForNotifications() {
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadTable), name: ISMSNotification_StreamHandlerSongDownloaded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadTable), name: ISMSNotification_CacheQueueSongDownloaded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadTable), name: "cachedSongDeleted")
    }

    private func unregisterForNotifications() {
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_StreamHandlerSongDownloaded)
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_CacheQueueSongDownloaded)
        NotificationCenter.removeObserverOnMainThread(self, name: "cachedSongDeleted")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Artists"
        view.backgroundColor = UIColor(named: "isubBackgroundColor")
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gearshape.fill"), style: .plain, target: self, action: #selector(settingsAction(_:)))

        addHeader()

        tableView.backgroundColor = UIColor(named: "isubBackgroundColor")
        tableView.separatorStyle = .none
        tableView.rowHeight = Defines.rowHeight
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)

        NotificationCenter.addObserverOnMainThread(self, selector: #selector(addURLRefBackButton), name: UIApplication.didBecomeActiveNotification.rawValue)
    }

    private func addHeader() {
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
            EX2Dispatch.runInMainThreadAsync { self?.loadPlayAllPlaylist(false) }
        }, shuffleHandler: { [weak self] in
            ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: "Shuffling")
            EX2Dispatch.runInMainThreadAsync { self?.loadPlayAllPlaylist(true) }
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
    }

    @objc private func addURLRefBackButton() {
        if AppDelegate.shared().referringAppUrl != nil && AppDelegate.shared().mainTabBarController.selectedIndex != 4 {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: AppDelegate.shared(), action: #selector(AppDelegate.backToReferringApp))
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        registerForNotifications()
        Flurry.logEvent("CacheTab")
        reloadTable()

        if listOfArtists.count == 0 {
            addNoSongsScreen()
        } else {
            removeNoSongsScreen()
        }

        tableView.isScrollEnabled = true
        addURLRefBackButton()

        navigationItem.rightBarButtonItem = nil
        if Music.shared().showPlayerIcon {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: Defines.musicNoteImageSystemName), style: .plain, target: self, action: #selector(nowPlayingAction(_:)))
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterForNotifications()
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

    private func loadPlayAllPlaylist(_ shuffle: Bool) {
        PlayQueue.shared().isShuffle = false
        Database.shared().resetCurrentPlaylistDb()

        var md5s: [String] = []
        Database.shared().songCacheDbQueue?.inDatabase { db in
            if let result = db.executeQuery("SELECT md5 FROM cachedSongsLayout ORDER BY seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8, seg9 COLLATE NOCASE", withArgumentsIn: []) {
                while result.next() {
                    if let md5 = result.string(forColumnIndex: 0) { md5s.append(md5) }
                }
                result.close()
            }
        }

        for md5 in md5s {
            Song(fromCacheDbQueue: md5)?.addToCurrentPlaylistDbQueue()
        }

        if shuffle {
            PlayQueue.shared().isShuffle = true
            Database.shared().shufflePlaylist()
        } else {
            PlayQueue.shared().isShuffle = false
        }

        NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
        ViewObjects.shared().hideLoadingScreen()
        playAllPlaySong()
    }

    @objc func reloadTable() {
        listOfArtists = NSMutableArray()
        listOfArtistsSections = NSMutableArray()

        Database.shared().songCacheDbQueue?.inDatabase { db in
            db.executeUpdate("DROP TABLE IF EXISTS cachedSongsArtistList", withArgumentsIn: [])
            db.executeUpdate("CREATE TEMP TABLE cachedSongsArtistList (artist TEXT UNIQUE)", withArgumentsIn: [])
            db.executeUpdate("INSERT OR IGNORE INTO cachedSongsArtistList SELECT seg1 FROM cachedSongsLayout", withArgumentsIn: [])

            if let result = db.executeQuery("SELECT artist FROM cachedSongsArtistList ORDER BY artist COLLATE NOCASE", withArgumentsIn: []) {
                while result.next() {
                    if let artist = result.string(forColumnIndex: 0), !artist.isEmpty {
                        listOfArtists.add(artist)
                    }
                }
                result.close()
            }

            listOfArtists.sort(comparator: { a, b in
                let sa = a as? NSString ?? ""
                let sb = b as? NSString ?? ""
                return sa.caseInsensitiveCompareWithoutIndefiniteArticles(sb as String)
            })

            db.executeUpdate("DROP TABLE IF EXISTS cachedSongsArtistIndex", withArgumentsIn: [])
            db.executeUpdate("CREATE TEMP TABLE cachedSongsArtistIndex (artist TEXT)", withArgumentsIn: [])
            for artist in listOfArtists {
                if let s = artist as? NSString {
                    db.executeUpdate("INSERT INTO cachedSongsArtistIndex (artist) VALUES (?)", withArgumentsIn: [s.stringWithoutIndefiniteArticle])
                }
            }
        }

        sectionInfo = Database.shared().sectionInfo(fromTable: "cachedSongsArtistIndex", in: Database.shared().songCacheDbQueue!, withColumn: "artist")
        showIndex = (sectionInfo?.count ?? 0) >= 5

        if let info = sectionInfo as? [[Any]], !info.isEmpty {
            var lastIndex = 0
            for i in 0..<info.count - 1 {
                let index = (info[i + 1][safe: 1] as? NSNumber)?.intValue ?? 0
                let section = NSMutableArray()
                for j in lastIndex..<index {
                    section.add(listOfArtists.objectAtIndexSafe(UInt(j)) as Any)
                }
                listOfArtistsSections.add(section)
                lastIndex = index
            }
            let lastSection = NSMutableArray()
            for j in lastIndex..<listOfArtists.count {
                lastSection.add(listOfArtists.objectAtIndexSafe(UInt(j)) as Any)
            }
            listOfArtistsSections.add(lastSection)
        }

        var cachedCount = 0
        Database.shared().songCacheDbQueue?.inDatabase { db in
            if let result = db.executeQuery("SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES' AND md5 != ''", withArgumentsIn: []) {
                if result.next() { cachedCount = Int(result.int(forColumnIndex: 0)) }
                result.close()
            }
        }

        if cachedCount == 0 {
            addNoSongsScreen()
        } else {
            removeNoSongsScreen()
        }

        tableView.reloadData()
    }

    private func removeNoSongsScreen() {
        if isNoSongsScreenShowing {
            noSongsScreen?.removeFromSuperview()
            isNoSongsScreenShowing = false
        }
    }

    private func addNoSongsScreen() {
        removeNoSongsScreen()
        isNoSongsScreenShowing = true
        let screen = UIImageView()
        screen.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        screen.frame = CGRect(x: 40, y: 100, width: 240, height: 180)
        screen.center = CGPoint(x: view.bounds.width / 2, y: view.bounds.height / 2)
        screen.image = UIImage(named: "loading-screen-image")
        screen.alpha = 0.8
        screen.isUserInteractionEnabled = true

        let label = UILabel()
        label.textColor = .white
        label.font = .boldSystemFont(ofSize: 30)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "No Cached\nSongs"
        label.frame = CGRect(x: 20, y: 20, width: 200, height: 140)
        screen.addSubview(label)

        view.addSubview(screen)
        noSongsScreen = screen

        if !UIDevice.isPad() && UIApplication.orientation().isLandscape {
            screen.transform = screen.transform.translatedBy(x: 0, y: 23)
        }
    }

    @objc func playAllPlaySong() {
        Music.shared().playSong(atPosition: 0)
        if UIDevice.isPad() {
            NotificationCenter.postNotificationToMainThread(name: ISMSNotification_ShowPlayer)
        } else {
            let playerVC = PlayerViewController()
            playerVC.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(playerVC, animated: true)
        }
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        sectionInfo?.count ?? 0
    }

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        guard showIndex, let info = sectionInfo else { return nil }
        return info.compactMap { ($0 as? NSArray)?.objectAtIndexSafe(0) as? String }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        (sectionInfo as? [[Any]])?[safe: section]?.first as? String
    }

    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        if index == 0 {
            tableView.scrollRectToVisible(CGRect(x: 0, y: 90, width: 320, height: 40), animated: false)
            return -1
        }
        return index
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        (listOfArtistsSections.objectAtIndexSafe(UInt(section)) as? NSArray)?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        cell.hideCacheIndicator = true
        cell.hideNumberLabel = true
        cell.hideCoverArt = true
        cell.hideSecondaryLabel = true
        cell.hideDurationLabel = true
        let section = listOfArtistsSections.objectAtIndexSafe(UInt(indexPath.section)) as? NSArray
        let name = section?.objectAtIndexSafe(UInt(indexPath.row)) as? String ?? ""
        cell.update(model: Artist(name: name, andArtistId: ""))
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = listOfArtistsSections.objectAtIndexSafe(UInt(indexPath.section)) as? NSArray
        let name = section?.objectAtIndexSafe(UInt(indexPath.row)) as? String

        let cacheAlbumVC = CacheAlbumViewController(nibName: "CacheAlbumViewController", bundle: nil)
        cacheAlbumVC.artistName = name
        cacheAlbumVC.listOfAlbums = NSMutableArray()
        cacheAlbumVC.listOfSongs = NSMutableArray()

        Database.shared().songCacheDbQueue?.inDatabase { db in
            let q = "SELECT md5, segs, seg2, track FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? GROUP BY seg2 ORDER BY seg2 COLLATE NOCASE"
            if let result = db.executeQuery(q, withArgumentsIn: [name as Any]) {
                while result.next() {
                    let segs = result.int(forColumnIndex: 1)
                    let md5 = result.string(forColumn: "md5")
                    let seg2 = result.string(forColumn: "seg2")

                    if segs > 2 {
                        if let md5, let seg2 { cacheAlbumVC.listOfAlbums.add([md5, seg2]) }
                    } else {
                        if let md5 {
                            let track = result.int(forColumn: "track")
                            cacheAlbumVC.listOfSongs.add([md5, NSNumber(value: track)])

                            // Check for duplicate track numbers
                            var trackNumbers: [NSNumber] = []
                            var multipleSame = false
                            for item in cacheAlbumVC.listOfSongs {
                                if let arr = item as? NSArray, let t = arr.objectAtIndexSafe(1) as? NSNumber {
                                    if trackNumbers.contains(t) { multipleSame = true; break }
                                    trackNumbers.append(t)
                                }
                            }
                            if !multipleSame {
                                cacheAlbumVC.listOfSongs.sort(comparator: { a, b in
                                    let t1 = (a as? NSArray)?.objectAtIndexSafe(1) as? NSNumber ?? 0
                                    let t2 = (b as? NSArray)?.objectAtIndexSafe(1) as? NSNumber ?? 0
                                    if t1.intValue < t2.intValue { return .orderedAscending }
                                    if t1.intValue > t2.intValue { return .orderedDescending }
                                    return .orderedSame
                                })
                            }
                        }
                    }

                    if cacheAlbumVC.segments == nil {
                        cacheAlbumVC.segments = [name as Any]
                    }
                }
                result.close()
            }
        }

        pushViewControllerCustom(cacheAlbumVC)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let section = listOfArtistsSections.objectAtIndexSafe(UInt(indexPath.section)) as? NSArray
        let name = section?.objectAtIndexSafe(UInt(indexPath.row)) as? String ?? ""

        return SwipeAction.downloadQueueAndDeleteConfig(downloadHandler: nil, queueHandler: {
            ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
            EX2Dispatch.runInBackgroundAsync {
                var md5s: [String] = []
                Database.shared().songCacheDbQueue?.inDatabase { db in
                    if let result = db.executeQuery("SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ORDER BY seg2 COLLATE NOCASE", withArgumentsIn: [name]) {
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
        }, deleteHandler: {
            ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
            EX2Dispatch.runInBackgroundAsync {
                var md5s: [String] = []
                Database.shared().songCacheDbQueue?.inDatabase { db in
                    if let result = db.executeQuery("SELECT md5 FROM cachedSongsLayout WHERE seg1 = ?", withArgumentsIn: [name]) {
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
    }
}

// Safe subscript for arrays
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
