//
//  Directory.swift
//  SlackKit — SlackOrg
//
//  Created by Sarfraz Basha on 1/12/2025.
//
//  Workspace-member enumeration and profile reads. The largest PII surface in
//  the kit: becomes server-internal (the server resolves member linkages and
//  returns only what the caller is authorised to see), then gets deleted here.
//

import Foundation
import Slack

@MainActor
extension Member {

    /**
     Every member of the workspace.

     Follows Slack's cursor to the end. The single-shot version returned one
     page, so a workspace larger than the page size looked smaller than it is —
     the kind of truncation that reads as a complete answer.
     */
    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    public static func list(as author: Author? = nil, maxMembers: Int? = nil) async throws -> [Member] {

        try await Users.list.readPages(Page.self, maxItems: maxMembers) {
            $0.from(author ?? Slack.defaultAuthor)
        }
    }

    private struct Page: SlackPage {
        let members: [Member]?
        let response_metadata: SlackEnvelope.Metadata?
        var items: [Member]? { members }
    }

    /**
     Fetches full member info via `users.info`.

     Unlike ``getProfile(as:)`` (which returns a `Profile` with no membership
     flags), this returns the whole `Member` — including `deleted`,
     i.e. whether the member has been deactivated on the workspace.

     - Parameters:
       - id: The Slack member ID to look up.
       - author: The workspace's ``Slack/Author`` used to authenticate the
                 request. When `nil`, ``Slack/Slack/defaultAuthor`` is used.
     */
    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    public static func getInfo(_ id: String, as author: Author? = nil) async throws -> Member {

        let response: InfoResponse = try await Users.info.read {
            $0.from(author ?? Slack.defaultAuthor)
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

    /**
     This member's profile.

     - Parameter author: The credential to read as. Previously this call alone
       ignored the author it was given and always used the global default,
       which made "who is allowed to see this profile?" depend on load order.
     */
    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    public func getProfile(as author: Author? = nil) async throws -> Profile {

        let response: ProfileResponse = try await Users.profileGet.read {
            $0.from(author ?? Slack.defaultAuthor)
              .params([
                  "user": id,
                  "include_labels": true
              ])
        }
        guard let profile = response.profile else {
            throw SlackError.unreadable(method: Users.profileGet.method, detail: "ok:true with no `profile`")
        }
        return profile
    }

    private struct ProfileResponse: Decodable, Sendable {
        let profile: Profile?
    }
}
