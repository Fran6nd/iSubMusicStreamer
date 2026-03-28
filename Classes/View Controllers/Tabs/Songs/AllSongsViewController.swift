//
//  AllSongsViewController.swift
//  iSub
//
//  Created by François Ganot on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(AllSongsViewController) final class AllSongsViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .plain)
    @objc var searchBar: UISearchBar?

    @objc var reloadButton: UIButton?
    @objc var reloadLabel: UILabel?
    @objc var reloadImage: UIImageView?
    @objc var countLabel: UILabel?
    @objc var reloadTimeLabel: UILabel?
    @objc var url: URL?
    @objc var numberOfRows: Int = 0
    @objc var isSearching: Bool = false
    @objc var isProcessingArtists: Bool = true
    @objc var searchOverlay: UIVisualEffectView?
    @objc var dataModel: SUSAllSongsDAO!
    @objc var headerView: UIView?
    @objc var sectionInfo: [Any]?
    @objc var loadingScreen: LoadingScreen?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Songs"
        isProcessingArtists = true

        createDataModel()

        NotificationCenter.addObserverOnMainThread(self, selector: #selector(createDataModel), name: ISMSNotification_ServerSwitched)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(loadingFinishedNotification), name: ISMSNotification_AllSongsLoadingFinished)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(addURLRefBackButton), name: UIApplication.didBecomeActiveNotification.rawValue)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        tableView.refreshControl = RefreshControl { [weak self] in self?.reloadAction(nil) }
        tableView.backgroundColor = UIColor(named: "isubBackgroundColor")
        tableView.separatorStyle = .none
        tableView.rowHeight = Defines.rowHeight
        tableView.register(BlurredSectionHeader.self, forHeaderFooterViewReuseIdentifier: BlurredSectionHeader.reuseId)
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)
        tableView.dataSource = self
        tableView.delegate = self
    }

    @objc private func createDataModel() {
        dataModel?.delegate = nil
        dataModel = SUSAllSongsDAO(delegate: self)
    }

    @objc private func addURLRefBackButton() {
        if AppDelegate.shared().referringAppUrl != nil && AppDelegate.shared().mainTabBarController.selectedIndex != 4 {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: AppDelegate.shared(), action: #selector(AppDelegate.backToReferringApp))
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if SUSAllSongsLoader.isLoading() {
            showLoadingScreen()
        } else {
            addURLRefBackButton()

            navigationItem.rightBarButtonItem = nil
            if Music.shared().showPlayerIcon {
                navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: Defines.musicNoteImageSystemName), style: .plain, target: self, action: #selector(nowPlayingAction(_:)))
            }

            if dataModel.isDataLoaded {
                addCount()
            } else {
                tableView.tableHeaderView = nil
                let key = "\(Settings.shared().urlString ?? "")isAllSongsLoading"
                if (UserDefaults.standard.object(forKey: key) as? String) == "YES" {
                    let alert = UIAlertController(title: "Resume Load?",
                        message: "If you've reloaded the albums tab since this load started you should choose 'Restart Load'.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.",
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Restart Load", style: .destructive) { [weak self] _ in
                        self?.showLoadingScreen()
                        self?.dataModel.restartLoad()
                        self?.tableView.tableHeaderView = nil
                        self?.tableView.reloadData()
                        self?.tableView.refreshControl?.endRefreshing()
                    })
                    alert.addAction(UIAlertAction(title: "Resume Load", style: .default) { [weak self] _ in
                        self?.showLoadingScreen()
                        self?.dataModel.startLoad()
                        self?.tableView.tableHeaderView = nil
                        self?.tableView.reloadData()
                        self?.tableView.refreshControl?.endRefreshing()
                    })
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                    present(alert, animated: true)
                } else {
                    let alert = UIAlertController(title: "Load?",
                        message: "This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists, you should reload the Folders first.",
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                        self?.showLoadingScreen()
                        self?.dataModel.restartLoad()
                        self?.tableView.tableHeaderView = nil
                        self?.tableView.reloadData()
                        self?.tableView.refreshControl?.endRefreshing()
                    })
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                    present(alert, animated: true)
                }
            }
        }

        tableView.reloadData()
        Flurry.logEvent("AllSongsTab")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideLoadingScreen()
    }

    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
        dataModel?.delegate = nil
    }

    @objc func addCount() {
        let hv = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 110))
        headerView = hv

        let rb = UIButton(type: .custom)
        rb.autoresizingMask = .flexibleWidth
        rb.frame = CGRect(x: 0, y: 0, width: 320, height: 40)
        hv.addSubview(rb)
        reloadButton = rb

        let cLabel = UILabel(frame: CGRect(x: 0, y: 9, width: 320, height: 30))
        cLabel.autoresizingMask = .flexibleWidth
        cLabel.textColor = .label
        cLabel.textAlignment = .center
        cLabel.font = .boldSystemFont(ofSize: 30)
        hv.addSubview(cLabel)
        countLabel = cLabel

        let tLabel = UILabel(frame: CGRect(x: 0, y: 40, width: 320, height: 12))
        tLabel.autoresizingMask = .flexibleWidth
        tLabel.textColor = .secondaryLabel
        tLabel.textAlignment = .center
        tLabel.font = .systemFont(ofSize: 11)
        hv.addSubview(tLabel)
        reloadTimeLabel = tLabel

        let sb = UISearchBar(frame: CGRect(x: 0, y: 61, width: 320, height: 40))
        sb.autoresizingMask = .flexibleWidth
        sb.delegate = self
        sb.autocorrectionType = .no
        sb.searchBarStyle = .minimal
        sb.placeholder = "Song name"
        hv.addSubview(sb)
        searchBar = sb

        cLabel.text = "\(dataModel.count) Songs"

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let key = "\(Settings.shared().urlString ?? "")songsReloadTime"
        if let date = UserDefaults.standard.object(forKey: key) as? Date {
            tLabel.text = "last reload: \(formatter.string(from: date))"
        }

        tableView.tableHeaderView = hv
        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func reloadAction(_ sender: Any?) {
        if !ViewObjects.shared().isArtistsLoading {
            let alert = UIAlertController(title: "Reload?",
                message: "This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists or albums, you should reload the Folders and Albums tabs first.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .destructive) { [weak self] _ in
                self?.showLoadingScreen()
                self?.dataModel.restartLoad()
                self?.tableView.tableHeaderView = nil
                self?.tableView.reloadData()
                self?.tableView.refreshControl?.endRefreshing()
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
                self?.tableView.refreshControl?.endRefreshing()
            })
            present(alert, animated: true)
        } else {
            if Settings.shared().isPopupsEnabled {
                let alert = UIAlertController(title: "Please Wait",
                    message: "You cannot reload the Songs tab while the Folders or Albums tabs are loading",
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel))
                present(alert, animated: true)
            }
            tableView.refreshControl?.endRefreshing()
        }
    }

    @IBAction private func nowPlayingAction(_ sender: Any) {
        let playerVC = PlayerViewController()
        playerVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(playerVC, animated: true)
    }

    // MARK: - Search Overlay

    private func createSearchOverlay() {
        let style: UIBlurEffect.Style = traitCollection.userInterfaceStyle == .dark
            ? .systemUltraThinMaterialLight : .systemUltraThinMaterialDark
        let overlay = UIVisualEffectView(effect: UIBlurEffect(style: style))
        overlay.translatesAutoresizingMaskIntoConstraints = false

        let dismissButton = UIButton(type: .custom)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.addTarget(self, action: #selector(searchBarSearchButtonClicked(_:)), for: .touchUpInside)
        overlay.contentView.addSubview(dismissButton)

        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dismissButton.leadingAnchor.constraint(equalTo: overlay.leadingAnchor),
            dismissButton.trailingAnchor.constraint(equalTo: overlay.trailingAnchor),
            dismissButton.topAnchor.constraint(equalTo: overlay.topAnchor),
            dismissButton.bottomAnchor.constraint(equalTo: overlay.bottomAnchor)
        ])

        overlay.alpha = 0
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) { overlay.alpha = 1 }
        searchOverlay = overlay
    }

    private func hideSearchOverlay() {
        guard let overlay = searchOverlay else { return }
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            overlay.alpha = 0
        }, completion: { _ in
            overlay.removeFromSuperview()
            self.searchOverlay = nil
        })
    }

    // MARK: - Loading Screen

    private func registerForLoadingNotifications() {
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateLoadingScreen(_:)), name: ISMSNotification_AllSongsLoadingArtists)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateLoadingScreen(_:)), name: ISMSNotification_AllSongsLoadingAlbums)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateLoadingScreen(_:)), name: ISMSNotification_AllSongsArtistName)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateLoadingScreen(_:)), name: ISMSNotification_AllSongsAlbumName)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateLoadingScreen(_:)), name: ISMSNotification_AllSongsSongName)
    }

    private func unregisterForLoadingNotifications() {
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_AllSongsLoadingArtists)
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_AllSongsLoadingAlbums)
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_AllSongsArtistName)
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_AllSongsAlbumName)
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_AllSongsSongName)
    }

    @objc private func updateLoadingScreen(_ notification: Notification) {
        let name = notification.object as? String
        switch notification.name.rawValue {
        case ISMSNotification_AllSongsLoadingArtists:
            isProcessingArtists = true
            loadingScreen?.loadingTitle1.text = "Processing Artist:"
            loadingScreen?.loadingTitle2.text = "Processing Album:"
        case ISMSNotification_AllSongsLoadingAlbums:
            isProcessingArtists = false
            loadingScreen?.loadingTitle1.text = "Processing Album:"
            loadingScreen?.loadingTitle2.text = "Processing Song:"
        case ISMSNotification_AllSongsArtistName:
            isProcessingArtists = true
            loadingScreen?.loadingTitle1.text = "Processing Artist:"
            loadingScreen?.loadingTitle2.text = "Processing Album:"
            loadingScreen?.loadingMessage1.text = name
        case ISMSNotification_AllSongsAlbumName:
            if isProcessingArtists {
                loadingScreen?.loadingMessage2.text = name
            } else {
                loadingScreen?.loadingMessage1.text = name
            }
        case ISMSNotification_AllSongsSongName:
            isProcessingArtists = false
            loadingScreen?.loadingTitle1.text = "Processing Album:"
            loadingScreen?.loadingTitle2.text = "Processing Song:"
            loadingScreen?.loadingMessage2.text = name
        default: break
        }
    }

    @objc func showLoadingScreen() {
        loadingScreen = LoadingScreen(onView: view, message: ["Processing Artist:", "", "Processing Album:", ""], blockInput: true, mainWindow: false)
        tableView.isScrollEnabled = false
        tableView.allowsSelection = false
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = nil
        registerForLoadingNotifications()
    }

    @objc func hideLoadingScreen() {
        unregisterForLoadingNotifications()
        tableView.isScrollEnabled = true
        tableView.allowsSelection = true
        loadingScreen?.hide()
        loadingScreen = nil
    }

    @objc private func loadingFinishedNotification() {
        tableView.reloadData()
        createDataModel()
        addCount()
        hideLoadingScreen()
    }

    // MARK: - Helpers

    private func isInSearchMode() -> Bool {
        isSearching && (dataModel.searchCount > 0 || (searchBar?.text?.count ?? 0) > 0)
    }

    private func songAtIndexPath(_ indexPath: IndexPath) -> Song? {
        if isInSearchMode() {
            return dataModel.songForPosition(inSearch: UInt(indexPath.row + 1))
        } else {
            let idx = dataModel.index() as? [ISMSIndex] ?? []
            guard indexPath.section < idx.count else { return nil }
            let sectionStart = idx[indexPath.section].position
            return dataModel.song(forPosition: sectionStart + UInt(indexPath.row + 1))
        }
    }
}

