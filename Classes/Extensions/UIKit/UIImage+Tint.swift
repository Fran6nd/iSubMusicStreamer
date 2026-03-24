//
//  UIImage+Tint.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

extension UIImage {
    @objc(imageWithTint:) func withTint(_ tintColor: UIColor) -> UIImage {
        let rect = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Draw base image
            draw(in: rect)
            // Build alpha mask from the image and clip to it
            if let alphaMask = cgImage {
                ctx.cgContext.clip(to: rect, mask: alphaMask)
            }
            // Fill with tint color
            tintColor.setFill()
            UIRectFill(rect)
        }
    }
}
