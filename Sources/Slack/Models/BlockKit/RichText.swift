//
//  RichText.swift
//  SlackKit
//
//  Models for Slack's `rich_text` Block content — the structured
//  representation of formatted message text (bold/italic/lists/quotes
//  /code blocks/mentions/emoji/etc.) that Slack ships in
//  conversations.history responses.
//
//  Spec: https://api.slack.com/reference/block-kit/blocks#rich_text
//

import Foundation

extension Block {

    //--------------------------------------
    // MARK: - RICH TEXT ELEMENT -
    //--------------------------------------
    /**
     One element inside a `rich_text` Block. Rich-text blocks group
     inline content (`RichTextInline`) into four structural kinds:

     - `section`      — paragraph-like run of inline content
     - `list`         — bullet / ordered list of sections
     - `quote`        — blockquote (`> …`)
     - `preformatted` — code block (` ```…``` `)
     */
    public enum RichTextElement: Codable, Equatable, Sendable {
        case section([RichTextInline])
        case list(style: ListStyle, indent: Int?, items: [RichTextElement])
        case quote([RichTextInline])
        case preformatted([RichTextInline])

        public enum ListStyle: String, Codable, Sendable {
            case bullet
            case ordered
        }

        private enum CodingKeys: String, CodingKey {
            case type, elements, style, indent
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type = try c.decode(String.self, forKey: .type)
            switch type {
            case "rich_text_section":
                let elements = (try? c.decode([RichTextInline].self, forKey: .elements)) ?? []
                self = .section(elements)
            case "rich_text_quote":
                let elements = (try? c.decode([RichTextInline].self, forKey: .elements)) ?? []
                self = .quote(elements)
            case "rich_text_preformatted":
                let elements = (try? c.decode([RichTextInline].self, forKey: .elements)) ?? []
                self = .preformatted(elements)
            case "rich_text_list":
                let style  = (try? c.decode(ListStyle.self, forKey: .style)) ?? .bullet
                let indent = try? c.decodeIfPresent(Int.self, forKey: .indent)
                let items  = (try? c.decode([RichTextElement].self, forKey: .elements)) ?? []
                self = .list(style: style, indent: indent, items: items)
            default:
                // Unknown rich_text_* kind — preserve a sentinel so
                // the surrounding decode still succeeds.
                self = .section([])
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .section(let elements):
                try c.encode("rich_text_section", forKey: .type)
                try c.encode(elements, forKey: .elements)
            case .quote(let elements):
                try c.encode("rich_text_quote", forKey: .type)
                try c.encode(elements, forKey: .elements)
            case .preformatted(let elements):
                try c.encode("rich_text_preformatted", forKey: .type)
                try c.encode(elements, forKey: .elements)
            case .list(let style, let indent, let items):
                try c.encode("rich_text_list", forKey: .type)
                try c.encode(style, forKey: .style)
                if let indent { try c.encode(indent, forKey: .indent) }
                try c.encode(items, forKey: .elements)
            }
        }

        /// Best-effort flat-text rendering of this element. List items
        /// get bullet/number prefixes, quotes get `> `, code blocks
        /// get triple-backtick fences.
        public var plainText: String {
            switch self {
            case .section(let inlines):
                return inlines.map(\.plainText).joined()
            case .quote(let inlines):
                return "> " + inlines.map(\.plainText).joined()
            case .preformatted(let inlines):
                return "```\n" + inlines.map(\.plainText).joined() + "\n```"
            case .list(let style, _, let items):
                let bullet = style == .bullet ? "•" : "1."
                return items
                    .map { "\(bullet) \($0.plainText)" }
                    .joined(separator: "\n")
            }
        }
    }

    //--------------------------------------
    // MARK: - RICH TEXT INLINE -
    //--------------------------------------
    /**
     Leaf-node element inside a `RichTextElement`. Covers every inline
     kind Slack ships: styled text, links, emoji, user/channel/group
     mentions, broadcast pings, dates, and colours. Unknown shapes
     decode as `.other` so the surrounding block still survives.
     */
    public enum RichTextInline: Codable, Equatable, Sendable {
        case text(String, style: Style?)
        case link(url: String, text: String?, style: Style?)
        case emoji(name: String, unicode: String?)
        case user(id: String, style: Style?)
        case channel(id: String, style: Style?)
        case usergroup(id: String, style: Style?)
        case broadcast(range: String)  // "here" / "channel" / "everyone"
        case date(timestamp: Int, format: String?, fallback: String?)
        case color(value: String)
        case other

        public struct Style: Codable, Equatable, Sendable {
            public var bold:   Bool?
            public var italic: Bool?
            public var strike: Bool?
            public var code:   Bool?
        }

