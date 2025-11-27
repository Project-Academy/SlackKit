//
//  Message.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 26/11/2025.
//

import Foundation

public struct Message: Codable {
    
    //--------------------------------------
    // MARK: - VARIABLES -
    //--------------------------------------
    public var text: String
    
    public var blocks: [Block]?
    public var thread_ts: String?
    public var mrkdwn: Bool?
    
    //--------------------------------------
    // MARK: - INITIALISERS -
    //--------------------------------------
    public init(_ text: String, blocks: [Block]? = nil, thread: String? = nil, mrkdwn: Bool? = nil) {
        self.text = text
        self.blocks = blocks
        self.thread_ts = thread
        self.mrkdwn = mrkdwn
    }
    
    //--------------------------------------
    // MARK: - JSON -
    //--------------------------------------
    public var json: [String: Sendable] {
        var dict: [String: Sendable] = ["text": text]
        if let blocks { dict["blocks"] = blocks.map(\.json) }
        if let thread_ts { dict["thread_ts"] = thread_ts }
        if let mrkdwn { dict["mrkdwn"] = mrkdwn }
        return dict
    }
}
