//
//  PeopleTests.swift
//  SlackKit
//
//  `users.info` — the lookup that turns a DM's `user` field into a name.
//

import Foundation
import Testing
@testable import Slack

@MainActor
@Suite("People")
struct PeopleTests {

    @Test("users.info resolves to Slack's users.info")
    func endpointURL() {
        #expect(Users.info.method == "users.info")
        #expect(Users.info.path.absoluteString == "https://slack.com/api/users.info")
    }

    @Test("the lookup names its subject in the query and its credential in the header")
    func requestShape() throws {
        let built = try Users.info.GET
            .from(Author.user(token: "xoxp-secret"))
            .params(["user": "U04N39BMP"])
            .build()

        let query = try #require(built.urlRequest.url?.query)
        #expect(query.contains("user=U04N39BMP"))
        #expect(query.contains("xoxp-secret") == false)
        #expect(built.urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer xoxp-secret")
    }

    /// The fallback SlackOrg's deprecated `getInfo` resolves to when it is
    /// handed no author and no default is set. It must reach the wire as an
    /// unauthenticated call — Slack answers `not_authed` — rather than
    /// borrowing whatever credential was set last.
    @Test("an author with no token adds no credential")
    func unauthenticatedFallback() throws {
        let built = try Users.info.GET
            .from(Author(token: nil))
            .params(["user": "U1"])
            .build()

        #expect(built.urlRequest.value(forHTTPHeaderField: "Authorization") == nil)
    }
}
