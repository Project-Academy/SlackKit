//
//  Elements.swift
//  SlackKit
//
//  Payload structs for the interactive Block Kit elements beyond Button —
//  selects, multi-selects, overflow, pickers, checkboxes, radio buttons and
//  the image display element. Each is dispatched by ``Block/ActionElement``,
//  which owns the wire `type`; none of these structs writes it.
//
//  Spec: docs/systems/comms/blockkit-spec-2026-08.md §2.
//

import Foundation

extension Block {

    //--------------------------------------
    // MARK: - SELECT MENUS (SINGLE) -
    //--------------------------------------
    /**
     `static_select` — a menu over app-defined options. Exactly one of
     `options` / `option_groups` (max 100 either way).
     */
    public struct StaticSelect: Codable, Equatable, Sendable {
        public var action_id: String?
        public var options: [Option]?
        public var option_groups: [OptionGroup]?
        /// Must exactly match an entry in `options` / `option_groups`.
        public var initial_option: Option?
        public var confirm: Confirm?
        public var focus_on_load: Bool?
        /// `plain_text` only; max 150.
        public var placeholder: Text?

        public init(placeholder: String? = nil, options: [Option]? = nil, optionGroups: [OptionGroup]? = nil, initialOption: Option? = nil, action_id: String? = nil, confirm: Confirm? = nil, focusOnLoad: Bool? = nil) {
            self.action_id = action_id
            self.options = options
            self.option_groups = optionGroups
            self.initial_option = initialOption
            self.confirm = confirm
            self.focus_on_load = focusOnLoad
            self.placeholder = placeholder.map { Text(plain: $0) }
        }
    }

    /**
     `external_select` — options served at open time by the app's Options
     Load URL (response `{options}` or `{option_groups}`).
     */
    public struct ExternalSelect: Codable, Equatable, Sendable {
        public var action_id: String?
        public var initial_option: Option?
        /// Typed characters before the load URL is called. Slack default 3.
        public var min_query_length: Int?
        public var confirm: Confirm?
        public var focus_on_load: Bool?
        public var placeholder: Text?

        public init(placeholder: String? = nil, initialOption: Option? = nil, minQueryLength: Int? = nil, action_id: String? = nil, confirm: Confirm? = nil, focusOnLoad: Bool? = nil) {
            self.action_id = action_id
            self.initial_option = initialOption
            self.min_query_length = minQueryLength
            self.confirm = confirm
            self.focus_on_load = focusOnLoad
            self.placeholder = placeholder.map { Text(plain: $0) }
        }
    }

    /// `users_select` — a menu over the workspace's users.
    public struct UsersSelect: Codable, Equatable, Sendable {
        public var action_id: String?
        public var initial_user: String?
        public var confirm: Confirm?
        public var focus_on_load: Bool?
        public var placeholder: Text?

        public init(placeholder: String? = nil, initialUser: String? = nil, action_id: String? = nil, confirm: Confirm? = nil, focusOnLoad: Bool? = nil) {
            self.action_id = action_id
            self.initial_user = initialUser
            self.confirm = confirm
            self.focus_on_load = focusOnLoad
            self.placeholder = placeholder.map { Text(plain: $0) }
        }
    }

    /// `conversations_select` — a menu over conversations, filterable via ``Block/Filter``.
    public struct ConversationsSelect: Codable, Equatable, Sendable {
        public var action_id: String?
        /// Takes precedence over `default_to_current_conversation`.
        public var initial_conversation: String?
        public var default_to_current_conversation: Bool?
        /// Only works in input blocks in modals; adds `response_url` to `view_submission`.
        public var response_url_enabled: Bool?
        public var filter: Filter?
        public var confirm: Confirm?
        public var focus_on_load: Bool?
        public var placeholder: Text?

        public init(placeholder: String? = nil, initialConversation: String? = nil, defaultToCurrent: Bool? = nil, filter: Filter? = nil, responseURLEnabled: Bool? = nil, action_id: String? = nil, confirm: Confirm? = nil, focusOnLoad: Bool? = nil) {
            self.action_id = action_id
            self.initial_conversation = initialConversation
            self.default_to_current_conversation = defaultToCurrent
            self.response_url_enabled = responseURLEnabled
            self.filter = filter
            self.confirm = confirm
            self.focus_on_load = focusOnLoad
            self.placeholder = placeholder.map { Text(plain: $0) }
        }
    }

    /// `channels_select` — a menu over public channels.
    public struct ChannelsSelect: Codable, Equatable, Sendable {
        public var action_id: String?
        public var initial_channel: String?
        /// Only works in input blocks in modals.
        public var response_url_enabled: Bool?
        public var confirm: Confirm?
        public var focus_on_load: Bool?
        public var placeholder: Text?

