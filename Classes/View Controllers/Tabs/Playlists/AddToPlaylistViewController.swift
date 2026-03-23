//
//  AddToPlaylistViewController.swift
//  iSub
//
//  Created by Francois ND on 3/22/26.
//  Copyright © 2026 Francois ND. All rights reserved.
//

import UIKit

/// A sheet that lets the user add a song to a local or server playlist.
final class AddToPlaylistViewController: UITableViewController {

    // MARK: - Private

    private let song: Song
    private let dao = LocalPlaylistDAO()

    private enum Scope { case local, server }
    private var scope: Scope = .local

    private enum Row {
        case newPlaylist
        case localPlaylist(ISMSLocalPlaylist)
        case serverPlaylist(ServerPlaylist)
        case loading
        case error(String)
    }
    private var rows: [Row] = []

    private var localPlaylists: [ISMSLocalPlaylist] = []
    private var serverPlaylists: [ServerPlaylist] = []
    private var isLoadingServer = false
    private var fetchTask: Task<Void, Never>?

    private lazy var segmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Local", "Server"])
        sc.selectedSegmentIndex = 0
        sc.addTarget(self, action: #selector(scopeChanged(_:)), for: .valueChanged)
        return sc
    }()

    // MARK: - Init

    init(song: Song) {
        self.song = song
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("unimplemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add to Playlist"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        navigationItem.titleView = segmentedControl

        loadLocal()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        fetchTask?.cancel()
    }

    // MARK: - Scope switching

    @objc private func scopeChanged(_ sender: UISegmentedControl) {
        scope = sender.selectedSegmentIndex == 0 ? .local : .server
        switch scope {
        case .local:
            rebuildRows()
        case .server:
            if serverPlaylists.isEmpty && !isLoadingServer {
                fetchServerPlaylists()
            } else {
                rebuildRows()
            }
        }
    }

    // MARK: - Data loading

    private func loadLocal() {
        localPlaylists = dao.fetchAll()
        rebuildRows()
    }

    private func fetchServerPlaylists() {
        isLoadingServer = true
        rebuildRows()

        fetchTask?.cancel()
        fetchTask = Task {
            do {
                let fetched = try await ServerPlaylistService().fetchAll()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.serverPlaylists = fetched
                    self.isLoadingServer = false
                    self.rebuildRows()
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.isLoadingServer = false
                    self.rows = [.newPlaylist, .error(error.localizedDescription)]
                    self.tableView.reloadData()
                }
            }
        }
    }

    private func rebuildRows() {
        switch scope {
        case .local:
            rows = [.newPlaylist] + localPlaylists.map { .localPlaylist($0) }
        case .server:
            if isLoadingServer {
                rows = [.loading]
            } else {
                rows = [.newPlaylist] + serverPlaylists.map { .serverPlaylist($0) }
            }
        }
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var cfg = UIListContentConfiguration.cell()
        switch rows[indexPath.row] {
        case .newPlaylist:
            cfg.text = "New Playlist…"
            cfg.image = UIImage(systemName: "plus.circle.fill")
            cfg.imageProperties.tintColor = .systemGreen
        case .localPlaylist(let pl):
            cfg.text = pl.name
            cfg.secondaryText = "\(pl.count) song\(pl.count == 1 ? "" : "s")"
            cfg.image = UIImage(systemName: "music.note.list")
            cfg.imageProperties.tintColor = .systemBlue
        case .serverPlaylist(let sp):
            cfg.text = sp.playlistName
            cfg.image = UIImage(systemName: "music.note.list")
            cfg.imageProperties.tintColor = .systemPurple
        case .loading:
            cfg.text = "Loading…"
            cfg.image = UIImage(systemName: "arrow.clockwise")
            cfg.imageProperties.tintColor = .secondaryLabel
        case .error(let msg):
            cfg.text = msg
            cfg.image = UIImage(systemName: "exclamationmark.circle")
            cfg.imageProperties.tintColor = .systemRed
        }
        cell.contentConfiguration = cfg
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch rows[indexPath.row] {
        case .newPlaylist:
            presentNewPlaylistAlert()
        case .localPlaylist(let pl):
            addSongToLocal(pl)
        case .serverPlaylist(let sp):
            addSongToServer(sp)
        case .loading, .error:
            break
        }
    }

    // MARK: - Local playlist actions

    private func addSongToLocal(_ playlist: ISMSLocalPlaylist) {
        dao.addSong(song, to: playlist)
        HapticEngine.shared.success()
        SlidingNotification.showOnMainWindow(message: "Added to \(playlist.name)", duration: 1.5)
        dismiss(animated: true)
    }

    private func presentNewPlaylistAlert() {
        let alert = UIAlertController(title: "New Playlist", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Playlist name"
            tf.autocapitalizationType = .sentences
            tf.returnKeyType = .done
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create", style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !name.isEmpty else { return }
            switch self.scope {
            case .local:
                self.createLocalAndAdd(named: name)
            case .server:
                self.createServerAndAdd(named: name)
            }
        })
        present(alert, animated: true)
    }

    private func createLocalAndAdd(named name: String) {
        guard let playlist = dao.create(named: name) else { return }
        dao.addSong(song, to: playlist)
        HapticEngine.shared.success()
        SlidingNotification.showOnMainWindow(message: "Created \"\(name)\"", duration: 1.5)
        dismiss(animated: true)
    }

    // MARK: - Server playlist actions

    private func addSongToServer(_ playlist: ServerPlaylist) {
        guard song.songId != nil else {
            SlidingNotification.showOnMainWindow(message: "Song has no server ID")
            return
        }
        Task {
            do {
                try await ServerPlaylistService().addSongs([song], to: playlist)
                await MainActor.run {
                    HapticEngine.shared.success()
                    SlidingNotification.showOnMainWindow(message: "Added to \(playlist.playlistName)", duration: 1.5)
                    self.dismiss(animated: true)
                }
            } catch {
                await MainActor.run {
                    SlidingNotification.showOnMainWindow(message: "Failed to add to playlist")
                }
            }
        }
    }

    private func createServerAndAdd(named name: String) {
        guard song.songId != nil else {
            SlidingNotification.showOnMainWindow(message: "Song has no server ID")
            return
        }
        Task {
            do {
                _ = try await ServerPlaylistService().create(named: name, songs: [song])
                await MainActor.run {
                    HapticEngine.shared.success()
                    SlidingNotification.showOnMainWindow(message: "Created \"\(name)\"", duration: 1.5)
                    self.dismiss(animated: true)
                }
            } catch {
                await MainActor.run {
                    SlidingNotification.showOnMainWindow(message: "Failed to create playlist")
                }
            }
        }
    }
}
