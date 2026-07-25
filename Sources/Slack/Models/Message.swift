//
//  Message.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 26/11/2025.
//
//  `Message` composes; `ReceivedMessage` is what Slack sends back. They used to
//  be one type, which forced the public initialiser to nil out a dozen
//  receive-only fields and made `Codable` unusable for sending (it would have
//  written `ts`, `bot_id`, `subtype` … into a `chat.postMessage` body). The
//  workaround was a hand-written `json` dictionary alongside the synthesised
//  `Codable` — two serialisers for one model, which drifted: `Block.json`
//  silently dropped `rich_text` and `actions` content that `Block.encode(to:)`
//  wrote correctly, so relaying a message posted an empty block.
//
//  Splitting the type removes the reason the second serialiser existed.
//

import Foundation

/**
 A message you are composing.

 Holds only what Slack accepts when posting, so it encodes directly to a
 `chat.postMessage` body with no field-stripping step in between.
 */
public struct Message: Encodable, Equatable, Sendable {

    //--------------------------------------
    // MARK: - VARIABLES -
    //--------------------------------------

    /// The message's fallback text. Shown in notifications and anywhere Block
    /// Kit can't render, so it should carry the message's meaning even when
    /// ``blocks`` does the real presentation.
    public var text: String

    /// Block Kit content. When present, this is what Slack renders.
    public var blocks: [Block]?

    /// The `ts` of the message this one replies to, making it a threaded reply.
    public var thread_ts: String?

    /// Whether Slack should parse markdown in ``text``.
    public var mrkdwn: Bool?

    /// Private, app-readable payload attached to the message. Only apps holding
    /// `metadata.message:read` can see it.
    public var metadata: Metadata?

    //--------------------------------------
    // MARK: - INITIALISERS -
    //--------------------------------------

    public init(
        _ text: String,
        blocks: [Block]? = nil,
        thread: String? = nil,
        mrkdwn: Bool? = nil,
        metadata: Metadata? = nil
    ) {
        self.text = text
        self.blocks = blocks
        self.thread_ts = thread
        self.mrkdwn = mrkdwn
        self.metadata = metadata
    }

    //--------------------------------------
    // MARK: - PLAIN TEXT -
    //--------------------------------------

    /// Flat-text rendering, per ``SlackTextual``.
    public var plainText: String { flattened }
}

extension Message {

    /**
     Private, app-readable payload attached to a message.

     `event_payload` holds arbitrary JSON, not just strings — Slack will return
     whatever the posting app put there, and `conversations.history` asks for
     `include_all_metadata`. Typing it as `[String: String]` meant one message
     with a nested or numeric payload failed to decode and took its whole page
     with it.
     */
    public struct Metadata: Codable, Equatable, Sendable {

        public var event_type: String
        public var event_payload: [String: JSONValue]

        public init(_ type: String, _ payload: [String: JSONValue]) {
            event_type = type
            event_payload = payload
        }

        /// Convenience for the common all-strings case.
        public init(_ type: String, _ payload: [String: String]) {
            self.init(type, payload.mapValues(JSONValue.string))
        }
    }
}

//--------------------------------------
// MARK: - RECEIVED -
//--------------------------------------

/**
 A message Slack sent us — from `conversations.history`, a `chat.postMessage`
 echo, and so on.

 Decode-only. Every field beyond `text` describes something that already
 happened (who posted it, when, whether it was edited), none of which is
 meaningful to send, so there is no path from here onto the wire. To repost
 received content, build a ``Message`` from it deliberately — see
 ``recomposed()``.
 */
public struct ReceivedMessage: Decodable, Equatable, Sendable {

    public let text: String
    public let blocks: [Block]?
    public let reactions: [Reaction]?

    public let thread_ts: String?
    public let metadata: Message.Metadata?

    public let app_id: String?
    public let bot_id: String?
    public let team: String?
    public let username: String?
    public let type: String?
    public let subtype: String?
    /// Present when `subtype == "channel_purpose"`.
    public let purpose: String?
    /// Present when `subtype == "channel_join"`.
    public let inviter: String?
    public let edited: [String: String]?
    public let ts: String?
    public let user: String?
    public let permalink: String?

    /// `text` is absent on some subtypes (and on block-only posts), which is
    /// not a decode failure — it's an empty fallback string.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text       = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        blocks     = try c.decodeIfPresent([Block].self, forKey: .blocks)
        reactions  = try c.decodeIfPresent([Reaction].self, forKey: .reactions)
        thread_ts  = try c.decodeIfPresent(String.self, forKey: .thread_ts)
        metadata   = try c.decodeIfPresent(Message.Metadata.self, forKey: .metadata)
        app_id     = try c.decodeIfPresent(String.self, forKey: .app_id)
        bot_id     = try c.decodeIfPresent(String.self, forKey: .bot_id)
        team       = try c.decodeIfPresent(String.self, forKey: .team)
        username   = try c.decodeIfPresent(String.self, forKey: .username)
        type       = try c.decodeIfPresent(String.self, forKey: .type)
        subtype    = try c.decodeIfPresent(String.self, forKey: .subtype)
        purpose    = try c.decodeIfPresent(String.self, forKey: .purpose)
        inviter    = try c.decodeIfPresent(String.self, forKey: .inviter)
        edited     = try c.decodeIfPresent([String: String].self, forKey: .edited)
        ts         = try c.decodeIfPresent(String.self, forKey: .ts)
        user       = try c.decodeIfPresent(String.self, forKey: .user)
        permalink  = try c.decodeIfPresent(String.self, forKey: .permalink)
    }

    private enum CodingKeys: String, CodingKey {
        case text, blocks, reactions, thread_ts, metadata
        case app_id, bot_id, team, username, type, subtype
        case purpose, inviter, edited, ts, user, permalink
    }

    //--------------------------------------
    // MARK: - HELPERS -
    //--------------------------------------

    /// Flat-text rendering, per ``SlackTextual``.
    public var plainText: String { flattened }

    /**
     A composable copy of this message's content — text, blocks, and metadata,
     with everything describing the original posting left behind.

     - Parameter inThread: When true, the copy replies into the received
       message's thread.
     */
    public func recomposed(inThread: Bool = false) -> Message {
        Message(
            text,
            blocks: blocks,
            thread: inThread ? (thread_ts ?? ts) : nil,
            metadata: metadata
        )
    }

    public struct Reaction: Decodable, Equatable, Sendable {
        public let name: String
        public let users: [String]
        public let count: Int
    }

    public enum Subtype: String, Sendable {
        case channel_purpose
        case channel_join
        case tombstone
    }
}

//--------------------------------------
// MARK: - FLAT TEXT -
//--------------------------------------

/**
 Anything that carries Slack message content and can be flattened to a string.

 Shared by ``Message`` and ``ReceivedMessage`` so the two can't render
 differently. Output uses CommonMark markers, so it's suitable for
 `Text(LocalizedStringKey(_:))`.
 */
public protocol SlackTextual {
    var text: String { get }
    var blocks: [Block]? { get }
}

extension Message: SlackTextual {}
extension ReceivedMessage: SlackTextual {}

extension SlackTextual {

    /// Prefers `text` (Slack's fallback string, almost always populated); falls
    /// back to walking `blocks` when it's empty or whitespace.
    package var flattened: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return blocks?
            .map(\.plainText)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            ?? ""
    }
}
