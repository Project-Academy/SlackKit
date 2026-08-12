//
//  Channel.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 27/11/2025.
//

import Foundation

public struct Channel: Codable, Equatable, Sendable {
    
    //--------------------------------------
    // MARK: - VARIABLES -
    //--------------------------------------
    public let id: String
    
    public var created: Int?
    public var creator: String?
    
    public var name: String?
    public var name_normalized: String?
    public var num_members: Int?
    public var purpose: Purpose?
    public var topic: Purpose?
    
    public var is_archived: Bool?
    public var is_channel: Bool?
    public var is_private: Bool?
    public var is_mpim: Bool?
    public var is_im: Bool?
    public var is_member: Bool?

    /**
     The other party, on a DM.

     Slack sends no `name` for an `im`, so this is the only thing identifying
     who the conversation is with — without it a DM can be listed but not
     labelled.
     */
    public var user: String?

    //--------------------------------------
    // MARK: - INITIALISERS -
    //--------------------------------------
    public init(_ id: String) { self.id = id }

    //--------------------------------------
    // MARK: - HELPERS -
    //--------------------------------------

    /**
     What kind of conversation this is.

     Ordered most specific first: an mpim and a DM are both also flagged
     private, so testing `is_private` before them would classify every DM as a
     private channel.
     */
    public var kind: Kind {
        if let is_mpim, is_mpim { return .mpim }
        if let is_im, is_im { return .im }
        if let is_private, is_private { return .privateChannel }
        return .publicChannel
    }
}
extension Channel: CustomStringConvertible {
    public var description: String {
        var channel = ""
        if let is_archived, is_archived { channel += "Archived " }

        if name == nil, kind == .im {
            return "DM(ID: \(id))"
        }

        channel += "Channel("
        if let name { channel += "\(kind.glyph)\(name), " }
        channel += "ID: \(id)"
        if let num_members { channel += ", members: \(num_members)" }
        if let purpose = purpose?.value, purpose != "" { channel += ", purpose: \(purpose)" }
        if let topic = topic?.value, topic != "" { channel += ", topic: \(topic)" }
        return channel + ")"
    }
}
extension Channel {

    public struct Purpose: Codable, Equatable, Sendable {
        public var creator: String?
        public var last_set: Int?
        public var value: String?
    }

    /**
     Slack's conversation taxonomy, spelled the way the `types` parameter
     expects it.

     The raw values are the wire strings rather than anything decorative, so a
     set of these can be handed straight to `users.conversations` /
     `conversations.list` without a translation table in between. Display
     characters live on ``glyph``.
     */
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case publicChannel  = "public_channel"
        case privateChannel = "private_channel"
        case mpim
        case im

        /// How this kind is prefixed when a conversation is described.
        public var glyph: String {
            switch self {
            case .publicChannel:  "#"
            case .privateChannel: "🔒"
            case .mpim:           "᠅"
            case .im:             "💬"
            }
        }
    }
}

extension Set where Element == Channel.Kind {

    /**
     Slack's `types` parameter for this set.

     Comma-separated with **no spaces** — Slack does not trim these, and a
     stray space makes the whole entry unmatchable. Emitted in
     ``Channel/Kind/allCases`` order so the string is stable regardless of how
     the set was built.
     */
    package var typesParameter: String {
        Channel.Kind.allCases
            .filter(contains)
            .map(\.rawValue)
            .joined(separator: ",")
    }
}
