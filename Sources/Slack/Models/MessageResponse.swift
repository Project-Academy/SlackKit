//
//  MessageResponse.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 26/11/2025.
//

import Foundation

/**
 A delivery receipt for a sent message: where it landed (`channel`) and its
 timestamp identity (`ts`), which together are what Slack needs to update,
 delete, or react to the message later.
 */
public struct MessageResponse: Decodable, Sendable {
    public let ts: String
    public let channel: Channel
    public let message: Message

    package init?(_ resp: ChatResponse, message: Message? = nil) {

        ts = resp.ts
        channel = Channel(resp.channel)
        guard message == nil
        else { self.message = message!; return }

        let text = resp.text ?? resp.message?.text
        guard let text else { return nil }

        var message_ = Message(text)
        guard let msg = resp.message else { return nil }
        if let blocks = msg.blocks {
            message_.blocks = blocks
        }
        self.message = message_
    }

    package init?(_ msg: Message, channel: Channel) {
        guard let ts = msg.ts else { return nil }
        self.ts = ts
        self.channel = channel
        self.message = msg
    }
}
