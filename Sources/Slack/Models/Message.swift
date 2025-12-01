//
//  Message.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 26/11/2025.
//

import Foundation

public struct Message: Codable, Equatable {
    
    //--------------------------------------
    // MARK: - VARIABLES -
    //--------------------------------------
    public var text: String
    public var blocks: [Block]?
    public var reactions: [Reaction]?
    
    public var thread_ts: String?
    public var mrkdwn: Bool?
    
    public var metadata: Metadata?
    
    public let app_id: String?
    public let bot_id: String?
    public let team: String?
    public let username: String?
    public let type: String?
    public let subtype: String?
    public let purpose: String? // Exists when `subtype` == "channel_purpose"
    public let inviter: String? // Exists when `subtype` == "channel_join"
    public let edited: [String: String]?
    public let ts: String?
    public let user: String?
    public let permalink: String?
    
    //--------------------------------------
    // MARK: - INITIALISERS -
    //--------------------------------------
    public init(_ text: String, blocks: [Block]? = nil, thread: String? = nil, mrkdwn: Bool? = nil) {
        self.text = text
        self.blocks = blocks
        self.thread_ts = thread
        self.mrkdwn = mrkdwn
        
        self.app_id = nil
        self.bot_id = nil
        self.team = nil
        self.username = nil
        self.type = nil
        self.subtype = nil
        self.purpose = nil
        self.inviter = nil
        self.edited = nil
        self.ts = nil
        self.user = nil
        self.permalink = nil
    }
    internal init(text: String, blocks: [Block]? = nil, thread_ts: String? = nil, mrkdwn: Bool? = nil, metadata: Message.Metadata? = nil, app_id: String? = nil, bot_id: String? = nil, team: String? = nil, username: String? = nil, type: String? = nil, subtype: String? = nil, purpose: String? = nil, inviter: String? = nil, edited: [String : String]? = nil, ts: String? = nil, user: String? = nil, permalink: String? = nil) {
        self.text = text
        self.blocks = blocks
        self.thread_ts = thread_ts
        self.mrkdwn = mrkdwn
        self.metadata = metadata
        self.app_id = app_id
        self.bot_id = bot_id
        self.team = team
        self.username = username
        self.type = type
        self.subtype = subtype
        self.purpose = purpose
        self.inviter = inviter
        self.edited = edited
        self.ts = ts
        self.user = user
        self.permalink = permalink
    }
    
    //--------------------------------------
    // MARK: - JSON -
    //--------------------------------------
    public var json: [String: Sendable] {
        var dict: [String: Sendable] = ["text": text]
        if let blocks { dict["blocks"] = blocks.map(\.json) }
        if let thread_ts { dict["thread_ts"] = thread_ts }
        if let mrkdwn { dict["mrkdwn"] = mrkdwn }
        if let metadata { dict["metadata"] = metadata.json }
        return dict
    }
}

extension Message {
    
    public struct Metadata: Codable, Equatable {
        public var event_type: String
        public var event_payload: [String: String]
        
        public init(_ type: String, _ payload: [String: String]) {
            event_type = type
            event_payload = payload
        }
        
        public var json: [String: Sendable] {
            [
                "event_type": event_type,
                "event_payload": event_payload
            ]
        }
    }
    
    public enum Subtype: String, Codable {
        case channel_purpose
        case channel_join
        case tombstone
    }
    
    public struct Reaction: Codable, Equatable {
        public let name: String
        public let users: [String]
        public let count: Int
    }
    
}
