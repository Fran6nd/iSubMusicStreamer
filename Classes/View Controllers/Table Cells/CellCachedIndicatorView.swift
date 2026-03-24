//
//  CellCachedIndicatorView.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

final class CellCachedIndicatorView: UIView {

    private let indicatorSize: CGFloat

    // TODO: Flip for RTL
    @objc init(size: CGFloat = 20) {
        self.indicatorSize = size
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))

        let maskPath = UIBezierPath()
        maskPath.move(to: CGPoint(x: 0, y: 0))
        maskPath.addLine(to: CGPoint(x: size, y: 0))
        maskPath.addLine(to: CGPoint(x: 0, y: size))
        maskPath.close()

        let triangleMaskLayer = CAShapeLayer()
        triangleMaskLayer.path = maskPath.cgPath

        backgroundColor = ViewObjects.shared().currentDarkColor()
        layer.mask = triangleMaskLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: indicatorSize, height: indicatorSize)
    }
}
