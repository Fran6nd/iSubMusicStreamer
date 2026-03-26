//
//  AlbumViewController.swift
//  iSub
//
//  Created by François Ganot on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(AlbumViewController) final class AlbumViewController: UITableViewController {

    @objc var isReloading: Bool = false
    @objc var myId: String?
    @objc var myArtist: Artist?
    @objc var myAlbum: Album?
    @objc var sectionInfo: [Any]?
    @objc var dataModel: SUSSubFolderDAO!

    @objc init?(artist anArtist: Artist?, orAlbum anAlbum: Album?) {
        guard anArtist != nil || anAlbum != nil else { return nil }
        super.init(nibName: "AlbumViewController", bundle: nil)

        if let artist = anArtist {
            title = artist.name
            myId = artist.artistId
            myArtist = artist
            myAlbum = nil
        } else if let album = anAlbum {
            title = album.title
            myId = album.albumId
            myArtist = Artist(name: album.artistName ?? "", andArtistId: album.artistId ?? "")
            myAlbum = album
        }

        dataModel = SUSSubFolderDAO(delegate: self, andId: myId, andArtist: myArtist)

        if dataModel.hasLoaded {
            tableView.reloadData()
            addHeaderAndIndex()
        } else {
            ViewObjects.shared().showAlbumLoadingScreen(view, sender: self)
            dataModel.startLoad()
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        refreshControl = RefreshControl { [weak self] in
            guard let self else { return }
            ViewObjects.shared().showAlbumLoadingScreen(view, sender: self)
            dataModel.startLoad()
        }

        tableView.rowHeight = Defines.rowHeight
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = .clear
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationItem.rightBarButtonItem = Music.shared().showPlayerIcon
            ? UIBarButtonItem(image: UIImage(systemName: Defines.musicNoteImageSystemName), style: .plain, target: self, action: #selector(nowPlayingAction(_:)))
            : nil

        tableView.reloadData()

        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadData), name: ISMSNotification_CurrentPlaylistIndexChanged)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadData), name: ISMSNotification_SongPlaybackStarted)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dataModel.cancelLoad()
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_CurrentPlaylistIndexChanged)
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_SongPlaybackStarted)
    }

    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
        dataModel?.delegate = nil
    }

    // MARK: - Loading

    @objc func cancelLoad() {
        dataModel.cancelLoad()
        refreshControl?.endRefreshing()
        ViewObjects.shared().hideLoadingScreen()
    }

    @objc private func reloadData() {
        tableView.reloadData()
    }

    private func addHeaderAndIndex() {
        if dataModel.songsCount == 0 && dataModel.albumsCount == 0 {
            tableView.tableHeaderView = nil
        } else {
            let headerView = UIView()
            headerView.translatesAutoresizingMaskIntoConstraints = false
            tableView.tableHeaderView = headerView
            NSLayoutConstraint.activate([
                headerView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
                headerView.widthAnchor.constraint(equalTo: tableView.widthAnchor),
                headerView.topAnchor.constraint(equalTo: tableView.topAnchor)
            ])

            let playAllAndShuffleHeader = PlayAllAndShuffleHeader(playAllHandler: { [weak self] in
                guard let self else { return }
                Database.shared().playAllSongs(myId ?? "", artist: myArtist ?? Artist())
            }, shuffleHandler: { [weak self] in
                guard let self else { return }
                Database.shared().shuffleAllSongs(myId ?? "", artist: myArtist ?? Artist())
            })
            headerView.addSubview(playAllAndShuffleHeader)
            NSLayoutConstraint.activate([
                playAllAndShuffleHeader.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
                playAllAndShuffleHeader.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
                playAllAndShuffleHeader.bottomAnchor.constraint(equalTo: headerView.bottomAnchor)
            ])

            if dataModel.songsCount > 0, let album = myAlbum {
                let albumHeader = AlbumTableViewHeader(album: album, tracks: Int(dataModel.songsCount), duration: Double(dataModel.folderLength))
                headerView.addSubview(albumHeader)
                NSLayoutConstraint.activate([
                    albumHeader.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
                    albumHeader.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
                    albumHeader.topAnchor.constraint(equalTo: headerView.topAnchor)
                ])
                playAllAndShuffleHeader.topAnchor.constraint(equalTo: albumHeader.bottomAnchor).isActive = true
            } else {
                playAllAndShuffleHeader.topAnchor.constraint(equalTo: headerView.topAnchor).isActive = true
            }

            tableView.tableHeaderView?.layoutIfNeeded()
            tableView.tableHeaderView = tableView.tableHeaderView
        }

        sectionInfo = dataModel.sectionInfo()
        if sectionInfo != nil {
            tableView.reloadData()
        }
    }

    // MARK: - Actions

    @IBAction private func nowPlayingAction(_ sender: Any) {
        let playerVC = PlayerViewController()
        playerVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(playerVC, animated: true)
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Int(dataModel.totalCount)
    }

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        guard let info = sectionInfo else { return nil }
        return info.compactMap { ($0 as? NSArray)?.firstObject as? String }
    }

    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        if let info = sectionInfo as NSArray?,
           let pair = info.objectAtIndexSafe(UInt(index)) as? NSArray,
           let row = pair.objectAtIndexSafe(1) as? NSNumber {
            let indexPath = IndexPath(row: row.intValue, section: 0)
            tableView.scrollToRow(at: indexPath, at: .top, animated: false)
        }
        return -1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        if indexPath.row < Int(dataModel.albumsCount) {
            cell.hideSecondaryLabel = true
            cell.hideNumberLabel = true
            cell.hideCoverArt = false
            cell.hideDurationLabel = true
            cell.update(model: dataModel.album(forTableViewRow: UInt(indexPath.row)))
        } else {
            cell.hideSecondaryLabel = false
            cell.hideCoverArt = true
            cell.hideDurationLabel = false
            let song = dataModel.song(forTableViewRow: UInt(indexPath.row))
            cell.update(model: song)
            if let song, !song.isVideo {
                cell.configureSongContextMenu(song: song, presenter: self)
            }
            if let track = song?.track, track.intValue != 0 {
                cell.hideNumberLabel = false
                cell.number = track.intValue
            } else {
                cell.hideNumberLabel = true
            }
        }
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row < Int(dataModel.albumsCount) {
            if let album = dataModel.album(forTableViewRow: UInt(indexPath.row)),
               let albumVC = AlbumViewController(artist: nil, orAlbum: album) {
                pushViewControllerCustom(albumVC)
            }
        } else {
            dataModel.playSong(atTableViewRow: UInt(indexPath.row))
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if indexPath.row < Int(dataModel.albumsCount) {
            return SwipeAction.downloadAndQueueConfig(model: dataModel.album(forTableViewRow: UInt(indexPath.row)))
        } else {
            if let song = dataModel.song(forTableViewRow: UInt(indexPath.row)), !song.isVideo {
                return SwipeAction.downloadAndQueueConfig(model: song)
            }
        }
        return nil
    }
}

// MARK: - SUSLoaderDelegate

extension AlbumViewController: SUSLoaderDelegate {
    @objc func loadingFailed(_ theLoader: SUSLoader!, withError error: Error!) {
        if Settings.shared().isPopupsEnabled {
            let nsError = error as NSError
            let msg = "There was an error loading the album.\n\nError \(nsError.code): \(nsError.localizedDescription)"
            let alert = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        }
        ViewObjects.shared().hideLoadingScreen()
        refreshControl?.endRefreshing()
    }

    @objc func loadingFinished(_ theLoader: SUSLoader!) {
        ViewObjects.shared().hideLoadingScreen()
        tableView.reloadData()
        addHeaderAndIndex()
        refreshControl?.endRefreshing()
    }
}
