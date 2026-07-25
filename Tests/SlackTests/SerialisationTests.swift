//
//  SerialisationTests.swift
//  SlackKit
//
//  Regression cover for the serialisation defects found in the 2026-07-25
//  audit. Each test names the behaviour it locks down; if one of these fails,
//  the wire format has drifted from what Slack accepts.
//

import Foundation
import Testing
@testable import Slack

private let decoder = JSONDecoder()
private let encoder = JSONEncoder()

private func decodeBlock(_ json: String) throws -> Block {
    try decoder.decode(Block.self, from: Data(json.utf8))
}

private func encodeToObject(_ value: some Encodable) throws -> [String: Any] {
    let data = try encoder.encode(value)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

//--------------------------------------
// MARK: - BLOCK ROUND TRIPS -
//--------------------------------------

@Suite("Block serialisation")
struct BlockSerialisationTests {

    /// There used to be two serialisers — `Block.json` (used to send) and
    /// `Block.encode(to:)` — and only the second one wrote rich-text content.
    /// Sending a relayed message therefore posted an empty `rich_text` block.
    @Test("rich_text content survives encoding")
    func richTextSurvivesEncoding() throws {
        let block = try decodeBlock("""
        {
          "type": "rich_text",
          "block_id": "abc",
          "elements": [
            { "type": "rich_text_section",
              "elements": [ { "type": "text", "text": "hello world" } ] }
          ]
        }
        """)

        #expect(block.richText?.count == 1)

        let encoded = try encodeToObject(block)
        let elements = try #require(encoded["elements"] as? [[String: Any]])
        #expect(elements.count == 1)
        #expect(elements[0]["type"] as? String == "rich_text_section")

        // And it decodes back to the same value.
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    /// Same defect, `actions` half: buttons vanished on the way out.
    @Test("actions content survives encoding")
    func actionsSurviveEncoding() throws {
        let block = try decodeBlock("""
        {
          "type": "actions",
          "elements": [
            { "type": "button",
              "text": { "type": "plain_text", "text": "Open" },
              "url": "https://example.com",
              "action_id": "a1" }
          ]
        }
        """)

        #expect(block.actions?.count == 1)

        let encoded = try encodeToObject(block)
        let elements = try #require(encoded["elements"] as? [[String: Any]])
        #expect(elements.count == 1)
        #expect(elements[0]["url"] as? String == "https://example.com")
    }

    /// `ActionElement.encode` delegated wholly to `Button`, which has no `type`
    /// field — so the kit emitted button elements Slack rejects, and which the
    /// kit itself then failed to decode.
    @Test("an encoded button keeps its type discriminator")
    func encodedButtonKeepsType() throws {
        let block = Block(
            type: "actions",
            actions: [.button(.init(text: .init(plain: "Open"), url: "https://example.com"))]
        )

        let encoded = try encodeToObject(block)
        let elements = try #require(encoded["elements"] as? [[String: Any]])
        #expect(elements[0]["type"] as? String == "button")

        // The round trip that used to throw `keyNotFound: "type"`.
        let reDecoded = try decoder.decode(Block.self, from: encoder.encode(block))
        #expect(reDecoded == block)
    }

    /// An unrecognised `rich_text_*` kind used to collapse to an empty section,
    /// deleting the content of any message relayed through the kit.
    @Test("an unknown rich_text kind round-trips verbatim")
    func unknownRichTextKindPreserved() throws {
        let block = try decodeBlock("""
        {
          "type": "rich_text",
          "elements": [
            { "type": "rich_text_something_new",
              "elements": [ { "type": "text", "text": "keep me" } ] }
          ]
        }
        """)

        let encoded = try encodeToObject(block)
        let elements = try #require(encoded["elements"] as? [[String: Any]])
        #expect(elements[0]["type"] as? String == "rich_text_something_new")

        let inner = try #require(elements[0]["elements"] as? [[String: Any]])
        #expect(inner[0]["text"] as? String == "keep me")
    }

    /// Same guarantee for an interactive element kind we don't model.
    @Test("an unknown action element round-trips verbatim")
    func unknownActionElementPreserved() throws {
        let block = try decodeBlock("""
        {
          "type": "actions",
          "elements": [
            { "type": "datepicker", "action_id": "d1", "initial_date": "2026-07-25" }
          ]
        }
        """)

        let encoded = try encodeToObject(block)
        let elements = try #require(encoded["elements"] as? [[String: Any]])
        #expect(elements[0]["type"] as? String == "datepicker")
        #expect(elements[0]["initial_date"] as? String == "2026-07-25")
    }

    /// A section carrying only `fields` is legal Slack. `Block.description`
    /// force-unwrapped `text`, so logging one crashed the app.
    @Test("describing a fields-only section doesn't trap")
    func fieldsOnlySectionDescribable() throws {
        let block = try decodeBlock("""
        {
          "type": "section",
          "fields": [ { "type": "mrkdwn", "text": "*Priority*" },
                      { "type": "mrkdwn", "text": "*Type*" } ]
        }
        """)

        #expect(block.text == nil)
        #expect(block.description.contains("Priority"))
        #expect(block.plainText.contains("Priority"))
    }

    /// Header blocks have the same shape of hazard.
    @Test("describing a text-less header doesn't trap")
    func textlessHeaderDescribable() throws {
        let block = try decodeBlock(#"{"type":"header"}"#)
        #expect(block.description.isEmpty == false)
    }

    @Test("ordered lists number upward instead of repeating 1.")
    func orderedListNumbers() throws {
        let block = try decodeBlock("""
        {
          "type": "rich_text",
          "elements": [
            { "type": "rich_text_list", "style": "ordered", "elements": [
                { "type": "rich_text_section", "elements": [{ "type": "text", "text": "first" }] },
                { "type": "rich_text_section", "elements": [{ "type": "text", "text": "second" }] }
            ]}
          ]
        }
        """)

        #expect(block.plainText.contains("1. first"))
        #expect(block.plainText.contains("2. second"))
    }
}

//--------------------------------------
// MARK: - OUTGOING PAYLOADS -
//--------------------------------------

@Suite("Outgoing payloads")
struct PayloadTests {

    /// A composed message must not carry receive-only fields onto the wire —
    /// which is the reason `Message` and `ReceivedMessage` are separate types.
    @Test("a post body carries only what Slack accepts")
    func postBodyIsCompositionOnly() throws {
        let message = Message("hello", blocks: [.section("hi")], mrkdwn: true)
        let payload = PostMessagePayload(message, to: "C123", as: nil)
        let body = try encodeToObject(payload)

        #expect(body["channel"] as? String == "C123")
        #expect(body["text"] as? String == "hello")
        #expect(body["blocks"] != nil)
        #expect(body["mrkdwn"] as? Bool == true)

        // Never present on an outgoing body.
        for absent in ["ts", "user", "bot_id", "app_id", "subtype", "permalink", "edited", "team"] {
            #expect(body[absent] == nil, "outgoing body leaked \(absent)")
        }
    }

    @Test("unset optionals are omitted, not sent as null")
    func unsetOptionalsOmitted() throws {
        let payload = PostMessagePayload(Message("bare"), to: "C1", as: nil)
        let body = try encodeToObject(payload)

        #expect(body["thread_ts"] == nil)
        #expect(body["metadata"] == nil)
        #expect(body["username"] == nil)
    }

    @Test("a bot persona rides on the payload")
    func personaOnPayload() throws {
        let author = Author.bot(token: "xoxb-1", username: "LibraryBOT", iconEmoji: "books")
        let payload = PostMessagePayload(Message("hi"), to: "C1", as: author.persona)
        let body = try encodeToObject(payload)

        #expect(body["username"] as? String == "LibraryBOT")
        // Bare emoji names get wrapped.
        #expect(body["icon_emoji"] as? String == ":books:")
    }

    @Test("a user author contributes no persona")
    func userAuthorHasNoPersona() {
        #expect(Author.user(token: "xoxp-1").persona == nil)
    }

    @Test("an emoji icon suppresses the url icon")
    func emojiBeatsURL() {
        let author = Author.bot(token: "t", iconEmoji: ":books:", iconURL: "https://example.com/i.png")
        #expect(author.persona?.icon_emoji == ":books:")
        #expect(author.persona?.icon_url == nil)
    }
}

//--------------------------------------
// MARK: - RECEIVED MESSAGES -
//--------------------------------------

@Suite("Received messages")
struct ReceivedMessageTests {

    /// Slack omits `text` on block-only posts and some subtypes; that isn't a
    /// decode failure.
    @Test("a message with no text decodes")
    func textlessMessageDecodes() throws {
        let msg = try decoder.decode(
            ReceivedMessage.self,
            from: Data(#"{"type":"message","ts":"1.0","blocks":[]}"#.utf8)
        )
        #expect(msg.text.isEmpty)
    }

    /// `description` used to force-unwrap `purpose` for this subtype.
    @Test("describing a channel_purpose message without a purpose doesn't trap")
    func purposelessSubtypeDescribable() throws {
        let msg = try decoder.decode(
            ReceivedMessage.self,
            from: Data(#"{"type":"message","subtype":"channel_purpose","text":"set it"}"#.utf8)
        )
        #expect(msg.description.contains("set it"))
    }

    @Test("recomposing keeps content and drops the posting record")
    func recomposeKeepsContent() throws {
        let msg = try decoder.decode(
            ReceivedMessage.self,
            from: Data("""
            {"type":"message","ts":"1700000000.1","user":"U1","bot_id":"B1",
             "text":"original","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"hi"}}]}
            """.utf8)
        )

        let recomposed = msg.recomposed()
        #expect(recomposed.text == "original")
        #expect(recomposed.blocks?.count == 1)
        #expect(recomposed.thread_ts == nil)

        let threaded = msg.recomposed(inThread: true)
        #expect(threaded.thread_ts == "1700000000.1")
    }

    @Test("plainText falls back to blocks when text is blank")
    func plainTextFallsBackToBlocks() throws {
        let msg = try decoder.decode(
            ReceivedMessage.self,
            from: Data(#"{"text":"   ","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"from a block"}}]}"#.utf8)
        )
        #expect(msg.plainText == "from a block")
    }
}

//--------------------------------------
// MARK: - TOLERANT DECODING -
//--------------------------------------

/// From the 2026-07-18 audit (F9, F10): shapes Slack legally sends that used to
/// fail decoding — and, because a failed decode took the whole response with
/// it, lost an entire member list or history page.
@Suite("Tolerant decoding")
struct TolerantDecodingTests {

    /// Labels only come back with `include_labels=true`; `users.info` and
    /// `users.list` don't ask for them.
    @Test("a profile field without a label decodes")
    func labellessFieldDecodes() throws {
        let field = try decoder.decode(Field.self, from: Data(#"{"value":"Physics","alt":""}"#.utf8))
        #expect(field.label == nil)
        #expect(field.value == "Physics")
    }

    @Test("a member carrying custom fields decodes")
    func memberWithCustomFieldsDecodes() throws {
        let member = try decoder.decode(Member.self, from: Data("""
        {"id":"U1","profile":{"real_name":"A Person",
         "fields":{"Xf01":{"value":"Physics","alt":""}}}}
        """.utf8))
        #expect(member.profile?.fields?["Xf01"]?.value == "Physics")
    }

    /// A context block may legally hold image elements alongside text.
    @Test("a context block with an image element decodes")
    func contextWithImageDecodes() throws {
        let block = try decodeBlock("""
        {"type":"context","elements":[
          {"type":"mrkdwn","text":"posted by"},
          {"type":"image","image_url":"https://example.com/a.png","alt_text":"avatar"}]}
        """)

        #expect(block.elements?.count == 2)
        #expect(block.plainText.contains("posted by"))
        #expect(block.plainText.contains("avatar"))

        let encoded = try encodeToObject(block)
        let elements = try #require(encoded["elements"] as? [[String: Any]])
        #expect(elements[1]["type"] as? String == "image")
        #expect(elements[1]["image_url"] as? String == "https://example.com/a.png")
    }

    @Test("an unknown context element round-trips verbatim")
    func unknownContextElementPreserved() throws {
        let block = try decodeBlock(#"{"type":"context","elements":[{"type":"video","src":"x"}]}"#)
        let encoded = try encodeToObject(block)
        let elements = try #require(encoded["elements"] as? [[String: Any]])
        #expect(elements[0]["type"] as? String == "video")
        #expect(elements[0]["src"] as? String == "x")
    }

    /// `event_payload` is arbitrary JSON, and `history` asks for all metadata.
    @Test("message metadata with a non-string payload decodes")
    func richMetadataDecodes() throws {
        let msg = try decoder.decode(ReceivedMessage.self, from: Data("""
        {"text":"hi","metadata":{"event_type":"submission",
         "event_payload":{"count":3,"ok":true,"nested":{"id":"x"}}}}
        """.utf8))

        #expect(msg.metadata?.event_payload["count"] == .number(3))
        #expect(msg.metadata?.event_payload["ok"] == .bool(true))
        #expect(msg.metadata?.event_payload["nested"]?["id"]?.stringValue == "x")
    }

    @Test("the all-strings metadata convenience still works")
    func stringMetadataConvenience() throws {
        let metadata = Message.Metadata("library_ask_for_help", ["user_id": "U1"])
        #expect(metadata.event_payload["user_id"] == .string("U1"))
    }
}
