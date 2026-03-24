//
//  UIView+FrameHelper.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

extension UIView {

    @objc var x: CGFloat {
        get { frame.origin.x }
        set {
            guard newValue.isFinite else { return }
            var f = frame; f.origin.x = newValue; frame = f
        }
    }

    @objc var y: CGFloat {
        get { frame.origin.y }
        set {
            guard newValue.isFinite else { return }
            var f = frame; f.origin.y = newValue; frame = f
        }
    }

    @objc var origin: CGPoint {
        get { frame.origin }
        set {
            guard newValue.x.isFinite, newValue.y.isFinite else { return }
            var f = frame; f.origin = newValue; frame = f
        }
    }

    @objc var width: CGFloat {
        get { frame.size.width }
        set {
            guard newValue.isFinite else { return }
            var f = frame; f.size.width = newValue; frame = f
        }
    }

    @objc var height: CGFloat {
        get { frame.size.height }
        set {
            guard newValue.isFinite else { return }
            var f = frame; f.size.height = newValue; frame = f
        }
    }

    @objc var size: CGSize {
        get { frame.size }
        set {
            guard newValue.width.isFinite, newValue.height.isFinite else { return }
            var f = frame; f.size = newValue; frame = f
        }
    }
}
