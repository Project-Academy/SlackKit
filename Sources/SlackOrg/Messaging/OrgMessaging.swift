//
//  OrgMessaging.swift
//  SlackKit — SlackOrg
//
//  SlackOrg is the departure lounge: every capability in this module acts as the
//  ORGANISATION (a bot credential), not as the user, and is scheduled to move behind
//  trusted server-side endpoints. An `import SlackOrg` in an app is a declaration
//  that the file contains org-principal call sites — i.e. the migration checklist.
//
//  - Messaging/  — org-as-principal messaging. Survives the migration as an INTERFACE:
//    apps talk to `OrgMessaging`; today's implementation (`DirectSlackOrgClient`) calls
//    Slack directly, and will be replaced by an edge-function-backed client with the
//    same shape, leaving call sites untouched.
//  - Privileged/ — directory, history, and moderation. Does NOT survive as a client
//    capability in any form; it becomes server-internal. Everything in it is deprecated
//    to stop new call sites while it awaits deletion.
//
//  Migration day = ship the edge-backed OrgMessaging implementation, delete Privileged/
//  and DirectSlackOrgClient, and fix what the compiler flags.
//

import Foundation
import Slack

/**
 Org-as-principal messaging: post, DM, update, and delete as the organisation's bot.

 This protocol is the surface that SURVIVES the server-side migration: an
 edge-function-backed implementation will replace ``DirectSlackOrgClient`` without
 changing call sites. Every send returns a ``MessageResponse`` receipt so the caller
 can update or delete exactly what it sent — and nothing else.
 */
public protocol OrgMessaging: Sendable {

    /// Posts to a channel as the org bot.
    @discardableResult
    func post(_ message: Message, to channel: Channel) async throws -> MessageResponse

    /// DMs a user via their DM conversation with the bot — never via their user ID.
    /// (See the note on `Message.send(from:to:)` for why the user ID is a footgun.)
    @discardableResult
    func dm(_ message: Message, to user: Member) async throws -> MessageResponse

    /// Rewrites a previously-sent message, acting as the identity that posted it.
    @discardableResult
    func update(_ receipt: MessageResponse, to newMessage: Message) async throws -> MessageResponse

    /// Deletes a previously-sent message.
    func delete(_ receipt: MessageResponse) async throws
}

/**
 Today's ``OrgMessaging``: calls Slack directly with a bot credential held on-device.

 Scheduled for replacement by an edge-function-backed client once the server-side seam
 exists — at which point the bot token moves off-device entirely and this type is deleted.
 */
public struct DirectSlackOrgClient: OrgMessaging {

    /// The bot credential + persona this client acts as.
    public let bot: Author

    public init(bot: Author) { self.bot = bot }

    @discardableResult
    public func post(_ message: Message, to channel: Channel) async throws -> MessageResponse {
        try await message.send(from: bot, to: channel.id)
    }

    @discardableResult
    public func dm(_ message: Message, to user: Member) async throws -> MessageResponse {
        try await message.sendDM(to: user, from: bot)
    }

    @discardableResult
    public func update(_ receipt: MessageResponse, to newMessage: Message) async throws -> MessageResponse {
        try await receipt.update(to: newMessage, author: bot)
    }

    public func delete(_ receipt: MessageResponse) async throws {
        try await receipt.delete(as: bot)
    }
}
