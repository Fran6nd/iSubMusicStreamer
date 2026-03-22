//
//  MiniPlayerView.swift
//  iSub
//
//  Created by Francois ND on 3/22/26.
//  Copyright © 2026 Francois ND. All rights reserved.
//

import UIKit
import SnapKit

/// Persistent mini-player bar that lives above the tab bar.
/// Shows album art, song/artist labels, and play/pause + skip controls.
/// Tapping the bar opens the full PlayerViewController as a sheet.
@objc final class MiniPlayerView: UIView {

    // MARK: - Public

    /// Called when the user taps the body of the bar to open the full player.
    @objc var openPlayerHandler: (() -> Void)?

    // MARK: - Subviews

    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let separatorLine = UIView()
    private let coverArtView = AsyncImageView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let playPauseButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)

    // MARK: - Init

    @objc override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayout()
        registerNotifications()
        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Layout

    private func buildLayout() {
        // Translucent blur background
        addSubview(blurView)
        blurView.snp.makeConstraints { $0.edges.equalToSuperview() }

        // Top hairline separator
        separatorLine.backgroundColor = .separator
        addSubview(separatorLine)
        separatorLine.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }

        // Album art — square, pinned left with 8pt inset
        coverArtView.isLarge = false
        coverArtView.layer.cornerRadius = 4
        coverArtView.layer.masksToBounds = true
        coverArtView.backgroundColor = .systemFill
        blurView.contentView.addSubview(coverArtView)
        coverArtView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.top.equalToSuperview().offset(8)
            make.bottom.equalToSuperview().offset(-8)
            make.width.equalTo(coverArtView.snp.height)
        }

        // Labels stack
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.lineBreakMode = .byTruncatingTail
        blurView.contentView.addSubview(titleLabel)

        artistLabel.font = .systemFont(ofSize: 12, weight: .regular)
        artistLabel.textColor = .secondaryLabel
        artistLabel.lineBreakMode = .byTruncatingTail
        blurView.contentView.addSubview(artistLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverArtView.snp.trailing).offset(10)
            make.bottom.equalTo(coverArtView.snp.centerY).offset(-1)
            make.trailing.equalTo(nextButton.snp.leading).offset(-8)
        }
        artistLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(coverArtView.snp.centerY).offset(1)
            make.trailing.equalTo(titleLabel)
        }

        // Next track button
        var nextConfig = UIButton.Configuration.plain()
        nextConfig.image = UIImage(systemName: "forward.fill",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .medium))
        nextConfig.baseForegroundColor = .label
        nextButton.configuration = nextConfig
        nextButton.addAction(UIAction { [weak self] _ in
            HapticEngine.shared.playbackAction()
            Music.shared().playSong(atPosition: PlayQueue.shared().currentIndex + 1)
        }, for: .touchUpInside)
        blurView.contentView.addSubview(nextButton)
        nextButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }

        // Play/Pause button
        var playConfig = UIButton.Configuration.plain()
        playConfig.image = UIImage(systemName: "play.fill",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium))
        playConfig.baseForegroundColor = .label
        playPauseButton.configuration = playConfig
        playPauseButton.addAction(UIAction { [weak self] _ in
            HapticEngine.shared.playbackAction()
            self?.togglePlayPause()
        }, for: .touchUpInside)
        blurView.contentView.addSubview(playPauseButton)
        playPauseButton.snp.makeConstraints { make in
            make.trailing.equalTo(nextButton.snp.leading).offset(-4)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }

        // Tap gesture to open full player
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    // MARK: - Notifications

    private func registerNotifications() {
        let center = NotificationCenter.default
        let names: [NSNotification.Name] = [
            .init(ISMSNotification_SongPlaybackStarted),
            .init(ISMSNotification_SongPlaybackPaused),
            .init(ISMSNotification_SongPlaybackEnded),
            .init(ISMSNotification_CurrentPlaylistIndexChanged)
        ]
        for name in names {
            center.addObserver(self, selector: #selector(refresh), name: name, object: nil)
        }
    }

    // MARK: - State

    @objc func refresh() {
        let song = PlayQueue.shared().currentDisplaySong()
        let hasSong = (song != nil)

        isHidden = !hasSong
        guard let song = song else { return }

        coverArtView.coverArtId = song.coverArtId
        titleLabel.text = song.title ?? ""
        artistLabel.text = song.artist ?? ""

        let isPlaying = AudioEngine.shared().player?.isPlaying ?? false
        let iconName = isPlaying ? "pause.fill" : "play.fill"
        var cfg = playPauseButton.configuration ?? .plain()
        cfg.image = UIImage(systemName: iconName,
                             withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium))
        playPauseButton.configuration = cfg
    }

    private func togglePlayPause() {
        if let player = AudioEngine.shared().player {
            if player.isPlaying {
                player.pause()
            } else {
                player.playPause()
            }
        }
    }

    @objc private func handleTap() {
        openPlayerHandler?()
    }
}
