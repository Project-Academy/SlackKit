//
//  DMs.swift
//  SlackKit — SlackOrg
//
//  Created by Sarfraz Basha on 1/12/2025.
//

import Foundation
import Slack

@MainActor
extension Message {

    /**
     Sends this message to `user`'s DM conversation with the bot — the safe way to DM a user.

     Resolves the user's DM channel (`D…`) via ``Slack/Member/getDM(createIfNeeded:as:)`` — opened
     as the same `sender` that posts, since DM conversations are per bot token — and posts there,
     so the message comes **from the bot**: it's editable after the fact, and its delivery can be
     verified by reading the DM's chat history. See the note on `Message.send(from:to:)` for why
     posting to a user's ID directly forfeits both.

     - note: This costs one extra API call (`conversations.open`) per send. When sending many
       messages to the same user, resolve the DM once with `getDM` and pass its `id` to
       `send(from:to:)`.
     */
    @discardableResult
    public func sendDM(to user: Member, from sender: Author? = nil) async throws -> MessageResponse {
        let dm = try await user.getDM(as: sender)
        return try await send(from: sender, to: dm.id)
    }
}

@MainActor
extension Member {

    /**
     Resolves the user's DM/IM conversation (`D…`) with the bot, via `conversations.open`.

     - Parameters:
       - createIfNeeded: When `true` (the default), Slack creates the DM conversation if one
                         doesn't exist yet; when `false`, a missing conversation throws instead.
       - author: The ``Slack/Author`` whose token opens the conversation. When `nil`,
                 ``Slack/Slack/defaultAuthor`` is used. DM conversations are **per bot token** —
                 open the DM as the same author that will post to it.
     */
    public func getDM(createIfNeeded: Bool = true, as author: Author? = nil) async throws -> Channel {
        try await Member.getDM(withUser: id, createIfNeeded: createIfNeeded, as: author)
    }

    public static func getDM(withUser id: String, createIfNeeded: Bool = true, as author: Author? = nil) async throws -> Channel {

        let response: OpenResponse = try await Conversations.open.write {
            $0.from(author ?? Slack.defaultAuthor)
              .body(OpenConversationPayload(
                  users: id,
                  return_im: true,
                  prevent_creation: !createIfNeeded
              ))
        }

        guard let channel = response.channel else {
            throw SlackError.unreadable(
                method: Conversations.open.method,
                detail: "ok:true with no `channel`"
            )
        }
        return channel
    }

    private struct OpenResponse: Decodable, Sendable {
        let channel: Channel?
        let warning: String?
    }
}
