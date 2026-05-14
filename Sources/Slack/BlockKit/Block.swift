//
//  Block.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 26/11/2025.
//

import Foundation

public struct Block: Codable, Equatable {

    //--------------------------------------
    // MARK: - VARIABLES -
    //--------------------------------------
    public let type: String
    /**
     A unique identifier for a block.
     
     If not specified, one will be generated.
     You can use this `block_id` when you receive an interaction payload to identify the source of the action.
     
     - note: Maximum length for this field is 255 characters.
     
     `block_id` should be unique for each message and each iteration of a message.
     If a message is updated, use a new `block_id`.
     */
    public var block_id: String?
    
    /**
     The text for the block, in the form of a ``Block.Text``.
     Usage depends on the type of block it is in; see below sections.
     
     ## Section Block
     Minimum length for the text in this field is 1 and maximum length is 3000 characters.
     This field is not _required_ if a valid array of `fields` objects is provided instead.
     
     ## Heading Block
     Maximum length for the text in this field is 150 characters.
     The text for the block, in the form of a `plain_text` ``Block.Text``.
     */
    public var text: Text?
    
    
    
    /**
     Used only for Section Blocks.
     
     Required if no `text` is provided. An array of text elements.
     Any text objects included with `fields` will be rendered in a compact format that allows for 2 columns of side-by-side text.
     - note: Maximum length for the text in each item is 2000 characters.
     - important: Maximum number of items is 10.
     
     [Click here for an example.](https://api.slack.com/tools/block-kit-builder?blocks=%5B%0A%09%7B%0A%09%09%22type%22%3A%20%22section%22%2C%0A%09%09%22text%22%3A%20%7B%0A%09%09%09%22text%22%3A%20%22A%20message%20*with%20some%20bold%20text*%20and%20_some%20italicized%20text_.%22%2C%0A%09%09%09%22type%22%3A%20%22mrkdwn%22%0A%09%09%7D%2C%0A%09%09%22fields%22%3A%20%5B%0A%09%09%09%7B%0A%09%09%09%09%22type%22%3A%20%22mrkdwn%22%2C%0A%09%09%09%09%22text%22%3A%20%22*Priority*%22%0A%09%09%09%7D%2C%0A%09%09%09%7B%0A%09%09%09%09%22type%22%3A%20%22mrkdwn%22%2C%0A%09%09%09%09%22text%22%3A%20%22*Type*%22%0A%09%09%09%7D%2C%0A%09%09%09%7B%0A%09%09%09%09%22type%22%3A%20%22plain_text%22%2C%0A%09%09%09%09%22text%22%3A%20%22High%22%0A%09%09%09%7D%2C%0A%09%09%09%7B%0A%09%09%09%09%22type%22%3A%20%22plain_text%22%2C%0A%09%09%09%09%22text%22%3A%20%22String%22%0A%09%09%09%7D%0A%09%09%5D%0A%09%7D%0A%5D)
     */
    public var fields: [Text]?

    /**
     Used only for Context Blocks.

     A mixed-element array. The current builder accepts mrkdwn strings;
     image element support can be added later if needed.
     - important: Maximum number of items is 10.
     */
    public var elements: [Text]?

    /**
     Rich-text content of a `rich_text` block — set only when
     `type == "rich_text"`. See `RichTextElement` for the structural
     model (sections / lists / quotes / preformatted) and
     `RichTextInline` for the leaf-node kinds (text / link / emoji /
     user / channel / broadcast / …).
     */
    public var richText: [RichTextElement]?

    /**
     Interactive elements inside an `actions` block — set only when
     `type == "actions"`. Currently models `Button`; other element
     kinds surface as `.unknown(type:)`.
     */
    public var actions: [ActionElement]?

    //--------------------------------------
    // MARK: - INIT -
    //--------------------------------------
    /// Memberwise init. Restored explicitly because the custom
    /// `init(from:)` below suppresses synthesis. Used by the static
    /// `.divider` / `.header(_:)` / `.section(_:)` / `.context(_:)`
    /// builders to construct outgoing blocks.
    public init(
        type: String,
        block_id: String? = nil,
        text: Text? = nil,
        fields: [Text]? = nil,
        elements: [Text]? = nil,
        richText: [RichTextElement]? = nil,
        actions: [ActionElement]? = nil
    ) {
        self.type = type
        self.block_id = block_id
        self.text = text
        self.fields = fields
        self.elements = elements
        self.richText = richText
        self.actions = actions
    }

    //--------------------------------------
    // MARK: - BLOCK BUILDERS -
    //--------------------------------------
    /**
     Visually separates pieces of info inside of a message.
     
     ## Available in Surfaces
     - Modals
     - Messages
     - Home tabs
     */
    public static var divider: Block { .init(type: BlockType.divider.rawValue) }
    
