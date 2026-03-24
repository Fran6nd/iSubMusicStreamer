//
//  NSString+Time.swift
//  iSub
//
//  Created by François ND on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

extension NSString {
    @objc(formatTime:) static func formatTime(_ seconds: Double) -> String {
        guard seconds > 0 else { return "0:00" }
        let total = Int(floor(seconds))
        let mins  = total / 60
        let secs  = total % 60
        return String(format: secs < 10 ? "%d:0%d" : "%d:%d", mins, secs)
    }

    @objc(formatTimeHoursMinutes:hideHoursIfZero:)
    static func formatTimeHoursMinutes(_ seconds: Double, hideHoursIfZero: Bool) -> String {
        guard seconds > 0 else { return hideHoursIfZero ? "00m" : "0h00m" }
        let total = Int(floor(seconds))
        let hours = total / 3600
        let mins  = (total % 3600) / 60
        if hideHoursIfZero && hours == 0 {
            return String(format: mins < 10 ? "0%dm" : "%dm", mins)
        } else {
            return String(format: mins < 10 ? "%dh0%dm" : "%dh%dm", hours, mins)
        }
    }

    @objc(formatTimeDecimalHours:) static func formatTimeDecimalHours(_ seconds: Double) -> String {
        guard seconds > 0 else { return "0:00" }
        if seconds < 3600 {
            return formatTime(seconds)
        } else {
            let hours = seconds / 3600
            return String(format: "%.1f %@", hours, NSLocalizedString("hrs", comment: "EX2Kit format time, hours string"))
        }
    }

    @objc(relativeTime:) static func relativeTime(_ date: Date) -> String {
        guard date != Date(timeIntervalSince1970: 0) else { return "never" }
        let elapsed = Date().timeIntervalSince(date)
        switch elapsed {
        case ...60:                        return "just now"
        case 60...3600:
            let m = Int(elapsed / 60)
            return m == 1 ? "1 minute ago"  : "\(m) minutes ago"
        case 3600...86400:
            let h = Int(elapsed / 3600)
            return h == 1 ? "1 hour ago"    : "\(h) hours ago"
        case 86400...604800:
            let d = Int(elapsed / 86400)
            return d == 1 ? "1 day ago"     : "\(d) days ago"
        case 604800...2_629_744:
            let w = Int(elapsed / 604800)
            return w == 1 ? "1 week ago"    : "\(w) weeks ago"
        default:
            let mo = Int(elapsed / 2_629_744)
            return mo == 1 ? "1 month ago"  : "\(mo) months ago"
        }
    }
}
