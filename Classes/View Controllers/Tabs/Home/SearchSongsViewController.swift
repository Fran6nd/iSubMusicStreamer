//
//  SearchSongsViewController.swift
//  iSub
//
//  Created by François Ganot on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

// Preserved ObjC-compatible enum for use from SearchAllViewController
@objc enum ISMSSearchSongsSearchType: Int {
    case artists = 0
    case albums  = 1
    case songs   = 2
}
let ISMSSearchSongsSearchType_Artists = ISMSSearchSongsSearchType.artists
let ISMSSearchSongsSearchType_Albums  = ISMSSearchSongsSearchType.albums
let ISMSSearchSongsSearchType_Songs   = ISMSSearchSongsSearchType.songs

@objc(SearchSongsViewController) final class SearchSongsViewController: UITableViewController {

    @objc var query: String?
    @objc var searchType: ISMSSearchSongsSearchType = .artists
    @objc var listOfArtists: NSMutableArray?
    @objc var listOfAlbums: NSMutableArray?
    @objc var listOfSongs: NSMutableArray?
    @objc var offset: UInt = 0
    @objc var isMoreResults: Bool = true
    @objc var isLoading: Bool = false

    private var dataTask: URLSessionDataTask?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = Music.shared().showPlayerIcon
            ? UIBarButtonItem(image: UIImage(systemName: Defines.musicNoteImageSystemName), style: .plain, target: self, action: #selector(nowPlayingAction(_:)))
            : nil

        tableView.rowHeight = Defines.rowHeight
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dataTask?.cancel()
        dataTask = nil
    }

    // MARK: - Actions

    @IBAction private func nowPlayingAction(_ sender: Any) {
        let playerVC = PlayerViewController()
        playerVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(playerVC, animated: true)
    }

    // MARK: - Helpers

    private var artists: NSMutableArray { listOfArtists ?? NSMutableArray() }
    private var albums: NSMutableArray  { listOfAlbums  ?? NSMutableArray() }
    private var songs: NSMutableArray   { listOfSongs   ?? NSMutableArray() }

    private func currentCount() -> Int {
        switch searchType {
        case .artists: return artists.count
        case .albums:  return albums.count
        case .songs:   return songs.count
        }
    }

    private func loadMoreResults() {
        guard !isLoading else { return }
        isLoading = true
        offset += 20

        let offsetStr = "\(offset)"
        let queryStr = Settings.shared().isNewSearchAPI ? "\(query ?? "")*" : (query ?? "")

        let action: String
        let parameters: [String: String]

        if Settings.shared().isNewSearchAPI {
            action = "search2"
            switch searchType {
            case .artists:
                parameters = ["artistCount": "20", "albumCount": "0", "songCount": "0", "query": queryStr, "artistOffset": offsetStr]
            case .albums:
                parameters = ["artistCount": "0", "albumCount": "20", "songCount": "0", "query": queryStr, "albumOffset": offsetStr]
            case .songs:
                parameters = ["artistCount": "0", "albumCount": "0", "songCount": "20", "query": queryStr, "songOffset": offsetStr]
            }
        } else {
            action = "search"
            parameters = ["count": "20", "any": queryStr, "offset": offsetStr]
        }

        guard let request = NSMutableURLRequest(susAction: action, parameters: parameters) else {
            isLoading = false
            return
        }

        dataTask = SUSLoader.sharedSession().dataTask(with: request as URLRequest) { [weak self] data, _, error in
            guard let self else { return }
            if let error = error {
                EX2Dispatch.runInMainThreadAsync {
                    if Settings.shared().isPopupsEnabled {
                        let msg = "There was an error performing the search.\n\nError: \(error.localizedDescription)"
                        let alert = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
                        self.present(alert, animated: true)
                    }
                    self.isLoading = false
                }
                return
            }
            guard let data = data else { self.isLoading = false; return }

            let parser = SearchXMLParser()
            let xmlParser = XMLParser(data: data)
            xmlParser.delegate = parser
            xmlParser.parse()

            switch self.searchType {
            case .artists:
                if parser.listOfArtists.isEmpty { self.isMoreResults = false }
                else { for a in parser.listOfArtists { self.listOfArtists?.add(a) } }
            case .albums:
                if parser.listOfAlbums.isEmpty { self.isMoreResults = false }
                else { for a in parser.listOfAlbums { self.listOfAlbums?.add(a) } }
            case .songs:
                if parser.listOfSongs.isEmpty { self.isMoreResults = false }
                else { for s in parser.listOfSongs { self.listOfSongs?.add(s) } }
            }

            EX2Dispatch.runInMainThreadAsync {
                self.tableView.reloadData()
                self.isLoading = false
            }
        }
        dataTask?.resume()
    }

