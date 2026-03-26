//
//  BookmarksViewController.swift
//  iSub
//
//  Created by François Ganot on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(BookmarksViewController) final class BookmarksViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    var tableViewTopConstraint: NSLayoutConstraint!
    var isNoBookmarksScreenShowing = false
    var noBookmarksScreen: UIImageView?
    var isSaveEditShowing = false
    var saveEditContainer: UIView?
    var bookmarkCountLabel: UILabel?
    var deleteBookmarksButton: UIButton?
    var deleteBookmarksLabel: UILabel?
    var editBookmarksLabel: UILabel?
    var editBookmarksButton: UIButton?
    var bookmarkIds: NSMutableArray = NSMutableArray()

    // MARK: - Lifecycle

    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        isNoBookmarksScreenShowing = false

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableViewTopConstraint = tableView.topAnchor.constraint(equalTo: view.topAnchor)
        NSLayoutConstraint.activate([
            tableViewTopConstraint,
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        view.backgroundColor = UIColor(named: "isubBackgroundColor")
        title = "Bookmarks"

        if Settings.shared().isOfflineMode {
            navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gearshape.fill"), style: .plain, target: self, action: #selector(settingsAction(_:)))
        }

        tableView.allowsMultipleSelectionDuringEditing = true
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
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: Defines.musicNoteImageSystemName), style: .plain, target: self, action: #selector(nowPlayingAction(_:)))
        }

        tableView.tableHeaderView = nil

        if isNoBookmarksScreenShowing {
            noBookmarksScreen?.removeFromSuperview()
            isNoBookmarksScreenShowing = false
        }

        var bookmarksCount = 0
        Database.shared().bookmarksDbQueue?.inDatabase { db in
            if let result = db.executeQuery("SELECT COUNT(*) FROM bookmarks", withArgumentsIn: []) {
                if result.next() { bookmarksCount = Int(result.int(forColumnIndex: 0)) }
                result.close()
            }
        }
        if bookmarksCount == 0 {
            removeSaveEditButtons()

            isNoBookmarksScreenShowing = true
            let screen = UIImageView()
            screen.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin, .flexibleRightMargin, .flexibleBottomMargin]
            screen.frame = CGRect(x: 40, y: 100, width: 240, height: 180)
            screen.center = CGPoint(x: view.bounds.width / 2, y: view.bounds.height / 2)
            screen.image = UIImage(named: "loading-screen-image")
            screen.alpha = 0.80
            noBookmarksScreen = screen

            let textLabel = UILabel()
            textLabel.backgroundColor = .clear
            textLabel.textColor = .white
            textLabel.font = .boldSystemFont(ofSize: 30)
            textLabel.textAlignment = .center
            textLabel.numberOfLines = 0
            textLabel.text = Settings.shared().isOfflineMode ? "No Offline\nBookmarks" : "No Saved\nBookmarks"
            textLabel.frame = CGRect(x: 20, y: 20, width: 200, height: 140)
            screen.addSubview(textLabel)

            view.addSubview(screen)
        } else {
            addSaveEditButtons(Int(bookmarksCount))
        }

        loadBookmarkIds()
        tableView.reloadData()

        Flurry.logEvent("BookmarksTab")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        bookmarkIds = NSMutableArray()
    }

    // MARK: - Header buttons

    private func removeSaveEditButtons() {
        guard isSaveEditShowing else { return }
        isSaveEditShowing = false
        saveEditContainer?.removeFromSuperview(); saveEditContainer = nil
        bookmarkCountLabel?.removeFromSuperview(); bookmarkCountLabel = nil
        deleteBookmarksButton?.removeFromSuperview(); deleteBookmarksButton = nil
        editBookmarksLabel?.removeFromSuperview(); editBookmarksLabel = nil
        editBookmarksButton?.removeFromSuperview(); editBookmarksButton = nil
        deleteBookmarksLabel?.removeFromSuperview(); deleteBookmarksLabel = nil
        tableViewTopConstraint.constant = 0
        tableView.setNeedsUpdateConstraints()
    }

    private func addSaveEditButtons(_ bookmarksCount: Int) {
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
        countLabel.text = bookmarksCount == 1 ? "1 Bookmark" : "\(bookmarksCount) Bookmarks"
        container.addSubview(countLabel)
        bookmarkCountLabel = countLabel

        let delLabel = UILabel()
        delLabel.translatesAutoresizingMaskIntoConstraints = false
        delLabel.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.5)
        delLabel.textColor = .label
        delLabel.textAlignment = .center
        delLabel.font = .boldSystemFont(ofSize: 22)
        delLabel.adjustsFontSizeToFitWidth = true
        delLabel.minimumScaleFactor = 12.0 / delLabel.font.pointSize
        delLabel.text = "Remove # Bookmarks"
        delLabel.isHidden = true
        container.addSubview(delLabel)
        deleteBookmarksLabel = delLabel

        let delButton = UIButton(type: .custom)
        delButton.translatesAutoresizingMaskIntoConstraints = false
        delButton.addTarget(self, action: #selector(deleteBookmarksAction(_:)), for: .touchUpInside)
        container.addSubview(delButton)
        deleteBookmarksButton = delButton

        let editLabel = UILabel()
        editLabel.translatesAutoresizingMaskIntoConstraints = false
        editLabel.textColor = .systemBlue
        editLabel.textAlignment = .center
        editLabel.font = .boldSystemFont(ofSize: 22)
        editLabel.text = "Edit"
        container.addSubview(editLabel)
        editBookmarksLabel = editLabel

        let editButton = UIButton(type: .custom)
        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.addTarget(self, action: #selector(editBookmarksAction(_:)), for: .touchUpInside)
        container.addSubview(editButton)
        editBookmarksButton = editButton

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalTo: view.widthAnchor),
            container.heightAnchor.constraint(equalToConstant: 50),
            container.topAnchor.constraint(equalTo: view.topAnchor),

            countLabel.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.75),
            countLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            countLabel.topAnchor.constraint(equalTo: container.topAnchor),
            countLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),

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

        tableViewTopConstraint.constant = 50
        tableView.setNeedsUpdateConstraints()
    }

    // MARK: - Data

    private func loadBookmarkIds() {
        let temp = NSMutableArray()
        Database.shared().bookmarksDbQueue?.inDatabase { db in
            if let result = db.executeQuery("SELECT bookmarkId FROM bookmarks", withArgumentsIn: []) {
                while result.next() {
                    autoreleasepool {
                        if let bookmarkId = result.object(forColumnIndex: 0) as? NSNumber {
                            temp.add(bookmarkId)
                        }
                    }
                }
                result.close()
            }
        }
        bookmarkIds = temp
    }

    // MARK: - Editing helpers

    private func showDeleteButton() {
        let count = tableView.indexPathsForSelectedRows?.count ?? 0
        if count == 0 {
            deleteBookmarksLabel?.text = "Clear Bookmarks"
        } else if count == 1 {
            deleteBookmarksLabel?.text = "Remove 1 Bookmark"
        } else {
            deleteBookmarksLabel?.text = "Remove \(count) Bookmarks"
        }
        bookmarkCountLabel?.isHidden = true
        deleteBookmarksLabel?.isHidden = false
    }

    private func hideDeleteButton() {
        let count = tableView.indexPathsForSelectedRows?.count ?? 0
        if count == 0 {
            if !isEditing {
                bookmarkCountLabel?.isHidden = false
                deleteBookmarksLabel?.isHidden = true
            } else {
                deleteBookmarksLabel?.text = "Clear Bookmarks"
            }
        } else if count == 1 {
            deleteBookmarksLabel?.text = "Remove 1 Bookmark"
        } else {
            deleteBookmarksLabel?.text = "Remove \(count) Bookmarks"
        }
    }

    private var selectedRowIndexes: [Int] {
        return tableView.indexPathsForSelectedRows?.map { $0.row } ?? []
    }

    // MARK: - Actions

    @objc private func editBookmarksAction(_ sender: Any?) {
        if !isEditing {
            setEditing(true, animated: true)
            editBookmarksLabel?.backgroundColor = UIColor(red: 0.008, green: 0.46, blue: 0.933, alpha: 1)
            editBookmarksLabel?.textColor = .label
            editBookmarksLabel?.text = "Done"
            showDeleteButton()
        } else {
            setEditing(false, animated: true)
            hideDeleteButton()
            editBookmarksLabel?.backgroundColor = .clear
            editBookmarksLabel?.textColor = .systemBlue
            editBookmarksLabel?.text = "Edit"
            viewWillAppear(false)
        }
    }

    @objc private func deleteBookmarksAction(_ sender: Any?) {
        if deleteBookmarksLabel?.text == "Clear Bookmarks" {
            for i in 0..<bookmarkIds.count {
                tableView.selectRow(at: IndexPath(row: i, section: 0), animated: false, scrollPosition: .none)
            }
            showDeleteButton()
        } else {
            let sortedIndexes = selectedRowIndexes.sorted()
            for index in sortedIndexes {
                if let bookmarkId = bookmarkIds.object(at: index) as? NSNumber {
                    Database.shared().bookmarksDbQueue?.inDatabase { db in
                        db.executeUpdate("DELETE FROM bookmarks WHERE bookmarkId = ?", withArgumentsIn: [bookmarkId])
                    }
                }
            }
            for index in sortedIndexes.reversed() {
                bookmarkIds.removeObject(at: index)
            }
            do {
                if let selectedPaths = tableView.indexPathsForSelectedRows {
                    tableView.deleteRows(at: selectedPaths, with: .right)
                }
            }
            editBookmarksAction(nil)
        }
    }

    @objc private func settingsAction(_ sender: Any?) {
        let serverListVC = ServerListViewController(nibName: "ServerListViewController", bundle: nil)
        serverListVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(serverListVC, animated: true)
    }

    @IBAction private func nowPlayingAction(_ sender: Any) {
        let playerVC = PlayerViewController()
        playerVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(playerVC, animated: true)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension BookmarksViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        bookmarkIds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var song: Song?
        var name: String?
        var position: Int = 0
        Database.shared().bookmarksDbQueue?.inDatabase { db in
            if let result = db.executeQuery("SELECT * FROM bookmarks WHERE bookmarkId = ?",
                                            withArgumentsIn: [self.bookmarkIds.objectAtIndexSafe(UInt(indexPath.row)) as Any]) {
                song = Song(fromDbResult: result)
                name = result.string(forColumn: "name")
                position = Int(result.int(forColumn: "position"))
                result.close()
            }
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        cell.hideHeaderLabel = false
        cell.hideNumberLabel = true
        cell.headerText = "\(name ?? "") - \(NSString.formatTime(Double(position)) ?? "")"
        cell.update(model: song)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditing {
            showDeleteButton()
            return
        }

        if Settings.shared().isJukeboxEnabled {
            Database.shared().resetJukeboxPlaylist()
            Jukebox.shared().clearRemotePlaylist()
        } else {
            Database.shared().resetCurrentPlaylistDb()
        }
        PlayQueue.shared().isShuffle = false

        var bookmarkId: Int = 0
        var playlistIndex: Int = 0
        var offsetSeconds: Int = 0
        var offsetBytes: Int = 0
        var aSong: Song?

        Database.shared().bookmarksDbQueue?.inDatabase { db in
            if let result = db.executeQuery("SELECT * FROM bookmarks WHERE bookmarkId = ?",
                                            withArgumentsIn: [self.bookmarkIds.objectAtIndexSafe(UInt(indexPath.row)) as Any]) {
                aSong = Song(fromDbResult: result)
                bookmarkId = Int(result.int(forColumn: "bookmarkId"))
                playlistIndex = Int(result.int(forColumn: "playlistIndex"))
                offsetSeconds = Int(result.int(forColumn: "position"))
                offsetBytes = Int(result.int(forColumn: "bytes"))
                result.close()
            }
        }

        let bookmarkTableName = "bookmark\(bookmarkId)"
        if Database.shared().bookmarksDbQueue?.tableExists(bookmarkTableName) == true {
            let databaseName = Settings.shared().isOfflineMode
                ? "offlineCurrentPlaylist.db"
                : "\(NSString.md5(Settings.shared().urlString ?? ""))currentPlaylist.db"
            let currTable = Settings.shared().isJukeboxEnabled ? "jukeboxCurrentPlaylist" : "currentPlaylist"
            let shufTable = Settings.shared().isJukeboxEnabled ? "jukeboxShufflePlaylist" : "shufflePlaylist"
            let table = PlayQueue.shared().isShuffle ? shufTable : currTable

            Database.shared().bookmarksDbQueue?.inDatabase { db in
                let dbPath = (Database.shared().databaseFolderPath as NSString).appendingPathComponent(databaseName)
                db.executeUpdate("ATTACH DATABASE ? AS ?", withArgumentsIn: [dbPath, "currentPlaylistDb"])
                db.executeUpdate("INSERT INTO currentPlaylistDb.\(table) SELECT * FROM \(bookmarkTableName)", withArgumentsIn: [])
                db.executeUpdate("DETACH DATABASE currentPlaylistDb", withArgumentsIn: [])
            }

            if Settings.shared().isJukeboxEnabled {
                Jukebox.shared().replacePlaylistWithLocal()
            }
        } else {
            aSong?.addToCurrentPlaylistDbQueue()
        }

        PlayQueue.shared().currentIndex = playlistIndex

        NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)

        if offsetBytes == 0 && offsetSeconds != 0 {
            var bitrate = aSong?.bitRate?.intValue ?? 0
            if aSong?.transcodedSuffix != nil {
                let maxBitrate = Settings.shared().currentMaxBitrate == 0 ? 128 : Int(Settings.shared().currentMaxBitrate)
                bitrate = min(maxBitrate, bitrate)
            }
            offsetBytes = (bitrate / 8) * 1024 * offsetSeconds
        }

        if Settings.shared().isJukeboxEnabled {
            Music.shared().playSong(atPosition: playlistIndex)
        } else {
            Music.shared().startSongAtOffset(inBytes: UInt64(offsetBytes), andSeconds: Double(offsetSeconds))
        }
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isEditing {
            hideDeleteButton()
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { true }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        .delete
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        var song: Song?
        Database.shared().bookmarksDbQueue?.inDatabase { db in
            if let result = db.executeQuery("SELECT * FROM bookmarks WHERE bookmarkId = ?",
                                            withArgumentsIn: [self.bookmarkIds.objectAtIndexSafe(UInt(indexPath.row)) as Any]) {
                song = Song(fromDbResult: result)
                result.close()
            }
        }
        guard let song else { return nil }
        return SwipeAction.downloadQueueAndDeleteConfig(model: song) { [weak self] in
            guard let self else { return }
            Database.shared().bookmarksDbQueue?.inDatabase { db in
                db.executeUpdate("DELETE FROM bookmarks WHERE bookmarkId = ?",
                                 withArgumentsIn: [self.bookmarkIds.object(at: indexPath.row)])
            }
            bookmarkIds.removeObject(at: indexPath.row)
            do {
                tableView.deleteRows(at: [indexPath], with: .right)
            }
        }
    }
}
