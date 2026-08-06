//
//  Block.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 26/11/2025.
//

import Foundation

public struct Block: Codable, Equatable, Sendable {

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
     The text for the block, in the form of a ``Block/Text``.
     Usage depends on the type of block it is in; see below sections.

     ## Section Block
     Minimum length for the text in this field is 1 and maximum length is 3000 characters.
     This field is not _required_ if a valid array of `fields` objects is provided instead.

     ## Heading Block
     Maximum length for the text in this field is 150 characters.
     The text for the block, in the form of a `plain_text` ``Block/Text``.
     */
    public var text: Text?

    /**
     Used only for Section Blocks.

     Required if no `text` is provided. An array of text elements.
     Any text objects included with `fields` will be rendered in a compact format that allows for 2 columns of side-by-side text.
     - note: Maximum length for the text in each item is 2000 characters.
     - important: Maximum number of items is 10.
     */
    public var fields: [Text]?

    /**
     Used only for Context Blocks.

     A genuinely mixed array — Slack allows text objects **and** image elements
     here, so this is `[ContextElement]` rather than `[Text]`. Decoding it as
     text-only meant one image in one context block failed the whole page.
     - important: Maximum number of items is 10.
     */
    public var elements: [ContextElement]?

    /**
     Rich-text content of a `rich_text` block — set only when
     `type == "rich_text"`. See ``Block/RichTextElement`` for the structural
     model (sections / lists / quotes / preformatted) and
     ``Block/RichTextInline`` for the leaf-node kinds (text / link / emoji /
     user / channel / broadcast / …).
     */
    public var richText: [RichTextElement]?

    /**
     Interactive elements inside an `actions` block — set only when
     `type == "actions"`. Currently models ``Block/Button``; other element
     kinds round-trip verbatim via ``Block/ActionElement/unknown(type:raw:)``.
     */
    public var actions: [ActionElement]?

    /**
     Used only for Section Blocks: one interactive or image element rendered
     beside the text (see the spec's containment table for which elements
     Slack accepts here).
     */
    public var accessory: ActionElement?

    /**
     Used only for Section Blocks: always expand the text, suppressing the
     "see more" fold on long content.
     */
    public var expand: Bool?

    /**
     Payload of an `input` block — set only when `type == "input"`.
     */
    public var input: Input?

    /// Payload of an `image` block — set only when `type == "image"`.
    public var image: ImageBlock?
    /// Payload of a `video` block — set only when `type == "video"`.
    public var video: Video?
    /// Payload of a `file` block — set only when `type == "file"`.
    public var file: FileBlock?
    /// Payload of a `markdown` block — set only when `type == "markdown"`.
    /// Its wire `text` is a raw String, so it never uses the shared `text`.
    public var markdown: Markdown?
    /// Payload of an `alert` block — set only when `type == "alert"`.
    public var alert: Alert?
    /// Payload of a `data_visualization` block — set only when
    /// `type == "data_visualization"`.
    public var dataVisualization: DataVisualization?
    /// Payload of a `table` block — set only when `type == "table"`.
    public var table: Table?
    /// Payload of a `data_table` block — set only when `type == "data_table"`.
    public var dataTable: DataTable?
    /// Payload of a `card` block — set only when `type == "card"`.
    public var card: Card?

    /**
     Used only for Header Blocks: heading level 1–4 (H1–H4).
     */
    public var level: Int?

