//
//  ChatUITableViewCell.swift
//  iSub
//
//  Created by François ND on 2026-03-26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(ChatUITableViewCell) final class ChatUITableViewCell: UITableViewCell {

    @objc let userNameLabel = UILabel()
    @objc let messageLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = UIColor(named: "isubBackgroundColor")

        userNameLabel.frame = CGRect(x: 0, y: 0, width: 320, height: 20)
        userNameLabel.autoresizingMask = .flexibleWidth
        userNameLabel.textAlignment = .center
        userNameLabel.backgroundColor = .systemGray
        userNameLabel.font = .boldSystemFont(ofSize: 10)
        userNameLabel.textColor = .white
        contentView.addSubview(userNameLabel)

        messageLabel.frame = CGRect(x: 5, y: 20, width: 310, height: 55)
        messageLabel.autoresizingMask = .flexibleWidth
        messageLabel.textAlignment = .left
        messageLabel.textColor = .label
        messageLabel.font = .systemFont(ofSize: 20)
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.numberOfLines = 0
        contentView.addSubview(messageLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let expectedSize = (messageLabel.text ?? "").boundingRect(
            with: CGSize(width: 310, height: CGFloat.greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: [.font: messageLabel.font as Any],
            context: nil
        ).size

        var frame = messageLabel.frame
        frame.size.height = max(expectedSize.height, 40)
        messageLabel.frame = frame
    }
}
