//
//  Message+Desc.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 1/12/2025.
//

import Foundation

extension Message: CustomStringConvertible {

    public var description: String {
        var msg = "Message(\(text)"
        if let blocks { msg += ", \(blocks)" }
        if let metadata { msg += ", \(metadata)" }
        if let thread_ts { msg += ", thread: \(thread_ts)" }
        return msg + ")"
    }
}

extension ReceivedMessage: CustomStringConvertible {

    /**
     A debug summary.

     Subtype-specific fields are read optionally: Slack does not guarantee that
     a `channel_purpose` message carries a `purpose`, and a debug description is
     the last place that should be able to bring the app down.
     */
    public var description: String {
        if let subtype {
            switch subtype {
            case Subtype.channel_purpose.rawValue:
                return "Purpose set: \"\(purpose ?? text)\""
            case Subtype.channel_join.rawValue:
                return "\"\(text)\""
            case Subtype.tombstone.rawValue:
                return "🪦 \(text)"
            default:
                return "\(subtype) Message(\(text))"
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