    private func makeLoadingCell(row: Int) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "NoReuse")
        cell.backgroundColor = UIColor(named: "isubBackgroundColor")
        if isMoreResults {
            cell.textLabel?.text = "Loading more results..."
            let indicator = UIActivityIndicatorView(style: .medium)
            let rowHeight = tableView(tableView, heightForRowAt: IndexPath(row: row, section: 0))
            indicator.center = CGPoint(x: 300, y: rowHeight / 2)
            indicator.autoresizingMask = .flexibleLeftMargin
            cell.addSubview(indicator)
            indicator.startAnimating()
            loadMoreResults()
        } else {
            cell.textLabel?.text = (artists.count > 0 || albums.count > 0 || songs.count > 0)
                ? "No more search results" : "No results"
        }
        return cell
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        currentCount() + 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let count = currentCount()
        if indexPath.row < count {
            let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
            cell.hideNumberLabel = true
            switch searchType {
            case .artists:
                cell.hideCoverArt = true; cell.hideSecondaryLabel = true; cell.hideDurationLabel = true
                cell.update(model: artists[indexPath.row] as? TableCellModel)
            case .albums:
                cell.hideCoverArt = false; cell.hideDurationLabel = true
                cell.update(model: albums[indexPath.row] as? TableCellModel)
            case .songs:
                cell.hideCoverArt = false; cell.hideDurationLabel = false
                cell.update(model: songs[indexPath.row] as? TableCellModel)
            }
            return cell
        } else {
            return makeLoadingCell(row: indexPath.row)
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let count = currentCount()
        guard indexPath.row < count else {
            tableView.deselectRow(at: indexPath, animated: false)
            return
        }

        switch searchType {
        case .artists:
            if let artist = artists[indexPath.row] as? Artist,
               let albumVC = AlbumViewController(artist: artist, orAlbum: nil) {
                pushViewControllerCustom(albumVC)
            }
        case .albums:
            if let album = albums[indexPath.row] as? Album,
               let albumVC = AlbumViewController(artist: nil, orAlbum: album) {
                pushViewControllerCustom(albumVC)
            }
        case .songs:
            let songList = songs.compactMap { $0 as? Song }
            if Settings.shared().isJukeboxEnabled {
                Database.shared().resetJukeboxPlaylist()
                Jukebox.shared().clearRemotePlaylist()
            } else {
                Database.shared().resetCurrentPlaylistDb()
            }
            var songIds: [String] = []
            for song in songList {
                song.addToCurrentPlaylistDbQueue()
                if Settings.shared().isJukeboxEnabled, let sid = song.songId { songIds.append(sid) }
            }
            if Settings.shared().isJukeboxEnabled {
                Jukebox.shared().stop()
                Jukebox.shared().clearPlaylist()
                Jukebox.shared().addSongs(songIds)
            }
            PlayQueue.shared().isShuffle = false
            NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
            Music.shared().playSong(atPosition: indexPath.row)
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let count = currentCount()
        guard indexPath.row < count else { return nil }

        let model: TableCellModel?
        switch searchType {
        case .artists: model = artists[indexPath.row] as? TableCellModel
        case .albums:  model = albums[indexPath.row]  as? TableCellModel
        case .songs:   model = songs[indexPath.row]   as? TableCellModel
        }
        guard let model else { return nil }
        return SwipeAction.downloadAndQueueConfig(model: model)
    }
}
