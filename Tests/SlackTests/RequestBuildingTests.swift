//
//  RequestBuildingTests.swift
//  SlackKit
//
//  The seam between the typed payloads and Tapioca's request builder. The model
//  tests prove a payload encodes correctly; these prove the encoded bytes are
//  what actually gets sent, and that the credential lands in the header rather
//  than the body.
//

import Foundation
import Testing
@testable import Slack

@MainActor
@Suite("Request building")
struct RequestBuildingTests {

    private func body(of request: Request) throws -> [String: Any] {
        let built = try request.build()
        let data = try #require(built.urlRequest.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("a typed payload becomes the request body")
    func payloadBecomesBody() throws {
        let message = Message("hello", blocks: [.section("hi")], thread: "1700000000.1")
        let request = Chat.postMessage.POST
            .body(PostMessagePayload(message, to: "C123", as: nil))

        let sent = try body(of: request)
        #expect(sent["channel"] as? String == "C123")
        #expect(sent["text"] as? String == "hello")
        #expect(sent["thread_ts"] as? String == "1700000000.1")

        let blocks = try #require(sent["blocks"] as? [[String: Any]])
        #expect(blocks[0]["type"] as? String == "section")
    }

    /// Rich-text content reaching the wire is the whole point of collapsing the
    /// two serialisers — this is the end-to-end version of that guarantee.
    @Test("rich_text content reaches the wire")
    func richTextReachesTheWire() throws {
        let block = try JSONDecoder().decode(Block.self, from: Data("""
        {"type":"rich_text","elements":[
          {"type":"rich_text_section","elements":[{"type":"text","text":"relayed"}]}]}
        """.utf8))

        let request = Chat.postMessage.POST
            .body(PostMessagePayload(Message("fallback", blocks: [block]), to: "C1", as: nil))

        let sent = try body(of: request)
        let blocks = try #require(sent["blocks"] as? [[String: Any]])
        let elements = try #require(blocks[0]["elements"] as? [[String: Any]])
        let inline = try #require(elements[0]["elements"] as? [[String: Any]])
        #expect(inline[0]["text"] as? String == "relayed")
    }

    /// The credential is request metadata, not message content. A token in the
    /// body would be a token in every request log that captures bodies.
    @Test("the token goes in the header, never the body")
    func tokenStaysInTheHeader() throws {
        let author = Author.bot(token: "xoxb-secret", username: "TestBOT")
        let request = Chat.postMessage.POST
            .from(author)
            .body(PostMessagePayload(Message("hi"), to: "C1", as: author.persona))

        let built = try request.build()
        #expect(built.headers["Authorization"] == "Bearer xoxb-secret")

        let sent = try body(of: request)
        #expect(sent["token"] == nil)
        #expect(sent["username"] as? String == "TestBOT")
        let raw = String(data: built.urlRequest.httpBody!, encoding: .utf8)!
        #expect(raw.contains("xoxb-secret") == false)
    }

    @Test("an author with no token adds no header")
    func noTokenNoHeader() throws {
        let request = Chat.postMessage.POST.from(Author(token: nil))
        #expect(try request.build().headers["Authorization"] == nil)
    }

    @Test("the endpoint's method drives its URL")
    func methodDrivesURL() {
        #expect(Chat.postMessage.method == "chat.postMessage")
        #expect(Chat.postMessage.path.absoluteString == "https://slack.com/api/chat.postMessage")
        #expect(Users.profileGet.method == "users.profile.get")
        #expect(Conversations.join.path.absoluteString == "https://slack.com/api/conversations.join")
    }

    /// Slack does not trim its comma-separated lists; a stray space made the
    /// spaced entries unmatchable.
    @Test("the conversations.list types filter carries no spaces")
    func typesFilterHasNoSpaces() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()   // SlackTests
                .deletingLastPathComponent()   // Tests
                .deletingLastPathComponent()   // package root
                .appendingPathComponent("Sources/SlackOrg/Privileged/Channels.swift"),
            encoding: .utf8
        )
        #expect(source.contains("\"public_channel,private_channel,mpim,im\""))
        #expect(source.contains(", private_channel") == false)
    }
}
