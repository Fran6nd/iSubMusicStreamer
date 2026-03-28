//
//  CurrentPlaylistViewController.swift
//  iSub
//
//  Created by François Navarro on 2026-03-28.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

final class CurrentPlaylistViewController: UIViewController {

    // MARK: - Properties

    var savePlaylistLocal = false
    var currentPlaylistCount: Int = 0

    private let saveEditContainer = UIView()
    private let savePlaylistLabel = UILabel()
    private let deleteSongsLabel = UILabel()
    private let playlistCountLabel = UILabel()
    private let savePlaylistButton = UIButton(type: .custom)
    private let editPlaylistLabel = UILabel()
    private let editPlaylistButton = UIButton(type: .custom)
    private let tableView = UITableView()

    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Notifications

    private func registerForNotifications() {
        let center = NotificationCenter.default
        let names: [String] = [
            ISMSNotification_BassInitialized,
            ISMSNotification_BassFreed,
            ISMSNotification_CurrentPlaylistIndexChanged,
            ISMSNotification_CurrentPlaylistShuffleToggled,
            ISMSNotification_JukeboxSongInfo,
            ISMSNotification_CurrentPlaylistSongsQueued,
            "updateCurrentPlaylistCount",
        ]
        for name in names {
            let observer = center.addObserver(forName: NSNotification.Name(rawValue: name), object: nil, queue: .main) { [weak self] notification in
                self?.handleNotification(notification)
            }
            notificationObservers.append(observer)
        }
    }

    private func unregisterForNotifications() {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers.removeAll()
    }