    /**
     Displays a larger-sized text.
     
     ## Available in Surfaces
     - Modals
     - Messages
     - Home tabs
     
     - note: Maximum length for the text in this field is 150 characters.
     */
    public static func header(_ text: String, showEmojis: Bool = true) -> Block {
        let text = Text(plain: text, emoji: showEmojis)
        return .init(type: BlockType.header.rawValue, text: text)
    }
    /**
     Displays text, possibly alongside elements.
     
     ## Available in Surfaces
     - Modals
     - Messages
     - Home tabs
     
     ## Compatible Block Elements
     - Button
     - Checkboxes
     - Date picker
     - Image
     - Multi-select menus
     - Overflow menu
     - Radio button
     - Select menu
     - Time picker
     - Workflow buttons
     
     - note: Maximum length for the text in this field is 3000 characters.
     */
    public static func section(_ text: String, verbatim: Bool = false) -> Block {
        let text = Text(text, verbatim: verbatim)
        return .init(type: BlockType.section.rawValue, text: text)
    }

    /**
     Displays one or more mrkdwn elements rendered as a context strip —
     smaller font, secondary colour. Useful for footers / hints that
     shouldn't compete with the main message body.

     ## Available in Surfaces
     - Modals
     - Messages
     - Home tabs

     - note: Maximum number of elements is 10.
     */
    public static func context(_ items: [String]) -> Block {
        let elements = items.map { Text($0) }
        return .init(type: BlockType.context.rawValue, elements: elements)
    }

    //--------------------------------------
    // MARK: - JSON -
    //--------------------------------------
    public var json: [String : Sendable] {
        var dict: [String: Sendable] = ["type": type]

        if let text { dict["text"] = text.json }
        if let fields { dict["fields"] = fields.map(\.json) }
        if let elements { dict["elements"] = elements.map(\.json) }

        if let block_id { dict["block_id"] = block_id }
        return dict
    }

    //--------------------------------------
    // MARK: - CODABLE -
    //--------------------------------------
    /**
     Strict, type-dispatched decode. The shape of the `elements`
     array depends on the block's `type`:

     - `rich_text` → `[RichTextElement]` (lists, quotes, inline runs).
       Modelled by `RichTextElement` / `RichTextInline`.
     - `actions`   → `[ActionElement]` (buttons + other interactives).
       Modelled by `ActionElement` / `Button`.
     - all other types (section / header / context / …) → `[Text]`,
       as documented.

     Unknown `type` values still decode (we capture the raw type
     string and leave the type-specific fields nil) so a future Slack
     block kind never blows up the surrounding message.
     */
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.type     = try c.decode(String.self, forKey: .type)
        self.block_id = try c.decodeIfPresent(String.self, forKey: .block_id)
        self.text     = try c.decodeIfPresent(Text.self,   forKey: .text)
        self.fields   = try c.decodeIfPresent([Text].self, forKey: .fields)

        switch self.type {
        case "rich_text":
            self.richText = try c.decodeIfPresent([RichTextElement].self, forKey: .elements)
            self.elements = nil
            self.actions  = nil
        case "actions":
            self.actions  = try c.decodeIfPresent([ActionElement].self, forKey: .elements)
            self.elements = nil
            self.richText = nil
        default:
            self.elements = try c.decodeIfPresent([Text].self, forKey: .elements)
            self.richText = nil
            self.actions  = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(block_id, forKey: .block_id)
        try c.encodeIfPresent(text,     forKey: .text)
        try c.encodeIfPresent(fields,   forKey: .fields)

        switch type {
        case "rich_text":
            try c.encodeIfPresent(richText, forKey: .elements)
        case "actions":
            try c.encodeIfPresent(actions,  forKey: .elements)
        default:
            try c.encodeIfPresent(elements, forKey: .elements)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, block_id, text, fields, elements
    }

    //--------------------------------------
    // MARK: - PLAIN TEXT -
    //--------------------------------------
    /**
     Best-effort flat-text rendering of this block. Section/header
     blocks return their `text`/`fields`; rich-text blocks recurse
     through the structured content; actions blocks list their
     buttons. Suitable for `Text(LocalizedStringKey(_:))` since the
     emitted markers are CommonMark-compatible.
     */
    public var plainText: String {
        var parts: [String] = []
        if let text { parts.append(text.text) }
        if let fields, !fields.isEmpty {
            parts.append(fields.map(\.text).joined(separator: "  "))
        }
        if let elements, !elements.isEmpty {
            parts.append(elements.map(\.text).joined(separator: " "))
        }
        if let richText, !richText.isEmpty {
            parts.append(richText.map(\.plainText).joined(separator: "\n"))
        }
        if let actions, !actions.isEmpty {
            let buttons: [String] = actions.compactMap { element in
                if case let .button(button) = element {
                    let label = button.text?.text ?? "Button"
                    if let url = button.url { return "\(label) → \(url)" }
                    return label
                }
                return nil
            }
            if !buttons.isEmpty { parts.append(buttons.joined(separator: "\n")) }
        }
        return parts.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    //--------------------------------------
    // MARK: - HELPERS -
    //--------------------------------------
    internal enum BlockType: String {
        case divider
        case header
        case section
        case context
    }
}
