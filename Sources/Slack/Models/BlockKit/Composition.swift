//
//  Composition.swift
//  SlackKit
//
//  Block Kit composition objects — the reusable value objects that element
//  and block payloads reference (confirmation dialogs, options, filters,
//  workflow triggers, Slack files and icons).
//
//  Spec: docs/systems/comms/blockkit-spec-2026-08.md §5, from
//  https://docs.slack.dev/reference/block-kit/composition-objects
//

import Foundation

extension Block {

    //--------------------------------------
    // MARK: - STYLE -
    //--------------------------------------
    /**
     Decorative style for buttons and confirmation dialogs.

     `RawRepresentable` over `String` rather than an enum so a style value
     this kit hasn't learned decodes instead of throwing — the same tolerance
     the element enums get from `.unknown`.
     */
    public struct Style: RawRepresentable, Codable, Equatable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        /// Green on desktop, blue on mobile. Slack's default when omitted.
        public static let primary = Style(rawValue: "primary")
        /// Red. For destructive or irreversible actions.
        public static let danger = Style(rawValue: "danger")
    }

    //--------------------------------------
    // MARK: - CONFIRMATION DIALOG -
    //--------------------------------------
    /**
     A confirmation dialog shown after an interactive element is used,
     before the interaction payload is sent.

     - note: `title`, `confirm` and `deny` are `plain_text` (max 100 / 30 / 30
       characters); `text` allows either text type (max 300).
     */
    public struct Confirm: Codable, Equatable, Sendable {

        public var title: Text
        public var text: Text
        public var confirm: Text
        public var deny: Text
        /// Applied to the confirm button. Omitted means `primary`.
        public var style: Style?

        public init(title: String, text: String, confirm: String = "Confirm", deny: String = "Cancel", style: Style? = nil) {
            self.title = Text(plain: title)
            self.text = Text(text)
            self.confirm = Text(plain: confirm)
            self.deny = Text(plain: deny)
            self.style = style
        }
    }

    //--------------------------------------
    // MARK: - OPTIONS -
    //--------------------------------------
    /**
     One choice in a select menu, multi-select menu, overflow menu,
     checkbox group or radio button group.

     - note: `text` and `description` max 75 characters; `value` max 150.
       Overflow/select menus require `plain_text` for `text`; checkboxes and
       radio buttons may use `mrkdwn`.
     */
    public struct Option: Codable, Equatable, Sendable {

        public var text: Text
        /// Passed to the app in the interaction payload when chosen.
        public var value: String
        public var description: Text?
        /**
         Overflow menus only: chosen options load this URL in the browser.
         The interaction payload is still sent and must still be acknowledged.
         - note: Maximum length 3000 characters.
         */
        public var url: String?

        public init(_ text: String, value: String, description: String? = nil, url: String? = nil) {
            self.text = Text(plain: text)
            self.value = value
            self.description = description.map { Text(plain: $0) }
            self.url = url
        }
    }

    /**
     A titled group of ``Block/Option`` values inside a select or
     multi-select menu's `option_groups` array.

     - note: Maximum 100 groups per menu, 100 options per group;
       `label` is `plain_text`, max 75 characters.
     */
    public struct OptionGroup: Codable, Equatable, Sendable {

        public var label: Text
        public var options: [Option]

        public init(label: String, options: [Option]) {
            self.label = Text(plain: label)
            self.options = options
        }
    }

    //--------------------------------------
    // MARK: - CONVERSATION FILTER -
    //--------------------------------------
    /**
     Restricts which conversations a `conversations_select` /
     `multi_conversations_select` offers. Slack requires at least one
     field to be supplied.
     */
    public struct Filter: Codable, Equatable, Sendable {

        /// Non-empty subset of ``ConversationType`` raw values.
        public var include: [ConversationType]?
        /// Default `false`. Does not exclude users from shared channels.
        public var exclude_external_shared_channels: Bool?
        /// Default `false`.
        public var exclude_bot_users: Bool?

        public init(include: [ConversationType]? = nil, excludeExternalSharedChannels: Bool? = nil, excludeBotUsers: Bool? = nil) {
            self.include = include
            self.exclude_external_shared_channels = excludeExternalSharedChannels
            self.exclude_bot_users = excludeBotUsers
        }

        /// Tolerant like ``Block/Style``: an unlisted value decodes rather than throws.
        public struct ConversationType: RawRepresentable, Codable, Equatable, Sendable {
            public let rawValue: String
            public init(rawValue: String) { self.rawValue = rawValue }

            public static let im = ConversationType(rawValue: "im")
            public static let mpim = ConversationType(rawValue: "mpim")
            public static let privateChannels = ConversationType(rawValue: "private")
            public static let publicChannels = ConversationType(rawValue: "public")
        }
    }

    //--------------------------------------
    // MARK: - DISPATCH ACTION CONFIG -
    //--------------------------------------
    /**
     Determines when a text-input element in an `input` block dispatches
     a `block_actions` payload.
     */
    public struct DispatchActionConfig: Codable, Equatable, Sendable {

        public var trigger_actions_on: [TriggerAction]?

        public init(triggerActionsOn: [TriggerAction]) {
            self.trigger_actions_on = triggerActionsOn
        }

        /// Tolerant like ``Block/Style``: an unlisted value decodes rather than throws.
        public struct TriggerAction: RawRepresentable, Codable, Equatable, Sendable {
            public let rawValue: String
            public init(rawValue: String) { self.rawValue = rawValue }

            public static let onEnterPressed = TriggerAction(rawValue: "on_enter_pressed")
            public static let onCharacterEntered = TriggerAction(rawValue: "on_character_entered")
        }
    }

    //--------------------------------------
    // MARK: - SLACK FILE -
    //--------------------------------------
    /**
     References an existing Slack-hosted image for image blocks/elements —
     by URL (`url_private` or `permalink`) or by file ID, never both:
     Slack rejects a payload carrying the two together, so the initialisers
     only offer one at a time.

     - note: The file must be an image the posting user can access;
       `png` / `jpg` / `jpeg` / `gif` only.
     */
    public struct SlackFile: Codable, Equatable, Sendable {

        public var url: String?
        public var id: String?

        public init(url: String) { self.url = url }
        public init(id: String) { self.id = id }
    }

    //--------------------------------------
    // MARK: - WORKFLOW -
    //--------------------------------------
    /**
     The workflow a `workflow_button` runs, wrapping the link ``Trigger``
     that starts it.
     */
    public struct Workflow: Codable, Equatable, Sendable {

        public var trigger: Trigger

        public init(trigger: Trigger) { self.trigger = trigger }
    }

    /**
     A link trigger for a workflow.

     - warning: `customizable_input_parameters` values may be visible
       client-side — never put secrets in them.
     */
    public struct Trigger: Codable, Equatable, Sendable {

        /// The link trigger URL; must belong to a valid trigger.
        public var url: String
        /**
         Each `name` must match a workflow input parameter marked
         `customizable: true` on the trigger; each `value` must match that
         parameter's type — hence ``JSONValue`` rather than `String`.
         (Slack's input-parameter page 404s as of 2026-08-06; `name`/`value`
         come from the trigger object's own documentation.)
         */
        public var customizable_input_parameters: [InputParameter]?

        public init(url: String, customizableInputParameters: [InputParameter]? = nil) {
            self.url = url
            self.customizable_input_parameters = customizableInputParameters
        }
    }

    /// One `{name, value}` entry of ``Trigger/customizable_input_parameters``.
    public struct InputParameter: Codable, Equatable, Sendable {

        public var name: String
        public var value: JSONValue

        public init(name: String, value: JSONValue) {
            self.name = name
            self.value = value
        }
    }

    //--------------------------------------
    // MARK: - SLACK ICON -
    //--------------------------------------
    /**
     A built-in Slack icon, usable only within a `card` block. The wire
     `type` is always `"icon"` and is written by this struct — it is a fixed
     field of the object, not a dispatch discriminator.

     `name` stays a `String` (with the documented names as statics on
     ``Name``) so an icon this kit hasn't learned decodes rather than throws.
     Documented names as of 2026-08-06: archive, book, bookmark, bot, bug,
     calendar, call, caret-left, caret-right, check, clipboard, code, comment,
     compass, copy, cube, download, edit, email, eye-closed, eye-open, file,
     flag, folder, gear, globe, heart, help, image, info, key, lightbulb,
     link, map, mobile, new-window, pin, plus, refine, refresh, rocket, save,
     screen, share, sparkle, star, star-filled, tag, thumbs-down, thumbs-up,
     trash, upload, user, warning.
     */
    public struct SlackIcon: Codable, Equatable, Sendable {

        public var name: String

        public init(_ name: String) { self.name = name }

        private enum CodingKeys: String, CodingKey {
            case type, name
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try c.decode(String.self, forKey: .name)
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode("icon", forKey: .type)
            try c.encode(name, forKey: .name)
        }
    }
}
