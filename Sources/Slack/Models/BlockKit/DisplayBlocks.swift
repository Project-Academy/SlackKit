//
//  DisplayBlocks.swift
//  SlackKit
//
//  Flattened payload families for the simple display blocks — image, video,
//  file, markdown and alert. Fields sit top-level on the block; `Block` owns
//  `type` and `block_id` and dispatches by type.
//
//  Spec: docs/systems/comms/blockkit-spec-2026-08.md §1.
//

import Foundation

extension Block {

    //--------------------------------------
    // MARK: - IMAGE -
    //--------------------------------------
    /**
     Payload of an `image` block. One of `image_url` / `slack_file`;
     `alt_text` is required by Slack (plain text, no markup, max 2000).
     `png` / `jpg` / `jpeg` / `gif` only.

     ## Available in Surfaces
     - Modals
     - Messages
     - Home tabs
     */
    public struct ImageBlock: Codable, Equatable, Sendable {
        public var image_url: String?
        public var slack_file: SlackFile?
        public var alt_text: String
        /// `plain_text` only; max 2000.
        public var title: Text?

        public init(url: String, altText: String, title: String? = nil) {
            self.image_url = url
            self.alt_text = altText
            self.title = title.map { Text(plain: $0) }
        }
        public init(slackFile: SlackFile, altText: String, title: String? = nil) {
            self.slack_file = slackFile
            self.alt_text = altText
            self.title = title.map { Text(plain: $0) }
        }

        private enum CodingKeys: String, CodingKey {
            case image_url, slack_file, alt_text, title
        }
    }

    /// Displays an image by public URL.
    public static func image(url: String, altText: String, title: String? = nil) -> Block {
        var block = Block(type: "image")
        block.image = ImageBlock(url: url, altText: altText, title: title)
        return block
    }
    /// Displays a Slack-hosted image by ``Block/SlackFile`` reference.
    public static func image(slackFile: SlackFile, altText: String, title: String? = nil) -> Block {
        var block = Block(type: "image")
        block.image = ImageBlock(slackFile: slackFile, altText: altText, title: title)
        return block
    }

    //--------------------------------------
    // MARK: - VIDEO -
    //--------------------------------------
    /**
     Payload of a `video` block — an embedded player.

     Posting one needs the `links.embed:write` scope, and `video_url` must be
     HTTPS, iframe-embeddable, and within the app's unfurl domains (not a
     Slack domain).

     ## Available in Surfaces
     - All (messages, modals, Home tabs, link unfurls)
     */
    public struct Video: Codable, Equatable, Sendable {
        /// Tooltip and accessibility text. Required.
        public var alt_text: String
        /// `plain_text` only; < 200 characters.
        public var title: Text
        public var thumbnail_url: String
        public var video_url: String
        /// Non-embeddable HTTPS fallback URL for the video.
        public var title_url: String?
        /// `plain_text` only; < 200 characters.
        public var description: Text?
        /// < 50 characters.
        public var author_name: String?
        public var provider_icon_url: String?
        public var provider_name: String?

        public init(title: String, videoURL: String, thumbnailURL: String, altText: String, titleURL: String? = nil, description: String? = nil, authorName: String? = nil, providerIconURL: String? = nil, providerName: String? = nil) {
            self.alt_text = altText
            self.title = Text(plain: title)
            self.thumbnail_url = thumbnailURL
            self.video_url = videoURL
            self.title_url = titleURL
            self.description = description.map { Text(plain: $0) }
            self.author_name = authorName
            self.provider_icon_url = providerIconURL
            self.provider_name = providerName
        }

        private enum CodingKeys: String, CodingKey {
            case alt_text, title, thumbnail_url, video_url, title_url, description, author_name, provider_icon_url, provider_name
        }
    }

    /// Displays an embedded video player. See ``Block/Video`` for the
    /// scope and URL requirements Slack enforces.
    public static func video(_ video: Video) -> Block {
        var block = Block(type: "video")
        block.video = video
        return block
    }

    //--------------------------------------
    // MARK: - FILE -
    //--------------------------------------
    /**
     Payload of a `file` block. Cannot be posted directly — Slack surfaces
     these when retrieving messages that contain remote files, so this
     family is decode-and-relay only (no builder).
     */
    public struct FileBlock: Codable, Equatable, Sendable {
        public var external_id: String
        /// Currently always `"remote"`.
        public var source: String

        public init(externalID: String, source: String = "remote") {
            self.external_id = externalID
            self.source = source
        }

        private enum CodingKeys: String, CodingKey {
            case external_id, source
        }
    }

    //--------------------------------------
    // MARK: - MARKDOWN -
    //--------------------------------------
    /**
     Payload of a `markdown` block — standard markdown, translated by Slack.

     The wire `text` here is a **raw JSON string**, not a text object — which
     is why this family exists rather than reusing the shared `Block.text`
     (Forbidden #6; sharing the field emits a shape Slack rejects).

     - note: For apps using platform AI features. Cumulative limit across all
       markdown blocks in one payload: 12,000 characters. `block_id` is
       ignored and not retained by Slack.
     */
    public struct Markdown: Codable, Equatable, Sendable {
        public var text: String

        public init(_ text: String) { self.text = text }

        private enum CodingKeys: String, CodingKey {
            case text
        }
    }

    /// Displays standard markdown (not mrkdwn).
    public static func markdown(_ text: String) -> Block {
        var block = Block(type: "markdown")
        block.markdown = Markdown(text)
        return block
    }

    //--------------------------------------
    // MARK: - ALERT -
    //--------------------------------------
    /**
     Payload of an `alert` block.

     ## Available in Surfaces
     - Modals **only** (per Slack's docs as of 2026-08; D9: documented, not
       kit-enforced)

     Modelled per Slack's own example (`text` a text object, `level` a
     string) — the doc table contradicts it; spec axiom says examples win.
     */
    public struct Alert: Codable, Equatable, Sendable {
        /// Max 200 characters.
        public var text: Text
        /// Omitted means `default`.
        public var level: Level?

        public init(_ text: String, level: Level? = nil) {
            self.text = Text(text)
            self.level = level
        }

        /// Tolerant like ``Block/Style``: an unlisted value decodes rather than throws.
        public struct Level: RawRepresentable, Codable, Equatable, Sendable {
            public let rawValue: String
            public init(rawValue: String) { self.rawValue = rawValue }

            public static let info = Level(rawValue: "info")
            public static let warning = Level(rawValue: "warning")
            public static let error = Level(rawValue: "error")
            public static let success = Level(rawValue: "success")
        }

        private enum CodingKeys: String, CodingKey {
            case text, level
        }
    }

    /// Displays an alert banner. Modals only, per Slack's current docs.
    public static func alert(_ text: String, level: Alert.Level? = nil) -> Block {
        var block = Block(type: "alert")
        block.alert = Alert(text, level: level)
        return block
    }
}
