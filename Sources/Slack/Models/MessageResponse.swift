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

 Construction is **not** failable. It used to be, returning `nil` when Slack's
 echo lacked a `message` object — which turned a post that had actually
 succeeded into a thrown error, and invited the caller to retry a message Slack
 already delivered. The receipt is `ts` + `channel`; those are what Slack
 guarantees, and `ok` has already been checked by the time we get here. The echo
 is a bonus.
 */
public struct MessageResponse: Sendable, Equatable {

    /// The message's timestamp identity, unique within its channel.
    public let ts: String

    /// Where the message landed.
    public let channel: Channel

    /// Slack's echo of the message as posted. Absent when the method doesn't
    /// return one (`chat.delete`), so treat it as a convenience, not proof.
    public let message: ReceivedMessage?

    package init(ts: String, channel: Channel, message: ReceivedMessage? = nil) {
        self.ts = ts
        self.channel = channel
        self.message = message
    }

    package init(_ resp: ChatResponse) {
        self.init(
            ts: resp.ts,
            channel: Channel(resp.channel),
            message: resp.message
        )
    }

    /// Builds a receipt for a message read back out of a channel (history,
    /// replies), which carries its own `ts`.
    package init?(_ msg: ReceivedMessage, channel: Channel) {
        guard let ts = msg.ts else { return nil }
        self.init(ts: ts, channel: channel, message: msg)
    }
}
