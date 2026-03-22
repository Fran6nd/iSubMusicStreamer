//
//  PlaylistGridCell.swift
//  iSub
//
//  Created by François ND
//  Copyright © 2026 François ND. All rights reserved.
//

import UIKit

@objc final class PlaylistGridCell: UICollectionViewCell {
    @objc static let reuseId = "PlaylistGridCell"

    // MARK: - Subviews

    private let artGrid = UIView()
    private let artViews: [AsyncImageView] = (0..<4).map { _ in AsyncImageView() }
    private let songCountBadge = UILabel()
    private let nameLabel = UILabel()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }

    // MARK: - Setup

    private func setup() {
        contentView.backgroundColor = .clear

        // Art grid container
        artGrid.translatesAutoresizingMaskIntoConstraints = false
        artGrid.clipsToBounds = true
        artGrid.layer.cornerRadius = 8
        contentView.addSubview(artGrid)

        // Four art quadrants
        for (i, view) in artViews.enumerated() {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.contentMode = .scaleAspectFill
            view.clipsToBounds = true
            view.backgroundColor = UIColor.systemGray5
            artGrid.addSubview(view)
        }

        // Song count badge (bottom-right corner of art grid)
        songCountBadge.translatesAutoresizingMaskIntoConstraints = false
        songCountBadge.font = .systemFont(ofSize: 11, weight: .semibold)
        songCountBadge.textColor = .white
        songCountBadge.textAlignment = .center
        songCountBadge.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        songCountBadge.layer.cornerRadius = 8
        songCountBadge.layer.masksToBounds = true
        songCountBadge.isHidden = true
        contentView.addSubview(songCountBadge)

        // Name label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = .byTruncatingTail
        contentView.addSubview(nameLabel)

        activateConstraints()
    }

    private func activateConstraints() {
        // Art grid fills the top portion; name label is below
        NSLayoutConstraint.activate([
            artGrid.topAnchor.constraint(equalTo: contentView.topAnchor),
            artGrid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            artGrid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            artGrid.heightAnchor.constraint(equalTo: contentView.widthAnchor), // square

            nameLabel.topAnchor.constraint(equalTo: artGrid.bottomAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
        ])

        // 2x2 quadrants inside artGrid
        let top = artViews[0]
        let topRight = artViews[1]
        let bottomLeft = artViews[2]
        let bottomRight = artViews[3]

        let mid = artGrid.centerXAnchor
        let midY = artGrid.centerYAnchor

        NSLayoutConstraint.activate([
            // Top-left
            top.topAnchor.constraint(equalTo: artGrid.topAnchor),
            top.leadingAnchor.constraint(equalTo: artGrid.leadingAnchor),
            top.trailingAnchor.constraint(equalTo: mid, constant: -0.5),
            top.bottomAnchor.constraint(equalTo: midY, constant: -0.5),

            // Top-right
            topRight.topAnchor.constraint(equalTo: artGrid.topAnchor),
            topRight.leadingAnchor.constraint(equalTo: mid, constant: 0.5),
            topRight.trailingAnchor.constraint(equalTo: artGrid.trailingAnchor),
            topRight.bottomAnchor.constraint(equalTo: midY, constant: -0.5),

            // Bottom-left
            bottomLeft.topAnchor.constraint(equalTo: midY, constant: 0.5),
            bottomLeft.leadingAnchor.constraint(equalTo: artGrid.leadingAnchor),
            bottomLeft.trailingAnchor.constraint(equalTo: mid, constant: -0.5),
            bottomLeft.bottomAnchor.constraint(equalTo: artGrid.bottomAnchor),

            // Bottom-right
            bottomRight.topAnchor.constraint(equalTo: midY, constant: 0.5),
            bottomRight.leadingAnchor.constraint(equalTo: mid, constant: 0.5),
            bottomRight.trailingAnchor.constraint(equalTo: artGrid.trailingAnchor),
            bottomRight.bottomAnchor.constraint(equalTo: artGrid.bottomAnchor),
        ])

        // Badge: anchored to bottom-right of art grid
        NSLayoutConstraint.activate([
            songCountBadge.bottomAnchor.constraint(equalTo: artGrid.bottomAnchor, constant: -6),
            songCountBadge.trailingAnchor.constraint(equalTo: artGrid.trailingAnchor, constant: -6),
            songCountBadge.heightAnchor.constraint(equalToConstant: 18),
            songCountBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 30),
        ])
    }

    // MARK: - Configuration

    /// Configure with a playlist name. Cover art IDs are optional; pass up to 4.
    @objc func configure(name: String, coverArtIds: [String], songCount: Int) {
        nameLabel.text = name

        for (i, view) in artViews.enumerated() {
            if i < coverArtIds.count {
                view.coverArtId = coverArtIds[i]
            } else {
                view.coverArtId = nil
            }
        }

        if songCount > 0 {
            songCountBadge.text = "\(songCount)"
            songCountBadge.isHidden = false
        } else {
            songCountBadge.isHidden = true
        }
    }

    /// Convenience: configure with only a name (no cover art, no count).
    @objc func configureName(_ name: String) {
        configure(name: name, coverArtIds: [], songCount: 0)
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        songCountBadge.isHidden = true
        songCountBadge.text = nil
        for view in artViews {
            view.coverArtId = nil
        }
    }
}
