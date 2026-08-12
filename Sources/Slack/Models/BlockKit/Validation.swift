//
//  Validation.swift
//  SlackKit
//
//  Slack's own limits, checked before the wire rather than after it.
//
//  Every rule here was already written down in `Block`'s doc comments and
//  enforced nowhere, so the first time you learned a message was illegal was
//  when `chat.postMessage` answered `invalid_blocks` — which names no block,
//  no field, and no number. A composer needs to say which one, and say it
//  while there is still something to fix.
//

import Foundation

extension Block {

    /**
     What is wrong with a block, and where.

     ``index`` is populated when the block was validated as part of a message
     and is `nil` when a block was validated on its own.
     */
    public struct Violation: Sendable, Equatable {

        public let index: Int?
        public let blockType: String
        public let problem: Problem

        public enum Problem: Sendable, Equatable {
            /// A section must carry `text`, `fields`, or both.
            case sectionHasNoContent
            case tooManyFields(count: Int, limit: Int)
            case tooManyElements(count: Int, limit: Int)
            case textTooLong(field: String, count: Int, limit: Int)
            case blockIDTooLong(count: Int, limit: Int)
            case tooManyBlocks(count: Int, limit: Int)
        }
    }

    //--------------------------------------
    // MARK: - LIMITS -
    //--------------------------------------

    package enum Limit {
        package static let blocksPerMessage = 50
        package static let fieldsPerSection = 10
        package static let elementsPerContext = 10
        package static let sectionText = 3000
        package static let fieldText = 2000
        package static let headerText = 150
        package static let blockID = 255
    }

    //--------------------------------------
    // MARK: - CHECKING -
    //--------------------------------------

    /**
     Slack's structural limits on this block, as documented on its own
     properties.

     A block whose ``isPassthrough`` is set is **not** checked: its payload
     didn't fit the model, so there is nothing here that can judge it fairly,
     and guessing would report violations against fields that were never read.
     Slack remains the authority; this only catches what can be caught early.

     Returns an empty array when there is nothing wrong, so
     `blocks.validate().isEmpty` reads as "postable".
     */
    public func validate(at index: Int? = nil) -> [Violation] {

        guard !isPassthrough else { return [] }

        var found: [Violation] = []
        func fail(_ problem: Violation.Problem) {
            found.append(Violation(index: index, blockType: type, problem: problem))
        }

        if let block_id, block_id.count > Limit.blockID {
            fail(.blockIDTooLong(count: block_id.count, limit: Limit.blockID))
        }

        switch type {
        case BlockType.section.rawValue:
            if text == nil, (fields ?? []).isEmpty {
                fail(.sectionHasNoContent)
            }
            if let text, text.text.count > Limit.sectionText {
                fail(.textTooLong(field: "text", count: text.text.count, limit: Limit.sectionText))
            }
            if let fields {
                if fields.count > Limit.fieldsPerSection {
                    fail(.tooManyFields(count: fields.count, limit: Limit.fieldsPerSection))
                }
                for (offset, field) in fields.enumerated() where field.text.count > Limit.fieldText {
                    fail(.textTooLong(field: "fields[\(offset)]", count: field.text.count, limit: Limit.fieldText))
                }
            }

        case BlockType.header.rawValue:
            if let text, text.text.count > Limit.headerText {
                fail(.textTooLong(field: "text", count: text.text.count, limit: Limit.headerText))
            }

        case "context":
            if let elements, elements.count > Limit.elementsPerContext {
                fail(.tooManyElements(count: elements.count, limit: Limit.elementsPerContext))
            }

        default:
            break
        }

        return found
    }
}

extension Array where Element == Block {

    /**
     Everything Slack would reject about this message, with each violation
     carrying the index of the block it belongs to.

     Checks the per-message limit as well as each block's own.
     */
    public func validate() -> [Block.Violation] {

        var found: [Block.Violation] = []

        if count > Block.Limit.blocksPerMessage {
            found.append(
                Block.Violation(
                    index: nil,
                    blockType: "message",
                    problem: .tooManyBlocks(count: count, limit: Block.Limit.blocksPerMessage)
                )
            )
        }

        for (index, block) in enumerated() {
            found.append(contentsOf: block.validate(at: index))
        }

        return found
    }
}

//--------------------------------------
// MARK: - DESCRIPTION -
//--------------------------------------

extension Block.Violation: CustomStringConvertible {

    /// Written to be shown to whoever is composing, not just logged: it names
    /// the block, the field, and both numbers.
    public var description: String {
        let where_ = index.map { "block \($0) (\(blockType))" } ?? blockType
        return "\(where_): \(problem)"
    }
}

extension Block.Violation.Problem: CustomStringConvertible {

    public var description: String {
        switch self {
        case .sectionHasNoContent:
            "a section needs text or fields"
        case let .tooManyFields(count, limit):
            "\(count) fields, limit \(limit)"
        case let .tooManyElements(count, limit):
            "\(count) elements, limit \(limit)"
        case let .textTooLong(field, count, limit):
            "\(field) is \(count) characters, limit \(limit)"
        case let .blockIDTooLong(count, limit):
            "block_id is \(count) characters, limit \(limit)"
        case let .tooManyBlocks(count, limit):
            "\(count) blocks, limit \(limit)"
        }
    }
}
