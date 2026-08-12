//
//  ChannelTests.swift
//  SlackKit
//
//  The conversation model: what a channel decodes to, how it classifies
//  itself, and how a set of kinds reaches the wire.
//

import Foundation
import Testing
@testable import Slack

@Suite("Channel")
struct ChannelTests {

    private func decode(_ json: String) throws -> Channel {
        try JSONDecoder().decode(Channel.self, from: Data(json.utf8))
    }

    //--------------------------------------
    // MARK: - KIND -
    //--------------------------------------

    /// The payload `users.conversations` actually returns for a DM: no name,
    /// and the counterpart carried in `user`. Without that field a DM can be
    /// listed but never labelled.
    @Test("a DM decodes with its counterpart and classifies as im")
    func directMessage() throws {
        let channel = try decode(#"{"id":"D72AQJQ3C","created":1,"is_im":true,"is_private":true,"user":"U04N39BMP"}"#)

        #expect(channel.kind == .im)
        #expect(channel.user == "U04N39BMP")
        #expect(channel.name == nil)
    }

    /// Slack flags an mpim and a DM as private too, so the classifier has to
    /// test the specific kinds first. Testing `is_private` first would call
    /// every DM a private channel.
    @Test("the more specific flag wins over is_private")
    func classificationPrecedence() throws {
        let mpim = try decode(#"{"id":"G1","is_mpim":true,"is_private":true}"#)
        let dm   = try decode(#"{"id":"D1","is_im":true,"is_private":true}"#)
        let priv = try decode(#"{"id":"C1","is_channel":true,"is_private":true}"#)
        let open = try decode(#"{"id":"C2","is_channel":true,"is_private":false}"#)

        #expect(mpim.kind == .mpim)
        #expect(dm.kind   == .im)
        #expect(priv.kind == .privateChannel)
        #expect(open.kind == .publicChannel)
    }

    @Test("kind raw values are the wire spellings, not the display ones")
    func rawValuesAreWireStrings() {
        #expect(Channel.Kind.publicChannel.rawValue  == "public_channel")
        #expect(Channel.Kind.privateChannel.rawValue == "private_channel")
        #expect(Channel.Kind.mpim.rawValue == "mpim")
        #expect(Channel.Kind.im.rawValue   == "im")

        #expect(Channel.Kind.publicChannel.glyph == "#")
        #expect(Channel.Kind.im.glyph == "💬")
    }

    /// A DM with no name used to describe itself as a private channel, because
    /// the old classifier reached `is_private` before `is_im`.
    @Test("a nameless DM describes itself as a DM")
    func dmDescription() throws {
        let dm = try decode(#"{"id":"D1","is_im":true,"is_private":true}"#)
        #expect(dm.description == "DM(ID: D1)")
    }

    //--------------------------------------
    // MARK: - TYPES PARAMETER -
    //--------------------------------------

    /// Slack does not trim its comma-separated lists; a stray space makes the
    /// spaced entries unmatchable, so the whole filter silently stops working.
    @Test("the types parameter carries no spaces")
    func typesParameterHasNoSpaces() {
        let all = Set(Channel.Kind.allCases).typesParameter

        #expect(all.contains(" ") == false)
        #expect(all == "public_channel,private_channel,mpim,im")
    }

    /// Built from a set, so the ordering has to come from somewhere stable —
    /// otherwise the same request differs run to run and can't be asserted.
    @Test("the types parameter is ordered regardless of how the set was built")
    func typesParameterIsStable() {
        let one: Set<Channel.Kind> = [.im, .publicChannel]
        let two: Set<Channel.Kind> = [.publicChannel, .im]

        #expect(one.typesParameter == "public_channel,im")
        #expect(one.typesParameter == two.typesParameter)
    }

    @Test("an empty set asks for nothing")
    func typesParameterEmpty() {
        #expect(Set<Channel.Kind>().typesParameter == "")
    }

    //--------------------------------------
    // MARK: - users.conversations -
    //--------------------------------------

    @MainActor
    @Test("mine() asks users.conversations, with the filter intact")
    func mineBuildsTheRightRequest() throws {
        #expect(Users.conversations.method == "users.conversations")
        #expect(Users.conversations.path.absoluteString == "https://slack.com/api/users.conversations")

        // The same request the facade builds, minus the paging params readPages
        // merges in at call time.
        let built = try Users.conversations.GET
            .from(Author.user(token: "xoxp-secret"))
            .params([
                "exclude_archived": true,
                "types": Set(Channel.Kind.allCases).typesParameter
            ])
            .build()

        // `URL.query` hands back the percent-decoded string, so the separator
        // reads as a literal comma here — the encoded form is what goes on the
        // wire. A space would survive decoding either way, which is the thing
        // worth guarding.
        let query = try #require(built.urlRequest.url?.query)
        #expect(query.contains("types=public_channel,private_channel,mpim,im"))
        #expect(query.contains(" ") == false)
        #expect(query.contains("xoxp-secret") == false)
        #expect(built.urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer xoxp-secret")
    }

    /// An empty set means "nothing", and answering it costs no round trip.
    /// Slack's own default for a missing `types` is public channels only, which
    /// is not what a caller who passed an empty set asked for.
    @MainActor
    @Test("asking for no kinds returns nothing without calling Slack")
    func mineWithNoKinds() async throws {
        let none = try await Channel.mine(as: .user(token: "xoxp-unused"), kinds: [])
        #expect(none.isEmpty)
    }

    //--------------------------------------
    // MARK: - ROUND TRIP -
    //--------------------------------------

    @Test("user survives a round trip")
    func userRoundTrips() throws {
        let decoded = try decode(#"{"id":"D1","is_im":true,"user":"U999"}"#)
        let reencoded = try JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(decoded)
        ) as? [String: Any]

        #expect(reencoded?["user"] as? String == "U999")
    }
}
