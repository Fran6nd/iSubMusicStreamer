//
//  PlaylistsViewController.swift
//  iSub
//
//  Created by François ND on 2026-03-23.
//  Copyright © 2026 François ND. All rights reserved.
//

import UIKit

// MARK: - PlaylistsViewController

@objc(PlaylistsViewController) final class PlaylistsViewController: UIViewController {

    // MARK: - Tab

    private enum Tab: Int {
        case local  = 0
        case server = 1
    }

    // MARK: - Cell identifiers

    private static let cellId     = "PlaylistCell"
    private static let actionCellId = "ActionCell"

    // MARK: - Subviews

    private let segmentedControl = UISegmentedControl(items: ["Local", "Server"])
    private let tableView        = UITableView(frame: .zero, style: .plain)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    // MARK: - State

    private var currentTab: Tab = .local

    // Local playlists
    private var localPlaylists: [ISMSLocalPlaylist] = []

    // Server playlists
    private var serverPlaylists: [ServerPlaylist] = []
    private var isLoadingServer = false

    // Async tasks
    private var serverFetchTask: Task<Void, Never>?

    // MARK: - Init / deinit

    deinit {
        NotificationCenter.default.removeObserver(self)
        serverFetchTask?.cancel()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Playlists"
        setupSegmentedControl()
        setupTableView()
        setupLoadingIndicator()
        registerForNotifications()
        reloadLocalPlaylists()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if currentTab == .local {
            reloadLocalPlaylists()
        }
    }

    // MARK: - Setup

