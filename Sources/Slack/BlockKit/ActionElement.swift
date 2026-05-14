//
//  ActionElement.swift
//  SlackKit
//
//  Models for the elements that appear inside an `actions` Block.
//  Slack supports many interactive element types (button, select,
//  datepicker, overflow, etc.); the current model is `Button` plus
//  an explicit `.unknown(type:)` case for shapes we haven't wired up.
//
//  Spec: https://api.slack.com/reference/block-kit/block-elements
//

import Foundation

extension Block {

    /**
     One element inside an `actions` Block.
     Model is intentionally non-exhaustive — interactive element
     types are added on demand. Unknown ones are surfaced via
     `.unknown(type:)` so the surrounding block decode stays strict
     instead of silently dropping data.
     */
    public enum ActionElement: Codable, Equatable, Sendable {
        case button(Button)
        case unknown(type: String)

        private enum CodingKeys: String, CodingKey {
            case type
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type = try c.decode(String.self, forKey: .type)
            switch type {
            case "button":
                self = .button(try Button(from: decoder))
            default:
                self = .unknown(type: type)
            }
        }

        public func encode(to encoder: Encoder) throws {
            switch self {
            case .button(let button):
                try button.encode(to: encoder)
            case .unknown(let type):
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(type, forKey: .type)
            }
        }
    }

    /**
     `actions`-block button element. Carries the visible label, the
     URL (if it's a link-button), the developer-specified action id,
     and an arbitrary payload value.
     */
    public struct Button: Codable, Equatable, Sendable {
        public var text: Text?
        public var url: String?
        public var action_id: String?
        public var value: String?

        public init(text: Text? = nil, url: String? = nil, action_id: String? = nil, value: String? = nil) {
            self.text = text
            self.url = url
            self.action_id = action_id
            self.value = value
        }

        private enum CodingKeys: String, CodingKey {
            case text, url, action_id, value
        }
    }
}
