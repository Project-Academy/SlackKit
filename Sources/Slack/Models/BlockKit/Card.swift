//
//  Card.swift
//  SlackKit
//
//  The `card` block family — Slack's structured content card, and the
//  building block of carousels.
//
//  Spec: docs/systems/comms/blockkit-spec-2026-08.md §1 `card`.
//  Field shapes follow Slack's own JSON examples where the doc tables
//  contradict them (title/subtitle/body/subtext are text objects, `actions`
//  is a bare element array) — the spec axiom says examples win.
//

import Foundation

extension Block {

    /**
     Payload of a `card` block. Slack requires at least one of
     `hero_image`, `title`, `actions` or `body`.

     Layout notes from the docs: no attribute controls card size; up to 3
     action buttons — `danger` left-aligned, `primary`/unstyled right-aligned
     with `primary` furthest right.
     */
    public struct Card: Codable, Equatable, Sendable {

        /// Top image. URL max 3000; `alt_text` max 2000.
        public var hero_image: ImageElement?
        /// Small image beside title/subtitle. Mutually exclusive with `slack_icon`.
        public var icon: ImageElement?
        /// Built-in Slack icon. Mutually exclusive with `icon`.
        public var slack_icon: SlackIcon?
        /// `plain_text` or `mrkdwn`; max 150.
        public var title: Text?
        /// `plain_text` or `mrkdwn`; max 150.
        public var subtitle: Text?
        /// `plain_text` or `mrkdwn`; max 200.
        public var body: Text?
        /// Below the body; `plain_text` or `mrkdwn`; max 200.
        public var subtext: Text?
        /// Up to 3 buttons, as a bare element array on the wire.
        public var actions: [ActionElement]?

        public init(
            title: String? = nil,
            subtitle: String? = nil,
            body: String? = nil,
            subtext: String? = nil,
            heroImage: ImageElement? = nil,
            icon: ImageElement? = nil,
            slackIcon: SlackIcon? = nil,
            actions: [ActionElement]? = nil
        ) {
            self.hero_image = heroImage
            self.icon = icon
            self.slack_icon = slackIcon
            self.title = title.map { Text($0) }
            self.subtitle = subtitle.map { Text($0) }
            self.body = body.map { Text($0) }
            self.subtext = subtext.map { Text($0) }
            self.actions = actions
        }

        private enum CodingKeys: String, CodingKey {
            case hero_image, icon, slack_icon, title, subtitle, body, subtext, actions
        }
    }

    /**
     Displays content in a card.

     ## Available in Surfaces
     - Messages

     At least one of `title`, `body`, `heroImage` or `actions` is required
     by Slack.
     */
    public static func card(_ card: Card) -> Block {
        var block = Block(type: "card")
        block.card = card
        return block
    }
}
