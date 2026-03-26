//
//  FolderDropdownControl.swift
//  iSub
//
//  Created by François Ganot on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit
import QuartzCore

private let kHeight: CGFloat = 40

@objc(FolderDropdownControl) final class FolderDropdownControl: UIView {

    @objc var arrowImage: CALayer!
    @objc var sizeIncrease: CGFloat = 0
    @objc var updatedfolders: NSMutableDictionary?
    @objc var selectedFolderLabel: UILabel!
    @objc var labels: NSMutableArray = NSMutableArray()
    @objc var isOpen: Bool = false
    @objc var selectedFolderId: NSNumber = NSNumber(value: -1)
    @objc var dropdownButton: UIButton!

    @objc var borderColor: UIColor = .systemGray { didSet { layer.borderColor = borderColor.cgColor } }
    @objc var textColor: UIColor   = .label
    @objc var lightColor: UIColor  = UIColor(named: "isubBackgroundColor") ?? .systemBackground
    @objc var darkColor: UIColor   = UIColor(named: "isubBackgroundColor") ?? .systemBackground

    @objc weak var delegate: FolderDropdownDelegate?

    private var _folders: NSDictionary = NSDictionary()
    @objc var folders: NSDictionary {
        get { _folders }
        set {
            _folders = newValue
            // Remove old labels
            for case let label as UILabel in labels { label.removeFromSuperview() }
            labels.removeAllObjects()

            sizeIncrease = CGFloat(newValue.count) * kHeight

            // Sort entries by name, excluding -1 (All Folders)
            var sortedPairs: [[Any]] = []
            for key in newValue.allKeys {
                if let n = key as? NSNumber, n.intValue != -1 {
                    sortedPairs.append([n, newValue[n] ?? ""])
                }
            }
            sortedPairs.sort {
                let a = ($0[1] as? String) ?? ""
                let b = ($1[1] as? String) ?? ""
                return a.caseInsensitiveCompare(b) == .orderedAscending
            }
            // Prepend "All Folders"
            sortedPairs.insert([NSNumber(value: -1), "All Folders"], at: 0)

            for (i, pair) in sortedPairs.enumerated() {
                let folderName = pair[1] as? String ?? ""
                let tag = (pair[0] as? NSNumber)?.intValue ?? -1
                let labelFrame = CGRect(x: 0, y: CGFloat(i + 1) * kHeight, width: frame.width, height: kHeight)

                let folderLabel = UILabel(frame: labelFrame)
                folderLabel.autoresizingMask = .flexibleWidth
                folderLabel.isUserInteractionEnabled = true
                folderLabel.backgroundColor = i % 2 == 0 ? lightColor : darkColor
                folderLabel.textColor = textColor
                folderLabel.textAlignment = .center
                folderLabel.font = .boldSystemFont(ofSize: 20)
                folderLabel.text = folderName
                folderLabel.tag = tag
                folderLabel.isAccessibilityElement = false
                addSubview(folderLabel)
                labels.add(folderLabel)

                let folderButton = UIButton(type: .custom)
                folderButton.frame = CGRect(origin: .zero, size: labelFrame.size)
                folderButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                folderButton.accessibilityLabel = folderName
                folderButton.isAccessibilityElement = isOpen
                folderButton.addTarget(self, action: #selector(selectFolder(_:)), for: .touchUpInside)
                folderLabel.addSubview(folderButton)
            }

            selectedFolderLabel.text = _folders[selectedFolderId] as? String
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        selectedFolderId = NSNumber(value: -1)
        _folders = (SUSRootFoldersDAO.folderDropdownFolders() as NSDictionary?) ?? NSDictionary()
        isOpen = false

        autoresizingMask = .flexibleWidth
        isUserInteractionEnabled = true
        backgroundColor = .systemGray5
        layer.borderColor = UIColor.systemGray.cgColor
        layer.borderWidth = 2
        layer.cornerRadius = 8
        layer.masksToBounds = true

        selectedFolderLabel = UILabel(frame: CGRect(x: 5, y: 0, width: frame.width - 10, height: kHeight))
        selectedFolderLabel.autoresizingMask = .flexibleWidth
        selectedFolderLabel.isUserInteractionEnabled = true
        selectedFolderLabel.backgroundColor = .clear
        selectedFolderLabel.textColor = .label
        selectedFolderLabel.textAlignment = .center
        selectedFolderLabel.font = .boldSystemFont(ofSize: 20)
        selectedFolderLabel.text = "All Folders"
        addSubview(selectedFolderLabel)

        let arrowContainer = UIView(frame: CGRect(x: 193, y: 12, width: 18, height: 18))
        arrowContainer.autoresizingMask = .flexibleLeftMargin
        addSubview(arrowContainer)

        arrowImage = CALayer()
        arrowImage.frame = CGRect(x: 0, y: 0, width: 18, height: 18)
        arrowImage.contentsGravity = .resizeAspect
        arrowImage.contents = UIImage(named: "folder-dropdown-arrow")?.cgImage
        arrowContainer.layer.addSublayer(arrowImage)

        dropdownButton = UIButton(frame: CGRect(x: 0, y: 0, width: 220, height: kHeight))
        dropdownButton.autoresizingMask = .flexibleWidth
        dropdownButton.accessibilityLabel = selectedFolderLabel.text
        dropdownButton.accessibilityHint = "Switches folders"
        dropdownButton.addTarget(self, action: #selector(toggleDropdown(_:)), for: .touchUpInside)
        addSubview(dropdownButton)

        updateFolders()
    }

    // MARK: - Actions

    @objc private func toggleDropdown(_ sender: Any?) {
        if isOpen {
            UIView.animate(withDuration: 0.25) {
                self.height -= self.sizeIncrease
                self.delegate?.folderDropdownMoveViewsY?(-Float(self.sizeIncrease))
            } completion: { _ in
                self.delegate?.folderDropdownViewsFinishedMoving?()
            }
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.25)
            arrowImage.transform = CATransform3DMakeRotation(0, 0, 0, 1)
            CATransaction.commit()
        } else {
            UIView.animate(withDuration: 0.25) {
                self.height += self.sizeIncrease
                self.delegate?.folderDropdownMoveViewsY?(Float(self.sizeIncrease))
            } completion: { _ in
                self.delegate?.folderDropdownViewsFinishedMoving?()
            }
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.25)
            arrowImage.transform = CATransform3DMakeRotation((.pi / 180) * -60, 0, 0, 1)
            CATransaction.commit()
        }
        isOpen = !isOpen

        for case let label as UILabel in labels {
            for case let button as UIButton in label.subviews {
                button.isAccessibilityElement = isOpen
            }
        }
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }

    @objc func closeDropdown() {
        if isOpen { toggleDropdown(nil) }
    }

    @objc func closeDropdownFast() {
        guard isOpen else { return }
        isOpen = false
        height -= sizeIncrease
        delegate?.folderDropdownMoveViewsY?(-Float(sizeIncrease))
        arrowImage.transform = CATransform3DMakeRotation(0, 0, 0, 1)
        delegate?.folderDropdownViewsFinishedMoving?()
    }

    @objc private func selectFolder(_ sender: UIButton) {
        guard let label = sender.superview as? UILabel else { return }
        selectedFolderId = NSNumber(value: label.tag)
        selectedFolderLabel.text = _folders[selectedFolderId] as? String
        dropdownButton.accessibilityLabel = selectedFolderLabel.text
        closeDropdownFast()
        delegate?.folderDropdownSelectFolder?(selectedFolderId)
    }

    @objc func selectFolderWithId(_ folderId: NSNumber) {
        selectedFolderId = folderId
        selectedFolderLabel.text = _folders[selectedFolderId] as? String
        dropdownButton.accessibilityLabel = selectedFolderLabel.text
    }

    @objc func updateFolders() {
        let loader = SUSDropdownFolderLoader { [weak self] success, _, loader in
            guard let self, let theLoader = loader as? SUSDropdownFolderLoader else { return }
            if success {
                self.folders = (theLoader.updatedfolders as NSDictionary?) ?? NSDictionary()
                SUSRootFoldersDAO.setFolderDropdownFolders(self.folders as? [AnyHashable: Any] ?? [:])
            }
        }
        loader.startLoad()
        SUSRootFoldersDAO.setFolderDropdownFolders(_folders as? [AnyHashable: Any] ?? [:])
    }
}