        private enum CodingKeys: String, CodingKey {
            case type, text, url, name, unicode
            case user_id, channel_id, usergroup_id
            case range, timestamp, format, fallback, value, style
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type  = (try? c.decode(String.self, forKey: .type)) ?? ""
            let style = try? c.decodeIfPresent(Style.self, forKey: .style)
            switch type {
            case "text":
                self = .text(
                    (try? c.decode(String.self, forKey: .text)) ?? "",
                    style: style
                )
            case "link":
                self = .link(
                    url:   (try? c.decode(String.self, forKey: .url)) ?? "",
                    text:  try? c.decodeIfPresent(String.self, forKey: .text),
                    style: style
                )
            case "emoji":
                self = .emoji(
                    name:    (try? c.decode(String.self, forKey: .name)) ?? "",
                    unicode: try? c.decodeIfPresent(String.self, forKey: .unicode)
                )
            case "user":
                self = .user(
                    id: (try? c.decode(String.self, forKey: .user_id)) ?? "",
                    style: style
                )
            case "channel":
                self = .channel(
                    id: (try? c.decode(String.self, forKey: .channel_id)) ?? "",
                    style: style
                )
            case "usergroup":
                self = .usergroup(
                    id: (try? c.decode(String.self, forKey: .usergroup_id)) ?? "",
                    style: style
                )
            case "broadcast":
                self = .broadcast(
                    range: (try? c.decode(String.self, forKey: .range)) ?? ""
                )
            case "date":
                self = .date(
                    timestamp: (try? c.decode(Int.self, forKey: .timestamp)) ?? 0,
                    format:    try? c.decodeIfPresent(String.self, forKey: .format),
                    fallback:  try? c.decodeIfPresent(String.self, forKey: .fallback)
                )
            case "color":
                self = .color(
                    value: (try? c.decode(String.self, forKey: .value)) ?? ""
                )
            default:
                self = .other
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let s, let style):
                try c.encode("text", forKey: .type)
                try c.encode(s, forKey: .text)
                if let style { try c.encode(style, forKey: .style) }
            case .link(let url, let text, let style):
                try c.encode("link", forKey: .type)
                try c.encode(url, forKey: .url)
                if let text  { try c.encode(text,  forKey: .text)  }
                if let style { try c.encode(style, forKey: .style) }
            case .emoji(let name, let unicode):
                try c.encode("emoji", forKey: .type)
                try c.encode(name, forKey: .name)
                if let unicode { try c.encode(unicode, forKey: .unicode) }
            case .user(let id, let style):
                try c.encode("user", forKey: .type)
                try c.encode(id, forKey: .user_id)
                if let style { try c.encode(style, forKey: .style) }
            case .channel(let id, let style):
                try c.encode("channel", forKey: .type)
                try c.encode(id, forKey: .channel_id)
                if let style { try c.encode(style, forKey: .style) }
            case .usergroup(let id, let style):
                try c.encode("usergroup", forKey: .type)
                try c.encode(id, forKey: .usergroup_id)
                if let style { try c.encode(style, forKey: .style) }
            case .broadcast(let range):
                try c.encode("broadcast", forKey: .type)
                try c.encode(range, forKey: .range)
            case .date(let ts, let format, let fallback):
                try c.encode("date", forKey: .type)
                try c.encode(ts, forKey: .timestamp)
                if let format   { try c.encode(format,   forKey: .format)   }
                if let fallback { try c.encode(fallback, forKey: .fallback) }
            case .color(let value):
                try c.encode("color", forKey: .type)
                try c.encode(value, forKey: .value)
            case .other:
                try c.encode("text", forKey: .type)
                try c.encode("", forKey: .text)
            }
        }

        /// Markdown-friendly flat string. Style flags become CommonMark
        /// markers so the result renders nicely via SwiftUI's
        /// `LocalizedStringKey`.
        public var plainText: String {
            switch self {
            case .text(let s, let style):
                return Self.style(s, with: style)
            case .link(let url, let text, _):
                let label = text?.isEmpty == false ? text! : url
                return "[\(label)](\(url))"
            case .emoji(let name, _):
                return ":\(name):"
            case .user(let id, _):
                return "@\(id)"
            case .channel(let id, _):
                return "#\(id)"
            case .usergroup(let id, _):
                return "@\(id)"
            case .broadcast(let range):
                return "@\(range)"
            case .date(_, _, let fallback):
                return fallback ?? ""
            case .color(let value):
                return value
            case .other:
                return ""
            }
        }

        private static func style(_ s: String, with style: Style?) -> String {
            guard let style else { return s }
            var out = s
            if style.code   == true { out = "`\(out)`" }
            if style.bold   == true { out = "**\(out)**" }
            if style.italic == true { out = "_\(out)_" }
            if style.strike == true { out = "~~\(out)~~" }
            return out
        }
    }
}