    private func setupSegmentedControl() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        view.addSubview(segmentedControl)
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = UIColor(named: "isubBackgroundColor")
        tableView.separatorStyle  = .none
        tableView.rowHeight       = Defines.rowHeight
        tableView.dataSource      = self
        tableView.delegate        = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellId)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.actionCellId)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupLoadingIndicator() {
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
        ])
    }

    // MARK: - Notifications

    private func registerForNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCurrentPlaylistIndexChanged),
            name: .init(ISMSNotification_CurrentPlaylistIndexChanged),
            object: nil
        )
    }

    @objc private func handleCurrentPlaylistIndexChanged() {
        guard currentTab == .local else { return }
        tableView.reloadData()
    }

    // MARK: - Segment

    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        currentTab = Tab(rawValue: sender.selectedSegmentIndex) ?? .local
        tableView.reloadData()
        if currentTab == .server && serverPlaylists.isEmpty && !isLoadingServer {
            fetchServerPlaylists()
        }
    }

    // MARK: - Data loading

    private func reloadLocalPlaylists() {
        localPlaylists = LocalPlaylistDAO().fetchAll()
        if currentTab == .local {
            tableView.reloadData()
        }
    }

    private func fetchServerPlaylists() {
        guard !isLoadingServer else { return }
        isLoadingServer = true
        loadingIndicator.startAnimating()
        serverFetchTask?.cancel()
        serverFetchTask = Task {
            do {
                let playlists = try await ServerPlaylistService().fetchAll()
                await MainActor.run {
                    self.serverPlaylists = playlists
                    self.isLoadingServer = false
                    self.loadingIndicator.stopAnimating()
                    if self.currentTab == .server {
                        self.tableView.reloadData()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingServer = false
                    self.loadingIndicator.stopAnimating()
                    SlidingNotification.showOnMainWindow(message: "Failed to load server playlists")
                }
            }
        }
    }

    // MARK: - New playlist alerts

    private func presentNewLocalPlaylistAlert() {
        let alert = UIAlertController(title: "New Playlist", message: "Enter a name for the playlist", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Playlist name"
            tf.autocapitalizationType = .sentences
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create", style: .default) { [weak self, weak alert] _ in
            guard let self, let name = alert?.textFields?.first?.text, !name.isEmpty else { return }
            LocalPlaylistDAO().create(named: name)
            self.reloadLocalPlaylists()
        })
        present(alert, animated: true)
    }

    private func presentNewServerPlaylistAlert() {
        let alert = UIAlertController(title: "New Server Playlist", message: "Enter a name for the playlist", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Playlist name"
            tf.autocapitalizationType = .sentences
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create", style: .default) { [weak self, weak alert] _ in
            guard let self, let name = alert?.textFields?.first?.text, !name.isEmpty else { return }
            Task {
                do {
                    _ = try await ServerPlaylistService().create(named: name)
                    await MainActor.run {
                        self.fetchServerPlaylists()
                    }
                } catch {
                    await MainActor.run {
                        SlidingNotification.showOnMainWindow(message: "Failed to create playlist")
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    // MARK: - Rename alerts

    private func presentRenameLocalAlert(for playlist: ISMSLocalPlaylist) {
        let alert = UIAlertController(title: "Rename Playlist", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = playlist.name
            tf.autocapitalizationType = .sentences
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self, weak alert] _ in
            guard let self, let name = alert?.textFields?.first?.text, !name.isEmpty else { return }
            LocalPlaylistDAO().rename(playlist, to: name)
            self.reloadLocalPlaylists()
        })
        present(alert, animated: true)
    }

    private func presentRenameServerAlert(for playlist: ServerPlaylist) {
        let alert = UIAlertController(title: "Rename Playlist", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = playlist.playlistName
            tf.autocapitalizationType = .sentences
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self, weak alert] _ in
            guard let self, let name = alert?.textFields?.first?.text, !name.isEmpty else { return }
            Task {
                do {
                    try await ServerPlaylistService().rename(playlist, to: name)
                    await MainActor.run { self.fetchServerPlaylists() }
                } catch {
                    await MainActor.run {
                        SlidingNotification.showOnMainWindow(message: "Failed to rename playlist")
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    // MARK: - Clone operations

    private func copyLocalToServer(_ playlist: ISMSLocalPlaylist) {
        SlidingNotification.showOnMainWindow(message: "Copying \"\(playlist.name)\" to server…", duration: 0)
        Task {
            do {
                _ = try await ServerPlaylistService().cloneLocalToServer(playlist)
                await MainActor.run {
                    SlidingNotification.showOnMainWindow(message: "\"\(playlist.name)\" copied to server")
                }
            } catch {
                await MainActor.run {
                    SlidingNotification.showOnMainWindow(message: "Failed to copy to server")
                }
            }
        }
    }

    private func copyServerToLocal(_ playlist: ServerPlaylist) {
        SlidingNotification.showOnMainWindow(message: "Copying \"\(playlist.playlistName)\" to local…", duration: 0)
        Task {
            do {
                _ = try await ServerPlaylistService().cloneServerToLocal(playlist)
                await MainActor.run {
                    SlidingNotification.showOnMainWindow(message: "\"\(playlist.playlistName)\" saved locally")
                    self.reloadLocalPlaylists()
                }
            } catch {
                await MainActor.run {
                    SlidingNotification.showOnMainWindow(message: "Failed to copy to local")
                }
            }
        }
    }

    // MARK: - Navigation

    private func pushPlaylistSongs(localPlaylist: ISMSLocalPlaylist) {
        let vc = PlaylistSongsViewController()
        vc.md5 = localPlaylist.md5
        vc.playlistCount = localPlaylist.count
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }

    private func pushPlaylistSongs(serverPlaylist: ServerPlaylist) {
        let vc = PlaylistSongsViewController()
        vc.serverPlaylist = serverPlaylist
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension PlaylistsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch currentTab {
        case .local:  return 1 + localPlaylists.count
        case .server: return 1 + serverPlaylists.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch currentTab {
        case .local:
            if indexPath.row == 0 {
                return makeActionCell(title: "New Playlist…", reuseId: Self.actionCellId, tableView: tableView)
            }
            let playlist = localPlaylists[indexPath.row - 1]
            let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellId, for: indexPath)
            var config = cell.defaultContentConfiguration()
            config.text          = playlist.name
            config.secondaryText = "\(playlist.count) \(playlist.count == 1 ? "song" : "songs")"
            cell.contentConfiguration = config
            cell.backgroundColor = .clear
            cell.accessoryType   = .disclosureIndicator
            return cell

        case .server:
            if indexPath.row == 0 {
                return makeActionCell(title: "New Server Playlist…", reuseId: Self.actionCellId, tableView: tableView)
            }
            let playlist = serverPlaylists[indexPath.row - 1]
            let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellId, for: indexPath)
            var config = cell.defaultContentConfiguration()
            config.text = playlist.playlistName
            cell.contentConfiguration = config
            cell.backgroundColor = .clear
            cell.accessoryType   = .disclosureIndicator
            return cell
        }
    }

    private func makeActionCell(title: String, reuseId: String, tableView: UITableView) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseId) ?? UITableViewCell(style: .default, reuseIdentifier: reuseId)
        var config = cell.defaultContentConfiguration()
        config.text                  = title
        config.textProperties.color  = .systemGreen
        config.image                 = UIImage(systemName: "plus.circle.fill")
        config.imageProperties.tintColor = .systemGreen
        cell.contentConfiguration    = config
        cell.backgroundColor         = .clear
        cell.accessoryType           = .none
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.row > 0
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, indexPath.row > 0 else { return }
        switch currentTab {
        case .local:
            let playlist = localPlaylists[indexPath.row - 1]
            LocalPlaylistDAO().delete(playlist)
            localPlaylists.remove(at: indexPath.row - 1)
            tableView.deleteRows(at: [indexPath], with: .automatic)

        case .server:
            let playlist = serverPlaylists[indexPath.row - 1]
            serverPlaylists.remove(at: indexPath.row - 1)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            Task {
                do {
                    try await ServerPlaylistService().delete(playlist)
                } catch {
                    await MainActor.run {
                        SlidingNotification.showOnMainWindow(message: "Failed to delete playlist")
                        self.fetchServerPlaylists()
                    }
                }
            }
        }
    }
}

// MARK: - UITableViewDelegate

extension PlaylistsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == 0 {
            switch currentTab {
            case .local:  presentNewLocalPlaylistAlert()
            case .server: presentNewServerPlaylistAlert()
            }
            return
        }
        switch currentTab {
        case .local:
            pushPlaylistSongs(localPlaylist: localPlaylists[indexPath.row - 1])
        case .server:
            pushPlaylistSongs(serverPlaylist: serverPlaylists[indexPath.row - 1])
        }
    }

    func tableView(_ tableView: UITableView,
                   contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.row > 0 else { return nil }

        switch currentTab {
        case .local:
            let playlist = localPlaylists[indexPath.row - 1]
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
                guard let self else { return nil }
                let rename = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { [weak self] _ in
                    self?.presentRenameLocalAlert(for: playlist)
                }
                let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"),
                                      attributes: .destructive) { [weak self] _ in
                    guard let self else { return }
                    LocalPlaylistDAO().delete(playlist)
                    self.reloadLocalPlaylists()
                }
                let copy = UIAction(title: "Copy to Server", image: UIImage(systemName: "arrow.up.to.line")) { [weak self] _ in
                    self?.copyLocalToServer(playlist)
                }
                return UIMenu(title: "", children: [rename, copy, delete])
            }

        case .server:
            let playlist = serverPlaylists[indexPath.row - 1]
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
                guard let self else { return nil }
                let rename = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { [weak self] _ in
                    self?.presentRenameServerAlert(for: playlist)
                }
                let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"),
                                      attributes: .destructive) { [weak self] _ in
                    guard let self else { return }
                    if let idx = self.serverPlaylists.firstIndex(where: { $0.playlistId == playlist.playlistId }) {
                        self.serverPlaylists.remove(at: idx)
                        self.tableView.deleteRows(at: [IndexPath(row: idx + 1, section: 0)], with: .automatic)
                    }
                    Task {
                        do {
                            try await ServerPlaylistService().delete(playlist)
                        } catch {
                            await MainActor.run {
                                SlidingNotification.showOnMainWindow(message: "Failed to delete playlist")
                                self.fetchServerPlaylists()
                            }
                        }
                    }
                }
                let copy = UIAction(title: "Copy to Local", image: UIImage(systemName: "arrow.down.to.line")) { [weak self] _ in
                    self?.copyServerToLocal(playlist)
                }
                return UIMenu(title: "", children: [rename, copy, delete])
            }
        }
    }
}
