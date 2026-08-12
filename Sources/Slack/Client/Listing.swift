//
//  Listing.swift
//  SlackKit
//
//  What a credential can see. `users.conversations` answers "the conversations
//  this token's user is in", which is a different question from
//  `conversations.list`'s "every conversation in the workspace" — and the only
//  one a client acting as a person should be asking.
//

import Foundation

@MainActor
extension Channel {

    /**
     The conversations this credential's user is a member of.

     Slack filters membership server-side here, so unlike
     `conversations.list` there is no `is_member` to check afterwards and no
     reading of channels the user isn't in.

     Follows the cursor to the end — one call returns a single page, and a
     partial list of "your channels" is worse than none, because nothing about
     it looks incomplete.

     - Parameter kinds: Which conversation kinds to ask for. An empty set asks
       for nothing and is answered without a round trip; Slack's own default
       (public channels only) is deliberately not reproduced, because a caller
       that passed an empty set did not mean "surprise me".
     - Parameter max: A ceiling on how many to accumulate. When it truncates,
       ``Slack/Slack/diagnostics`` is told.
     */
    public static func mine(
        as author: Author,
        kinds: Set<Kind> = Set(Kind.allCases),
        max: Int? = nil
    ) async throws -> [Channel] {

        guard !kinds.isEmpty else { return [] }

        return try await Users.conversations.readPages(MyConversations.self, maxItems: max) {
            $0.from(author)
              .params([
                  "exclude_archived": true,
                  // Comma-separated with no spaces — Slack does not trim these,
                  // and a stray space makes the whole entry unmatchable.
                  "types": kinds.typesParameter
              ])
        }
    }

    private struct MyConversations: SlackPage {
        let channels: [Channel]?
        let response_metadata: SlackEnvelope.Metadata?
        var items: [Channel]? { channels }
    }
}
