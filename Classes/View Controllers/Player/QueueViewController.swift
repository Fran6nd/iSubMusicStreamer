//
//  QueueViewController.swift
//  iSub
//
//  Created by François ND on 2026.
//  Copyright © 2026 François ND. All rights reserved.
//

import UIKit
import SnapKit

final class QueueViewController: UIViewController {

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .plain)

    // MARK: - State

    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Play Queue"
        view.backgroundColor = UIColor(named: "isubBackgroundColor")

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(dismiss(_:))
        )

        setupTableView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        registerForNotifications()
        tableView.reloadData()
        scrollToCurrentSong(animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterForNotifications()
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor(named: "isubBackgroundColor")
        tableView.separatorStyle = .none
        tableView.rowHeight = Defines.rowHeight
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)
        // Enable editing to get the reorder handles
        tableView.isEditing = true
        tableView.allowsSelectionDuringEditing = true

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - Notifications

    private func registerForNotifications() {
        let center = NotificationCenter.default
        let names = [
            ISMSNotification_CurrentPlaylistIndexChanged,
            ISMSNotification_SongPlaybackStarted,
            ISMSNotification_CurrentPlaylistSongsQueued,
            ISMSNotification_CurrentPlaylistShuffleToggled
        ]
        for name in names {
            let observer = center.addObserver(
                forName: NSNotification.Name(rawValue: name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handlePlaylistUpdate()
            }
            notificationObservers.append(observer)
        }
    }

    private func unregisterForNotifications() {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers.removeAll()
    }

    @objc private func handlePlaylistUpdate() {
        tableView.reloadData()
        scrollToCurrentSong(animated: true)
    }

    // MARK: - Helpers

    private func scrollToCurrentSong(animated: Bool) {
        let currentIndex = Int(PlayQueue.shared().currentIndex)
        let count = Int(PlayQueue.shared().count)
        guard currentIndex >= 0, currentIndex < count else { return }
        let indexPath = IndexPath(row: currentIndex, section: 0)
        tableView.scrollToRow(at: indexPath, at: .middle, animated: animated)
    }

    // MARK: - Actions

    @objc private func dismiss(_ sender: Any) {
        if let nav = navigationController {
            nav.dismiss(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: - Move row (DB operation mirrors CurrentPlaylistViewController)

    private func moveRow(from fromRow: Int, to toRow: Int) {
        guard let dbQueue = Database.shared().currentPlaylistDbQueue else { return }
        let playQueue = PlayQueue.shared()
        let settings = Settings.shared()

        let fromRowId = fromRow + 1
        let toRowId = toRow + 1

        dbQueue.inDatabase { db in
            let table: String
            if settings.isJukeboxEnabled {
                table = playQueue.isShuffle ? "jukeboxShufflePlaylist" : "jukeboxCurrentPlaylist"
            } else {
                table = playQueue.isShuffle ? "shufflePlaylist" : "currentPlaylist"
            }

            let schema = ISMSSong.standardSongColumnSchema() ?? ""
            db.executeUpdate("DROP TABLE IF EXISTS moveTemp", withArgumentsIn: [])
            db.executeUpdate("CREATE TABLE moveTemp (\(schema))", withArgumentsIn: [])

            if fromRowId < toRowId {
                db.executeUpdate("INSERT INTO moveTemp SELECT * FROM \(table) WHERE ROWID < ?", withArgumentsIn: [fromRowId])
                db.executeUpdate("INSERT INTO moveTemp SELECT * FROM \(table) WHERE ROWID > ? AND ROWID <= ?", withArgumentsIn: [fromRowId, toRowId])
                db.executeUpdate("INSERT INTO moveTemp SELECT * FROM \(table) WHERE ROWID = ?", withArgumentsIn: [fromRowId])
                db.executeUpdate("INSERT INTO moveTemp SELECT * FROM \(table) WHERE ROWID > ?", withArgumentsIn: [toRowId])
            } else {
                db.executeUpdate("INSERT INTO moveTemp SELECT * FROM \(table) WHERE ROWID < ?", withArgumentsIn: [toRowId])
                db.executeUpdate("INSERT INTO moveTemp SELECT * FROM \(table) WHERE ROWID = ?", withArgumentsIn: [fromRowId])
                db.executeUpdate("INSERT INTO moveTemp SELECT * FROM \(table) WHERE ROWID >= ? AND ROWID < ?", withArgumentsIn: [toRowId, fromRowId])
                db.executeUpdate("INSERT INTO moveTemp SELECT * FROM \(table) WHERE ROWID > ?", withArgumentsIn: [fromRowId])
            }

            db.executeUpdate("DROP TABLE \(table)", withArgumentsIn: [])
            db.executeUpdate("ALTER TABLE moveTemp RENAME TO \(table)", withArgumentsIn: [])
        }

        // Correct currentIndex
        let currentIndex = playQueue.currentIndex
        if fromRow == currentIndex {
            playQueue.currentIndex = toRow
        } else if fromRow < currentIndex, toRow >= currentIndex {
            playQueue.currentIndex = currentIndex - 1
        } else if fromRow > currentIndex, toRow <= currentIndex {
            playQueue.currentIndex = currentIndex + 1
        }

        if !settings.isJukeboxEnabled {
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: ISMSNotification_CurrentPlaylistOrderChanged),
                object: nil
            )
        }
    }
}

// MARK: - UITableViewDataSource

extension QueueViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Int(PlayQueue.shared().count)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: UniversalTableViewCell.reuseId,
            for: indexPath
        ) as! UniversalTableViewCell

        let song = PlayQueue.shared().song(forIndex: UInt(indexPath.row))
        if let song = song {
            cell.update(with: song)
        }
        cell.number = indexPath.row + 1

        // Highlight the currently playing song
        let currentIndex = Int(PlayQueue.shared().currentIndex)
        if indexPath.row == currentIndex {
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 16)
            cell.tintColor = UIColor.systemBlue
        }

        return cell
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        moveRow(from: sourceIndexPath.row, to: destinationIndexPath.row)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        // Use .none so only the reorder handle appears, swipe-to-delete is handled via trailing swipe actions
        return .none
    }
}

// MARK: - UITableViewDelegate

extension QueueViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !tableView.isEditing else { return }
        dismiss(animated: true) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Music.shared().playSong(atPosition: indexPath.row)
            }
        }
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        // Allow selection even during editing so tapping a row plays it
        return indexPath
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let song = PlayQueue.shared().song(forIndex: UInt(indexPath.row)),
              !song.isVideo else { return nil }

        let deleteAction = UIContextualAction(style: .destructive, title: "Remove") { [weak self] _, _, completionHandler in
            guard let self = self else { completionHandler(false); return }
            PlayQueue.shared().deleteSongs([NSNumber(value: indexPath.row)])
            tableView.deleteRows(at: [indexPath], with: .automatic)
            // Update visible cell numbers
            for visibleIndexPath in tableView.indexPathsForVisibleRows ?? [] {
                if let cell = tableView.cellForRow(at: visibleIndexPath) as? UniversalTableViewCell {
                    cell.number = visibleIndexPath.row + 1
                }
            }
            HapticEngine.shared.success()
            completionHandler(true)
        }
        deleteAction.image = UIImage(systemName: "trash.fill")

        let config = UISwipeActionsConfiguration(actions: [deleteAction])
        config.performsFirstActionWithFullSwipe = false
        return config
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}