// MARK: - UITableViewDataSource

extension AllSongsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        if isInSearchMode() { return 1 }
        return (dataModel.index() as? [Any])?.count ?? 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isInSearchMode() { return Int(dataModel.searchCount) }
        let idx = dataModel.index() as? [ISMSIndex] ?? []
        guard section < idx.count else { return 0 }
        return Int(idx[section].count)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        cell.hideNumberLabel = true
        let song = songAtIndexPath(indexPath)
        cell.update(model: song)
        if let song, !song.isVideo {
            cell.configureSongContextMenu(song: song, presenter: self)
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension AllSongsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if isInSearchMode() { return 0 }
        return Defines.rowHeight - 5
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if isInSearchMode() { return nil }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: BlurredSectionHeader.reuseId) as! BlurredSectionHeader
        let idx = dataModel.index() as? [ISMSIndex] ?? []
        if section < idx.count { header.text = idx[section].name }
        return header
    }

    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        if isInSearchMode() { return nil }
        var titles = ["{search}"]
        let idx = dataModel.index() as? [ISMSIndex] ?? []
        titles.append(contentsOf: idx.compactMap { $0.name })
        return titles
    }

    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        if isInSearchMode() { return -1 }
        if index == 0 {
            tableView.scrollRectToVisible(CGRect(x: 0, y: 50, width: 320, height: 40), animated: false)
            return -1
        }
        return index - 1
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let song = songAtIndexPath(indexPath) else { return }

        if Settings.shared().isJukeboxEnabled {
            Database.shared().resetJukeboxPlaylist()
        } else {
            Database.shared().resetCurrentPlaylistDb()
        }

        song.addToCurrentPlaylistDbQueue()

        if Settings.shared().isJukeboxEnabled {
            Jukebox.shared().stop()
            Jukebox.shared().clearPlaylist()
            Jukebox.shared().addSong(song.songId ?? "")
        }

        PlayQueue.shared().isShuffle = false
        NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
        Music.shared().playSong(atPosition: 0)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let song = songAtIndexPath(indexPath), !song.isVideo else { return nil }
        return SwipeAction.downloadAndQueueConfig(model: song)
    }
}

