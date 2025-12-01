//
//  Message+Desc.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 1/12/2025.
//

import Foundation

extension Message: CustomStringConvertible {
    public var description: String {
        guard subtype == nil
        else {
            switch subtype! {
            case Subtype.channel_purpose.rawValue: return "Purpose set: \"\(purpose!)\""
            case Subtype.channel_join.rawValue: return "\"\(text)\""
            case Subtype.tombstone.rawValue: return "🪦 \(text)"
            default: return "\(subtype!) Message(\(text))"
            }
        }
        var msg = "Message(\(text)"
        if let blocks { msg += ", \(blocks)" }
        if let metadata { msg += ", \(metadata)" }
        if let user { msg += ", User: \(user)" }
        if let ts { msg += ", ts: \(ts)" }
        else if let thread_ts { msg += ", Timestamp: \(thread_ts)" }
        return msg + ")"
    }
}
