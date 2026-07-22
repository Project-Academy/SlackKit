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

extension Member {

    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    public static func list() async throws -> [Member] {

        let resp = try await Users.list.GET
            .response()

        guard let response = try? resp.asType(Response.self),
              let members = response.members
        else { throw SlackError.Users(resp.json?.description) }
        return members

        struct Response: Decodable {
            let ok: Bool
            let members: [Member]?
        }
    }

    /**
     Fetches full member info via `users.info`.

     Unlike ``getProfile()`` (which returns a `Profile` with no membership
     flags), this returns the whole `Member` — including `deleted`,
     i.e. whether the member has been deactivated on the workspace.

     - Parameters:
       - id: The Slack member ID to look up.
       - author: The workspace's `Author` (e.g. a `Bot` carrying that
                 workspace's bot token) used to authenticate the request. When
                 `nil`, `Slack.defaultAuthor` is used instead.
     */
    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    public static func getInfo(_ id: String, as author: Author? = nil) async throws -> Member {

        let resp = try await Users.info.GET
            .from(author)
            .params(["user": id])
            .response()

        guard let response = try? resp.asType(Response.self),
              let member = response.user
        else { throw SlackError.Users(resp.json?.description) }
        return member

        struct Response: Decodable {
            let ok: Bool
            let user: Member?
        }
    }

    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    public func getProfile() async throws -> Profile {

        let resp = try await Users.profileGet.GET
            .params([
                "user": id,
                "include_labels": true
            ])
            .response()

        guard let response = try? resp.asType(Response.self),
              let profile = response.profile
        else { throw SlackError.Users(resp.json?.description) }
        return profile

        struct Response: Decodable {
            let ok: Bool
            let profile: Profile?
        }
    }
}
