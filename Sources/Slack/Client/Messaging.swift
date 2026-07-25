//
//  Messaging.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 26/11/2025.
//
//  The public messaging surface of the client kit: sending a message, and
//  updating/deleting a message you hold the receipt (`MessageResponse`) for.
//  Org-as-principal messaging (bot DMs, editing arbitrary messages, etc.)
//  lives in the SlackOrg module.
//

import Foundation

@MainActor
extension Message {

    /**
     Posts this message to `channel`.

     - important: When DMing a user, pass a **DM/IM conversation channel ID** (`D…`, obtained via
       `conversations.open`) — **not** the user's own ID (`U…`). Posting to a user's ID with a custom
       author makes the message appear to come from **that user's Slackbot** instead of from ProjectBOT,
       which is a footgun for two reasons:

       1. Slackbot messages are **not editable** — we can't update them after the fact.
       2. We **can't confirm a Slackbot message ever delivered**, and we can't inspect it afterwards.
          When ProjectBOT delivers the message (i.e. we post to the DM channel), we can open the DM with
          ProjectBOT and read its chat history to verify delivery and diagnose bugs. A message from the
          user's own Slackbot leaves no such trail.

       So: when DMing a user as the org's bot, prefer `sendDM(to:from:)` from the **SlackOrg** module,
       which resolves the DM channel for you. Only target a user's ID directly when you deliberately
       want the Slackbot appearance.

     - Parameter sender: The principal to post as. Falls back to
       ``Slack/Slack/defaultAuthor``; if that is unset too, the call goes out
       unauthenticated and Slack answers `not_authed`.
     */
    @discardableResult
    public func send(from sender: Author? = nil, to channel: String) async throws -> MessageResponse {

        let author = sender ?? Slack.defaultAuthor

        let response: ChatResponse = try await Chat.postMessage.write {
            $0.from(author)
              .body(PostMessagePayload(self, to: channel, as: author?.persona))
        }
        return MessageResponse(response)
    }
}

@MainActor
extension MessageResponse {

    /**
     Rewrites the message this receipt points at.

     - important: `chat.update` only succeeds as the identity that posted the message —
       pass the same `author` the message was originally sent `from` (or leave `nil`
       only when it was posted by ``Slack/Slack/defaultAuthor``).
     */
    @discardableResult
    public func update(to newMessage: Message, author: Author? = nil) async throws -> MessageResponse {

        let response: ChatResponse = try await Chat.update.write {
            $0.from(author ?? Slack.defaultAuthor)
              .body(UpdateMessagePayload(newMessage, at: ts, in: channel.id))
        }
        return MessageResponse(response)
    }

    /**
     Deletes the message this receipt points at.

     Returns nothing: the message is gone, so there is no receipt left to act
     on. (This used to hand back a `MessageResponse` wrapping the deleted
     message, which read as though you could still chain off it.)
     */
    public func delete(as author: Author? = nil) async throws {

        _ = try await Chat.delete.write(SlackEnvelope.self) {
            $0.from(author ?? Slack.defaultAuthor)
              .body(DeleteMessagePayload(at: ts, in: channel.id))
        }
    }
}
