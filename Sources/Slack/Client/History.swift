//
//  History.swift
//  SlackKit
//
//  Reading a conversation as the person in it.
//
//  SlackOrg has both of these already, but as org-principal capabilities on
//  the server-migration checklist. Reading the last few messages of a channel
//  you are a member of, with your own token, is not that — it is the same
//  user-principal category as `Channel.mine`, and belongs beside it.
//

import Foundation

@MainActor
extension Channel {

    /**
     The most recent messages, newest first.

     - Parameter limit: How many to fetch. Deliberately small by default: this
       exists so a composer can see what it is replying to, not so an app can
       hold a conversation's history.

     - important: Needs a `*:history` scope for the conversation kind —
       `channels:history`, `groups:history`, `im:history`, `mpim:history`. A
       token with only the `:read` scopes can list conversations and will fail
       here with `missing_scope`.
     */
    public static func recent(
        _ channel: String,
        as author: Author,
        limit: Int = 5
    ) async throws -> [ReceivedMessage] {

        try await Conversations.history.readPages(MessagePage.self, pageSize: limit, maxItems: limit) {
            $0.from(author)
              .params(["channel": channel])
        }
    }

    /**
     Every message in one thread, oldest first — the parent included, which is
     how Slack returns it.

     Unbounded by default where ``recent(_:as:limit:)`` is not: a thread is a
     single conversation and half of one is worse than none.
     */
    public static func replies(
        to ts: String,
        in channel: String,
        as author: Author,
        max: Int = 500
    ) async throws -> [ReceivedMessage] {

        try await Conversations.replies.readPages(MessagePage.self, maxItems: max) {
            $0.from(author)
              .params(["channel": channel, "ts": ts])
        }
    }

    private struct MessagePage: SlackPage {
        let messages: [ReceivedMessage]?
        let response_metadata: SlackEnvelope.Metadata?
        var items: [ReceivedMessage]? { messages }
    }
}

extension ReceivedMessage {

    /// Whether this message starts a thread worth opening.
    public var startsThread: Bool {
        (reply_count ?? 0) > 0
    }
}
