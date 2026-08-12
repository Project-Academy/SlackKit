//
//  IdentityTests.swift
//  SlackKit
//
//  `auth.test` — the request it builds, and the discrimination its answer
//  carries. A caller that can't tell a bot token from a user token can't tell
//  the reader who a message came from.
//

import Foundation
import Testing
@testable import Slack

@MainActor
@Suite("Identity")
struct IdentityTests {

    private func decode(_ json: String) throws -> Slack.Identity {
        try JSONDecoder().decode(Slack.Identity.self, from: Data(json.utf8))
    }

    //--------------------------------------
    // MARK: - THE REQUEST -
    //--------------------------------------

    @Test("auth.test resolves to Slack's auth.test")
    func endpointURL() {
        #expect(Auth.test.method == "auth.test")
        #expect(Auth.test.path.absoluteString == "https://slack.com/api/auth.test")
    }

    /// Same guarantee the rest of the kit has: the credential travels in the
    /// header, never the body and never the query — a token in a URL survives
    /// in logs and proxies.
    @Test("the token goes in the header, not the body or the query")
    func tokenPlacement() throws {
        let built = try Auth.test.GET.from(Author.user(token: "xoxp-secret")).build()

        #expect(built.urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer xoxp-secret")
        #expect(built.urlRequest.httpBody == nil)
        #expect(built.urlRequest.url?.absoluteString.contains("xoxp-secret") == false)
    }

    //--------------------------------------
    // MARK: - THE ANSWER -
    //--------------------------------------

    /// A real user-token response. No `bot_id`, which is the whole signal.
    @Test("a user token reports no bot id")
    func userToken() throws {
        let identity = try decode("""
        {"ok":true,"url":"https://projectacademy.slack.com/","team":"Project Academy",
         "user":"saf","team_id":"T04N39BM3","user_id":"U04N39BMP"}
        """)

        #expect(identity.botID == nil)
        #expect(identity.isBot == false)
        #expect(identity.user == "saf")
        #expect(identity.userID == "U04N39BMP")
        #expect(identity.teamID == "T04N39BM3")
        #expect(identity.team == "Project Academy")
    }

    /// A bot token carries `bot_id`, and its `user` is the app's own bot user
    /// rather than a person — which is exactly why the flag is needed to
    /// describe who a post will come from.
    @Test("a bot token reports a bot id")
    func botToken() throws {
        let identity = try decode("""
        {"ok":true,"url":"https://projectacademy.slack.com/","team":"Project Academy",
         "user":"projectbot","team_id":"T04N39BM3","user_id":"U0BOTUSER","bot_id":"B0BN3RQGZ1C"}
        """)

        #expect(identity.botID == "B0BN3RQGZ1C")
        #expect(identity.isBot)
        #expect(identity.description == "Bot(@projectbot U0BOTUSER, Project Academy T04N39BM3)")
    }

    /// `auth.test`'s refusals are the ones a stored credential produces once it
    /// stops being valid, and they must classify rather than land in `.other`.
    @Test("a revoked or invalid credential classifies as an auth failure")
    func authFailuresClassify() throws {
        for raw in ["invalid_auth", "not_authed", "token_revoked", "account_inactive"] {
            let env = try JSONDecoder().decode(
                SlackEnvelope.self,
                from: Data(#"{"ok":false,"error":"\#(raw)"}"#.utf8)
            )
            let code = try #require(SlackError.Code(rawValue: try #require(env.error)))

            #expect(env.ok == false)
            #expect(code.isAuthFailure, "\(raw) should read as an auth failure")
        }
    }
}