    private func handleNotification(_ notification: Notification) {
        let name = notification.name.rawValue
        if name == ISMSNotification_JukeboxSongInfo {
            jukeboxSongInfo()
        } else if name == ISMSNotification_CurrentPlaylistSongsQueued {
            songsQueued()
        } else {
            selectRow()
        }
    }

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(named: "isubBackgroundColor")
        title = "Play Queue"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissAction(_:)))

        registerForNotifications()

        // Save/Edit header container
        saveEditContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(saveEditContainer)

        savePlaylistLabel.translatesAutoresizingMaskIntoConstraints = false
        savePlaylistLabel.textColor = .label
        savePlaylistLabel.textAlignment = .center
        savePlaylistLabel.font = .boldSystemFont(ofSize: 22)
        savePlaylistLabel.text = "Save Playlist"
        saveEditContainer.addSubview(savePlaylistLabel)

        playlistCountLabel.translatesAutoresizingMaskIntoConstraints = false
        playlistCountLabel.textColor = .label
        playlistCountLabel.textAlignment = .center
        playlistCountLabel.font = .boldSystemFont(ofSize: 12)
        saveEditContainer.addSubview(playlistCountLabel)
        updateCurrentPlaylistCount()

        deleteSongsLabel.translatesAutoresizingMaskIntoConstraints = false
        deleteSongsLabel.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.5)
        deleteSongsLabel.textColor = .label
        deleteSongsLabel.textAlignment = .center
        deleteSongsLabel.font = .boldSystemFont(ofSize: 22)
        deleteSongsLabel.adjustsFontSizeToFitWidth = true
        deleteSongsLabel.minimumScaleFactor = 12.0 / deleteSongsLabel.font.pointSize
        deleteSongsLabel.text = "Remove # Songs"
        deleteSongsLabel.isHidden = true
        saveEditContainer.addSubview(deleteSongsLabel)

        savePlaylistButton.translatesAutoresizingMaskIntoConstraints = false
        savePlaylistButton.addTarget(self, action: #selector(savePlaylistAction(_:)), for: .touchUpInside)
        saveEditContainer.addSubview(savePlaylistButton)

        editPlaylistLabel.translatesAutoresizingMaskIntoConstraints = false
        editPlaylistLabel.textColor = .systemBlue
        editPlaylistLabel.textAlignment = .center
        editPlaylistLabel.font = .boldSystemFont(ofSize: 22)
        editPlaylistLabel.text = "Edit"
        saveEditContainer.addSubview(editPlaylistLabel)

        editPlaylistButton.translatesAutoresizingMaskIntoConstraints = false
        editPlaylistButton.addTarget(self, action: #selector(editPlaylistAction(_:)), for: .touchUpInside)
        saveEditContainer.addSubview(editPlaylistButton)

        NSLayoutConstraint.activate([
            saveEditContainer.widthAnchor.constraint(equalTo: view.widthAnchor),
            saveEditContainer.heightAnchor.constraint(equalToConstant: 50),
            saveEditContainer.topAnchor.constraint(equalTo: view.topAnchor),

            savePlaylistLabel.widthAnchor.constraint(equalTo: saveEditContainer.widthAnchor, multiplier: 0.75),
            savePlaylistLabel.heightAnchor.constraint(equalTo: saveEditContainer.heightAnchor, multiplier: 0.666),
            savePlaylistLabel.leadingAnchor.constraint(equalTo: saveEditContainer.leadingAnchor),
            savePlaylistLabel.topAnchor.constraint(equalTo: saveEditContainer.topAnchor),

            playlistCountLabel.widthAnchor.constraint(equalTo: saveEditContainer.widthAnchor, multiplier: 0.75),
            playlistCountLabel.heightAnchor.constraint(equalTo: saveEditContainer.heightAnchor, multiplier: 0.333),
            playlistCountLabel.leadingAnchor.constraint(equalTo: saveEditContainer.leadingAnchor),
            playlistCountLabel.bottomAnchor.constraint(equalTo: saveEditContainer.bottomAnchor, constant: -4),

            deleteSongsLabel.widthAnchor.constraint(equalTo: saveEditContainer.widthAnchor, multiplier: 0.75),
            deleteSongsLabel.leadingAnchor.constraint(equalTo: saveEditContainer.leadingAnchor),
            deleteSongsLabel.topAnchor.constraint(equalTo: saveEditContainer.topAnchor),
            deleteSongsLabel.bottomAnchor.constraint(equalTo: saveEditContainer.bottomAnchor),

            savePlaylistButton.widthAnchor.constraint(equalTo: saveEditContainer.widthAnchor, multiplier: 0.75),
            savePlaylistButton.leadingAnchor.constraint(equalTo: saveEditContainer.leadingAnchor),
            savePlaylistButton.topAnchor.constraint(equalTo: saveEditContainer.topAnchor),
            savePlaylistButton.bottomAnchor.constraint(equalTo: saveEditContainer.bottomAnchor),

            editPlaylistLabel.widthAnchor.constraint(equalTo: saveEditContainer.widthAnchor, multiplier: 0.25),
            editPlaylistLabel.trailingAnchor.constraint(equalTo: saveEditContainer.trailingAnchor),
            editPlaylistLabel.topAnchor.constraint(equalTo: saveEditContainer.topAnchor),
            editPlaylistLabel.bottomAnchor.constraint(equalTo: saveEditContainer.bottomAnchor),

            editPlaylistButton.widthAnchor.constraint(equalTo: saveEditContainer.widthAnchor, multiplier: 0.25),
            editPlaylistButton.trailingAnchor.constraint(equalTo: saveEditContainer.trailingAnchor),
            editPlaylistButton.topAnchor.constraint(equalTo: saveEditContainer.topAnchor),
            editPlaylistButton.bottomAnchor.constraint(equalTo: saveEditContainer.bottomAnchor),
        ])

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor(named: "isubBackgroundColor")
        tableView.separatorStyle = .none
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: saveEditContainer.bottomAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)
        tableView.rowHeight = Defines.rowHeight
        tableView.reloadData()

        selectRow()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        selectRow()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterForNotifications()
        if isEditing { setEditing(false, animated: true) }
    }

    // MARK: - Notification handlers

    private func jukeboxSongInfo() {
        updateCurrentPlaylistCount()
        tableView.reloadData()
        selectRow()
    }

    private func songsQueued() {
        updateCurrentPlaylistCount()
        tableView.reloadData()
    }

    func updateCurrentPlaylistCount() {
        currentPlaylistCount = Int(PlayQueue.shared().count)
        playlistCountLabel.text = currentPlaylistCount == 1 ? "1 song" : "\(currentPlaylistCount) songs"
    }

    // MARK: - Actions

    @objc private func editPlaylistAction(_ sender: Any?) {
        if isEditing {
            setEditing(false, animated: true)
            hideDeleteButton()
            editPlaylistLabel.backgroundColor = .clear
            editPlaylistLabel.textColor = .systemBlue
            editPlaylistLabel.text = "Edit"
            tableView.reloadData()
            let idx = Int(PlayQueue.shared().currentIndex)
            if idx >= 0 && idx < currentPlaylistCount {
                tableView.selectRow(at: IndexPath(row: idx, section: 0), animated: false, scrollPosition: .top)
            }
        } else {
            for i in 0..<currentPlaylistCount {
                tableView.deselectRow(at: IndexPath(row: i, section: 0), animated: false)
            }
            setEditing(true, animated: true)
            editPlaylistLabel.backgroundColor = UIColor(red: 0.008, green: 0.46, blue: 0.933, alpha: 1)
            editPlaylistLabel.textColor = .label
            editPlaylistLabel.text = "Done"
            showDeleteButton()
        }
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
    }

    func hideEditControls() {
        if isEditing { editPlaylistAction(nil) }
    }

    func showDeleteButton() {
        let count = tableView.indexPathsForSelectedRows?.count ?? 0
        if count == 0 {
            deleteSongsLabel.text = "Clear Playlist"
        } else if count == 1 {
            deleteSongsLabel.text = "Remove 1 Song  "
        } else {
            deleteSongsLabel.text = "Remove \(count) Songs"
        }
        savePlaylistLabel.isHidden = true
        playlistCountLabel.isHidden = true
        deleteSongsLabel.isHidden = false
    }

    func hideDeleteButton() {
        guard isEditing else {
            savePlaylistLabel.isHidden = false
            playlistCountLabel.isHidden = false
            deleteSongsLabel.isHidden = true
            return
        }
        let count = tableView.indexPathsForSelectedRows?.count ?? 0
        if count == 0 {
            deleteSongsLabel.text = "Clear Playlist"
        } else if count == 1 {
            deleteSongsLabel.text = "Remove 1 Song  "
        } else {
            deleteSongsLabel.text = "Remove \(count) Songs"
        }
    }

    @objc private func savePlaylistAction(_ sender: Any?) {
        if deleteSongsLabel.isHidden {
            guard !isEditing else { return }
            if Settings.shared().isOfflineMode {
                showSavePlaylistAlert()
            } else {
                let alert = UIAlertController(title: "Playlist Location",
                                             message: "Would you like to save this playlist to your device or to your Subsonic server?",
                                             preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Local", style: .default) { [weak self] _ in
                    self?.savePlaylistLocal = true
                    self?.showSavePlaylistAlert()
                })
                alert.addAction(UIAlertAction(title: "Server", style: .default) { [weak self] _ in
                    self?.savePlaylistLocal = false
                    self?.showSavePlaylistAlert()
                })
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                present(alert, animated: true)
            }
        } else {
            let selectedIndexes = (tableView.indexPathsForSelectedRows ?? []).map { $0.row }
            unregisterForNotifications()

            if selectedIndexes.isEmpty {
                for i in 0..<currentPlaylistCount {
                    tableView.selectRow(at: IndexPath(row: i, section: 0), animated: false, scrollPosition: .none)
                }
                showDeleteButton()
            } else {
                PlayQueue.shared().deleteSongs(selectedIndexes as [Any])
                updateCurrentPlaylistCount()
                if let toDelete = tableView.indexPathsForSelectedRows {
                    tableView.deleteRows(at: toDelete, with: .automatic)
                }
                updateTableCellNumbers()
                editPlaylistAction(nil)
            }

            let songCount = Int(PlayQueue.shared().count)
            playlistCountLabel.text = songCount == 1 ? "1 song" : "\(songCount) songs"

            if !Settings.shared().isJukeboxEnabled {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: ISMSNotification_CurrentPlaylistOrderChanged), object: nil)
            }
            registerForNotifications()
        }
    }

    @objc private func dismissAction(_ sender: Any?) {
        if navigationController != nil {
            navigationController?.dismiss(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    func selectRow() {
        tableView.reloadData()
        let idx = Int(PlayQueue.shared().currentIndex)
        if idx >= 0 && idx < currentPlaylistCount {
            tableView.selectRow(at: IndexPath(row: idx, section: 0), animated: false, scrollPosition: .top)
        }
    }

    // MARK: - Playlist upload

    private func uploadPlaylist(name: String) {
        var parameters: [String: Any] = ["name": name]
        var songIds = [String]()
        let playlist = PlayQueue.shared()!
        let settings = Settings.shared()!
        let database = Database.shared()!
        let currTable = settings.isJukeboxEnabled ? "jukeboxCurrentPlaylist" : "currentPlaylist"
        let shufTable = settings.isJukeboxEnabled ? "jukeboxShufflePlaylist" : "shufflePlaylist"
        let table = playlist.isShuffle ? shufTable : currTable

        database.currentPlaylistDbQueue?.inDatabase { db in
            for i in 0..<self.currentPlaylistCount {
                autoreleasepool {
                    if let song = Song.songFromDbRow(UInt(i), inTable: table, inDatabase: db) {
                        songIds.append(song.songId ?? "")
                    }
                }
            }
        }
        parameters["songId"] = songIds

        let request = NSMutableURLRequest.request(withSUSAction: "createPlaylist", parameters: parameters)
        let task = SUSLoader.sharedSession().dataTask(with: request as URLRequest) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error = error {
                    if settings.isPopupsEnabled {
                        let msg = "There was an error saving the playlist to the server.\n\nError \(error._code): \(error.localizedDescription)"
                        let alert = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
                        self.present(alert, animated: true)
                    }
                } else if let data = data {
                    let root = RXMLElement(fromXMLData: data)
                    if root?.isValid == false {
                        self.subsonicError(code: nil, message: "Not valid XML")
                    } else if let errorEl = root?.child("error"), errorEl.isValid {
                        self.subsonicError(code: errorEl.attribute("code"), message: errorEl.attribute("message"))
                    }
                }
                self.tableView.isScrollEnabled = true
                ViewObjects.shared().hideLoadingScreen()
            }
        }
        task?.resume()

        tableView.isScrollEnabled = false
        ViewObjects.shared().showAlbumLoadingScreen(view, sender: self)
    }

    private func subsonicError(code: String?, message: String?) {
        DDLogError("[CurrentPlaylistViewController] subsonic error \(code ?? ""): \(message ?? "")")
        guard Settings.shared().isPopupsEnabled else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let alert = UIAlertController(title: "Subsonic Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            self.present(alert, animated: true)
        }
    }

    private func showSavePlaylistAlert() {
        let alert = UIAlertController(title: "Save Playlist", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Playlist name" }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self else { return }
            let name = alert.textFields?.first?.text ?? ""
            let settings = Settings.shared()!
            let database = Database.shared()!
            if self.savePlaylistLocal || settings.isOfflineMode {
                let test = database.localPlaylistsDbQueue?.string(forQuery: "SELECT md5 FROM localPlaylists WHERE md5 = ?", name.md5)
                if test != nil {
                    self.showOverwritePlaylistAlert(name: name)
                } else {
                    let dbName = settings.isOfflineMode ? "offlineCurrentPlaylist.db" : "\(settings.urlString.md5)currentPlaylist.db"
                    let playlist = PlayQueue.shared()!
                    let currTable = settings.isJukeboxEnabled ? "jukeboxCurrentPlaylist" : "currentPlaylist"
                    let shufTable = settings.isJukeboxEnabled ? "jukeboxShufflePlaylist" : "shufflePlaylist"
                    let table = playlist.isShuffle ? shufTable : currTable
                    database.localPlaylistsDbQueue?.inDatabase { db in
                        db.executeUpdate("INSERT INTO localPlaylists (playlist, md5) VALUES (?, ?)", withArgumentsIn: [name, name.md5])
                        db.executeUpdate("CREATE TABLE playlist\(name.md5) (\(Song.standardSongColumnSchema() ?? ""))", withArgumentsIn: [])
                        let dbPath = (database.databaseFolderPath as NSString).appendingPathComponent(dbName)
                        db.executeUpdate("ATTACH DATABASE ? AS ?", withArgumentsIn: [dbPath, "currentPlaylistDb"])
                        if db.hadError() { DDLogError("[CurrentPlaylistViewController] Err attaching currentPlaylistDb \(db.lastErrorCode()): \(db.lastErrorMessage() ?? "")") }
                        db.executeUpdate("INSERT INTO playlist\(name.md5) SELECT * FROM \(table)", withArgumentsIn: [])
                        db.executeUpdate("DETACH DATABASE currentPlaylistDb", withArgumentsIn: [])
                    }
                }
            } else {
                let tableName = "splaylist\(name.md5)"
                if database.localPlaylistsDbQueue?.tableExists(tableName) == true {
                    self.showOverwritePlaylistAlert(name: name)
                } else {
                    self.uploadPlaylist(name: name)
                }
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showOverwritePlaylistAlert(name: String) {
        let alert = UIAlertController(title: "Overwrite?",
                                      message: "A playlist named \"\(name)\" already exists. Would you like to overwrite it?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Overwrite", style: .destructive) { [weak self] _ in
            guard let self else { return }
            let settings = Settings.shared()!
            let database = Database.shared()!
            if self.savePlaylistLocal || settings.isOfflineMode {
                let dbName = settings.isOfflineMode ? "offlineCurrentPlaylist.db" : "\(settings.urlString.md5)currentPlaylist.db"
                let playlist = PlayQueue.shared()!
                let currTable = settings.isJukeboxEnabled ? "jukeboxCurrentPlaylist" : "currentPlaylist"
                let shufTable = settings.isJukeboxEnabled ? "jukeboxShufflePlaylist" : "shufflePlaylist"
                let table = playlist.isShuffle ? shufTable : currTable
                database.localPlaylistsDbQueue?.inDatabase { db in
                    db.executeUpdate("DROP TABLE playlist\(name.md5)", withArgumentsIn: [])
                    db.executeUpdate("CREATE TABLE playlist\(name.md5) (\(Song.standardSongColumnSchema() ?? ""))", withArgumentsIn: [])
                    let dbPath = (database.databaseFolderPath as NSString).appendingPathComponent(dbName)
                    db.executeUpdate("ATTACH DATABASE ? AS ?", withArgumentsIn: [dbPath, "currentPlaylistDb"])
                    if db.hadError() { DDLogError("[CurrentPlaylistViewController] Err attaching currentPlaylistDb \(db.lastErrorCode()): \(db.lastErrorMessage() ?? "")") }
                    db.executeUpdate("INSERT INTO playlist\(name.md5) SELECT * FROM \(table)", withArgumentsIn: [])
                    db.executeUpdate("DETACH DATABASE currentPlaylistDb", withArgumentsIn: [])
                }
            } else {
                database.localPlaylistsDbQueue?.inDatabase { db in
                    db.executeUpdate("DROP TABLE splaylist\(name.md5)", withArgumentsIn: [])
                }
                self.uploadPlaylist(name: name)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func updateTableCellNumbers() {
        for indexPath in tableView.indexPathsForVisibleRows ?? [] {
            let cell = tableView.cellForRow(at: indexPath) as? UniversalTableViewCell
            cell?.number = indexPath.row + 1
        }
    }
}

// MARK: - UITableViewDataSource / UITableViewDelegate

extension CurrentPlaylistViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        currentPlaylistCount
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        let playlist = PlayQueue.shared()!
        let settings = Settings.shared()!
        let database = Database.shared()!
        let song: Song?
        if settings.isJukeboxEnabled {
            let table = playlist.isShuffle ? "jukeboxShufflePlaylist" : "jukeboxCurrentPlaylist"
            song = Song.songFromDbRow(UInt(indexPath.row), inTable: table, inDatabaseQueue: database.currentPlaylistDbQueue)
        } else {
            let table = playlist.isShuffle ? "shufflePlaylist" : "currentPlaylist"
            song = Song.songFromDbRow(UInt(indexPath.row), inTable: table, inDatabaseQueue: database.currentPlaylistDbQueue)
        }
        cell.number = indexPath.row + 1
        cell.update(model: song)
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { true }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle { .delete }

    func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to toIndexPath: IndexPath) {
        let fromRow = fromIndexPath.row + 1
        let toRow = toIndexPath.row + 1
        let settings = Settings.shared()!
        let database = Database.shared()!
        let playlist = PlayQueue.shared()!
        let currTable = settings.isJukeboxEnabled ? "jukeboxCurrentPlaylist" : "currentPlaylist"
        let shufTable = settings.isJukeboxEnabled ? "jukeboxShufflePlaylist" : "shufflePlaylist"
        let table = playlist.isShuffle ? shufTable : currTable

        database.currentPlaylistDbQueue?.inDatabase { db in
            db.executeUpdate("DROP TABLE moveTemp", withArgumentsIn: [])
            db.executeUpdate("CREATE TABLE moveTemp (\(Song.standardSongColumnSchema() ?? ""))", withArgumentsIn: [])
            if fromRow < toRow {
                db.executeUpdate("INSERT INTO moveTemp SELECT * FROM \(table) WHERE ROWID < ?", withArgumentsIn: [fromRow])
                db.executeUpdate("INSERT INTO moveTemp SELECT * FROM \(table) WHERE ROWID > ? AND ROWID <= ?", withArgumentsIn: [fromRow, toRow])
                db.executeUpdate("INSERT INTO moveTemp SELECT * FROM \(table) WHERE ROWID = ?", withArgumentsIn: [fromRow])
                db.executeUpdate("INSERT INTO moveTemp SELECT * FROM \(table) WHERE ROWID > ?", withArgumentsIn: [toRow])
            } else {
                db.executeUpdate("INSERT INTO moveTemp SELECT * FROM \(table) WHERE ROWID < ?", withArgumentsIn: [toRow])
                db.executeUpdate("INSERT INTO moveTemp SELECT * FROM \(table) WHERE ROWID = ?", withArgumentsIn: [fromRow])
                db.executeUpdate("INSERT INTO moveTemp SELECT * FROM \(table) WHERE ROWID >= ? AND ROWID < ?", withArgumentsIn: [toRow, fromRow])
                db.executeUpdate("INSERT INTO moveTemp SELECT * FROM \(table) WHERE ROWID > ?", withArgumentsIn: [fromRow])
            }
            db.executeUpdate("DROP TABLE \(table)", withArgumentsIn: [])
            db.executeUpdate("ALTER TABLE moveTemp RENAME TO \(table)", withArgumentsIn: [])
        }

        if settings.isJukeboxEnabled {
            Jukebox.shared().replacePlaylistWithLocal()
        }

        let from = fromIndexPath.row
        let to = toIndexPath.row
        let currentIndex = Int(playlist.currentIndex)
        if from == currentIndex {
            playlist.currentIndex = to
        } else if from < currentIndex && to >= currentIndex {
            playlist.currentIndex = currentIndex - 1
        } else if from > currentIndex && to <= currentIndex {
            playlist.currentIndex = currentIndex + 1
        }

        if !settings.isJukeboxEnabled {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: ISMSNotification_CurrentPlaylistOrderChanged), object: nil)
        }
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool { true }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !isEditing else { showDeleteButton(); return }
        dismiss(animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Music.shared().playSong(atPosition: indexPath.row)
        }
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isEditing { hideDeleteButton() }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let song = PlayQueue.shared().songForIndex(UInt(indexPath.row))
        guard song?.isVideo == false else { return nil }
        return SwipeAction.downloadQueueAndDeleteConfig(model: song) { [weak self] in
            guard let self else { return }
            PlayQueue.shared().deleteSongs([indexPath.row] as [Any])
            self.updateCurrentPlaylistCount()
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
}
