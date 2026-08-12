//
//  HistoryTests.swift
//  SlackKit
//
//  Reading a conversation as the person in it, and telling a thread's parent
//  from its replies.
//

import Foundation
import Testing
@testable import Slack

@MainActor
@Suite("History")
struct HistoryTests {

    @Test("the endpoints resolve to Slack's own")
    func endpoints() {
        #expect(Conversations.history.method == "conversations.history")
        #expect(Conversations.replies.method == "conversations.replies")
    }

    @Test("history names its channel and carries the credential in the header")
    func historyRequest() throws {
        let built = try Conversations.history.GET
            .from(Author.user(token: "xoxp-secret"))
            .params(["channel": "C123"])
            .build()

        let query = try #require(built.urlRequest.url?.query)
        #expect(query.contains("channel=C123"))
        #expect(query.contains("xoxp-secret") == false)
        #expect(built.urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer xoxp-secret")
    }

    @Test("replies names both the channel and the thread")
    func repliesRequest() throws {
        let built = try Conversations.replies.GET
            .from(Author.user(token: "xoxp-secret"))
            .params(["channel": "C123", "ts": "1786000949.850479"])
            .build()

        let query = try #require(built.urlRequest.url?.query)
        #expect(query.contains("channel=C123"))
        #expect(query.contains("ts=1786000949.850479"))
    }

    //--------------------------------------
    // MARK: - TELLING A PARENT FROM A REPLY -
    //--------------------------------------

    /// `thread_ts` is set on the parent *and* on every reply, so it cannot say
    /// which is which. `reply_count` is present only on the parent, and is the
    /// only signal that a message has a thread worth opening.
    @Test("only a thread's parent reports a reply count")
    func threadParent() throws {
        let parent = try JSONDecoder().decode(ReceivedMessage.self, from: Data("""
        {"type":"message","text":"Doors open at 5:45pm","ts":"1.1",
         "thread_ts":"1.1","reply_count":3,"user":"U1"}
        """.utf8))

        let reply = try JSONDecoder().decode(ReceivedMessage.self, from: Data("""
        {"type":"message","text":"Which room?","ts":"1.2","thread_ts":"1.1","user":"U2"}
        """.utf8))

        let plain = try JSONDecoder().decode(ReceivedMessage.self, from: Data("""
        {"type":"message","text":"No thread here","ts":"1.3","user":"U3"}
        """.utf8))

        #expect(parent.startsThread)
        #expect(parent.reply_count == 3)

        #expect(reply.startsThread == false)
        #expect(reply.thread_ts == "1.1", "a reply still knows its thread")

        #expect(plain.startsThread == false)
        #expect(plain.thread_ts == nil)
    }

    /// A channel's history is full of subtypes — joins, purpose changes, and
    /// block-only posts with no text. None of them is a decode failure.
    @Test("history decodes the messages a real channel actually contains")
    func realHistoryShapes() throws {
        let messages = try JSONDecoder().decode([ReceivedMessage].self, from: Data("""
        [{"type":"message","subtype":"channel_join","text":"<@U1> has joined","ts":"1.1","user":"U1"},
         {"type":"message","ts":"1.2","user":"U2","blocks":[{"type":"divider"}]},
         {"type":"message","text":"plain","ts":"1.3","user":"U3","edited":{"user":"U3","ts":"1.4"}}]
        """.utf8))

        #expect(messages.count == 3)
        #expect(messages[0].subtype == "channel_join")
        #expect(messages[1].text == "", "a block-only post has no text, which is not an error")
        #expect(messages[1].blocks?.count == 1)
        #expect(messages[2].edited != nil)
    }
}
