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

extension Message {

    /**
     Updates the message at `ts` in `channel`.

     - important: `chat.update` only succeeds as the identity that posted the message —
       pass the same `author` the message was originally sent `from` (or leave `nil`
       only when it was posted by `Slack.defaultAuthor`).
     */
    @discardableResult
    public static func update(messageAt ts: String, in channel: String, with newMessage: Message, as author: Author? = nil) async throws -> MessageResponse {

        let resp = try await Chat.update.POST
            .messageAt(ts, in: channel)
            .message(newMessage)
            .from(author)
            .response()

        guard let chatResp = try? resp.asType(ChatResponse.self),
              let response = MessageResponse(chatResp)
        else { throw SlackError.Chat(resp.json?.description)  }
        return response
    }

    public static func delete(messageAt ts: String, in channel: Channel, authority: Author? = nil) async throws {

        let resp = try await Chat.delete.POST
            .params(["ts": ts, "channel": channel.id])
            .from(authority)
            .response()

        guard (try? resp.asType(ChatResponse.self)) != nil
        else { throw SlackError.Chat(resp.json?.description)  }
    }
}