// MARK: - UISearchBarDelegate

extension AllSongsViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        if searchBar.text?.isEmpty != false { createSearchOverlay() }
        isSearching = true
        tableView.setContentOffset(CGPoint(x: 0, y: 56), animated: true)
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(searchBarSearchButtonClicked(_:)))
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.count > 0 {
            hideSearchOverlay()
            dataModel.search(forSongName: searchText)
        } else {
            tableView.setContentOffset(CGPoint(x: 0, y: 56), animated: true)
            createSearchOverlay()
            Database.shared().allSongsDbQueue?.inDatabase { db in
                db.executeUpdate("DROP TABLE allSongsSearch", withArgumentsIn: [])
            }
        }
        tableView.reloadData()
    }

    @objc func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.searchBar?.text = ""
        self.searchBar?.resignFirstResponder()
        hideSearchOverlay()
        isSearching = false
        navigationItem.leftBarButtonItem = nil
        tableView.reloadData()
        tableView.setContentOffset(CGPoint(x: 0, y: 56), animated: true)
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - SUSLoaderDelegate

extension AllSongsViewController: SUSLoaderDelegate {
    @objc func loadingFailed(_ theLoader: SUSLoader!, withError error: Error!) {
        tableView.reloadData()
        createDataModel()
        hideLoadingScreen()
    }

    @objc func loadingFinished(_ theLoader: SUSLoader!) {
        // Handled by notification
    }
}
