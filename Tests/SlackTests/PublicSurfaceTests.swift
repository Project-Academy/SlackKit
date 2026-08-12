//
//  PublicSurfaceTests.swift
//  SlackKit
//
//  Everything else in this suite is `@testable`, which sees `internal` and
//  `package` too — so it cannot tell whether a symbol an app needs is actually
//  reachable by one. This file imports the module the way an app does. It is
//  a compile-time test: if it builds, the surface is public.
//

import Foundation
import Testing
import Slack

@MainActor
@Suite("Public surface")
struct PublicSurfaceTests {

    /// The read surface a client acting as a person needs, none of which
    /// should require importing SlackOrg.
    @Test("user-principal reads are reachable without SlackOrg")
    func readsArePublic() {
        let _: (Author) async throws -> Slack.Identity = Slack.whoAmI(as:)
        let _: (String, Author) async throws -> Member = Member.info(_:as:)
        let _: (Author, Set<Channel.Kind>, Int?) async throws -> [Channel] = Channel.mine(as:kinds:max:)
    }

    /// A conversation can be classified and addressed from outside.
    @Test("channel kinds are reachable and carry the wire spellings")
    func channelKindIsPublic() {
        let kinds: Set<Channel.Kind> = [.publicChannel, .im]
        #expect(kinds.contains(.im))
        #expect(Channel.Kind.privateChannel.rawValue == "private_channel")
        #expect(Channel.Kind.allCases.count == 4)
        #expect(Channel("D1").kind == .publicChannel)   // no flags set
    }

    /// A receipt has to be storable and rebuildable by the app that holds it.
    @Test("a receipt can be built, encoded and decoded by a consumer")
    func receiptIsPublicAndCodable() throws {
        let receipt = MessageResponse(ts: "1786000949.850479", in: Channel("C1"))
        let restored = try JSONDecoder().decode(
            MessageResponse.self,
            from: try JSONEncoder().encode(receipt)
        )
        #expect(restored == receipt)
    }

    /// A caller that would rather not have its writes re-issued has to be able
    /// to say so.
    @Test("a write's retry policy can be chosen by the caller")
    func retryPolicyIsPublic() {
        let _: RetryPolicy = .none
        let _: RetryPolicy = .rateLimitOnly
        let _: RetryPolicy = .idempotent

        let send: (Message) -> (Author?, String, RetryPolicy) async throws -> MessageResponse = { message in
            { try await message.send(from: $0, to: $1, retry: $2) }
        }
        _ = send
    }

    /// A composer needs to build a fields section and to know, before posting,
    /// whether Slack will refuse what it built.
    @Test("composing and checking are reachable")
    func composingIsPublic() {
        let blocks: [Block] = [
            .header("Heading"),
            .section(fields: ["*A*\n1", "*B*\n2"]),
            .section(fields: [Block.Text("*C*\n3")]),
        ]
        #expect(blocks.validate().isEmpty)

        let broken: [Block] = [Block(type: "section")]
        let violation = try? #require(broken.validate().first)
        #expect(violation?.problem == .sectionHasNoContent)
        #expect(violation?.index == 0)
    }

    /// The distinction a renderer needs: carried, or understood.
    @Test("passthrough state is visible to a consumer")
    func passthroughIsPublic() throws {
        let carried = try JSONDecoder().decode(
            Block.self,
            from: Data(#"{"type":"space_invader","rows":3}"#.utf8)
        )
        #expect(carried.isPassthrough)
        #expect(Block.section("built here").isPassthrough == false)
    }
}
