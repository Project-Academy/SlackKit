//
//  Channels.swift
//  SlackKit — SlackOrg
//
//  Created by Sarfraz Basha on 27/11/2025.
//
//  Workspace-structure enumeration and conversation history. Bulk-read
//  capability: becomes server-internal, then gets deleted here.
//

import Foundation
import Slack

@MainActor
extension Channel {

    /**
     Every conversation in the workspace.

     Follows Slack's cursor to the end — a single `conversations.list` call
     returns one page, so the previous single-shot version silently reported a
     workspace of exactly its page size.
     */
    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    public static func list(as author: Author? = nil, maxChannels: Int? = nil) async throws -> [Channel] {

        try await Conversations.list.readPages(Page.self, maxItems: maxChannels) {
            $0.from(author ?? Slack.defaultAuthor)
              .params([
                  "exclude_archived": true,
                  // Comma-separated with no spaces — Slack does not trim these,
                  // and a stray space makes the whole entry unmatchable.
                  "types": "public_channel,private_channel,mpim,im"
              ])
        }
    }

    private struct Page: SlackPage {
        let channels: [Channel]?
        let response_metadata: SlackEnvelope.Metadata?
        var items: [Channel]? { channels }
    }

    /**
     This channel's messages, newest first.

     - Parameter maxMessages: Ceiling on how many to read. Slack pages these,
       and a channel's full history can be enormous, so the ceiling is explicit
       rather than implied by a page size. When it truncates the result,
       ``Slack/Slack/diagnostics`` is told.
     */
    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    public func history(maxMessages: Int = 200, as author: Author? = nil) async throws -> [MessageResponse] {

        let messages: [ReceivedMessage] = try await Conversations.history.readPages(
            MessagePage.self,
            maxItems: maxMessages
        ) {
            $0.from(author ?? Slack.defaultAuthor)
              .params(["channel": id, "include_all_metadata": true])
        }
        return messages.compactMap { MessageResponse($0, channel: self) }
    }

    /// The replies in `ts`'s thread.
    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    public func getReplies(to ts: String, maxMessages: Int = 200, as author: Author? = nil) async throws -> [MessageResponse] {

        let messages: [ReceivedMessage] = try await Conversations.replies.readPages(
            MessagePage.self,
            maxItems: maxMessages
        ) {
            $0.from(author ?? Slack.defaultAuthor)
              .params(["channel": id, "ts": ts])
        }
        return messages.compactMap { MessageResponse($0, channel: self) }
    }

    private struct MessagePage: SlackPage {
        let messages: [ReceivedMessage]?
        let response_metadata: SlackEnvelope.Metadata?
        var items: [ReceivedMessage]? { messages }
    }

    /// This channel's full metadata.
    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    public func info(as author: Author? = nil) async throws -> Channel {

        let response: InfoResponse = try await Conversations.info.read {
            $0.from(author ?? Slack.defaultAuthor)
              .params([
                  "channel": id,
                  "include_num_members": true,
                  "include_locale": true,
              ])
        }
        guard let channel = response.channel else {
            throw SlackError.unreadable(
                method: Conversations.info.method,
                detail: "ok:true with no `channel`"
            )
        }
        return channel
    }

    private struct InfoResponse: Decodable, Sendable {
        let channel: Channel?
    }
}
