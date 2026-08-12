//
//  ValidationTests.swift
//  SlackKit
//
//  Catching what Slack would reject, while there is still something to fix.
//

import Foundation
import Testing
@testable import Slack

@Suite("Validation")
struct ValidationTests {

    //--------------------------------------
    // MARK: - NOTHING WRONG -
    //--------------------------------------

    /// The common case has to be silent, or nobody will trust the noisy one.
    @Test("a well-formed message reports nothing")
    func validMessageIsSilent() {
        let blocks: [Block] = [
            .header("Markable 1.7.0"),
            .section("Markable now *locks to the iPad you signed in on*."),
            .section(fields: ["*Rollout*\nAll marking iPads", "*Minimum build*\n1.7.0"]),
            .context(["Shipped by @saf"]),
            .divider,
            .actions([.button(.init(text: .init(plain: "Release notes"), url: "https://example.com"))]),
        ]

        #expect(blocks.validate().isEmpty)
    }

    //--------------------------------------
    // MARK: - THE RULES -
    //--------------------------------------

    /// The one a composer hits by accident: delete a section's text and it
    /// still looks like a block, but Slack refuses the whole message.
    @Test("a section with neither text nor fields is caught")
    func emptySection() {
        let empty = Block(type: "section")
        let found = empty.validate()

        #expect(found.count == 1)
        #expect(found.first?.problem == .sectionHasNoContent)
        #expect(found.first?.blockType == "section")
    }

    @Test("over-long text is caught, per field, with both numbers")
    func textLimits() {
        let longSection = Block.section(String(repeating: "a", count: 3001))
        #expect(longSection.validate().first?.problem
                == .textTooLong(field: "text", count: 3001, limit: 3000))

        let longHeader = Block.header(String(repeating: "a", count: 151))
        #expect(longHeader.validate().first?.problem
                == .textTooLong(field: "text", count: 151, limit: 150))

        let longField = Block.section(fields: ["ok", String(repeating: "a", count: 2001)])
        #expect(longField.validate().first?.problem
                == .textTooLong(field: "fields[1]", count: 2001, limit: 2000))
    }

    @Test("over-full collections are caught")
    func countLimits() {
        let manyFields = Block.section(fields: (1...11).map { "field \($0)" })
        #expect(manyFields.validate().contains { $0.problem == .tooManyFields(count: 11, limit: 10) })

        let manyElements = Block.context((1...11).map { "note \($0)" })
        #expect(manyElements.validate().contains { $0.problem == .tooManyElements(count: 11, limit: 10) })

        let tooManyBlocks = Array(repeating: Block.divider, count: 51)
        #expect(tooManyBlocks.validate().contains { $0.problem == .tooManyBlocks(count: 51, limit: 50) })
    }

    @Test("an over-long block_id is caught on any block")
    func blockIDLimit() {
        var divider = Block.divider
        divider.block_id = String(repeating: "b", count: 256)

        #expect(divider.validate().first?.problem == .blockIDTooLong(count: 256, limit: 255))
    }

    //--------------------------------------
    // MARK: - LOCATING IT -
    //--------------------------------------

    /// `invalid_blocks` names nothing. The point of validating locally is to
    /// be able to say *which* block, so the report carries the index.
    @Test("a violation names the block it belongs to")
    func violationsCarryTheirIndex() {
        let blocks: [Block] = [
            .divider,
            Block(type: "section"),
            .header(String(repeating: "a", count: 200)),
        ]
        let found = blocks.validate()

        #expect(found.count == 2)
        #expect(found[0].index == 1)
        #expect(found[0].problem == .sectionHasNoContent)
        #expect(found[1].index == 2)
        #expect(found[0].description == "block 1 (section): a section needs text or fields")
        #expect(found[1].description.contains("200 characters, limit 150"))
    }

    //--------------------------------------
    // MARK: - WHAT IT WON'T JUDGE -
    //--------------------------------------

    /// A block whose payload didn't fit the model was never read, so every
    /// typed property is nil — validating it would report violations against
    /// fields that don't exist. Slack stays the authority on those.
    @Test("a passthrough block is carried, not judged")
    func passthroughIsNotValidated() throws {
        let carried = try JSONDecoder().decode(
            Block.self,
            from: Data(#"{"type":"section","text":"a bare string, not a text object"}"#.utf8)
        )

        #expect(carried.isPassthrough)
        #expect(carried.text == nil)
        // Would otherwise report `sectionHasNoContent`, which is false: it has
        // text, just not text this kit could read.
        #expect(carried.validate().isEmpty)
    }

    /// An unmodelled type has no rules here to break.
    @Test("an unknown block type reports nothing")
    func unknownTypeIsSilent() throws {
        let alien = try JSONDecoder().decode(
            Block.self,
            from: Data(#"{"type":"space_invader","rows":3}"#.utf8)
        )
        #expect(alien.validate().isEmpty)
    }
}

//--------------------------------------
// MARK: - SURFACES -
//--------------------------------------

@Suite("Surface rules")
struct SurfaceValidationTests {

    private func decode(_ json: String) throws -> Block {
        try JSONDecoder().decode(Block.self, from: Data(json.utf8))
    }

    /// The differences between surfaces are not guessable, and getting one
    /// wrong means composing a message Slack will refuse. Catching it here is
    /// the difference between a warning and an `invalid_blocks` after the fact.
    @Test("families Slack refuses in a message are caught before it is sent")
    func messageOnlyRules() throws {
        let alert = Block.alert("Careful")
        let input = Block.input(label: "Email", element: .emailTextInput(.init()))
        let file  = try decode(#"{"type":"file","external_id":"F1","source":"remote"}"#)

        for block in [alert, input, file] {
            let violations = block.validate(on: .message)
            #expect(violations.count == 1, "\(block.type) should be refused in a message")
            if case let .notValidHere(surface, _) = violations.first?.problem {
                #expect(surface == .message)
            } else {
                Issue.record("\(block.type) reported \(String(describing: violations.first?.problem))")
            }
        }
    }

    /// And are accepted where they belong, so the rule is a rule rather than a
    /// blanket refusal.
    @Test("the same families are legal on the surfaces that take them")
    func legalElsewhere() {
        #expect(Block.alert("Careful").validate(on: .modal).isEmpty)
        #expect(Block.input(label: "Email", element: .emailTextInput(.init())).validate(on: .modal).isEmpty)
        #expect(Block.input(label: "Email", element: .emailTextInput(.init())).validate(on: .homeTab).isEmpty)

        // `file` is legal nowhere this app can post.
        #expect(Block.alert("Careful").validate(on: .homeTab).isEmpty == false)
    }

    /// Slack renders at most two charts in one message and silently drops the
    /// rest, which is worse than refusing them.
    @Test("more than two charts in a message is caught")
    func chartCeiling() {
        let chart = Block.dataVisualization(title: "Marks", chart: .pie(segments: [.init("A", value: 1)]))
        let message = Array(repeating: chart, count: 3)

        let violations = message.validate()
        #expect(violations.contains { violation in
            if case let .tooManyOfAKind(type, count, limit) = violation.problem {
                return type == "data_visualization" && count == 3 && limit == 2
            }
            return false
        })

        #expect(Array(repeating: chart, count: 2).validate().isEmpty)
    }

    @Test("an ordinary message is unaffected")
    func ordinaryMessage() {
        let blocks: [Block] = [.header("Fine"), .section("Also fine"), .divider]
        #expect(blocks.validate().isEmpty)
        #expect(blocks.validate(on: .modal).isEmpty)
    }
}
