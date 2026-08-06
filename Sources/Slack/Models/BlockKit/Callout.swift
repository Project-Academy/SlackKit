//
//  Callout.swift
//  SlackKit
//
//  The `callout` and `contact_card` block families.
//
//  Neither appears in Slack's Block Kit reference index as of 2026-08-06 —
//  both were found in a live Block Kit Builder payload. Fields here are
//  modelled from that payload, so treat the field list as observed rather
//  than specified: anything Slack sends beyond it is preserved by the
//  unknown-field passthrough in `Block`, not lost.
//

import Foundation

extension Block {

    /**
     Payload of a `callout` block — a coloured panel wrapping child blocks.

     Structurally a sibling of ``Block/Container``: the children ride
     `child_blocks`, and the observed payload nests rich text, dividers,
     sections, images and contact cards inside one.
     */
    public struct Callout: Codable, Equatable, Sendable {

        /// Panel tint. Observed: `green`. Modelled as a tolerant string
        /// because the full palette isn't documented anywhere.
        public var background_color: BackgroundColor?
        public var child_blocks: [Block]

        public init(backgroundColor: BackgroundColor? = nil, blocks: [Block]) {
            self.background_color = backgroundColor
            self.child_blocks = blocks
        }

        /// Tolerant like ``Block/Style``: an unlisted value decodes rather
        /// than throws. Only `green` has been observed; the others are
        /// unverified guesses and deliberately not offered as statics.
        public struct BackgroundColor: RawRepresentable, Codable, Equatable, Sendable {
            public let rawValue: String
            public init(rawValue: String) { self.rawValue = rawValue }

            public static let green = BackgroundColor(rawValue: "green")
        }

        private enum CodingKeys: String, CodingKey {
            case background_color, child_blocks
        }
    }

    /**
     Payload of a `contact_card` block — renders a workspace user as a card.

     Observed only as a child of a `callout`, carrying just the user ID.
     */
    public struct ContactCard: Codable, Equatable, Sendable {

        public var contact_user_id: String

        public init(userID: String) { self.contact_user_id = userID }

        private enum CodingKeys: String, CodingKey {
            case contact_user_id
        }
    }

    /**
     Wraps child blocks in a coloured callout panel.

     ## Available in Surfaces
     - Messages (offered by Block Kit Builder in message preview)

     - note: Undocumented in Slack's block reference; see ``Block/Callout``.
     */
    public static func callout(backgroundColor: Callout.BackgroundColor? = nil, blocks: [Block]) -> Block {
        var block = Block(type: "callout")
        block.callout = Callout(backgroundColor: backgroundColor, blocks: blocks)
        return block
    }

    /**
     Displays a workspace user as a contact card.

     - note: Undocumented in Slack's block reference; see ``Block/ContactCard``.
     */
    public static func contactCard(userID: String) -> Block {
        var block = Block(type: "contact_card")
        block.contactCard = ContactCard(userID: userID)
        return block
    }
}
