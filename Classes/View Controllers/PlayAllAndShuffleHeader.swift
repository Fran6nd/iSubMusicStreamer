//
//  PlayAllAndShuffleHeader.swift
//  iSub
//
//  Created by Benjamin Baron on 11/13/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

@objc final class PlayAllAndShuffleHeader: UIView {
    private let playAllButton = UIButton(type: .system)
    private let shuffleButton = UIButton(type: .system)
    private let divider = UIView()

    @objc init(playAllHandler: @escaping () -> (), shuffleHandler: @escaping () -> ()) {
        super.init(frame: .zero)

        backgroundColor = UIColor(named: "isubBackgroundColor")
        snp.makeConstraints { make in
            make.height.equalTo(60)
        }

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
            playAllHandler()
        }, for: .touchUpInside)
        addSubview(playAllButton)

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
            shuffleHandler()
        }, for: .touchUpInside)
        addSubview(shuffleButton)

        divider.backgroundColor = .separator
        addSubview(divider)

        playAllButton.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.trailing.equalTo(snp.centerX)
        }
        shuffleButton.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview()
            make.leading.equalTo(snp.centerX)
        }
        divider.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(1.0 / UIScreen.main.scale)
            make.height.equalToSuperview().multipliedBy(0.5)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
}
