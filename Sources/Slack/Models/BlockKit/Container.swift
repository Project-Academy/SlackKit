//
//  Container.swift
//  SlackKit
//
//  The `carousel` and `container` block families — the two blocks that
//  nest other block content.
//
//  Spec: docs/systems/comms/blockkit-spec-2026-08.md §1.
//

import Foundation

extension Block {

    /**
     Payload of a `container` block — wraps up to 10 child blocks with a
     header, optional icon, sizing and collapsibility. One of `title` /
     `rich_text_title` is required by Slack (`rich_text_title` wins when
     both are given).

     Supported child block types per the docs: actions, context, divider,
     file, header, image, input, rich_text, section, table, video.
     */
    public struct Container: Codable, Equatable, Sendable {

        /// `plain_text`; max 150. Required unless `rich_text_title` is set.
        public var title: String?
        /**
         Rich-text title content; takes precedence over `title`.

         On the wire this is a whole `rich_text` *block* — the envelope is
         added and stripped in this struct's Codable so the stored value can
         be the content itself (storing a `Block` here would recurse
         `Block → Container → Block` inline, which Swift value types forbid).
         */
        public var rich_text_title: [RichTextElement]?
        /// `plain_text` or `mrkdwn`; max 150.
        public var subtitle: String?
        /// Max 10 blocks.
        public var child_blocks: [Block]
        /// `narrow` / `standard` / `wide` (platform-constrained) or `full`.
        public var width: Width?
        public var icon: ImageElement?
        /// Default `false`.
        public var is_collapsible: Bool?
        /// Default `false`; effective only with `is_collapsible: true`.
        public var default_collapsed: Bool?
        /// Default `false`; only applies when not collapsible.
        public var has_header_divider: Bool?

        public init(
            title: String? = nil,
            richTextTitle: [RichTextElement]? = nil,
            subtitle: String? = nil,
            blocks: [Block],
            width: Width? = nil,
            icon: ImageElement? = nil,
            isCollapsible: Bool? = nil,
            defaultCollapsed: Bool? = nil,
            hasHeaderDivider: Bool? = nil
        ) {
            self.title = title
            self.rich_text_title = richTextTitle
            self.subtitle = subtitle
            self.child_blocks = blocks
            self.width = width
            self.icon = icon
            self.is_collapsible = isCollapsible
            self.default_collapsed = defaultCollapsed
            self.has_header_divider = hasHeaderDivider
        }

        /// Tolerant like ``Block/Style``: an unlisted value decodes rather than throws.
        public struct Width: RawRepresentable, Codable, Equatable, Sendable {
            public let rawValue: String
            public init(rawValue: String) { self.rawValue = rawValue }

            public static let narrow = Width(rawValue: "narrow")
            public static let standard = Width(rawValue: "standard")
            public static let wide = Width(rawValue: "wide")
            public static let full = Width(rawValue: "full")
        }

        private enum CodingKeys: String, CodingKey {
            case title, rich_text_title, subtitle, child_blocks, width, icon, is_collapsible, default_collapsed, has_header_divider
        }

        /// The wire form of `rich_text_title`: a full `rich_text` block.
        private struct RichTextEnvelope: Codable {
            var type: String
            var elements: [RichTextElement]
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.title = try c.decodeIfPresent(String.self, forKey: .title)
            self.rich_text_title = try c.decodeIfPresent(RichTextEnvelope.self, forKey: .rich_text_title)?.elements
            self.subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
            self.child_blocks = try c.decode([Block].self, forKey: .child_blocks)
            self.width = try c.decodeIfPresent(Width.self, forKey: .width)
            self.icon = try c.decodeIfPresent(ImageElement.self, forKey: .icon)
            self.is_collapsible = try c.decodeIfPresent(Bool.self, forKey: .is_collapsible)
            self.default_collapsed = try c.decodeIfPresent(Bool.self, forKey: .default_collapsed)
            self.has_header_divider = try c.decodeIfPresent(Bool.self, forKey: .has_header_divider)
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encodeIfPresent(title, forKey: .title)
            try c.encodeIfPresent(rich_text_title.map { RichTextEnvelope(type: "rich_text", elements: $0) }, forKey: .rich_text_title)
            try c.encodeIfPresent(subtitle, forKey: .subtitle)
            try c.encode(child_blocks, forKey: .child_blocks)
            try c.encodeIfPresent(width, forKey: .width)
            try c.encodeIfPresent(icon, forKey: .icon)
            try c.encodeIfPresent(is_collapsible, forKey: .is_collapsible)
            try c.encodeIfPresent(default_collapsed, forKey: .default_collapsed)
            try c.encodeIfPresent(has_header_divider, forKey: .has_header_divider)
        }
    }

    /**
     Wraps child blocks in a titled, optionally collapsible container.

     ## Available in Surfaces
     - Messages
     */
    public static func container(_ container: Container) -> Block {
        var block = Block(type: "container")
        block.container = container
        return block
    }

    /**
     Displays related cards in a horizontally-scrolling container.
     The cards ride the shared `elements` wire key.

     ## Available in Surfaces
     - Messages

     - note: 1–10 cards.
     */
    public static func carousel(_ cards: [Card]) -> Block {
        var block = Block(type: "carousel")
        block.cards = cards
        return block
    }
}