        public init(placeholder: String? = nil, initialChannel: String? = nil, responseURLEnabled: Bool? = nil, action_id: String? = nil, confirm: Confirm? = nil, focusOnLoad: Bool? = nil) {
            self.action_id = action_id
            self.initial_channel = initialChannel
            self.response_url_enabled = responseURLEnabled
            self.confirm = confirm
            self.focus_on_load = focusOnLoad
            self.placeholder = placeholder.map { Text(plain: $0) }
        }
    }

    //--------------------------------------
    // MARK: - MULTI-SELECT MENUS -
    //--------------------------------------
    /// `multi_static_select`. Each option's text < 76 characters.
    public struct MultiStaticSelect: Codable, Equatable, Sendable {
        public var action_id: String?
        public var options: [Option]?
        public var option_groups: [OptionGroup]?
        public var initial_options: [Option]?
        /// Minimum 1.
        public var max_selected_items: Int?
        public var confirm: Confirm?
        public var focus_on_load: Bool?
        public var placeholder: Text?

        public init(placeholder: String? = nil, options: [Option]? = nil, optionGroups: [OptionGroup]? = nil, initialOptions: [Option]? = nil, maxSelectedItems: Int? = nil, action_id: String? = nil, confirm: Confirm? = nil, focusOnLoad: Bool? = nil) {
            self.action_id = action_id
            self.options = options
            self.option_groups = optionGroups
            self.initial_options = initialOptions
            self.max_selected_items = maxSelectedItems
            self.confirm = confirm
            self.focus_on_load = focusOnLoad
            self.placeholder = placeholder.map { Text(plain: $0) }
        }
    }

    /// `multi_external_select` — Options Load URL mechanics as ``Block/ExternalSelect``.
    public struct MultiExternalSelect: Codable, Equatable, Sendable {
        public var action_id: String?
        public var initial_options: [Option]?
        public var min_query_length: Int?
        public var max_selected_items: Int?
        public var confirm: Confirm?
        public var placeholder: Text?

        public init(placeholder: String? = nil, initialOptions: [Option]? = nil, minQueryLength: Int? = nil, maxSelectedItems: Int? = nil, action_id: String? = nil, confirm: Confirm? = nil) {
            self.action_id = action_id
            self.initial_options = initialOptions
            self.min_query_length = minQueryLength
            self.max_selected_items = maxSelectedItems
            self.confirm = confirm
            self.placeholder = placeholder.map { Text(plain: $0) }
        }
    }

    /// `multi_users_select`.
    public struct MultiUsersSelect: Codable, Equatable, Sendable {
        public var action_id: String?
        public var initial_users: [String]?
        public var max_selected_items: Int?
        public var confirm: Confirm?
        public var focus_on_load: Bool?
        public var placeholder: Text?

        public init(placeholder: String? = nil, initialUsers: [String]? = nil, maxSelectedItems: Int? = nil, action_id: String? = nil, confirm: Confirm? = nil, focusOnLoad: Bool? = nil) {
            self.action_id = action_id
            self.initial_users = initialUsers
            self.max_selected_items = maxSelectedItems
            self.confirm = confirm
            self.focus_on_load = focusOnLoad
            self.placeholder = placeholder.map { Text(plain: $0) }
        }
    }

    /// `multi_conversations_select`. `initial_conversations` is ignored when
    /// `default_to_current_conversation` is supplied.
    public struct MultiConversationsSelect: Codable, Equatable, Sendable {
        public var action_id: String?
        public var initial_conversations: [String]?
        public var default_to_current_conversation: Bool?
        public var max_selected_items: Int?
        public var filter: Filter?
        public var confirm: Confirm?
        public var focus_on_load: Bool?
        public var placeholder: Text?

        public init(placeholder: String? = nil, initialConversations: [String]? = nil, defaultToCurrent: Bool? = nil, maxSelectedItems: Int? = nil, filter: Filter? = nil, action_id: String? = nil, confirm: Confirm? = nil, focusOnLoad: Bool? = nil) {
            self.action_id = action_id
            self.initial_conversations = initialConversations
            self.default_to_current_conversation = defaultToCurrent
            self.max_selected_items = maxSelectedItems
            self.filter = filter
            self.confirm = confirm
            self.focus_on_load = focusOnLoad
            self.placeholder = placeholder.map { Text(plain: $0) }
        }
    }

    /// `multi_channels_select` (public channels).
    public struct MultiChannelsSelect: Codable, Equatable, Sendable {
        public var action_id: String?
        public var initial_channels: [String]?
        public var max_selected_items: Int?
        public var confirm: Confirm?
        public var focus_on_load: Bool?
        public var placeholder: Text?

        public init(placeholder: String? = nil, initialChannels: [String]? = nil, maxSelectedItems: Int? = nil, action_id: String? = nil, confirm: Confirm? = nil, focusOnLoad: Bool? = nil) {
            self.action_id = action_id
            self.initial_channels = initialChannels
            self.max_selected_items = maxSelectedItems
            self.confirm = confirm
            self.focus_on_load = focusOnLoad
            self.placeholder = placeholder.map { Text(plain: $0) }
        }
    }

