//
//  ToleranceTests.swift
//  SlackKit
//
//  What happens to a block this kit can't model. Unmodelled *types* were
//  already carried whole; these cover the harder case — a type we do model,
//  shaped in a way we don't — which used to throw and take every sibling block
//  down with it.
//

import Foundation
import Testing
@testable import Slack

@Suite("Decode tolerance")
struct ToleranceTests {

    private func blocks(_ json: String) throws -> [Block] {
        try JSONDecoder().decode([Block].self, from: Data(json.utf8))
    }

    private func encoded(_ block: Block) throws -> [String: Any] {
        let data = try JSONEncoder().encode(block)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    //--------------------------------------
    // MARK: - THE REGRESSION -
    //--------------------------------------

    /// Block Kit Builder emits image blocks without `alt_text`, and
    /// `ImageBlock.alt_text` is non-optional. Decoding an array is
    /// all-or-nothing, so one such block used to lose the entire message.
    @Test("a malformed block no longer takes its siblings with it")
    func siblingsSurvive() throws {
        let decoded = try blocks("""
        [{"type":"section","text":{"type":"mrkdwn","text":"kept"}},
         {"type":"image","image_url":"https://example.com/chart.png"},
         {"type":"divider"}]
        """)

        #expect(decoded.count == 3)
        #expect(decoded[0].text?.text == "kept")
        #expect(decoded[2].type == "divider")
    }

    /// And the block that couldn't be modelled is carried, not blanked: what
    /// goes back out is what came in.
    @Test("what couldn't be modelled is re-encoded verbatim")
    func passthroughRoundTrips() throws {
        let decoded = try blocks("""
        [{"type":"image","image_url":"https://example.com/chart.png","image_width":720}]
        """)
        let image = try #require(decoded.first)

        #expect(image.isPassthrough)
        #expect(image.image == nil)

        let out = try encoded(image)
        #expect(out["type"] as? String == "image")
        #expect(out["image_url"] as? String == "https://example.com/chart.png")
        #expect(out["image_width"] as? Int == 720)
        #expect(Set(out.keys) == ["type", "image_url", "image_width"])
    }

    //--------------------------------------
    // MARK: - TELLING THE TWO APART -
    //--------------------------------------

    /// The flag is the only way to distinguish "a section carrying no text"
    /// from "a section we failed to read", since both present as `text == nil`.
    @Test("isPassthrough separates unread from empty")
    func passthroughIsDistinguishable() throws {
        let unreadable = try blocks(#"[{"type":"section","text":"a bare string, not a text object"}]"#)[0]
        let modelled   = try blocks(#"[{"type":"section","text":{"type":"mrkdwn","text":"fine"}}]"#)[0]
        let built      = Block.section("built here")

        #expect(unreadable.isPassthrough)
        #expect(unreadable.text == nil)

        #expect(modelled.isPassthrough == false)
        #expect(modelled.text?.text == "fine")

        #expect(built.isPassthrough == false)
    }

    /// A block that models cleanly must not be swept into the passthrough
    /// path — its unknown *fields* still ride in `raw`, as before.
    @Test("a modelled block keeps its typed reading and its extras")
    func modelledBlockUnaffected() throws {
        let section = try blocks("""
        [{"type":"section","text":{"type":"mrkdwn","text":"hi"},"future_key":{"nested":true}}]
        """)[0]

        #expect(section.isPassthrough == false)
        #expect(section.text?.text == "hi")
        #expect(section.raw?["future_key"] != nil)

        let out = try encoded(section)
        #expect(out["future_key"] != nil)
        #expect((out["text"] as? [String: Any])?["text"] as? String == "hi")
    }

    /// The pre-existing behaviour for a type the kit has never heard of.
    @Test("an unmodelled type is still carried whole")
    func unmodelledTypeUnchanged() throws {
        let alien = try blocks(#"[{"type":"space_invader","rows":3,"block_id":"b1"}]"#)[0]

        #expect(alien.isPassthrough)
        #expect(alien.block_id == "b1")

        let out = try encoded(alien)
        #expect(out["rows"] as? Int == 3)
        #expect(out["type"] as? String == "space_invader")
    }

    //--------------------------------------
    // MARK: - THE LIMIT -
    //--------------------------------------

    /// Tolerance is for a body that doesn't fit the model — not for something
    /// that isn't a block at all. A missing `type` still throws, because there
    /// is nothing to carry it *as*.
    @Test("a block with no type is still an error")
    func typelessStillThrows() {
        #expect(throws: (any Error).self) {
            try blocks(#"[{"text":"no type here"}]"#)
        }
    }
}
