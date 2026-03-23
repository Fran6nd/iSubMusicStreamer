//
//  PlaylistSongsViewController.swift
//  iSub
//
//  Created by François ND on 2026-03-23.
//  Copyright © 2026 François ND. All rights reserved.
//

import UIKit
import CocoaLumberjackSwift

// MARK: - PlaylistSource

private enum PlaylistSource {
    case local(md5: String, count: UInt)
    case server(ServerPlaylist)
}

// MARK: - PlaylistSongsViewController

@objc(PlaylistSongsViewController) final class PlaylistSongsViewController: UITableViewController {

    // MARK: - ObjC-visible properties (callers set these before pushing)

    @objc var md5: String = ""
    @objc var playlistCount: UInt = 0
    @objc var serverPlaylist: ServerPlaylist? = nil

    // MARK: - Private state

    private var source: PlaylistSource = .local(md5: "", count: 0)
    private var songs: [Song] = []
    private var fetchTask: Task<Void, Never>?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Resolve source from ObjC-set properties
        if let sp = serverPlaylist {
            source = .server(sp)
            title = sp.playlistName
        } else {
            source = .local(md5: md5, count: playlistCount)
            var playlistName: String = ""
            Database.shared().localPlaylistsDbQueue?.inDatabase { db in
                if let rs = db.executeQuery("SELECT playlist FROM localPlaylists WHERE md5 = ?", withArgumentsIn: [md5]) {
                    if rs.next() { playlistName = rs.string(forColumnIndex: 0) ?? "" }
                    rs.close()
                }
            }
            title = playlistName
        }

        tableView.backgroundColor = UIColor(named: "isubBackgroundColor")
        tableView.separatorStyle = .none
        tableView.rowHeight = Defines.rowHeight
        tableView.register(
            UniversalTableViewCell.self,
            forCellReuseIdentifier: UniversalTableViewCell.reuseId
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Now-playing button
        navigationItem.rightBarButtonItem = Music.shared().showPlayerIcon
            ? UIBarButtonItem(
                image: UIImage(systemName: Defines.musicNoteImageSystemName),
                style: .plain,
                target: self,
                action: #selector(nowPlayingAction(_:))
              )
            : nil

        switch source {
        case .local:
            reloadLocalSongs()

        case .server:
            if songs.isEmpty {
                fetchServerSongs()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        fetchTask?.cancel()
    }

    deinit {
        fetchTask?.cancel()
    }

    // MARK: - Data loading

    private func reloadLocalSongs() {
        guard case .local(let md5, _) = source else { return }

        // Re-read current count from DB so a push-back-then-return reflects edits
        var count: Int32 = 0
        Database.shared().localPlaylistsDbQueue?.inDatabase { db in
            if let rs = db.executeQuery("SELECT COUNT(*) FROM playlist\(md5)", withArgumentsIn: []) {
                if rs.next() { count = rs.int(forColumnIndex: 0) }
                rs.close()
            }
        }
        self.playlistCount = UInt(count)
        self.source = .local(md5: md5, count: UInt(count))
        let playlist = ISMSLocalPlaylist(name: title ?? "", md5: md5, count: UInt(count))
        songs = LocalPlaylistDAO().fetchSongs(in: playlist)

        updateHeader()
        tableView.reloadData()
    }

    private func fetchServerSongs() {
        guard case .server(let sp) = source else { return }

        ViewObjects.shared().showAlbumLoadingScreen(view, sender: self)
        tableView.isScrollEnabled = false

        fetchTask?.cancel()
        fetchTask = Task {
            do {
                let fetched = try await ServerPlaylistService().fetchSongs(in: sp)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.songs = fetched
                    self.playlistCount = UInt(fetched.count)
                    self.updateHeader()
                    self.tableView.reloadData()
                    self.tableView.isScrollEnabled = true
                    ViewObjects.shared().hideLoadingScreen()
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.tableView.isScrollEnabled = true
                    ViewObjects.shared().hideLoadingScreen()
                    if Settings.shared().isPopupsEnabled {
                        let msg = "There was an error loading the playlist.\n\n\(error.localizedDescription)"
                        let alert = UIAlertController(
                            title: "Error",
                            message: msg,
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
                        self.present(alert, animated: true)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private func updateHeader() {
        let artIds: [String] = songs.prefix(4).compactMap { $0.coverArtId }

        let header = PlaylistHeaderView()
        header.playlistName = title
        header.songCount = songs.count
        header.coverArtIds = artIds
        header.onPlayAll = { [weak self] in self?.playAll() }
        header.onShuffle = { [weak self] in self?.shuffleAll() }

        // Wrap in a container so Auto Layout can size the tableHeaderView properly
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.heightAnchor.constraint(equalToConstant: PlaylistHeaderView.height),
            header.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        tableView.tableHeaderView = container
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            container.widthAnchor.constraint(equalTo: tableView.widthAnchor),
            container.topAnchor.constraint(equalTo: tableView.topAnchor),
        ])
        container.layoutIfNeeded()
        // Force UITableView to adopt the header's intrinsic size
        tableView.tableHeaderView = tableView.tableHeaderView
    }

    // MARK: - Playback helpers

    /// Copies all songs from the in-memory `songs` array into the current playlist DB and plays from `position`.
    private func loadPlaylistAndPlay(at position: Int) {
        let settings = Settings.shared()
        let database = Database.shared()
        let jukebox = Jukebox.shared()
        let playQueue = PlayQueue.shared()

        if settings.isJukeboxEnabled {
            database.resetJukeboxPlaylist()
            jukebox.clearRemotePlaylist()
        } else {
            database.resetCurrentPlaylistDb()
        }

        playQueue.isShuffle = false

        let currTableName = settings.isJukeboxEnabled ? "jukeboxCurrentPlaylist" : "currentPlaylist"
        if let queue = database.currentPlaylistDbQueue {
            for song in songs {
                song.insertIntoTable(currTableName, inDatabaseQueue: queue)
            }
        }

        if settings.isJukeboxEnabled {
            jukebox.replacePlaylistWithLocal()
        }

        Music.shared().playSong(atPosition: position)
    }

    private func playAll() {
        loadPlaylistAndPlay(at: 0)
    }

    private func shuffleAll() {
        let settings = Settings.shared()
        let database = Database.shared()
        let jukebox = Jukebox.shared()

        if settings.isJukeboxEnabled {
            database.resetJukeboxPlaylist()
            jukebox.clearRemotePlaylist()
        } else {
            database.resetCurrentPlaylistDb()
        }

        PlayQueue.shared().isShuffle = true

        let currTableName = settings.isJukeboxEnabled ? "jukeboxCurrentPlaylist" : "currentPlaylist"
        if let queue = database.currentPlaylistDbQueue {
            for song in songs {
                song.insertIntoTable(currTableName, inDatabaseQueue: queue)
            }
        }

        if settings.isJukeboxEnabled {
            jukebox.replacePlaylistWithLocal()
        }

        Music.shared().playSong(atPosition: 0)
    }

    private func addAllToQueue() {
        for song in songs {
            song.addToCurrentPlaylistDbQueue()
        }
        SlidingNotification.showOnMainWindow(message: "All songs added to queue", duration: 1.5)
        HapticEngine.shared.success()
    }

    // MARK: - Actions

    @objc private func nowPlayingAction(_ sender: Any?) {
        let vc = PlayerViewController()
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Server playlist: Add Songs (placeholder, wired up in a future step)

    @objc private func addSongsAction(_ sender: Any?) {
        // TODO: Present song browser to add songs to this server playlist
    }
}

// MARK: - UITableViewDataSource

extension PlaylistSongsViewController {

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        songs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: UniversalTableViewCell.reuseId,
            for: indexPath
        ) as! UniversalTableViewCell

        let song = songs[indexPath.row]
        cell.hideNumberLabel = false
        cell.hideCoverArt    = false
        cell.hideDurationLabel = false
        cell.hideSecondaryLabel = false
        cell.number = indexPath.row + 1
        cell.update(model: song)
        cell.backgroundColor = .clear

        if !song.isVideo {
            let isServer = { if case .server = self.source { return true }; return false }()
            if isServer {
                cell.contextMenuProvider = { [weak self] _ in
                    self?.serverSongContextMenu(song: song, index: indexPath.row)
                }
            } else {
                cell.configureSongContextMenu(song: song, presenter: self)
            }
        }

        return cell
    }
}

// MARK: - UITableViewDelegate

extension PlaylistSongsViewController {

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
        // Defer slightly so the loading screen appears before we block the main thread
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.loadPlaylistAndPlay(at: indexPath.row)
        }
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let song = songs[indexPath.row]
        guard !song.isVideo else { return nil }
        return SwipeAction.downloadAndQueueConfig(model: song)
    }

    override func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        // Context menus are handled via UniversalTableViewCell's UIContextMenuInteraction;
        // returning nil here prevents double-triggering from the table view delegate.
        return nil
    }
}

// MARK: - Context menus

private extension PlaylistSongsViewController {