    //--------------------------------------
    // MARK: - OVERFLOW & PICKERS -
    //--------------------------------------
    /// `overflow` — the "…" menu. Up to 5 options; options may carry URLs.
    public struct Overflow: Codable, Equatable, Sendable {
        public var action_id: String?
        public var options: [Option]
        public var confirm: Confirm?

        public init(options: [Option], action_id: String? = nil, confirm: Confirm? = nil) {
            self.action_id = action_id
            self.options = options
            self.confirm = confirm
        }
    }

    /// `datepicker`. `initial_date` is `YYYY-MM-DD`.
    public struct DatePicker: Codable, Equatable, Sendable {
        public var action_id: String?
        public var initial_date: String?
        public var confirm: Confirm?
        public var focus_on_load: Bool?
        public var placeholder: Text?

        public init(placeholder: String? = nil, initialDate: String? = nil, action_id: String? = nil, confirm: Confirm? = nil, focusOnLoad: Bool? = nil) {
            self.action_id = action_id
            self.initial_date = initialDate
            self.confirm = confirm
            self.focus_on_load = focusOnLoad
            self.placeholder = placeholder.map { Text(plain: $0) }
        }
    }

    /// `timepicker`. `initial_time` is 24-hour `HH:mm`; `timezone` is IANA.
    public struct TimePicker: Codable, Equatable, Sendable {
        public var action_id: String?
        public var initial_time: String?
        public var timezone: String?
        public var confirm: Confirm?
        public var focus_on_load: Bool?
        public var placeholder: Text?

        public init(placeholder: String? = nil, initialTime: String? = nil, timezone: String? = nil, action_id: String? = nil, confirm: Confirm? = nil, focusOnLoad: Bool? = nil) {
            self.action_id = action_id
            self.initial_time = initialTime
            self.timezone = timezone
            self.confirm = confirm
            self.focus_on_load = focusOnLoad
            self.placeholder = placeholder.map { Text(plain: $0) }
        }
    }

    /// `datetimepicker`. `initial_date_time` is a UNIX timestamp in seconds.
    /// Not valid as a section accessory (actions/input only).
    public struct DatetimePicker: Codable, Equatable, Sendable {
        public var action_id: String?
        public var initial_date_time: Int?
        public var confirm: Confirm?
        public var focus_on_load: Bool?

        public init(initialDateTime: Int? = nil, action_id: String? = nil, confirm: Confirm? = nil, focusOnLoad: Bool? = nil) {
            self.action_id = action_id
            self.initial_date_time = initialDateTime
            self.confirm = confirm
            self.focus_on_load = focusOnLoad
        }
    }

    //--------------------------------------
    // MARK: - CHECKBOXES & RADIO -
    //--------------------------------------
    /// `checkboxes`. Max 10 options; options may use `mrkdwn` text.
    public struct Checkboxes: Codable, Equatable, Sendable {
        public var action_id: String?
        public var options: [Option]
        /// Must exactly match entries in `options`.
        public var initial_options: [Option]?
        public var confirm: Confirm?
        public var focus_on_load: Bool?

        public init(options: [Option], initialOptions: [Option]? = nil, action_id: String? = nil, confirm: Confirm? = nil, focusOnLoad: Bool? = nil) {
            self.action_id = action_id
            self.options = options
            self.initial_options = initialOptions
            self.confirm = confirm
            self.focus_on_load = focusOnLoad
        }
    }

    /// `radio_buttons`. Max 10 options; options may use `mrkdwn` text.
    public struct RadioButtons: Codable, Equatable, Sendable {
        public var action_id: String?
        public var options: [Option]
        /// Must exactly match one entry in `options`.
        public var initial_option: Option?
        public var confirm: Confirm?
        public var focus_on_load: Bool?

        public init(options: [Option], initialOption: Option? = nil, action_id: String? = nil, confirm: Confirm? = nil, focusOnLoad: Bool? = nil) {
            self.action_id = action_id
            self.options = options
            self.initial_option = initialOption
            self.confirm = confirm
            self.focus_on_load = focusOnLoad
        }
    }

    //--------------------------------------
    // MARK: - IMAGE ELEMENT -
    //--------------------------------------
    /**
     `image` element — a display-only image, valid as a section accessory or
     inside a context block. One of `image_url` / `slack_file`; `alt_text`
     is required by Slack (plain text, no markup).

     This is the element form. Context blocks keep their own
     ``Block/ContextElement/image(url:altText:)`` (D10) — this struct exists
     so an image can also appear where the element enum is used, e.g.
     `section.accessory`.
     */
    public struct ImageElement: Codable, Equatable, Sendable {
        public var image_url: String?
        public var slack_file: SlackFile?
        public var alt_text: String

        public init(url: String, altText: String) {
            self.image_url = url
            self.alt_text = altText
        }
        public init(slackFile: SlackFile, altText: String) {
            self.slack_file = slackFile
            self.alt_text = altText
        }
    }
}
