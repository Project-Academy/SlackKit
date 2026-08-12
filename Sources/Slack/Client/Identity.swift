//
//  Identity.swift
//  SlackKit
//
//  Asking a credential who it is. The one question you can ask Slack without
//  already knowing the answer, and the only way to tell a user token from a
//  bot token without reading the token itself.
//

import Foundation

@MainActor
extension Slack {

    /**
     Who this credential is, and where.

     Takes its author **non-optionally**, unlike the rest of the kit. Every
     other facade has a sensible fallback; this one does not — "who am I" is
     meaningless without saying which credential is asking, and a version that
     quietly consulted ``defaultAuthor`` could answer about a principal the
     caller never named.

     Costs one round trip, and is worth spending immediately before a post: it
     is also the cheapest way to find out that a token has been revoked
     *before* the message goes out rather than after.
     */
    public static func whoAmI(as author: Author) async throws -> Identity {
        try await Auth.test.read(Identity.self) { $0.from(author) }
    }

    /**
     The answer to `auth.test`.

     ``botID`` is the discriminator that matters: Slack returns it only for a
     bot token, so it — not the shape of the token string — is how you know
     whether a post will appear as a person or as an app.
     */
    public struct Identity: Decodable, Sendable, Equatable {

        /// `T…` — the workspace this credential acts in.
        public let teamID: String
        /// The workspace's display name.
        public let team: String
        /// The workspace's URL, e.g. `https://projectacademy.slack.com/`.
        public let url: String

        /// `U…` — the user this credential acts as. Present for both token
        /// kinds; on a bot token it is the app's own bot user.
        public let userID: String
        /// That user's handle.
        public let user: String

        /// `B…`, and **only on a bot token**. `nil` means a user token, i.e.
        /// posts will appear as the person in ``user``.
        public let botID: String?

        /// Whether a post made with this credential appears as an app.
        public var isBot: Bool { botID != nil }

        private enum CodingKeys: String, CodingKey {
            case teamID = "team_id"
            case team
            case url
            case userID = "user_id"
            case user
            case botID = "bot_id"
        }
    }
}

extension Slack.Identity: CustomStringConvertible {

    public var description: String {
        "\(isBot ? "Bot" : "User")(@\(user) \(userID), \(team) \(teamID))"
    }
}
