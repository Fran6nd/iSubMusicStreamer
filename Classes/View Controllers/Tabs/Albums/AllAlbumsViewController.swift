//
//  AllAlbumsViewController.swift
//  iSub
//
//  Created by François Ganot on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(AllAlbumsViewController) final class AllAlbumsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!

    @objc var reloadButton: UIButton?
    @objc var countLabel: UILabel?
    @objc var reloadTimeLabel: UILabel?
    @objc var url: URL?
    @objc var isAllAlbumsLoading: Bool = false
    @objc var isProcessingArtists: Bool = false
    @objc var isSearching: Bool = false
    @objc var searchOverlay: UIVisualEffectView?
    @objc var dataModel: SUSAllAlbumsDAO!
    @objc var allSongsDataModel: SUSAllSongsDAO!
    @objc var headerView: UIView?
    @objc var sectionInfo: [Any]?
    @objc var loadingScreen: LoadingScreen?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Albums"

        createDataModel()

        NotificationCenter.addObserverOnMainThread(self, selector: #selector(createDataModel), name: ISMSNotification_ServerSwitched)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(loadingFinishedNotification), name: ISMSNotification_AllSongsLoadingFinished)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(addURLRefBackButton), name: UIApplication.didBecomeActiveNotification.rawValue)

        tableView.refreshControl = RefreshControl { [weak self] in self?.reloadAction(nil) }
        tableView.rowHeight = Defines.rowHeight
        tableView.register(BlurredSectionHeader.self, forHeaderFooterViewReuseIdentifier: BlurredSectionHeader.reuseId)
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)
        tableView.dataSource = self
        tableView.delegate = self
    }

    @objc private func createDataModel() {
        dataModel = SUSAllAlbumsDAO()
        allSongsDataModel?.delegate = nil
        allSongsDataModel = SUSAllSongsDAO(delegate: self)
    }

    @objc func addCount() {
        let hv = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 110))
        hv.autoresizingMask = .flexibleWidth
        headerView = hv

        let cLabel = UILabel(frame: CGRect(x: 0, y: 9, width: 320, height: 30))
        cLabel.autoresizingMask = .flexibleWidth
        cLabel.textColor = .label
        cLabel.textAlignment = .center
        cLabel.font = .boldSystemFont(ofSize: 32)
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
        sb.searchBarStyle = .minimal
        sb.autoresizingMask = .flexibleWidth
        sb.delegate = self
        sb.autocorrectionType = .no
        sb.placeholder = "Album name"
        hv.addSubview(sb)
        searchBar = sb

        cLabel.text = "\(dataModel.count) Albums"

        let defaults = UserDefaults.standard
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let key = "\(Settings.shared().urlString ?? "")songsReloadTime"
        if let date = defaults.object(forKey: key) as? Date {
            tLabel.text = "last reload: \(formatter.string(from: date))"
        }

        tableView.tableHeaderView = hv
        tableView.reloadData()
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
                        self?.allSongsDataModel.restartLoad()
                        self?.tableView.tableHeaderView = nil
                        self?.tableView.reloadData()
                        self?.tableView.refreshControl?.endRefreshing()
                    })
                    alert.addAction(UIAlertAction(title: "Resume Load", style: .destructive) { [weak self] _ in
                        self?.showLoadingScreen()
                        self?.allSongsDataModel.startLoad()
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
                    alert.addAction(UIAlertAction(title: "OK", style: .destructive) { [weak self] _ in
                        self?.showLoadingScreen()
                        self?.allSongsDataModel.restartLoad()
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
        Flurry.logEvent("AllAlbumsTab")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideLoadingScreen()
    }

    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }

    // MARK: - Actions

    @objc private func reloadAction(_ sender: Any?) {
        if !SUSAllSongsLoader.isLoading() {
            let alert = UIAlertController(title: "Reload?",
                message: "This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists, you should reload the Folders tab first.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .destructive) { [weak self] _ in
                self?.showLoadingScreen()
                self?.allSongsDataModel.restartLoad()
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
                    message: "You cannot reload the Albums tab while the Folders or Songs tabs are loading",
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

    // MARK: - Search

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
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
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
        case ISMSNotification_AllSongsSorting:
            loadingScreen?.loadingTitle1.text = "Sorting"
            loadingScreen?.loadingTitle2.text = ""
            loadingScreen?.loadingMessage1.text = name
            loadingScreen?.loadingMessage2.text = ""
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

    private func albumAtIndexPath(_ indexPath: IndexPath) -> Album? {
        if isInSearchMode() {
            return dataModel.albumForPosition(inSearch: UInt(indexPath.row + 1))
        } else {
            let idx = dataModel.index() as? [ISMSIndex] ?? []
            guard indexPath.section < idx.count else { return nil }
            let sectionStart = idx[indexPath.section].position
            return dataModel.album(forPosition: sectionStart + UInt(indexPath.row + 1))
        }
    }
}

// MARK: - UITableViewDataSource

extension AllAlbumsViewController: UITableViewDataSource {
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
        cell.hideDurationLabel = true
        cell.update(model: albumAtIndexPath(indexPath))
        return cell
    }
}

// MARK: - UITableViewDelegate

extension AllAlbumsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if isInSearchMode() || (dataModel.index() as? [Any])?.isEmpty == true { return 0 }
        return Defines.rowHeight - 5
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if isInSearchMode() || (dataModel.index() as? [Any])?.isEmpty == true { return nil }
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
        if let album = albumAtIndexPath(indexPath),
           let albumVC = AlbumViewController(artist: nil, orAlbum: album) {
            pushViewControllerCustom(albumVC)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let model = albumAtIndexPath(indexPath) else { return nil }
        return SwipeAction.downloadAndQueueConfig(model: model)
    }
}

// MARK: - UISearchBarDelegate

extension AllAlbumsViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        if isSearching { return }
        isSearching = true
        tableView.setContentOffset(CGPoint(x: 0, y: 56), animated: true)
        if searchBar.text?.isEmpty != false { createSearchOverlay() }
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(searchBarSearchButtonClicked(_:)))
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.count > 0 {
            hideSearchOverlay()
            dataModel.search(forAlbumName: searchText)
        } else {
            tableView.setContentOffset(CGPoint(x: 0, y: 56), animated: true)
            createSearchOverlay()
            Database.shared().allAlbumsDbQueue?.inDatabase { db in
                db.executeUpdate("DROP TABLE allAlbumsSearch", withArgumentsIn: [])
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
}

// MARK: - SUSLoaderDelegate

extension AllAlbumsViewController: SUSLoaderDelegate {
    @objc func loadingFailed(_ theLoader: SUSLoader!, withError error: Error!) {
        tableView.reloadData()
        createDataModel()
        hideLoadingScreen()
    }

    @objc func loadingFinished(_ theLoader: SUSLoader!) {
        // Handled by notification
    }
}
