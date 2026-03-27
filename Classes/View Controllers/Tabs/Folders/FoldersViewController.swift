//
//  FoldersViewController.swift
//  iSub
//
//  Created by François Ganot on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(FoldersViewController) final class FoldersViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    var isSearching = false
    var isCountShowing = false
    var headerView: UIView?
    var searchBar: UISearchBar?
    var searchOverlay: UIVisualEffectView?
    var countLabel: UILabel?
    var reloadTimeLabel: UILabel?
    var dropdown: FolderDropdownControl?
    var dataModel: SUSRootFoldersDAO!

    // MARK: - Lifecycle

    private func createDataModel() {
        dataModel = SUSRootFoldersDAO(delegate: self)
        dataModel.selectedFolderId = Settings.shared().rootFoldersSelectedFolderId
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        createDataModel()

        title = "Folders"
        view.backgroundColor = UIColor(named: "isubBackgroundColor")

        isSearching = false
        isCountShowing = false

        NotificationCenter.addObserverOnMainThread(self, selector: #selector(serverSwitched), name: ISMSNotification_ServerSwitched)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateFolders), name: ISMSNotification_ServerCheckPassed)

        tableView.refreshControl = RefreshControl { [weak self] in
            self?.loadData(Settings.shared().rootFoldersSelectedFolderId)
        }

        tableView.backgroundColor = UIColor(named: "isubBackgroundColor")
        tableView.separatorStyle = .none
        tableView.register(BlurredSectionHeader.self, forHeaderFooterViewReuseIdentifier: BlurredSectionHeader.reuseId)
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)
        tableView.rowHeight = Defines.rowHeight

        if dataModel.isRootFolderIdCached {
            addCount()
            tableView.setContentOffset(.zero, animated: false)
        }

        NotificationCenter.addObserverOnMainThread(self, selector: #selector(addURLRefBackButton), name: UIApplication.didBecomeActiveNotification.rawValue)
    }

    @objc private func addURLRefBackButton() {
        if AppDelegate.shared().referringAppUrl != nil && AppDelegate.shared().mainTabBarController.selectedIndex != 4 {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: AppDelegate.shared(), action: #selector(AppDelegate.backToReferringApp))
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        addURLRefBackButton()

        navigationItem.rightBarButtonItem = nil
        if Music.shared().showPlayerIcon {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: Defines.musicNoteImageSystemName), style: .plain, target: self, action: #selector(nowPlayingAction(_:)))
        }

        if !SUSAllSongsLoader.isLoading() && !ViewObjects.shared().isArtistsLoading {
            if !dataModel.isRootFolderIdCached {
                loadData(Settings.shared().rootFoldersSelectedFolderId)
            }
        }

        Flurry.logEvent("FoldersTab")
    }

    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
        dataModel.delegate = nil
        dropdown?.delegate = nil
    }

    // MARK: - Loading

    private func updateCount() {
        let count = dataModel.count
        countLabel?.text = count == 1 ? "\(count) Folder" : "\(count) Folders"

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        if let reloadTime = Settings.shared().rootFoldersReloadTime {
            reloadTimeLabel?.text = "last reload: \(formatter.string(from: reloadTime))"
        }
    }

    private func removeCount() {
        tableView.tableHeaderView = nil
        isCountShowing = false
    }

    private func addCount() {
        isCountShowing = true

        let hv = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 157))
        hv.autoresizingMask = .flexibleWidth
        hv.backgroundColor = view.backgroundColor
        headerView = hv

        let cLabel = UILabel(frame: CGRect(x: 0, y: 9, width: 320, height: 30))
        cLabel.autoresizingMask = .flexibleWidth
        cLabel.textColor = .label
        cLabel.textAlignment = .center
        cLabel.font = .boldSystemFont(ofSize: 32)
        hv.addSubview(cLabel)
        countLabel = cLabel

        let rLabel = UILabel(frame: CGRect(x: 0, y: 40, width: 320, height: 14))
        rLabel.autoresizingMask = .flexibleWidth
        rLabel.textColor = .secondaryLabel
        rLabel.textAlignment = .center
        rLabel.font = .systemFont(ofSize: 11)
        hv.addSubview(rLabel)
        reloadTimeLabel = rLabel

        let dd = FolderDropdownControl(frame: CGRect(x: 50, y: 61, width: 220, height: 40))
        dd.delegate = self
        if let dropdownFolders = SUSRootFoldersDAO.folderDropdownFolders() {
            dd.folders = dropdownFolders as NSDictionary
        } else {
            dd.folders = NSDictionary(object: "All Folders", forKey: NSNumber(value: -1))
        }
        dd.selectFolderWithId(dataModel.selectedFolderId)
        hv.addSubview(dd)
        dropdown = dd

        let sb = UISearchBar(frame: CGRect(x: 0, y: 111, width: 320, height: 40))
        sb.autoresizingMask = .flexibleWidth
        sb.searchBarStyle = .minimal
        sb.delegate = self
        sb.autocorrectionType = .no
        sb.placeholder = "Folder name"
        hv.addSubview(sb)
        searchBar = sb

        updateCount()

        if UIAccessibility.isVoiceOverRunning {
            let voiceOverRefresh = UIButton(type: .custom)
            voiceOverRefresh.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            voiceOverRefresh.addTarget(self, action: #selector(reloadAction(_:)), for: .touchUpInside)
            voiceOverRefresh.accessibilityLabel = "Reload Folders"
            hv.addSubview(voiceOverRefresh)

            cLabel.frame = CGRect(x: 50, y: 5, width: 220, height: 30)
            rLabel.frame = CGRect(x: 50, y: 36, width: 220, height: 12)
        }

        tableView.tableHeaderView = hv
    }

    private func cancelLoad() {
        dataModel.cancelLoad()
        ViewObjects.shared().hideLoadingScreen()
        tableView.refreshControl?.endRefreshing()
    }

    private func loadData(_ folderId: NSNumber?) {
        dropdown?.updateFolders()
        ViewObjects.shared().isArtistsLoading = true
        ViewObjects.shared().showAlbumLoadingScreen(AppDelegate.shared().window, sender: self)
        dataModel.selectedFolderId = folderId
        dataModel.startLoad()
    }

    // MARK: - Actions

    @objc private func reloadAction(_ sender: Any) {
        if !SUSAllSongsLoader.isLoading() {
            loadData(Settings.shared().rootFoldersSelectedFolderId)
        } else if Settings.shared().isPopupsEnabled {
            let alert = UIAlertController(title: "Please Wait",
                message: "You cannot reload the Artists tab while the Albums or Songs tabs are loading",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        }
    }

    @objc private func settingsAction(_ sender: Any) {
        let serverListVC = ServerListViewController(nibName: "ServerListViewController", bundle: nil)
        serverListVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(serverListVC, animated: true)
    }

    @IBAction private func nowPlayingAction(_ sender: Any) {
        let playerVC = PlayerViewController()
        playerVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(playerVC, animated: true)
    }

    // MARK: - Folder Dropdown Delegate helpers

    @objc private func serverSwitched() {
        createDataModel()
        if !dataModel.isRootFolderIdCached {
            tableView.reloadData()
            removeCount()
        }
        folderDropdownSelectFolder(NSNumber(value: -1))
    }

    @objc private func updateFolders() {
        dropdown?.updateFolders()
    }

    // MARK: - Search Overlay

    private func createSearchOverlay() {
        let effectStyle: UIBlurEffect.Style = traitCollection.userInterfaceStyle == .dark
            ? .systemUltraThinMaterialLight
            : .systemUltraThinMaterialDark
        let overlay = UIVisualEffectView(effect: UIBlurEffect(style: effectStyle))
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
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            overlay.alpha = 1
        }
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

    // MARK: - Table helpers

    private func artist(at indexPath: IndexPath) -> Artist? {
        if isSearching && (dataModel.searchCount > 0 || (searchBar?.text?.count ?? 0) > 0) {
            return dataModel.artistForPosition(inSearch: UInt(indexPath.row + 1))
        } else {
            let indexPositions = dataModel.indexPositions as? [NSNumber] ?? []
            if indexPositions.count > indexPath.section {
                let sectionStartIndex = indexPositions[indexPath.section].uintValue
                return dataModel.artist(forPosition: sectionStartIndex + UInt(indexPath.row))
            }
            return nil
        }
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension FoldersViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        if isSearching && (dataModel.searchCount > 0 || (searchBar?.text?.count ?? 0) > 0) {
            return 1
        }
        return dataModel.indexNames.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearching && (dataModel.searchCount > 0 || (searchBar?.text?.count ?? 0) > 0) {
            return Int(dataModel.searchCount)
        } else if (dataModel.indexCounts as? [NSNumber] ?? []).count > section {
            return (dataModel.indexCounts as! [NSNumber])[section].intValue
        }
        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        cell.hideNumberLabel = true
        cell.hideCoverArt = true
        cell.hideSecondaryLabel = true
        cell.hideDurationLabel = true
        cell.update(model: artist(at: indexPath))
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if isSearching && (dataModel.searchCount > 0 || (searchBar?.text?.count ?? 0) > 0) { return nil }
        if dataModel.indexNames.count == 0 { return nil }

        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: BlurredSectionHeader.reuseId) as! BlurredSectionHeader
        header.text = (dataModel.indexNames as? [String])?[section]
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if isSearching && (dataModel.searchCount > 0 || (searchBar?.text?.count ?? 0) > 0) { return 0 }
        if dataModel.indexNames.count == 0 { return 0 }
        return Defines.rowHeight - 5
    }

    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        if isSearching && (dataModel.searchCount > 0 || (searchBar?.text?.count ?? 0) > 0) { return nil }
        var titles = [UITableView.indexSearch]
        titles.append(contentsOf: dataModel.indexNames as? [String] ?? [])
        return titles
    }

    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        if isSearching && (dataModel.searchCount > 0 || (searchBar?.text?.count ?? 0) > 0) { return -1 }
        if index == 0 {
            if dropdown?.folders == nil || (dropdown?.folders.count ?? 0) == 2 {
                tableView.setContentOffset(CGPoint(x: 0, y: 104), animated: false)
            } else {
                tableView.setContentOffset(CGPoint(x: 0, y: 54), animated: false)
            }
            return -1
        }
        return index - 1
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let artist = artist(at: indexPath), let vc = AlbumViewController(artist: artist, orAlbum: nil) else { return }
        pushViewControllerCustom(vc)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let model = artist(at: indexPath) else { return nil }
        return SwipeAction.downloadAndQueueConfig(model: model)
    }
}

