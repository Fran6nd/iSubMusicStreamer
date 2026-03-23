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
/// Tapping the bar opens the full PlayerViewController.
@objc final class MiniPlayerView: UIView {

    // MARK: - Public

    /// Called when the user taps the bar body to open the full player.
    @objc var openPlayerHandler: (() -> Void)?

    /// Called whenever the mini player transitions between visible (true) and hidden (false).
    /// Fired on the main thread immediately after `isHidden` is updated.
    var visibilityChanged: ((Bool) -> Void)?

    // MARK: - Subviews

    private let blurView    = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let separator   = UIView()
    private let artView     = AsyncImageView()
    private let titleLabel  = UILabel()
    private let artistLabel = UILabel()
    private let playButton  = UIButton(type: .system)
    private let nextButton  = UIButton(type: .system)

    // MARK: - Init

    @objc override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        addSubviews()
        configureSubviews()
        makeConstraints()
        registerNotifications()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("unimplemented") }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Layout phases

    private func addSubviews() {
        addSubview(blurView)
        addSubview(separator)
        let cv = blurView.contentView
        cv.addSubview(artView)
        cv.addSubview(nextButton)
        cv.addSubview(playButton)
        cv.addSubview(titleLabel)
        cv.addSubview(artistLabel)
    }

    private func configureSubviews() {
        separator.backgroundColor = .separator

        artView.isLarge = false
        artView.layer.cornerRadius = 4
        artView.layer.masksToBounds = true
        artView.backgroundColor = .systemFill

        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.lineBreakMode = .byTruncatingTail

        artistLabel.font = .systemFont(ofSize: 12)
        artistLabel.textColor = .secondaryLabel
        artistLabel.lineBreakMode = .byTruncatingTail

        var nextCfg = UIButton.Configuration.plain()
        nextCfg.image = UIImage(systemName: "forward.fill",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .medium))
        nextCfg.baseForegroundColor = .label
        nextButton.configuration = nextCfg
        nextButton.addAction(UIAction { _ in
            HapticEngine.shared.playbackAction()
            Music.shared().playSong(atPosition: PlayQueue.shared().currentIndex + 1)
        }, for: .touchUpInside)

        var playCfg = UIButton.Configuration.plain()
        playCfg.image = UIImage(systemName: "play.fill",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium))
        playCfg.baseForegroundColor = .label
        playButton.configuration = playCfg
        playButton.addAction(UIAction { [weak self] _ in
            HapticEngine.shared.playbackAction()
            self?.togglePlayPause()
        }, for: .touchUpInside)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    private func makeConstraints() {
        blurView.snp.makeConstraints { $0.edges.equalToSuperview() }

        separator.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }

        artView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.top.equalToSuperview().offset(8)
            make.bottom.equalToSuperview().offset(-8)
            make.width.equalTo(artView.snp.height)
        }

        nextButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }

        playButton.snp.makeConstraints { make in
            make.trailing.equalTo(nextButton.snp.leading).offset(-4)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(artView.snp.trailing).offset(10)
            make.trailing.equalTo(playButton.snp.leading).offset(-8)
            make.bottom.equalTo(artView.snp.centerY).offset(-1)
        }

        artistLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.top.equalTo(artView.snp.centerY).offset(1)
        }
    }

    // MARK: - Notifications

    private func registerNotifications() {
        let names: [NSNotification.Name] = [
            .init(ISMSNotification_SongPlaybackStarted),
            .init(ISMSNotification_SongPlaybackPaused),
            .init(ISMSNotification_SongPlaybackEnded),
            .init(ISMSNotification_CurrentPlaylistIndexChanged)
        ]
        for name in names {
            NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: name, object: nil)
        }
    }

    // MARK: - State

    @objc func refresh() {
        let song = PlayQueue.shared().currentDisplaySong()
        let nowVisible = (song != nil)
        let wasVisible = !isHidden
        if wasVisible != nowVisible {
            // Notify the owner (CustomUITabBarController) so it can drive the
            // animated isHidden + insets transition. If no owner is wired yet
            // (e.g. during init), manage isHidden directly so the initial state
            // is correct before the first layout pass.
            if let visibilityChanged {
                visibilityChanged(nowVisible)
            } else {
                isHidden = !nowVisible
            }
        }
        guard let song = song else { return }

        artView.coverArtId = song.coverArtId
        titleLabel.text = song.title ?? ""
        artistLabel.text = song.artist ?? ""

        let isPlaying = AudioEngine.shared().player?.isPlaying ?? false
        var cfg = playButton.configuration ?? .plain()
        cfg.image = UIImage(
            systemName: isPlaying ? "pause.fill" : "play.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium))
        playButton.configuration = cfg
    }

    // MARK: - Actions

    private func togglePlayPause() {
        guard let player = AudioEngine.shared().player else { return }
        player.isPlaying ? player.pause() : player.playPause()
    }

    @objc private func handleTap() { openPlayerHandler?() }
}
