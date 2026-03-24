//
//  CustomUITextView.swift
//  iSub
//
//  Created by François Navarro on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

@objc(CustomUITextView) class CustomUITextView: UITextView {
    override func draw(_ rect: CGRect) {
        UIGraphicsBeginImageContext(frame.size)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext(),
              let backgroundImage = UIGraphicsGetImageFromCurrentImageContext() else { return }

        context.setLineWidth(3.0)
        context.setStrokeColor(UIColor.black.cgColor)
        context.stroke(context.boundingBoxOfClipPath)

        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height))
        imageView.image = backgroundImage
        addSubview(imageView)
    }
}
