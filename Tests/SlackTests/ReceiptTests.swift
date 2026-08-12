//
//  ReceiptTests.swift
//  SlackKit
//
//  A receipt has to outlive the process that earned it, or "edit the message I
//  just sent" stops working the moment the app is quit.
//

import Foundation
import Testing
@testable import Slack

@Suite("Receipt persistence")
struct ReceiptTests {

    private func roundTrip(_ receipt: MessageResponse) throws -> MessageResponse {
        let data = try JSONEncoder().encode(receipt)
        return try JSONDecoder().decode(MessageResponse.self, from: data)
    }

    /// The identity — `ts` plus channel — is what Slack needs to address the
    /// message again, and it is what has to survive.
    @Test("a receipt's identity survives a round trip")
    func identitySurvives() throws {
        var channel = Channel("C07BP065NJG")
        channel.name = "app-fixes"
        let receipt = MessageResponse(ts: "1786000949.850479", in: channel)

        let restored = try roundTrip(receipt)

        #expect(restored.ts == "1786000949.850479")
        #expect(restored.channel.id == "C07BP065NJG")
        #expect(restored.channel.name == "app-fixes")
        #expect(restored == receipt)
    }

    /// Slack's echo is not persisted: it is a convenience rather than proof,
    /// and `ReceivedMessage` is decode-only by design so that something read
    /// out of Slack can't be re-encoded into something postable. A receipt
    /// that came off the wire therefore isn't `==` to its restored self —
    /// but it addresses the same message, which is the job.
    @Test("the echo is dropped, and the message addressed is unchanged")
    func echoIsNotPersisted() throws {
        let wire = try JSONDecoder().decode(
            ChatResponse.self,
            from: Data(#"""
            {"ok":true,"channel":"C07BP065NJG","ts":"1786000949.850479",
             "message":{"text":"hello","ts":"1786000949.850479","user":"U04N39BMP"}}
            """#.utf8)
        )
        let posted = MessageResponse(wire)
        #expect(posted.message != nil)

        let restored = try roundTrip(posted)

        #expect(restored.message == nil)
        #expect(restored != posted)
        #expect(restored.ts == posted.ts)
        #expect(restored.channel.id == posted.channel.id)
    }

    /// The encoded form is the receipt and nothing else — a stored receipt
    /// should not quietly accumulate a copy of the message body.
    @Test("only ts and channel are written")
    func encodedShape() throws {
        let data = try JSONEncoder().encode(MessageResponse(ts: "1.2", in: Channel("D1")))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(Set(json.keys) == ["ts", "channel"])
    }
}
