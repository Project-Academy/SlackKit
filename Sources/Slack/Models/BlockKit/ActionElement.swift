//
//  ActionElement.swift
//  SlackKit
//
//  Models for the elements that appear inside an `actions` Block.
//  Slack supports many interactive element types (button, select,
//  datepicker, overflow, etc.); the current model is `Button` plus
//  an `.unknown` case that round-trips anything else verbatim.
//
//  Spec: https://api.slack.com/reference/block-kit/block-elements
//

import Foundation

extension Block {

    /**
     One element inside an `actions` Block.

     Model is intentionally non-exhaustive — interactive element types are added
     on demand. Unknown ones keep their whole JSON body in
     ``unknown(type:raw:)``, so relaying a message doesn't quietly strip the
     interactive parts this kit hasn't learned yet.
     */
    public enum ActionElement: Codable, Equatable, Sendable {

        case button(Button)
        case unknown(type: String, raw: [String: JSONValue])

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
                let raw = try JSONValue(from: decoder)
                self = .unknown(type: type, raw: raw.objectDropping(["type"]))
            }
        }

        /**
         Writes the element back exactly as Slack expects it.

         `type` is written here rather than by ``Block/Button``, which has no
         `type` field of its own: an earlier version delegated the whole encode
         to `Button` and so emitted a button element with **no `type`** — output
         Slack rejects, and which this kit could not even decode back.
         */
        public func encode(to encoder: Encoder) throws {
            switch self {
            case let .button(button):
                try button.encode(to: encoder)
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode("button", forKey: .type)

            case let .unknown(type, raw):
                var fields = raw
                fields["type"] = .string(type)
                try JSONValue.object(fields).encode(to: encoder)
            }
        }
    }

    /**
     `actions`-block button element. Carries the visible label, the
     URL (if it's a link-button), the developer-specified action id,
     and an arbitrary payload value.

     The `type` discriminator is owned by ``Block/ActionElement`` — a `Button`
     never writes it, so there's exactly one place it can be got wrong.
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
