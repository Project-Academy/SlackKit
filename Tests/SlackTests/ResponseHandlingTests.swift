//
//  ResponseHandlingTests.swift
//  SlackKit
//
//  Cover for the failure-classification layer: `ok` checking, the error
//  vocabulary, cursor normalisation, and the retry policy. These are the
//  behaviours that used to be accidents of which fields a `Decodable` happened
//  to declare non-optional.
//

import Foundation
import Testing
@testable import Slack

private func envelope(_ json: String) throws -> SlackEnvelope {
    try JSONDecoder().decode(SlackEnvelope.self, from: Data(json.utf8))
}

//--------------------------------------
// MARK: - THE VERDICT -
//--------------------------------------

@Suite("Slack's verdict")
struct EnvelopeTests {

    /// Slack reports failure at HTTP 200. `ok` is the only reliable signal, and
    /// it used to be decoded everywhere and read nowhere.
    @Test("a refusal is readable as a refusal")
    func refusalDecodes() throws {
        let env = try envelope(#"{"ok":false,"error":"not_in_channel"}"#)
        #expect(env.ok == false)
        #expect(SlackError.Code(rawValue: env.error!) == .notInChannel)
    }

    /// A body with no `ok` isn't a Slack API response at all — a proxy page, an
    /// HTML interstitial — which is a different failure from Slack saying no.
    @Test("a non-Slack body fails to decode as an envelope")
    func nonSlackBodyRejected() {
        #expect(throws: (any Error).self) {
            try envelope(#"{"message":"Bad gateway"}"#)
        }
    }

    /// Slack signals "no more pages" with an empty string, not a missing field.
    @Test("an empty cursor means no more pages")
    func emptyCursorIsNoCursor() throws {
        let done = try envelope(#"{"ok":true,"response_metadata":{"next_cursor":""}}"#)
        #expect(done.nextCursor == nil)

        let more = try envelope(#"{"ok":true,"response_metadata":{"next_cursor":"dXNlcjpV"}}"#)
        #expect(more.nextCursor == "dXNlcjpV")

        let absent = try envelope(#"{"ok":true}"#)
        #expect(absent.nextCursor == nil)
    }
}

//--------------------------------------
// MARK: - ERROR VOCABULARY -
//--------------------------------------

@Suite("Error vocabulary")
struct SlackErrorTests {

    /// The P198 class of bug: a caller branching on a Slack code. It failed
    /// because the payload was the stringified whole body, which no `case`
    /// could ever match.
    @Test("a known code is matchable in a pattern")
    func knownCodeMatches() {
        let error = SlackError.refused(method: "conversations.join", code: .alreadyInChannel)

        var tolerated = false
        switch error {
        case .refused(_, .alreadyInChannel), .refused(_, .methodNotSupportedForChannelType):
            tolerated = true
        default:
            tolerated = false
        }
        #expect(tolerated)
    }

    @Test("an unknown code survives verbatim")
    func unknownCodePreserved() {
        let code = SlackError.Code(rawValue: "some_new_slack_error")
        #expect(code == .other("some_new_slack_error"))
        #expect(code.rawValue == "some_new_slack_error")
    }

    @Test("every named code round-trips through its raw value")
    func codesRoundTrip() {
        let codes: [SlackError.Code] = [
            .alreadyInChannel, .notInChannel, .methodNotSupportedForChannelType,
            .channelNotFound, .isArchived, .cantInvite, .cantInviteSelf,
            .notAuthed, .invalidAuth, .tokenRevoked, .accountInactive,
            .missingScope, .noPermission, .messageNotFound, .cantUpdateMessage,
            .cantDeleteMessage, .msgTooLong, .noText, .alreadyReacted,
            .noReaction, .tooManyEmoji, .tooManyReactions, .userNotFound,
            .usersNotFound, .rateLimited,
        ]
        for code in codes {
            #expect(SlackError.Code(rawValue: code.rawValue) == code, "\(code) didn't round-trip")
        }
    }

    /// Slack's error bodies carry `needed`/`provided` OAuth scope lists. Those
    /// leaked into student-facing UI when a caller rendered the raw error.
    @Test("the human-readable description leaks no response body")
    func descriptionLeaksNothing() {
        let error = SlackError.refused(method: "chat.postMessage", code: .missingScope)
        let text = try! #require(error.errorDescription)
        #expect(text.contains("chat.postMessage"))
        #expect(text.contains("needed") == false)
        #expect(text.contains("provided") == false)
    }

    /// Retrying a call Slack already processed is how a post becomes a
    /// duplicate. Only what Slack certainly didn't run is retryable.
    @Test("retryability tracks whether Slack processed the call")
    func retryabilityIsHonest() {
        #expect(SlackError.transport(method: "chat.postMessage", status: 503, retryAfter: nil).isRetryable)
        #expect(SlackError.refused(method: "chat.postMessage", code: .rateLimited).isRetryable)

        // Slack ran it and said no — retrying changes nothing.
        #expect(SlackError.refused(method: "chat.postMessage", code: .notInChannel).isRetryable == false)
        // It probably worked; we just couldn't read the answer.
        #expect(SlackError.unreadable(method: "chat.postMessage", detail: "…").isRetryable == false)
    }

    @Test("auth failures are identifiable as such")
    func authFailuresFlagged() {
        #expect(SlackError.Code.invalidAuth.isAuthFailure)
        #expect(SlackError.Code.tokenRevoked.isAuthFailure)
        #expect(SlackError.Code.missingScope.isAuthFailure)
        #expect(SlackError.Code.notInChannel.isAuthFailure == false)
    }
}

//--------------------------------------
// MARK: - RETRY POLICY -
//--------------------------------------

@Suite("Retry policy")
struct RetryPolicyTests {

    @Test("Slack's Retry-After is honoured over our own backoff")
    func retryAfterWins() {
        let delay = RetryPolicy.rateLimitOnly.delay(
            after: SlackError.transport(method: "users.list", status: 429, retryAfter: 12),
            attempt: 1
        )
        #expect(delay == .seconds(12))
    }

    @Test("an absurd Retry-After is capped")
    func retryAfterCapped() {
        let delay = RetryPolicy.rateLimitOnly.delay(
            after: SlackError.transport(method: "users.list", status: 429, retryAfter: 6000),
            attempt: 1
        )
        #expect(delay == .seconds(30))
    }

    /// A write must not be re-issued through a dropped connection: Slack may
    /// have processed it, and a second attempt posts the message twice.
    @Test("a dropped connection is retried only for idempotent calls")
    func droppedConnectionOnlyRetriedWhenSafe() {
        let dropped = URLError(.networkConnectionLost)
        #expect(RetryPolicy.rateLimitOnly.delay(after: dropped, attempt: 1) == nil)
        #expect(RetryPolicy.idempotent.delay(after: dropped, attempt: 1) != nil)
    }

    @Test("a refusal is never retried")
    func refusalNotRetried() {
        let refused = SlackError.refused(method: "chat.postMessage", code: .channelNotFound)
        #expect(RetryPolicy.idempotent.delay(after: refused, attempt: 1) == nil)
    }

    @Test("attempts are bounded")
    func attemptsBounded() {
        let rateLimited = SlackError.transport(method: "users.list", status: 429, retryAfter: 1)
        #expect(RetryPolicy.rateLimitOnly.delay(after: rateLimited, attempt: 3) == nil)
        #expect(RetryPolicy.none.delay(after: rateLimited, attempt: 1) == nil)
    }
}

//--------------------------------------
// MARK: - PAGING -
//--------------------------------------

@Suite("Paging")
struct PagingTests {

    private struct MemberPage: SlackPage {
        let members: [String]?
        let response_metadata: SlackEnvelope.Metadata?
        var items: [String]? { members }
    }

    /// `has_more` was decoded and ignored, so a workspace bigger than one page
    /// silently reported as one page.
    @Test("a page reports whether more remain")
    func pageReportsCursor() throws {
        let page = try JSONDecoder().decode(
            MemberPage.self,
            from: Data(#"{"members":["U1","U2"],"response_metadata":{"next_cursor":"abc"}}"#.utf8)
        )
        #expect(page.items?.count == 2)
        #expect(page.nextCursor == "abc")
    }

    @Test("the last page has no cursor")
    func lastPageHasNoCursor() throws {
        let page = try JSONDecoder().decode(
            MemberPage.self,
            from: Data(#"{"members":["U3"],"response_metadata":{"next_cursor":""}}"#.utf8)
        )
        #expect(page.nextCursor == nil)
    }
}
