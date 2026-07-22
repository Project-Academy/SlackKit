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

extension Channel {

    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    @discardableResult
    public func join(as author: Author? = nil) async throws -> Channel {

        // `author` joins the channel on that user's behalf (their token);
        // nil falls back to `Slack.defaultAuthor` via preProcess (the bot),
        // so existing callers are unaffected.
        let resp = try await Conversations.join.POST
            .params(["channel": id])
            .from(author)
            .response()

        guard let response = try? resp.asType(Response.self),
              let channel = response.channel
        else { throw SlackError.Conversations(resp.json?.description)  }
        if let warning = response.warning {
            print("Join warning: \(warning)")
        }
        return channel

    }

    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    @discardableResult
    public func invite(_ user: Member) async throws -> Channel {
        try await invite([user])
    }

    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    @discardableResult
    public func invite(_ users: [Member]) async throws -> Channel {

        let resp = try await Conversations.invite.POST
            .params([
                "channel": id,
                "users": users.compactMap(\.id).joined(separator: ","),
                "force": true // When set to `true` and multiple user IDs are provided, continue inviting the valid ones while disregarding invalid IDs.
            ])
            .response()

        guard let response = try? resp.asType(Response.self)
        else { throw SlackError.Conversations(resp.json?.description)  }
        if let warning = response.warning {
            print("Invite warning: \(warning)")
        }
        if let errors = response.errors {
            print("Invite errors: \(errors)")
        }
        return response.channel ?? self

        struct Response: Decodable {
            let ok: Bool
            let channel: Channel?
            let warning: String?

            let errors: [InviteError]?

            struct InviteError: Decodable, CustomStringConvertible {
                let user: String
                let error: String

                var description: String {
                    "\(user): \(error)"
                }
            }


        }

    }

    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    public func kick(_ user: Member, authority: Author? = nil) async throws {

        _ = try await Conversations.kick.POST
            .params([
                "channel": id,
                "user": user.id,
            ])
            .from(authority)
            .response()

    }
}
