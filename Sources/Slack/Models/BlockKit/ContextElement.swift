//
//  ContextElement.swift
//  SlackKit
//
//  Elements inside a `context` block.
//
//  Slack allows a *mixed* array here: text objects and image elements. Decoding
//  the array as `[Block.Text]` meant a single context block containing an image
//  — which any app is free to post — failed to decode, and took the entire
//  `conversations.history` page down with it.
//
//  Spec: https://api.slack.com/reference/block-kit/blocks#context
//

import Foundation

extension Block {

    public enum ContextElement: Codable, Equatable, Sendable {

        case text(Text)
        case image(url: String, altText: String?)
        /// Any element kind this kit doesn't model, kept verbatim.
        case unknown(type: String, raw: [String: JSONValue])

        private enum CodingKeys: String, CodingKey {
            case type, image_url, alt_text
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type = try c.decode(String.self, forKey: .type)
            switch type {
            case Text.TextType.markdown.rawValue, Text.TextType.plainText.rawValue:
                self = .text(try Text(from: decoder))
            case "image":
                self = .image(
                    url: try c.decode(String.self, forKey: .image_url),
                    altText: try c.decodeIfPresent(String.self, forKey: .alt_text)
                )
            default:
                let raw = try JSONValue(from: decoder)
                self = .unknown(type: type, raw: raw.objectDropping(["type"]))
            }
        }

        public func encode(to encoder: Encoder) throws {
            switch self {
            case let .text(text):
                // `Text` writes its own `type` (mrkdwn / plain_text).
                try text.encode(to: encoder)

            case let .image(url, altText):
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode("image", forKey: .type)
                try c.encode(url, forKey: .image_url)
                // Slack requires alt_text on image elements; default rather
                // than emit a block it will reject.
                try c.encode(altText ?? "", forKey: .alt_text)

            case let .unknown(type, raw):
                var fields = raw
                fields["type"] = .string(type)
                try JSONValue.object(fields).encode(to: encoder)
            }
        }

        /// Flat-text rendering. Images contribute their alt text, which is the
        /// only part of them a reader can be given as words.
        public var plainText: String {
            switch self {
            case let .text(text):        return text.text
            case let .image(_, altText): return altText ?? ""
            case .unknown:               return ""
            }
        }
    }
}
