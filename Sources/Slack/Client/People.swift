//
//  People.swift
//  SlackKit
//
//  Looking up a person you already have an ID for. Distinct from SlackOrg's
//  directory reads, which enumerate a workspace: this answers "who is U123?",
//  which any credential may reasonably ask about someone it is already talking
//  to — a DM's counterpart, most obviously, since Slack sends no name for one.
//

import Foundation

@MainActor
extension Member {

    /**
     The member behind an ID.

     Returns the whole `Member` — including `deleted`, i.e. whether the account
     has been deactivated — rather than the profile alone.

     Takes its author non-optionally: this is the read a client makes about
     someone it is *already* in a conversation with, and which credential is
     asking decides what comes back.
     */
    public static func info(_ id: String, as author: Author) async throws -> Member {

        let response: InfoResponse = try await Users.info.read {
            $0.from(author)
              .params(["user": id])
        }
        guard let member = response.user else {
            throw SlackError.unreadable(method: Users.info.method, detail: "ok:true with no `user`")
        }
        return member
    }

    private struct InfoResponse: Decodable, Sendable {
        let user: Member?
    }
}
