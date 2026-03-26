//
//  SearchAllViewController.swift
//  iSub
//
//  Created by François Ganot on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(SearchAllViewController) final class SearchAllViewController: UITableViewController {

    @objc var listOfArtists: [Artist] = []
    @objc var listOfAlbums: [Album] = []
    @objc var listOfSongs: [Song] = []
    @objc var query: String?

    private var cellNames: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        if !listOfArtists.isEmpty { cellNames.append("Artists") }
        if !listOfAlbums.isEmpty  { cellNames.append("Albums") }
        if !listOfSongs.isEmpty   { cellNames.append("Songs") }

        tableView.rowHeight = Defines.rowHeight
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        cellNames.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        cell.update(primaryText: cellNames[indexPath.row], secondaryText: nil)
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let searchView = SearchSongsViewController(nibName: "SearchSongsViewController", bundle: nil)
        let type = cellNames[indexPath.row]
        switch type {
        case "Artists":
            searchView.listOfArtists = NSMutableArray(array: listOfArtists)
            searchView.searchType = ISMSSearchSongsSearchType_Artists
        case "Albums":
            searchView.listOfAlbums = NSMutableArray(array: listOfAlbums)
            searchView.searchType = ISMSSearchSongsSearchType_Albums
        case "Songs":
            searchView.listOfSongs = NSMutableArray(array: listOfSongs)
            searchView.searchType = ISMSSearchSongsSearchType_Songs
        default: break
        }
        searchView.query = query
        pushViewControllerCustom(searchView)
    }
}