    /// Context menu for server-playlist rows (adds "Remove from Playlist" on top of the standard items).
    func serverSongContextMenu(song: Song, index: Int) -> UIMenu {
        let play = UIAction(
            title: "Play",
            image: UIImage(systemName: "play.fill")
        ) { [weak self] _ in
            guard let self else { return }
            ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.loadPlaylistAndPlay(at: index)
            }
        }

        let addToQueue = UIAction(
            title: "Add to Queue",
            image: UIImage(systemName: "text.badge.plus")
        ) { _ in
            song.addToCurrentPlaylistDbQueue()
            SlidingNotification.showOnMainWindow(message: "Added to queue", duration: 1.0)
            HapticEngine.shared.success()
        }

        let addToPlaylist = UIAction(
            title: "Add to Playlist…",
            image: UIImage(systemName: "music.note.list")
        ) { [weak self] _ in
            guard let self else { return }
            HapticEngine.shared.secondaryAction()
            let vc = AddToPlaylistViewController(song: song)
            let nav = UINavigationController(rootViewController: vc)
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
            self.present(nav, animated: true)
        }

        let remove = UIAction(
            title: "Remove from Playlist",
            image: UIImage(systemName: "minus.circle"),
            attributes: .destructive
        ) { [weak self] _ in
            guard let self, case .server(let sp) = self.source else { return }
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await ServerPlaylistService().removeSongs(at: [index], from: sp)
                    await MainActor.run {
                        self.songs.remove(at: index)
                        self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                        self.updateHeader()
                    }
                } catch {
                    await MainActor.run {
                        SlidingNotification.showOnMainWindow(message: "Failed to remove song")
                    }
                }
            }
        }

        return UIMenu(title: song.title ?? "", children: [play, addToQueue, addToPlaylist, remove])
    }
}
