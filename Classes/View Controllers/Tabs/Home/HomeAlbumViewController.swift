//
//  HomeAlbumViewController.swift
//  iSub
//
//  Created by François Ganot on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(HomeAlbumViewController) final class HomeAlbumViewController: UITableViewController {

    @objc var listOfAlbums: NSMutableArray?
    @objc var modifier: String = ""
    @objc var offset: UInt = 0
    @objc var isMoreAlbums: Bool = true
    @objc var isLoading: Bool = false

    private var albums: NSMutableArray { listOfAlbums ?? NSMutableArray() }
    private var loader: SUSQuickAlbumsLoader?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        if Music.shared().showPlayerIcon {
            let image = UIImage(systemName: Defines.musicNoteImageSystemName)
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(nowPlayingAction(_:)))
        } else {
            navigationItem.rightBarButtonItem = nil
        }

        tableView.rowHeight = Defines.rowHeight
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)
    }

    // MARK: - Actions

    @IBAction private func nowPlayingAction(_ sender: Any) {
        let playerVC = PlayerViewController()
        playerVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(playerVC, animated: true)
    }

    private func loadMoreResults() {
        guard !isLoading else { return }
        isLoading = true
        offset += 20

        loader = SUSQuickAlbumsLoader(delegate: self)
        loader?.modifier = modifier
        loader?.offset = offset
        loader?.startLoad()
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        albums.count + 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row < albums.count {
            let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
            cell.hideNumberLabel = true
            cell.hideCoverArt = false
            cell.hideDurationLabel = true
            cell.update(model: albums[indexPath.row] as? TableCellModel)
            return cell
        } else {
            let cell = UITableViewCell(style: .default, reuseIdentifier: "HomeAlbumLoadCell")
            cell.backgroundColor = UIColor(named: "isubBackgroundColor")
            if isMoreAlbums {
                cell.textLabel?.text = "Loading more results..."
                let indicator = UIActivityIndicatorView(style: .medium)
                indicator.center = CGPoint(x: 300, y: 30)
                cell.addSubview(indicator)
                indicator.startAnimating()
                loadMoreResults()
            } else {
                cell.textLabel?.text = "No more results"
            }
            return cell
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < albums.count else {
            tableView.deselectRow(at: indexPath, animated: false)
            return
        }
        if let album = albums[indexPath.row] as? Album,
           let albumVC = AlbumViewController(artist: nil, orAlbum: album) {
            pushViewControllerCustom(albumVC)
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row < albums.count,
              let model = albums[indexPath.row] as? TableCellModel else { return nil }
        return SwipeAction.downloadAndQueueConfig(model: model)
    }
}

// MARK: - SUSLoaderDelegate

extension HomeAlbumViewController: SUSLoaderDelegate {
    @objc func loadingFinished(_ loader: SUSLoader!) {
        if let loaded = self.loader?.listOfAlbums, loaded.count > 0 {
            if listOfAlbums == nil { listOfAlbums = NSMutableArray() }
            for item in loaded { listOfAlbums?.add(item) }
        } else {
            isMoreAlbums = false
        }
        tableView.reloadData()
        isLoading = false
        self.loader = nil
    }

    @objc func loadingFailed(_ loader: SUSLoader!, withError error: Error!) {
        self.loader = nil
        isLoading = false
        if Settings.shared().isPopupsEnabled {
            let message = "There was an error performing the search.\n\nError: \(error.localizedDescription)"
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        }
    }
}
