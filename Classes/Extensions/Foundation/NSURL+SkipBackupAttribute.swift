//
//  NSURL+SkipBackupAttribute.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import CocoaLumberjackSwift
import Foundation

extension NSURL {
    private func setSkipBackupAttribute(_ skip: Bool) -> Bool {
        guard let path, FileManager.default.fileExists(atPath: path) else { return false }
        var url = self as URL
        var values = URLResourceValues()
        values.isExcludedFromBackup = skip
        do {
            try url.setResourceValues(values)
            return true
        } catch {
            DDLogError("Error excluding \(lastPathComponent ?? "") from backup: \(error)")
            return false
        }
    }

    @objc func addSkipBackupAttribute() -> Bool    { setSkipBackupAttribute(true) }
    @objc func removeSkipBackupAttribute() -> Bool { setSkipBackupAttribute(false) }
}
