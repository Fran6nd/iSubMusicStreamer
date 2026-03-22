//
//  SwipeAction.swift
//  iSub
//
//  Created by Benjamin Baron on 11/11/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit

// Haptic info: https://medium.com/@sdrzn/make-your-ios-app-feel-better-a-comprehensive-guide-over-taptic-engine-and-haptic-feedback-724dec425f10

@objc final class SwipeAction: NSObject {
    @objc static func downloadAndQueueConfig(model: TableCellModel) -> UISwipeActionsConfiguration {
        let actions = model.isCached ? [queue(model: model)] : [download(model: model), queue(model: model)];
        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = false;
        return config;
    }
    
    @objc static func downloadQueueAndDeleteConfig(model: TableCellModel, deleteHandler: @escaping () -> ()) -> UISwipeActionsConfiguration {
        let actions = model.isCached ? [queue(model: model), delete(handler: deleteHandler)] : [download(model: model), queue(model: model), delete(handler: deleteHandler)];
        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = false;
        return config;
    }
    
    @objc static func downloadQueueAndDeleteConfig(downloadHandler: (() -> ())?, queueHandler: (() -> ())?, deleteHandler: (() -> ())?) -> UISwipeActionsConfiguration {
        var actions = [UIContextualAction]()
        if let downloadHandler = downloadHandler {
            actions.append(download(handler: downloadHandler))
        }
        if let queueHandler = queueHandler {
            actions.append(queue(handler: queueHandler))
        }
        if let deleteHandler = deleteHandler {
            actions.append(delete(handler: deleteHandler))
        }
        
        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = false;
        return config;
    }
    
    @objc static func download(model: TableCellModel) -> UIContextualAction {
        return download(handler: model.download)
    }
    
    @objc static func queue(model: TableCellModel) -> UIContextualAction {
        return queue(handler: model.queue)
    }
    
    @objc static func download(handler: @escaping () -> ()) -> UIContextualAction {
        let action = UIContextualAction(style: .normal, title: "Download") { _, _, completionHandler in
            handler()
            SlidingNotification.showOnMainWindow(message: "Added to download queue", duration: 1.0)
            HapticEngine.shared.success()
            completionHandler(true)
        }
        action.backgroundColor = .systemBlue
        action.image = UIImage(systemName: "arrow.down.circle.fill")
        return action
    }

    @objc static func queue(handler: @escaping () -> ()) -> UIContextualAction {
        let action = UIContextualAction(style: .normal, title: "Queue") { _, _, completionHandler in
            handler()
            SlidingNotification.showOnMainWindow(message: "Added to play queue", duration: 1.0)
            HapticEngine.shared.success()
            completionHandler(true)
        }
        action.backgroundColor = .systemGreen
        action.image = UIImage(systemName: "text.badge.plus")
        return action
    }

    @objc static func delete(handler: @escaping () -> ()) -> UIContextualAction {
        let action = UIContextualAction(style: .destructive, title: "Delete") { _, _, completionHandler in
            handler()
            HapticEngine.shared.success()
            completionHandler(true)
        }
        action.image = UIImage(systemName: "trash.fill")
        return action
    }

    // MARK: - Context Menu helpers

    // MARK: - Context Menu helpers

    /// Full song context menu: Play Next, Add to Queue, Download, Add to Playlist.
    /// `presenter` is used to present the AddToPlaylistViewController sheet.
    static func songContextMenu(song: Song, presenter: UIViewController) -> UIMenu {
        let playNext = UIAction(
            title: "Play Next",
            image: UIImage(systemName: "text.line.first.and.arrowtriangle.forward")
        ) { _ in
            song.insertAsNextInCurrentPlaylistDbQueue()
            SlidingNotification.showOnMainWindow(message: "Playing next", duration: 1.0)
            HapticEngine.shared.success()
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
            title: "Add to Playlist",
            image: UIImage(systemName: "music.note.list")
        ) { [weak presenter] _ in
            guard let presenter = presenter else { return }
            HapticEngine.shared.secondaryAction()
            let vc = AddToPlaylistViewController(song: song)
            let nav = UINavigationController(rootViewController: vc)
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
            presenter.present(nav, animated: true)
        }

        var children: [UIMenuElement] = [playNext, addToQueue, addToPlaylist]

        if !song.isCached {
            children.append(UIAction(
                title: "Download",
                image: UIImage(systemName: "arrow.down.circle")
            ) { _ in
                song.download()
                SlidingNotification.showOnMainWindow(message: "Added to download queue", duration: 1.0)
                HapticEngine.shared.success()
            })
        }

        return UIMenu(title: song.title ?? "", children: children)
    }

    /// Standard Download + Queue context menu built from a TableCellModel (non-song fallback).
    static func contextMenu(model: TableCellModel) -> UIMenu {
        var actions: [UIAction] = []

        actions.append(UIAction(title: "Add to Queue", image: UIImage(systemName: "text.badge.plus")) { _ in
            model.queue()
            SlidingNotification.showOnMainWindow(message: "Added to play queue", duration: 1.0)
            HapticEngine.shared.success()
        })

        if !model.isCached {
            actions.append(UIAction(title: "Download", image: UIImage(systemName: "arrow.down.circle")) { _ in
                model.download()
                SlidingNotification.showOnMainWindow(message: "Added to download queue", duration: 1.0)
                HapticEngine.shared.success()
            })
        }

        return UIMenu(title: model.primaryLabelText ?? "", children: actions)
    }

    /// Extended context menu with an additional delete action.
    static func contextMenu(model: TableCellModel, deleteHandler: @escaping () -> ()) -> UIMenu {
        let deleteAction = UIAction(
            title: "Delete",
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) { _ in
            deleteHandler()
            HapticEngine.shared.success()
        }
        let base = contextMenu(model: model)
        return UIMenu(title: base.title, children: base.children + [deleteAction])
    }
}