// MARK: - UISearchBarDelegate

extension FoldersViewController: UISearchBarDelegate {

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        if isSearching { return }
        isSearching = true
        dataModel.clearSearchTable()

        dropdown?.closeDropdownFast()
        tableView.setContentOffset(CGPoint(x: 0, y: 104), animated: true)

        if (searchBar.text?.count ?? 0) == 0 {
            createSearchOverlay()
        }

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(searchBarSearchButtonClicked(_:)))
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.count > 0 {
            hideSearchOverlay()
            dataModel.search(forFolderName: self.searchBar?.text ?? "")
        } else {
            createSearchOverlay()
            dataModel.clearSearchTable()
            tableView.setContentOffset(CGPoint(x: 0, y: 104), animated: false)
        }
        tableView.reloadData()
    }

    @objc func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        updateCount()

        self.searchBar?.text = ""
        self.searchBar?.resignFirstResponder()
        hideSearchOverlay()
        isSearching = false

        navigationItem.leftBarButtonItem = nil
        dataModel.clearSearchTable()
        tableView.reloadData()
        tableView.setContentOffset(CGPoint(x: 0, y: 104), animated: true)
    }
}

// MARK: - SUSLoaderDelegate

extension FoldersViewController: SUSLoaderDelegate {

    func loadingFailed(_ theLoader: SUSLoader!, withError error: Error!) {
        ViewObjects.shared().isArtistsLoading = false
        ViewObjects.shared().hideLoadingScreen()
        tableView.refreshControl?.endRefreshing()

        EX2Dispatch.runInMainThread(afterDelay: 0.3) {
            let alert = UIAlertController(title: "Subsonic Error",
                message: error.localizedDescription,
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            self.present(alert, animated: true)
        }
    }

    func loadingFinished(_ theLoader: SUSLoader!) {
        if isCountShowing {
            updateCount()
        } else {
            addCount()
        }
        tableView.reloadData()
        ViewObjects.shared().isArtistsLoading = false
        ViewObjects.shared().hideLoadingScreen()
        tableView.refreshControl?.endRefreshing()
    }
}

// MARK: - FolderDropdownDelegate

extension FoldersViewController: FolderDropdownDelegate {

    func folderDropdownMoveViewsY(_ y: Float) {
        tableView.performBatchUpdates({
            tableView.tableHeaderView?.height += CGFloat(y)
            searchBar?.y += CGFloat(y)
            tableView.tableHeaderView = tableView.tableHeaderView

            let visibleSections = Set(tableView.indexPathsForVisibleRows?.map { $0.section } ?? [])
            for section in visibleSections {
                let sectionHeader = tableView.headerView(forSection: section)
                sectionHeader?.y += CGFloat(y)
            }
        }, completion: nil)
    }

    func folderDropdownSelectFolder(_ folderId: NSNumber) {
        dropdown?.selectFolderWithId(folderId)

        Settings.shared().rootFoldersSelectedFolderId = folderId

        dataModel.selectedFolderId = folderId
        isSearching = false
        if dataModel.isRootFolderIdCached {
            tableView.reloadData()
            updateCount()
        } else {
            loadData(folderId)
        }
    }
}
