//
//  PlaylistHeaderView.swift
//  iSub
//
//  Created by François ND on 2026.
//  Copyright © 2026 François ND. All rights reserved.
//

import UIKit
import SnapKit

@objc final class PlaylistHeaderView: UIView {

    @objc static let height: CGFloat = 260

    // MARK: - Public interface

    @objc var playlistName: String? {
        didSet { titleLabel.text = playlistName }
    }

    @objc var coverArtIds: [String] = [] {
        didSet { applyCoverArtIds() }
    }

    @objc var songCount: Int = 0 {
        didSet { songCountLabel.text = "\(songCount) \(songCount == 1 ? "song" : "songs")" }
    }

    @objc var onPlayAll: (() -> Void)?
    @objc var onShuffle: (() -> Void)?

    // MARK: - Private subviews

    private let artCollageView = UIView()
    private let artViews: [AsyncImageView] = (0..<4).map { _ in AsyncImageView() }
    private let gradientLayer = CAGradientLayer()
    private let titleLabel = UILabel()
    private let songCountLabel = UILabel()
    private let playAllButton = UIButton(type: .system)
    private let shuffleButton = UIButton(type: .system)
    private let buttonDivider = UIView()

    // MARK: - Init

    @objc override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @objc convenience init() {
        self.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    // MARK: - Setup

    private func setupView() {
        clipsToBounds = true

        // Art collage — 2x2 grid of AsyncImageViews
        artCollageView.clipsToBounds = true
        addSubview(artCollageView)
        artCollageView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(PlaylistHeaderView.height)
        }

        // Place 4 art views in 2x2 grid
        for (index, artView) in artViews.enumerated() {
            artView.contentMode = .scaleAspectFill
            artView.clipsToBounds = true
            artCollageView.addSubview(artView)
            let col = index % 2
            let row = index / 2
            artView.snp.makeConstraints { make in
                make.width.equalToSuperview().multipliedBy(0.5)
                make.height.equalToSuperview().multipliedBy(0.5)
                if col == 0 {
                    make.leading.equalToSuperview()
                } else {
                    make.trailing.equalToSuperview()
                }
                if row == 0 {
                    make.top.equalToSuperview()
                } else {
                    make.bottom.equalToSuperview()
                }
            }
        }

        // Gradient overlay
        let bgColor = UIColor(named: "isubBackgroundColor") ?? .systemBackground
        gradientLayer.colors = [
            UIColor.clear.cgColor,
            bgColor.withAlphaComponent(0.7).cgColor,
            bgColor.cgColor
        ]
        gradientLayer.locations = [0.0, 0.6, 1.0]
        layer.addSublayer(gradientLayer)

        // Title label
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        addSubview(titleLabel)

        // Song count label
        songCountLabel.font = .systemFont(ofSize: 14, weight: .regular)
        songCountLabel.textColor = .secondaryLabel
        addSubview(songCountLabel)

        // Button row
        let buttonRowHeight: CGFloat = 60
        let buttonRow = UIView()
        addSubview(buttonRow)
        buttonRow.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(buttonRowHeight)
        }

        // Play All button
        var playConfig = UIButton.Configuration.plain()
        playConfig.image = UIImage(systemName: "play.fill")
        playConfig.title = "Play All"
        playConfig.imagePadding = 6
        playConfig.imagePlacement = .leading
        playConfig.baseForegroundColor = .systemBlue
        playAllButton.configuration = playConfig
        playAllButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        playAllButton.addAction(UIAction { [weak self] _ in
            HapticEngine.shared.playbackAction()
            self?.onPlayAll?()
        }, for: .touchUpInside)
        buttonRow.addSubview(playAllButton)

        // Shuffle button
        var shuffleConfig = UIButton.Configuration.plain()
        shuffleConfig.image = UIImage(systemName: "shuffle")
        shuffleConfig.title = "Shuffle"
        shuffleConfig.imagePadding = 6
        shuffleConfig.imagePlacement = .leading
        shuffleConfig.baseForegroundColor = .systemBlue
        shuffleButton.configuration = shuffleConfig
        shuffleButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        shuffleButton.addAction(UIAction { [weak self] _ in
            HapticEngine.shared.modeToggle()
            self?.onShuffle?()
        }, for: .touchUpInside)
        buttonRow.addSubview(shuffleButton)

        // Divider between buttons
        buttonDivider.backgroundColor = .separator
        buttonRow.addSubview(buttonDivider)

        playAllButton.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.trailing.equalTo(buttonRow.snp.centerX)
        }
        shuffleButton.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview()
            make.leading.equalTo(buttonRow.snp.centerX)
        }
        buttonDivider.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(1.0 / UIScreen.main.scale)
            make.height.equalToSuperview().multipliedBy(0.5)
        }

        // Song count label above buttons
        songCountLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalTo(buttonRow.snp.top).offset(-4)
        }

        // Title label above song count
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalTo(songCountLabel.snp.top).offset(-2)
        }
    }

    // MARK: - Helpers

    private func applyCoverArtIds() {
        for (index, artView) in artViews.enumerated() {
            artView.coverArtId = index < coverArtIds.count ? coverArtIds[index] : nil
        }
    }
}
