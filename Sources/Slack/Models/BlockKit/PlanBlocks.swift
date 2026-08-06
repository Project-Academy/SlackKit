//
//  PlanBlocks.swift
//  SlackKit
//
//  The `plan`, `task_card` and `context_actions` block families — Slack's
//  agent-task surface.
//
//  Spec: docs/systems/comms/blockkit-spec-2026-08.md §1.
//

import Foundation

extension Block {

    /**
     Payload of a `plan` block — a collection of related tasks.

     `title` is a bare string on the wire (the doc table says Object; the
     page's own example sends a string — examples win, per the spec axiom).
     */
    public struct Plan: Codable, Equatable, Sendable {

        public var title: String
        /// A sequence of `task_card` blocks.
        public var tasks: [Block]?

        public init(title: String, tasks: [Block]? = nil) {
            self.title = title
            self.tasks = tasks
        }

        private enum CodingKeys: String, CodingKey {
            case title, tasks
        }
    }

    /**
     Payload of a `task_card` block — a single task with status, rich-text
     details/output and URL sources.
     */
    public struct TaskCard: Codable, Equatable, Sendable {

        public var task_id: String
        /// Plain text.
        public var title: String
        /// Rich-text content; a whole `rich_text` block on the wire
        /// (envelope handled in Codable, as ``Block/Container``'s title).
        public var details: [RichTextElement]?
        /// Rich-text content; same envelope handling as `details`.
        public var output: [RichTextElement]?
        /// URL source elements.
        public var sources: [URLSource]?
        public var status: Status?

        public init(taskID: String, title: String, details: [RichTextElement]? = nil, output: [RichTextElement]? = nil, sources: [URLSource]? = nil, status: Status? = nil) {
            self.task_id = taskID
            self.title = title
            self.details = details
            self.output = output
            self.sources = sources
            self.status = status
        }

        /// Tolerant like ``Block/Style``: an unlisted value decodes rather than throws.
        public struct Status: RawRepresentable, Codable, Equatable, Sendable {
            public let rawValue: String
            public init(rawValue: String) { self.rawValue = rawValue }

            public static let pending = Status(rawValue: "pending")
            public static let inProgress = Status(rawValue: "in_progress")
            public static let complete = Status(rawValue: "complete")
            public static let error = Status(rawValue: "error")
        }

        private enum CodingKeys: String, CodingKey {
            case task_id, title, details, output, sources, status
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.task_id = try c.decode(String.self, forKey: .task_id)
            self.title = try c.decode(String.self, forKey: .title)
            self.details = try c.decodeIfPresent(RichTextEnvelope.self, forKey: .details)?.elements
            self.output = try c.decodeIfPresent(RichTextEnvelope.self, forKey: .output)?.elements
            self.sources = try c.decodeIfPresent([URLSource].self, forKey: .sources)
            self.status = try c.decodeIfPresent(Status.self, forKey: .status)
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(task_id, forKey: .task_id)
            try c.encode(title, forKey: .title)
            try c.encodeIfPresent(details.map { RichTextEnvelope(type: "rich_text", elements: $0) }, forKey: .details)
            try c.encodeIfPresent(output.map { RichTextEnvelope(type: "rich_text", elements: $0) }, forKey: .output)
            try c.encodeIfPresent(sources, forKey: .sources)
            try c.encodeIfPresent(status, forKey: .status)
        }
    }

    /**
     A `url` source element — only valid inside a `task_card`'s `sources`.
     Its wire `type` is a fixed field of the element, written here
     (like ``Block/SlackIcon``), not a dispatch discriminator.
     */
    public struct URLSource: Codable, Equatable, Sendable {

        public var url: String
        /// Display text.
        public var text: String

        public init(url: String, text: String) {
            self.url = url
            self.text = text
        }

        private enum CodingKeys: String, CodingKey {
            case type, url, text
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.url = try c.decode(String.self, forKey: .url)
            self.text = try c.decode(String.self, forKey: .text)
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode("url", forKey: .type)
            try c.encode(url, forKey: .url)
            try c.encode(text, forKey: .text)
        }
    }

    /**
     Displays a collection of related tasks.

     ## Available in Surfaces
     - Messages
     */
    public static func plan(title: String, tasks: [Block]? = nil) -> Block {
        var block = Block(type: "plan")
        block.plan = Plan(title: title, tasks: tasks)
        return block
    }

    /**
     Displays a single task.

     ## Available in Surfaces
     - Messages
     */
    public static func taskCard(_ taskCard: TaskCard) -> Block {
        var block = Block(type: "task_card")
        block.taskCard = taskCard
        return block
    }

    /**
     Presents feedback buttons and icon buttons as supporting information.
     Takes ``Block/ActionElement/feedbackButtons(_:)`` and
     ``Block/ActionElement/iconButton(_:)`` elements only, max 5.

     ## Available in Surfaces
     - Messages
     */
    public static func contextActions(_ elements: [ActionElement]) -> Block {
        var block = Block(type: "context_actions")
        block.actions = elements
        return block
    }

    //--------------------------------------
    // MARK: - CONTEXT-ACTIONS ELEMENTS -
    //--------------------------------------
    /**
     `feedback_buttons` element — a positive/negative pair. Both buttons
     are required by Slack.
     */
    public struct FeedbackButtons: Codable, Equatable, Sendable {

        public var positive_button: FeedbackButton
        public var negative_button: FeedbackButton
        public var action_id: String?

        public init(positive: FeedbackButton, negative: FeedbackButton, action_id: String? = nil) {
            self.positive_button = positive
            self.negative_button = negative
            self.action_id = action_id
        }

        /// One half of a `feedback_buttons` pair. `value` is required (max
        /// 2000); `text` is `plain_text` (max 75).
        public struct FeedbackButton: Codable, Equatable, Sendable {
            public var text: Text
            public var value: String
            /// Max 75.
            public var accessibility_label: String?

            public init(_ text: String, value: String, accessibilityLabel: String? = nil) {
                self.text = Text(plain: text)
                self.value = value
                self.accessibility_label = accessibilityLabel
            }
        }
    }

    /**
     `icon_button` element. Slack currently only offers the `trash` icon
     here (unlike card ``Block/SlackIcon``s).
     */
    public struct IconButton: Codable, Equatable, Sendable {

        /// Only `"trash"` is available at this time.
        public var icon: String
        /// `plain_text` only.
        public var text: Text
        public var action_id: String?
        /// Max 2000.
        public var value: String?
        public var confirm: Confirm?
        /// Max 75.
        public var accessibility_label: String?
        /// User IDs the button appears for; visible to all if omitted.
        public var visible_to_user_ids: [String]?

        public init(icon: String = "trash", text: String, action_id: String? = nil, value: String? = nil, confirm: Confirm? = nil, accessibilityLabel: String? = nil, visibleToUserIDs: [String]? = nil) {
            self.icon = icon
            self.text = Text(plain: text)
            self.action_id = action_id
            self.value = value
            self.confirm = confirm
            self.accessibility_label = accessibilityLabel
            self.visible_to_user_ids = visibleToUserIDs
        }
    }
}
