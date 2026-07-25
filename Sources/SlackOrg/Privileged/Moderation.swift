//
//  Moderation.swift
//  SlackKit — SlackOrg
//
//  Created by Sarfraz Basha on 27/11/2025.
//
//  Channel-membership control (join/invite/kick). Admin-grade capability:
//  becomes server-internal behind role-gated endpoints, then gets deleted here.
//

import Foundation
import Slack

@MainActor
extension Channel {

    /**
     Joins `author` to this channel.

     `conversations.join` is idempotent for public channels. Two refusals mean
     the caller already has what it wanted and are therefore *not* errors:
     `already_in_channel` (the repeat case) and
     `method_not_supported_for_channel_type` (DMs and mpims can't be joined, and
     don't need to be — posting works regardless). Everything else throws.
     */
    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    @discardableResult
    public func join(as author: Author? = nil) async throws -> Channel {

        do {
            let response: JoinResponse = try await Conversations.join.write {
                $0.from(author ?? Slack.defaultAuthor)
                  .body(ChannelMembershipPayload(channel: id))
            }
            if let warning = response.warning {
                Slack.report("conversations.join: \(warning)")
            }
            return response.channel ?? self
        } catch let SlackError.refused(_, code)
            where code == .alreadyInChannel || code == .methodNotSupportedForChannelType {
            return self
        }
    }

    private struct JoinResponse: Decodable, Sendable {
        let channel: Channel?
        let warning: String?
    }

    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    @discardableResult
    public func invite(_ user: Member, as author: Author? = nil) async throws -> Channel {
        try await invite([user], as: author)
    }

    /**
     Invites `users` to this channel.

     Slack can partially succeed here — invalid IDs come back in `errors` while
     the valid ones are still invited. Those are reported through
     ``Slack/Slack/diagnostics`` rather than thrown, because the call did do
     what it could.
     */
    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    @discardableResult
    public func invite(_ users: [Member], as author: Author? = nil) async throws -> Channel {

        let response: InviteResponse = try await Conversations.invite.write {
            $0.from(author ?? Slack.defaultAuthor)
              .body(InvitePayload(channel: id, users: users.map(\.id).joined(separator: ",")))
        }

        if let warning = response.warning {
            Slack.report("conversations.invite: \(warning)")
        }
        if let errors = response.errors, !errors.isEmpty {
            Slack.report("conversations.invite: \(errors.map(\.description).joined(separator: ", "))")
        }
        return response.channel ?? self
    }

    private struct InviteResponse: Decodable, Sendable {

        let channel: Channel?
        let warning: String?
        let errors: [InviteError]?

        struct InviteError: Decodable, Sendable, CustomStringConvertible {
            let user: String
            let error: String
            var description: String { "\(user): \(error)" }
        }
    }

    /**
     Removes `user` from this channel.

     Throws when the kick fails. It previously discarded the response entirely,
     so "removed" and "you don't have permission to remove" were the same
     outcome from the caller's side.
     */
    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    public func kick(_ user: Member, authority: Author? = nil) async throws {

        _ = try await Conversations.kick.write(SlackEnvelope.self) {
            $0.from(authority ?? Slack.defaultAuthor)
              .body(ChannelMembershipPayload(channel: id, user: user.id))
        }
    }
}
