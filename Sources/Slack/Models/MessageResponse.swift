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

    /**
     Rebuilds a receipt from the two things Slack needs to address a message
     again.

     Public because a receipt has to outlive the process that earned it: a
     client that posts, quits, and reopens must still be able to edit or delete
     what it sent, and before this there was no way to reconstruct one.
     */
    public init(ts: String, in channel: Channel) {
        self.init(ts: ts, channel: channel, message: nil)
    }

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

//--------------------------------------
// MARK: - PERSISTENCE -
//--------------------------------------

/**
 Storing a receipt, so that quitting isn't the same as losing the ability to
 edit.

 This is **not** the wire path — Slack's own reply decodes as `ChatResponse`.
 This is for a client keeping its own record, and it deliberately persists only
 the receipt proper: `ts` and `channel`, the pair Slack needs to address the
 message again.

 ``MessageResponse/message`` is dropped. It is Slack's echo of what was posted,
 documented above as a convenience rather than proof, and ``ReceivedMessage`` is
 `Decodable` only by design — a message read back out of Slack should not be
 re-encodable into something postable. So a decoded receipt has no echo, and is
 not `==` to the one that came off the wire. What it *is* equal to is the same
 message: the identity round-trips exactly, which is the whole job.
 */
extension MessageResponse: Codable {

    private enum CodingKeys: String, CodingKey {
        case ts, channel
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            ts: try container.decode(String.self, forKey: .ts),
            in: try container.decode(Channel.self, forKey: .channel)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ts, forKey: .ts)
        try container.encode(channel, forKey: .channel)
    }
}