    /**
     The complete body (minus `type`) of a block whose `type` this kit
     doesn't model — set only for unmodelled types, and re-encoded verbatim.

     Element-level `.unknown` cases weren't enough on their own: an
     unmodelled *block* used to have its unrecognised keys silently dropped
     (relaying stripped it to `{"type": …}`, which Slack rejects), and its
     `elements` array was force-decoded as `[ContextElement]`, so a foreign
     shape there threw and took the whole message down.
     */
    public var raw: [String: JSONValue]?

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
        elements: [ContextElement]? = nil,
        richText: [RichTextElement]? = nil,
        actions: [ActionElement]? = nil,
        raw: [String: JSONValue]? = nil
    ) {
        self.type = type
        self.block_id = block_id
        self.text = text
        self.fields = fields
        self.elements = elements
        self.richText = richText
        self.actions = actions
        self.raw = raw
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
    public static func header(_ text: String, showEmojis: Bool = true, level: Int? = nil) -> Block {
        let text = Text(plain: text, emoji: showEmojis)
        var block = Block(type: BlockType.header.rawValue, text: text)
        block.level = level
        return block
    }
    /**
     Displays text, possibly alongside elements.

     ## Available in Surfaces
     - Modals
     - Messages
     - Home tabs

     - note: Maximum length for the text in this field is 3000 characters.
     */
    public static func section(_ text: String, verbatim: Bool = false, accessory: ActionElement? = nil) -> Block {
        let text = Text(text, verbatim: verbatim)
        var block = Block(type: BlockType.section.rawValue, text: text)
        block.accessory = accessory
        return block
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
        let elements = items.map { ContextElement.text(Text($0)) }
        return .init(type: BlockType.context.rawValue, elements: elements)
    }

    /**
     Context strip over mixed elements — text and images together
     (e.g. an avatar beside a caption).

     ## Available in Surfaces
     - Modals
     - Messages
     - Home tabs

     - note: Maximum number of elements is 10.
     */
    public static func context(_ elements: [ContextElement]) -> Block {
        .init(type: BlockType.context.rawValue, elements: elements)
    }

    /**
     Holds up to 25 interactive elements — buttons, selects, pickers,
     checkboxes, radio buttons, overflow menus.

     ## Available in Surfaces
     - Modals
     - Messages
     - Home tabs
     */
    public static func actions(_ elements: [ActionElement]) -> Block {
        .init(type: "actions", actions: elements)
    }

    //--------------------------------------
    // MARK: - CODABLE -
    //--------------------------------------
    /**
     Strict, type-dispatched decode. The shape of the `elements`
     array depends on the block's `type`:

     - `rich_text` → `[RichTextElement]` (lists, quotes, inline runs).
     - `actions`   → `[ActionElement]` (buttons + other interactives).
     - all other types (section / header / context / …) → `[ContextElement]`
       (text objects and image elements, mixed), as documented.

     Unmodelled `type` values still decode — their whole body is captured
     in ``raw`` and re-encoded verbatim, and none of their fields are
     force-decoded as modelled shapes, so a future Slack block kind never
     blows up the surrounding message *and* never loses content on relay.

     This is the **only** serialiser. Outgoing bodies are built by
     `JSONEncoder` over these same conformances, so what a block decodes to and
     what it posts as cannot disagree.
     */
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try c.decode(String.self, forKey: .type)

        guard Block.modelledTypes.contains(self.type) else {
            let body = try JSONValue(from: decoder).objectDropping(["type"])
            self.raw      = body
            // Convenience accessor only — the encoded block_id comes from `raw`.
            if case let .string(id) = body["block_id"] { self.block_id = id }
            return
        }

        self.block_id  = try c.decodeIfPresent(String.self, forKey: .block_id)
        // `markdown` (raw String) and `alert` (family-owned text object)
        // own the `text` key themselves; the shared decode must not touch it
        // there or the same key populates two properties.
        if self.type != "markdown", self.type != "alert" {
            self.text  = try c.decodeIfPresent(Text.self,   forKey: .text)
        }
        self.fields    = try c.decodeIfPresent([Text].self, forKey: .fields)
        self.accessory = try c.decodeIfPresent(ActionElement.self, forKey: .accessory)
        self.expand    = try c.decodeIfPresent(Bool.self, forKey: .expand)
        if self.type == BlockType.header.rawValue {
            self.level = try c.decodeIfPresent(Int.self, forKey: .level)
        }

        switch self.type {
        case "rich_text":
            self.richText = try c.decodeIfPresent([RichTextElement].self, forKey: .elements)
        case "actions":
            self.actions  = try c.decodeIfPresent([ActionElement].self, forKey: .elements)
        case "input":
            self.input    = try Input(from: decoder)
        case "image":
            self.image    = try ImageBlock(from: decoder)
        case "video":
            self.video    = try Video(from: decoder)
        case "file":
            self.file     = try FileBlock(from: decoder)
        case "markdown":
            self.markdown = try Markdown(from: decoder)
        case "alert":
            self.alert    = try Alert(from: decoder)
        case "data_visualization":
            self.dataVisualization = try DataVisualization(from: decoder)
        case "table":
            self.table    = try Table(from: decoder)
        case "data_table":
            self.dataTable = try DataTable(from: decoder)
        case "card":
            self.card     = try Card(from: decoder)
        default:
            self.elements = try c.decodeIfPresent([ContextElement].self, forKey: .elements)
        }
    }

    public func encode(to encoder: Encoder) throws {
        if let raw {
            var fields = raw
            fields["type"] = .string(type)
            try JSONValue.object(fields).encode(to: encoder)
            return
        }

        // Flattened families write their fields into the same encoder first;
        // `Block` still owns `type` and `block_id`.
        try input?.encode(to: encoder)
        try image?.encode(to: encoder)
        try video?.encode(to: encoder)
        try file?.encode(to: encoder)
        try markdown?.encode(to: encoder)
        try alert?.encode(to: encoder)
        try dataVisualization?.encode(to: encoder)
        try table?.encode(to: encoder)
        try dataTable?.encode(to: encoder)
        try card?.encode(to: encoder)

        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(block_id,  forKey: .block_id)
        try c.encodeIfPresent(text,      forKey: .text)
        try c.encodeIfPresent(fields,    forKey: .fields)
        try c.encodeIfPresent(accessory, forKey: .accessory)
        try c.encodeIfPresent(expand,    forKey: .expand)
        try c.encodeIfPresent(level,     forKey: .level)

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
        case type, block_id, text, fields, elements, accessory, expand, level
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
            parts.append(elements.map(\.plainText).filter { !$0.isEmpty }.joined(separator: " "))
        }
        if let richText, !richText.isEmpty {
            parts.append(richText.map(\.plainText).joined(separator: "\n"))
        }
        if let actions, !actions.isEmpty {
            let buttons: [String] = actions.compactMap { element in
                guard case let .button(button) = element else { return nil }
                let label = button.text?.text ?? "Button"
                if let url = button.url { return "\(label) → \(url)" }
                return label
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

    /**
     The block `type` strings this kit decodes into typed fields. Anything
     else takes the ``raw`` passthrough path. Every new family the kit
     learns must be added here in the same change that models it — a type
     listed here but not dispatched decodes to an empty block.
     */
    internal static let modelledTypes: Set<String> = [
        BlockType.divider.rawValue,
        BlockType.header.rawValue,
        BlockType.section.rawValue,
        BlockType.context.rawValue,
        "rich_text",
        "actions",
        "input",
        "image",
        "video",
        "file",
        "markdown",
        "alert",
        "data_visualization",
        "table",
        "data_table",
        "card",
    ]
}
