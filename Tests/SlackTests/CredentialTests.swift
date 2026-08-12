//
//  CredentialTests.swift
//  SlackKit
//
//  A credential's two jobs outside of authenticating: saying what kind it is,
//  and never saying what it is.
//

import Foundation
import Testing
@testable import Slack

@Suite("Credentials")
struct CredentialTests {

    //--------------------------------------
    // MARK: - NOT PRINTING ITSELF -
    //--------------------------------------

    /// The whole point: interpolation, `print`, `dump` and `os_log` all route
    /// through these, and unified-logging entries outlive the process.
    @Test("a token never appears in a description")
    func tokenIsRedacted() {
        let secret = "xoxp-1234567890-0987654321-abcdefghijklmnop"
        let author = Author.user(token: secret)

        #expect(author.description.contains(secret) == false)
        #expect(author.description.contains("1234567890") == false)
        #expect(author.debugDescription.contains(secret) == false)
        #expect("\(author)".contains(secret) == false)

        var dumped = ""
        dump(author, to: &dumped)
        #expect(dumped.contains(secret) == false)
    }

    /// Redacted, but not useless — the prefix says which kind of credential it
    /// is, which is the thing you're usually squinting at a log to find out.
    @Test("what survives redaction is the kind, not the secret")
    func redactionKeepsTheUsefulPart() {
        #expect(Author.user(token: "xoxp-secret").description == "Author(user xoxp-…)")
        #expect(Author.bot(token: "xoxb-secret").description == "Author(bot xoxb-…)")
        #expect(Author(token: nil).description == "Author(unauthenticated)")
        #expect(Author(token: "").description == "Author(unauthenticated)")
        #expect(Author(token: "mystery").description == "Author(token …)")
    }

    @Test("a persona is named, since it is what the reader will see")
    func personaIsShown() {
        let bot = Author.bot(token: "xoxb-secret", username: "ProjectBOT")
        #expect(bot.description == "Author(bot xoxb-… as ProjectBOT)")
    }

    //--------------------------------------
    // MARK: - KIND -
    //--------------------------------------

    /// A local read of the prefix, for deciding whether a post will appear as a
    /// person before spending a round trip asking Slack.
    @Test("a token's kind is readable from its prefix")
    func kindFromPrefix() {
        #expect(Author.user(token: "xoxp-abc").kind == .user)
        #expect(Author.bot(token: "xoxb-abc").kind == .bot)
        #expect(Author(token: "xapp-abc").kind == .unknown)
        #expect(Author(token: nil).kind == .unknown)
    }

    //--------------------------------------
    // MARK: - COMPOSER ERRORS -
    //--------------------------------------

    /// `invalid_blocks` is the error a Block Kit composer produces most, and it
    /// used to land in `.other` where no error copy would match it.
    @Test("the composer's own refusals are named")
    func composerCodes() {
        let pairs: [(String, SlackError.Code)] = [
            ("invalid_blocks", .invalidBlocks),
            ("invalid_blocks_format", .invalidBlocksFormat),
            ("posting_to_general_channel_denied", .postingToGeneralChannelDenied),
            ("restricted_action", .restrictedAction),
        ]

        for (raw, expected) in pairs {
            #expect(SlackError.Code(rawValue: raw) == expected)
            #expect(expected.rawValue == raw)
        }
    }

    /// None of them is a credential problem — telling someone to re-authenticate
    /// because their layout is illegal sends them the wrong way entirely.
    @Test("a bad layout is not an auth failure")
    func composerCodesAreNotAuthFailures() {
        #expect(SlackError.Code.invalidBlocks.isAuthFailure == false)
        #expect(SlackError.Code.restrictedAction.isAuthFailure == false)
        #expect(SlackError.Code.tokenRevoked.isAuthFailure)
    }
}
