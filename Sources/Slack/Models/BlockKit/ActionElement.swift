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
        case workflowButton(WorkflowButton)
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
            case "workflow_button":
                self = .workflowButton(try WorkflowButton(from: decoder))
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

            case let .workflowButton(button):
                try button.encode(to: encoder)
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode("workflow_button", forKey: .type)

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

        /// `plain_text` only; max 75 characters (Slack may truncate around 30).
        public var text: Text?
        /// Link-button target, max 3000 characters. The interaction payload
        /// is still sent and must still be acknowledged.
        public var url: String?
        public var action_id: String?
        /// Arbitrary payload returned in the interaction, max 2000 characters.
        public var value: String?
        /// `primary` (one per set) or `danger`; omit for the default look.
        public var style: Style?
        /// Confirmation dialog shown before the interaction payload is sent.
        public var confirm: Confirm?
        /// Read by screen readers instead of `text`; max 75 characters.
        public var accessibility_label: String?

        public init(
            text: Text? = nil,
            url: String? = nil,
            action_id: String? = nil,
            value: String? = nil,
            style: Style? = nil,
            confirm: Confirm? = nil,
            accessibility_label: String? = nil
        ) {
            self.text = text
            self.url = url
            self.action_id = action_id
            self.value = value
            self.style = style
            self.confirm = confirm
            self.accessibility_label = accessibility_label
        }

        private enum CodingKeys: String, CodingKey {
            case text, url, action_id, value, style, confirm, accessibility_label
        }
    }

    /**
     `workflow_button` element — runs a workflow via its link ``Block/Trigger``
     when clicked. Unlike ``Block/Button``, `action_id` and the workflow are
     required by Slack.

     The `type` discriminator is owned by ``Block/ActionElement``, as for
     every element payload.
     */
    public struct WorkflowButton: Codable, Equatable, Sendable {

        /// `plain_text` only; max 75 characters (Slack may truncate around 30).
        public var text: Text?
        public var workflow: Workflow
        public var action_id: String?
        public var style: Style?
        /// Read by screen readers instead of `text`; max 75 characters.
        public var accessibility_label: String?

        public init(
            text: Text? = nil,
            workflow: Workflow,
            action_id: String? = nil,
            style: Style? = nil,
            accessibility_label: String? = nil
        ) {
            self.text = text
            self.workflow = workflow
            self.action_id = action_id
            self.style = style
            self.accessibility_label = accessibility_label
        }

        private enum CodingKeys: String, CodingKey {
            case text, workflow, action_id, style, accessibility_label
        }
    }
}
