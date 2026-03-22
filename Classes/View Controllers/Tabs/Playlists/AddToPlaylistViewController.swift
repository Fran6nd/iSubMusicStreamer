//
//  AddToPlaylistViewController.swift
//  iSub
//
//  Created by Francois ND on 3/22/26.
//  Copyright © 2026 Francois ND. All rights reserved.
//

import UIKit
import CryptoKit

/// A sheet that lists all local playlists and lets the user add a song to one.
/// Present it modally; it uses `UISheetPresentationController` detents automatically.
final class AddToPlaylistViewController: UITableViewController {

    // MARK: - Private

    private let song: Song
    private var playlists: [ISMSLocalPlaylist] = []

    private enum Row {
        case newPlaylist
        case playlist(ISMSLocalPlaylist)
    }
    private var rows: [Row] = []

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
        loadPlaylists()
    }

    // MARK: - Data

    private func loadPlaylists() {
        playlists = fetchLocalPlaylists()
        rows = [.newPlaylist] + playlists.map { .playlist($0) }
        tableView.reloadData()
    }

    private func fetchLocalPlaylists() -> [ISMSLocalPlaylist] {
        var result: [ISMSLocalPlaylist] = []
        Database.shared().localPlaylistsDbQueue?.inDatabase { db in
            guard let rs = db.executeQuery("SELECT playlist, md5 FROM localPlaylists", withArgumentsIn: []) else { return }
            defer { rs.close() }
            while rs.next() {
                guard let name = rs.string(forColumn: "playlist"),
                      let md5  = rs.string(forColumn: "md5") else { continue }
                var count = 0
                if let countRs = db.executeQuery("SELECT COUNT(*) FROM playlist\(md5)", withArgumentsIn: []) {
                    if countRs.next() { count = Int(countRs.int(forColumnIndex: 0)) }
                    countRs.close()
                }
                result.append(ISMSLocalPlaylist(name: name, md5: md5, count: UInt(count)))
            }
        }
        return result
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
        case .playlist(let pl):
            cfg.text = pl.name
            cfg.secondaryText = "\(pl.count) song\(pl.count == 1 ? "" : "s")"
            cfg.image = UIImage(systemName: "music.note.list")
            cfg.imageProperties.tintColor = .systemBlue
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
        case .playlist(let pl):
            addSong(to: pl)
        }
    }

    // MARK: - Actions

    private func addSong(to playlist: ISMSLocalPlaylist) {
        song.addToLocalPlaylist(withMd5: playlist.md5)
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
            guard let self = self,
                  let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !name.isEmpty else { return }
            self.createPlaylist(named: name)
        })
        present(alert, animated: true)
    }

    private static func md5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func createPlaylist(named name: String) {
        let md5 = Self.md5(name)
        Database.shared().localPlaylistsDbQueue?.inDatabase { db in
            // Guard against duplicate names
            var existing: String? = nil
            if let rs = db.executeQuery("SELECT md5 FROM localPlaylists WHERE md5 = ?", withArgumentsIn: [md5]) {
                if rs.next() { existing = rs.string(forColumnIndex: 0) }
                rs.close()
            }
            guard existing == nil else { return }
            db.executeUpdate("INSERT INTO localPlaylists (playlist, md5) VALUES (?, ?)", withArgumentsIn: [name, md5])
            db.executeUpdate("CREATE TABLE IF NOT EXISTS playlist\(md5) (\(Song.standardSongColumnSchema()))", withArgumentsIn: [])
        }
        // Add the song to the freshly created playlist
        song.addToLocalPlaylist(withMd5: md5)
        HapticEngine.shared.success()
        SlidingNotification.showOnMainWindow(message: "Created \"\(name)\"", duration: 1.5)
        dismiss(animated: true)
    }
}
