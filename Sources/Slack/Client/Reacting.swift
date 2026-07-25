//
//  Reacting.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 1/12/2025.
//

import Foundation

@MainActor
extension MessageResponse {

    /**
     Adds `reaction` to this message.

     Slack answers `already_reacted` when the emoji is already there, which is
     the outcome the caller wanted — so it's success, not an error. The call is
     therefore idempotent, and safe to retry through a dropped connection.
     */
    public func addReaction(_ reaction: String, as author: Author? = nil) async throws {
        try await react(with: Reactions.add, reaction: reaction, tolerating: .alreadyReacted, as: author)
    }

    /**
     Removes `reaction` from this message.

     `no_reaction` means it wasn't there to remove — again the caller's intended
     end state, so it's treated as success.
     */
    public func removeReaction(_ reaction: String, as author: Author? = nil) async throws {
        try await react(with: Reactions.remove, reaction: reaction, tolerating: .noReaction, as: author)
    }

    private func react(
        with endpoint: Reactions,
        reaction: String,
        tolerating tolerated: SlackError.Code,
        as author: Author?
    ) async throws {
        do {
            _ = try await endpoint.write(SlackEnvelope.self, retry: .idempotent) {
                $0.from(author ?? Slack.defaultAuthor)
                  .body(ReactionPayload(channel: channel.id, name: reaction, timestamp: ts))
            }
        } catch let SlackError.refused(_, code) where code == tolerated {
            return
        }
    }

    /**
     Every reaction currently on this message.

     Returns an **empty array** when the message has none. Slack omits the
     `reactions` key entirely in that case, which this used to read as a failure
     and throw on — making "nobody reacted yet" indistinguishable from "the call
     didn't work".
     */
    public func getReactions(as author: Author? = nil) async throws -> [ReceivedMessage.Reaction] {

        let response: Response = try await Reactions.get.read(retry: .idempotent) {
            $0.from(author ?? Slack.defaultAuthor)
              .params([
                  "channel": channel.id,
                  "timestamp": ts,
                  "full": true  // always return the complete reaction list
              ])
        }
        return response.message?.reactions ?? []
    }

    private struct Response: Decodable, Sendable {
        let message: ReceivedMessage?
    }
}
