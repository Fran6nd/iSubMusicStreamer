//
//  CacheViewController.swift
//  iSub
//
//  Created by François Ganot on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(CacheViewController) final class CacheViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    var tableViewTopConstraint: NSLayoutConstraint!
    var segmentControlContainer: UIView!
    var segmentedControl: UISegmentedControl!
    var saveEditContainer: UIView?
    var songsCountLabel: UILabel?
    var deleteSongsButton: UIButton?
    var deleteSongsLabel: UILabel?
    var editSongsLabel: UILabel?
    var editSongsButton: UIButton?
    var isSaveEditShowing = false
    var playAllImage: UIImageView?
    var playAllLabel: UILabel?
    var playAllButton: UIButton?
    var shuffleImage: UIImageView?
    var shuffleLabel: UILabel?
    var shuffleButton: UIButton?
    var isNoSongsScreenShowing = false
    var noSongsScreen: UIImageView?
    var jukeboxInputBlocker: UIButton?
    var showIndex = false
    var listOfArtists: NSMutableArray = NSMutableArray()
    var listOfArtistsSections: NSMutableArray = NSMutableArray()
    var sectionInfo: [Any]?
    var cacheSizeLabel: UILabel?

    private var cacheQueueCount: Int = 0

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

    override func viewDidLoad() {
        super.viewDidLoad()

        cacheSizeLabel = nil
        jukeboxInputBlocker = nil
        isNoSongsScreenShowing = false
        isSaveEditShowing = false

        view.backgroundColor = UIColor(named: "isubBackgroundColor")

        segmentControlContainer = UIView()
        segmentControlContainer.translatesAutoresizingMaskIntoConstraints = false

        segmentedControl = UISegmentedControl(items: ["Cached", "Downloading"])
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addTarget(self, action: #selector(segmentAction(_:)), for: .valueChanged)
        segmentedControl.selectedSegmentIndex = 0

        segmentControlContainer.addSubview(segmentedControl)
        view.addSubview(segmentControlContainer)

        NSLayoutConstraint.activate([
            segmentControlContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 7),
            segmentControlContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 5),
            segmentControlContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -5),
            segmentControlContainer.heightAnchor.constraint(equalToConstant: 36),

            segmentedControl.topAnchor.constraint(equalTo: segmentControlContainer.topAnchor),
            segmentedControl.bottomAnchor.constraint(equalTo: segmentControlContainer.bottomAnchor),
            segmentedControl.leadingAnchor.constraint(equalTo: segmentControlContainer.leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: segmentControlContainer.trailingAnchor)
        ])

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableViewTopConstraint = tableView.topAnchor.constraint(equalTo: segmentControlContainer.bottomAnchor)
        NSLayoutConstraint.activate([
            tableViewTopConstraint,
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        tableView.backgroundColor = UIColor(named: "isubBackgroundColor")
        tableView.separatorStyle = .none
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.register(BlurredSectionHeader.self, forHeaderFooterViewReuseIdentifier: BlurredSectionHeader.reuseId)
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)

        title = "Cache"

        updateQueueDownloadProgress()

        NotificationCenter.addObserverOnMainThread(self, selector: #selector(addURLRefBackButton), name: UIApplication.didBecomeActiveNotification.rawValue)
    }

    @objc private func addURLRefBackButton() {
        if AppDelegate.shared().referringAppUrl != nil && AppDelegate.shared().mainTabBarController.selectedIndex != 4 {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: AppDelegate.shared(), action: #selector(AppDelegate.backToReferringApp))
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        registerForNotifications()
        reloadTable()
        updateQueueDownloadProgress()
        updateCacheSizeLabel()

        Flurry.logEvent("CacheTab")

        tableView.tableHeaderView?.isHidden = false
        segmentAction(nil)

        tableView.isScrollEnabled = true
        jukeboxInputBlocker?.removeFromSuperview()
        jukeboxInputBlocker = nil

        if Settings.shared().isJukeboxEnabled {
            tableView.isScrollEnabled = false
            let blocker = UIButton(type: .custom)
            blocker.frame = CGRect(x: 0, y: 0, width: 1004, height: 1004)
            let overlay = UIView(frame: blocker.frame)
            overlay.backgroundColor = .black
            overlay.alpha = 0.5
            blocker.addSubview(overlay)
            view.addSubview(blocker)
            jukeboxInputBlocker = blocker
        }

        addURLRefBackButton()

        navigationItem.rightBarButtonItem = nil
        if Music.shared().showPlayerIcon {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: Defines.musicNoteImageSystemName), style: .plain, target: self, action: #selector(nowPlayingAction(_:)))
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.tableHeaderView?.isHidden = false
        segmentAction(nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterForNotifications()
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateQueueDownloadProgress), object: nil)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateCacheSizeLabel), object: nil)
    }

    // MARK: - Notifications

    private func registerForNotifications() {
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadTable), name: ISMSNotification_StreamHandlerSongDownloaded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadTable), name: ISMSNotification_CacheQueueSongDownloaded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadTable), name: "cachedSongDeleted")
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(segmentAction(_:)), name: "kNetworkReachabilityChangedNotification")
    }

    private func unregisterForNotifications() {
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_StreamHandlerSongDownloaded)
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_CacheQueueSongDownloaded)
        NotificationCenter.removeObserverOnMainThread(self, name: "cachedSongDeleted")
        NotificationCenter.removeObserverOnMainThread(self, name: "kNetworkReachabilityChangedNotification")
    }

    // MARK: - Segment

    @objc func segmentAction(_ sender: Any?) {
        if segmentedControl.selectedSegmentIndex == 0 {
            if isEditing { editSongsAction(nil) }
            reloadTable()
            if listOfArtists.count == 0 {
                removeSaveEditButtons()
                addNoSongsScreen()
            } else {
                removeNoSongsScreen()
                addSaveEditButtons()
            }
        } else if segmentedControl.selectedSegmentIndex == 1 {
            if isEditing { editSongsAction(nil) }
            reloadTable()
            if cacheQueueCount > 0 {
                removeNoSongsScreen()
                addSaveEditButtons()
            }
        }
        tableView.reloadData()
    }

    // MARK: - Actions

    private func settingsAction(_ sender: Any?) {
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

        if Settings.shared().isJukeboxEnabled {
            Database.shared().resetJukeboxPlaylist()
            Jukebox.shared().clearRemotePlaylist()
        } else {
            Database.shared().resetCurrentPlaylistDb()
        }

        var md5s: [String] = []
        Database.shared().songCacheDbQueue?.inDatabase { db in
            if let result = db.executeQuery("SELECT md5 FROM cachedSongsLayout ORDER BY seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8, seg9 COLLATE NOCASE", withArgumentsIn: []) {
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
            Database.shared().shufflePlaylist()
        } else {
            PlayQueue.shared().isShuffle = false
        }

        if Settings.shared().isJukeboxEnabled {
            Jukebox.shared().playSong(atPosition: 0)
        }

        NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
        ViewObjects.shared().hideLoadingScreen()
        playAllPlaySong()
    }

    // MARK: - Data

    @objc func reloadTable() {
        if segmentedControl.selectedSegmentIndex == 0 {
            listOfArtists = NSMutableArray()
            listOfArtistsSections = NSMutableArray()

            Database.shared().songCacheDbQueue?.inDatabase { db in
                db.executeUpdate("DROP TABLE IF EXISTS cachedSongsArtistList", withArgumentsIn: [])
                db.executeUpdate("CREATE TEMP TABLE cachedSongsArtistList (artist TEXT UNIQUE)", withArgumentsIn: [])
                db.executeUpdate("INSERT OR IGNORE INTO cachedSongsArtistList SELECT seg1 FROM cachedSongsLayout", withArgumentsIn: [])

                if let result = db.executeQuery("SELECT artist FROM cachedSongsArtistList ORDER BY artist COLLATE NOCASE", withArgumentsIn: []) {
                    while result.next() {
                        autoreleasepool {
                            if let artist = result.string(forColumnIndex: 0), !artist.isEmpty {
                                self.listOfArtists.add(artist)
                            }
                        }
                    }
                    result.close()
                }

                self.listOfArtists.sort(comparator: { a, b in
                    let sa = a as? NSString ?? ""
                    let sb = b as? NSString ?? ""
                    return sa.caseInsensitiveCompareWithoutIndefiniteArticles(sb as String)
                })

                db.executeUpdate("DROP TABLE IF EXISTS cachedSongsArtistIndex", withArgumentsIn: [])
                db.executeUpdate("CREATE TEMP TABLE cachedSongsArtistIndex (artist TEXT)", withArgumentsIn: [])
                for artist in self.listOfArtists {
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

            var cachedSongsCount = 0
            Database.shared().songCacheDbQueue?.inDatabase { db in
                if let result = db.executeQuery("SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES' AND md5 != ''", withArgumentsIn: []) {
                    if result.next() { cachedSongsCount = Int(result.int(forColumnIndex: 0)) }
                    result.close()
                }
            }

            if cachedSongsCount == 0 {
                removeSaveEditButtons()
                addNoSongsScreen()
            } else {
                if isSaveEditShowing {
                    songsCountLabel?.text = cachedSongsCount == 1 ? "1 Song" : "\(cachedSongsCount) Songs"
                } else {
                    addSaveEditButtons()
                }
                removeNoSongsScreen()
            }
        } else {
            var count = 0
            Database.shared().cacheQueueDbQueue?.inDatabase { db in
                if let result = db.executeQuery("SELECT COUNT(*) FROM cacheQueue", withArgumentsIn: []) {
                    if result.next() { count = Int(result.int(forColumnIndex: 0)) }
                    result.close()
                }
            }
            cacheQueueCount = count

            if cacheQueueCount == 0 {
                removeSaveEditButtons()
                addNoSongsScreen()
            } else {
                if isSaveEditShowing {
                    songsCountLabel?.text = cacheQueueCount == 1 ? "1 Song" : "\(cacheQueueCount) Songs"
                } else {
                    addSaveEditButtons()
                }
                if isNoSongsScreenShowing { removeNoSongsScreen() }
            }
        }

        tableView.reloadData()
    }

    @objc func updateCacheSizeLabel() {
        if segmentedControl.selectedSegmentIndex == 0 {
            let size = Cache.shared().cacheSize
            cacheSizeLabel?.text = size <= 0 ? "" : NSString.formatFileSize(size)
        }

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateCacheSizeLabel), object: nil)
        perform(#selector(updateCacheSizeLabel), with: nil, afterDelay: 2.0)
    }

    @objc func updateQueueDownloadProgress() {
        if segmentedControl.selectedSegmentIndex == 1,
           let mgr = ISMSCacheQueueManager.sharedInstance(), mgr.isQueueDownloading {
            reloadTable()
        }
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateQueueDownloadProgress), object: nil)
        perform(#selector(updateQueueDownloadProgress), with: nil, afterDelay: 3.0)
    }

    // MARK: - Header

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

    // MARK: - Save/Edit button bar

    private func removeSaveEditButtons() {
        guard isSaveEditShowing else { return }
        isSaveEditShowing = false
        saveEditContainer?.removeFromSuperview(); saveEditContainer = nil
        songsCountLabel?.removeFromSuperview(); songsCountLabel = nil
        deleteSongsButton?.removeFromSuperview(); deleteSongsButton = nil
        editSongsLabel?.removeFromSuperview(); editSongsLabel = nil
        editSongsButton?.removeFromSuperview(); editSongsButton = nil
        deleteSongsLabel?.removeFromSuperview(); deleteSongsLabel = nil
        cacheSizeLabel?.removeFromSuperview(); cacheSizeLabel = nil
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateCacheSizeLabel), object: nil)
        tableView.tableHeaderView = nil
        tableViewTopConstraint.constant = 0
        tableView.setNeedsUpdateConstraints()
    }

    private func addSaveEditButtons() {
        removeSaveEditButtons()
        isSaveEditShowing = true

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        saveEditContainer = container

        let countLabel = UILabel()
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.textColor = .label
        countLabel.textAlignment = .center
        countLabel.font = .boldSystemFont(ofSize: 22)
        if segmentedControl.selectedSegmentIndex == 0 {
            var count = 0
            Database.shared().songCacheDbQueue?.inDatabase { db in
                if let result = db.executeQuery("SELECT COUNT(*) FROM cachedSongs WHERE finished = 'YES' AND md5 != ''", withArgumentsIn: []) {
                    if result.next() { count = Int(result.int(forColumnIndex: 0)) }
                    result.close()
                }
            }
            countLabel.text = count == 1 ? "1 Song" : "\(count) Songs"
        } else {
            countLabel.text = cacheQueueCount == 1 ? "1 Song" : "\(cacheQueueCount) Songs"
        }
        container.addSubview(countLabel)
        songsCountLabel = countLabel

        let sizeLabel = UILabel()
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        sizeLabel.textColor = .label
        sizeLabel.textAlignment = .center
        sizeLabel.font = .boldSystemFont(ofSize: 12)
        if segmentedControl.selectedSegmentIndex == 0 {
            let size = Cache.shared().cacheSize
            sizeLabel.text = size <= 0 ? "" : NSString.formatFileSize(size)
        } else {
            sizeLabel.text = ""
        }
        container.addSubview(sizeLabel)
        cacheSizeLabel = sizeLabel
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateCacheSizeLabel), object: nil)
        updateCacheSizeLabel()

        let delLabel = UILabel()
        delLabel.translatesAutoresizingMaskIntoConstraints = false
        delLabel.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.5)
        delLabel.textColor = .label
        delLabel.textAlignment = .center
        delLabel.font = .boldSystemFont(ofSize: 22)
        delLabel.adjustsFontSizeToFitWidth = true
        delLabel.minimumScaleFactor = 12.0 / delLabel.font.pointSize
        delLabel.text = "Delete # Songs"
        delLabel.isHidden = true
        container.addSubview(delLabel)
        deleteSongsLabel = delLabel

        let delButton = UIButton(type: .custom)
        delButton.translatesAutoresizingMaskIntoConstraints = false
        delButton.addTarget(self, action: #selector(deleteSongsAction(_:)), for: .touchUpInside)
        container.addSubview(delButton)
        deleteSongsButton = delButton

        let editLabel = UILabel()
        editLabel.translatesAutoresizingMaskIntoConstraints = false
        editLabel.textColor = .systemBlue
        editLabel.textAlignment = .center
        editLabel.font = .boldSystemFont(ofSize: 22)
        editLabel.text = "Edit"
        container.addSubview(editLabel)
        editSongsLabel = editLabel

        let editButton = UIButton(type: .custom)
        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.addTarget(self, action: #selector(editSongsAction(_:)), for: .touchUpInside)
        container.addSubview(editButton)
        editSongsButton = editButton

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalTo: view.widthAnchor),
            container.heightAnchor.constraint(equalToConstant: 50),
            container.topAnchor.constraint(equalTo: segmentControlContainer.bottomAnchor, constant: 8),

            countLabel.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.75),
            countLabel.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.666),
            countLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            countLabel.topAnchor.constraint(equalTo: container.topAnchor),

            sizeLabel.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.75),
            sizeLabel.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.333),
            sizeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sizeLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),

            delLabel.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.75),
            delLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            delLabel.topAnchor.constraint(equalTo: container.topAnchor),
            delLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            delButton.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.75),
            delButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            delButton.topAnchor.constraint(equalTo: container.topAnchor),
            delButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            editLabel.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.25),
            editLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            editLabel.topAnchor.constraint(equalTo: container.topAnchor),
            editLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            editButton.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.25),
            editButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            editButton.topAnchor.constraint(equalTo: container.topAnchor),
            editButton.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        tableViewTopConstraint.constant = 58
        tableView.setNeedsUpdateConstraints()

        if segmentedControl.selectedSegmentIndex == 0 { addHeader() }
    }

    // MARK: - No songs screen

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
        screen.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin, .flexibleRightMargin, .flexibleBottomMargin]
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
        label.text = segmentedControl.selectedSegmentIndex == 0 ? "No Cached\nSongs" : "No Queued\nSongs"
        label.frame = CGRect(x: 20, y: 20, width: 200, height: 140)
        screen.addSubview(label)

        view.addSubview(screen)
        noSongsScreen = screen

        if !UIDevice.isPad() && UIApplication.orientation().isLandscape {
            screen.transform = screen.transform.translatedBy(x: 0, y: 23)
        }
    }

    // MARK: - Edit/Delete

    private func showDeleteButton() {
        let count = tableView.indexPathsForSelectedRows?.count ?? 0
        if count == 0 {
            deleteSongsLabel?.text = "Select All"
        } else if count == 1 {
            deleteSongsLabel?.text = segmentedControl.selectedSegmentIndex == 0 ? "Delete 1 Folder  " : "Delete 1 Song  "
        } else {
            deleteSongsLabel?.text = segmentedControl.selectedSegmentIndex == 0
                ? "Delete \(count) Folders"
                : "Delete \(count) Songs"
        }
        songsCountLabel?.isHidden = true
        cacheSizeLabel?.isHidden = true
        deleteSongsLabel?.isHidden = false
    }

    private func hideDeleteButton() {
        if !isEditing {
            songsCountLabel?.isHidden = false
            cacheSizeLabel?.isHidden = false
            deleteSongsLabel?.isHidden = true
            return
        }
        let count = tableView.indexPathsForSelectedRows?.count ?? 0
        if count == 0 {
            deleteSongsLabel?.text = "Select All"
        } else if count == 1 {
            deleteSongsLabel?.text = segmentedControl.selectedSegmentIndex == 0 ? "Delete 1 Folder  " : "Delete 1 Song  "
        } else {
            deleteSongsLabel?.text = segmentedControl.selectedSegmentIndex == 0
                ? "Delete \(count) Folders"
                : "Delete \(count) Songs"
        }
    }

    @objc func editSongsAction(_ sender: Any?) {
        if segmentedControl.selectedSegmentIndex == 0 {
            if !isEditing {
                setEditing(true, animated: true)
                editSongsLabel?.backgroundColor = UIColor(red: 0.008, green: 0.46, blue: 0.933, alpha: 1)
                editSongsLabel?.textColor = .label
                editSongsLabel?.text = "Done"
                showDeleteButton()
            } else {
                setEditing(false, animated: true)
                hideDeleteButton()
                editSongsLabel?.backgroundColor = .clear
                editSongsLabel?.textColor = .systemBlue
                editSongsLabel?.text = "Edit"
                tableView.reloadData()
            }
        } else if segmentedControl.selectedSegmentIndex == 1 {
            if !tableView.isEditing {
                unregisterForNotifications()
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateQueueDownloadProgress), object: nil)
                setEditing(true, animated: true)
                editSongsLabel?.backgroundColor = UIColor(red: 0.008, green: 0.46, blue: 0.933, alpha: 1)
                editSongsLabel?.textColor = .label
                editSongsLabel?.text = "Done"
                showDeleteButton()
            } else {
                setEditing(false, animated: true)
                hideDeleteButton()
                editSongsLabel?.backgroundColor = .clear
                editSongsLabel?.textColor = .systemBlue
                editSongsLabel?.text = "Edit"
                registerForNotifications()
                updateQueueDownloadProgress()
                reloadTable()
            }
        }
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
    }

    private func deleteRowsAtIndexPaths(_ indexes: [IndexPath]) {
        do { tableView.deleteRows(at: indexes, with: .automatic) }
        if segmentedControl.selectedSegmentIndex == 0 { segmentAction(nil) }
    }

    private var selectedRowNames: [String] {
        guard segmentedControl.selectedSegmentIndex == 0 else { return [] }
        return tableView.indexPathsForSelectedRows?.compactMap { indexPath in
            (listOfArtistsSections.objectAtIndexSafe(UInt(indexPath.section)) as? NSArray)?.objectAtIndexSafe(UInt(indexPath.row)) as? String
        } ?? []
    }

    private var selectedRowMD5s: [String] {
        var result: [String] = []
        if segmentedControl.selectedSegmentIndex == 0 {
            for name in selectedRowNames {
                Database.shared().songCacheDbQueue?.inDatabase { db in
                    if let rs = db.executeQuery("SELECT md5 FROM cachedSongsLayout WHERE seg1 = ?", withArgumentsIn: [name]) {
                        while rs.next() {
                            if let md5 = rs.string(forColumnIndex: 0) { result.append(md5) }
                        }
                        rs.close()
                    }
                }
            }
        } else {
            for indexPath in tableView.indexPathsForSelectedRows ?? [] {
                Database.shared().cacheQueueDbQueue?.inDatabase { db in
                    if let rs = db.executeQuery("SELECT * FROM cacheQueue ORDER BY ROWID ASC LIMIT 1 OFFSET ?", withArgumentsIn: [indexPath.row]) {
                        if rs.next(), let md5 = rs.string(forColumn: "md5") { result.append(md5) }
                        rs.close()
                    }
                }
            }
        }
        return result
    }

    private func deleteCachedSongs() {
        unregisterForNotifications()
        for md5 in selectedRowMD5s {
            _ = Song.removeFromCacheDbQueue(byMD5: md5)
        }
        segmentAction(nil)
        Cache.shared().findCacheSize()
        ViewObjects.shared().hideLoadingScreen()
        if let mgr = ISMSCacheQueueManager.sharedInstance(), !mgr.isQueueDownloading {
            mgr.startDownloadQueue()
        }
        registerForNotifications()
    }

    private func deleteQueuedSongs() {
        unregisterForNotifications()
        for md5 in selectedRowMD5s {
            if let mgr = ISMSCacheQueueManager.sharedInstance(), mgr.isQueueDownloading {
                if let current = mgr.currentQueuedSong,
                   let path = current.path,
                   NSString.md5(path) == md5 {
                    mgr.stopDownloadQueue()
                }
            }
            Database.shared().cacheQueueDbQueue?.inDatabase { db in
                db.executeUpdate("DELETE FROM cacheQueue WHERE md5 = ?", withArgumentsIn: [md5])
            }
        }
        editSongsAction(nil)
        if let mgr = ISMSCacheQueueManager.sharedInstance(), !mgr.isQueueDownloading {
            mgr.startDownloadQueue()
        }
        ViewObjects.shared().hideLoadingScreen()
        registerForNotifications()
    }

    @objc private func deleteSongsAction(_ sender: Any?) {
        guard isEditing else { return }
        if deleteSongsLabel?.text == "Select All" {
            if segmentedControl.selectedSegmentIndex == 0 {
                for section in 0..<listOfArtistsSections.count {
                    let rowCount = (listOfArtistsSections[section] as? NSArray)?.count ?? 0
                    for row in 0..<rowCount {
                        tableView.selectRow(at: IndexPath(row: row, section: section), animated: false, scrollPosition: .none)
                    }
                }
            } else {
                for i in 0..<cacheQueueCount {
                    tableView.selectRow(at: IndexPath(row: i, section: 0), animated: false, scrollPosition: .none)
                }
            }
            showDeleteButton()
        } else {
            ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: "Deleting")
            if segmentedControl.selectedSegmentIndex == 0 {
                perform(#selector(deleteCachedSongsDeferred), with: nil, afterDelay: 0.05)
            } else {
                perform(#selector(deleteQueuedSongsDeferred), with: nil, afterDelay: 0.05)
            }
        }
    }

    @objc private func deleteCachedSongsDeferred() { deleteCachedSongs() }
    @objc private func deleteQueuedSongsDeferred() { deleteQueuedSongs() }

    // MARK: - Play all

    @objc func playAllPlaySong() {
        Music.shared().playSong(atPosition: 0)
        showPlayer()
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension CacheViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        segmentedControl.selectedSegmentIndex == 0 ? (sectionInfo?.count ?? 0) : 1
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard segmentedControl.selectedSegmentIndex == 0 && showIndex else { return nil }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: BlurredSectionHeader.reuseId) as! BlurredSectionHeader
        header.text = (sectionInfo?[section] as? NSArray)?.objectAtIndexSafe(0) as? String
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        segmentedControl.selectedSegmentIndex == 0 && showIndex ? Defines.rowHeight - 5 : 0
    }

    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        guard segmentedControl.selectedSegmentIndex == 0 && showIndex else { return nil }
        return sectionInfo?.compactMap { ($0 as? NSArray)?.objectAtIndexSafe(0) as? String }
    }

    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        if segmentedControl.selectedSegmentIndex == 0 {
            if index == 0 {
                tableView.scrollRectToVisible(CGRect(x: 0, y: 90, width: 320, height: 40), animated: false)
                return -1
            }
            return index
        }
        return -1
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        segmentedControl.selectedSegmentIndex == 0 ? Defines.rowHeight : Defines.tallRowHeight
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if segmentedControl.selectedSegmentIndex == 0 {
            return (listOfArtistsSections.objectAtIndexSafe(UInt(section)) as? NSArray)?.count ?? 0
        }
        return cacheQueueCount
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        if segmentedControl.selectedSegmentIndex == 0 {
            cell.hideHeaderLabel = true
            cell.hideCacheIndicator = true
            cell.hideNumberLabel = true
            cell.hideCoverArt = true
            cell.hideSecondaryLabel = true
            cell.hideDurationLabel = true
            let name = (listOfArtistsSections.objectAtIndexSafe(UInt(indexPath.section)) as? NSArray)?.objectAtIndexSafe(UInt(indexPath.row)) as? String ?? ""
            cell.update(model: Artist(name: name, andArtistId: ""))
        } else {
            cell.hideHeaderLabel = false
            cell.hideCacheIndicator = true
            cell.hideNumberLabel = true
            cell.hideCoverArt = false
            cell.hideSecondaryLabel = false
            cell.hideDurationLabel = false

            var song: Song?
            var cachedDate: Date?
            Database.shared().cacheQueueDbQueue?.inDatabase { db in
                if let result = db.executeQuery("SELECT * FROM cacheQueue ORDER BY ROWID ASC LIMIT 1 OFFSET ?", withArgumentsIn: [indexPath.row]) {
                    song = Song(fromDbResult: result)
                    cachedDate = Date(timeIntervalSince1970: result.double(forColumn: "cachedDate"))
                    result.close()
                }
            }

            cell.update(model: song)

            let dateStr = cachedDate.map { NSString.relativeTime($0) } ?? ""
            if indexPath.row == 0,
               let song, let mgr = ISMSCacheQueueManager.sharedInstance(),
               song.isEqual(to: mgr.currentQueuedSong) && mgr.isQueueDownloading {
                cell.headerText = "Added \(dateStr) - Progress: \(NSString.formatFileSize(mgr.currentQueuedSong?.localFileSize ?? 0))"
            } else if indexPath.row == 0 && (AppDelegate.shared().isWifi || Settings.shared().isManualCachingOnWWANEnabled) {
                cell.headerText = "Added \(dateStr) - Progress: Waiting..."
            } else if indexPath.row == 0 {
                cell.headerText = "Added \(dateStr) - Progress: Need Wifi"
            } else {
                cell.headerText = "Added \(dateStr) - Progress: Waiting..."
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { true }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        .delete
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !isEditing else { showDeleteButton(); return }
        guard segmentedControl.selectedSegmentIndex == 0 else { return }

        let section = listOfArtistsSections.objectAtIndexSafe(UInt(indexPath.section)) as? NSArray
        let name = section?.objectAtIndexSafe(UInt(indexPath.row)) as? String

        let cacheAlbumVC = CacheAlbumViewController()
        cacheAlbumVC.artistName = name
        cacheAlbumVC.listOfAlbums = NSMutableArray()
        cacheAlbumVC.listOfSongs = NSMutableArray()

        Database.shared().songCacheDbQueue?.inDatabase { db in
            let q = "SELECT md5, segs, seg2, track FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? GROUP BY seg2 ORDER BY seg2 COLLATE NOCASE"
            if let result = db.executeQuery(q, withArgumentsIn: [name as Any]) {
                while result.next() {
                    let numSegs = result.int(forColumnIndex: 1)
                    let md5 = result.string(forColumn: "md5")
                    let seg2 = result.string(forColumn: "seg2")

                    if numSegs > 2 {
                        if let md5, let seg2 { cacheAlbumVC.listOfAlbums.add([md5, seg2]) }
                    } else if let md5 {
                        let track = result.int(forColumn: "track")
                        cacheAlbumVC.listOfSongs.add([md5, NSNumber(value: track)])

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

                    if cacheAlbumVC.segments == nil { cacheAlbumVC.segments = [name as Any] }
                }
                result.close()
            }
        }

        pushViewControllerCustom(cacheAlbumVC)
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isEditing { hideDeleteButton() }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if segmentedControl.selectedSegmentIndex == 0 {
            let name = (listOfArtistsSections.objectAtIndexSafe(UInt(indexPath.section)) as? NSArray)?.objectAtIndexSafe(UInt(indexPath.row)) as? String ?? ""
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
        } else {
            var song: Song?
            Database.shared().cacheQueueDbQueue?.inDatabase { db in
                if let result = db.executeQuery("SELECT * FROM cacheQueue ORDER BY ROWID ASC LIMIT 1 OFFSET ?", withArgumentsIn: [indexPath.row]) {
                    song = Song(fromDbResult: result)
                    result.close()
                }
            }
            guard let song else { return nil }
            return SwipeAction.downloadQueueAndDeleteConfig(downloadHandler: nil, queueHandler: {
                song.addToCurrentPlaylistDbQueue()
            }, deleteHandler: { [weak self] in
                _ = song.removeFromCacheQueueDbQueue()
                self?.reloadTable()
            })
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
