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
    public indirect enum ActionElement: Codable, Equatable, Sendable {

        case button(Button)
        case workflowButton(WorkflowButton)
        case staticSelect(StaticSelect)
        case externalSelect(ExternalSelect)
        case usersSelect(UsersSelect)
        case conversationsSelect(ConversationsSelect)
        case channelsSelect(ChannelsSelect)
        case multiStaticSelect(MultiStaticSelect)
        case multiExternalSelect(MultiExternalSelect)
        case multiUsersSelect(MultiUsersSelect)
        case multiConversationsSelect(MultiConversationsSelect)
        case multiChannelsSelect(MultiChannelsSelect)
        case overflow(Overflow)
        case datePicker(DatePicker)
        case timePicker(TimePicker)
        case datetimePicker(DatetimePicker)
        case checkboxes(Checkboxes)
        case radioButtons(RadioButtons)
        case image(ImageElement)
        case plainTextInput(PlainTextInput)
        case richTextInput(RichTextInput)
        case emailTextInput(EmailTextInput)
        case urlTextInput(URLTextInput)
        case numberInput(NumberInput)
        case fileInput(FileInput)
        case feedbackButtons(FeedbackButtons)
        case iconButton(IconButton)
        case unknown(type: String, raw: [String: JSONValue])

        private enum CodingKeys: String, CodingKey {
            case type
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type = try c.decode(String.self, forKey: .type)
            switch type {
            case "button":                     self = .button(try Button(from: decoder))
            case "workflow_button":            self = .workflowButton(try WorkflowButton(from: decoder))
            case "static_select":              self = .staticSelect(try StaticSelect(from: decoder))
            case "external_select":            self = .externalSelect(try ExternalSelect(from: decoder))
            case "users_select":               self = .usersSelect(try UsersSelect(from: decoder))
            case "conversations_select":       self = .conversationsSelect(try ConversationsSelect(from: decoder))
            case "channels_select":            self = .channelsSelect(try ChannelsSelect(from: decoder))
            case "multi_static_select":        self = .multiStaticSelect(try MultiStaticSelect(from: decoder))
            case "multi_external_select":      self = .multiExternalSelect(try MultiExternalSelect(from: decoder))
            case "multi_users_select":         self = .multiUsersSelect(try MultiUsersSelect(from: decoder))
            case "multi_conversations_select": self = .multiConversationsSelect(try MultiConversationsSelect(from: decoder))
            case "multi_channels_select":      self = .multiChannelsSelect(try MultiChannelsSelect(from: decoder))
            case "overflow":                   self = .overflow(try Overflow(from: decoder))
            case "datepicker":                 self = .datePicker(try DatePicker(from: decoder))
            case "timepicker":                 self = .timePicker(try TimePicker(from: decoder))
            case "datetimepicker":             self = .datetimePicker(try DatetimePicker(from: decoder))
            case "checkboxes":                 self = .checkboxes(try Checkboxes(from: decoder))
            case "radio_buttons":              self = .radioButtons(try RadioButtons(from: decoder))
            case "image":                      self = .image(try ImageElement(from: decoder))
            case "plain_text_input":           self = .plainTextInput(try PlainTextInput(from: decoder))
            case "rich_text_input":            self = .richTextInput(try RichTextInput(from: decoder))
            case "email_text_input":           self = .emailTextInput(try EmailTextInput(from: decoder))
            case "url_text_input":             self = .urlTextInput(try URLTextInput(from: decoder))
            case "number_input":               self = .numberInput(try NumberInput(from: decoder))
            case "file_input":                 self = .fileInput(try FileInput(from: decoder))
            case "feedback_buttons":           self = .feedbackButtons(try FeedbackButtons(from: decoder))
            case "icon_button":                self = .iconButton(try IconButton(from: decoder))
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
        /// The wire `type` string for each modelled case.
        private var typeString: String? {
            switch self {
            case .button:                   return "button"
            case .workflowButton:           return "workflow_button"
            case .staticSelect:             return "static_select"
            case .externalSelect:           return "external_select"
            case .usersSelect:              return "users_select"
            case .conversationsSelect:      return "conversations_select"
            case .channelsSelect:           return "channels_select"
            case .multiStaticSelect:        return "multi_static_select"
            case .multiExternalSelect:      return "multi_external_select"
            case .multiUsersSelect:         return "multi_users_select"
            case .multiConversationsSelect: return "multi_conversations_select"
            case .multiChannelsSelect:      return "multi_channels_select"
            case .overflow:                 return "overflow"
            case .datePicker:               return "datepicker"
            case .timePicker:               return "timepicker"
            case .datetimePicker:           return "datetimepicker"
            case .checkboxes:               return "checkboxes"
            case .radioButtons:             return "radio_buttons"
            case .image:                    return "image"
            case .plainTextInput:           return "plain_text_input"
            case .richTextInput:            return "rich_text_input"
            case .emailTextInput:           return "email_text_input"
            case .urlTextInput:             return "url_text_input"
            case .numberInput:              return "number_input"
            case .fileInput:                return "file_input"
            case .feedbackButtons:          return "feedback_buttons"
            case .iconButton:               return "icon_button"
            case .unknown:                  return nil
            }
        }

        /// The payload each modelled case carries, type-erased for encoding.
        private var payload: (any Encodable & Sendable)? {
            switch self {
            case let .button(v):                   return v
            case let .workflowButton(v):           return v
            case let .staticSelect(v):             return v
            case let .externalSelect(v):           return v
            case let .usersSelect(v):              return v
            case let .conversationsSelect(v):      return v
            case let .channelsSelect(v):           return v
            case let .multiStaticSelect(v):        return v
            case let .multiExternalSelect(v):      return v
            case let .multiUsersSelect(v):         return v
            case let .multiConversationsSelect(v): return v
            case let .multiChannelsSelect(v):      return v
            case let .overflow(v):                 return v
            case let .datePicker(v):               return v
            case let .timePicker(v):               return v
            case let .datetimePicker(v):           return v
            case let .checkboxes(v):               return v
            case let .radioButtons(v):             return v
            case let .image(v):                    return v
            case let .plainTextInput(v):           return v
            case let .richTextInput(v):            return v
            case let .emailTextInput(v):           return v
            case let .urlTextInput(v):             return v
            case let .numberInput(v):              return v
            case let .fileInput(v):                return v
            case let .feedbackButtons(v):          return v
            case let .iconButton(v):               return v
            case .unknown:                         return nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            if case let .unknown(type, raw) = self {
                var fields = raw
                fields["type"] = .string(type)
                try JSONValue.object(fields).encode(to: encoder)
                return
            }
            guard let payload, let typeString else { return }
            try payload.encode(to: encoder)
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(typeString, forKey: .type)
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
