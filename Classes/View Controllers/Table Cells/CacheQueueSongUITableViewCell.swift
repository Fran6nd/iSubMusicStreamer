//
//  CacheQueueSongUITableViewCell.swift
//  iSub
//
//  Created by François ND on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(CacheQueueSongUITableViewCell) final class CacheQueueSongUITableViewCell: UITableViewCell {

    @objc let coverArtView = AsyncImageView()
    @objc let cacheInfoLabel = UILabel()
    @objc let nameScrollView = UIScrollView()
    @objc let songNameLabel = UILabel()
    @objc let artistNameLabel = UILabel()
    @objc var md5: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        coverArtView.isLarge = false
        contentView.addSubview(coverArtView)

        cacheInfoLabel.frame = CGRect(x: 0, y: 0, width: 320, height: 20)
        cacheInfoLabel.autoresizingMask = .flexibleWidth
        cacheInfoLabel.textAlignment = .center
        cacheInfoLabel.backgroundColor = .black
        cacheInfoLabel.alpha = 0.65
        cacheInfoLabel.font = .boldSystemFont(ofSize: 10)
        cacheInfoLabel.textColor = .label
        contentView.addSubview(cacheInfoLabel)

        nameScrollView.frame = CGRect(x: 65, y: 20, width: 245, height: 55)
        nameScrollView.autoresizingMask = .flexibleWidth
        nameScrollView.backgroundColor = .clear
        nameScrollView.showsVerticalScrollIndicator = false
        nameScrollView.showsHorizontalScrollIndicator = false
        nameScrollView.isUserInteractionEnabled = false
        nameScrollView.decelerationRate = .fast
        contentView.addSubview(nameScrollView)

        songNameLabel.backgroundColor = .clear
        songNameLabel.textAlignment = .left
        songNameLabel.font = .systemFont(ofSize: 16)
        songNameLabel.textColor = .label
        nameScrollView.addSubview(songNameLabel)

        artistNameLabel.backgroundColor = .clear
        artistNameLabel.textAlignment = .left
        artistNameLabel.font = .systemFont(ofSize: 15)
        artistNameLabel.textColor = .label
        nameScrollView.addSubview(artistNameLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        coverArtView.frame = CGRect(x: 0, y: 20, width: 60, height: 60)

        songNameLabel.frame = CGRect(x: 0, y: 0, width: 245, height: 35)
        let songSize = (songNameLabel.text ?? "").boundingRect(
            with: CGSize(width: 1000, height: 35),
            options: .usesLineFragmentOrigin,
            attributes: [.font: songNameLabel.font as Any],
            context: nil
        ).size
        songNameLabel.frame.size.width = songSize.width

        artistNameLabel.frame = CGRect(x: 0, y: 35, width: 245, height: 20)
        let artistSize = (artistNameLabel.text ?? "").boundingRect(
            with: CGSize(width: 1000, height: 20),
            options: .usesLineFragmentOrigin,
            attributes: [.font: artistNameLabel.font as Any],
            context: nil
        ).size
        artistNameLabel.frame.size.width = artistSize.width
    }

    @objc func scrollLabels() {
        let scrollWidth = max(songNameLabel.frame.size.width, artistNameLabel.frame.size.width)
        guard scrollWidth > nameScrollView.frame.size.width else { return }
        let target = scrollWidth - nameScrollView.frame.size.width + 10
        let duration = scrollWidth / 150
        UIView.animate(withDuration: duration) {
            self.nameScrollView.contentOffset = CGPoint(x: target, y: 0)
        } completion: { _ in
            UIView.animate(withDuration: duration) {
                self.nameScrollView.contentOffset = .zero
            }
        }
    }
}
