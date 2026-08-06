//
//  Input.swift
//  SlackKit
//
//  The `input` block family — collects a value from a user via one
//  interactive element.
//
//  Spec: docs/systems/comms/blockkit-spec-2026-08.md §1 `input`.
//

import Foundation

extension Block {

    /**
     Payload of an `input` block (`type == "input"`), a flattened family:
     these fields sit top-level on the block; `Block` owns `type`/`block_id`.

     ## Available in Surfaces
     - Modals
     - Home tabs

     Not valid in messages (D9: documented, Slack-enforced).
     */
    public struct Input: Codable, Equatable, Sendable {

        /// `plain_text` only; max 2000.
        public var label: Text
        /// The collecting element — text inputs, selects, pickers,
        /// checkboxes or radio buttons (see spec §4 containment).
        public var element: ActionElement
        /// Dispatch a `block_actions` payload on interaction. Default `false`;
        /// incompatible with a `file_input` element.
        public var dispatch_action: Bool?
        /// `plain_text` only; max 2000.
        public var hint: Text?
        /// Whether the element may be empty on modal submit. Default `false`.
        public var optional: Bool?

        public init(label: String, element: ActionElement, hint: String? = nil, optional: Bool? = nil, dispatchAction: Bool? = nil) {
            self.label = Text(plain: label)
            self.element = element
            self.dispatch_action = dispatchAction
            self.hint = hint.map { Text(plain: $0) }
            self.optional = optional
        }

        private enum CodingKeys: String, CodingKey {
            case label, element, dispatch_action, hint, optional
        }
    }

    /**
     Collects information from a user via one element.

     ## Available in Surfaces
     - Modals
     - Home tabs
     */
    public static func input(label: String, element: ActionElement, hint: String? = nil, optional: Bool? = nil, dispatchAction: Bool? = nil) -> Block {
        var block = Block(type: "input")
        block.input = Input(label: label, element: element, hint: hint, optional: optional, dispatchAction: dispatchAction)
        return block
    }
}
