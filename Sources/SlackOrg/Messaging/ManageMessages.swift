//
//  ManageMessages.swift
//  SlackKit — SlackOrg
//
//  Created by Sarfraz Basha on 26/11/2025.
//
//  Editing/deleting arbitrary messages by (ts, channel) — org-side message
//  management, as opposed to `MessageResponse.update/delete` in the client kit,
//  which only operates on receipts the caller itself holds.
//

import Foundation
import Slack

@MainActor
extension Message {

    /**
     Updates the message at `ts` in `channel`.

     - important: `chat.update` only succeeds as the identity that posted the message —
       pass the same `author` the message was originally sent `from` (or leave `nil`
       only when it was posted by ``Slack/Slack/defaultAuthor``).
     */
    @discardableResult
    public static func update(
        messageAt ts: String,
        in channel: Channel,
        with newMessage: Message,
        as author: Author? = nil
    ) async throws -> MessageResponse {

        let response: ChatResponse = try await Chat.update.write {
            $0.from(author ?? Slack.defaultAuthor)
              .body(UpdateMessagePayload(newMessage, at: ts, in: channel.id))
        }
        return MessageResponse(response)
    }

    /// Deletes the message at `ts` in `channel`.
    public static func delete(messageAt ts: String, in channel: Channel, authority: Author? = nil) async throws {

        _ = try await Chat.delete.write(SlackEnvelope.self) {
            $0.from(authority ?? Slack.defaultAuthor)
              .body(DeleteMessagePayload(at: ts, in: channel.id))
        }
    }
}
